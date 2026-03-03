#!/bin/bash
# ============================================================================
# SafeTrip Local Development - 통합 실행 스크립트
# ============================================================================
# 사용법: bash scripts/start-local.sh [옵션]
#
# 옵션:
#   --all          PostgreSQL + Firebase Emulator + Backend 전부 시작 (기본)
#   --firebase     Firebase Emulator만 시작
#   --backend      Backend 서버만 시작
#   --stop         모든 서비스 중지
#   --reset        Firebase Emulator 데이터 초기화 후 시드 데이터로 재시작
# ============================================================================

set -e

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 프로젝트 루트 디렉토리 (이 스크립트 기준)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$PROJECT_ROOT/safetrip-server-api"
MOBILE_DIR="$PROJECT_ROOT/safetrip-mobile"
FUNCTIONS_DIR="$PROJECT_ROOT/safetrip-firebase-function"
EMULATOR_DATA_DIR="$PROJECT_ROOT/emulator-data"

# Java 경로 (WSL2 네이티브 JDK 21 - ~/java/ 설치)
# Firebase CLI 경로 (~/.npm-global/bin/)
export PATH="$HOME/bin:$HOME/.npm-global/bin:$PATH"

# ============================================================================
# 유틸리티 함수
# ============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_port() {
    local port=$1
    local name=$2
    if lsof -i ":$port" -sTCP:LISTEN > /dev/null 2>&1; then
        log_warn "포트 $port ($name) 이미 사용 중"
        return 1
    fi
    return 0
}

wait_for_port() {
    local port=$1
    local name=$2
    local max_wait=${3:-30}
    local waited=0

    while ! lsof -i ":$port" -sTCP:LISTEN > /dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            log_error "$name 시작 타임아웃 (${max_wait}s)"
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done
    log_success "$name 시작됨 (포트 $port, ${waited}s)"
}

# ============================================================================
# 환경 체크
# ============================================================================
check_prerequisites() {
    log_section "환경 확인"

    local has_error=false

    # Node.js
    if command -v node &> /dev/null; then
        log_success "Node.js $(node --version)"
    else
        log_error "Node.js 미설치"
        has_error=true
    fi

    # Java (Firebase Emulator 필수)
    if command -v java &> /dev/null; then
        local java_ver=$(java -version 2>&1 | head -1)
        log_success "Java: $java_ver"
    else
        log_error "Java 미설치 (Firebase Emulator 필수)"
        log_info "  설치: sudo apt install openjdk-17-jre-headless"
        log_info "  또는 WSL2: ln -s '/mnt/c/Program Files/Microsoft/jdk-17.*/bin/java.exe' ~/bin/java"
        has_error=true
    fi

    # Firebase CLI
    if command -v firebase &> /dev/null; then
        log_success "Firebase CLI $(firebase --version 2>/dev/null)"
    else
        log_error "Firebase CLI 미설치"
        log_info "  설치: npm install -g firebase-tools"
        has_error=true
    fi

    # Docker
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            log_success "Docker 실행 중"
        else
            log_warn "Docker 설치됨, 데몬 미실행"
        fi
    else
        log_warn "Docker 미설치 (PostgreSQL 직접 관리 필요)"
    fi

    if [ "$has_error" = true ]; then
        log_error "필수 환경이 갖추어지지 않았습니다."
        exit 1
    fi
}

# ============================================================================
# PostgreSQL (Docker)
# ============================================================================
start_postgres() {
    log_section "PostgreSQL 시작"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q safetrip-postgres-local; then
        log_success "PostgreSQL 이미 실행 중"
        return 0
    fi

    log_info "Docker Compose로 PostgreSQL 시작..."
    cd "$SERVER_DIR"
    docker compose -f docker-compose.local.yml up -d postgres

    # 헬스체크 대기
    local max_wait=30
    local waited=0
    while ! docker exec safetrip-postgres-local pg_isready -U safetrip -d safetrip_local &> /dev/null; do
        if [ $waited -ge $max_wait ]; then
            log_error "PostgreSQL 시작 타임아웃"
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done

    log_success "PostgreSQL 준비 완료 (localhost:5432)"
}

