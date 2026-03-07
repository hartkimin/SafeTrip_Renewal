# Member Tab (DOC-T3-MBR-019) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement all Phase 1~3 gaps between existing code and the member tab architecture principles (DOC-T3-MBR-019 v1.1).

**Architecture:** Gap-fill approach — existing MemberTabProvider, TripMember model, MemberCard widget, and BottomSheetMember are retained. Missing APIs are added to the NestJS backend (guardians module + new attendance controller). Flutter side wires existing TODO stubs to real API calls, adds offline caching, and completes minor protection flow.

**Tech Stack:** Flutter (Riverpod, SharedPreferences), NestJS (TypeORM, PostgreSQL), Firebase RTDB

---

## Phase 1 — 런칭 필수 (P0 + P1)

### Task 1: Backend — Attendance Controller & Service

**Files:**
- Create: `safetrip-server-api/src/modules/attendance/attendance.controller.ts`
- Create: `safetrip-server-api/src/modules/attendance/attendance.service.ts`
- Create: `safetrip-server-api/src/modules/attendance/attendance.module.ts`
- Modify: `safetrip-server-api/src/app.module.ts` (import AttendanceModule)

**Context:**
- Entities already exist: `AttendanceCheck`, `AttendanceResponse` in `src/entities/attendance.entity.ts`
- Tables exist in SQL: `tb_attendance_check`, `tb_attendance_response` (sql/05-schema-safety-sos.sql:84-118)
- No controller/service exists yet — only entities and schema

**Step 1: Create attendance.service.ts**

```typescript
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AttendanceCheck, AttendanceResponse } from '../../entities/attendance.entity';

@Injectable()
export class AttendanceService {
    constructor(
        @InjectRepository(AttendanceCheck) private checkRepo: Repository<AttendanceCheck>,
        @InjectRepository(AttendanceResponse) private responseRepo: Repository<AttendanceResponse>,
    ) {}

    // POST /api/v1/trips/:tripId/attendance
    async startCheck(tripId: string, groupId: string, initiatedBy: string) {
        // 진행 중인 출석 체크가 있는지 확인
        const ongoing = await this.checkRepo.findOne({
            where: { tripId, groupId, status: 'ongoing' },
        });
        if (ongoing) {
            throw new BadRequestException('이미 진행 중인 출석 체크가 있습니다');
        }

        const deadline = new Date(Date.now() + 10 * 60 * 1000); // 10분
        const check = this.checkRepo.create({
            tripId,
            groupId,
            initiatedBy,
            status: 'ongoing',
            deadlineAt: deadline,
        });
        const saved = await this.checkRepo.save(check);

        return {
            check_id: saved.checkId,
            trip_id: saved.tripId,
            group_id: saved.groupId,
            status: saved.status,
            deadline_at: saved.deadlineAt,
            created_at: saved.createdAt,
        };
    }

    // PATCH /api/v1/trips/:tripId/attendance/:checkId/respond
    async respond(checkId: string, userId: string, responseType: 'present' | 'absent') {
        const check = await this.checkRepo.findOne({ where: { checkId } });
        if (!check || check.status !== 'ongoing') {
            throw new NotFoundException('진행 중인 출석 체크를 찾을 수 없습니다');
        }

        // 마감 시간 확인
        if (new Date() > check.deadlineAt) {
            throw new BadRequestException('출석 체크 마감 시간이 지났습니다');
        }

        let response = await this.responseRepo.findOne({
            where: { checkId, userId },
        });

        if (response) {
            response.responseType = responseType;
            response.respondedAt = new Date();
        } else {
            response = this.responseRepo.create({
                checkId,
                userId,
                responseType,
                respondedAt: new Date(),
            });
        }

        const saved = await this.responseRepo.save(response);
        return {
            response_id: saved.responseId,
            check_id: saved.checkId,
            user_id: saved.userId,
            response_type: saved.responseType,
            responded_at: saved.respondedAt,
        };
    }

    // PATCH /api/v1/trips/:tripId/attendance/:checkId/close
    async closeCheck(checkId: string) {
        const check = await this.checkRepo.findOne({ where: { checkId } });
        if (!check) throw new NotFoundException('출석 체크를 찾을 수 없습니다');

        // 미응답자 자동 absent 처리
        await this.responseRepo
            .createQueryBuilder()
            .update()
            .set({ responseType: 'absent' })
            .where('check_id = :checkId AND response_type = :unknown', {
                checkId,
                unknown: 'unknown',
            })
            .execute();

        check.status = 'completed';
        check.completedAt = new Date();
        await this.checkRepo.save(check);

        return { check_id: check.checkId, status: 'completed' };
    }

    // GET /api/v1/trips/:tripId/attendance
    async getChecks(tripId: string) {
        const checks = await this.checkRepo.find({
            where: { tripId },
            order: { createdAt: 'DESC' },
            take: 10,
        });
        return checks.map(c => ({
            check_id: c.checkId,
            trip_id: c.tripId,
            status: c.status,
            deadline_at: c.deadlineAt,
            created_at: c.createdAt,
            completed_at: c.completedAt,
        }));
    }

    // GET /api/v1/trips/:tripId/attendance/:checkId/responses
    async getResponses(checkId: string) {
        const responses = await this.responseRepo.find({
            where: { checkId },
            order: { createdAt: 'ASC' },
        });
        return responses.map(r => ({
            response_id: r.responseId,
            user_id: r.userId,
            response_type: r.responseType,
            responded_at: r.respondedAt,
        }));
    }
}
```

