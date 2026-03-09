# Safety Guide Tab Phase 1 — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the Safety Guide tab with 6 sub-tabs, MOFA API integration, layered caching, one-touch emergency calls, and context-based country selection.

**Architecture:** Guides module (NestJS) wraps MOFA service as facade with PostgreSQL 24h cache. Flutter uses Riverpod + SQLite for offline cache. Bottom sheet with TabBar for 6 sub-tabs.

**Tech Stack:** NestJS/TypeORM (backend), Flutter/Riverpod/sqflite (mobile), PostgreSQL + SQLite (caching)

---

## Task 1: DB Migration — Safety Guide Tables

**Files:**
- Create: `safetrip-server-api/sql/16-schema-safety-guide.sql`

**Step 1: Create migration file**

```sql
-- 16-schema-safety-guide.sql
-- DOC-T3-SFG-021 §7 — 안전가이드 DB 스키마

-- §7.1 MOFA API 응답 캐시 테이블
CREATE TABLE IF NOT EXISTS tb_safety_guide_cache (
    id              BIGSERIAL PRIMARY KEY,
    country_code    VARCHAR(3)   NOT NULL,
    data_type       VARCHAR(30)  NOT NULL,
    content         JSONB        NOT NULL,
    fetched_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_cache_country_type UNIQUE (country_code, data_type)
);

CREATE INDEX IF NOT EXISTS idx_safety_cache_country ON tb_safety_guide_cache (country_code);
CREATE INDEX IF NOT EXISTS idx_safety_cache_expires ON tb_safety_guide_cache (expires_at);

-- §7.2 긴급연락처 로컬 저장 테이블
CREATE TABLE IF NOT EXISTS tb_emergency_contact (
    id              BIGSERIAL PRIMARY KEY,
    country_code    VARCHAR(3)   NOT NULL,
    contact_type    VARCHAR(20)  NOT NULL,
    phone_number    VARCHAR(30)  NOT NULL,
    description_ko  VARCHAR(100),
    is_24h          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emergency_contact_country ON tb_emergency_contact (country_code);

-- 시드: 영사콜센터 (하드코딩 필수 레코드)
INSERT INTO tb_emergency_contact (country_code, contact_type, phone_number, description_ko, is_24h)
VALUES ('ALL', 'consulate_call_center', '+82-2-3210-0404', '영사콜센터 (24시간)', TRUE)
ON CONFLICT DO NOTHING;
```

**Step 2: Run migration**

```bash
cd safetrip-server-api && psql $DATABASE_URL -f sql/16-schema-safety-guide.sql
```

**Step 3: Commit**

```bash
git add safetrip-server-api/sql/16-schema-safety-guide.sql
git commit -m "feat(db): add tb_safety_guide_cache and tb_emergency_contact tables (§7)"
```

---

## Task 2: Backend Entities

**Files:**
- Create: `safetrip-server-api/src/entities/safety-guide-cache.entity.ts`
- Create: `safetrip-server-api/src/entities/emergency-contact.entity.ts`

**Step 1: Create SafetyGuideCache entity**

```typescript
// safety-guide-cache.entity.ts
import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

/**
 * TB_SAFETY_GUIDE_CACHE — MOFA API 응답 캐시 (§7.1)
 * TTL: 24시간. country_code + data_type UNIQUE.
 */
@Entity('tb_safety_guide_cache')
export class SafetyGuideCache {
    @PrimaryGeneratedColumn({ name: 'id', type: 'bigint' })
    id: number;

    @Column({ name: 'country_code', type: 'varchar', length: 3 })
    countryCode: string;

    @Column({ name: 'data_type', type: 'varchar', length: 30 })
    dataType: string;

    @Column({ name: 'content', type: 'jsonb' })
    content: any;

    @Column({ name: 'fetched_at', type: 'timestamptz' })
    fetchedAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz' })
    expiresAt: Date;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', default: () => 'now()' })
    updatedAt: Date;
}
```

