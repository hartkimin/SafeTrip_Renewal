# ngrok 외부 공유 개발 환경 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** WSL2에서 ngrok으로 Firebase Auth/RTDB/Storage Emulator + Backend API를 외부 네트워크에 터널링하여 물리 기기 Flutter 앱이 실제 여행 생성/참여 플로우를 테스트할 수 있게 한다.

**Architecture:** ngrok이 WSL2 내부에서 localhost 서비스 4개(포트 3001, 9099, 9000, 9199)를 각각 HTTPS 터널로 노출한다. 스크립트가 터널 URL을 파싱해 `safetrip-mobile/.env`를 자동 업데이트한다. Flutter 앱은 HTTPS URL로 Firebase Emulator에 연결하므로 `firebase_emulator_config.dart`가 서비스별 개별 URL + port 443을 지원하도록 수정된다.

**Tech Stack:** bash, ngrok v3, Python3(URL 파싱), Flutter/Dart(firebase_auth ^5.0.0, firebase_database ^11.0.0, firebase_storage ^12.0.0)

---

## 사전 지식

### 환경변수 구조 변경

```
# 기존 (단일 호스트 — 로컬 WiFi 전용)
FIREBASE_EMULATOR_HOST=192.168.219.115

# 신규 (ngrok 모드 — 스크립트가 자동 기입)
FIREBASE_AUTH_EMULATOR_URL=https://abc.ngrok-free.app
FIREBASE_RTDB_EMULATOR_URL=https://def.ngrok-free.app
FIREBASE_STORAGE_EMULATOR_URL=https://ghi.ngrok-free.app
API_SERVER_URL=https://jkl.ngrok-free.app
```

**우선순위:** 개별 URL이 있으면 ngrok 모드(HTTPS, port 443). 없으면 `FIREBASE_EMULATOR_HOST` 폴백(기존 동작).

### firebase_auth ^5.0.0 API

```dart
// isEmulatorSecure: true → HTTPS 사용
await FirebaseAuth.instance.useAuthEmulator(host, 443, isEmulatorSecure: true);
// RTDB, Storage는 port 443 지정 시 자동으로 HTTPS 시도
FirebaseDatabase.instance.useDatabaseEmulator(host, 443);
await FirebaseStorage.instance.useStorageEmulator(host, 443);
```

### ngrok API 응답 구조

```json
{
  "tunnels": [
    {
      "name": "safetrip-backend",
      "proto": "https",
      "public_url": "https://abc123.ngrok-free.app",
      "config": { "addr": "http://localhost:3001" }
    }
  ]
}
```

---

## Task 1: firebase_emulator_config.dart — ngrok HTTPS 모드 지원

**Files:**
- Modify: `safetrip-mobile/lib/config/firebase_emulator_config.dart` (전체 교체)

### Step 1: 파일 전체를 아래 내용으로 교체