**Step 2: Create attendance.controller.ts**

```typescript
import { Controller, Get, Post, Patch, Param, Body, HttpCode, HttpStatus, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AttendanceService } from './attendance.service';

@ApiTags('Attendance')
@ApiBearerAuth('firebase-auth')
@Controller('trips/:tripId/attendance')
export class AttendanceController {
    constructor(private readonly attendanceService: AttendanceService) {}

    @Get()
    @ApiOperation({ summary: '출석 체크 목록 조회' })
    getChecks(@Param('tripId') tripId: string) {
        return this.attendanceService.getChecks(tripId);
    }

    @Post()
    @ApiOperation({ summary: '출석 체크 시작 (캡틴/크루장 전용)' })
    @HttpCode(HttpStatus.CREATED)
    startCheck(
        @Param('tripId') tripId: string,
        @Body('group_id') groupId: string,
        @CurrentUser() userId: string,
    ) {
        return this.attendanceService.startCheck(tripId, groupId, userId);
    }

    @Patch(':checkId/respond')
    @ApiOperation({ summary: '출석 응답 (크루)' })
    respond(
        @Param('checkId') checkId: string,
        @CurrentUser() userId: string,
        @Body('response_type') responseType: 'present' | 'absent',
    ) {
        return this.attendanceService.respond(checkId, userId, responseType);
    }

    @Patch(':checkId/close')
    @ApiOperation({ summary: '출석 체크 종료 (미응답 → absent 자동 처리)' })
    closeCheck(@Param('checkId') checkId: string) {
        return this.attendanceService.closeCheck(checkId);
    }

    @Get(':checkId/responses')
    @ApiOperation({ summary: '출석 응답 목록 조회' })
    getResponses(@Param('checkId') checkId: string) {
        return this.attendanceService.getResponses(checkId);
    }
}
```

**Step 3: Create attendance.module.ts**

```typescript
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AttendanceCheck, AttendanceResponse } from '../../entities/attendance.entity';
import { AttendanceController } from './attendance.controller';
import { AttendanceService } from './attendance.service';

@Module({
    imports: [TypeOrmModule.forFeature([AttendanceCheck, AttendanceResponse])],
    controllers: [AttendanceController],
    providers: [AttendanceService],
    exports: [AttendanceService],
})
export class AttendanceModule {}
```

**Step 4: Register in app.module.ts**

Add `AttendanceModule` to the imports array in `app.module.ts`.

**Step 5: Verify**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: No type errors

**Step 6: Commit**

```
feat(backend): add attendance controller and service (DOC-T3-MBR-019 §8)
```

---

### Task 2: Backend — Guardian Release Request for Minors (§10.2)

**Files:**
- Create: `safetrip-server-api/sql/migration-guardian-release-request.sql`
- Modify: `safetrip-server-api/src/entities/guardian.entity.ts` (add GuardianReleaseRequest entity)
- Modify: `safetrip-server-api/src/modules/guardians/guardians.controller.ts` (add release-request endpoints)
- Modify: `safetrip-server-api/src/modules/guardians/guardians.service.ts` (add release request logic)
- Modify: `safetrip-server-api/src/modules/guardians/guardians.module.ts` (register entity)

**Step 1: Create migration SQL**

