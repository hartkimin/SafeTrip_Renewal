# Physical Device Testing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Android 실기기에서 SafeTrip 전체 기능(인증→여행→멤버→위치→가디언→SOS→채팅→일정→지오펜스)을 ngrok 환경으로 테스트할 수 있도록 준비

**Architecture:** Flutter 앱은 ngrok 터널을 통해 로컬 PC의 리버스 프록시(port 8888)에 연결. 프록시는 URL 경로 기반으로 Firebase Auth Emulator(9099), RTDB Emulator(9000), Storage Emulator(9199), Backend API(3001)로 라우팅. Flutter `main.dart`에 Firebase Emulator 연결 코드 추가가 핵심 누락 사항.

**Tech Stack:** Flutter 3.42 (master), NestJS 10.4, PostgreSQL 15 (PostGIS), Firebase Emulator Suite, ngrok 3.36

---

### Task 1: Flutter — Firebase Emulator 연결 코드 추가

**Files:**
- Modify: `safetrip-mobile/lib/main.dart`

**Context:**
현재 `main.dart`는 `Firebase.initializeApp()` 후 에뮬레이터 연결 없이 프로덕션 Firebase에 직접 연결함.
`.env`에는 `USE_FIREBASE_EMULATOR`, `FIREBASE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_URL` 등이 정의되어 있으나 Dart 코드에서 읽지 않음.
ngrok 모드에서는 `FIREBASE_AUTH_EMULATOR_URL=http://xxxx.ngrok.io` 형태의 단일 프록시 URL을 사용하고,
로컬 WiFi 모드에서는 `FIREBASE_EMULATOR_HOST=10.0.2.2`와 개별 포트를 사용.

**Step 1: main.dart에 Firebase Emulator 연결 코드 추가**

`main.dart`의 `main()` 함수에서 `Firebase.initializeApp()` 이후, `runApp()` 이전에 다음 코드를 추가:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

// (기존 main 함수 내, Firebase.initializeApp() 이후)

// Firebase Emulator 연결 (개발 환경)
final useEmulator = dotenv.env['USE_FIREBASE_EMULATOR']?.toLowerCase() == 'true';
if (useEmulator) {
  final ngrokUrl = dotenv.env['FIREBASE_AUTH_EMULATOR_URL'] ?? '';

  if (ngrokUrl.isNotEmpty) {
    // ngrok 모드: 단일 프록시 URL (local-proxy.cjs가 경로 기반 라우팅)
    final uri = Uri.parse(ngrokUrl);
    final host = uri.host;
    final port = uri.port != 0 ? uri.port : 80;

    await FirebaseAuth.instance.useAuthEmulator(host, port);
    FirebaseDatabase.instance.useDatabaseEmulator(host, port);
    await FirebaseStorage.instance.useEmulator(host: host, port: port);
    debugPrint('[Firebase] Emulator connected via ngrok: $host:$port');
  } else {
    // 로컬 WiFi/에뮬레이터 모드: 개별 포트
    final emulatorHost = dotenv.env['FIREBASE_EMULATOR_HOST'] ?? '10.0.2.2';

    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseDatabase.instance.useDatabaseEmulator(emulatorHost, 9000);
    await FirebaseStorage.instance.useEmulator(host: emulatorHost, port: 9199);
    debugPrint('[Firebase] Emulator connected: $emulatorHost (local)');
  }
}
```

**Step 2: flutter analyze 실행하여 에러 없음 확인**

Run (Windows): `flutter analyze --no-fatal-infos`
Expected: `No issues found!`

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/main.dart
git commit -m "feat(mobile): add Firebase Emulator connection in main.dart for ngrok/local dev"
```

---

### Task 2: Flutter — 누락 패키지 추가 (qr_flutter, share_plus)

**Files:**
- Modify: `safetrip-mobile/pubspec.yaml`
- Modify: `safetrip-mobile/lib/utils/qr_code_generator.dart`
- Modify: `safetrip-mobile/lib/utils/share_helper.dart`

**Context:**
`qr_code_generator.dart`와 `share_helper.dart`에 TODO로 패키지 추가 후 구현하라고 되어 있음.
현재는 플레이스홀더(Container)와 클립보드 복사로 대체 구현되어 있음.
전체 기능 테스트 시 QR 코드와 공유 기능이 필요.