```dart
/// ============================================================================
/// SafeTrip - Firebase Emulator Configuration
/// 로컬 개발 시 Firebase Emulator에 연결하기 위한 설정
/// ============================================================================
///
/// 사용법: main.dart에서 Firebase.initializeApp() 후 호출
///   await FirebaseEmulatorConfig.connectIfNeeded();
///
/// 환경변수 모드:
///   [ngrok 모드]  FIREBASE_AUTH_EMULATOR_URL / FIREBASE_RTDB_EMULATOR_URL / FIREBASE_STORAGE_EMULATOR_URL
///   [로컬 모드]   FIREBASE_EMULATOR_HOST (기존 동작)
///
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseEmulatorConfig {
  /// Firebase Emulator 연결 (로컬 개발 환경에서만)
  static Future<void> connectIfNeeded() async {
    final useEmulator = dotenv.env['USE_FIREBASE_EMULATOR'] == 'true';

    if (!useEmulator) {
      debugPrint('[Firebase] Production mode - using real Firebase services');
      return;
    }

    // ngrok 모드: 서비스별 개별 HTTPS URL
    final authUrl = dotenv.env['FIREBASE_AUTH_EMULATOR_URL'] ?? '';
    final rtdbUrl = dotenv.env['FIREBASE_RTDB_EMULATOR_URL'] ?? '';
    final storageUrl = dotenv.env['FIREBASE_STORAGE_EMULATOR_URL'] ?? '';

    if (authUrl.isNotEmpty && rtdbUrl.isNotEmpty && storageUrl.isNotEmpty) {
      await _connectNgrokMode(authUrl, rtdbUrl, storageUrl);
    } else {
      await _connectLocalMode();
    }
  }

  /// ngrok 모드: HTTPS 터널 URL로 연결 (port 443, isEmulatorSecure: true)
  static Future<void> _connectNgrokMode(
    String authUrl,
    String rtdbUrl,
    String storageUrl,
  ) async {
    debugPrint('[Firebase] ngrok mode — connecting via HTTPS tunnels');

    try {
      final authHost = _extractHost(authUrl);
      await FirebaseAuth.instance.useAuthEmulator(
        authHost,
        443,
        isEmulatorSecure: true,
      );
      debugPrint('[Firebase] Auth Emulator connected: $authHost:443 (HTTPS)');

      final rtdbHost = _extractHost(rtdbUrl);
      FirebaseDatabase.instance.useDatabaseEmulator(rtdbHost, 443);
      debugPrint('[Firebase] RTDB Emulator connected: $rtdbHost:443 (HTTPS)');

      final storageHost = _extractHost(storageUrl);
      await FirebaseStorage.instance.useStorageEmulator(storageHost, 443);
      debugPrint('[Firebase] Storage Emulator connected: $storageHost:443 (HTTPS)');

      debugPrint('[Firebase] All emulators connected (ngrok mode)');
    } catch (e) {
      debugPrint('[Firebase] ngrok emulator connection failed: $e');
      debugPrint('[Firebase] Falling back to real Firebase services');
    }
  }

  /// 로컬 모드: 단일 호스트 + 고정 포트 (기존 동작)
  static Future<void> _connectLocalMode() async {
    final emulatorHost = _getLocalHost();
    debugPrint('[Firebase] Local mode — connecting to $emulatorHost');

    try {
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      debugPrint('[Firebase] Auth Emulator connected: $emulatorHost:9099');

      FirebaseDatabase.instance.useDatabaseEmulator(emulatorHost, 9000);
      debugPrint('[Firebase] RTDB Emulator connected: $emulatorHost:9000');

      await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
      debugPrint('[Firebase] Storage Emulator connected: $emulatorHost:9199');

      debugPrint('[Firebase] All emulators connected (local mode)');
    } catch (e) {
      debugPrint('[Firebase] Local emulator connection failed: $e');
      debugPrint('[Firebase] Falling back to real Firebase services');
    }
  }

  /// URL에서 호스트명만 추출 (프로토콜·경로 제거)
  /// "https://abc.ngrok-free.app" → "abc.ngrok-free.app"
  static String _extractHost(String url) {
    return url
        .replaceFirst(RegExp(r'^https?://'), '')
        .split('/')[0]
        .split(':')[0]; // 포트가 포함된 경우 제거
  }

  /// 로컬 모드 호스트 결정 (FIREBASE_EMULATOR_HOST > 플랫폼 기본값)
  static String _getLocalHost() {
    final envHost = dotenv.env['FIREBASE_EMULATOR_HOST'];
    if (envHost != null && envHost.isNotEmpty) {
      return envHost;
    }

    if (kIsWeb) return 'localhost';

    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}

    return 'localhost';
  }

  /// 현재 에뮬레이터 사용 중인지 확인
  static bool get isUsingEmulator {
    return dotenv.env['USE_FIREBASE_EMULATOR'] == 'true';
  }

  /// ngrok 모드인지 확인
  static bool get isNgrokMode {
    final authUrl = dotenv.env['FIREBASE_AUTH_EMULATOR_URL'] ?? '';
    return isUsingEmulator && authUrl.isNotEmpty;
  }
}
```

### Step 2: 변경 확인

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
grep -n "FIREBASE_AUTH_EMULATOR_URL\|_connectNgrokMode\|isEmulatorSecure" lib/config/firebase_emulator_config.dart
```
**예상 출력:** 3줄 이상 매치

### Step 3: Commit

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-mobile/lib/config/firebase_emulator_config.dart
git commit -m "feat: firebase_emulator_config — ngrok HTTPS 터널 모드 지원 (서비스별 개별 URL)"
```

---

## Task 2: safetrip-mobile/.env.local — 신규 환경변수 구조 반영

**Files:**
- Modify: `safetrip-mobile/.env.local`