**Step 2: Create EmergencyContact entity**

```typescript
// emergency-contact.entity.ts
import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

/**
 * TB_EMERGENCY_CONTACT — 긴급연락처 (§7.2)
 * 캐시 만료와 무관하게 영구 유지되는 핵심 안전 정보.
 */
@Entity('tb_emergency_contact')
export class EmergencyContact {
    @PrimaryGeneratedColumn({ name: 'id', type: 'bigint' })
    id: number;

    @Column({ name: 'country_code', type: 'varchar', length: 3 })
    countryCode: string;

    @Column({ name: 'contact_type', type: 'varchar', length: 20 })
    contactType: string; // 'police'|'fire'|'ambulance'|'embassy'|'consulate_call_center'

    @Column({ name: 'phone_number', type: 'varchar', length: 30 })
    phoneNumber: string;

    @Column({ name: 'description_ko', type: 'varchar', length: 100, nullable: true })
    descriptionKo: string | null;

    @Column({ name: 'is_24h', type: 'boolean', default: true })
    is24h: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', default: () => 'now()' })
    updatedAt: Date;
}
```

**Step 3: Commit**

```bash
git add safetrip-server-api/src/entities/safety-guide-cache.entity.ts safetrip-server-api/src/entities/emergency-contact.entity.ts
git commit -m "feat(entities): add SafetyGuideCache and EmergencyContact entities (§7)"
```

---

## Task 3: Backend Guides Service — Cache + MOFA Integration

**Files:**
- Modify: `safetrip-server-api/src/modules/guides/guides.service.ts`

**Step 1: Rewrite guides.service.ts with cache logic**

Replace existing content with expanded service that:
- Injects `Repository<SafetyGuideCache>`, `Repository<EmergencyContact>`, and `MofaService`
- Implements `getGuideData(countryCode, dataType)` with cache-first strategy:
  1. Check `tb_safety_guide_cache` for valid (non-expired) entry
  2. If hit → return cached content with `meta.cached=true`
  3. If miss → call MofaService → UPSERT cache → return with `meta.cached=false`
  4. If MOFA fails → return stale cache with `meta.stale=true`
  5. If no cache at all → return hardcoded fallback (영사콜센터)
- Implements individual tab methods: `getOverview()`, `getSafety()`, `getMedical()`, `getEntry()`, `getEmergency()`, `getLocalLife()`, `getAll()`
- Maps MOFA service responses to each tab's data structure

Key method signature:
```typescript
async getGuideData(countryCode: string, dataType: string): Promise<{ data: any; meta: CacheMeta }>
```

CacheMeta type:
```typescript
interface CacheMeta {
    countryCode: string;
    cached: boolean;
    stale: boolean;
    fetchedAt: string | null;
    expiresAt: string | null;
}
```

**Step 2: Verify server compiles**

```bash
cd safetrip-server-api && npx tsc --noEmit
```

**Step 3: Commit**

```bash
git add safetrip-server-api/src/modules/guides/guides.service.ts
git commit -m "feat(guides): integrate MOFA service with 24h cache strategy (§3.4.2)"
```

---

## Task 4: Backend Guides Controller — 7 Endpoints

**Files:**
- Modify: `safetrip-server-api/src/modules/guides/guides.controller.ts`

**Step 1: Extend controller with 7 endpoints**

Keep existing `search` endpoint. Add/modify:
- `GET /guides/:countryCode` → `getAll()` — 전체 6탭 통합 응답
- `GET /guides/:countryCode/overview` → 개요
- `GET /guides/:countryCode/safety` → 안전
- `GET /guides/:countryCode/medical` → 의료
- `GET /guides/:countryCode/entry` → 입국
- `GET /guides/:countryCode/emergency` → 긴급연락 (keep existing, enhance)
- `GET /guides/:countryCode/local-life` → 현지생활

All endpoints are `@Public()` (S5: 역할 무관 동등 접근). All normalize `countryCode.toUpperCase()`.

