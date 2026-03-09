#!/bin/bash
# ============================================================================
# SafeTrip 여행 생성 E2E 테스트
# 백엔드 API → DB 저장 → card-view 조회까지 전체 흐름 검증
# ============================================================================
set +e

API_BASE="http://localhost:3001"
FIREBASE_AUTH="http://localhost:9099"
PROJECT_ID="safetrip-urock"
DB_CONTAINER="safetrip-postgres-local"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  local desc="$1" ok="$2"
  if [ "$ok" = "true" ]; then
    echo -e "  ${GREEN}✓${NC} $desc"
    ((PASS++))
  else
    echo -e "  ${RED}✗${NC} $desc"
    ((FAIL++))
  fi
}

echo "============================================"
echo "  SafeTrip 여행 생성 E2E 테스트"
echo "============================================"

# ── 1) 사전 조건 확인 ──
echo ""
echo "▸ Step 1: 서비스 상태 확인"

SERVER_OK=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE/api/v1/version" 2>/dev/null || echo "000")
check "백엔드 서버 응답" "$([ "$SERVER_OK" != "000" ] && echo true || echo false)"

FIREBASE_OK=$(curl -s "$FIREBASE_AUTH/" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('authEmulator',{}).get('ready',''))" 2>/dev/null || echo "")
check "Firebase Auth 에뮬레이터" "$([ "$FIREBASE_OK" = "True" ] && echo true || echo false)"

DB_OK=$(docker exec "$DB_CONTAINER" psql -U safetrip -d safetrip_local -c "SELECT 1" 2>/dev/null | grep -c "1 row" || echo "0")
check "PostgreSQL 접속" "$([ "$DB_OK" -gt 0 ] && echo true || echo false)"

# ── 2) 테스트 사용자 생성 ──
echo ""
echo "▸ Step 2: 테스트 사용자 생성"

SIGNUP_RESP=$(curl -s -X POST "$FIREBASE_AUTH/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key" \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+821099998888", "displayName": "TripTestUser"}' 2>/dev/null)

TOKEN=$(echo "$SIGNUP_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('idToken',''))" 2>/dev/null || echo "")
USER_ID=$(echo "$SIGNUP_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('localId',''))" 2>/dev/null || echo "")

check "Firebase 토큰 발급" "$([ -n "$TOKEN" ] && echo true || echo false)"
check "사용자 ID 생성" "$([ -n "$USER_ID" ] && echo true || echo false)"

if [ -z "$TOKEN" ]; then
  echo -e "\n${RED}Firebase 토큰 발급 실패 — 테스트 중단${NC}"
  exit 1
fi

# ── 3) 여행 생성 API 테스트 ──
echo ""
echo "▸ Step 3: 여행 생성 API (POST /api/v1/trips)"

TRIP_NAME="E2E_테스트여행_$(date +%H%M%S)"
CREATE_RESP=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/api/v1/trips" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"title\": \"$TRIP_NAME\",
    \"country_code\": \"JP\",
    \"country_name\": \"일본\",
    \"trip_type\": \"group\",
    \"start_date\": \"2026-05-01\",
    \"end_date\": \"2026-05-05\"
  }" 2>/dev/null)

HTTP_CODE=$(echo "$CREATE_RESP" | tail -1)
BODY=$(echo "$CREATE_RESP" | head -n -1)

check "HTTP 201 Created" "$([ "$HTTP_CODE" = "201" ] && echo true || echo false)"

SUCCESS=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success',''))" 2>/dev/null || echo "")
check "응답 success=true" "$([ "$SUCCESS" = "True" ] && echo true || echo false)"

TRIP_ID=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('tripId',''))" 2>/dev/null || echo "")
GROUP_ID=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('groupId',''))" 2>/dev/null || echo "")
STATUS=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('status',''))" 2>/dev/null || echo "")
INVITE=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('inviteCode',''))" 2>/dev/null || echo "")
COUNTRY=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data',{}).get('countryCode',''))" 2>/dev/null || echo "")

check "tripId 반환" "$([ -n "$TRIP_ID" ] && echo true || echo false)"
check "groupId 반환" "$([ -n "$GROUP_ID" ] && echo true || echo false)"
check "status=planning" "$([ "$STATUS" = "planning" ] && echo true || echo false)"
check "inviteCode 반환" "$([ -n "$INVITE" ] && echo true || echo false)"
check "countryCode=JP" "$([ "$COUNTRY" = "JP" ] && echo true || echo false)"

# ── 4) DB 저장 검증 ──
echo ""
echo "▸ Step 4: DB 저장 검증"