### Step 1: .env.local 업데이트

```
# ============================================================================
# SafeTrip Flutter - Local Development Environment
# ============================================================================
# 사용법:
#   [로컬 WiFi]  cp .env.local .env
#   [ngrok 외부] bash ../scripts/start-dev-ngrok.sh  (자동으로 .env 업데이트)
# ============================================================================

# ── 로컬 WiFi 모드 ──────────────────────────────────────────────────────────
# Android 에뮬레이터:  http://10.0.2.2:3001
# iOS 시뮬레이터:      http://localhost:3001
# 물리 기기 (WiFi):    http://<PC_IP>:3001
API_SERVER_URL=http://10.0.2.2:3001

# Firebase Emulator (로컬 WiFi 모드)
USE_FIREBASE_EMULATOR=true
FIREBASE_EMULATOR_HOST=10.0.2.2

# ── ngrok 모드 (start-dev-ngrok.sh 가 아래 4줄을 자동으로 채워줌) ──────────
# 아래 값들은 ngrok 세션마다 바뀌므로 직접 수정하지 마세요.
FIREBASE_AUTH_EMULATOR_URL=
FIREBASE_RTDB_EMULATOR_URL=
FIREBASE_STORAGE_EMULATOR_URL=

# Kakao SDK (테스트용)
# KAKAO_NATIVE_APP_KEY=your_kakao_native_app_key_here
```

### Step 2: 확인

```bash
cat /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/.env.local | grep -E "FIREBASE_AUTH_EMULATOR_URL|FIREBASE_RTDB_EMULATOR_URL"
```
**예상 출력:** 두 줄 모두 빈 값으로 존재

### Step 3: Commit

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-mobile/.env.local
git commit -m "chore: .env.local — ngrok 모드 환경변수 구조 추가"
```

---

## Task 3: scripts/ngrok.yml — ngrok 터널 설정 파일

**Files:**
- Create: `scripts/ngrok.yml`

### Step 1: 파일 생성

```yaml
# ============================================================================
# SafeTrip ngrok 터널 설정
# ============================================================================
# 사용법: start-dev-ngrok.sh 가 자동으로 사용합니다.
# 수동 실행: ngrok start --all --config scripts/ngrok.yml
#
# authtoken 설정 방법:
#   export NGROK_AUTHTOKEN=your_token_here
#   또는 ~/.bashrc 에 추가
# ============================================================================
version: "3"

tunnels:
  safetrip-backend:
    addr: 3001
    proto: http
    inspect: true

  firebase-auth:
    addr: 9099
    proto: http
    inspect: false

  firebase-rtdb:
    addr: 9000
    proto: http
    inspect: false

  firebase-storage:
    addr: 9199
    proto: http
    inspect: false
```

### Step 2: 확인

```bash
cat /mnt/d/Project/15_SafeTrip_New/scripts/ngrok.yml | grep "addr:"
```
**예상 출력:** 3001, 9099, 9000, 9199 네 줄

### Step 3: Commit

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add scripts/ngrok.yml
git commit -m "chore: ngrok 터널 설정 파일 추가 (4개 서비스)"
```

---

## Task 4: scripts/start-dev-ngrok.sh — 메인 시작 스크립트

**Files:**
- Create: `scripts/start-dev-ngrok.sh`

### Step 1: 스크립트 작성

