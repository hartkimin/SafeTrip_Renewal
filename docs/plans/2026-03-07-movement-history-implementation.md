# 멤버별 이동기록 구현 계획 (Member Movement History)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 문서 25_T3_멤버별_이동기록_원칙_v1.2의 P0~P3 전체 범위를 구현한다. 역할별 접근 권한, 프라이버시 마스킹, 가디언 is_paid 차등, 타임라인/지도 이중 뷰, 체류 지점 감지, 인사이트를 포함한다.

**Architecture:** 기존 `locations` 모듈에 Guard/Interceptor를 계층적으로 추가하고, Flutter는 `features/movement_history/` 신규 feature로 생성한다. 기존 `SessionService`, `ApiService`, `MemberTabProvider`를 활용하되, 이동기록 전용 API 엔드포인트와 프라이버시 로직을 신규 추가한다.

**Tech Stack:** NestJS (Guard/Interceptor/Service), TypeORM (PostgreSQL), Flutter (Riverpod, flutter_map, GoRouter)

---

## Task 1: DB 마이그레이션 — tb_movement_session 테이블 생성

TypeORM 엔티티는 존재하지만 SQL 스키마에 tb_movement_session 테이블 정의가 누락되어 있다. 마이그레이션 파일을 추가한다.

**Files:**
- Create: `safetrip-server-api/sql/migrations/20260307-add-movement-session-table.sql`

**Step 1: 마이그레이션 SQL 작성**

```sql
-- 20260307-add-movement-session-table.sql
-- TB_MOVEMENT_SESSION 테이블 생성 (엔티티는 존재하나 DDL 누락)

CREATE TABLE IF NOT EXISTS tb_movement_session (
    session_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    start_time      TIMESTAMPTZ,
    end_time        TIMESTAMPTZ,
    is_completed    BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_movement_session_user ON tb_movement_session(user_id);
CREATE INDEX IF NOT EXISTS idx_movement_session_start ON tb_movement_session(start_time DESC);

-- tb_location.movement_session_id에 FK 추가 (IF NOT EXISTS 패턴)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_location_movement_session'
    ) THEN
        ALTER TABLE tb_location
            ADD CONSTRAINT fk_location_movement_session
            FOREIGN KEY (movement_session_id) REFERENCES tb_movement_session(session_id)
            ON DELETE SET NULL;
    END IF;
END $$;
```

**Step 2: 마이그레이션 실행 확인**

Run: `cd safetrip-server-api && psql $DATABASE_URL -f sql/migrations/20260307-add-movement-session-table.sql`
Expected: CREATE TABLE, CREATE INDEX 성공 (이미 존재 시 IF NOT EXISTS로 무시)

**Step 3: 커밋**

```bash
git add safetrip-server-api/sql/migrations/20260307-add-movement-session-table.sql
git commit -m "chore(db): add tb_movement_session DDL migration (스키마 정합성)"
```

---

## Task 2: 백엔드 — 역할별 접근 권한 가드 (§7 RoleAccessGuard)

**Files:**
- Create: `safetrip-server-api/src/modules/locations/guards/movement-history-access.guard.ts`
- Modify: `safetrip-server-api/src/modules/locations/locations.module.ts` (GroupMember, GuardianLink 엔티티 import)

**Step 1: Guard 파일 작성**

```typescript
// safetrip-server-api/src/modules/locations/guards/movement-history-access.guard.ts

import {
    Injectable, CanActivate, ExecutionContext,
    ForbiddenException, NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { GroupMember } from '../../../entities/group-member.entity';
import { GuardianLink } from '../../../entities/guardian.entity';

/**
 * 멤버별 이동기록 접근 권한 가드 (§7 역할별 접근 권한 매트릭스)
 *
 * 요청 경로: /trips/:tripId/members/:targetUserId/movement-history/**
 * 판별 로직:
 *   1. 본인 조회 → 항상 허용 (M1 투명성)
 *   2. 캡틴 → 전체 멤버 허용
 *   3. 크루장 → 소속 조 멤버만 허용 (현재 sub_group 미구현이므로 같은 그룹 멤버로 제한)
 *   4. 크루 → 본인만 허용
 *   5. 가디언 → 연결된(accepted) 멤버만 허용
 */
@Injectable()
export class MovementHistoryAccessGuard implements CanActivate {
    constructor(
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(GuardianLink) private guardianLinkRepo: Repository<GuardianLink>,
    ) {}

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest();
        const requestUserId: string = request.userId;
        const tripId: string = request.params.tripId;
        const targetUserId: string = request.params.targetUserId;

        if (!tripId || !targetUserId) {
            throw new ForbiddenException('tripId and targetUserId are required');
        }

        // M1 투명성: 본인 이동기록은 항상 접근 가능
        if (requestUserId === targetUserId) {
            request.movementHistoryAccess = { role: 'self', isGuardian: false };
            return true;
        }

        // 1. 그룹 멤버로서의 역할 확인
        const requesterMember = await this.memberRepo.findOne({
            where: { tripId, userId: requestUserId, status: 'active' },
        });

        if (requesterMember) {
            const role = requesterMember.memberRole;

            if (role === 'captain') {
                // 캡틴: 전체 멤버 이동기록 조회 가능
                request.movementHistoryAccess = { role: 'captain', isGuardian: false };
                return true;
            }

            if (role === 'crew_chief') {
                // 크루장: 같은 그룹(조) 내 멤버만 조회 가능
                const targetMember = await this.memberRepo.findOne({
                    where: { tripId, userId: targetUserId, status: 'active' },
                });
                if (targetMember && targetMember.groupId === requesterMember.groupId) {
                    request.movementHistoryAccess = { role: 'crew_chief', isGuardian: false };
                    return true;
                }
                throw new ForbiddenException('크루장은 소속 조 멤버의 이동기록만 조회할 수 있습니다.');
            }

            if (role === 'crew') {
                // 크루: 본인만 (이미 위에서 체크됨, 여기 도달하면 타인 조회 시도)
                throw new ForbiddenException('크루는 본인의 이동기록만 조회할 수 있습니다.');
            }
        }

        // 2. 가디언 연결 확인
        const guardianLink = await this.guardianLinkRepo.findOne({
            where: {
                tripId,
                guardianId: requestUserId,
                memberId: targetUserId,
                status: 'accepted',
            },
        });

        if (guardianLink) {
            if (!guardianLink.canViewLocation) {
                throw new ForbiddenException('이 가디언 연결은 위치 조회 권한이 없습니다.');
            }
            request.movementHistoryAccess = {
                role: 'guardian',
                isGuardian: true,
                isPaid: guardianLink.isPaid,
                linkId: guardianLink.linkId,
            };
            return true;
        }

        throw new ForbiddenException('이동기록 조회 권한이 없습니다.');
    }
}
```

**Step 2: locations.module.ts에 엔티티 추가**

기존 `locations.module.ts`에 `GroupMember`와 `GuardianLink` 엔티티를 TypeOrmModule.forFeature에 추가한다.

```typescript
// 변경할 부분 (safetrip-server-api/src/modules/locations/locations.module.ts)
// imports 섹션에 추가:
import { GroupMember } from '../../entities/group-member.entity';
import { GuardianLink } from '../../entities/guardian.entity';

// TypeOrmModule.forFeature 배열에 GroupMember, GuardianLink 추가
TypeOrmModule.forFeature([
    Location, LocationSharing, LocationSchedule,
    StayPoint, SessionMapImage, PlannedRoute, RouteDeviation, MovementSession,
    GroupMember, GuardianLink,  // 신규 추가
]),

// providers에 MovementHistoryAccessGuard 추가
providers: [LocationsService, LocationsGateway, MovementHistoryAccessGuard],
```

**Step 3: 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: 컴파일 에러 없음

**Step 4: 커밋**

```bash
git add safetrip-server-api/src/modules/locations/guards/movement-history-access.guard.ts
git add safetrip-server-api/src/modules/locations/locations.module.ts
git commit -m "feat(backend): add MovementHistoryAccessGuard (§7 역할별 접근 권한)"
```

---

## Task 3: 백엔드 — 프라이버시 마스킹 인터셉터 (§8 PrivacyMaskingInterceptor)

**Files:**
- Create: `safetrip-server-api/src/modules/locations/interceptors/privacy-masking.interceptor.ts`

**Step 1: 인터셉터 작성**

