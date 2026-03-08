# Trip Creation Bug Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 6 bugs causing trip creation to succeed on API but trip card not showing on main screen.

**Architecture:** Backend SQL migration adds missing column + view, service gets transaction + fallback. Frontend gets error feedback + proper provider wiring.

**Tech Stack:** NestJS/TypeORM (backend), Flutter/Riverpod (frontend), PostgreSQL

---

### Task 1: DB Migration — Add `created_by` column + `tb_trip_card_view` view

**Files:**
- Modify: `safetrip-server-api/sql/20-migration-schema-sync.sql:278-332`

**Step 1: Add `created_by` to `tb_group` in migration section 19**

Replace lines 278-280:

```sql
-- ============================================================================
-- 19. tb_group 누락 컬럼
-- ============================================================================
ALTER TABLE tb_group ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
```

With:

```sql
-- ============================================================================
-- 19. tb_group 누락 컬럼
-- ============================================================================
ALTER TABLE tb_group ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE tb_group ADD COLUMN IF NOT EXISTS created_by VARCHAR(128);
```

**Step 2: Replace SKIP comment with actual view creation (section 26)**

Replace lines 327-330:

```sql
-- ============================================================================
-- 26. 17-view-trip-card.sql 뷰 (IF NOT EXISTS로 안전하게)
-- ============================================================================
-- 뷰는 위에서 만든 테이블이 있어야 하므로 여기서 SKIP
```

With:

```sql
-- ============================================================================
-- 26. tb_trip_card_view 뷰 생성
-- ============================================================================
CREATE OR REPLACE VIEW tb_trip_card_view AS
SELECT
    t.trip_id,
    t.trip_name,
    t.status,
    t.start_date,
    t.end_date,
    t.end_date - t.start_date                          AS trip_days,
    t.privacy_level,
    t.sharing_mode,
    t.schedule_type,
    t.country_code,
    t.country_name,
    t.destination_city,
    t.has_minor_members,
    t.reactivated_at,
    t.reactivation_count,
    t.group_id,
    t.updated_at,
    CASE
        WHEN t.status = 'active'    THEN 0
        WHEN t.status = 'planning'  THEN (t.start_date - CURRENT_DATE)
        ELSE NULL
    END                                                 AS d_day,
    CASE
        WHEN t.status = 'active'
            THEN (CURRENT_DATE - t.start_date + 1)
        ELSE NULL
    END                                                 AS current_day,
    (
        SELECT COUNT(*)
        FROM tb_group_member gm
        WHERE gm.trip_id = t.trip_id
          AND gm.status = 'active'
          AND gm.member_role IN ('captain', 'crew_chief', 'crew')
    )                                                   AS member_count,
    CASE
        WHEN t.status = 'completed'
         AND t.reactivation_count = 0
         AND t.updated_at > NOW() - INTERVAL '24 hours'
            THEN TRUE
        ELSE FALSE
    END                                                 AS can_reactivate
FROM tb_trip t
WHERE t.deleted_at IS NULL;
```

**Step 3: Commit**

```
fix(db): add tb_group.created_by column and tb_trip_card_view view to migration
```

---

### Task 2: Backend — Transaction wrap for trip creation

**Files:**
- Modify: `safetrip-server-api/src/modules/trips/trips.service.ts:39-139`

**Step 1: Replace the `create()` method body with transaction-wrapped version**

Replace the entire method body (lines 49-138) — keep the method signature and B2B validation (lines 50-76), then wrap the DB operations in a transaction:

```typescript
    async create(userId: string, data: {
        title: string;
        country_code: string;
        country_name?: string;
        trip_type: string;
        start_date: string;
        end_date: string;
        sharing_mode?: string;
        privacy_level?: string;
        b2b_contract_id?: string;
    }) {
        // 1) 15일 제한 체크
        const start = new Date(data.start_date);
        const end = new Date(data.end_date);
        const diffDays = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
        if (diffDays > 15 || diffDays < 0) {
            throw new BadRequestException('Trip duration must be between 1 and 15 days');
        }

        // 2) B2B 쿼터 및 제약 사항 확인
        let finalPrivacyLevel = data.privacy_level || 'standard';
        let finalSharingMode = data.sharing_mode || 'voluntary';

        if (data.b2b_contract_id) {
            const hasQuota = await this.b2bService.checkTripQuota(data.b2b_contract_id);
            if (!hasQuota) {
                throw new BadRequestException('B2B Trip quota exceeded for this contract');
            }
            const contract = await this.dataSource.query('SELECT forced_privacy_level, forced_sharing_mode FROM tb_b2b_contract WHERE contract_id = $1', [data.b2b_contract_id]);
            if (contract && contract.length > 0) {
                if (contract[0].forced_privacy_level) finalPrivacyLevel = contract[0].forced_privacy_level;
                if (contract[0].forced_sharing_mode) finalSharingMode = contract[0].forced_sharing_mode;
            }
        }

        const inviteCode = Math.random().toString(36).substring(2, 8).toUpperCase();

        // 트랜잭션으로 그룹+여행+멤버+채팅방 원자적 생성
        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            // 3) 그룹 생성
            const group = this.groupRepo.create({
                groupName: data.title,
                groupType: data.trip_type,
                createdBy: userId,
                inviteCode,
            });
            const savedGroup = await queryRunner.manager.save(group);

            // 4) 여행 생성
            const trip = this.tripRepo.create({
                groupId: savedGroup.groupId,
                tripName: data.title,
                destination: data.country_name || data.country_code,
                destinationCountryCode: data.country_code,
                countryCode: data.country_code,
                countryName: data.country_name || null,
                tripType: data.trip_type || null,
                startDate: start,
                endDate: end,
                sharingMode: finalSharingMode,
                privacyLevel: finalPrivacyLevel,
                b2bContractId: data.b2b_contract_id || null,
                createdBy: userId,
            });
            const savedTrip = await queryRunner.manager.save(trip);

            // B2B인 경우 카운트 증가
            if (data.b2b_contract_id) {
                await this.b2bService.incrementTripCount(data.b2b_contract_id);
            }

            // 5) captain 등록
            const member = this.memberRepo.create({
                groupId: savedGroup.groupId,
                userId,
                tripId: savedTrip.tripId,
                memberRole: 'captain',
                isAdmin: true,
                canEditSchedule: true,
                canManageMembers: true,
                canSendNotifications: true,
                canViewLocation: true,
                canManageGeofences: true,
            });
            await queryRunner.manager.save(member);

            // 6) §10.2: 미성년자 보호 로직 적용
            await this.checkAndEnforceMinorProtection(savedTrip.tripId, userId);

            // 7) 채팅방 자동 생성
            const chatRoom = this.chatRoomRepo.create({
                tripId: savedTrip.tripId,
                roomType: 'group',
                roomName: data.title,
            });
            await queryRunner.manager.save(chatRoom);

            await queryRunner.commitTransaction();

            // Refresh trip data to include updated privacy_level if changed
            const finalTrip = await this.tripRepo.findOne({ where: { tripId: savedTrip.tripId } });
            return { ...finalTrip, inviteCode };
        } catch (err) {
            await queryRunner.rollbackTransaction();
            throw err;
        } finally {
            await queryRunner.release();
        }
    }
```

**Step 2: Commit**

```
fix(backend): wrap trip creation in database transaction
```

---

### Task 3: Backend — card-view fallback when view doesn't exist

**Files:**
- Modify: `safetrip-server-api/src/modules/trips/trips.service.ts:486-627`

**Step 1: Wrap the memberTrips query in try-catch with inline fallback**

Replace lines 498-521 (the memberTrips query block):

```typescript
        // 2) 멤버 여행 카드 데이터
        const memberTrips = await this.dataSource.query(`
            SELECT
                v.trip_id, v.trip_name, v.status, v.start_date, v.end_date,
                v.trip_days, v.privacy_level, v.sharing_mode, v.schedule_type,
                v.country_code, v.country_name, v.destination_city,
                v.has_minor_members, v.reactivation_count,
                v.d_day, v.current_day, v.member_count, v.can_reactivate,
                v.group_id, v.reactivated_at, v.updated_at,
                gm.member_role AS user_role,
                gm.is_admin
            FROM tb_trip_card_view v
            JOIN tb_group_member gm ON gm.trip_id = v.trip_id
            WHERE gm.user_id = $1
              AND gm.status = 'active'
              AND gm.member_role IN ('captain', 'crew_chief', 'crew')
            ORDER BY
                CASE v.status
                    WHEN 'active' THEN 1
                    WHEN 'planning' THEN 2
                    WHEN 'completed' THEN 3
                END,
                v.start_date DESC
        `, [userId]);
```

With:

```typescript
        // 2) 멤버 여행 카드 데이터 (tb_trip_card_view fallback 포함)
        let memberTrips: any[] = [];
        try {
            memberTrips = await this.dataSource.query(`
                SELECT
                    v.trip_id, v.trip_name, v.status, v.start_date, v.end_date,
                    v.trip_days, v.privacy_level, v.sharing_mode, v.schedule_type,
                    v.country_code, v.country_name, v.destination_city,
                    v.has_minor_members, v.reactivation_count,
                    v.d_day, v.current_day, v.member_count, v.can_reactivate,
                    v.group_id, v.reactivated_at, v.updated_at,
                    gm.member_role AS user_role,
                    gm.is_admin
                FROM tb_trip_card_view v
                JOIN tb_group_member gm ON gm.trip_id = v.trip_id
                WHERE gm.user_id = $1
                  AND gm.status = 'active'
                  AND gm.member_role IN ('captain', 'crew_chief', 'crew')
                ORDER BY
                    CASE v.status
                        WHEN 'active' THEN 1
                        WHEN 'planning' THEN 2
                        WHEN 'completed' THEN 3
                    END,
                    v.start_date DESC
            `, [userId]);
        } catch (viewErr) {
            console.warn('getCardView: tb_trip_card_view failed, using fallback query:', viewErr.message);
            memberTrips = await this.dataSource.query(`
                SELECT
                    t.trip_id, t.trip_name, t.status,
                    TO_CHAR(t.start_date, 'YYYY-MM-DD') AS start_date,
                    TO_CHAR(t.end_date, 'YYYY-MM-DD') AS end_date,
                    (t.end_date - t.start_date) AS trip_days,
                    t.privacy_level, t.sharing_mode, t.schedule_type,
                    t.country_code, t.country_name, t.destination_city,
                    t.has_minor_members, t.reactivation_count,
                    CASE
                        WHEN t.status = 'active' THEN 0
                        WHEN t.status = 'planning' THEN (t.start_date - CURRENT_DATE)
                        ELSE NULL
                    END AS d_day,
                    CASE
                        WHEN t.status = 'active' THEN (CURRENT_DATE - t.start_date + 1)
                        ELSE NULL
                    END AS current_day,
                    (SELECT COUNT(*) FROM tb_group_member gm2
                     WHERE gm2.trip_id = t.trip_id AND gm2.status = 'active'
                       AND gm2.member_role IN ('captain','crew_chief','crew')) AS member_count,
                    FALSE AS can_reactivate,
                    t.group_id, t.reactivated_at, t.updated_at,
                    gm.member_role AS user_role,
                    gm.is_admin
                FROM tb_trip t
                JOIN tb_group_member gm ON gm.trip_id = t.trip_id
                WHERE gm.user_id = $1
                  AND gm.status = 'active'
                  AND gm.member_role IN ('captain', 'crew_chief', 'crew')
                  AND t.deleted_at IS NULL
                ORDER BY
                    CASE t.status
                        WHEN 'active' THEN 1
                        WHEN 'planning' THEN 2
                        WHEN 'completed' THEN 3
                    END,
                    t.start_date DESC
            `, [userId]);
        }
```

**Step 2: Commit**

```
fix(backend): add fallback query when tb_trip_card_view doesn't exist
```

---

### Task 4: Frontend — Fix `createTrip` error handling in ApiService

**Files:**
- Modify: `safetrip-mobile/lib/services/api_service.dart:213-245`

**Step 1: Change error handling to rethrow instead of swallowing**

Replace lines 213-245:

```dart
  // 여행 생성
  Future<Map<String, dynamic>?> createTrip({
    required String title,
    required String countryCode,
    required String tripType,
    required String startDate,
    required String endDate,
    String? countryName,
    String? privacyLevel,
    String? sharingMode,
  }) async {
    try {
      final data = <String, dynamic>{
        'title': title,
        'country_code': countryCode,
        'trip_type': tripType,
        'start_date': startDate,
        'end_date': endDate,
      };
      if (countryName != null) data['country_name'] = countryName;
      if (privacyLevel != null) data['privacy_level'] = privacyLevel;
      if (sharingMode != null) data['sharing_mode'] = sharingMode;

      final response = await _dio.post('/api/v1/trips', data: data);
      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] createTrip Error: $e');
      return null;
    }
  }
```

With:

```dart
  // 여행 생성
  Future<Map<String, dynamic>?> createTrip({
    required String title,
    required String countryCode,
    required String tripType,
    required String startDate,
    required String endDate,
    String? countryName,
    String? privacyLevel,
    String? sharingMode,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      'country_code': countryCode,
      'trip_type': tripType,
      'start_date': startDate,
      'end_date': endDate,
    };
    if (countryName != null) data['country_name'] = countryName;
    if (privacyLevel != null) data['privacy_level'] = privacyLevel;
    if (sharingMode != null) data['sharing_mode'] = sharingMode;

    final response = await _dio.post('/api/v1/trips', data: data);
    if (response.data['success'] == true && response.data['data'] != null) {
      return response.data['data'] as Map<String, dynamic>;
    }
    return null;
  }
```