```bash
#!/bin/bash
# ============================================================================
# SafeTrip - ngrok 외부 공유 개발 환경 시작 스크립트
# ============================================================================
# 사용법: bash scripts/start-dev-ngrok.sh
#
# 사전 요구사항:
#   1. ngrok 설치 (https://ngrok.com/download 또는 아래 자동 설치)
#   2. export NGROK_AUTHTOKEN=your_token  (또는 ~/.bashrc 에 추가)
#      토큰 발급: https://dashboard.ngrok.com/get-started/your-authtoken
#
# 동작:
#   1. 사전 요구사항 확인 (ngrok, NGROK_AUTHTOKEN, Node.js, Firebase CLI)
#   2. Firebase Emulator 시작 (--import로 시드 데이터 복원)
#   3. Backend API 서버 시작 (백그라운드)
#   4. ngrok 터널 4개 시작
#   5. 터널 URL 파싱 → safetrip-mobile/.env 자동 업데이트
#   6. 접속 정보 출력
# ============================================================================

set -e

# ── 색상 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── 경로 ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MOBILE_DIR="$PROJECT_ROOT/safetrip-mobile"
SERVER_DIR="$PROJECT_ROOT/safetrip-server-api"
EMULATOR_DATA_DIR="$PROJECT_ROOT/emulator-data"
NGROK_CONFIG="$SCRIPT_DIR/ngrok.yml"
NGROK_API="http://localhost:4040/api/tunnels"
MOBILE_ENV="$MOBILE_DIR/.env"

export PATH="$HOME/bin:$HOME/.npm-global/bin:$PATH"

# ── 로그 함수 ────────────────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ── 포트 대기 ────────────────────────────────────────────────────────────
wait_for_port() {
    local port=$1 name=$2 max=${3:-60} waited=0
    while ! lsof -i ":$port" -sTCP:LISTEN > /dev/null 2>&1; do
        if [ $waited -ge $max ]; then
            log_error "$name 시작 타임아웃 (${max}s)"
            return 1
        fi
        sleep 1; waited=$((waited + 1))
        printf "\r  ${YELLOW}대기 중...${NC} $name (${waited}s/${max}s)"
    done
    printf "\r"
    log_ok "$name 시작됨 (포트 $port, ${waited}s 소요)"
}

# ============================================================================
# STEP 1: 사전 요구사항 확인
# ============================================================================
check_prerequisites() {
    log_section "Step 1/5 — 사전 요구사항 확인"
    local fail=false

    # ngrok
    if ! command -v ngrok &> /dev/null; then
        log_warn "ngrok 미설치 — 자동 설치를 시도합니다..."
        if install_ngrok; then
            log_ok "ngrok 설치 완료"
        else
            log_error "ngrok 설치 실패. 수동 설치: https://ngrok.com/download"
            fail=true
        fi
    else
        log_ok "ngrok $(ngrok version 2>/dev/null | head -1)"
    fi

    # NGROK_AUTHTOKEN
    if [ -z "${NGROK_AUTHTOKEN:-}" ]; then
        log_error "NGROK_AUTHTOKEN 환경변수가 없습니다."
        echo ""
        echo "  설정 방법:"
        echo "    export NGROK_AUTHTOKEN=your_token"
        echo "    (또는 ~/.bashrc 에 추가)"
        echo ""
        echo "  토큰 발급: https://dashboard.ngrok.com/get-started/your-authtoken"
        fail=true
    else
        log_ok "NGROK_AUTHTOKEN 설정됨"
        # authtoken을 ngrok에 등록 (이미 등록된 경우 무시)
        ngrok authtoken "$NGROK_AUTHTOKEN" > /dev/null 2>&1 || true
    fi

    # Node.js
    if command -v node &> /dev/null; then
        log_ok "Node.js $(node --version)"
    else
        log_error "Node.js 미설치"
        fail=true
    fi

    # Firebase CLI
    if command -v firebase &> /dev/null; then
        log_ok "Firebase CLI $(firebase --version 2>/dev/null | head -1)"
    else
        log_error "Firebase CLI 미설치 (npm install -g firebase-tools)"
        fail=true
    fi

    # Java
    if command -v java &> /dev/null; then
        log_ok "Java $(java -version 2>&1 | head -1 | grep -oP '\"[^\"]+\"' | tr -d '\"')"
    else
        log_error "Java 미설치 (Firebase Emulator 필수)"
        fail=true
    fi

    # Python3 (URL 파싱용)
    if command -v python3 &> /dev/null; then
        log_ok "Python3 $(python3 --version)"
    else
        log_error "Python3 미설치 (sudo apt install python3)"
        fail=true
    fi

    if [ "$fail" = true ]; then
        log_error "사전 요구사항을 충족하지 못했습니다. 위 항목을 해결 후 재실행하세요."
        exit 1
    fi
}

# ngrok 자동 설치 (WSL2/Ubuntu)
install_ngrok() {
    if command -v apt-get &> /dev/null; then
        curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
            | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc > /dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
            | sudo tee /etc/apt/sources.list.d/ngrok.list > /dev/null
        sudo apt-get update -qq && sudo apt-get install -y ngrok 2>/dev/null
        return $?
    fi
    return 1
}

# ============================================================================
# STEP 2: Firebase Emulator 시작
# ============================================================================
start_firebase_emulator() {
    log_section "Step 2/5 — Firebase Emulator 시작"

    # 이미 실행 중이면 스킵
    if lsof -i :4000 -sTCP:LISTEN > /dev/null 2>&1; then
        log_ok "Firebase Emulator 이미 실행 중 (포트 4000)"

        # Auth 사용자 수 확인
        local user_count
        user_count=$(curl -s "http://localhost:9099/emulator/v1/projects/safetrip-urock/accounts" \
            2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(len(d.get('users',[])))
except:
    print(0)
" 2>/dev/null || echo "0")

        if [ "$user_count" = "0" ]; then
            log_warn "Auth Emulator에 유저 없음 — 에뮬레이터를 재시작합니다 (--import 적용)"
            pkill -f "firebase emulators:start" 2>/dev/null || true
            sleep 3
        else
            log_ok "Auth Emulator 유저: ${user_count}명"
            return 0
        fi
    fi

    cd "$PROJECT_ROOT"

    local import_flag=""
    if [ -f "$EMULATOR_DATA_DIR/firebase-export-metadata.json" ]; then
        import_flag="--import=$EMULATOR_DATA_DIR"
        log_info "시드 데이터 복원: $EMULATOR_DATA_DIR"
    else
        log_warn "시드 데이터 없음 — 빈 상태로 시작"
    fi

    log_info "Firebase Emulator 시작 중 (백그라운드)..."
    firebase emulators:start \
        --only auth,database,storage \
        $import_flag \
        --export-on-exit="$EMULATOR_DATA_DIR" \
        > /tmp/safetrip-emulator.log 2>&1 &

    echo $! > /tmp/safetrip-emulator.pid

    wait_for_port 4000 "Emulator UI" 120
    wait_for_port 9099 "Auth Emulator" 15
    wait_for_port 9000 "RTDB Emulator" 15

    # Auth 유저 재확인
    sleep 2
    local user_count
    user_count=$(curl -s "http://localhost:9099/emulator/v1/projects/safetrip-urock/accounts" \
        2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(len(d.get('users',[])))
except:
    print(0)
" 2>/dev/null || echo "0")

    log_ok "Firebase Emulator 시작 완료 (Auth 유저: ${user_count}명)"
    log_info "Emulator UI: http://localhost:4000"
    log_info "로그: /tmp/safetrip-emulator.log"
}

# ============================================================================
# STEP 3: Backend 서버 시작
# ============================================================================
start_backend() {
    log_section "Step 3/5 — Backend API 서버 시작"

    if lsof -i :3001 -sTCP:LISTEN > /dev/null 2>&1; then
        log_ok "Backend API 이미 실행 중 (포트 3001)"
        return 0
    fi

    cd "$SERVER_DIR"

    if [ ! -f ".env" ]; then
        if [ -f ".env.local" ]; then
            cp .env.local .env
            log_info ".env.local → .env 복사"
        else
            log_error "safetrip-server-api/.env 파일이 없습니다"
            exit 1
        fi
    fi

    if [ ! -d "node_modules" ]; then
        log_info "npm install 실행 중..."
        npm install --silent
    fi

    log_info "Backend 서버 시작 중 (백그라운드)..."
    npx tsx watch src/index.ts > /tmp/safetrip-backend.log 2>&1 &
    echo $! > /tmp/safetrip-backend.pid

    wait_for_port 3001 "Backend API" 30
    log_info "로그: /tmp/safetrip-backend.log"
}

# ============================================================================
# STEP 4: ngrok 터널 시작
# ============================================================================
start_ngrok() {
    log_section "Step 4/5 — ngrok 터널 시작"

    # 기존 ngrok 종료
    pkill -f "ngrok start" 2>/dev/null || true
    sleep 1

    log_info "ngrok 터널 4개 시작 중..."
    ngrok start --all --config "$NGROK_CONFIG" \
        --log=stdout > /tmp/safetrip-ngrok.log 2>&1 &
    echo $! > /tmp/safetrip-ngrok.pid

    # ngrok Web UI 대기 (최대 15초)
    local waited=0
    while ! curl -s "$NGROK_API" > /dev/null 2>&1; do
        if [ $waited -ge 15 ]; then
            log_error "ngrok API 응답 없음. 로그 확인: /tmp/safetrip-ngrok.log"
            cat /tmp/safetrip-ngrok.log | tail -20
            exit 1
        fi
        sleep 1; waited=$((waited + 1))
    done

    log_ok "ngrok 터널 시작됨 (Web UI: http://localhost:4040)"
}

# ============================================================================
# STEP 5: 터널 URL 파싱 → .env 업데이트
# ============================================================================
update_mobile_env() {
    log_section "Step 5/5 — safetrip-mobile/.env 업데이트"

    # ngrok API에서 터널 URL 추출
    local tunnels_json
    tunnels_json=$(curl -s "$NGROK_API")

    local backend_url auth_url rtdb_url storage_url
    backend_url=$(echo "$tunnels_json" | python3 -c "
import json,sys
tunnels=json.load(sys.stdin)['tunnels']
for t in tunnels:
    if t['name']=='safetrip-backend' and t['proto']=='https':
        print(t['public_url']); break
" 2>/dev/null)

    auth_url=$(echo "$tunnels_json" | python3 -c "
import json,sys
tunnels=json.load(sys.stdin)['tunnels']
for t in tunnels:
    if t['name']=='firebase-auth' and t['proto']=='https':
        print(t['public_url']); break
" 2>/dev/null)

    rtdb_url=$(echo "$tunnels_json" | python3 -c "
import json,sys
tunnels=json.load(sys.stdin)['tunnels']
for t in tunnels:
    if t['name']=='firebase-rtdb' and t['proto']=='https':
        print(t['public_url']); break
" 2>/dev/null)

    storage_url=$(echo "$tunnels_json" | python3 -c "
import json,sys
tunnels=json.load(sys.stdin)['tunnels']
for t in tunnels:
    if t['name']=='firebase-storage' and t['proto']=='https':
        print(t['public_url']); break
" 2>/dev/null)

    # 빈 값 체크
    if [ -z "$backend_url" ] || [ -z "$auth_url" ] || [ -z "$rtdb_url" ] || [ -z "$storage_url" ]; then
        log_error "터널 URL 파싱 실패. ngrok API 응답:"
        echo "$tunnels_json" | python3 -m json.tool 2>/dev/null || echo "$tunnels_json"
        exit 1
    fi

    # .env 파일 생성/업데이트 (python3로 정확하게 처리)
    python3 << PYEOF
import re, os

env_path = "$MOBILE_ENV"
env_local = "$MOBILE_DIR/.env.local"

# .env.local을 기준으로 시작 (없으면 빈 dict)
lines = []
if os.path.exists(env_local):
    with open(env_local) as f:
        lines = f.readlines()
elif os.path.exists(env_path):
    with open(env_path) as f:
        lines = f.readlines()

updates = {
    'API_SERVER_URL': '$backend_url',
    'FIREBASE_AUTH_EMULATOR_URL': '$auth_url',
    'FIREBASE_RTDB_EMULATOR_URL': '$rtdb_url',
    'FIREBASE_STORAGE_EMULATOR_URL': '$storage_url',
    'USE_FIREBASE_EMULATOR': 'true',
}

updated_keys = set()
new_lines = []
for line in lines:
    matched = False
    for key, val in updates.items():
        if re.match(rf'^{re.escape(key)}\s*=', line):
            new_lines.append(f'{key}={val}\n')
            updated_keys.add(key)
            matched = True
            break
    if not matched:
        new_lines.append(line)

# 없는 키는 파일 끝에 추가
for key, val in updates.items():
    if key not in updated_keys:
        new_lines.append(f'{key}={val}\n')

with open(env_path, 'w') as f:
    f.writelines(new_lines)

print("OK")
PYEOF

    log_ok ".env 업데이트 완료: $MOBILE_ENV"

    # ── 결과 출력 ──────────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}  SafeTrip 외부 공유 환경 준비 완료!${NC}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}Backend API:${NC}        $backend_url"
    echo -e "  ${CYAN}Firebase Auth:${NC}      $auth_url"
    echo -e "  ${CYAN}Firebase RTDB:${NC}      $rtdb_url"
    echo -e "  ${CYAN}Firebase Storage:${NC}   $storage_url"
    echo ""
    echo -e "  ${CYAN}Emulator UI:${NC}        http://localhost:4000"
    echo -e "  ${CYAN}ngrok Web UI:${NC}       http://localhost:4040"
    echo ""
    echo -e "${YELLOW}  ── 물리 기기 테스트 방법 ──────────────────────────────────${NC}"
    echo -e "  1. 위 URL이 자동으로 .env에 반영됨"
    echo -e "  2. flutter run (또는 설치된 앱 재실행)"
    echo -e "  3. 전화번호 입력 → Auth Emulator가 OTP 생성"
    echo -e "  4. PC: http://localhost:4000/auth 에서 OTP 코드 확인"
    echo -e "  5. OTP 입력 → 로그인 성공"
    echo -e "  6. 여행 생성 → 실제 UUID group_id 발급"
    echo -e "  7. 초대 코드로 다른 기기 참여"
    echo ""
    echo -e "${YELLOW}  ── 종료 방법 ────────────────────────────────────────────${NC}"
    echo -e "  bash scripts/start-local.sh --stop"
    echo -e "  pkill -f ngrok"
    echo ""
}

# ── 종료 핸들러 ──────────────────────────────────────────────────────────────
cleanup() {
    echo ""
    log_warn "종료 신호 수신 — 서비스 정리 중..."
    pkill -f "ngrok start" 2>/dev/null || true
    # Firebase Emulator는 --export-on-exit으로 자동 저장됨
    log_ok "ngrok 종료됨. Firebase Emulator는 데이터 저장 후 종료됩니다."
}
trap cleanup EXIT INT TERM

# ============================================================================
# 메인
# ============================================================================
main() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════╗"
    echo "  ║   SafeTrip — ngrok 외부 공유 개발 환경 시작       ║"
    echo "  ╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_prerequisites
    start_firebase_emulator
    start_backend
    start_ngrok
    update_mobile_env

    # 스크립트 종료 후 서비스는 백그라운드에서 계속 실행
    # (trap cleanup은 스크립트 종료 시 ngrok만 정리)
    echo -e "${GREEN}  스크립트 완료. 서비스는 백그라운드에서 실행 중입니다.${NC}"
    echo -e "${GREEN}  flutter run 을 실행하세요.${NC}"
    echo ""
}

main "$@"
```

