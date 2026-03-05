import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, DataSource, IsNull } from 'typeorm';
import {
    Location, LocationSharing, LocationSchedule,
    StayPoint, MovementSession
} from '../../entities/location.entity';
import { PlannedRoute } from '../../entities/planned-route.entity';
import { RouteDeviation } from '../../entities/route-deviation.entity';

@Injectable()
export class LocationsService {
    constructor(
        @InjectRepository(Location) private locationRepo: Repository<Location>,
        @InjectRepository(LocationSharing) private sharingRepo: Repository<LocationSharing>,
        @InjectRepository(LocationSchedule) private scheduleRepo: Repository<LocationSchedule>,
        @InjectRepository(StayPoint) private stayPointRepo: Repository<StayPoint>,
        @InjectRepository(PlannedRoute) private routeRepo: Repository<PlannedRoute>,
        @InjectRepository(RouteDeviation) private deviationRepo: Repository<RouteDeviation>,
        @InjectRepository(MovementSession) private sessionRepo: Repository<MovementSession>,
        private dataSource: DataSource,
    ) { }

    /** 위치 기록 일괄 저장 (오프라인 배치 지원) */
    async batchRecord(userId: string, tripId: string, locations: Array<{
        latitude: number; longitude: number; altitude?: number; accuracy?: number;
        speed?: number; heading?: number; activityType?: string; recordedAt: string;
        batteryLevel?: number; isOffline?: boolean;
    }>) {
        const entities = locations.map((loc) =>
            this.locationRepo.create({
                userId, tripId,
                ...loc,
                recordedAt: new Date(loc.recordedAt),
                serverReceivedAt: new Date(),
            }),
        );
        return this.locationRepo.save(entities);
    }

    /** 오프라인 데이터 벌크 동기화 */
    async syncLocations(userId: string, locations: any[]) {
        const entities = locations.map((loc) =>
            this.locationRepo.create({
                userId,
                tripId: loc.trip_id,
                latitude: loc.latitude,
                longitude: loc.longitude,
                accuracy: loc.accuracy,
                altitude: loc.altitude,
                speed: loc.speed,
                heading: loc.heading,
                batteryLevel: loc.battery_level,
                recordedAt: new Date(loc.timestamp),
                serverReceivedAt: new Date(),
            }),
        );
        return this.locationRepo.save(entities);
    }

    /** PostGIS 기반 경로 이탈 감지 (공간 쿼리 최적화) */
    async checkRouteDeviation(userId: string, tripId: string, lat: number, lng: number) {
        const point = `ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)`;
        
        // 현재 위치와 계획된 경로(LineString) 사이의 최단 거리가 임계값을 넘는지 확인
        const routes = await this.routeRepo.createQueryBuilder('route')
            .where('route.trip_id = :tripId', { tripId })
            .andWhere('route.user_id = :userId', { userId })
            .andWhere('route.is_active = true')
            .select([
                'route.routeId',
                'route.deviationThreshold',
                `ST_Distance(route.geometry, ${point}) * 111000 AS distance_meters` // 대략적인 m 환산 (좌표계에 따라 정확도 차이 발생 가능)
            ])
            .getRawMany();

        for (const r of routes) {
            if (r.distance_meters > r.route_deviationThreshold) {
                // 이탈 감지 로그 기록 (RouteDeviation 엔티티 저장 등)
                this.recordDeviation(userId, tripId, r.route_route_id, r.distance_meters, lat, lng);
            }
        }
        return routes;
    }

    private async recordDeviation(userId: string, tripId: string, routeId: string, distance: number, lat: number, lng: number) {
        const deviation = this.deviationRepo.create({
            userId, tripId, routeId,
            distanceMeters: distance,
            latitude: lat,
            longitude: lng,
            startedAt: new Date()
        });
        await this.deviationRepo.save(deviation);
    }

    async logLocation(data: {
        tripId: string;
        userId: string;
        latitude: number;
        longitude: number;
        accuracy?: number;
        speed?: number;
        heading?: number;
        batteryLevel?: number;
    }) {
        const location = this.locationRepo.create({
            ...data,
            recordedAt: new Date(),
            serverReceivedAt: new Date(),
        });
        return this.locationRepo.save(location);
    }

    async getLocations(tripId: string, userId: string, startTime?: string, endTime?: string, limit: number = 100) {
        const query: any = { tripId, userId };
        if (startTime || endTime) {
            if (startTime && endTime) {
                query.recordedAt = Between(new Date(startTime), new Date(endTime));
            } else if (startTime) {
                query.recordedAt = Between(new Date(startTime), new Date());
            }
        }

        return this.locationRepo.find({
            where: query,
            order: { recordedAt: 'DESC' },
            take: limit,
        });
    }