```typescript
// safetrip-server-api/src/modules/locations/interceptors/privacy-masking.interceptor.ts

import {
    Injectable, NestInterceptor, ExecutionContext, CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { DataSource } from 'typeorm';

/**
 * §8 프라이버시 마스킹 인터셉터
 *
 * 응답 데이터의 위치 좌표를 프라이버시 등급에 따라 변환:
 * - safety_first: 마스킹 없음
 * - standard: 정확 주소 제거 (도로명 수준)
 * - privacy_first + 비연동 시간대: 500m 격자 스냅 + 흐림 처리
 *
 * M1 투명성: 본인 조회 시 마스킹 미적용
 * SOS 활성 시: 마스킹 자동 해제 (±30분)
 */
@Injectable()
export class PrivacyMaskingInterceptor implements NestInterceptor {
    constructor(private dataSource: DataSource) {}

    intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
        const request = context.switchToHttp().getRequest();
        const access = request.movementHistoryAccess;

        // 본인 조회 시 마스킹 미적용 (M1 투명성)
        if (access?.role === 'self') {
            return next.handle();
        }

        return next.handle().pipe(
            map(async (responseData) => {
                const tripId = request.params.tripId;
                const targetUserId = request.params.targetUserId;

                // 여행 프라이버시 등급 조회
                const trip = await this.dataSource.query(
                    'SELECT privacy_level FROM tb_trip WHERE trip_id = $1',
                    [tripId],
                );
                const privacyLevel = trip?.[0]?.privacy_level || 'standard';

                if (privacyLevel === 'safety_first') {
                    return responseData;
                }

                // SOS 활성 여부 확인
                const activeSos = await this.dataSource.query(
                    `SELECT sos_id, activated_at FROM tb_sos
                     WHERE user_id = $1 AND status = 'active'
                     ORDER BY activated_at DESC LIMIT 1`,
                    [targetUserId],
                );
                const isSosActive = activeSos?.length > 0;

                // 공유 스케줄 시간대 조회
                const schedules = await this.dataSource.query(
                    `SELECT share_start, share_end, day_of_week, specific_date, is_sharing_on
                     FROM tb_location_schedule
                     WHERE trip_id = $1 AND user_id = $2`,
                    [tripId, targetUserId],
                );

                const data = responseData?.data || responseData;
                if (!data) return responseData;

                // 응답이 배열인 경우 (위치 포인트 목록)
                const locations = Array.isArray(data) ? data
                    : (data.locations ? data.locations : (data.sessions ? null : [data]));

                if (!locations) return responseData;

                const masked = locations.map((loc: any) => {
                    if (!loc.recordedAt && !loc.recorded_at) return loc;

                    const recordedAt = new Date(loc.recordedAt || loc.recorded_at);

                    // SOS 활성 시 ±30분 구간 마스킹 해제
                    if (isSosActive && activeSos[0]) {
                        const sosTime = new Date(activeSos[0].activated_at);
                        const diffMinutes = Math.abs(recordedAt.getTime() - sosTime.getTime()) / 60000;
                        if (diffMinutes <= 30) return loc;
                    }

                    const isSharingOn = this.isWithinSchedule(recordedAt, schedules);

                    if (privacyLevel === 'standard') {
                        // 표준: 정확 주소 제거
                        return { ...loc, address: this.maskToRoadLevel(loc.address) };
                    }

                    if (privacyLevel === 'privacy_first' && !isSharingOn) {
                        // 프라이버시우선 + 비연동: 500m 격자 스냅
                        return {
                            ...loc,
                            latitude: this.snapToGrid(loc.latitude, 500),
                            longitude: this.snapToGrid(loc.longitude, 500),
                            address: this.maskToDistrictLevel(loc.address),
                            accuracy: null,
                            is_masked: true,
                        };
                    }

                    if (privacyLevel === 'privacy_first' && isSharingOn) {
                        // 프라이버시우선 + 연동 시간대: 정확 주소만 제거
                        return { ...loc, address: this.maskToDistrictLevel(loc.address) };
                    }

                    return loc;
                });

                // 응답 구조에 맞게 반환
                if (Array.isArray(data)) return masked;
                if (data.locations) return { ...data, locations: masked };
                return masked[0];
            }),
        );
    }

    /** 위도/경도를 gridMeters 격자 중심으로 스냅 */
    private snapToGrid(coord: number, gridMeters: number): number {
        // 1도 ≈ 111,320m (적도 기준)
        const gridDegrees = gridMeters / 111320;
        return Math.round(coord / gridDegrees) * gridDegrees;
    }

    /** 주소를 도로명 수준으로 마스킹 (standard 등급) */
    private maskToRoadLevel(address: string | null): string | null {
        if (!address) return null;
        // "서울시 강남구 테헤란로 123길 45" → "서울시 강남구 테헤란로 인근"
        const parts = address.split(' ');
        if (parts.length >= 3) {
            return parts.slice(0, 3).join(' ') + ' 인근';
        }
        return address;
    }

    /** 주소를 구/동 수준으로 마스킹 (privacy_first 등급) */
    private maskToDistrictLevel(address: string | null): string | null {
        if (!address) return null;
        const parts = address.split(' ');
        if (parts.length >= 2) {
            return parts.slice(0, 2).join(' ');
        }
        return address;
    }

    /** 특정 시각이 공유 스케줄 시간대 내인지 확인 */
    private isWithinSchedule(recordedAt: Date, schedules: any[]): boolean {
        if (!schedules || schedules.length === 0) return true; // 스케줄 없으면 기본 ON

        const day = recordedAt.getDay();
        const timeStr = recordedAt.getHours().toString().padStart(2, '0') + ':' +
                        recordedAt.getMinutes().toString().padStart(2, '0');

        for (const s of schedules) {
            if (!s.is_sharing_on) continue;

            // 요일 매칭 (NULL이면 매일 적용)
            if (s.day_of_week !== null && s.day_of_week !== day) continue;

            // 특정 일자 매칭
            if (s.specific_date) {
                const specificDate = new Date(s.specific_date).toISOString().split('T')[0];
                const recordedDate = recordedAt.toISOString().split('T')[0];
                if (specificDate !== recordedDate) continue;
            }

            // 시간 범위 체크
            if (timeStr >= s.share_start && timeStr <= s.share_end) {
                return true;
            }
        }

        return false;
    }
}
```

**Step 2: 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: 컴파일 에러 없음

**Step 3: 커밋**

```bash
git add safetrip-server-api/src/modules/locations/interceptors/privacy-masking.interceptor.ts
git commit -m "feat(backend): add PrivacyMaskingInterceptor (§8 프라이버시 등급별 마스킹)"
```

---

## Task 4: 백엔드 — 이동기록 전용 API 컨트롤러 메서드 추가

기존 `locations.controller.ts`에 이동기록 전용 엔드포인트를 추가한다. Guard와 Interceptor를 적용한다.

**Files:**
- Modify: `safetrip-server-api/src/modules/locations/locations.controller.ts`
- Modify: `safetrip-server-api/src/modules/locations/locations.service.ts`

**Step 1: Service에 이동기록 전용 메서드 추가**

`locations.service.ts` 파일 끝에 다음 메서드들을 추가한다:

```typescript
    // ── 멤버별 이동기록 (§7~§9 접근 제어 적용) ──

    /**
     * §7 역할 검증된 멤버 이동기록 조회
     * Guard에서 역할 검증 완료 후 호출됨
     */
    async getMemberMovementHistory(
        tripId: string,
        targetUserId: string,
        date: string,
        access: { role: string; isGuardian: boolean; isPaid?: boolean },
    ) {
        // §9 가디언 접근 범위 필터링
        let timeFilter: { start: Date; end: Date } | null = null;

        if (access.isGuardian && !access.isPaid) {
            // 무료 가디언: 당일(24시간) 이내만
            const now = new Date();
            const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
            const requestedDate = new Date(date + 'T00:00:00Z');

            if (requestedDate < twentyFourHoursAgo) {
                return { sessions: [], date, total: 0, upgrade_required: true };
            }
            timeFilter = { start: twentyFourHoursAgo, end: now };
        }

        // 이동 세션 조회
        const query = this.sessionRepo.createQueryBuilder('ms')
            .where('ms.userId = :userId', { userId: targetUserId })
            .andWhere('DATE(ms.startTime) = :date', { date })
            .orderBy('ms.startTime', 'ASC');

        if (timeFilter) {
            query.andWhere('ms.startTime >= :start', { start: timeFilter.start });
        }

        const [sessions, total] = await query.getManyAndCount();

        // 각 세션의 위치 포인트 수 집계
        const sessionsWithStats = await Promise.all(
            sessions.map(async (session) => {
                const locationCount = await this.locationRepo.count({
                    where: { movementSessionId: session.sessionId },
                });
                return { ...session, location_count: locationCount };
            }),
        );

        return { sessions: sessionsWithStats, date, total };
    }

    /**
     * §7 역할 검증된 타임라인 데이터 조회
     */
    async getMemberTimeline(
        tripId: string,
        targetUserId: string,
        date: string,
        access: { role: string; isGuardian: boolean; isPaid?: boolean },
    ) {
        // 가디언 접근 범위 검증 (무료: 24h)
        if (access.isGuardian && !access.isPaid) {
            const now = new Date();
            const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
            const requestedDate = new Date(date + 'T00:00:00Z');
            if (requestedDate < twentyFourHoursAgo) {
                return { events: [], date, upgrade_required: true };
            }
        }

        const dayStart = new Date(date + 'T00:00:00Z');
        const dayEnd = new Date(date + 'T23:59:59.999Z');

        // 위치 포인트 조회
        const locations = await this.locationRepo.find({
            where: {
                userId: targetUserId,
                recordedAt: Between(dayStart, dayEnd),
            },
            order: { recordedAt: 'ASC' },
        });

        // 체류 지점 조회
        const stayPoints = await this.stayPointRepo.find({
            where: {
                userId: targetUserId,
                tripId,
                arrivedAt: Between(dayStart, dayEnd),
            },
            order: { arrivedAt: 'ASC' },
        });

        // 타임라인 이벤트로 병합
        const events = this.buildTimelineEvents(locations, stayPoints);

        return { events, date, location_count: locations.length, stay_point_count: stayPoints.length };
    }

    /** 위치 포인트와 체류 지점을 타임라인 이벤트로 병합 (§5.3) */
    private buildTimelineEvents(locations: any[], stayPoints: any[]) {
        const events: any[] = [];

        // 이동 세션 시작/종료 이벤트
        let currentSessionId: string | null = null;
        for (const loc of locations) {
            if (loc.movementSessionId && loc.movementSessionId !== currentSessionId) {
                events.push({
                    type: 'movement_start',
                    time: loc.recordedAt,
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                    session_id: loc.movementSessionId,
                });
                currentSessionId = loc.movementSessionId;
            }
        }

        // 이동 세션 종료 이벤트 (마지막 포인트)
        const sessionIds = [...new Set(locations.filter(l => l.movementSessionId).map(l => l.movementSessionId))];
        for (const sid of sessionIds) {
            const sessionLocs = locations.filter(l => l.movementSessionId === sid);
            if (sessionLocs.length > 0) {
                const lastLoc = sessionLocs[sessionLocs.length - 1];
                events.push({
                    type: 'movement_end',
                    time: lastLoc.recordedAt,
                    latitude: lastLoc.latitude,
                    longitude: lastLoc.longitude,
                    session_id: sid,
                });
            }
        }

        // 체류 지점 이벤트
        for (const sp of stayPoints) {
            events.push({
                type: 'stay_point',
                time: sp.arrivedAt,
                end_time: sp.leftAt,
                latitude: sp.latitude,
                longitude: sp.longitude,
                duration_minutes: sp.durationMinutes,
                place_name: sp.placeName,
            });
        }

        // 시간순 정렬 (M3 원칙: 과거→현재)
        events.sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime());

        return events;
    }

    /**
     * 세션 통계 계산
     */
    async getMovementSessionStats(userId: string, sessionId: string) {
        const session = await this.sessionRepo.findOne({ where: { sessionId, userId } });
        if (!session) return null;

        const locations = await this.locationRepo.find({
            where: { movementSessionId: sessionId },
            order: { recordedAt: 'ASC' },
        });

        if (locations.length === 0) return { session_id: sessionId, total_distance_km: 0, avg_speed: 0, max_speed: 0, duration_minutes: 0, location_count: 0 };

        // 총 이동 거리 계산 (Haversine)
        let totalDistance = 0;
        let maxSpeed = 0;
        const speeds: number[] = [];

        for (let i = 1; i < locations.length; i++) {
            const dist = this.haversineDistance(
                locations[i - 1].latitude, locations[i - 1].longitude,
                locations[i].latitude, locations[i].longitude,
            );
            totalDistance += dist;

            if (locations[i].speed) {
                speeds.push(locations[i].speed);
                if (locations[i].speed > maxSpeed) maxSpeed = locations[i].speed;
            }
        }

        const durationMs = session.endTime
            ? new Date(session.endTime).getTime() - new Date(session.startTime).getTime()
            : new Date(locations[locations.length - 1].recordedAt).getTime() - new Date(locations[0].recordedAt).getTime();

        return {
            session_id: sessionId,
            total_distance_km: Math.round(totalDistance * 100) / 100,
            avg_speed: speeds.length > 0 ? Math.round((speeds.reduce((a, b) => a + b, 0) / speeds.length) * 10) / 10 : 0,
            max_speed: Math.round(maxSpeed * 10) / 10,
            duration_minutes: Math.round(durationMs / 60000),
            location_count: locations.length,
        };
    }

    /** Haversine 거리 계산 (km) */
    private haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
        const R = 6371;
        const dLat = (lat2 - lat1) * Math.PI / 180;
        const dLon = (lon2 - lon1) * Math.PI / 180;
        const a = Math.sin(dLat / 2) ** 2 +
                  Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
                  Math.sin(dLon / 2) ** 2;
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    /**
     * §12 체류 지점 감지 (배치 트리거)
     * is_movement_end = TRUE인 위치 포인트가 저장될 때 호출
     */
    async detectStayPoints(userId: string, tripId: string, sessionId: string) {
        const locations = await this.locationRepo.find({
            where: { movementSessionId: sessionId, userId },
            order: { recordedAt: 'ASC' },
        });

        if (locations.length < 3) return [];

        const stayPoints: any[] = [];
        let clusterStart = 0;

        for (let i = 1; i < locations.length; i++) {
            const dist = this.haversineDistance(
                locations[clusterStart].latitude, locations[clusterStart].longitude,
                locations[i].latitude, locations[i].longitude,
            ) * 1000; // km → m

            if (dist > 100) {
                // 반경 100m 초과 → 클러스터 종료 판정
                const clusterLocs = locations.slice(clusterStart, i);
                const durationMs = new Date(clusterLocs[clusterLocs.length - 1].recordedAt).getTime()
                                 - new Date(clusterLocs[0].recordedAt).getTime();
                const durationMinutes = durationMs / 60000;

                if (clusterLocs.length >= 3 && durationMinutes >= 5) {
                    // §12.1 조건 충족: 3포인트 이상 + 5분 이상
                    const centerLat = clusterLocs.reduce((s, l) => s + l.latitude, 0) / clusterLocs.length;
                    const centerLng = clusterLocs.reduce((s, l) => s + l.longitude, 0) / clusterLocs.length;

                    const sp = this.stayPointRepo.create({
                        userId,
                        tripId,
                        latitude: centerLat,
                        longitude: centerLng,
                        arrivedAt: clusterLocs[0].recordedAt,
                        leftAt: clusterLocs[clusterLocs.length - 1].recordedAt,
                        durationMinutes: Math.round(durationMinutes),
                    });
                    stayPoints.push(sp);
                }
                clusterStart = i;
            }
        }

        // 마지막 클러스터 처리
        const lastCluster = locations.slice(clusterStart);
        if (lastCluster.length >= 3) {
            const durationMs = new Date(lastCluster[lastCluster.length - 1].recordedAt).getTime()
                             - new Date(lastCluster[0].recordedAt).getTime();
            if (durationMs / 60000 >= 5) {
                const centerLat = lastCluster.reduce((s, l) => s + l.latitude, 0) / lastCluster.length;
                const centerLng = lastCluster.reduce((s, l) => s + l.longitude, 0) / lastCluster.length;
                stayPoints.push(this.stayPointRepo.create({
                    userId, tripId,
                    latitude: centerLat, longitude: centerLng,
                    arrivedAt: lastCluster[0].recordedAt,
                    leftAt: lastCluster[lastCluster.length - 1].recordedAt,
                    durationMinutes: Math.round(durationMs / 60000),
                }));
            }
        }

        if (stayPoints.length > 0) {
            await this.stayPointRepo.save(stayPoints);
        }

        return stayPoints;
    }
```

**Step 2: Controller에 이동기록 엔드포인트 추가**

`locations.controller.ts`에 Guard/Interceptor를 적용한 새 엔드포인트를 추가한다:

```typescript
// locations.controller.ts 상단 import에 추가:
import { UseGuards, UseInterceptors } from '@nestjs/common';
import { MovementHistoryAccessGuard } from './guards/movement-history-access.guard';
import { PrivacyMaskingInterceptor } from './interceptors/privacy-masking.interceptor';

// 클래스 내부, 기존 메서드들 아래에 추가:

    // ── 멤버별 이동기록 API (§7~§9 접근 제어 적용) ──

    @Get('trips/:tripId/members/:targetUserId/movement-history')
    @ApiOperation({ summary: '멤버 이동기록 조회 (역할 검증 + 마스킹)' })
    @UseGuards(MovementHistoryAccessGuard)
    @UseInterceptors(PrivacyMaskingInterceptor)
    async getMemberMovementHistory(
        @Param('tripId') tripId: string,
        @Param('targetUserId') targetUserId: string,
        @Query('date') date: string,
        @CurrentUser() requestUserId: string,
    ) {
        const request = arguments[arguments.length - 1]; // NestJS injects request
        // Access info is set by guard on request object
        // We need to access it via @Req() decorator
        // For now, reconstruct from params
        const result = await this.locationsService.getMemberMovementHistory(
            tripId, targetUserId, date,
            { role: 'self', isGuardian: false }, // Will be overridden by actual guard data
        );
        return result;
    }

    @Get('trips/:tripId/members/:targetUserId/movement-history/timeline')
    @ApiOperation({ summary: '멤버 이동기록 타임라인 데이터 조회' })
    @UseGuards(MovementHistoryAccessGuard)
    @UseInterceptors(PrivacyMaskingInterceptor)
    async getMemberTimeline(
        @Param('tripId') tripId: string,
        @Param('targetUserId') targetUserId: string,
        @Query('date') date: string,
    ) {
        // Guard sets request.movementHistoryAccess
        return this.locationsService.getMemberTimeline(
            tripId, targetUserId, date,
            { role: 'self', isGuardian: false },
        );
    }

    @Get('trips/:tripId/members/:targetUserId/stay-points')
    @ApiOperation({ summary: '멤버 체류 지점 조회' })
    @UseGuards(MovementHistoryAccessGuard)
    async getMemberStayPoints(
        @Param('tripId') tripId: string,
        @Param('targetUserId') targetUserId: string,
    ) {
        return this.locationsService.getStayPoints(tripId, targetUserId);
    }

    @Get('trips/:tripId/members/:targetUserId/movement-sessions/:sessionId/stats')
    @ApiOperation({ summary: '이동 세션 통계 조회' })
    @UseGuards(MovementHistoryAccessGuard)
    async getMemberSessionStats(
        @Param('tripId') tripId: string,
        @Param('targetUserId') targetUserId: string,
        @Param('sessionId') sessionId: string,
    ) {
        return this.locationsService.getMovementSessionStats(targetUserId, sessionId);
    }
```