### Step 2: 실행 권한 부여

```bash
chmod +x /mnt/d/Project/15_SafeTrip_New/scripts/start-dev-ngrok.sh
```

### Step 3: 문법 검사

```bash
bash -n /mnt/d/Project/15_SafeTrip_New/scripts/start-dev-ngrok.sh
echo "문법 OK: $?"
```
**예상 출력:** `문법 OK: 0`

### Step 4: Commit

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add scripts/start-dev-ngrok.sh scripts/ngrok.yml
git commit -m "feat: start-dev-ngrok.sh — ngrok 외부 공유 환경 시작 스크립트 추가"
```

---

## Task 5: LOCAL-DEV-SETUP.md — ngrok 섹션 추가

**Files:**
- Modify: `LOCAL-DEV-SETUP.md` — 문서 끝에 새 섹션 추가

### Step 1: 파일에 ngrok 섹션 추가

`## 전체 종료 순서` 바로 앞에 다음 내용 삽입:

```markdown
---

## 외부 네트워크 공유 (ngrok)

물리 기기 + 외부 네트워크에서 로컬 개발 환경에 접속할 때 사용합니다.

### 사전 준비 (최초 1회)

1. [ngrok.com](https://ngrok.com) 무료 계정 가입
2. authtoken 발급: Dashboard → Your Authtoken
3. WSL2에 환경변수 설정:
   ```bash
   echo 'export NGROK_AUTHTOKEN=your_token_here' >> ~/.bashrc
   source ~/.bashrc
   ```

### 시작

```bash
cd D:\Project\15_SafeTrip_New
bash scripts/start-dev-ngrok.sh
```

스크립트가 자동으로:
- Firebase Emulator 시작 (`--import=./emulator-data` 적용)
- Backend API 시작
- ngrok 터널 4개(Backend, Auth, RTDB, Storage) 생성
- `safetrip-mobile/.env` 에 터널 URL 기입

### 물리 기기 앱 실행

```bash
cd safetrip-mobile
flutter run
```

### 물리 기기 로그인 방법

| 단계 | 내용 |
|------|------|
| 1 | 앱에서 전화번호 입력 |
| 2 | PC 브라우저에서 http://localhost:4000/auth 열기 |
| 3 | 해당 전화번호 행의 "SMS Code" 확인 |
| 4 | 앱에서 코드 입력 → 로그인 완료 |

### 주의사항

- ngrok URL은 세션마다 변경됨 → 스크립트 재실행 시 `.env` 자동 갱신
- Firebase RTDB는 WebSocket 연결 — 방화벽이 WSS를 차단하면 실시간 위치가 안 보일 수 있음
- ngrok 무료 플랜: 분당 40 요청 제한 (개발 테스트 충분)
- 종료: `pkill -f ngrok && bash scripts/start-local.sh --stop`
```