**Step 2: Verify compilation**

```bash
cd safetrip-server-api && npx tsc --noEmit
```

**Step 3: Commit**

```bash
git add safetrip-server-api/src/modules/guides/guides.controller.ts
git commit -m "feat(guides): add 7 safety guide endpoints (§3.2)"
```

---

## Task 5: Backend Module Wiring

**Files:**
- Modify: `safetrip-server-api/src/modules/guides/guides.module.ts`

**Step 1: Update module to import MOFA and register new entities**

```typescript
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuidesController } from './guides.controller';
import { GuidesService } from './guides.service';
import { Country } from '../../entities/country.entity';
import { SafetyGuideCache } from '../../entities/safety-guide-cache.entity';
import { EmergencyContact } from '../../entities/emergency-contact.entity';
import { MofaModule } from '../mofa/mofa.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([Country, SafetyGuideCache, EmergencyContact]),
        MofaModule,
    ],
    controllers: [GuidesController],
    providers: [GuidesService],
    exports: [GuidesService],
})
export class GuidesModule { }
```

**Step 2: Start server and test endpoints**

```bash
cd safetrip-server-api && npm run dev
# In another terminal:
curl http://localhost:3001/api/v1/guides/JP/emergency | jq .
curl http://localhost:3001/api/v1/guides/JP | jq .meta
```

Expected: Response with `data` and `meta` fields. First call: `meta.cached=false`. Second call: `meta.cached=true`.

**Step 3: Commit**

```bash
git add safetrip-server-api/src/modules/guides/guides.module.ts
git commit -m "feat(guides): wire MofaModule + cache entities into GuidesModule"
```

---

## Task 6: Mobile Models (6 tab data classes)

**Files:**
- Create: `safetrip-mobile/lib/features/safety_guide/models/guide_data.dart`

**Step 1: Create unified model file**

Create all 6 tab models + meta in one file. Each model has `fromJson` factory. Key models:

- `GuideOverview` — country flag, name, alert badge, capital, currency, language, timezone
- `GuideSafety` — travel alert level (1-4), security status, recent notices (max 5), regional alerts
- `GuideMedical` — hospitals, insurance guide, pharmacies, emergency guide
- `GuideEntry` — visa requirements, documents, customs, passport validity
- `GuideEmergency` — list of `EmergencyContactItem` (type, phone, description, is24h)
- `GuideLocalLife` — transport, SIM, tips culture, voltage, cost reference, cultural notes
- `GuideMeta` — cached, stale, fetchedAt, expiresAt
- `SafetyGuideData` — wraps all 6 tabs + meta

All use snake_case JSON keys matching backend response.

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/safety_guide/models/
git commit -m "feat(flutter): add SafetyGuide data models (§3.2)"
```

---

## Task 7: Mobile API Service

**Files:**
- Modify: `safetrip-mobile/lib/services/api_service.dart` (add methods)

**Step 1: Add safety guide API methods to ApiService**

Add these methods following existing patterns (try/catch, debugPrint, return null on error):

```dart
/// GET /api/v1/guides/:countryCode — 전체 6탭 통합 (§3.2)
Future<Map<String, dynamic>?> getSafetyGuideAll(String countryCode) async { ... }

/// GET /api/v1/guides/:countryCode/overview
Future<Map<String, dynamic>?> getSafetyGuideOverview(String countryCode) async { ... }

/// GET /api/v1/guides/:countryCode/safety
Future<Map<String, dynamic>?> getSafetyGuideSafety(String countryCode) async { ... }

/// GET /api/v1/guides/:countryCode/medical
Future<Map<String, dynamic>?> getSafetyGuideMedical(String countryCode) async { ... }

/// GET /api/v1/guides/:countryCode/entry
Future<Map<String, dynamic>?> getSafetyGuideEntry(String countryCode) async { ... }