if [ -n "$TRIP_ID" ]; then
  DB_TRIP=$(docker exec "$DB_CONTAINER" psql -U safetrip -d safetrip_local -t -c "
    SELECT trip_name, status, country_code, trip_type
    FROM tb_trip WHERE trip_id = '$TRIP_ID'
  " 2>/dev/null | tr -d ' ')

  check "tb_trip 레코드 존재" "$([ -n "$DB_TRIP" ] && echo true || echo false)"
  check "tb_trip status=planning" "$(echo "$DB_TRIP" | grep -q 'planning' && echo true || echo false)"
  check "tb_trip country_code=JP" "$(echo "$DB_TRIP" | grep -q 'JP' && echo true || echo false)"

  DB_MEMBER=$(docker exec "$DB_CONTAINER" psql -U safetrip -d safetrip_local -t -c "
    SELECT member_role, is_admin FROM tb_group_member
    WHERE trip_id = '$TRIP_ID' AND user_id = '$USER_ID'
  " 2>/dev/null | tr -d ' ')

  check "tb_group_member captain 등록" "$(echo "$DB_MEMBER" | grep -q 'captain' && echo true || echo false)"
  check "tb_group_member is_admin=true" "$(echo "$DB_MEMBER" | grep -q 't' && echo true || echo false)"

  DB_CHAT=$(docker exec "$DB_CONTAINER" psql -U safetrip -d safetrip_local -t -c "
    SELECT room_type FROM tb_chat_room WHERE trip_id = '$TRIP_ID'
  " 2>/dev/null | tr -d ' ')

  check "tb_chat_room 자동 생성" "$(echo "$DB_CHAT" | grep -q 'group' && echo true || echo false)"

  DB_GROUP=$(docker exec "$DB_CONTAINER" psql -U safetrip -d safetrip_local -t -c "
    SELECT invite_code FROM tb_group WHERE group_id = '$GROUP_ID'
  " 2>/dev/null | tr -d ' ')

  check "tb_group invite_code 저장" "$([ -n "$DB_GROUP" ] && echo true || echo false)"
fi

# ── 5) card-view 조회 검증 ──
echo ""
echo "▸ Step 5: card-view 조회 (GET /api/v1/trips/card-view)"

CARD_RESP=$(curl -s "$API_BASE/api/v1/trips/card-view" \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null)

CARD_SUCCESS=$(echo "$CARD_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success',''))" 2>/dev/null || echo "")
check "card-view success=true" "$([ "$CARD_SUCCESS" = "True" ] && echo true || echo false)"

MEMBER_TRIPS=$(echo "$CARD_RESP" | python3 -c "
import json,sys
data = json.load(sys.stdin)
trips = data.get('data',{}).get('memberTrips',[])
print(len(trips))
" 2>/dev/null || echo "0")

check "memberTrips 1건 이상" "$([ "$MEMBER_TRIPS" -gt 0 ] && echo true || echo false)"

CARD_TRIP_FOUND=$(echo "$CARD_RESP" | python3 -c "
import json,sys
data = json.load(sys.stdin)
trips = data.get('data',{}).get('memberTrips',[])
found = any(t.get('trip_id') == '$TRIP_ID' for t in trips)
print('true' if found else 'false')
" 2>/dev/null || echo "false")

check "card-view에 생성한 여행 포함" "$CARD_TRIP_FOUND"

# ── 6) ngrok 경유 테스트 (선택) ──
echo ""
echo "▸ Step 6: ngrok 경유 테스트"

NGROK_URL=$(grep 'API_SERVER_URL=' /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/.env 2>/dev/null | cut -d= -f2 | tr -d ' ')
if [ -n "$NGROK_URL" ] && [[ "$NGROK_URL" == *"ngrok"* ]]; then
  NGROK_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$NGROK_URL/api/v1/trips/card-view" \
    -H "Authorization: Bearer $TOKEN" \
    -H "ngrok-skip-browser-warning: true" 2>/dev/null || echo "000")
  check "ngrok 터널 응답 ($NGROK_CODE)" "$([ "$NGROK_CODE" = "200" ] && echo true || echo false)"
else
  echo -e "  ${YELLOW}⊘${NC} ngrok URL 미설정 — 스킵"
fi

# ── 결과 요약 ──
echo ""
echo "============================================"
TOTAL=$((PASS + FAIL))
echo -e "  결과: ${GREEN}${PASS} 통과${NC} / ${RED}${FAIL} 실패${NC} (총 $TOTAL)"
echo "============================================"

# 정리: 테스트 데이터 삭제 (선택)
if [ -n "$TRIP_ID" ]; then
  docker exec "$DB_CONTAINER" psql -U safetrip -d safetrip_local -c "
    DELETE FROM tb_chat_room WHERE trip_id = '$TRIP_ID';
    DELETE FROM tb_group_member WHERE trip_id = '$TRIP_ID';
    DELETE FROM tb_trip WHERE trip_id = '$TRIP_ID';
    DELETE FROM tb_group WHERE group_id = '$GROUP_ID';
  " > /dev/null 2>&1
  echo -e "\n${YELLOW}테스트 데이터 정리 완료${NC}"
fi

exit $FAIL
