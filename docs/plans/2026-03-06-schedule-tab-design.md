# 일정탭 (Schedule Tab) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the complete Schedule Tab (P0–P3) for SafeTrip: backend CRUD APIs with role-based access, Flutter UI with 5 screen regions, offline sync, privacy-level-aware sharing timeline, and Phase 3 social features (reactions, voting, weather, templates, progress).

**Architecture:** Phase-sequential build on top of existing `TravelSchedule` entity and `ApiService` CRUD methods. Backend gets a dedicated `SchedulesModule` (NestJS controller + service). Flutter gets a `ScheduleProvider` (Riverpod StateNotifier) and rewrites `bottom_sheet_1_trip.dart` from 3 mock items to a 5-region live data layout. Each phase adds a layer: P0/P1 = core CRUD + display, P2 = sharing timeline + AI, P3 = social features.

**Tech Stack:** Flutter 3.x + Riverpod 2.6 + Dio 5.4 + sqflite, NestJS + TypeORM + PostgreSQL, Firebase Auth + RTDB

---

## Phase 1: P0 + P1 — Core Schedule Tab

### Task 1: Backend — Schedule History Migration

**Files:**
- Create: `safetrip-server-api/sql/11-schema-schedule-history.sql`

**Step 1: Write the migration SQL**

```sql
-- ============================================================
-- SafeTrip DB Schema v3.6
-- 11: [D] 일정 수정 이력 (일정탭 원칙 §8.2)
-- ============================================================

-- tb_schedule_history: 일정 수정 감사 로그
CREATE TABLE IF NOT EXISTS tb_schedule_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL,
    modified_by     VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    field_name      VARCHAR(50) NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    modified_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_schedule_history_schedule ON tb_schedule_history(schedule_id);
CREATE INDEX idx_schedule_history_modified ON tb_schedule_history(modified_at);

-- Add missing columns to tb_travel_schedule for 일정탭 원칙 §8.1 compliance
ALTER TABLE tb_travel_schedule
    ADD COLUMN IF NOT EXISTS schedule_type VARCHAR(20) DEFAULT 'other',
    ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS end_time TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS all_day BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS location_name VARCHAR(300),
    ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Optimized index for date-based schedule queries
CREATE INDEX IF NOT EXISTS idx_travel_schedule_date
    ON tb_travel_schedule(trip_id, schedule_date)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_travel_schedule_start
    ON tb_travel_schedule(start_time)
    WHERE deleted_at IS NULL;
```

**Step 2: Run migration on dev database**

```bash
cd safetrip-server-api
psql $DATABASE_URL -f sql/11-schema-schedule-history.sql
```

Expected: Tables created, indexes created, no errors.

**Step 3: Commit**

```bash
git add safetrip-server-api/sql/11-schema-schedule-history.sql
git commit -m "feat(db): add schedule_history table and travel_schedule indexes"
```

---

### Task 2: Backend — Schedule History Entity

**Files:**
- Create: `safetrip-server-api/src/entities/schedule-history.entity.ts`
- Modify: `safetrip-server-api/src/entities/index.ts`

**Step 1: Create entity**

```typescript
import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
} from 'typeorm';

/**
 * TB_SCHEDULE_HISTORY -- 일정 수정 이력 (일정탭 원칙 §8.2)
 */
@Entity('tb_schedule_history')
export class ScheduleHistory {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'schedule_id', type: 'uuid' })
    scheduleId: string;

    @Column({ name: 'modified_by', type: 'varchar', length: 128 })
    modifiedBy: string;

    @Column({ name: 'field_name', type: 'varchar', length: 50 })
    fieldName: string;

    @Column({ name: 'old_value', type: 'text', nullable: true })
    oldValue: string | null;

    @Column({ name: 'new_value', type: 'text', nullable: true })
    newValue: string | null;

    @Column({ name: 'modified_at', type: 'timestamptz', default: () => 'NOW()' })
    modifiedAt: Date;
}
```

**Step 2: Export from barrel**

Add to `entities/index.ts`:
```typescript
export { ScheduleHistory } from './schedule-history.entity';
```

**Step 3: Commit**

```bash
git add safetrip-server-api/src/entities/schedule-history.entity.ts safetrip-server-api/src/entities/index.ts
git commit -m "feat(entity): add ScheduleHistory entity"
```

---

### Task 3: Backend — Schedules Module (Controller + Service)

**Files:**
- Create: `safetrip-server-api/src/modules/schedules/schedules.module.ts`
- Create: `safetrip-server-api/src/modules/schedules/schedules.controller.ts`
- Create: `safetrip-server-api/src/modules/schedules/schedules.service.ts`
- Modify: `safetrip-server-api/src/app.module.ts` (add SchedulesModule to imports)

**Step 1: Create the service**