**Step 3: @Req() 데코레이터로 Guard 데이터 접근 수정**

위의 컨트롤러 메서드들이 Guard가 설정한 `request.movementHistoryAccess`를 올바르게 사용하도록 수정:

```typescript
// import 추가
import { Req } from '@nestjs/common';

// 각 메서드에서 @Req() request 파라미터 추가하고 access 활용:
    @Get('trips/:tripId/members/:targetUserId/movement-history')
    @UseGuards(MovementHistoryAccessGuard)
    @UseInterceptors(PrivacyMaskingInterceptor)
    async getMemberMovementHistory(
        @Param('tripId') tripId: string,
        @Param('targetUserId') targetUserId: string,
        @Query('date') date: string,
        @Req() request: any,
    ) {
        return this.locationsService.getMemberMovementHistory(
            tripId, targetUserId, date,
            request.movementHistoryAccess,
        );
    }
```

(같은 패턴을 timeline, stay-points, stats 엔드포인트에도 적용)

**Step 4: 빌드 확인**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: 에러 없음

**Step 5: 커밋**

```bash
git add safetrip-server-api/src/modules/locations/locations.controller.ts
git add safetrip-server-api/src/modules/locations/locations.service.ts
git commit -m "feat(backend): add movement history API endpoints with Guard/Interceptor (§7-§9, §12 적용)"
```

---

## Task 5: 백엔드 — 이동기록 인사이트 API (P3)

**Files:**
- Modify: `safetrip-server-api/src/modules/locations/locations.service.ts`
- Modify: `safetrip-server-api/src/modules/locations/locations.controller.ts`

**Step 1: Service에 인사이트 메서드 추가**

```typescript
    /**
     * §13 개인 이동기록 인사이트
     */
    async getMemberInsights(tripId: string, userId: string, date: string) {
        const dayStart = new Date(date + 'T00:00:00Z');
        const dayEnd = new Date(date + 'T23:59:59.999Z');

        // 일별 이동 거리
        const locations = await this.locationRepo.find({
            where: { userId, recordedAt: Between(dayStart, dayEnd) },
            order: { recordedAt: 'ASC' },
        });

        let totalDistance = 0;
        for (let i = 1; i < locations.length; i++) {
            totalDistance += this.haversineDistance(
                locations[i - 1].latitude, locations[i - 1].longitude,
                locations[i].latitude, locations[i].longitude,
            );
        }

        // 이동 수단 분포
        const activityDistribution: Record<string, number> = {};
        for (const loc of locations) {
            const type = loc.activityType || loc.motionState || 'unknown';
            activityDistribution[type] = (activityDistribution[type] || 0) + 1;
        }

        // 체류 핫스팟 TOP 3
        const stayPoints = await this.stayPointRepo.find({
            where: { userId, tripId, arrivedAt: Between(dayStart, dayEnd) },
            order: { durationMinutes: 'DESC' },
            take: 3,
        });

        return {
            date,
            daily_distance_km: Math.round(totalDistance * 100) / 100,
            location_count: locations.length,
            activity_distribution: activityDistribution,
            top_stay_points: stayPoints.map(sp => ({
                place_name: sp.placeName,
                latitude: sp.latitude,
                longitude: sp.longitude,
                duration_minutes: sp.durationMinutes,
            })),
            longest_stay: stayPoints[0] ? {
                place_name: stayPoints[0].placeName,
                duration_minutes: stayPoints[0].durationMinutes,
            } : null,
        };
    }

    /**
     * §13.2 그룹 인사이트 (캡틴/크루장용)
     */
    async getGroupInsights(tripId: string) {
        // 그룹 멤버들의 최신 위치 조회
        const latestLocations = await this.getGroupLocations(tripId);

        if (latestLocations.length === 0) return { members: [], farthest_member: null };

        // 그룹 중심 계산
        const centerLat = latestLocations.reduce((s, l) => s + l.latitude, 0) / latestLocations.length;
        const centerLng = latestLocations.reduce((s, l) => s + l.longitude, 0) / latestLocations.length;

        // 각 멤버의 중심 거리 계산
        const memberDistances = latestLocations.map(loc => ({
            user_id: loc.userId,
            latitude: loc.latitude,
            longitude: loc.longitude,
            distance_from_center_km: this.haversineDistance(centerLat, centerLng, loc.latitude, loc.longitude),
            is_straggler: false,
        }));

        // 낙오 위험 (500m 이상 이격)
        for (const md of memberDistances) {
            md.is_straggler = md.distance_from_center_km > 0.5;
        }

        memberDistances.sort((a, b) => b.distance_from_center_km - a.distance_from_center_km);

        return {
            group_center: { latitude: centerLat, longitude: centerLng },
            members: memberDistances,
            farthest_member: memberDistances[0] || null,
            stragglers: memberDistances.filter(m => m.is_straggler),
        };
    }
```

**Step 2: Controller에 인사이트 엔드포인트 추가**

```typescript
    @Get('trips/:tripId/members/:targetUserId/insights')
    @ApiOperation({ summary: '멤버 이동기록 인사이트 (Phase 2)' })
    @UseGuards(MovementHistoryAccessGuard)
    async getMemberInsights(
        @Param('tripId') tripId: string,
        @Param('targetUserId') targetUserId: string,
        @Query('date') date: string,
    ) {
        return this.locationsService.getMemberInsights(tripId, targetUserId, date);
    }

    @Get('trips/:tripId/insights/group')
    @ApiOperation({ summary: '그룹 인사이트 (캡틴/크루장용, Phase 2)' })
    async getGroupInsights(@Param('tripId') tripId: string) {
        return this.locationsService.getGroupInsights(tripId);
    }
```

**Step 3: 빌드 확인 & 커밋**

```bash
cd safetrip-server-api && npx tsc --noEmit
git add safetrip-server-api/src/modules/locations/locations.service.ts
git add safetrip-server-api/src/modules/locations/locations.controller.ts
git commit -m "feat(backend): add movement insights API (§13 Phase 2 인사이트)"
```

---

## Task 6: 백엔드 테스트 — 역할별 접근 권한 검증 (§18 검증 체크리스트)

**Files:**
- Create: `safetrip-server-api/src/modules/locations/locations.service.spec.ts`

**Step 1: 테스트 파일 작성**

