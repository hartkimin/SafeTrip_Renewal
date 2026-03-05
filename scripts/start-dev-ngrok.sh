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
#   4. 로컬 리버스 프록시 시작 (포트 8888, 경로 기반 라우팅)
#   5. ngrok HTTP 터널 1개 시작 (→ 프록시 :8888)
#   6. 터널 URL 파싱 → safetrip-mobile/.env 자동 업데이트
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
    log_section "Step 1/6 — 사전 요구사항 확인"
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
    log_section "Step 2/6 — Firebase Emulator 시작"

    # 이미 실행 중이면 스킵
    if lsof -i :4000 -sTCP:LISTEN > /dev/null 2>&1; then
        log_ok "Firebase Emulator 이미 실행 중 (포트 4000)"

        # Auth 사용자 수 확인
        local user_count
        user_count=$(curl -s \
            -H "Authorization: Bearer owner" \
            "http://localhost:9099/identitytoolkit.googleapis.com/v1/projects/safetrip-urock/accounts:batchGet?maxResults=100" \
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
    user_count=$(curl -s \
        -H "Authorization: Bearer owner" \
        "http://localhost:9099/identitytoolkit.googleapis.com/v1/projects/safetrip-urock/accounts:batchGet?maxResults=100" \
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
    log_section "Step 3/6 — Backend API 서버 시작"

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
    npm run start:dev > /tmp/safetrip-backend.log 2>&1 &
    echo $! > /tmp/safetrip-backend.pid

    wait_for_port 3001 "Backend API" 30
    log_info "로그: /tmp/safetrip-backend.log"
}

# ============================================================================
# STEP 4: 로컬 리버스 프록시 시작 (포트 8888)
# ============================================================================
# Firebase Auth/RTDB/Storage + Backend API를 단일 포트로 라우팅.
# ngrok 단일 HTTP 터널이 이 포트를 외부에 노출합니다.
# ============================================================================
start_proxy() {
    log_section "Step 4/6 — 로컬 리버스 프록시 시작 (포트 8888)"

    if lsof -i :8888 -sTCP:LISTEN > /dev/null 2>&1; then
        log_ok "로컬 프록시 이미 실행 중 (포트 8888)"
        return 0
    fi

    log_info "프록시 시작 중 (백그라운드)..."
    node "$SCRIPT_DIR/local-proxy.cjs" > /tmp/safetrip-proxy.log 2>&1 &
    echo $! > /tmp/safetrip-proxy.pid

    wait_for_port 8888 "Local Proxy" 10
    log_info "로그: /tmp/safetrip-proxy.log"
}

# ============================================================================
# STEP 5: ngrok 터널 시작 (단일 HTTP 터널 → 포트 8888)
# ============================================================================
start_ngrok() {
    log_section "Step 5/6 — ngrok 터널 시작"

    # 기존 ngrok 종료
    pkill -f "ngrok start" 2>/dev/null || true
    sleep 1

    log_info "ngrok 터널 시작 중 (→ 로컬 프록시 :8888)..."
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
# STEP 6: 터널 URL 파싱 → .env 업데이트
# ============================================================================
update_mobile_env() {
    log_section "Step 6/6 — safetrip-mobile/.env 업데이트"

    # ngrok API에서 프록시 터널 URL 추출 (단일 URL)
    local tunnels_json proxy_url
    tunnels_json=$(curl -s "$NGROK_API")

    proxy_url=$(echo "$tunnels_json" | python3 -c "
import json,sys
tunnels=json.load(sys.stdin)['tunnels']
for t in tunnels:
    if t['name']=='safetrip-proxy' and t['proto']=='http':
        print(t['public_url']); break
" 2>/dev/null)

    # 빈 값 체크
    if [ -z "$proxy_url" ]; then
        log_error "터널 URL 파싱 실패. ngrok API 응답:"
        echo "$tunnels_json" | python3 -m json.tool 2>/dev/null || echo "$tunnels_json"
        exit 1
    fi

    # 모든 서비스가 동일한 프록시 URL 사용 (local-proxy.cjs가 경로 기반 라우팅)
    local backend_url="$proxy_url"
    local auth_url="$proxy_url"
    local rtdb_url="$proxy_url"
    local storage_url="$proxy_url"

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
    pkill -f "local-proxy.cjs" 2>/dev/null || true
    # Firebase Emulator는 --export-on-exit으로 자동 저장됨
    log_ok "ngrok/proxy 종료됨. Firebase Emulator는 데이터 저장 후 종료됩니다."
}
trap cleanup INT TERM

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
    start_proxy
    start_ngrok
    update_mobile_env

    # 스크립트 종료 후 서비스는 백그라운드에서 계속 실행
    # (trap cleanup은 스크립트 종료 시 ngrok만 정리)
    echo -e "${GREEN}  스크립트 완료. 서비스는 백그라운드에서 실행 중입니다.${NC}"
    echo -e "${GREEN}  flutter run 을 실행하세요.${NC}"
    echo ""
}

main "$@"