    /**
     * §04.5 가디언 전용 위치 조회 로직
     * 여행의 프라이버시 등급에 따라 노출 데이터 필터링
     */
    async getGuardianView(tripId: string, memberUserId: string, guardianUserId: string) {
        // 1. 여행 정보 및 프라이버시 등급 조회
        const trip = await this.dataSource.getRepository('tb_trip').findOne({ where: { tripId } });
        if (!trip) throw new NotFoundException('Trip not found');

        // 2. 현재 해당 멤버의 공유 스케줄 ON 여부 확인
        const isSharingOn = await this.checkIsSharingOn(tripId, memberUserId);

        // 3. 등급별 필터링 정책 적용
        const privacyLevel = trip.privacy_level || 'standard';

        if (privacyLevel === 'safety_first') {
            // 안전 최우선: 항상 실시간 최신 위치 반환
            return this.getRecent(tripId, memberUserId, 1);
        }

        if (privacyLevel === 'standard') {
            if (isSharingOn) {
                return this.getRecent(tripId, memberUserId, 1);
            } else {
                // 표준 등급 OFF 시간: 30분 간격 스냅샷 제공
                const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
                return this.locationRepo.find({
                    where: {
                        tripId,
                        userId: memberUserId,
                        recordedAt: Between(thirtyMinutesAgo, new Date())
                    },
                    order: { recordedAt: 'DESC' },
                    take: 1
                });
            }
        }

        if (privacyLevel === 'privacy_first') {
            if (isSharingOn) {
                return this.getRecent(tripId, memberUserId, 1);
            } else {
                // 프라이버시 우선 OFF 시간: 비공유
                return [];
            }
        }

        return [];
    }

    /** 현재 공유 스케줄이 ON인지 판별하는 헬퍼 */
    private async checkIsSharingOn(tripId: string, userId: string): Promise<boolean> {
        const now = new Date();
        const currentTime = now.getHours().toString().padStart(2, '0') + ':' + now.getMinutes().toString().padStart(2, '0');
        const currentDay = now.getDay(); // 0(Sun) ~ 6(Sat)

        // 1. 강제 공유 모드인지 확인 (Trip Entity의 sharing_mode 참조 필요)
        // 2. LocationSchedule 테이블에서 현재 시간에 맞는 규칙이 있는지 확인
        const schedule = await this.scheduleRepo.findOne({
            where: [
                { tripId, userId, dayOfWeek: currentDay, isSharingOn: true },
                { tripId, userId, dayOfWeek: IsNull(), isSharingOn: true } // 매일 적용
            ]
        });

        if (!schedule) return true; // 기본값은 ON (비즈니스 원칙 v5.1 기준)

        // 시간 범위 체크: (startTime <= currentTime <= endTime)
        return currentTime >= schedule.startTime && currentTime <= schedule.endTime;
    }

    async getRecent(tripId: string, userId: string, limit = 100) {
        return this.locationRepo.find({
            where: { tripId, userId },
            order: { recordedAt: 'DESC' },
            take: limit,
        });
    }

    async getGroupLocations(tripId: string) {
        // 각 멤버의 최신 위치 반환 — subquery로 최적화 필요 시 QueryBuilder 사용
        const raw = await this.locationRepo
            .createQueryBuilder('l')
            .distinctOn(['l.user_id'])
            .where('l.trip_id = :tripId', { tripId })
            .orderBy('l.user_id', 'ASC')
            .addOrderBy('l.recorded_at', 'DESC')
            .getMany();
        return raw;
    }

    // ── 위치 공유 설정 ──
    async getSharingSettings(tripId: string, userId: string) {
        return this.sharingRepo.find({ where: { tripId, userId } });
    }

    async updateSharing(tripId: string, userId: string, isSharing: boolean, visibilityType?: string) {
        let sharing = await this.sharingRepo.findOne({ where: { tripId, userId } });
        if (sharing) {
            await this.sharingRepo.update(sharing.sharingId, {
                isSharing,
                visibilityType,

                updatedAt: new Date()
            });
        } else {
            sharing = this.sharingRepo.create({ tripId, userId, isSharing, visibilityType });
            await this.sharingRepo.save(sharing);
        }
        return this.sharingRepo.findOne({ where: { tripId, userId } });
    }