```typescript
// safetrip-server-api/src/modules/locations/locations.service.spec.ts

import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { LocationsService } from './locations.service';
import { Location, LocationSharing, LocationSchedule, StayPoint, MovementSession } from '../../entities/location.entity';
import { PlannedRoute } from '../../entities/planned-route.entity';
import { RouteDeviation } from '../../entities/route-deviation.entity';
import { DataSource } from 'typeorm';

describe('LocationsService', () => {
    let service: LocationsService;

    const mockRepo = () => ({
        find: jest.fn(),
        findOne: jest.fn(),
        save: jest.fn(),
        create: jest.fn((data) => data),
        count: jest.fn(),
        createQueryBuilder: jest.fn(() => ({
            where: jest.fn().mockReturnThis(),
            andWhere: jest.fn().mockReturnThis(),
            orderBy: jest.fn().mockReturnThis(),
            addOrderBy: jest.fn().mockReturnThis(),
            skip: jest.fn().mockReturnThis(),
            take: jest.fn().mockReturnThis(),
            select: jest.fn().mockReturnThis(),
            distinctOn: jest.fn().mockReturnThis(),
            getManyAndCount: jest.fn().mockResolvedValue([[], 0]),
            getMany: jest.fn().mockResolvedValue([]),
            getRawOne: jest.fn().mockResolvedValue({}),
            getRawMany: jest.fn().mockResolvedValue([]),
        })),
    });

    const mockDataSource = {
        getRepository: jest.fn(() => ({ findOne: jest.fn() })),
        query: jest.fn(),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                LocationsService,
                { provide: getRepositoryToken(Location), useFactory: mockRepo },
                { provide: getRepositoryToken(LocationSharing), useFactory: mockRepo },
                { provide: getRepositoryToken(LocationSchedule), useFactory: mockRepo },
                { provide: getRepositoryToken(StayPoint), useFactory: mockRepo },
                { provide: getRepositoryToken(PlannedRoute), useFactory: mockRepo },
                { provide: getRepositoryToken(RouteDeviation), useFactory: mockRepo },
                { provide: getRepositoryToken(MovementSession), useFactory: mockRepo },
                { provide: DataSource, useValue: mockDataSource },
            ],
        }).compile();

        service = module.get<LocationsService>(LocationsService);
    });

    describe('getMemberMovementHistory', () => {
        it('§18.4 무료 가디언 24h 초과 시 upgrade_required 반환', async () => {
            const yesterday = new Date();
            yesterday.setDate(yesterday.getDate() - 2);
            const dateStr = yesterday.toISOString().split('T')[0];

            const result = await service.getMemberMovementHistory(
                'trip-1', 'user-1', dateStr,
                { role: 'guardian', isGuardian: true, isPaid: false },
            );

            expect(result.upgrade_required).toBe(true);
            expect(result.sessions).toEqual([]);
        });

        it('§18.5 유료 가디언 전체 기간 조회 성공', async () => {
            const result = await service.getMemberMovementHistory(
                'trip-1', 'user-1', '2026-03-01',
                { role: 'guardian', isGuardian: true, isPaid: true },
            );

            expect(result.upgrade_required).toBeUndefined();
        });
    });

    describe('detectStayPoints', () => {
        it('§18.10 반경 100m + 5분 기준 체류 지점 감지', async () => {
            const mockLocations = [
                { latitude: 37.5, longitude: 127.0, recordedAt: new Date('2026-03-07T10:00:00Z') },
                { latitude: 37.5001, longitude: 127.0001, recordedAt: new Date('2026-03-07T10:02:00Z') },
                { latitude: 37.5002, longitude: 127.0, recordedAt: new Date('2026-03-07T10:06:00Z') },
                { latitude: 37.51, longitude: 127.01, recordedAt: new Date('2026-03-07T10:20:00Z') },
            ];

            const locationRepo = service['locationRepo'];
            (locationRepo.find as jest.Mock).mockResolvedValue(mockLocations);
            (service['stayPointRepo'].save as jest.Mock).mockResolvedValue([]);

            const result = await service.detectStayPoints('user-1', 'trip-1', 'session-1');

            expect(result.length).toBeGreaterThanOrEqual(1);
            expect(result[0].durationMinutes).toBeGreaterThanOrEqual(5);
        });
    });

    describe('haversineDistance', () => {
        it('서울-부산 거리 약 325km', () => {
            const dist = service['haversineDistance'](37.5665, 126.978, 35.1796, 129.0756);
            expect(dist).toBeGreaterThan(300);
            expect(dist).toBeLessThan(400);
        });
    });

    describe('getMovementSessionStats', () => {
        it('세션 통계 정상 계산', async () => {
            const mockSession = { sessionId: 's1', userId: 'u1', startTime: new Date('2026-03-07T09:00:00Z'), endTime: new Date('2026-03-07T10:00:00Z'), isCompleted: true };
            const mockLocations = [
                { latitude: 37.5, longitude: 127.0, speed: 5, recordedAt: new Date('2026-03-07T09:00:00Z') },
                { latitude: 37.501, longitude: 127.001, speed: 10, recordedAt: new Date('2026-03-07T09:30:00Z') },
                { latitude: 37.502, longitude: 127.002, speed: 3, recordedAt: new Date('2026-03-07T10:00:00Z') },
            ];

            (service['sessionRepo'].findOne as jest.Mock).mockResolvedValue(mockSession);
            (service['locationRepo'].find as jest.Mock).mockResolvedValue(mockLocations);

            const stats = await service.getMovementSessionStats('u1', 's1');

            expect(stats).toBeDefined();
            expect(stats.session_id).toBe('s1');
            expect(stats.total_distance_km).toBeGreaterThan(0);
            expect(stats.max_speed).toBe(10);
            expect(stats.duration_minutes).toBe(60);
            expect(stats.location_count).toBe(3);
        });
    });
});
```

**Step 2: 테스트 실행**

Run: `cd safetrip-server-api && npx jest --testPathPattern=locations.service.spec --verbose`
Expected: 모든 테스트 PASS

**Step 3: 커밋**

```bash
git add safetrip-server-api/src/modules/locations/locations.service.spec.ts
git commit -m "test(backend): add locations service tests (§18 검증 체크리스트)"
```

---

## Task 7: Flutter — 이동기록 데이터 모델

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/models/movement_history_data.dart`
- Create: `safetrip-mobile/lib/features/movement_history/models/timeline_event.dart`
- Create: `safetrip-mobile/lib/features/movement_history/models/session_stats.dart`

**Step 1: 데이터 모델 작성**

```dart
// movement_history_data.dart
class MovementHistoryData {
  final List<MovementSessionData> sessions;
  final String date;
  final int total;
  final bool upgradeRequired;

  const MovementHistoryData({
    required this.sessions,
    required this.date,
    required this.total,
    this.upgradeRequired = false,
  });

  factory MovementHistoryData.fromJson(Map<String, dynamic> json) {
    return MovementHistoryData(
      sessions: (json['sessions'] as List? ?? [])
          .map((s) => MovementSessionData.fromJson(s))
          .toList(),
      date: json['date'] ?? '',
      total: json['total'] ?? 0,
      upgradeRequired: json['upgrade_required'] ?? false,
    );
  }
}

class MovementSessionData {
  final String sessionId;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isCompleted;
  final int locationCount;

  const MovementSessionData({
    required this.sessionId,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.locationCount = 0,
  });

  factory MovementSessionData.fromJson(Map<String, dynamic> json) {
    return MovementSessionData(
      sessionId: json['session_id'] ?? json['sessionId'] ?? '',
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time'].toString()) : null,
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time'].toString()) : null,
      isCompleted: json['is_completed'] ?? json['isCompleted'] ?? false,
      locationCount: json['location_count'] ?? 0,
    );
  }
}
```

```dart
// timeline_event.dart
enum TimelineEventType {
  movementStart,
  movementEnd,
  stayPoint,
  sosEvent,
  alertEvent,
  scheduleEvent,
  gpsGap,
  maskedSection,
}

class TimelineEvent {
  final TimelineEventType type;
  final DateTime time;
  final DateTime? endTime;
  final double latitude;
  final double longitude;
  final String? sessionId;
  final int? durationMinutes;
  final String? placeName;
  final bool isMasked;

  const TimelineEvent({
    required this.type,
    required this.time,
    this.endTime,
    required this.latitude,
    required this.longitude,
    this.sessionId,
    this.durationMinutes,
    this.placeName,
    this.isMasked = false,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      type: _parseEventType(json['type'] ?? ''),
      time: DateTime.parse(json['time'].toString()),
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time'].toString()) : null,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sessionId: json['session_id'],
      durationMinutes: json['duration_minutes'],
      placeName: json['place_name'],
      isMasked: json['is_masked'] ?? false,
    );
  }

  static TimelineEventType _parseEventType(String type) {
    switch (type) {
      case 'movement_start': return TimelineEventType.movementStart;
      case 'movement_end': return TimelineEventType.movementEnd;
      case 'stay_point': return TimelineEventType.stayPoint;
      case 'sos_event': return TimelineEventType.sosEvent;
      case 'alert_event': return TimelineEventType.alertEvent;
      case 'schedule_event': return TimelineEventType.scheduleEvent;
      case 'gps_gap': return TimelineEventType.gpsGap;
      case 'masked_section': return TimelineEventType.maskedSection;
      default: return TimelineEventType.gpsGap;
    }
  }
}
```

```dart
// session_stats.dart
class SessionStats {
  final String sessionId;
  final double totalDistanceKm;
  final double avgSpeed;
  final double maxSpeed;
  final int durationMinutes;
  final int locationCount;

  const SessionStats({
    required this.sessionId,
    required this.totalDistanceKm,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.durationMinutes,
    required this.locationCount,
  });

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    return SessionStats(
      sessionId: json['session_id'] ?? '',
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0,
      avgSpeed: (json['avg_speed'] as num?)?.toDouble() ?? 0,
      maxSpeed: (json['max_speed'] as num?)?.toDouble() ?? 0,
      durationMinutes: json['duration_minutes'] ?? 0,
      locationCount: json['location_count'] ?? 0,
    );
  }
}
```

**Step 2: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/models/
git commit -m "feat(flutter): add movement history data models (§5, §12, §13)"
```

---

## Task 8: Flutter — 이동기록 Service (API 호출 래퍼)

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/services/movement_history_service.dart`

**Step 1: Service 작성**

```dart
// movement_history_service.dart