`schedules.service.ts`:
```typescript
import { Injectable, ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, DataSource } from 'typeorm';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { ScheduleHistory } from '../../entities/schedule-history.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';

@Injectable()
export class SchedulesService {
    constructor(
        @InjectRepository(TravelSchedule) private scheduleRepo: Repository<TravelSchedule>,
        @InjectRepository(ScheduleHistory) private historyRepo: Repository<ScheduleHistory>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        private dataSource: DataSource,
    ) {}

    /**
     * Check if user has edit permission (captain or crew_chief)
     * §5.1: 캡틴/크루장만 CUD 가능
     */
    async checkEditPermission(tripId: string, userId: string): Promise<GroupMember> {
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });
        if (!member) {
            throw new ForbiddenException('여행 멤버가 아닙니다');
        }
        if (!member.canEditSchedule) {
            throw new ForbiddenException('일정 수정 권한이 없습니다');
        }
        return member;
    }

    /**
     * GET schedules by trip + date
     * §3 영역 D: 선택된 날짜의 일정을 시간순 정렬
     */
    async getSchedulesByDate(tripId: string, date?: string) {
        const query = this.scheduleRepo.createQueryBuilder('s')
            .where('s.trip_id = :tripId', { tripId })
            .andWhere('s.deleted_at IS NULL');

        if (date) {
            query.andWhere('s.schedule_date = :date', { date });
        }

        query.orderBy('s.start_time', 'ASC');

        // Select all columns including backward-compat ones
        query.addSelect([
            's.scheduleType', 's.startTime', 's.endTime', 's.allDay',
            's.locationName', 's.locationLat', 's.locationLng',
            's.participants', 's.currencyCode', 's.bookingStatus',
            's.bookingUrl', 's.reminderEnabled', 's.reminderTime',
            's.isCompleted', 's.completedAt', 's.timezone',
        ]);

        return query.getMany();
    }

    /**
     * GET all schedule dates for a trip (for date timeline dots)
     * §3 영역 B: 일정이 있는 날짜에 파란 점 표시
     */
    async getScheduleDates(tripId: string): Promise<string[]> {
        const result = await this.scheduleRepo.createQueryBuilder('s')
            .select('DISTINCT s.schedule_date', 'date')
            .where('s.trip_id = :tripId', { tripId })
            .andWhere('s.deleted_at IS NULL')
            .andWhere('s.schedule_date IS NOT NULL')
            .orderBy('s.schedule_date', 'ASC')
            .getRawMany();
        return result.map(r => r.date);
    }

    /**
     * CREATE schedule
     * §4.1: 직접 입력 / 지도 핀
     */
    async createSchedule(tripId: string, userId: string, data: {
        title: string;
        description?: string;
        scheduleType?: string;
        scheduleDate?: string;
        startTime?: string;
        endTime?: string;
        allDay?: boolean;
        locationName?: string;
        locationLat?: number;
        locationLng?: number;
        reminderEnabled?: boolean;
        timezone?: string;
    }) {
        await this.checkEditPermission(tripId, userId);

        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) throw new NotFoundException('여행을 찾을 수 없습니다');
        if (trip.status === 'completed') {
            throw new BadRequestException('종료된 여행의 일정은 수정할 수 없습니다');
        }

        // §4.1: 여행 기간 내 날짜만 허용
        if (data.scheduleDate && trip.startDate && trip.endDate) {
            const schedDate = new Date(data.scheduleDate);
            if (schedDate < new Date(trip.startDate) || schedDate > new Date(trip.endDate)) {
                throw new BadRequestException('여행 기간 내의 날짜를 선택해 주세요');
            }
        }

        // §4.4: end_datetime < start_datetime 검증
        if (data.startTime && data.endTime) {
            if (new Date(data.endTime) <= new Date(data.startTime)) {
                throw new BadRequestException('종료 시간이 시작 시간보다 빠릅니다');
            }
        }

        const schedule = this.scheduleRepo.create({
            tripId,
            groupId: trip.groupId,
            createdBy: userId,
            title: data.title,
            description: data.description || null,
            scheduleType: data.scheduleType || 'other',
            scheduleDate: data.scheduleDate ? new Date(data.scheduleDate) : null,
            startTime: data.startTime ? new Date(data.startTime) : null,
            endTime: data.endTime ? new Date(data.endTime) : null,
            allDay: data.allDay || false,
            locationName: data.locationName || null,
            locationLat: data.locationLat || null,
            locationLng: data.locationLng || null,
            reminderEnabled: data.reminderEnabled ?? true,
            timezone: data.timezone || null,
        });

        return this.scheduleRepo.save(schedule);
    }

    /**
     * UPDATE schedule with history tracking
     * §4.2: 수정 이력 tb_schedule_history에 기록
     */
    async updateSchedule(tripId: string, scheduleId: string, userId: string, data: Record<string, any>) {
        await this.checkEditPermission(tripId, userId);

        const schedule = await this.scheduleRepo.findOne({
            where: { travelScheduleId: scheduleId, tripId, deletedAt: IsNull() },
        });
        if (!schedule) throw new NotFoundException('일정을 찾을 수 없습니다');

        // Track changes for history
        const trackFields = ['title', 'description', 'scheduleType', 'scheduleDate',
            'startTime', 'endTime', 'allDay', 'locationName', 'locationLat', 'locationLng'];

        const histories: Partial<ScheduleHistory>[] = [];
        for (const field of trackFields) {
            if (data[field] !== undefined && data[field] !== (schedule as any)[field]) {
                histories.push({
                    scheduleId,
                    modifiedBy: userId,
                    fieldName: field,
                    oldValue: String((schedule as any)[field] ?? ''),
                    newValue: String(data[field] ?? ''),
                });
            }
        }

        // Validate times
        const newStart = data.startTime ? new Date(data.startTime) : schedule.startTime;
        const newEnd = data.endTime ? new Date(data.endTime) : schedule.endTime;
        if (newStart && newEnd && newEnd <= newStart) {
            throw new BadRequestException('종료 시간이 시작 시간보다 빠릅니다');
        }

        // Save history + update in transaction
        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
            if (histories.length > 0) {
                await queryRunner.manager.save(ScheduleHistory, histories);
            }
            await queryRunner.manager.update(TravelSchedule,
                { travelScheduleId: scheduleId },
                { ...data, updatedAt: new Date() },
            );
            await queryRunner.commitTransaction();
        } catch (err) {
            await queryRunner.rollbackTransaction();
            throw err;
        } finally {
            await queryRunner.release();
        }

        return this.scheduleRepo.findOne({
            where: { travelScheduleId: scheduleId },
        });
    }

    /**
     * DELETE schedule (soft delete)
     * §4.3: 논리 삭제 (deleted_at 타임스탬프)
     */
    async deleteSchedule(tripId: string, scheduleId: string, userId: string) {
        await this.checkEditPermission(tripId, userId);

        const schedule = await this.scheduleRepo.findOne({
            where: { travelScheduleId: scheduleId, tripId, deletedAt: IsNull() },
        });
        if (!schedule) throw new NotFoundException('일정을 찾을 수 없습니다');

        await this.scheduleRepo.update(
            { travelScheduleId: scheduleId },
            { deletedAt: new Date() },
        );

        return { deleted: true, scheduleId };
    }

    /**
     * Check time conflicts for a given date
     * §4.4: 시간 충돌 경고 (차단하지 않음)
     */
    async checkConflicts(tripId: string, date: string, startTime: string, endTime: string, excludeId?: string) {
        const query = this.scheduleRepo.createQueryBuilder('s')
            .where('s.trip_id = :tripId', { tripId })
            .andWhere('s.schedule_date = :date', { date })
            .andWhere('s.deleted_at IS NULL')
            .andWhere('s.start_time < :endTime', { endTime })
            .andWhere('s.end_time > :startTime', { startTime });

        if (excludeId) {
            query.andWhere('s.travel_schedule_id != :excludeId', { excludeId });
        }

        const conflicts = await query.getMany();
        return { hasConflict: conflicts.length > 0, conflicts };
    }
}
```