```sql
-- tb_guardian_release_request — 미성년자 가디언 해제 요청 (§10.2)
CREATE TABLE IF NOT EXISTS tb_guardian_release_request (
    request_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    link_id       UUID NOT NULL REFERENCES tb_guardian_link(link_id),
    trip_id       UUID NOT NULL,
    requested_by  VARCHAR(128) NOT NULL,    -- 해제 요청한 사용자
    status        VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected')),
    captain_id    VARCHAR(128),             -- 승인/거부한 캡틴
    responded_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_release_req_link ON tb_guardian_release_request(link_id);
CREATE INDEX idx_release_req_trip ON tb_guardian_release_request(trip_id, status);
```

**Step 2: Add GuardianReleaseRequest entity**

Add to `guardian.entity.ts`:

```typescript
@Entity('tb_guardian_release_request')
export class GuardianReleaseRequest {
    @PrimaryGeneratedColumn('uuid', { name: 'request_id' })
    requestId: string;

    @Column({ name: 'link_id' })
    linkId: string;

    @Column({ name: 'trip_id' })
    tripId: string;

    @Column({ name: 'requested_by' })
    requestedBy: string;

    @Column({ default: 'pending' })
    status: string;

    @Column({ name: 'captain_id', nullable: true })
    captainId: string;

    @Column({ name: 'responded_at', nullable: true })
    respondedAt: Date;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;
}
```

**Step 3: Add controller endpoints**

Add to `guardians.controller.ts` (before parameterized routes):

```typescript
@Post('release-requests')
@ApiOperation({ summary: '미성년자 가디언 해제 요청 (크루 → 캡틴 승인 필요)' })
@HttpCode(HttpStatus.CREATED)
requestRelease(
    @Param('tripId') tripId: string,
    @CurrentUser() userId: string,
    @Body('link_id') linkId: string,
) {
    return this.guardiansService.createReleaseRequest(tripId, linkId, userId);
}

@Patch('release-requests/:requestId')
@ApiOperation({ summary: '가디언 해제 요청 승인/거부 (캡틴 전용)' })
respondToRelease(
    @Param('tripId') tripId: string,
    @Param('requestId') requestId: string,
    @CurrentUser() captainId: string,
    @Body('action') action: 'approved' | 'rejected',
) {
    return this.guardiansService.respondToReleaseRequest(requestId, captainId, action);
}
```

**Step 4: Add service methods**

Add to `guardians.service.ts`:

```typescript
async createReleaseRequest(tripId: string, linkId: string, requestedBy: string) {
    const link = await this.linkRepo.findOne({ where: { linkId, tripId } });
    if (!link) throw new NotFoundException('가디언 링크를 찾을 수 없습니다');

    const member = await this.userRepo.findOne({ where: { userId: link.memberId } });
    if (!member || member.minorStatus !== 'minor') {
        throw new BadRequestException('미성년자 멤버의 가디언만 해제 요청이 필요합니다');
    }

    const request = this.releaseReqRepo.create({
        linkId, tripId, requestedBy, status: 'pending',
    });
    const saved = await this.releaseReqRepo.save(request);
    // TODO: FCM 알림 발송 (캡틴에게)
    return { request_id: saved.requestId, status: saved.status };
}

async respondToReleaseRequest(requestId: string, captainId: string, action: 'approved' | 'rejected') {
    const request = await this.releaseReqRepo.findOne({ where: { requestId } });
    if (!request || request.status !== 'pending') {
        throw new NotFoundException('처리할 수 없는 요청입니다');
    }

    request.status = action;
    request.captainId = captainId;
    request.respondedAt = new Date();
    await this.releaseReqRepo.save(request);

    if (action === 'approved') {
        await this.linkRepo.remove(
            await this.linkRepo.findOne({ where: { linkId: request.linkId } })
        );
    }

    return { request_id: request.requestId, status: request.status };
}
```

**Step 5: Update module**

Add `GuardianReleaseRequest` to TypeOrmModule.forFeature in guardians.module.ts and inject repository in service constructor.

**Step 6: Commit**

```
feat(backend): add guardian release request for minors (DOC-T3-MBR-019 §10.2)
```

---

### Task 3: Backend — Guardian Schedule Summary API (§9.3)

