# Physical Device Testing — Design Document

**Date**: 2026-03-05
**Goal**: Android 실기기에서 SafeTrip 전체 기능을 테스트할 수 있는 환경 구축

---

## Current State Assessment

| Component | Status | Details |
|-----------|--------|---------|
| Backend TypeScript | PASS | 0 errors, NestJS build OK |
| Backend Server | PASS | health check OK on port 3001 |
| PostgreSQL | RUNNING | 55 tables including tb_country |
| Flutter Analysis | PASS | No issues found |
| Flutter SDK | 3.42.0 | Windows (master channel) |
| Java 21 | INSTALLED | Firebase Emulator ready |
| Firebase CLI 15.7 | INSTALLED | |
| ngrok 3.36 | INSTALLED | |
| Docker 28.3 | INSTALLED | |

## Remaining Work

### Phase 1: Flutter Missing Packages
- Add `qr_flutter` and `share_plus` to pubspec.yaml
- These are referenced in utils/ but not in dependencies — causes runtime crash if features used

### Phase 2: ngrok Environment & Full Stack Startup
- Start Firebase Emulator (Auth:9099, RTDB:9000, Storage:9199, UI:4000)
- Start backend server (port 3001)
- Create ngrok tunnels → inject external URLs into Flutter .env
- Use existing `scripts/start-dev-ngrok.sh`

### Phase 3: Android APK Build & Install
- `flutter build apk --debug`
- Install on physical device via USB or APK transfer

### Phase 4: Full Feature Manual Testing
- Onboarding/Auth → Trip Create → Member Invite → Location Sharing → Guardian → SOS → Chat → Schedule → Geofence

## Decisions

- **Target**: Android physical device only (no iOS)
- **Server**: ngrok tunnel from local PC
- **Scope**: Full feature testing (all modules)
- **Tools**: All required tools already installed