**Step 1: pubspec.yaml에 패키지 추가**

`pubspec.yaml`의 dependencies 섹션에 추가:
```yaml
  # QR 코드 생성
  qr_flutter: ^4.1.0

  # 시스템 공유 시트
  share_plus: ^10.1.4
```

**Step 2: qr_code_generator.dart 구현**

`generateQrCode()` 메서드의 플레이스홀더 Container를 실제 QrImageView로 교체:
```dart
import 'package:qr_flutter/qr_flutter.dart';

// generateQrCode 내부:
return QrImageView(
  data: data,
  version: QrVersions.auto,
  size: size,
  backgroundColor: Colors.white,
);
```

**Step 3: share_helper.dart 구현**

`share()` 메서드의 클립보드 대체 구현을 실제 Share로 교체:
```dart
import 'package:share_plus/share_plus.dart';

// share() 내부:
await SharePlus.instance.share(ShareParams(text: text, title: subject));
```

**Step 4: flutter pub get + flutter analyze**

Run: `flutter pub get && flutter analyze --no-fatal-infos`
Expected: Dependencies resolved, No issues found

**Step 5: Commit**

```bash
git add safetrip-mobile/pubspec.yaml safetrip-mobile/lib/utils/qr_code_generator.dart safetrip-mobile/lib/utils/share_helper.dart
git commit -m "feat(mobile): add qr_flutter and share_plus packages with implementations"
```

---

### Task 3: ngrok 스크립트 — Backend 시작 명령어 수정

**Files:**
- Modify: `scripts/start-dev-ngrok.sh` (line 264)

**Context:**
현재 `start_backend()` 함수가 `npx tsx watch src/index.ts`를 실행하지만,
실제 NestJS 프로젝트의 entry point는 `src/main.ts`이고, 올바른 명령어는 `npm run start:dev`.
`src/index.ts` 파일이 존재하지 않아 서버 시작 실패.

**Step 1: start-dev-ngrok.sh 264행 수정**

변경 전:
```bash
    npx tsx watch src/index.ts > /tmp/safetrip-backend.log 2>&1 &
```

변경 후:
```bash
    npm run start:dev > /tmp/safetrip-backend.log 2>&1 &
```

**Step 2: start-local.sh에도 같은 문제가 있는지 확인**

`scripts/start-local.sh`에서 백엔드 시작 명령어를 grep하여 동일 문제 여부 확인.
문제가 있으면 동일하게 수정.

**Step 3: Commit**

```bash
git add scripts/start-dev-ngrok.sh
git commit -m "fix(scripts): use npm run start:dev instead of npx tsx for backend startup"
```

---

### Task 4: Android 권한 확인 및 보완

**Files:**
- Check: `safetrip-mobile/android/app/src/main/AndroidManifest.xml`

**Context:**
현재 main AndroidManifest.xml에는 위치 권한이 선언되어 있지 않음.
`flutter_background_geolocation` 플러그인이 자체 manifest에서 위치 권한을 선언하여 빌드 시 merge되지만,
실기기 테스트에서 위치 권한이 제대로 요청되는지 확인 필요.
Android 10+ 에서는 `ACCESS_BACKGROUND_LOCATION`이 별도 권한 요청 필요.

**Step 1: merged manifest에서 권한 확인**

빌드 후 생성되는 merged manifest를 확인하여 위치 권한이 포함되어 있는지 검증:
```bash
# Windows에서:
flutter build apk --debug 2>&1
# 빌드 후 merged manifest 확인:
# android/app/build/intermediates/merged_manifests/debug/AndroidManifest.xml
```

**Step 2: 필요시 main AndroidManifest.xml에 권한 추가**

만약 merged manifest에 위치 권한이 없으면:
```xml
<manifest ...>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.INTERNET" />
    ...
```

**Step 3: Commit (if changes)**

```bash
git add safetrip-mobile/android/app/src/main/AndroidManifest.xml
git commit -m "fix(android): add location permissions to main AndroidManifest"
```

---

### Task 5: 전체 스택 기동 테스트 (로컬)

