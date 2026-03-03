#!/usr/bin/env bash
# scripts/test/run-all-tests.sh
#
# SafeTrip UAT — 전체 테스트 실행 스크립트
#
# 사용법:
#   cd /mnt/d/Project/15_SafeTrip_New
#   bash scripts/test/run-all-tests.sh
#
# 옵션:
#   --phase=1       특정 Phase만 실행 (1~6)
#   --skip=3,4      특정 Phase 건너뜀
#   --no-security   보안 테스트(Phase 6) 건너뜀
#   --no-cleanup    테스트 후 Firebase 계정 유지
#
# 사전 조건:
#   - 서버: npm run dev (port 3001)
#   - Firebase Emulator: firebase emulators:start (9099, 9000)
#   - PostgreSQL: safetrip-postgres-local 컨테이너
#
# 실행 결과: /tmp/safetrip-test-results.log

set -euo pipefail

# ─── 경로 설정 ────────────────────────────────────────────────────────────────

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts/test"
LOG_FILE="/tmp/safetrip-test-results.log"
STATE_FILE="/tmp/safetrip-test-state.json"
NODE_PATH_ENV="${PROJECT_ROOT}/safetrip-server-api/node_modules"

# 색상 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── 인수 파싱 ────────────────────────────────────────────────────────────────

PHASE_FILTER=""
SKIP_PHASES=""
NO_CLEANUP=false
NO_SECURITY=false

for arg in "$@"; do
  case $arg in
    --phase=*) PHASE_FILTER="${arg#*=}" ;;
    --skip=*)  SKIP_PHASES="${arg#*=}" ;;
    --no-cleanup) NO_CLEANUP=true ;;
    --no-security) NO_SECURITY=true ;;
  esac
done

# ─── 헬퍼 함수 ────────────────────────────────────────────────────────────────

log() {
  echo -e "$1" | tee -a "${LOG_FILE}"
}

run_phase() {
  local phase_num="$1"
  local phase_file="$2"
  local phase_name="$3"

  # 필터 확인
  if [[ -n "${PHASE_FILTER}" && "${PHASE_FILTER}" != *"${phase_num}"* ]]; then
    log "${YELLOW}[SKIP] Phase ${phase_num}: ${phase_name} (--phase 필터)${NC}"
    return 0
  fi

  if [[ -n "${SKIP_PHASES}" && "${SKIP_PHASES}" == *"${phase_num}"* ]]; then
    log "${YELLOW}[SKIP] Phase ${phase_num}: ${phase_name} (--skip 지정)${NC}"
    return 0
  fi

  if [[ ! -f "${SCRIPTS_DIR}/${phase_file}" ]]; then
    log "${RED}[ERROR] Phase ${phase_num}: ${phase_file} 파일 없음${NC}"
    return 1
  fi

  log "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  log "${BLUE}  Phase ${phase_num}: ${phase_name}${NC}"
  log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  local start_time
  start_time=$(date +%s)

  if NODE_PATH="${NODE_PATH_ENV}" npx tsx "${SCRIPTS_DIR}/${phase_file}" 2>&1 | tee -a "${LOG_FILE}"; then
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log "${GREEN}[PASS] Phase ${phase_num} 완료 (${duration}초)${NC}"
    return 0
  else
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log "${RED}[FAIL] Phase ${phase_num} 실패 (${duration}초)${NC}"
    log "${RED}       서버 로그: tail -20 /tmp/safetrip-backend.log${NC}"
    return 1
  fi
}

# ─── 사전 검증 ────────────────────────────────────────────────────────────────