/// GET /api/v1/guides/:countryCode/emergency — 긴급연락처 (§3.2.5)
Future<Map<String, dynamic>?> getSafetyGuideEmergency(String countryCode) async { ... }

/// GET /api/v1/guides/:countryCode/local-life
Future<Map<String, dynamic>?> getSafetyGuideLocalLife(String countryCode) async { ... }
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/services/api_service.dart
git commit -m "feat(flutter): add safety guide API methods to ApiService"
```

---

## Task 8: Mobile SQLite Cache Service

**Files:**
- Create: `safetrip-mobile/lib/features/safety_guide/data/safety_guide_cache_service.dart`

**Step 1: Create SQLite cache service**

Uses `sqflite` (already in pubspec). Creates two tables on init:
- `guide_cache` — mirrors server cache (country_code, data_type, content JSON, expires_at)
- `emergency_contacts` — permanent storage (country_code, contact_type, phone_number, description_ko, is_24h)

Key methods:
```dart
Future<void> initDb()
Future<Map<String, dynamic>?> getCachedGuide(String countryCode, String dataType)
Future<void> cacheGuide(String countryCode, String dataType, Map<String, dynamic> content, DateTime expiresAt)
Future<List<Map<String, dynamic>>> getEmergencyContacts(String countryCode)
Future<void> saveEmergencyContacts(String countryCode, List<Map<String, dynamic>> contacts)
```

Emergency contacts are saved permanently (no TTL). Guide cache respects `expires_at`.

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/safety_guide/data/
git commit -m "feat(flutter): add SQLite cache service for safety guide (§8, S3)"
```

---

## Task 9: Mobile Repository

**Files:**
- Create: `safetrip-mobile/lib/features/safety_guide/data/safety_guide_repository.dart`

**Step 1: Create repository**

Orchestrates API service + cache service. Decision logic:
1. Try API call
2. Success → cache locally → return data
3. Failure → try SQLite cache
4. Cache hit → return with `stale=true`
5. Cache miss → return hardcoded fallback (영사콜센터 only)

```dart
class SafetyGuideRepository {
  final ApiService _api;
  final SafetyGuideCacheService _cache;

  Future<SafetyGuideData> loadAll(String countryCode) async { ... }
  Future<GuideEmergency> loadEmergency(String countryCode) async { ... }
}
```

Emergency contacts are ALWAYS cached on successful fetch (permanent).

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/safety_guide/data/safety_guide_repository.dart
git commit -m "feat(flutter): add SafetyGuideRepository with layered cache (S3)"
```

---

## Task 10: Mobile Providers

**Files:**
- Create: `safetrip-mobile/lib/features/safety_guide/providers/country_context_provider.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/providers/safety_guide_providers.dart`

**Step 1: Create country context provider (§3.3)**

Implements context-based country auto-selection:
1. Active trip → `trip.country_code`
2. Guardian → linked member's trip destination
3. GPS (if permitted) → reverse geocoding
4. None → free browse mode (null)
5. Manual override → session-scoped

```dart
class CountryContextNotifier extends StateNotifier<CountryContextState> {
  // Watches trip provider for active trip changes
  // Restores context when manual override expires
}
```

**Step 2: Create safety guide providers**

```dart
/// Main guide data provider — watches country context
final safetyGuideProvider = StateNotifierProvider.autoDispose<SafetyGuideNotifier, SafetyGuideState>((ref) { ... });

/// Emergency contacts provider (separate, for fast access per S6)
final emergencyContactsProvider = FutureProvider.autoDispose.family<GuideEmergency, String>((ref, countryCode) { ... });
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/safety_guide/providers/
git commit -m "feat(flutter): add country context + safety guide providers (§3.3, S1)"
```

---

## Task 11: Mobile Widgets

**Files:**
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/widgets/emergency_call_button.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/widgets/travel_alert_badge.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/widgets/offline_banner.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/widgets/stale_data_banner.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/widgets/country_selector_widget.dart`