**Files:** None (실행 검증만)

**Context:**
코드 수정 완료 후, ngrok 없이 로컬에서 모든 서비스가 정상 기동되는지 확인.

**Step 1: PostgreSQL 실행 확인**

```bash
docker ps | grep safetrip-postgres
# Expected: safetrip-postgres-local 컨테이너 Running
```

**Step 2: Firebase Emulator 시작**

```bash
cd /mnt/d/Project/15_SafeTrip_New
firebase emulators:start --only auth,database,storage --import=emulator-data &
# Expected: Auth(:9099), RTDB(:9000), Storage(:9199), UI(:4000) 시작
```

**Step 3: Backend 서버 시작**

```bash
cd safetrip-server-api && npm run start:dev &
# Expected: NestJS 서버 port 3001 시작, health check 통과
curl http://localhost:3001/health
# Expected: {"success":true,"data":{"status":"ok",...}}
```

**Step 4: 서비스 연결 검증**

```bash
# Auth Emulator 연결 확인
curl -s http://localhost:9099/ | head -5

# Backend → DB 연결 확인
curl -s http://localhost:3001/api/v1/countries | head -3
```

---

### Task 6: ngrok 환경 기동 및 실기기 APK 빌드

**Files:** None (실행 단계)

**Prerequisite:** Task 1-4 완료, NGROK_AUTHTOKEN 환경변수 설정됨

**Step 1: ngrok 전체 스택 기동**

```bash
cd /mnt/d/Project/15_SafeTrip_New
export NGROK_AUTHTOKEN=your_token_here  # 이미 설정된 경우 스킵
bash scripts/start-dev-ngrok.sh
```

Expected output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SafeTrip 외부 공유 환경 준비 완료!
  Backend API:        http://xxxx.ngrok.io
  Firebase Auth:      http://xxxx.ngrok.io
  ...
```

**Step 2: .env 업데이트 확인**

```bash
cat safetrip-mobile/.env
# Expected: API_SERVER_URL, FIREBASE_AUTH_EMULATOR_URL 등에 ngrok URL이 설정됨
```

**Step 3: Android 디버그 APK 빌드**

```bash
cd safetrip-mobile
flutter build apk --debug
# Expected: build/app/outputs/flutter-apk/app-debug.apk 생성
```

**Step 4: 실기기에 APK 설치**

USB 연결 후:
```bash
flutter install
# 또는 adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

### Task 7: 실기기 전체 기능 테스트 체크리스트

**Files:** None (수동 테스트)

실기기에서 아래 항목을 순서대로 테스트:

**인증 (Auth)**
- [ ] 전화번호 입력 → SMS OTP 전송 (Emulator UI http://localhost:4000/auth 에서 코드 확인)
- [ ] OTP 입력 → 로그인 성공
- [ ] 프로필 설정 (닉네임, 생년월일)
- [ ] 약관 동의

**여행 생성 (Trip)**
- [ ] 새 여행 생성 (제목, 국가, 날짜)
- [ ] 초대 코드 생성
- [ ] 초대 코드로 여행 미리보기

**멤버 관리 (Members)**
- [ ] 초대 코드 공유 (share_plus 동작)
- [ ] QR 코드 표시 (qr_flutter 동작)
- [ ] 멤버 목록 조회
- [ ] 리더십 이전

**위치 공유 (Location)**
- [ ] 위치 권한 요청 → 허용
- [ ] 백그라운드 위치 추적 시작
- [ ] 지도에 현재 위치 표시
- [ ] 위치 공유 설정 변경

**가디언 (Guardian)**
- [ ] 가디언 추가 (전화번호)
- [ ] 가디언 링크 수락/거절
- [ ] 가디언 위치 요청

**SOS**
- [ ] SOS 버튼 → 긴급 알림 전송
- [ ] SOS 취소

**일정 (Schedule)**
- [ ] 일정 추가 (장소, 시간)
- [ ] 일정 수정/삭제

**지오펜스 (Geofence)**
- [ ] 지오펜스 생성 (반경 설정)
- [ ] 지오펜스 진입/이탈 알림

**설정 (Settings)**
- [ ] 프로필 수정
- [ ] 알림 설정
- [ ] 로그아웃