### Step 2: Commit

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add LOCAL-DEV-SETUP.md
git commit -m "docs: LOCAL-DEV-SETUP.md — ngrok 외부 공유 환경 가이드 추가"
```

---

## Task 6: 통합 검증

### Step 1: NGROK_AUTHTOKEN 없이 스크립트 실행 — 오류 메시지 확인

```bash
unset NGROK_AUTHTOKEN
bash /mnt/d/Project/15_SafeTrip_New/scripts/start-dev-ngrok.sh 2>&1 | head -20
```
**예상 출력:** `[ERROR] NGROK_AUTHTOKEN 환경변수가 없습니다.` 메시지 후 종료

### Step 2: firebase_emulator_config.dart 로직 검증 (Dart 없이 Python으로 검증)

```bash
python3 -c "
import re
def extract_host(url):
    return re.sub(r'^https?://', '', url).split('/')[0].split(':')[0]

tests = [
    ('https://abc123.ngrok-free.app', 'abc123.ngrok-free.app'),
    ('http://192.168.1.1', '192.168.1.1'),
    ('https://abc.ngrok-free.app/path', 'abc.ngrok-free.app'),
    ('https://host:8080', 'host'),
]
for url, expected in tests:
    result = extract_host(url)
    status = 'OK' if result == expected else 'FAIL'
    print(f'[{status}] {url} → {result}')
