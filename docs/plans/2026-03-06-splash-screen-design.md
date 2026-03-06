# Splash Screen Implementation Design

**Date**: 2026-03-06
**Spec**: DOC-T3-SPL-028 (28_T3_스플래시_화면_원칙.md)
**Approach**: A — Retrofit existing structure

## Architecture

Extend current `InitialScreen` + `AuthNotifier` + GoRouter redirect pattern with:
1. `SplashInitializer` — orchestrates 5 parallel background tasks
2. `VersionCheckService` — app version check + cache + critical/optional determination
3. 3-phase loading UI with timer management
4. Backend `GET /api/v1/version/check` endpoint

## Flow

```
App Launch → SplashScreen
  ├─ SplashInitializer (5 parallel tasks)
  │   ├─ [Required] Firebase silentRefresh
  │   ├─ [Required] Version Check
  │   ├─ [Optional] FCM token refresh
  │   ├─ [Optional] Cache integrity check
  │   └─ [Conditional] Deep link parsing (existing)
  ├─ Timer (min 1s, max 3s)
  ├─ 3-phase loading UI
  └─ Result → AuthNotifier → GoRouter redirect
      ├─ Critical update → ForceUpdateDialog
      ├─ Route A (new user) → /onboarding/welcome
      ├─ Route B (returning) → /main
      └─ Route C (deep link) → target screen
```

## Files

| File | Type | Description |
|------|------|-------------|
| `lib/services/splash_initializer.dart` | New | 5-task parallel orchestrator |
| `lib/services/version_check_service.dart` | New | Version check + cache |
| `lib/screens/screen_splash.dart` | Modify | 3-phase UI, timers, retry |
| `lib/router/auth_notifier.dart` | Modify | Init results, force update state |
| `lib/router/app_router.dart` | Modify | Force update route |
| `lib/widgets/force_update_dialog.dart` | New | Blocking update dialog |
| `lib/widgets/offline_banner.dart` | New | Offline banner |
| Backend `version.controller.ts` | New | GET /api/v1/version/check |
| Backend `version.service.ts` | New | Version comparison logic |

## 3-Phase Loading UI

- Phase 1 (0-1s): Logo fade-in 0.3s → Slogan fade-in after 0.2s delay
- Phase 2 (1-3s): Bottom indeterminate progress bar fade-in
- Phase 3 (3s+): Slogan → "연결 중..." text + "다시 시도" retry button

## Backend API

```
GET /api/v1/version/check?platform=android&version=1.1.0

Response: {
  min_version, recommended_version, update_type, store_url
}
```

## Error Handling

- Network error → offline banner → local token-based routing
- Firebase expired → delete local token → Route A
- Version check failed → use cache, skip if no cache
- 3s timeout → retry UI, extra message after 3 consecutive failures