check_prereqs() {
  log "\n${BLUE}[사전 검증] 서비스 상태 확인 중...${NC}"

  # 서버 확인
  if curl -s "http://localhost:3001/health" > /dev/null 2>&1; then
    log "${GREEN}  ✓ API 서버 (3001)${NC}"
  else
    log "${RED}  ✗ API 서버 (3001) — 응답 없음${NC}"
    log "    실행: cd safetrip-server-api && npm run dev"
    exit 1
  fi

  # Firebase Auth 에뮬레이터 확인
  if curl -s "http://localhost:9099" > /dev/null 2>&1; then
    log "${GREEN}  ✓ Firebase Auth 에뮬레이터 (9099)${NC}"
  else
    log "${RED}  ✗ Firebase Auth 에뮬레이터 (9099) — 응답 없음${NC}"
    log "    실행: firebase emulators:start"
    exit 1
  fi

  # Firebase RTDB 에뮬레이터 확인
  if curl -s "http://localhost:9000" > /dev/null 2>&1; then
    log "${GREEN}  ✓ Firebase RTDB 에뮬레이터 (9000)${NC}"
  else
    log "${YELLOW}  ⚠ Firebase RTDB 에뮬레이터 (9000) — 응답 없음 (가디언 메시지 테스트 실패 가능)${NC}"
  fi

  # PostgreSQL 확인
  if docker exec safetrip-postgres-local pg_isready -U safetrip > /dev/null 2>&1; then
    log "${GREEN}  ✓ PostgreSQL (safetrip-postgres-local)${NC}"
  else
    log "${RED}  ✗ PostgreSQL — 응답 없음${NC}"
    log "    실행: docker start safetrip-postgres-local"
    exit 1
  fi

  log ""
}

# ─── 메인 실행 ────────────────────────────────────────────────────────────────

main() {
  # 로그 파일 초기화
  mkdir -p "$(dirname "${LOG_FILE}")"
  echo "" > "${LOG_FILE}"

  log "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
  log "${BLUE}║           SafeTrip UAT 전체 테스트 실행                   ║${NC}"
  log "${BLUE}║           $(date '+%Y-%m-%d %H:%M:%S')                          ║${NC}"
  log "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

  # 사전 검증
  check_prereqs

  # State 파일 초기화 (Phase 1 이전)
  if [[ -z "${PHASE_FILTER}" || "${PHASE_FILTER}" == *"1"* ]]; then
    log "${YELLOW}[초기화] 이전 테스트 상태 파일 제거${NC}"
    rm -f "${STATE_FILE}"
  fi

  # ─── Phase 실행 ───────────────────────────────────────────────────────────

  PASS_COUNT=0
  FAIL_COUNT=0
  TOTAL_START=$(date +%s)

  phases=(
    "1:phase1-captain-onboarding.ts:Captain 온보딩"
    "2:phase2-member-roles.ts:멤버 역할 검증"
    "3:phase3-guardian-system.ts:가디언 시스템"
    "4:phase4-daily-features.ts:일상 기능"
    "5:phase5-edge-cases.ts:엣지 케이스"
  )

  # 보안 테스트 (Phase 6) — 선택적 실행 (--no-security 로 건너뜀)
  if [[ "${NO_SECURITY}" == "false" ]]; then
    phases+=("6:phase6-security.ts:보안 테스트 (Layer 3)")
  fi

  for phase_entry in "${phases[@]}"; do
    IFS=':' read -r num file name <<< "${phase_entry}"
    if run_phase "${num}" "${file}" "${name}"; then
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      # Phase 1 실패 시 State 없으므로 중단
      if [[ "${num}" == "1" ]]; then
        log "${RED}[ABORT] Phase 1 실패 — 이후 Phase는 State 파일이 필요하므로 중단합니다${NC}"
        break
      fi
    fi
  done

  # ─── 최종 요약 ────────────────────────────────────────────────────────────

  TOTAL_END=$(date +%s)
  TOTAL_DURATION=$((TOTAL_END - TOTAL_START))

  log "\n${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
  log "${BLUE}║                     최종 결과                             ║${NC}"
  log "${BLUE}╠══════════════════════════════════════════════════════════╣${NC}"
  log "${BLUE}║  PASS: ${PASS_COUNT} / FAIL: ${FAIL_COUNT} (총 소요: ${TOTAL_DURATION}초)${NC}"
  log "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

  if [[ -f "${STATE_FILE}" ]]; then
    log "\n${BLUE}[State 파일] ${STATE_FILE}${NC}"
    cat "${STATE_FILE}" | python3 -m json.tool 2>/dev/null || cat "${STATE_FILE}"
  fi

  log "\n전체 로그: ${LOG_FILE}"

  if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
