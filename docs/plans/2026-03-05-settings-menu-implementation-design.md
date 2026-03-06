# Settings Menu Implementation Design (P0 + P1)

**Date:** 2026-03-05
**Spec:** `Master_docs/15_T3_설정_메뉴_원칙.md` v1.1
**Scope:** P0 (MVP 필수) + P1 (런칭 직전)

---

## Architecture: Hybrid Hub + Incremental

Restructure `screen_settings_main.dart` into a Settings Hub following the spec's 3-layer model (§3.1), then add individual sub-screens under `lib/screens/settings/`.

Layer 3 (역할별 접근 권한) is applied **within each screen** — captains see edit buttons, crew sees read-only, etc.

---

## Settings Hub Structure (§3.2)

```
설정 허브
├── [프로필 카드] → screen_profile_edit.dart
│
├── 앱 설정 (Layer 1 — 항상 표시)
│   ├── 기기 권한 → screen_device_permissions.dart
│   ├── 전역 알림 설정 → screen_notification_settings.dart
│   ├── 개인정보 관리 → screen_privacy_management.dart
│   ├── 로그아웃
│   └── 계정 삭제 → screen_account_delete.dart
│
├── [여행명] 설정 (Layer 2 — 여행 참여 시만)
│   ├── 여행 정보 (읽기 전용, 캡틴만 편집)
│   ├── 프라이버시 등급 → screen_trip_privacy.dart (enhanced)
│   ├── 위치 공유 설정 → screen_trip_privacy.dart
│   └── 가디언 관리 → screen_guardian_management.dart (enhanced)
│
└── 앱 버전
```

---

## New Screens

| File | Spec | Priority |
|---|---|---|
| `screen_profile_edit.dart` | §4.1 | P0 |
| `screen_device_permissions.dart` | §4.1, §4.2 | P0 |
| `screen_notification_settings.dart` | §4.1 | P0 |
| `screen_privacy_management.dart` | §8 | P1 |
| `screen_account_delete.dart` | §7 | P1 |

## Enhanced Existing Screens

### screen_trip_privacy.dart
- Captain-only privacy level change button (§9.2)
- Privacy level change confirmation dialog (§5.3)
- Minor protection: disable change if minors present (§5.3)
- Location pause feature (§5.4) with role/level time limits
- Safety-first: disable visibility scope selection (§10)

### screen_guardian_management.dart
- Real API integration (GET /trips/:id/guardians/me)
- Spec-compliant payment modal (§6.3): ₩1,900/여행 (not 월)
- Paid guardian removal confirmation (§11)
- 5-guardian limit message (§11)

### screen_settings_main.dart
- Layer 1/Layer 2 conditional display
- Load trip info from AppCache for Layer 2
- Profile card → profile edit navigation
- Load role info for Layer 3

---

## Account Deletion Flow (§7)

```
Step 1: 확인 화면 (즉시삭제/익명화/영구보관 안내)
Step 2: FirebaseAuth 재인증
Step 3: API: PUT /users/:id { deletion_requested_at }
Step 4: 로그인 시 철회 배너
```

---

## API Additions

| Method | Endpoint | Purpose |
|---|---|---|
| requestAccountDeletion | PUT /users/:id | deletion_requested_at 설정 |
| cancelAccountDeletion | PUT /users/:id | deletion_requested_at NULL |
| getConsentHistory | GET /users/consent | 동의 현황 조회 |
| updateMarketingConsent | POST /users/consent | 마케팅 동의 변경 |
| getTripById | GET /trips/:id | 여행 정보 조회 |
| getMyGuardians | GET /trips/:id/guardians/me | 내 가디언 목록 |

---

## Offline Handling (§12)

- Layer 1/2 reads: SharedPreferences cache
- Profile edit: local temp save → sync on reconnect
- Privacy change, guardian ops, account deletion: online required → show message