**Step 2: Create the controller**

`schedules.controller.ts`:
```typescript
import { Controller, Get, Post, Patch, Delete, Param, Body, Query } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SchedulesService } from './schedules.service';

@ApiTags('Schedules')
@ApiBearerAuth('firebase-auth')
@Controller('trips/:tripId/schedules')
export class SchedulesController {
    constructor(private readonly schedulesService: SchedulesService) {}

    @Get()
    @ApiOperation({ summary: 'Get schedules (optionally by date)' })
    getSchedules(
        @Param('tripId') tripId: string,
        @Query('date') date?: string,
    ) {
        return this.schedulesService.getSchedulesByDate(tripId, date);
    }

    @Get('dates')
    @ApiOperation({ summary: 'Get dates that have schedules (for timeline dots)' })
    getScheduleDates(@Param('tripId') tripId: string) {
        return this.schedulesService.getScheduleDates(tripId);
    }

    @Post()
    @ApiOperation({ summary: 'Create a schedule (captain/crew_chief only)' })
    createSchedule(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Body() body: {
            title: string;
            description?: string;
            scheduleType?: string;
            scheduleDate?: string;
            startTime?: string;
            endTime?: string;
            allDay?: boolean;
            locationName?: string;
            locationLat?: number;
            locationLng?: number;
            reminderEnabled?: boolean;
            timezone?: string;
        },
    ) {
        return this.schedulesService.createSchedule(tripId, userId, body);
    }

    @Patch(':scheduleId')
    @ApiOperation({ summary: 'Update a schedule with history tracking (captain/crew_chief only)' })
    updateSchedule(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Param('scheduleId') scheduleId: string,
        @Body() body: Record<string, any>,
    ) {
        return this.schedulesService.updateSchedule(tripId, scheduleId, userId, body);
    }

    @Delete(':scheduleId')
    @ApiOperation({ summary: 'Soft-delete a schedule (captain/crew_chief only)' })
    deleteSchedule(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Param('scheduleId') scheduleId: string,
    ) {
        return this.schedulesService.deleteSchedule(tripId, scheduleId, userId);
    }

    @Get('conflicts')
    @ApiOperation({ summary: 'Check time conflicts for a given date/time range' })
    checkConflicts(
        @Param('tripId') tripId: string,
        @Query('date') date: string,
        @Query('startTime') startTime: string,
        @Query('endTime') endTime: string,
        @Query('excludeId') excludeId?: string,
    ) {
        return this.schedulesService.checkConflicts(tripId, date, startTime, endTime, excludeId);
    }
}
```

**Step 3: Create the module**

`schedules.module.ts`:
```typescript
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { ScheduleHistory } from '../../entities/schedule-history.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';
import { SchedulesController } from './schedules.controller';
import { SchedulesService } from './schedules.service';

@Module({
    imports: [TypeOrmModule.forFeature([TravelSchedule, ScheduleHistory, GroupMember, Trip])],
    controllers: [SchedulesController],
    providers: [SchedulesService],
    exports: [SchedulesService],
})
export class SchedulesModule {}
```

**Step 4: Register module in app.module.ts**

Add `SchedulesModule` to `imports` array in `app.module.ts`.

**Step 5: Verify server starts**

```bash
cd safetrip-server-api && npm run build
```
Expected: No compilation errors.

**Step 6: Commit**

```bash
git add safetrip-server-api/src/modules/schedules/
git commit -m "feat(api): add SchedulesModule with CRUD, history tracking, role-based access"
```

---

### Task 4: Backend — Update TravelSchedule Entity (remove select:false)

**Files:**
- Modify: `safetrip-server-api/src/entities/travel-schedule.entity.ts`

**Step 1: Remove `select: false` from key columns**