**Step 1: EmergencyCallButton (§3.2.5)**

```dart
/// 원터치 긴급전화 버튼 (S6: 즉시 행동)
/// - 최소 높이 56dp, 빨간 배경 (#E53935), 흰 전화기 아이콘
/// - 탭 → url_launcher tel: URI → 즉시 다이얼
/// - 전화 권한 미허용 시 permission_handler 다이얼로그
class EmergencyCallButton extends StatelessWidget { ... }
```

**Step 2: TravelAlertBadge**

```dart
/// 여행경보 1~4단계 배지 (§3.2.2)
/// 1=초록(여행유의), 2=노랑(여행자제), 3=주황(출국권고), 4=빨강(여행금지)
class TravelAlertBadge extends StatelessWidget { ... }
```

**Step 3: OfflineBanner + StaleBanner**

Amber banner for offline (§8.3). Yellow banner for stale cache data (§6.1).

**Step 4: CountrySelectorWidget**

Bottom sheet with country search + list. Shows flag emoji + Korean name. Allows manual country change (§3.3).

**Step 5: Commit**

```bash
git add safetrip-mobile/lib/features/safety_guide/presentation/widgets/
git commit -m "feat(flutter): add safety guide widgets (S6 emergency button, alert badge, banners)"
```

---

## Task 12: Mobile Sub-Tab Screens (6 tabs)

**Files:**
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/tabs/overview_tab.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/tabs/safety_tab.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/tabs/medical_tab.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/tabs/entry_tab.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/tabs/emergency_tab.dart`
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/tabs/local_life_tab.dart`

**Step 1: Create all 6 tab widgets**

Each tab is a `ConsumerWidget` that reads from `safetyGuideProvider` and displays the corresponding section data. Uses `AppColors`, `AppTypography`, `AppSpacing` constants.

Key tab specifics:
- **OverviewTab**: Country flag, name, alert badge, capital, currency, language, timezone
- **SafetyTab**: Travel alert level with color, security status, 5 recent notices. **4단계 여행금지 → 빨간 배너 경고** (§6.1)
- **MedicalTab**: Hospital list, insurance checklist, pharmacy info, emergency guide
- **EntryTab**: Visa requirements, document checklist, customs rules, passport validity
- **EmergencyTab**: `EmergencyCallButton` for each contact type (police, fire, embassy, 영사콜센터). **S6: 탭 진입 1초 내 노출**
- **LocalLifeTab**: Transport, SIM, tipping, voltage, cost reference, cultural notes

All tabs show `StaleBanner` when `meta.stale == true`. Show loading skeleton while data loads. Show "정보를 불러오지 못했습니다" per section on error (§6.1).

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/safety_guide/presentation/tabs/
git commit -m "feat(flutter): add 6 safety guide sub-tab screens (§3.2)"
```

---

## Task 13: Mobile Bottom Sheet — Main Container

**Files:**
- Create: `safetrip-mobile/lib/features/safety_guide/presentation/safety_guide_bottom_sheet.dart`

**Step 1: Create main bottom sheet with TabBar**

```dart
/// 안전가이드 바텀시트 (DOC-T3-SFG-021)
/// 드래가블 바텀시트 + 6개 서브탭 (§3.1)
/// S5: 역할 무관 동등 접근 — 권한 체크 없음
class SafetyGuideBottomSheet extends ConsumerStatefulWidget { ... }
```

Structure:
- Top: Country selector header (현재 선택 국가 + 변경 버튼)
- Below: `TabBar` with 6 tabs (개요/안전/의료/입국/긴급연락/현지생활)
- Body: `TabBarView` with 6 tab widgets
- Offline: Shows `OfflineBanner` when `networkStateProvider.isOffline`

Receives `scrollController` from parent (same pattern as existing `BottomSheetGuide`).

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/safety_guide/presentation/safety_guide_bottom_sheet.dart
git commit -m "feat(flutter): add SafetyGuideBottomSheet with 6 sub-tabs (§3.1)"
```