# ============================================================================
# Firebase Emulator
# ============================================================================
start_firebase_emulator() {
    log_section "Firebase Emulator 시작"

    # 이미 실행 중인지 확인
    if check_port 4000 "Emulator UI" 2>/dev/null; then
        : # 포트 사용 가능
    else
        log_success "Firebase Emulator 이미 실행 중"
        return 0
    fi

    cd "$PROJECT_ROOT"

    local import_flag=""
    if [ -d "$EMULATOR_DATA_DIR" ] && [ -f "$EMULATOR_DATA_DIR/firebase-export-metadata.json" ]; then
        import_flag="--import=$EMULATOR_DATA_DIR"
        log_info "시드 데이터 로드: $EMULATOR_DATA_DIR"
    fi

    # Functions 에뮬레이터 포함 여부 결정
    local only_flag="--only auth,database,storage"
    if [ "${INCLUDE_FUNCTIONS:-false}" = "true" ]; then
        only_flag=""  # 전체 시작 (firebase.json 설정 따름)
        log_info "Functions 에뮬레이터 포함"
    fi

    log_info "Firebase Emulator 시작 중 (백그라운드)..."
    firebase emulators:start $only_flag $import_flag \
        --export-on-exit="$EMULATOR_DATA_DIR" \
        --project demo-safetrip-local \
        > /tmp/firebase-emulator.log 2>&1 &

    local emulator_pid=$!
    echo $emulator_pid > /tmp/firebase-emulator.pid
    log_info "Emulator PID: $emulator_pid"

    # Emulator UI 포트 대기 (RTDB 에뮬레이터가 Java JAR 다운로드 시 오래 걸림)
    wait_for_port 4000 "Emulator UI" 90
    wait_for_port 9099 "Auth Emulator" 10
    wait_for_port 9000 "Database Emulator" 10

    echo ""
    log_success "Firebase Emulator Suite 시작 완료"
    echo -e "  ${CYAN}Emulator UI:${NC}     http://localhost:4000"
    echo -e "  ${CYAN}Auth:${NC}            localhost:9099"
    echo -e "  ${CYAN}Realtime DB:${NC}     localhost:9000"
    echo -e "  ${CYAN}Storage:${NC}         localhost:9199"
    echo -e "  ${CYAN}로그 파일:${NC}       /tmp/firebase-emulator.log"
}

# ============================================================================
# Storage 아바타 이미지 업로드
# ============================================================================
upload_storage_assets() {
    log_section "Storage 아바타 이미지 업로드"

    local bucket="safetrip-urock.firebasestorage.app"
    local emulator_url="http://localhost:9199"
    local assets_dir="$PROJECT_ROOT/safetrip-mobile/assets/images"

    if [ ! -d "$assets_dir" ]; then
        log_warn "assets 디렉토리 없음: $assets_dir"
        return 0
    fi

    local success=0 skip=0 fail=0

    for i in $(seq -w 1 10); do
        local file="$assets_dir/avata_${i}.png"
        local storage_path="profiles/avata_${i}.png"

        if [ ! -f "$file" ]; then
            log_warn "파일 없음: $file"
            continue
        fi

        local encoded
        encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${storage_path}', safe=''))")

        # 이미 존재하면 스킵
        local exists_code
        exists_code=$(curl -s -o /dev/null -w "%{http_code}" \
            "${emulator_url}/v0/b/${bucket}/o/${encoded}" 2>/dev/null)
        if [ "$exists_code" = "200" ]; then
            skip=$((skip + 1))
            continue
        fi

        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST \
            "${emulator_url}/v0/b/${bucket}/o?name=${encoded}&uploadType=media" \
            -H "Content-Type: image/png" \
            --data-binary "@${file}" 2>/dev/null)

        if [ "$http_code" = "200" ]; then
            success=$((success + 1))
        else
            log_warn "avata_${i}.png 업로드 실패 (HTTP $http_code)"
            fail=$((fail + 1))
        fi
    done

    log_success "아바타 이미지: ${success}개 업로드, ${skip}개 기존 유지, ${fail}개 실패"
}