Key change: removed the try-catch — Dio errors now propagate to the caller where they can be displayed to the user.

**Step 2: Commit**

```
fix(app): let createTrip errors propagate to caller for user feedback
```

---

### Task 5: Frontend — Fix trip creation screen (tripType, await, error feedback, tripProvider)

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_create.dart:42-79`

**Step 1: Replace the `_onCreate()` method**

Replace lines 42-79:

```dart
  Future<void> _onCreate() async {
    if (!_canProceed) return;

    // §08: 클라이언트 측 15일 초과 검증
    final duration = _endDate!.difference(_startDate!).inDays;
    if (duration > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행 기간은 최대 15일을 초과할 수 없습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final trip = await _apiService.createTrip(
        title: _nameController.text.trim(),
        countryCode: _selectedCountryCode!,
        tripType: 'leisure',
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        countryName: _selectedCountryName,
      );

      if (trip != null && mounted) {
        // group_id 저장 및 AuthNotifier 활성 여행 갱신 → 라우터 redirect가 main으로 이동
        final groupId = trip['groupId'] as String?;
        if (groupId != null) {
          await widget.authNotifier.setActiveTrip(groupId);
        }
        ref.read(tripCardProvider.notifier).fetchCardView();
        if (mounted) context.go(RoutePaths.main);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('여행 생성에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
```

With:

```dart
  Future<void> _onCreate() async {
    if (!_canProceed) return;

    // §08: 클라이언트 측 15일 초과 검증
    final duration = _endDate!.difference(_startDate!).inDays;
    if (duration > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행 기간은 최대 15일을 초과할 수 없습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final trip = await _apiService.createTrip(
        title: _nameController.text.trim(),
        countryCode: _selectedCountryCode!,
        tripType: 'group',
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        countryName: _selectedCountryName,
      );

      if (trip != null && mounted) {
        final groupId = trip['groupId'] as String?;
        if (groupId != null) {
          await widget.authNotifier.setActiveTrip(groupId);
        }

        // tripProvider 초기화 — 메인 화면 바텀시트에서 사용
        ref.read(tripProvider.notifier).setCurrentTripDetails(
          tripName: trip['tripName'] as String? ?? _nameController.text.trim(),
          tripStatus: trip['status'] as String? ?? 'planning',
          userRole: 'captain',
          tripStartDate: _startDate,
          tripEndDate: _endDate,
          countryCode: _selectedCountryCode,
          countryName: _selectedCountryName,
        );

        await ref.read(tripCardProvider.notifier).fetchCardView();
        if (mounted) context.go(RoutePaths.main);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('여행 생성에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } catch (e) {
      debugPrint('[TripCreate] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('여행 생성에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
```

**Step 2: Add import for tripProvider if not present**

Check line 1-13 for existing imports. Add if missing:

```dart
import '../../features/trip/providers/trip_provider.dart';
```

**Step 3: Commit**

```
fix(app): fix trip creation — correct tripType, await fetchCardView, add error feedback, wire tripProvider
```

---

### Task 6: Verification — Run migration and test end-to-end

**Step 1: Run the migration against the database**

```bash
cd safetrip-server-api
# If using local PostgreSQL:
psql -U postgres -d safetrip -f sql/20-migration-schema-sync.sql
# Or via the server's migration runner if available
```

Expected: `ALTER TABLE`, `CREATE OR REPLACE VIEW` succeed without errors.

**Step 2: Restart the backend server**

```bash
cd safetrip-server-api && npm run dev
```

**Step 3: Verify card-view endpoint directly**

```bash
# Get a Firebase ID token from the app or emulator, then:
curl -H "Authorization: Bearer <token>" http://localhost:3001/api/v1/trips/card-view
```

Expected: `{ "success": true, "data": { "memberTrips": [...], "guardianTrips": [...] } }`

**Step 4: Test trip creation from the app**

1. Open app → navigate to trip creation screen
2. Fill in trip name, country, dates
3. Tap "여행 생성하기"
4. Verify: navigates to main screen WITH trip card visible
5. Verify: trip card shows correct name, dates, status="planning"

**Step 5: Final commit with all changes**

```
fix: resolve trip creation + card display — migration, transaction, error handling
```