---

## Task 14: Integration — Replace Bottom Sheet 4

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart` (update import + usage)
- Modify: `safetrip-mobile/lib/screens/main/screen_main_guardian.dart` (update import + usage)

**Step 1: Update screen_main.dart**

Replace:
```dart
import 'bottom_sheets/bottom_sheet_4_guide.dart';
```
With:
```dart
import '../../../features/safety_guide/presentation/safety_guide_bottom_sheet.dart';
```

In `_buildBottomSheetContent()`, replace:
```dart
case BottomTab.guide:
  return BottomSheetGuide(
    key: const ValueKey('tab_guide'),
    scrollController: scrollController,
  );
```
With:
```dart
case BottomTab.guide:
  return SafetyGuideBottomSheet(
    key: const ValueKey('tab_guide'),
    scrollController: scrollController,
  );
```

**Step 2: Same changes for screen_main_guardian.dart**

**Step 3: Build and verify**

```bash
cd safetrip-mobile && flutter build apk --debug 2>&1 | tail -5
```

Expected: BUILD SUCCESSFUL

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart safetrip-mobile/lib/screens/main/screen_main_guardian.dart
git commit -m "feat(flutter): integrate SafetyGuideBottomSheet replacing placeholder (§3.1)"
```

---

## Task 15: End-to-End Verification

**Step 1: Start backend**

```bash
cd safetrip-server-api && npm run dev
```

**Step 2: Test API endpoints**

```bash
# 전체 통합 응답
curl -s http://localhost:3001/api/v1/guides/JP | jq '.meta'

# 긴급연락처
curl -s http://localhost:3001/api/v1/guides/JP/emergency | jq '.data'

# 캐시 히트 확인 (2번째 호출)
curl -s http://localhost:3001/api/v1/guides/JP | jq '.meta.cached'
# Expected: true
```

**Step 3: Run Flutter app on emulator**

```bash
cd safetrip-mobile && flutter run
```

Verify:
- [ ] 안전가이드 탭 진입 → 6개 서브탭 표시
- [ ] 개요 탭: 국가 정보 표시
- [ ] 긴급연락 탭: 원터치 전화 버튼 (빨간색, 56dp)
- [ ] 오프라인 모드: 황색 배너 + 캐시 데이터 표시
- [ ] 국가 변경: 우상단 버튼 → 바텀시트 → 국가 선택

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: Safety Guide Tab Phase 1 complete (DOC-T3-SFG-021)"
```

---

## Dependency Graph

```
Task 1 (DB Migration)
  └→ Task 2 (Entities)
       └→ Task 3 (Service)
            └→ Task 4 (Controller)
                 └→ Task 5 (Module Wiring)

Task 6 (Models) ─────────────────┐
Task 7 (API Service) ────────────┤
Task 8 (Cache Service) ──────────┤
  └→ Task 9 (Repository) ────────┤
       └→ Task 10 (Providers) ───┤
            └→ Task 11 (Widgets) ┤
                 └→ Task 12 (Tabs)
                      └→ Task 13 (Bottom Sheet)
                           └→ Task 14 (Integration)
                                └→ Task 15 (E2E Verification)
```

Backend tasks (1-5) and mobile model/service tasks (6-8) can run in parallel.

---

## Architecture Principles Compliance Checklist

| 원칙 | Task | 구현 확인 |
|------|------|----------|
| S1 컨텍스트 우선 | Task 10 | CountryContextProvider 자동 선택 |
| S2 MOFA 신뢰성 | Task 3 | MofaService 단일 소스, 편집 금지 |
| S3 오프라인 안정성 | Task 8,9 | SQLite 2단 캐시, 긴급연락처 영구 저장 |
| S5 역할 무관 동등 | Task 4 | @Public() 데코레이터, 권한 체크 없음 |
| S6 즉시 행동 | Task 11,12 | EmergencyCallButton 56dp, url_launcher |