The current entity has `select: false` on critical columns (`scheduleType`, `startTime`, `endTime`, `allDay`, `locationName`, `locationLat`, `locationLng`, `timezone`, `deletedAt`). These must be selectable for schedule queries.

Remove `select: false` from: `scheduleType`, `startTime`, `endTime`, `allDay`, `locationName`, `locationLat`, `locationLng`, `isCompleted`, `timezone`.

Keep `select: false` on: `locationAddress`, `participants`, `currencyCode`, `bookingStatus`, `bookingUrl`, `reminderEnabled`, `reminderTime`, `attachments`, `completedAt` (loaded explicitly when needed).

**Step 2: Commit**

```bash
git add safetrip-server-api/src/entities/travel-schedule.entity.ts
git commit -m "fix(entity): enable select on key TravelSchedule columns for schedule queries"
```

---

### Task 5: Flutter — Schedule Provider

**Files:**
- Create: `safetrip-mobile/lib/features/schedule/providers/schedule_provider.dart`

**Step 1: Create the provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/schedule.dart';
import '../../../services/api_service.dart';

/// 일정탭 상태 (일정탭 원칙 §3)
class ScheduleState {
  const ScheduleState({
    this.isLoading = false,
    this.error,
    this.schedules = const [],
    this.selectedDate,
    this.scheduleDates = const [],
    this.tripStartDate,
    this.tripEndDate,
    this.privacyLevel = 'standard',
    this.userRole = 'crew',
    this.tripStatus = 'active',
    this.tripId,
  });

  final bool isLoading;
  final String? error;
  final List<Schedule> schedules;
  final DateTime? selectedDate;
  final List<String> scheduleDates; // 일정이 있는 날짜 목록 (파란 점)
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;
  final String privacyLevel; // safety_first | standard | privacy_first
  final String userRole; // captain | crew_chief | crew | guardian
  final String tripStatus; // planning | active | completed
  final String? tripId;

  /// §5.1: 캡틴/크루장만 CUD 가능
  bool get canEdit =>
      (userRole == 'captain' || userRole == 'crew_chief') &&
      tripStatus != 'completed';

  /// §6: 프라이버시 우선 등급에서만 배너/타임라인 표시
  bool get showPrivacyBanner => privacyLevel == 'privacy_first';
  bool get showShareTimeline => privacyLevel == 'privacy_first';

  /// §3 영역 B: 여행 기간 날짜 목록 (최대 15일)
  List<DateTime> get tripDates {
    if (tripStartDate == null || tripEndDate == null) return [];
    final dates = <DateTime>[];
    var current = tripStartDate!;
    while (!current.isAfter(tripEndDate!) && dates.length < 15) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  /// 진행 중 일정 (현재 시간 기준)
  Schedule? get currentSchedule {
    final now = DateTime.now();
    try {
      return schedules.firstWhere((s) =>
          s.startTime.isBefore(now) &&
          (s.endTime?.isAfter(now) ?? false));
    } catch (_) {
      return null;
    }
  }

  /// 곧 시작 일정 (15분 이내)
  Schedule? get upcomingSchedule {
    final now = DateTime.now();
    final buffer = now.add(const Duration(minutes: 15));
    try {
      return schedules.firstWhere((s) =>
          s.startTime.isAfter(now) && s.startTime.isBefore(buffer));
    } catch (_) {
      return null;
    }
  }

  ScheduleState copyWith({
    bool? isLoading,
    String? error,
    List<Schedule>? schedules,
    DateTime? selectedDate,
    List<String>? scheduleDates,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
    String? privacyLevel,
    String? userRole,
    String? tripStatus,
    String? tripId,
  }) {
    return ScheduleState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      schedules: schedules ?? this.schedules,
      selectedDate: selectedDate ?? this.selectedDate,
      scheduleDates: scheduleDates ?? this.scheduleDates,
      tripStartDate: tripStartDate ?? this.tripStartDate,
      tripEndDate: tripEndDate ?? this.tripEndDate,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      userRole: userRole ?? this.userRole,
      tripStatus: tripStatus ?? this.tripStatus,
      tripId: tripId ?? this.tripId,
    );
  }
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  ScheduleNotifier(this._apiService) : super(const ScheduleState());

  final ApiService _apiService;

  /// 여행 컨텍스트 설정 (tripProvider에서 호출)
  void setTripContext({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String privacyLevel,
    required String userRole,
    required String tripStatus,
  }) {
    state = state.copyWith(
      tripId: tripId,
      tripStartDate: startDate,
      tripEndDate: endDate,
      privacyLevel: privacyLevel,
      userRole: userRole,
      tripStatus: tripStatus,
      selectedDate: DateTime.now().isAfter(startDate) && DateTime.now().isBefore(endDate)
          ? DateTime.now()
          : startDate,
    );
    fetchScheduleDates();
    fetchSchedules();
  }