"
```
**예상 출력:** 4줄 모두 `[OK]`

### Step 3: .env 업데이트 Python 로직 검증 (dry-run)

```bash
python3 -c "
import re
test_lines = [
    'API_SERVER_URL=http://10.0.2.2:3001\n',
    'USE_FIREBASE_EMULATOR=true\n',
    'FIREBASE_EMULATOR_HOST=10.0.2.2\n',
    'FIREBASE_AUTH_EMULATOR_URL=\n',
    'FIREBASE_RTDB_EMULATOR_URL=\n',
    'FIREBASE_STORAGE_EMULATOR_URL=\n',
]
updates = {
    'API_SERVER_URL': 'https://backend.ngrok-free.app',
    'FIREBASE_AUTH_EMULATOR_URL': 'https://auth.ngrok-free.app',
    'FIREBASE_RTDB_EMULATOR_URL': 'https://rtdb.ngrok-free.app',
    'FIREBASE_STORAGE_EMULATOR_URL': 'https://storage.ngrok-free.app',
    'USE_FIREBASE_EMULATOR': 'true',
}
updated_keys = set()
new_lines = []
for line in test_lines:
    matched = False
    for key, val in updates.items():
        if re.match(rf'^{re.escape(key)}\s*=', line):
            new_lines.append(f'{key}={val}\n')
            updated_keys.add(key)
            matched = True
            break
    if not matched:
        new_lines.append(line)
for key, val in updates.items():
    if key not in updated_keys:
        new_lines.append(f'{key}={val}\n')
print(''.join(new_lines))
assert 'API_SERVER_URL=https://backend.ngrok-free.app' in ''.join(new_lines)
assert 'FIREBASE_AUTH_EMULATOR_URL=https://auth.ngrok-free.app' in ''.join(new_lines)
print('모든 assertions 통과')
"
```
**예상 출력:** 업데이트된 .env 내용 + `모든 assertions 통과`

### Step 4: git log 확인

```bash
cd /mnt/d/Project/15_SafeTrip_New
git log --oneline -5
```
**예상 출력:** Task 1~5 커밋 5개 확인

---

## 실행 방법 요약

```bash
# 1회 설정
echo 'export NGROK_AUTHTOKEN=your_token' >> ~/.bashrc && source ~/.bashrc

# 매 개발 세션
bash scripts/start-dev-ngrok.sh

# 앱 실행
cd safetrip-mobile && flutter run
```