**Files:**
- Modify: `safetrip-server-api/src/modules/guardians/guardians.controller.ts`
- Modify: `safetrip-server-api/src/modules/guardians/guardians.service.ts`
- Modify: `safetrip-server-api/src/modules/guardians/guardians.module.ts`

**Step 1: Add controller endpoint**

```typescript
@Get(':linkId/schedule-summary')
@ApiOperation({ summary: '연결 멤버 일정 요약 (유료 가디언 전용)' })
getScheduleSummary(
    @Param('tripId') tripId: string,
    @Param('linkId') linkId: string,
    @CurrentUser() guardianId: string,
) {
    return this.guardiansService.getScheduleSummary(tripId, linkId, guardianId);
}
```

**Step 2: Add service method**

```typescript
async getScheduleSummary(tripId: string, linkId: string, guardianId: string) {
    const link = await this.linkRepo.findOne({ where: { linkId, tripId, guardianId } });
    if (!link) throw new NotFoundException('가디언 연결을 찾을 수 없습니다');
    if (!link.isPaid) throw new ForbiddenException('유료 가디언만 일정 요약을 조회할 수 있습니다');

    // 오늘 날짜의 일정만 조회
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const schedules = await this.scheduleRepo.find({
        where: {
            tripId,
            scheduledDate: Between(today, tomorrow),
        },
        order: { scheduledDate: 'ASC' },
        take: 10,
    });

    return schedules.map(s => ({
        schedule_id: s.scheduleId,
        title: s.title,
        scheduled_date: s.scheduledDate,
        location_name: s.locationName,
    }));
}
```

**Step 3: Import Schedule entity in module and inject repository**

Add `TravelSchedule` (or relevant schedule entity) to module imports and service constructor.

**Step 4: Commit**

```
feat(backend): add guardian schedule summary API (DOC-T3-MBR-019 §9.3)
```

---

### Task 4: Flutter — Fix B2B Trip Detection

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart:84`

**Step 1: Fix hardcoded isB2b**

Replace line 84:
```dart
// OLD: const isB2b = false;
// NEW: Detect from trip data
final isB2b = tripState.currentTrip?.isB2b ?? false;
```

If `Trip` model doesn't have `isB2b` field, check `tripType` or add the field.

**Step 2: Verify Trip model has B2B field**

Check `safetrip-mobile/lib/models/trip.dart` for `isB2b` or `is_b2b` field. If missing, add:

```dart
final bool isB2b;
```

And parse from JSON: `isB2b: json['is_b2b'] as bool? ?? false`

**Step 3: Commit**

```
fix(member): wire B2B trip detection from trip model (DOC-T3-MBR-019 §6)
```

---

### Task 5: Flutter — Wire Guardian Management APIs

**Files:**
- Modify: `safetrip-mobile/lib/services/api_service.dart` (add guardian API methods)
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`
- Modify: `safetrip-mobile/lib/features/member/providers/member_tab_provider.dart`

**Step 1: Add API methods to api_service.dart**

```dart
/// 가디언 해제 (DELETE /api/v1/trips/:tripId/guardians/:linkId)
Future<void> removeGuardian(String tripId, String linkId) async {
  await _dio.delete('/trips/$tripId/guardians/$linkId');
}

/// 유료 가디언 추가 결제 (POST /api/v1/trips/:tripId/guardians)
Future<Map<String, dynamic>> addPaidGuardian(
    String tripId, String guardianPhone) async {
  final response = await _dio.post(
    '/trips/$tripId/guardians',
    data: {'guardian_phone': guardianPhone},
  );
  return response.data['data'] as Map<String, dynamic>;
}

/// 미성년자 가디언 해제 요청 (POST /api/v1/trips/:tripId/guardians/release-requests)
Future<Map<String, dynamic>> requestGuardianRelease(
    String tripId, String linkId) async {
  final response = await _dio.post(
    '/trips/$tripId/guardians/release-requests',
    data: {'link_id': linkId},
  );
  return response.data['data'] as Map<String, dynamic>;
}

/// 가디언 해제 요청 승인/거부 (PATCH)
Future<Map<String, dynamic>> respondToGuardianRelease(
    String tripId, String requestId, String action) async {
  final response = await _dio.patch(
    '/trips/$tripId/guardians/release-requests/$requestId',
    data: {'action': action},
  );
  return response.data['data'] as Map<String, dynamic>;
}

/// 가디언 일정 요약 (GET /api/v1/trips/:tripId/guardians/:linkId/schedule-summary)
Future<List<Map<String, dynamic>>> getGuardianScheduleSummary(
    String tripId, String linkId) async {
  final response =
      await _dio.get('/trips/$tripId/guardians/$linkId/schedule-summary');
  return (response.data['data'] as List).cast<Map<String, dynamic>>();
}
```