    // ── 일정 기반 공유 ──
    async setSchedule(tripId: string, userId: string, data: {
        dayOfWeek?: number; specificDate?: string; startTime: string; endTime: string; isSharingOn: boolean;
    }) {
        const schedule = this.scheduleRepo.create({
            tripId, userId,
            dayOfWeek: data.dayOfWeek,
            specificDate: data.specificDate ? new Date(data.specificDate) : undefined,
            startTime: data.startTime,
            endTime: data.endTime,
            isSharingOn: data.isSharingOn,
        });
        return this.scheduleRepo.save(schedule);
    }

    // ── 체류 지점 ──
    async getStayPoints(tripId: string, userId: string) {
        return this.stayPointRepo.find({ where: { tripId, userId }, order: { arrivedAt: 'DESC' } });
    }

    // ── Movement Sessions (9.4 ~ 9.9) ──
    async getMovementSessionsSummary(userId: string, page: number, limit: number, needImages?: string, targetDate?: string, timezoneOffset: number = 0) {
        const query = this.sessionRepo.createQueryBuilder('ms')
            .where('ms.userId = :userId', { userId })
            .orderBy('ms.startTime', 'DESC')
            .skip((page - 1) * limit)
            .take(limit);

        if (targetDate) {
            // Very simple date filtering assuming YYYY-MM-DD
            query.andWhere('DATE(ms.startTime) = :targetDate', { targetDate });
        }

        const [sessions, total] = await query.getManyAndCount();

        return {
            sessions,
            page,
            limit,
            total
        };
    }

    async getMovementSessionsDateRange(userId: string, timezoneOffset: number) {
        // Get the earliest and latest session start time
        const { min } = await this.sessionRepo
            .createQueryBuilder('ms')
            .where('ms.userId = :userId', { userId })
            .select('MIN(ms.startTime)', 'min')
            .getRawOne();

        const { max } = await this.sessionRepo
            .createQueryBuilder('ms')
            .where('ms.userId = :userId', { userId })
            .select('MAX(ms.startTime)', 'max')
            .getRawOne();

        return {
            start_date: min || null,
            end_date: max || null
        };
    }

    async getMovementSessionsByDate(userId: string, date: string, timezoneOffset: number, needImages?: string) {
        const query = this.sessionRepo.createQueryBuilder('ms')
            .where('ms.userId = :userId', { userId })
            .andWhere('DATE(ms.startTime) = :date', { date })
            .orderBy('ms.startTime', 'DESC');

        const [sessions, total] = await query.getManyAndCount();

        return {
            sessions,
            date,
            total
        };
    }

    async getMovementSessionDetail(userId: string, sessionId: string) {
        const session = await this.sessionRepo.findOne({ where: { sessionId, userId } });
        if (!session) return null;

        const locations = await this.locationRepo.find({
            where: { movementSessionId: sessionId },
            order: { recordedAt: 'ASC' }
        });

        return {
            session_id: session.sessionId,
            start_time: session.startTime,
            end_time: session.endTime,
            is_completed: session.isCompleted,
            locations
        };
    }

    async completeMovementSession(userId: string, sessionId: string, latitude: number, longitude: number, recordedAt: string) {
        const session = await this.sessionRepo.findOne({ where: { sessionId, userId } });
        if (!session) throw new Error('Session not found');

        // Update session completion
        await this.sessionRepo.update(sessionId, {
            isCompleted: true,
            endTime: new Date(recordedAt)
        });

        // Ensure closing location is stored (assuming tripId exists on location, we might need it ideally, omitting here to just save point)
        // If tripId is strictly required by the schema, we must fetch it.
        const locations = await this.locationRepo.find({ where: { movementSessionId: sessionId }, take: 1 });
        if (locations.length > 0) {
            await this.locationRepo.save(this.locationRepo.create({
                userId,
                tripId: locations[0].tripId, // copy from previous points
                movementSessionId: sessionId,
                latitude,
                longitude,
                recordedAt: new Date(recordedAt),
                serverReceivedAt: new Date()
            }));
        }

        return { success: true };
    }

    async getMovementSessionEvents(userId: string, sessionId: string) {
        // Return locations as events or any other specific event log logic related to this session.
        // Usually relates to deviations or status changes.
        const locations = await this.locationRepo.find({
            where: { movementSessionId: sessionId },
            order: { recordedAt: 'ASC' }
        });

        return {
            session_id: sessionId,
            events: locations,
            count: locations.length
        };
    }
}