import '../../../services/api_service.dart';
import '../models/movement_history_data.dart';
import '../models/timeline_event.dart';
import '../models/session_stats.dart';

class MovementHistoryService {
  final ApiService _apiService;

  MovementHistoryService([ApiService? apiService])
      : _apiService = apiService ?? ApiService();

  /// 멤버 이동기록 조회 (역할 검증 + 마스킹 서버 적용)
  Future<MovementHistoryData> getMemberMovementHistory({
    required String tripId,
    required String targetUserId,
    required String date,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/movement-history',
        queryParameters: {'date': date},
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return MovementHistoryData.fromJson(response.data['data']);
      }
      return MovementHistoryData(sessions: [], date: date, total: 0);
    } catch (e) {
      rethrow;
    }
  }

  /// 타임라인 데이터 조회
  Future<List<TimelineEvent>> getMemberTimeline({
    required String tripId,
    required String targetUserId,
    required String date,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/movement-history/timeline',
        queryParameters: {'date': date},
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        final events = response.data['data']['events'] as List? ?? [];
        return events.map((e) => TimelineEvent.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// 세션 통계 조회
  Future<SessionStats?> getSessionStats({
    required String tripId,
    required String targetUserId,
    required String sessionId,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/movement-sessions/$sessionId/stats',
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return SessionStats.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// 체류 지점 조회
  Future<List<Map<String, dynamic>>> getMemberStayPoints({
    required String tripId,
    required String targetUserId,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/stay-points',
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// 개인 인사이트 조회 (Phase 2)
  Future<Map<String, dynamic>?> getMemberInsights({
    required String tripId,
    required String targetUserId,
    required String date,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/insights',
        queryParameters: {'date': date},
      );
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
```

**Step 2: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/services/movement_history_service.dart
git commit -m "feat(flutter): add MovementHistoryService API wrapper (§7-§9 접근 제어)"
```

---

## Task 9: Flutter — Riverpod Provider

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/providers/movement_history_provider.dart`

**Step 1: Provider 작성**

```dart
// movement_history_provider.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movement_history_data.dart';
import '../models/timeline_event.dart';
import '../models/session_stats.dart';
import '../services/movement_history_service.dart';

class MovementHistoryState {
  final bool isLoading;
  final String? error;
  final String selectedDate;
  final MovementHistoryData? historyData;
  final List<TimelineEvent> timelineEvents;
  final SessionStats? sessionStats;
  final int? selectedEventIndex;
  final bool upgradeRequired;
  final String viewMode; // 'timeline' | 'map'

  const MovementHistoryState({
    this.isLoading = false,
    this.error,
    this.selectedDate = '',
    this.historyData,
    this.timelineEvents = const [],
    this.sessionStats,
    this.selectedEventIndex,
    this.upgradeRequired = false,
    this.viewMode = 'timeline',
  });

  MovementHistoryState copyWith({
    bool? isLoading,
    String? error,
    String? selectedDate,
    MovementHistoryData? historyData,
    List<TimelineEvent>? timelineEvents,
    SessionStats? sessionStats,
    int? selectedEventIndex,
    bool? upgradeRequired,
    String? viewMode,
  }) {
    return MovementHistoryState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
      historyData: historyData ?? this.historyData,
      timelineEvents: timelineEvents ?? this.timelineEvents,
      sessionStats: sessionStats ?? this.sessionStats,
      selectedEventIndex: selectedEventIndex ?? this.selectedEventIndex,
      upgradeRequired: upgradeRequired ?? this.upgradeRequired,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

class MovementHistoryNotifier extends StateNotifier<MovementHistoryState> {
  final MovementHistoryService _service;
  final String tripId;
  final String targetUserId;

  MovementHistoryNotifier({
    required this.tripId,
    required this.targetUserId,
    MovementHistoryService? service,
  })  : _service = service ?? MovementHistoryService(),
        super(const MovementHistoryState());

  /// 특정 날짜의 이동기록 + 타임라인 로드
  Future<void> loadHistory(String date) async {
    state = state.copyWith(isLoading: true, error: null, selectedDate: date);
    try {
      final history = await _service.getMemberMovementHistory(
        tripId: tripId, targetUserId: targetUserId, date: date,
      );

      if (history.upgradeRequired) {
        state = state.copyWith(
          isLoading: false,
          historyData: history,
          upgradeRequired: true,
        );
        return;
      }

      final timeline = await _service.getMemberTimeline(
        tripId: tripId, targetUserId: targetUserId, date: date,
      );

      state = state.copyWith(
        isLoading: false,
        historyData: history,
        timelineEvents: timeline,
        upgradeRequired: false,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      String errorMsg = '이동기록을 불러올 수 없습니다.';

      if (statusCode == 403) {
        final code = e.response?.data?['code'];
        if (code == 'upgrade_required') {
          state = state.copyWith(isLoading: false, upgradeRequired: true);
          return;
        }
        errorMsg = e.response?.data?['message'] ?? '접근 권한이 없습니다.';
      } else if (statusCode == 404) {
        errorMsg = '이동기록 보존 기간이 만료되었습니다.';
      }
      state = state.copyWith(isLoading: false, error: errorMsg);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 세션 통계 로드
  Future<void> loadSessionStats(String sessionId) async {
    try {
      final stats = await _service.getSessionStats(
        tripId: tripId, targetUserId: targetUserId, sessionId: sessionId,
      );
      state = state.copyWith(sessionStats: stats);
    } catch (_) {}
  }

  /// 타임라인 이벤트 선택 (양방향 연동)
  void selectEvent(int index) {
    state = state.copyWith(selectedEventIndex: index);
  }

  /// 뷰 모드 전환
  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == 'timeline' ? 'map' : 'timeline',
    );
  }
}

final movementHistoryProvider = StateNotifierProvider.autoDispose
    .family<MovementHistoryNotifier, MovementHistoryState, ({String tripId, String targetUserId})>(
  (ref, params) {
    return MovementHistoryNotifier(
      tripId: params.tripId,
      targetUserId: params.targetUserId,
    );
  },
);
```

**Step 2: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/providers/movement_history_provider.dart
git commit -m "feat(flutter): add MovementHistoryProvider with Riverpod (상태 관리)"
```

---

## Task 10: Flutter — 타임라인 뷰 위젯 (§5)

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/presentation/widgets/timeline_view.dart`
- Create: `safetrip-mobile/lib/features/movement_history/presentation/widgets/timeline_event_marker.dart`

**Step 1: TimelineEventMarker 위젯 작성**

```dart
// timeline_event_marker.dart
import 'package:flutter/material.dart';
import '../../models/timeline_event.dart';

class TimelineEventMarker extends StatelessWidget {
  final TimelineEvent event;
  final bool isSelected;
  final VoidCallback? onTap;

  const TimelineEventMarker({
    super.key,
    required this.event,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _buildMarkerIcon(),
            const SizedBox(width: 12),
            _buildTimeText(context),
            const SizedBox(width: 12),
            Expanded(child: _buildDescription(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerIcon() {
    switch (event.type) {
      case TimelineEventType.movementStart:
        return const Icon(Icons.play_circle_filled, color: Colors.green, size: 20);
      case TimelineEventType.movementEnd:
        return const Icon(Icons.stop_circle, color: Colors.red, size: 20);
      case TimelineEventType.stayPoint:
        return const Icon(Icons.location_on, color: Colors.blue, size: 20);
      case TimelineEventType.sosEvent:
        return const Icon(Icons.warning_amber, color: Colors.red, size: 20);
      case TimelineEventType.alertEvent:
        return const Icon(Icons.notifications, color: Colors.orange, size: 20);
      case TimelineEventType.scheduleEvent:
        return const Icon(Icons.calendar_today, color: Colors.purple, size: 20);
      case TimelineEventType.gpsGap:
        return const Icon(Icons.signal_wifi_off, color: Colors.grey, size: 20);
      case TimelineEventType.maskedSection:
        return const Icon(Icons.visibility_off, color: Colors.grey, size: 20);
    }
  }

  Widget _buildTimeText(BuildContext context) {
    final localTime = event.time.toLocal();
    final timeStr = '${localTime.hour.toString().padStart(2, '0')}:${localTime.minute.toString().padStart(2, '0')}';
    return Text(
      timeStr,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: event.isMasked ? Colors.grey : null,
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    String text;
    switch (event.type) {
      case TimelineEventType.movementStart:
        text = '출발';
      case TimelineEventType.movementEnd:
        text = '도착';
      case TimelineEventType.stayPoint:
        final place = event.placeName ?? '알 수 없는 장소';
        final dur = event.durationMinutes ?? 0;
        text = '$place (${dur}분 체류)';
      case TimelineEventType.sosEvent:
        text = 'SOS 이벤트';
      case TimelineEventType.alertEvent:
        text = '안전 알림';
      case TimelineEventType.scheduleEvent:
        text = '일정 시간대';
      case TimelineEventType.gpsGap:
        text = 'GPS 신호 없음';
      case TimelineEventType.maskedSection:
        text = '비공개 구간';
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: event.isMasked ? Colors.grey : null,
      ),
    );
  }
}
```

**Step 2: TimelineView 위젯 작성**

```dart
// timeline_view.dart
import 'package:flutter/material.dart';
import '../../models/timeline_event.dart';
import 'timeline_event_marker.dart';

class TimelineView extends StatelessWidget {
  final List<TimelineEvent> events;
  final int? selectedIndex;
  final ValueChanged<int>? onEventSelected;
  final ScrollController? scrollController;

  const TimelineView({
    super.key,
    required this.events,
    this.selectedIndex,
    this.onEventSelected,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('이동기록이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      separatorBuilder: (_, __) => _buildConnectorLine(),
      itemBuilder: (context, index) {
        final event = events[index];
        return TimelineEventMarker(
          event: event,
          isSelected: index == selectedIndex,
          onTap: () => onEventSelected?.call(index),
        );
      },
    );
  }

  Widget _buildConnectorLine() {
    return Padding(
      padding: const EdgeInsets.only(left: 25),
      child: Container(
        width: 2,
        height: 24,
        color: Colors.grey.shade300,
      ),
    );
  }
}
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/presentation/widgets/timeline_view.dart
git add safetrip-mobile/lib/features/movement_history/presentation/widgets/timeline_event_marker.dart
git commit -m "feat(flutter): add TimelineView + EventMarker widgets (§5 타임라인 뷰)"
```

---

## Task 11: Flutter — 지도 경로 뷰 위젯 (§6)

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/presentation/widgets/map_route_view.dart`

**Step 1: 지도 뷰 작성**

```dart
// map_route_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/timeline_event.dart';

class MapRouteView extends StatelessWidget {
  final List<TimelineEvent> events;
  final int? selectedIndex;
  final ValueChanged<int>? onEventSelected;
  final MapController? mapController;

  const MapRouteView({
    super.key,
    required this.events,
    this.selectedIndex,
    this.onEventSelected,
    this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('이동기록이 없습니다', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final points = events
        .where((e) => e.latitude != 0 && e.longitude != 0)
        .map((e) => LatLng(e.latitude, e.longitude))
        .toList();

    final bounds = LatLngBounds.fromPoints(points);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: bounds.center,
        initialZoom: 14,
        onTap: (_, __) {},
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.safetrip.app',
        ),
        // §6.2 폴리라인
        PolylineLayer(
          polylines: _buildPolylines(),
        ),
        // §6.3 체류 지점 + 이벤트 마커
        MarkerLayer(
          markers: _buildMarkers(),
        ),
      ],
    );
  }

  List<Polyline> _buildPolylines() {
    // 이동 세션별 폴리라인 (§6.2: 세션별 색상, 최대 8색 순환)
    final sessionColors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    ];

    final Map<String, List<LatLng>> sessionPaths = {};
    for (final event in events) {
      if (event.sessionId != null && !event.isMasked) {
        sessionPaths.putIfAbsent(event.sessionId!, () => []);
        sessionPaths[event.sessionId!]!.add(LatLng(event.latitude, event.longitude));
      }
    }

    int colorIndex = 0;
    return sessionPaths.entries.map((entry) {
      final color = sessionColors[colorIndex % sessionColors.length];
      colorIndex++;
      return Polyline(
        points: entry.value,
        color: color.withOpacity(0.8),
        strokeWidth: 3.0,
      );
    }).toList();
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      if (event.isMasked) continue;

      IconData icon;
      Color color;
      switch (event.type) {
        case TimelineEventType.movementStart:
          icon = Icons.play_circle_filled;
          color = Colors.green;
        case TimelineEventType.movementEnd:
          icon = Icons.stop_circle;
          color = Colors.red;
        case TimelineEventType.stayPoint:
          icon = Icons.location_on;
          color = Colors.blue;
        case TimelineEventType.sosEvent:
          icon = Icons.warning_amber;
          color = Colors.red;
        default:
          continue; // 다른 타입은 마커 표시 안 함
      }

      final isSelected = i == selectedIndex;
      markers.add(Marker(
        point: LatLng(event.latitude, event.longitude),
        width: isSelected ? 48 : 32,
        height: isSelected ? 48 : 32,
        child: GestureDetector(
          onTap: () => onEventSelected?.call(i),
          child: Icon(icon, color: color, size: isSelected ? 32 : 24),
        ),
      ));
    }

    return markers;
  }
}
```

**Step 2: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/presentation/widgets/map_route_view.dart
git commit -m "feat(flutter): add MapRouteView widget (§6 지도 뷰 폴리라인/마커)"
```

---

## Task 12: Flutter — 날짜 선택기 + 가디언 업그레이드 모달

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/presentation/widgets/date_navigator.dart`
- Create: `safetrip-mobile/lib/features/movement_history/presentation/widgets/guardian_upgrade_modal.dart`

**Step 1: DateNavigator 작성**

```dart
// date_navigator.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? minDate;
  final DateTime? maxDate;

  const DateNavigator({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.minDate,
    this.maxDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _canGoBack ? () => _changeDate(-1) : null,
        ),
        GestureDetector(
          onTap: () => _showDatePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              DateFormat('yyyy.MM.dd (E)', 'ko').format(selectedDate),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _canGoForward ? () => _changeDate(1) : null,
        ),
      ],
    );
  }

  bool get _canGoBack => minDate == null || selectedDate.isAfter(minDate!);
  bool get _canGoForward => maxDate == null || selectedDate.isBefore(maxDate!);

  void _changeDate(int days) {
    onDateChanged(selectedDate.add(Duration(days: days)));
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: minDate ?? DateTime(2024),
      lastDate: maxDate ?? DateTime.now(),
    );
    if (picked != null) onDateChanged(picked);
  }
}
```

**Step 2: GuardianUpgradeModal 작성**

```dart
// guardian_upgrade_modal.dart
import 'package:flutter/material.dart';

class GuardianUpgradeModal extends StatelessWidget {
  final String date;
  final VoidCallback? onUpgrade;
  final VoidCallback? onDismiss;

  const GuardianUpgradeModal({
    super.key,
    required this.date,
    this.onUpgrade,
    this.onDismiss,
  });

  static Future<void> show(BuildContext context, {required String date, VoidCallback? onUpgrade}) {
    return showDialog(
      context: context,
      builder: (_) => GuardianUpgradeModal(
        date: date,
        onUpgrade: onUpgrade,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이동기록 열람 제한'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            '$date 이동기록을 보려면\n유료 가디언으로 전환하세요',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '무료 가디언은 당일(24시간 이내)\n이동기록만 조회할 수 있습니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: onUpgrade,
          child: const Text('1,900원으로 전체 기간 조회하기'),
        ),
      ],
    );
  }
}
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/presentation/widgets/date_navigator.dart
git add safetrip-mobile/lib/features/movement_history/presentation/widgets/guardian_upgrade_modal.dart
git commit -m "feat(flutter): add DateNavigator + GuardianUpgradeModal (§9.3 과금 전환)"
```

---

## Task 13: Flutter — 통계 카드 + 인사이트 대시보드

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/presentation/widgets/session_stats_card.dart`
- Create: `safetrip-mobile/lib/features/movement_history/presentation/widgets/insight_dashboard.dart`

**Step 1: 통계 카드 작성**

```dart
// session_stats_card.dart
import 'package:flutter/material.dart';
import '../../models/session_stats.dart';

class SessionStatsCard extends StatelessWidget {
  final SessionStats stats;

  const SessionStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.straighten,
              value: '${stats.totalDistanceKm} km',
              label: '이동 거리',
            ),
            _StatItem(
              icon: Icons.timer,
              value: '${stats.durationMinutes}분',
              label: '이동 시간',
            ),
            _StatItem(
              icon: Icons.speed,
              value: '${stats.avgSpeed} m/s',
              label: '평균 속도',
            ),
            _StatItem(
              icon: Icons.location_on,
              value: '${stats.locationCount}',
              label: '위치 포인트',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
```

**Step 2: 인사이트 대시보드 (P3)**

```dart
// insight_dashboard.dart
import 'package:flutter/material.dart';

class InsightDashboard extends StatelessWidget {
  final Map<String, dynamic> insights;

  const InsightDashboard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('오늘의 인사이트', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildDistanceRow(context),
            const Divider(),
            _buildTopStayPoints(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceRow(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.directions_walk, color: Colors.teal),
        const SizedBox(width: 8),
        Text(
          '총 이동 거리: ${insights['daily_distance_km'] ?? 0} km',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildTopStayPoints(BuildContext context) {
    final topStayPoints = insights['top_stay_points'] as List? ?? [];
    if (topStayPoints.isEmpty) {
      return const Text('체류 지점 데이터가 없습니다.', style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('체류 핫스팟 TOP 3', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...topStayPoints.take(3).map((sp) => ListTile(
          dense: true,
          leading: const Icon(Icons.place, color: Colors.blue),
          title: Text(sp['place_name'] ?? '알 수 없는 장소'),
          trailing: Text('${sp['duration_minutes']}분'),
        )),
      ],
    );
  }
}
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/presentation/widgets/session_stats_card.dart
git add safetrip-mobile/lib/features/movement_history/presentation/widgets/insight_dashboard.dart
git commit -m "feat(flutter): add SessionStatsCard + InsightDashboard (§13 인사이트)"
```

---

## Task 14: Flutter — 메인 이동기록 화면 (screen_movement_history.dart)

이중 뷰(M2), 양방향 연동, 날짜 선택, 통계를 통합하는 메인 화면.

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/presentation/screens/screen_movement_history.dart`

**Step 1: 메인 화면 작성**

```dart
// screen_movement_history.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/movement_history_provider.dart';
import '../widgets/timeline_view.dart';
import '../widgets/map_route_view.dart';
import '../widgets/date_navigator.dart';
import '../widgets/session_stats_card.dart';
import '../widgets/guardian_upgrade_modal.dart';

class MovementHistoryScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String targetUserId;
  final String memberName;

  const MovementHistoryScreen({
    super.key,
    required this.tripId,
    required this.targetUserId,
    required this.memberName,
  });

  @override
  ConsumerState<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends ConsumerState<MovementHistoryScreen> {
  late DateTime _selectedDate;
  final ScrollController _timelineScrollController = ScrollController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _loadData() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    ref
        .read(movementHistoryProvider((
          tripId: widget.tripId,
          targetUserId: widget.targetUserId,
        )).notifier)
        .loadHistory(dateStr);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movementHistoryProvider((
      tripId: widget.tripId,
      targetUserId: widget.targetUserId,
    )));

    // §9.3 가디언 업그레이드 모달 자동 표시
    if (state.upgradeRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GuardianUpgradeModal.show(
          context,
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.memberName} 이동기록'),
      ),
      body: Column(
        children: [
          // 날짜 선택기
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DateNavigator(
              selectedDate: _selectedDate,
              maxDate: DateTime.now(),
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
                _loadData();
              },
            ),
          ),

          // 뷰 모드 탭 (M2 이중 뷰)
          _buildViewModeTab(state),

          // 통계 카드
          if (state.sessionStats != null)
            SessionStatsCard(stats: state.sessionStats!),

          // 메인 콘텐츠
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text(state.error!, style: const TextStyle(color: Colors.red)))
                    : _buildMainContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeTab(MovementHistoryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'timeline', icon: Icon(Icons.timeline), label: Text('타임라인')),
          ButtonSegment(value: 'map', icon: Icon(Icons.map), label: Text('지도')),
        ],
        selected: {state.viewMode},
        onSelectionChanged: (selected) {
          ref
              .read(movementHistoryProvider((
                tripId: widget.tripId,
                targetUserId: widget.targetUserId,
              )).notifier)
              .toggleViewMode();
        },
      ),
    );
  }

  Widget _buildMainContent(MovementHistoryState state) {
    if (state.viewMode == 'timeline') {
      return TimelineView(
        events: state.timelineEvents,
        selectedIndex: state.selectedEventIndex,
        scrollController: _timelineScrollController,
        onEventSelected: (index) {
          _onEventSelected(index, state);
        },
      );
    } else {
      return MapRouteView(
        events: state.timelineEvents,
        selectedIndex: state.selectedEventIndex,
        mapController: _mapController,
        onEventSelected: (index) {
          _onEventSelected(index, state);
        },
      );
    }
  }

  /// M2 양방향 연동: 이벤트 선택 시 타임라인↔지도 동기화
  void _onEventSelected(int index, MovementHistoryState state) {
    final notifier = ref.read(movementHistoryProvider((
      tripId: widget.tripId,
      targetUserId: widget.targetUserId,
    )).notifier);
    notifier.selectEvent(index);

    // 지도 모드에서 선택 시 → 타임라인 스크롤
    // 타임라인에서 선택 시 → 지도 카메라 이동
    if (state.viewMode == 'map' && index < state.timelineEvents.length) {
      // 타임라인 스크롤 (대략적 위치 계산)
      _timelineScrollController.animateTo(
        index * 56.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}
```

**Step 2: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/presentation/screens/screen_movement_history.dart
git commit -m "feat(flutter): add MovementHistoryScreen with dual view (M2 이중 뷰, §5-§6)"
```

---

## Task 15: Flutter — GoRouter 라우팅 + 진입 경로 연결

**Files:**
- Modify: `safetrip-mobile/lib/router/route_paths.dart` (경로 상수 추가)
- Modify: `safetrip-mobile/lib/router/app_router.dart` (GoRoute 추가)

**Step 1: route_paths.dart에 경로 상수 추가**

```dart
// 추가할 경로 상수:
static const String movementHistory = '/trip/:tripId/members/:userId/movement-history';
```

**Step 2: app_router.dart에 GoRoute 추가**

```dart
// import 추가:
import '../features/movement_history/presentation/screens/screen_movement_history.dart';

// GoRoute 추가 (기존 GoRoute 목록에):
GoRoute(
  path: '/trip/:tripId/members/:userId/movement-history',
  builder: (context, state) => MovementHistoryScreen(
    tripId: state.pathParameters['tripId'] ?? '',
    targetUserId: state.pathParameters['userId'] ?? '',
    memberName: state.uri.queryParameters['name'] ?? '',
  ),
),
```

**Step 3: 멤버탭에서 이동기록 진입 버튼 추가**

멤버 상세 화면이나 멤버 카드에서 이동기록으로 이동하는 Navigation 호출:

```dart
// 사용 예시 (멤버 상세 or 멤버 카드에서):
context.push('/trip/$tripId/members/$userId/movement-history?name=${Uri.encodeComponent(memberName)}');
```

**Step 4: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze`
Expected: No issues found

**Step 5: 커밋**

```bash
git add safetrip-mobile/lib/router/route_paths.dart
git add safetrip-mobile/lib/router/app_router.dart
git commit -m "feat(flutter): add movement history route + navigation entry points"
```

---

## Task 16: Flutter — 내보내기 다이얼로그 (P2)

**Files:**
- Create: `safetrip-mobile/lib/features/movement_history/presentation/widgets/export_dialog.dart`

**Step 1: ExportDialog 작성**

```dart
// export_dialog.dart
import 'package:flutter/material.dart';

enum ExportFormat { pdf, csv }

class ExportDialog extends StatelessWidget {
  final String memberName;
  final String date;
  final ValueChanged<ExportFormat>? onExport;

  const ExportDialog({
    super.key,
    required this.memberName,
    required this.date,
    this.onExport,
  });

  static Future<ExportFormat?> show(BuildContext context, {
    required String memberName,
    required String date,
  }) {
    return showDialog<ExportFormat>(
      context: context,
      builder: (_) => ExportDialog(memberName: memberName, date: date),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이동기록 내보내기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$memberName님의 $date 이동기록'),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('PDF'),
            subtitle: const Text('지도 이미지 + 타임라인 요약'),
            onTap: () => Navigator.pop(context, ExportFormat.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.green),
            title: const Text('CSV'),
            subtitle: const Text('위치 포인트 원시 데이터'),
            onTap: () => Navigator.pop(context, ExportFormat.csv),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: 커밋**

```bash
git add safetrip-mobile/lib/features/movement_history/presentation/widgets/export_dialog.dart
git commit -m "feat(flutter): add ExportDialog for PDF/CSV export (§10.3 내보내기)"
```

---

## 실행 규칙 요약

각 Task 구현 후:
1. 빌드/컴파일 확인 (tsc --noEmit / flutter analyze)
2. 테스트 실행 (해당 시)
3. 실패 시 최대 3회 재시도 (원인 분석 → 수정)
4. 모든 테스트 통과 후에만 커밋
5. 커밋 메시지: `[type] 변경 내용 (아키텍처 원칙 적용)`

---

## 구현 순서 요약

| Task | 대상 | 우선순위 | 의존성 |
|------|------|---------|--------|
| 1 | DB 마이그레이션 | P0 | 없음 |
| 2 | RoleAccessGuard | P0 | 없음 |
| 3 | PrivacyMaskingInterceptor | P0 | 없음 |
| 4 | 이동기록 API 엔드포인트 | P0 | Task 2, 3 |
| 5 | 인사이트 API (P3) | P3 | Task 4 |
| 6 | 백엔드 테스트 | P0 | Task 4 |
| 7 | Flutter 데이터 모델 | P1 | 없음 |
| 8 | Flutter Service | P1 | Task 7 |
| 9 | Flutter Provider | P1 | Task 8 |
| 10 | 타임라인 뷰 | P1 | Task 7 |
| 11 | 지도 경로 뷰 | P1 | Task 7 |
| 12 | 날짜 선택기 + 가디언 모달 | P1-P2 | 없음 |
| 13 | 통계 카드 + 인사이트 | P1-P3 | Task 7 |
| 14 | 메인 화면 | P1 | Task 9-13 |
| 15 | 라우팅 연결 | P1 | Task 14 |
| 16 | 내보내기 다이얼로그 | P2 | 없음 |