**Step 2: Wire _showRemoveGuardianDialog to real API**

In `_GuardianManageSheet._showRemoveGuardianDialog`, replace the TODO:

```dart
onPressed: () async {
  Navigator.pop(ctx);
  try {
    await ApiService().removeGuardian(tripId, slot.linkId);
    onRefresh?.call();
  } catch (e) {
    // Show error snackbar in parent context
    debugPrint('Guardian removal failed: $e');
  }
},
```

**Step 3: Wire _showPaymentModal to real API**

Replace the TODO in payment modal button:

```dart
onPressed: () async {
  Navigator.pop(ctx);
  // TODO: Integrate with payment SDK (PG 연동 후 활성화)
  // For now, show phone number input and call addPaidGuardian
},
```

**Step 4: Add provider methods for guardian management**

Add to `MemberTabNotifier`:

```dart
/// 가디언 해제
Future<void> removeGuardian(String linkId) async {
  final tripId = state.tripId;
  if (tripId == null) return;
  try {
    await _apiService.removeGuardian(tripId, linkId);
    await fetchMembers(); // 목록 갱신
  } catch (e) {
    debugPrint('[MemberTabNotifier] removeGuardian error: $e');
  }
}

/// 미성년자 가디언 해제 요청
Future<void> requestGuardianRelease(String linkId) async {
  final tripId = state.tripId;
  if (tripId == null) return;
  await _apiService.requestGuardianRelease(tripId, linkId);
}
```

**Step 5: Commit**

```
feat(member): wire guardian management APIs — release & payment (DOC-T3-MBR-019 §5)
```

---

### Task 6: Flutter — B2B Role Name Truncation + Long-Press (§6.2)

**Files:**
- Modify: `safetrip-mobile/lib/widgets/member_card.dart:124-139`

**Step 1: Add 20-char truncation with Tooltip on long-press**

Replace the B2B role name section:

```dart
if (isB2bTrip &&
    member.b2bRoleName != null &&
    member.b2bRoleName!.isNotEmpty) ...[
  const SizedBox(width: AppSpacing.xs),
  Flexible(
    flex: 0,
    child: Tooltip(
      message: member.b2bRoleName!,
      child: Text(
        '(${member.b2bRoleName!.length > 20 ? '${member.b2bRoleName!.substring(0, 20)}...' : member.b2bRoleName!})',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  ),
],
```

**Step 2: Commit**

```
fix(member): add B2B role name 20-char truncation with tooltip (DOC-T3-MBR-019 §6.2)
```

---

## Phase 2 — 확장 기능 (P2)

### Task 7: Flutter — Attendance Real-Time Counts in Banner (§8.3)

**Files:**
- Modify: `safetrip-mobile/lib/features/trip/providers/attendance_provider.dart`
- Modify: `safetrip-mobile/lib/services/api_service.dart`
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart` (_AttendanceBanner)

**Step 1: Add response counts to AttendanceState**

```dart
class AttendanceState {
  // ... existing fields ...
  final int presentCount;
  final int absentCount;
  final int unknownCount;