  /// 날짜 선택 (영역 B 탭)
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    fetchSchedules();
  }

  /// 일정이 있는 날짜 목록 조회 (파란 점)
  Future<void> fetchScheduleDates() async {
    if (state.tripId == null) return;
    try {
      final result = await _apiService.dio.get(
        '/api/v1/trips/${state.tripId}/schedules/dates',
      );
      if (result.data?['success'] == true) {
        final dates = List<String>.from(result.data['data'] ?? []);
        state = state.copyWith(scheduleDates: dates);
      }
    } catch (_) {
      // Silent fail — dots are cosmetic
    }
  }

  /// 선택된 날짜의 일정 조회
  Future<void> fetchSchedules() async {
    if (state.tripId == null || state.selectedDate == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dateStr =
          '${state.selectedDate!.year}-${state.selectedDate!.month.toString().padLeft(2, '0')}-${state.selectedDate!.day.toString().padLeft(2, '0')}';
      final result = await _apiService.dio.get(
        '/api/v1/trips/${state.tripId}/schedules',
        queryParameters: {'date': dateStr},
      );
      if (result.data?['success'] == true) {
        final list = (result.data['data'] as List?)
                ?.map((e) => Schedule.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        // 시간순 정렬
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
        state = state.copyWith(schedules: list, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '일정을 불러올 수 없습니다. 다시 시도해 주세요',
      );
    }
  }

  /// 일정 삭제
  Future<bool> deleteSchedule(String scheduleId) async {
    if (state.tripId == null) return false;
    try {
      final result = await _apiService.dio.delete(
        '/api/v1/trips/${state.tripId}/schedules/$scheduleId',
      );
      if (result.data?['success'] == true) {
        await fetchSchedules();
        await fetchScheduleDates();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  return ScheduleNotifier(ApiService());
});
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/schedule/providers/schedule_provider.dart
git commit -m "feat(provider): add ScheduleProvider with date-based CRUD and trip context"
```

---

### Task 6: Flutter — DateTimelineBar Widget (영역 B)

**Files:**
- Create: `safetrip-mobile/lib/widgets/schedule/date_timeline_bar.dart`

**Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 영역 B: 날짜 타임라인 바 (일정탭 원칙 §3)
/// - 최대 15일 표시 (§02.3)
/// - 현재 날짜: 파란 테두리 + 진한 텍스트
/// - 일정 있는 날짜: 파란 점
/// - 가로 스크롤, 탭 시 해당 날짜 일정으로 이동
class DateTimelineBar extends StatefulWidget {
  const DateTimelineBar({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.scheduleDates,
    required this.onDateSelected,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final List<String> scheduleDates; // 'YYYY-MM-DD' format
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<DateTimelineBar> createState() => _DateTimelineBarState();
}

class _DateTimelineBarState extends State<DateTimelineBar> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(DateTimelineBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final index = widget.dates.indexWhere((d) =>
        d.year == widget.selectedDate.year &&
        d.month == widget.selectedDate.month &&
        d.day == widget.selectedDate.day);
    if (index >= 0 && _scrollController.hasClients) {
      final offset = (index * 64.0) - (MediaQuery.of(context).size.width / 2 - 32);
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dates.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 68,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: widget.dates.length,
        itemBuilder: (context, index) => _buildDateChip(widget.dates[index]),
      ),
    );
  }

  Widget _buildDateChip(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isSelected = date.year == widget.selectedDate.year &&
        date.month == widget.selectedDate.month &&
        date.day == widget.selectedDate.day;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final hasSchedule = widget.scheduleDates.contains(dateStr);
    final dayName = DateFormat.E('ko').format(date); // 월,화,수...

    return GestureDetector(
      onTap: () => widget.onDateSelected(date),
      child: Container(
        width: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTeal.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          border: isToday
              ? Border.all(color: AppColors.primaryTeal, width: 2)
              : isSelected
                  ? Border.all(color: AppColors.primaryTeal.withOpacity(0.3), width: 1)
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              style: AppTypography.labelSmall.copyWith(
                color: isToday || isSelected
                    ? AppColors.primaryTeal
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.month}/${date.day}',
              style: (isToday || isSelected
                      ? AppTypography.labelMedium
                      : AppTypography.bodySmall)
                  .copyWith(
                color: isToday || isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: isToday ? FontWeight.bold : null,
              ),
            ),
            const SizedBox(height: 4),
            // 파란 점: 일정 있는 날짜
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasSchedule ? AppColors.primaryTeal : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/widgets/schedule/date_timeline_bar.dart
git commit -m "feat(widget): add DateTimelineBar with 15-day limit, today highlight, schedule dots"
```

---

### Task 7: Flutter — ScheduleCard Widget (영역 D)

**Files:**
- Create: `safetrip-mobile/lib/widgets/schedule/schedule_card.dart`

**Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/schedule.dart';

/// 일정 카드 위젯 (일정탭 원칙 §3 영역 D)
/// - 7종 아이콘 (§3 카드 유형별)
/// - 진행 중: 파란 테두리 2px
/// - 곧 시작: 노란 테두리 + "곧 시작" 배지
/// - 종료: 회색 처리
/// - [지도▶] 버튼
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.status, // 'current' | 'upcoming' | 'past' | 'future'
    this.canEdit = false,
    this.onTap,
    this.onMapTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  final Schedule schedule;
  final String status;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  /// §3: 일정 카드 유형별 아이콘 7종
  static IconData typeIcon(String type) {
    switch (type) {
      case 'move':
        return FontAwesomeIcons.plane;
      case 'stay':
        return FontAwesomeIcons.hotel;
      case 'meal':
        return FontAwesomeIcons.utensils;
      case 'sightseeing':
        return FontAwesomeIcons.locationDot;
      case 'shopping':
        return FontAwesomeIcons.bagShopping;
      case 'meeting':
        return FontAwesomeIcons.userGroup;
      case 'other':
      default:
        return FontAwesomeIcons.thumbtack;
    }
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'move': return '이동';
      case 'stay': return '숙박';
      case 'meal': return '식사';
      case 'sightseeing': return '관광';
      case 'shopping': return '쇼핑';
      case 'meeting': return '모임';
      case 'other': default: return '기타';
    }
  }

  Color get _borderColor {
    switch (status) {
      case 'current': return AppColors.primaryTeal;
      case 'upcoming': return AppColors.secondaryAmber;
      case 'past': return Colors.transparent;
      default: return Colors.transparent;
    }
  }

  double get _opacity => status == 'past' ? 0.5 : 1.0;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final startStr = timeFormat.format(schedule.startTime);
    final endStr = schedule.endTime != null ? timeFormat.format(schedule.endTime!) : '';

    return Opacity(
      opacity: _opacity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius12),
            border: Border.all(
              color: _borderColor,
              width: status == 'current' ? 2 : (status == 'upcoming' ? 1.5 : 0.5),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black08, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // 시간 + 타임라인 인디케이터
                SizedBox(
                  width: 52,
                  child: Column(
                    children: [
                      Text(startStr, style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                      if (endStr.isNotEmpty) ...[
                        Container(
                          width: 1.5, height: 16,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: AppColors.outline,
                        ),
                        Text(endStr, style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                        )),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // 아이콘
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  ),
                  child: Center(
                    child: FaIcon(
                      typeIcon(schedule.scheduleType),
                      size: 16,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // 제목 + 장소
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.title,
                        style: AppTypography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (schedule.locationName != null)
                        Text(
                          schedule.locationName!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // 상태 배지
                if (status == 'current')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal,
                      borderRadius: BorderRadius.circular(AppSpacing.radius4),
                    ),
                    child: Text('진행 중', style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                    )),
                  )
                else if (status == 'upcoming')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryAmber,
                      borderRadius: BorderRadius.circular(AppSpacing.radius4),
                    ),
                    child: Text('곧 시작', style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                    )),
                  ),
                const SizedBox(width: AppSpacing.xs),
                // [지도▶] 버튼
                if (schedule.locationCoords != null)
                  IconButton(
                    onPressed: onMapTap,
                    icon: const Icon(Icons.map_outlined, size: 20),
                    color: AppColors.primaryTeal,
                    tooltip: '지도',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/widgets/schedule/schedule_card.dart
git commit -m "feat(widget): add ScheduleCard with 7 type icons, status badges, map button"
```

---

### Task 8: Flutter — Rewrite bottom_sheet_1_trip.dart (5 Regions)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_1_trip.dart`

**Step 1: Full rewrite with 5 regions**

Replace the entire file content. The new version:
- Extends `ConsumerStatefulWidget` (Riverpod)
- Reads from `scheduleProvider` and `tripProvider`
- Displays 5 regions: A (PrivacyBanner), B (DateTimelineBar), C (ShareTimelineBar placeholder), D (ScheduleCardList), E (AddScheduleButton)
- Sorts schedules with current/upcoming first
- Shows empty state with add button for captain/crew_chief

Key structure:
```dart
Column(
  children: [
    // Sub-tabs (일정 | 장소)
    _buildTabs(),
    if (_selectedTab == 0) ...[
      // 영역 A: Privacy banner (privacy_first only)
      if (scheduleState.showPrivacyBanner) _buildPrivacyBanner(),
      // 영역 B: Date timeline
      DateTimelineBar(...),
      // 영역 C: Share timeline (P2 — placeholder)
      if (scheduleState.showShareTimeline) _buildShareTimelinePlaceholder(),
      // 영역 D: Schedule card list
      Expanded(child: _buildScheduleCardList()),
      // 영역 E: Add button (captain/crew_chief only)
      if (scheduleState.canEdit) _buildAddButton(),
    ] else
      Expanded(child: _buildPlaceList()),
  ],
)
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_1_trip.dart
git commit -m "feat(ui): rewrite trip tab with 5 regions, live data from ScheduleProvider"
```

---

### Task 9: Flutter — Update Schedule Model (7-type mapping)

**Files:**
- Modify: `safetrip-mobile/lib/models/schedule.dart`

**Step 1: Update fromJson to map server field names**

The current model uses `scheduleId` but the server returns `travel_schedule_id`. Ensure `fromJson` handles both:
```dart
scheduleId: json['travel_schedule_id'] ?? json['schedule_id'] ?? json['scheduleId'] ?? '',
```

Also ensure `schedule_type` 7종 values map correctly:
```dart
scheduleType: json['schedule_type'] ?? json['scheduleType'] ?? 'other',
```

**Step 2: Commit**

---

### Task 10: Flutter — Update add_schedule_direct_modal.dart (7-type icons)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/add_schedule_direct_modal.dart`

**Step 1: Update `_scheduleTypes` to match 원칙 문서 7종**

Replace current 9 types with the 7 types from §3:
```dart
final List<Map<String, dynamic>> _scheduleTypes = [
  {'id': 'move', 'label': '이동', 'icon': FontAwesomeIcons.plane},
  {'id': 'stay', 'label': '숙박', 'icon': FontAwesomeIcons.hotel},
  {'id': 'meal', 'label': '식사', 'icon': FontAwesomeIcons.utensils},
  {'id': 'sightseeing', 'label': '관광', 'icon': FontAwesomeIcons.locationDot},
  {'id': 'shopping', 'label': '쇼핑', 'icon': FontAwesomeIcons.bagShopping},
  {'id': 'meeting', 'label': '모임', 'icon': FontAwesomeIcons.userGroup},
  {'id': 'other', 'label': '기타', 'icon': FontAwesomeIcons.thumbtack},
];
```

**Step 2: Add `scheduleDate` to API payload**

Update `_handleRegisterSchedule()` to include `schedule_date` derived from `_selectedStartDateTime`.

**Step 3: After successful create/update, refresh scheduleProvider**

```dart
// After Navigator.pop(context, true)
if (mounted) {
  // Trigger schedule list refresh via provider
  // (Parent widget handles this via onScheduleUpdated callback)
}
```

**Step 4: Commit**

---

## Phase 2: P2 — Extended Features

### Task 11: Backend — Share Timeline Calculation API

**Files:**
- Modify: `safetrip-server-api/src/modules/schedules/schedules.service.ts`
- Modify: `safetrip-server-api/src/modules/schedules/schedules.controller.ts`

**Step 1: Add `getShareTimeline` to service**

Calculates sharing segments for a date:
- Green (shared): schedule time ranges
- Light green (buffer): ±15min (configurable 0/15/30)
- Gray (not shared): gaps > 30min
- Auto-connect gaps ≤ 30min (§4.5)

```typescript
async getShareTimeline(tripId: string, date: string) {
    const schedules = await this.getSchedulesByDate(tripId, date);
    // Sort by start_time, calculate segments with buffer merging
    // Return: { segments: [{ start, end, type: 'shared'|'buffer'|'off' }] }
}
```

**Step 2: Add route**
```typescript
@Get('share-timeline')
getShareTimeline(@Param('tripId') tripId: string, @Query('date') date: string) {
    return this.schedulesService.getShareTimeline(tripId, date);
}
```

**Step 3: Commit**

---

### Task 12: Flutter — ShareTimelineBar Widget (영역 C)

**Files:**
- Create: `safetrip-mobile/lib/widgets/schedule/share_timeline_bar.dart`

**Step 1: Create the 24-hour timeline bar**

Renders a horizontal bar showing:
- Dark green segments: scheduled sharing time
- Light green segments: buffer time (±15min)
- Gray segments: not sharing
- Tap to scroll to time's schedule card

**Step 2: Commit**

---

### Task 13: Backend — AI Schedule Suggestion

**Files:**
- Create: `safetrip-server-api/src/modules/schedules/ai-suggest.service.ts`

**Step 1: Create AI suggestion service**

Uses Claude API to generate schedule suggestions based on destination and trip dates.

**Step 2: Add route**
```typescript
@Post('ai-suggest')
aiSuggest(@Param('tripId') tripId: string, @Body() body: { prompt?: string }) {
    return this.aiSuggestService.suggest(tripId, body.prompt);
}
```

**Step 3: Commit**

---

### Task 14: Backend — Schedule Export (.ics / PDF)

**Files:**
- Add to: `safetrip-server-api/src/modules/schedules/schedules.service.ts`

**Step 1: Add export methods**

```typescript
async exportICS(tripId: string): Promise<string> { /* .ics format */ }
async exportPDF(tripId: string): Promise<Buffer> { /* PDF generation */ }
```

**Step 2: Add routes**
```typescript
@Get('export/ics') exportIcs(...)
@Get('export/pdf') exportPdf(...)
```

**Step 3: Commit**

---

### Task 15: Flutter — AI Suggestion & Export UI

**Files:**
- Create: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/ai_schedule_modal.dart`

**Step 1: Create AI suggestion modal**

Input: destination prompt → Shows generated schedule list → "일괄 추가" button

**Step 2: Add export buttons to schedule tab action menu**

**Step 3: Commit**

---

## Phase 3: P3 — Social Features

### Task 16: Backend — Comments & Reactions

**Files:**
- Create: `safetrip-server-api/sql/12-schema-schedule-social.sql`
- Create: `safetrip-server-api/src/entities/schedule-comment.entity.ts`
- Create: `safetrip-server-api/src/entities/schedule-reaction.entity.ts`

**Step 1: Migration**
```sql
CREATE TABLE tb_schedule_comment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID NOT NULL,
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE tb_schedule_reaction (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID NOT NULL,
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, user_id, emoji)
);
```

**Step 2: Entities + API endpoints**

```typescript
// GET /trips/:tripId/schedules/:scheduleId/comments
// POST /trips/:tripId/schedules/:scheduleId/comments
// DELETE /trips/:tripId/schedules/:scheduleId/comments/:commentId
// POST /trips/:tripId/schedules/:scheduleId/reactions { emoji }
// DELETE /trips/:tripId/schedules/:scheduleId/reactions/:emoji
```

**Step 3: Commit**

---

### Task 17: Backend — Voting System

**Files:**
- Create: `safetrip-server-api/sql/13-schema-schedule-voting.sql`
- Create: `safetrip-server-api/src/entities/schedule-vote.entity.ts`

**Step 1: Migration**
```sql
CREATE TABLE tb_schedule_vote (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES tb_trip(trip_id),
    title VARCHAR(200) NOT NULL,
    created_by VARCHAR(128) REFERENCES tb_user(user_id),
    status VARCHAR(20) DEFAULT 'open', -- open | closed
    deadline TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tb_schedule_vote_option (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vote_id UUID NOT NULL REFERENCES tb_schedule_vote(id),
    label VARCHAR(200) NOT NULL,
    schedule_data JSONB -- 일정 후보 데이터
);

CREATE TABLE tb_schedule_vote_response (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vote_id UUID NOT NULL REFERENCES tb_schedule_vote(id),
    option_id UUID NOT NULL REFERENCES tb_schedule_vote_option(id),
    user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(vote_id, user_id)
);
```

**Step 2: API endpoints**
```typescript
// POST /trips/:tripId/votes
// GET /trips/:tripId/votes
// POST /trips/:tripId/votes/:voteId/respond { optionId }
// PATCH /trips/:tripId/votes/:voteId/close
```

**Step 3: Commit**

---

### Task 18: Backend — Weather Integration

**Files:**
- Create: `safetrip-server-api/src/modules/schedules/weather.service.ts`

**Step 1: Create weather service**

Fetches weather from OpenWeatherMap API using schedule location + date.

```typescript
async getWeather(lat: number, lng: number, date: string): Promise<WeatherInfo> {
    // Call OpenWeatherMap forecast API
    // Return: { temp, description, icon, humidity }
}
```

**Step 2: Add route**
```typescript
@Get(':scheduleId/weather')
getWeather(@Param('scheduleId') scheduleId: string) { }
```

**Step 3: Commit**

---

### Task 19: Backend — Schedule Templates

**Files:**
- Create: `safetrip-server-api/sql/14-schema-schedule-templates.sql`

**Step 1: Migration**
```sql
CREATE TABLE tb_schedule_template (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    category VARCHAR(50), -- 'japan_tokyo' | 'europe_paris' etc.
    items JSONB NOT NULL, -- 일정 아이템 배열
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Step 2: API endpoints**
```typescript
// GET /schedule-templates?category=japan_tokyo
// POST /trips/:tripId/schedules/from-template { templateId }
```

**Step 3: Commit**

---

### Task 20: Flutter — Reactions & Comments UI

**Files:**
- Create: `safetrip-mobile/lib/widgets/schedule/schedule_reactions.dart`
- Create: `safetrip-mobile/lib/widgets/schedule/schedule_comments.dart`

**Step 1: Create reaction bar**

Shows emoji counts below schedule card. Tap to toggle own reaction.
Available emojis: 👍 ❤️ 😊 🎉 👏

**Step 2: Create comments section**

Expandable comment list below card. Text input for new comments.

**Step 3: Integrate into ScheduleCard**

**Step 4: Commit**

---

### Task 21: Flutter — Vote Card Widget

**Files:**
- Create: `safetrip-mobile/lib/widgets/schedule/vote_card.dart`

**Step 1: Create vote card**

Shows vote title, options with progress bars, vote button, deadline countdown.
Captain can close vote and auto-create winning schedule.

**Step 2: Commit**

---

### Task 22: Flutter — Weather Display & Templates

**Files:**
- Modify: `safetrip-mobile/lib/widgets/schedule/schedule_card.dart` (add weather icon)
- Create: `safetrip-mobile/lib/screens/main/bottom_sheets/modals/template_select_modal.dart`

**Step 1: Add weather info to ScheduleCard**

Small weather icon + temp in top-right corner of card.

**Step 2: Create template selection modal**

Grid of template categories → List of templates → Preview → "적용" button.

**Step 3: Commit**

---

### Task 23: Flutter — Trip Progress Bar

**Files:**
- Create: `safetrip-mobile/lib/widgets/schedule/trip_progress_bar.dart`

**Step 1: Create progress bar widget**

Shows: "여행 진행률 65% (13/20 일정 완료)"
Linear progress bar with teal fill.
Displayed at the bottom of the schedule tab in `active` trip status.

**Step 2: Integrate into bottom_sheet_1_trip.dart**

**Step 3: Commit**

---

## Verification Rounds

### Round 1: After Phase 1 (Tasks 1–10)

```bash
# Backend
cd safetrip-server-api && npm run build
# Verify no compilation errors

# Flutter
cd safetrip-mobile && flutter analyze
# Verify no analysis errors

cd safetrip-mobile && flutter build apk --debug
# Verify APK builds

# API test
curl -X GET http://localhost:3001/api/v1/trips/{tripId}/schedules?date=2026-03-06 \
  -H "x-test-bypass: true" -H "x-test-user-id: test-user"
# Expected: { success: true, data: [...] }

curl -X POST http://localhost:3001/api/v1/trips/{tripId}/schedules \
  -H "x-test-bypass: true" -H "x-test-user-id: test-user" \
  -H "Content-Type: application/json" \
  -d '{"title":"테스트 일정","scheduleType":"meal","scheduleDate":"2026-03-06","startTime":"2026-03-06T12:00:00Z","endTime":"2026-03-06T13:00:00Z"}'
# Expected: { success: true, data: { travelScheduleId: "..." } }
```

Checklist (§11.2):
- [ ] 날짜 타임라인이 최대 15일만 표시
- [ ] 일정 카드 7종 아이콘 표시
- [ ] 진행 중 일정 파란 테두리 + 상단 고정
- [ ] 크루가 일정 추가 버튼을 볼 수 없는가
- [ ] 캡틴/크루장의 일정 수정/삭제 API 동작
- [ ] 크루의 CUD API 요청 시 403 반환

### Round 2: After Phase 2 (Tasks 11–15)

Checklist:
- [ ] 프라이버시 우선 등급에서 영역 A, C 표시
- [ ] 안전 최우선/표준 등급에서 영역 A, C 미표시
- [ ] 공유 타임라인 바 렌더링 (녹색/연한녹색/회색)
- [ ] 연속 일정 30분 이내 자동 연결 동작
- [ ] AI 일정 제안 API 응답
- [ ] .ics 파일 다운로드

### Round 3: After Phase 3 (Tasks 16–23)

Checklist (전체 §11.2):
- [ ] 이모지 리액션 토글 동작
- [ ] 댓글 CRUD 동작
- [ ] 투표 생성/응답/종료/일정 확정
- [ ] 날씨 정보 표시 (위치 기반)
- [ ] 일정 템플릿 적용
- [ ] 여행 진행률 표시
- [ ] 오프라인 일정 열람 가능
- [ ] 오프라인 수정 후 온라인 동기화