# ============================================================================
# IP 감지
# ============================================================================

# WSL2 내부 IP (172.x.x.x)
get_wsl2_ip() {
    hostname -I | awk '{print $1}'
}

# Windows 실제 LAN IP (192.168.x.x 등 — 물리 기기가 WiFi로 접속하는 IP)
# WSL2에서 PowerShell을 통해 Windows 네트워크 어댑터 중 실제 LAN IP를 추출
get_windows_lan_ip() {
    powershell.exe -Command \
        "Get-NetIPAddress -AddressFamily IPv4 | \
         Where-Object { \$_.InterfaceAlias -notmatch 'Loopback|WSL|vEthernet|Bluetooth|Teredo|isatap' -and \
                        \$_.IPAddress -notlike '127.*' -and \$_.IPAddress -notlike '169.254.*' } | \
         Sort-Object InterfaceMetric | \
         Select-Object -First 1 -ExpandProperty IPAddress" \
        2>/dev/null | tr -d '\r\n\t '
}

# ============================================================================
# safetrip-mobile/.env 자동 업데이트 (현재 LAN IP 반영)
# ============================================================================
update_mobile_env() {
    log_section "safetrip-mobile/.env 자동 업데이트"

    local host_ip
    host_ip=$(get_windows_lan_ip)

    if [ -n "$host_ip" ]; then
        log_success "Windows LAN IP 감지: $host_ip"
    else
        host_ip=$(get_wsl2_ip)
        log_warn "Windows LAN IP 감지 실패 → WSL2 IP 사용: $host_ip"
        log_warn "물리 기기 접속이 안 되면 PC에서 ipconfig /all 로 IP를 확인하세요"
    fi

    python3 << PYEOF
import re, os

env_path   = "$MOBILE_DIR/.env"
env_local  = "$MOBILE_DIR/.env.local"
host_ip    = "$host_ip"

lines = []
if os.path.exists(env_local):
    with open(env_local) as f:
        lines = f.readlines()
elif os.path.exists(env_path):
    with open(env_path) as f:
        lines = f.readlines()

updates = {
    'API_SERVER_URL':        f'http://{host_ip}:3001',
    'FIREBASE_EMULATOR_HOST': host_ip,
    'USE_FIREBASE_EMULATOR':  'true',
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

for key, val in updates.items():
    if key not in updated_keys:
        new_lines.append(f'{key}={val}\n')

with open(env_path, 'w') as f:
    f.writelines(new_lines)

print("OK")
PYEOF

    log_success "API_SERVER_URL=http://$host_ip:3001"
    log_success "FIREBASE_EMULATOR_HOST=$host_ip"
    log_info "파일: $MOBILE_DIR/.env"
}

# ============================================================================
# portproxy 자동 업데이트 (WSL2 IP 변경 감지 → Windows portproxy 갱신)
# 대상 포트: 3001(Backend) · 9099(Auth) · 9000(RTDB) · 9199(Storage)
# ============================================================================
update_portproxy() {
    log_section "portproxy 자동 업데이트 (물리 기기 LAN 접속용)"

    local wsl2_ip
    wsl2_ip=$(get_wsl2_ip)
    log_info "현재 WSL2 IP: $wsl2_ip"

    local current_target
    current_target=$(powershell.exe -Command \
        "netsh interface portproxy show all" 2>/dev/null | \
        grep "[[:space:]]3001[[:space:]]" | awk '{print $3}' | tr -d '\r\n ')

    if [ "$current_target" = "$wsl2_ip" ]; then
        log_success "portproxy 최신 상태 (→ $wsl2_ip)"
        return 0
    fi

    log_info "portproxy 업데이트 중: ${current_target:-(없음)} → $wsl2_ip"

    local ports=(3001 9099 9000 9199)
    local ps_script=""
    for port in "${ports[@]}"; do
        ps_script+="netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0 2>\$null; "
        ps_script+="netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wsl2_ip; "
    done

    local result
    result=$(powershell.exe -Command "$ps_script echo 'OK'" 2>/dev/null | tr -d '\r\n ')

    if echo "$result" | grep -q "OK"; then
        log_success "portproxy 업데이트 완료 (포트 ${ports[*]} → $wsl2_ip)"
    else
        log_warn "portproxy 자동 업데이트 실패 — Windows 관리자 권한이 필요합니다"
        log_warn "관리자 PowerShell에서 직접 실행:"
        for port in "${ports[@]}"; do
            echo "    netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wsl2_ip"
        done
    fi
}

# ============================================================================
# Backend 서버
# ============================================================================
start_backend() {
    log_section "Backend 서버 시작"

    cd "$SERVER_DIR"

    # .env 파일 확인
    if [ ! -f ".env" ]; then
        if [ -f ".env.local" ]; then
            log_info ".env.local → .env 복사"
            cp .env.local .env
        else
            log_error ".env 파일 없음"
            return 1
        fi
    fi

    # node_modules 확인
    if [ ! -d "node_modules" ]; then
        log_info "npm install 실행 중..."
        npm install
    fi

    # Firebase Emulator 환경변수 확인
    if grep -q "FIREBASE_AUTH_EMULATOR_HOST" .env; then
        log_success "Firebase Emulator 환경변수 설정됨"
    else
        log_warn "Firebase Emulator 환경변수가 .env에 없습니다"
    fi

    log_info "Backend 서버 시작 (tsx watch)..."
    echo -e "  ${CYAN}서버 URL:${NC}  http://localhost:$(grep PORT .env | head -1 | cut -d= -f2)"
    echo ""

    # Foreground로 실행 (개발 모드)
    npx tsx watch src/index.ts
}

# ============================================================================
# 서비스 중지
# ============================================================================
stop_all() {
    log_section "모든 서비스 중지"

    # Firebase Emulator 중지
    if [ -f /tmp/firebase-emulator.pid ]; then
        local pid=$(cat /tmp/firebase-emulator.pid)
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Firebase Emulator 중지 (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            # Java 프로세스도 정리
            pkill -f "firebase-tools" 2>/dev/null || true
            pkill -f "cloud-firestore-emulator" 2>/dev/null || true
        fi
        rm -f /tmp/firebase-emulator.pid
        log_success "Firebase Emulator 중지됨"
    else
        # PID 파일 없어도 프로세스 확인
        pkill -f "firebase emulators:start" 2>/dev/null && log_success "Firebase Emulator 중지됨" || log_info "Firebase Emulator 미실행"
    fi

    # PostgreSQL Docker 중지
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q safetrip-postgres-local; then
        log_info "PostgreSQL Docker 중지..."
        cd "$SERVER_DIR" 2>/dev/null && docker compose -f docker-compose.local.yml down 2>/dev/null
        log_success "PostgreSQL 중지됨"
    else
        log_info "PostgreSQL 미실행"
    fi

    # Backend 서버 (tsx) 중지
    pkill -f "tsx.*src/index.ts" 2>/dev/null && log_success "Backend 서버 중지됨" || log_info "Backend 서버 미실행"

    log_success "모든 서비스 중지 완료"
}

# ============================================================================
# 에뮬레이터 데이터 초기화
# ============================================================================
reset_emulator_data() {
    log_section "Firebase Emulator 데이터 초기화"

    # 실행 중인 에뮬레이터 중지
    pkill -f "firebase emulators:start" 2>/dev/null || true
    sleep 2

    log_info "시드 데이터로 초기화됩니다."
    start_firebase_emulator
}

# ============================================================================
# 상태 확인
# ============================================================================
show_status() {
    log_section "서비스 상태"

    # PostgreSQL
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q safetrip-postgres-local; then
        echo -e "  ${GREEN}●${NC} PostgreSQL     localhost:5432"
    else
        echo -e "  ${RED}○${NC} PostgreSQL     (미실행)"
    fi

    # Firebase Emulator UI
    if lsof -i :4000 -sTCP:LISTEN > /dev/null 2>&1; then
        echo -e "  ${GREEN}●${NC} Emulator UI    http://localhost:4000"
    else
        echo -e "  ${RED}○${NC} Emulator UI    (미실행)"
    fi

    # Firebase Auth
    if lsof -i :9099 -sTCP:LISTEN > /dev/null 2>&1; then
        echo -e "  ${GREEN}●${NC} Auth           localhost:9099"
    else
        echo -e "  ${RED}○${NC} Auth           (미실행)"
    fi

    # Firebase RTDB
    if lsof -i :9000 -sTCP:LISTEN > /dev/null 2>&1; then
        echo -e "  ${GREEN}●${NC} Realtime DB    localhost:9000"
    else
        echo -e "  ${RED}○${NC} Realtime DB    (미실행)"
    fi

    # Firebase Storage
    if lsof -i :9199 -sTCP:LISTEN > /dev/null 2>&1; then
        echo -e "  ${GREEN}●${NC} Storage        localhost:9199"
    else
        echo -e "  ${RED}○${NC} Storage        (미실행)"
    fi

    # Firebase Functions
    if lsof -i :5001 -sTCP:LISTEN > /dev/null 2>&1; then
        echo -e "  ${GREEN}●${NC} Functions      localhost:5001"
    else
        echo -e "  ${RED}○${NC} Functions      (미실행)"
    fi

    # Backend
    if lsof -i :3001 -sTCP:LISTEN > /dev/null 2>&1; then
        echo -e "  ${GREEN}●${NC} Backend API    http://localhost:3001"
    elif lsof -i :3099 -sTCP:LISTEN > /dev/null 2>&1; then
        echo -e "  ${GREEN}●${NC} Backend API    http://localhost:3099"
    else
        echo -e "  ${RED}○${NC} Backend API    (미실행)"
    fi

    echo ""
}

# ============================================================================
# 메인 실행
# ============================================================================
main() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   SafeTrip Local Development Environment  ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"

    local mode="${1:---all}"

    case "$mode" in
        --all)
            check_prerequisites
            update_mobile_env    # PC IP 감지 → safetrip-mobile/.env 자동 업데이트
            update_portproxy     # WSL2 IP 변경 감지 → Windows portproxy 자동 갱신
            start_postgres
            start_firebase_emulator
            upload_storage_assets
            show_status
            start_backend  # 마지막 (foreground)
            ;;
        --env)
            # IP만 재감지해서 .env 업데이트 (서비스 재시작 없이)
            update_mobile_env
            update_portproxy
            ;;
        --firebase)
            check_prerequisites
            start_firebase_emulator
            show_status
            ;;
        --backend)
            start_backend
            ;;
        --stop)
            stop_all
            ;;
        --reset)
            reset_emulator_data
            ;;
        --status)
            show_status
            ;;
        --help|-h)
            echo "사용법: bash scripts/start-local.sh [옵션]"
            echo ""
            echo "옵션:"
            echo "  --all        전체 시작: PostgreSQL + Firebase Emulator + Backend (기본)"
            echo "               └─ PC LAN IP 자동 감지 → .env + portproxy 자동 갱신 포함"
            echo "  --env        IP만 재감지해서 .env + portproxy 갱신 (서비스 재시작 없이)"
            echo "  --firebase   Firebase Emulator만 시작"
            echo "  --backend    Backend 서버만 시작"
            echo "  --stop       모든 서비스 중지"
            echo "  --reset      Firebase Emulator 데이터 초기화"
            echo "  --status     서비스 상태 확인"
            echo "  --help       이 도움말 표시"
            ;;
        *)
            log_error "알 수 없는 옵션: $mode"
            echo "  --help 로 사용법 확인"
            exit 1
            ;;
    esac
}

main "$@"