  const AttendanceState({
    // ... existing ...
    this.presentCount = 0,
    this.absentCount = 0,
    this.unknownCount = 0,
  });
}
```

**Step 2: Add fetchResponses method to AttendanceNotifier**

```dart
Future<void> fetchResponses(String tripId, String checkId) async {
  try {
    final responses = await _apiService.getAttendanceResponses(tripId, checkId);
    int present = 0, absent = 0, unknown = 0;
    for (final r in responses) {
      switch (r['response_type']) {
        case 'present': present++; break;
        case 'absent': absent++; break;
        default: unknown++; break;
      }
    }
    state = state.copyWith(
      presentCount: present,
      absentCount: absent,
      unknownCount: unknown,
    );
  } catch (e) {
    debugPrint('[AttendanceNotifier] fetchResponses error: $e');
  }
}
```

**Step 3: Add API method**

```dart
Future<List<Map<String, dynamic>>> getAttendanceResponses(
    String tripId, String checkId) async {
  final response = await _dio.get('/trips/$tripId/attendance/$checkId/responses');
  return (response.data['data'] as List).cast<Map<String, dynamic>>();
}
```

**Step 4: Wire real counts in _AttendanceBanner**

Replace TODO hardcoded counts (lines 754-773) with actual state values:

```dart
Row(
  children: [
    _AttendanceStat(
      emoji: '✅', label: '확인',
      count: attendState.presentCount,
      color: AppColors.semanticSuccess,
    ),
    const SizedBox(width: AppSpacing.md),
    _AttendanceStat(
      emoji: '⏳', label: '미응답',
      count: attendState.unknownCount,
      color: AppColors.secondaryAmber,
    ),
    const SizedBox(width: AppSpacing.md),
    _AttendanceStat(
      emoji: '❌', label: '부재',
      count: attendState.absentCount,
      color: AppColors.semanticError,
    ),
  ],
),
```

**Step 5: Add periodic polling during active check**

In `_AttendanceBannerState.initState`, add response polling timer:

```dart
_responseTimer = Timer.periodic(const Duration(seconds: 5), (_) {
  // Poll attendance responses for real-time counts
  // via ref.read(attendanceProvider.notifier).fetchResponses(...)
});
```

**Step 6: Commit**

```
feat(member): wire real-time attendance response counts in banner (DOC-T3-MBR-019 §8.3)
```

---

### Task 8: Flutter — Guardian Schedule Summary (§9.3)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_guardian_members.dart`
- Use: `api_service.dart.getGuardianScheduleSummary()` (added in Task 5)

**Step 1: Add schedule state and fetch**

In `_BottomSheetGuardianMembersState`:

```dart
Map<String, List<Map<String, dynamic>>> _schedulesByMember = {};

Future<void> _fetchSchedule(String linkId) async {
  if (!_isPaidGuardian) return;
  try {
    final tripId = /* from provider */;
    final schedules = await ApiService().getGuardianScheduleSummary(tripId, linkId);
    setState(() { _schedulesByMember[linkId] = schedules; });
  } catch (e) {
    debugPrint('Schedule fetch failed: $e');
  }
}
```

**Step 2: Add schedule section below each linked member card**

```dart
if (_isPaidGuardian && (_schedulesByMember[linkId]?.isNotEmpty ?? false)) ...[
  const SizedBox(height: AppSpacing.sm),
  Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppSpacing.radius8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('연결 멤버 일정 요약', style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        ..._schedulesByMember[linkId]!.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${_formatTime(s['scheduled_date'])}  ${s['title']}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        )),
      ],
    ),
  ),
],
```

**Step 3: Commit**

```
feat(guardian): add paid guardian schedule summary display (DOC-T3-MBR-019 §9.3)
```

---

## Phase 3 — 고급 기능 (P3)

### Task 9: Flutter — Minor Guardian Release Approval Flow (§10.2)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart` (_GuardianManageSheet)

**Step 1: Check isMinor in release dialog**

Modify `_showRemoveGuardianDialog` to check the linked member's minor status:

```dart
void _showRemoveGuardianDialog(BuildContext context, GuardianSlot slot) {
  // Find the member this guardian is linked to
  // If the linked member is minor → show captain approval request dialog
  // Otherwise → show normal release dialog (existing code)

  // For minors:
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('가디언 해제'),
      content: const Text(
        '미성년자 멤버의 가디언 해제는 캡틴 승인이 필요합니다.\n'
        '캡틴에게 해제 요청을 보내시겠습니까?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ApiService().requestGuardianRelease(tripId, slot.linkId);
            // Show confirmation snackbar
          },
          child: const Text('요청 전송'),
        ),
      ],
    ),
  );
}
```

**Step 2: Need member minor status in GuardianSlot**

Add `memberIsMinor` field to GuardianSlot or pass it from the parent member data. The `_GuardianManageSheet` needs access to the linked member's `isMinor` status.

Option: Pass `allMembers` list to `_GuardianManageSheet` and look up member by cross-referencing guardian links.

**Step 3: Commit**

```
feat(member): implement minor guardian release captain approval (DOC-T3-MBR-019 §10.2)
```

---

### Task 10: Flutter — Offline Mode (§14)

**Files:**
- Create: `safetrip-mobile/lib/services/offline_cache_service.dart`
- Modify: `safetrip-mobile/lib/features/member/providers/member_tab_provider.dart`
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart`

**Step 1: Create offline cache service**

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_member.dart';

class OfflineCacheService {
  static const _membersCacheKey = 'offline_members_cache';
  static const _lastSyncKey = 'offline_last_sync';

  /// 멤버 목록 캐시 저장
  Future<void> cacheMembers(List<TripMember> members) async {
    final prefs = await SharedPreferences.getInstance();
    final json = members.map((m) => m.toJson()).toList();
    await prefs.setString(_membersCacheKey, jsonEncode(json));
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// 캐시된 멤버 목록 로드
  Future<List<TripMember>?> loadCachedMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_membersCacheKey);
    if (cached == null) return null;
    final list = (jsonDecode(cached) as List)
        .map((e) => TripMember.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  /// 마지막 동기화 시각
  Future<DateTime?> getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastSyncKey);
    return str != null ? DateTime.tryParse(str) : null;
  }
}
```

**Step 2: Integrate in MemberTabNotifier**

Add connectivity check and caching:

```dart
final OfflineCacheService _cacheService = OfflineCacheService();

Future<void> fetchMembers() async {
  // ... existing fetch logic ...
  // On success, cache the members:
  _cacheService.cacheMembers(members);

  // On error, try loading from cache:
  // catch (e) {
  //   final cached = await _cacheService.loadCachedMembers();
  //   if (cached != null) {
  //     state = state.copyWith(
  //       allMembers: cached,
  //       isOfflineMode: true,
  //       lastSyncAt: await _cacheService.getLastSyncAt(),
  //     );
  //   }
  // }
}
```

**Step 3: Update offline banner to show last sync time**

```dart
Widget _buildOfflineModeBanner() {
  final lastSync = memberState.lastSyncAt;
  final syncText = lastSync != null
      ? _formatTimeDiff(DateTime.now().difference(lastSync))
      : '알 수 없음';
  // ... show "[오프라인 모드] 마지막 동기화: $syncText. 연결 후 자동 갱신됩니다."
}
```

**Step 4: Commit**

```
feat(member): implement offline mode with cache and sync banner (DOC-T3-MBR-019 §14)
```

---

### Task 11: Flutter — Verify & Fix Spec Compliance

**Files:**
- Verify: `safetrip-mobile/lib/widgets/member_card.dart` — §4.2 색상값, dp 규격
- Verify: `safetrip-mobile/lib/features/member/providers/member_tab_provider.dart` — §7.1 정렬
- Verify: `safetrip-mobile/lib/models/trip_member.dart` — §11.1 프라이버시 로직

**Step 1: Check _StatusDot colors match spec**

Spec values (§4.2):
- Online: `#4CAF50` ← Current: `0xFF4CAF50` ✅
- Offline: `#9E9E9E` ← Current: `0xFF9E9E9E` ✅
- SOS: `#F44336` ← Current: `0xFFF44336` ✅
- Dot size: 8dp ← Current: `width: 8, height: 8` ✅

**Step 2: Check avatar size**

Spec: 40×40dp ← Current: `radius: 20` (40dp circle) ✅

**Step 3: Check sorting rule (§7.1)**

4-step sort: SOS → Role → Online → Name ← Current implementation matches ✅

**Step 4: Check privacy logic (§11.1)**

- SOS → always show ✅
- safety_first → always show ✅
- privacy_first + OFF → "위치 비공유 중" ✅
- standard + OFF → "마지막 갱신: N" ✅

**Step 5: Log findings and fix any discrepancies**

If all checks pass, skip commit. If fixes needed, commit:

```
fix(member): align spec compliance for card colors, sorting, privacy (DOC-T3-MBR-019 §4/§7/§11)
```

---

### Task 12: Final Integration Test & Commit

**Step 1: Run Flutter analyze**

```bash
cd safetrip-mobile && flutter analyze lib/widgets/member_card.dart lib/screens/main/bottom_sheets/bottom_sheet_2_member.dart lib/features/member/providers/member_tab_provider.dart lib/models/trip_member.dart
```

Expected: No errors

**Step 2: Run backend TypeScript check**

```bash
cd safetrip-server-api && npx tsc --noEmit
```

Expected: No type errors

**Step 3: Run existing tests**

```bash
cd safetrip-mobile && flutter test test/
cd safetrip-server-api && npm test
```

**Step 4: Final commit if any remaining changes**

```
chore(member): final spec compliance verification (DOC-T3-MBR-019)
```
