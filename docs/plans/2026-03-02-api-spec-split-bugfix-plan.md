# API 명세서 파일 분리 + 버그 검토 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 6,209줄 단일 API 명세서(`35_T2_API_명세서.md`)를 INDEX + Part1~3으로 분리하고, 명세서 내용(Response/Request 필드, HTTP 상태코드, 인증 표기)을 백엔드 코드 대조 검토 후 수정한다.

**Architecture:** Phase 1에서 기존 파일을 4개로 분리(bash sed 사용). Phase 2에서 3개 Explore 에이전트를 병렬 투입해 §3~§18의 명세서-코드 불일치를 검출. Phase 3에서 불일치 항목을 Edit 도구로 수정. 백엔드 TypeScript 코드는 변경하지 않는다.

**Tech Stack:** Bash(sed), Read, Write, Edit, Glob, Grep 도구. 분석 대상: `safetrip-server-api/src/controllers/`, `safetrip-server-api/src/routes/`. 수정 대상: `Master_docs/35~38번 파일`.

---

## ━━━━━━━━━━━━ PHASE 1: 파일 분리 ━━━━━━━━━━━━

---

### Task 1: Part1 파일 생성 (§3~§5 인증·사용자·여행)

**Files:**
- Create: `Master_docs/36_T2_API_명세서_Part1.md`
- Read-only: `Master_docs/35_T2_API_명세서.md` (lines 107~1971)

**Step 1: 파트 헤더를 포함한 Part1 파일 생성**

다음 bash 명령으로 헤더를 먼저 작성하고, 이어서 원본 라인을 추출해 붙인다:

```bash
# 1) 헤더 파일 작성
cat > /mnt/d/Project/15_SafeTrip_New/Master_docs/36_T2_API_명세서_Part1.md << 'HEADER'
# SafeTrip Backend API 명세서 — Part 1 (§3~§5)

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-036` |
| **상위 인덱스** | [35_T2_API_명세서_INDEX.md](./35_T2_API_명세서_INDEX.md) |
| **범위** | §3 인증 / §4 사용자 / §5 여행 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |

> Part 2: [37_T2_API_명세서_Part2.md](./37_T2_API_명세서_Part2.md) | Part 3: [38_T2_API_명세서_Part3.md](./38_T2_API_명세서_Part3.md)

---

HEADER

# 2) 원본 §3~§5 내용 추출 후 추가 (lines 107~1971)
sed -n '107,1971p' /mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md >> /mnt/d/Project/15_SafeTrip_New/Master_docs/36_T2_API_명세서_Part1.md
```

**Step 2: 생성 결과 검증**

```bash
wc -l /mnt/d/Project/15_SafeTrip_New/Master_docs/36_T2_API_명세서_Part1.md
# 예상: ~1,890줄 (헤더 15줄 + 내용 1,865줄)

head -20 /mnt/d/Project/15_SafeTrip_New/Master_docs/36_T2_API_명세서_Part1.md
# 첫 줄: # SafeTrip Backend API 명세서 — Part 1

grep -n "^## §" /mnt/d/Project/15_SafeTrip_New/Master_docs/36_T2_API_명세서_Part1.md
# 예상: §3, §4, §5만 있어야 함
```

---

### Task 2: Part2 파일 생성 (§6~§10 그룹·초대코드·가디언·위치·지오펜스)

**Files:**
- Create: `Master_docs/37_T2_API_명세서_Part2.md`
- Read-only: `Master_docs/35_T2_API_명세서.md` (lines 1972~5018)

**Step 1: Part2 파일 생성**

```bash
cat > /mnt/d/Project/15_SafeTrip_New/Master_docs/37_T2_API_명세서_Part2.md << 'HEADER'
# SafeTrip Backend API 명세서 — Part 2 (§6~§10)

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-037` |
| **상위 인덱스** | [35_T2_API_명세서_INDEX.md](./35_T2_API_명세서_INDEX.md) |
| **범위** | §6 그룹 / §7 초대코드 / §8 가디언 / §9 위치 / §10 지오펜스 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |

> Part 1: [36_T2_API_명세서_Part1.md](./36_T2_API_명세서_Part1.md) | Part 3: [38_T2_API_명세서_Part3.md](./38_T2_API_명세서_Part3.md)

---

HEADER

sed -n '1972,5018p' /mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md >> /mnt/d/Project/15_SafeTrip_New/Master_docs/37_T2_API_명세서_Part2.md
```

**Step 2: 검증**

```bash
wc -l /mnt/d/Project/15_SafeTrip_New/Master_docs/37_T2_API_명세서_Part2.md
# 예상: ~3,060줄

grep -n "^## §" /mnt/d/Project/15_SafeTrip_New/Master_docs/37_T2_API_명세서_Part2.md
# 예상: §6, §7, §8, §9, §10만 있어야 함
```

---

### Task 3: Part3 파일 생성 (§11~§18 이동기록~관련문서)

**Files:**
- Create: `Master_docs/38_T2_API_명세서_Part3.md`
- Read-only: `Master_docs/35_T2_API_명세서.md` (lines 5019~6209)

**Step 1: Part3 파일 생성**

```bash
cat > /mnt/d/Project/15_SafeTrip_New/Master_docs/38_T2_API_명세서_Part3.md << 'HEADER'
# SafeTrip Backend API 명세서 — Part 3 (§11~§18)

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-038` |
| **상위 인덱스** | [35_T2_API_명세서_INDEX.md](./35_T2_API_명세서_INDEX.md) |
| **범위** | §11 이동기록 / §12 FCM / §13 안전가이드 / §14 리더십 / §15 국가·이벤트·위치공유 / §16 공통타입 / §17~§18 이력·참조 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |

> Part 1: [36_T2_API_명세서_Part1.md](./36_T2_API_명세서_Part1.md) | Part 2: [37_T2_API_명세서_Part2.md](./37_T2_API_명세서_Part2.md)

---

HEADER

sed -n '5019,6209p' /mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md >> /mnt/d/Project/15_SafeTrip_New/Master_docs/38_T2_API_명세서_Part3.md
```

**Step 2: 검증**

```bash
wc -l /mnt/d/Project/15_SafeTrip_New/Master_docs/38_T2_API_명세서_Part3.md
# 예상: ~1,210줄

grep -n "^## §" /mnt/d/Project/15_SafeTrip_New/Master_docs/38_T2_API_명세서_Part3.md
# 예상: §11, §12, §13, §14, §15, §15.5, §15.6, §16, §17, §18
```

---

### Task 4: 기존 35번 파일을 INDEX로 교체

**Files:**
- Modify: `Master_docs/35_T2_API_명세서.md` — 전체 내용을 INDEX로 교체

**Step 1: 기존 35번 파일의 §1~§2 내용 확인**

```bash
# §1~§2 내용은 lines 1~106
sed -n '1,106p' /mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md
```

**Step 2: Write 도구로 35번 파일을 INDEX 내용으로 교체**

다음 내용으로 `Master_docs/35_T2_API_명세서.md`를 완전히 교체한다
(Write 도구 사용. 기존 파일을 먼저 Read한 후 Write 가능):

INDEX 파일 내용 구조:
```markdown
# SafeTrip Backend API 명세서 — INDEX

[기존 메타데이터 테이블 유지]

---

## 전체 파트 목차

| 파트 | 파일 | 섹션 | 엔드포인트 수 |
|------|------|------|:---:|
| INDEX | 35_T2_API_명세서.md (이 파일) | §1 목적, §2 공통규칙 | — |
| Part 1 | [36_T2_API_명세서_Part1.md](./36_T2_API_명세서_Part1.md) | §3 인증, §4 사용자, §5 여행 | ~35 |
| Part 2 | [37_T2_API_명세서_Part2.md](./37_T2_API_명세서_Part2.md) | §6 그룹, §7 초대코드, §8 가디언, §9 위치, §10 지오펜스 | ~55 |
| Part 3 | [38_T2_API_명세서_Part3.md](./38_T2_API_명세서_Part3.md) | §11~§18 이동기록~관련문서 | ~30 |

## §1. 목적 및 적용 범위
[기존 §1 내용 그대로]

## §2. 공통 규칙
[기존 §2 내용 그대로]
```

**구체적 구현:**
- `Read` 도구로 `35_T2_API_명세서.md`의 lines 1~106 읽기
- `Write` 도구로 파일 전체를 위 구조로 교체 (메타데이터 + 목차 + §1 + §2)
- `##` 이하 §3~§18 내용은 포함하지 않음

**Step 3: 검증**

```bash
wc -l /mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md
# 예상: ~130줄 (기존 6,209줄에서 대폭 축소)

grep -n "^## §" /mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md
# 예상: §1, §2만 있어야 함

# 4개 파일 존재 확인
ls -la /mnt/d/Project/15_SafeTrip_New/Master_docs/3[5678]_T2_API*.md
```

---

## ━━━━━━━━━━━━ PHASE 2: 버그 검토 (병렬) ━━━━━━━━━━━━

> Task 5, 6, 7은 서로 독립적이므로 3개 에이전트를 동시에 투입한다.

---

### Task 5: Explore Part1 — §3~§5 버그 검토

**Files (Read-only):**
- `Master_docs/36_T2_API_명세서_Part1.md`
- `safetrip-server-api/src/controllers/auth.controller.ts`
- `safetrip-server-api/src/controllers/users.controller.ts`
- `safetrip-server-api/src/controllers/trips.controller.ts`
- `safetrip-server-api/src/routes/auth.routes.ts`
- `safetrip-server-api/src/routes/users.routes.ts`
- `safetrip-server-api/src/routes/trips.routes.ts`

**검토 방법:**

각 엔드포인트에 대해 다음 4개 항목을 코드와 명세서를 대조하여 확인한다:

**항목 1 — Response Body 필드 정확성**
컨트롤러의 `res.json({ ... })` 또는 `res.status(XXX).json({ ... })` 반환값의 최상위 필드명을 명세서 Response 테이블과 대조:
- 명세서에 있는데 코드에 없는 필드 → 오류
- 코드에 있는데 명세서에 없는 필드 → 오류
- 필드 타입 불일치 (명세서: string, 코드: number) → 오류

**항목 2 — HTTP 상태코드 정확성**
컨트롤러의 `res.status(XXX)` 숫자와 명세서 Error Codes 표의 상태코드 대조:
- 성공 응답: 200 vs 201 불일치
- 에러 응답: 400/401/403/404/500 중 실제 코드와 다른 경우

**항목 3 — Request Body 필드명 일치**
컨트롤러의 `req.body.fieldName`, `const { fieldName } = req.body` 추출 패턴과 명세서 Request Body 테이블의 `필드` 열 대조:
- snake_case vs camelCase 불일치
- 명세서에 없는 필수 필드
- 명세서에 있는데 코드에서 사용하지 않는 필드

**항목 4 — 인증 표기 정확성**
라우트 파일에서 `authenticate` 미들웨어 적용 여부와 명세서 "**인증**: 필요/불필요/선택적" 표기 대조:
- 라우트에 `authenticate` 있음 → 명세서 "불필요" → 오류
- 라우트에 `authenticate` 없음 → 명세서 "필요" → 오류

**출력 형식 (반드시 이 형식으로 반환):**

```
## Part1 Explore 결과

### §3.1 POST /api/v1/auth/login
- [없음] 불일치 없음

### §3.2 POST /api/v1/auth/logout
- [있음] 불일치:
  - Response: 명세서에 `token` 필드 있으나 코드에서 반환하지 않음
  - HTTP: 명세서 200, 코드 201

### §4.3 GET /api/v1/users/:userId
- [있음] 불일치:
  - 인증: 명세서 "필요", 라우트에 authenticate 미들웨어 없음

[각 엔드포인트마다 위 형식으로 출력]

---
## 총 불일치 건수: N건
```

---

### Task 6: Explore Part2 — §6~§10 버그 검토

**Files (Read-only):**
- `Master_docs/37_T2_API_명세서_Part2.md`
- `safetrip-server-api/src/controllers/groups.controller.ts`
- `safetrip-server-api/src/controllers/trip-guardian.controller.ts`
- `safetrip-server-api/src/controllers/guardian-view.controller.ts`
- `safetrip-server-api/src/controllers/guardian-messages.controller.ts`
- `safetrip-server-api/src/controllers/locations.controller.ts`
- `safetrip-server-api/src/controllers/location-sharing.controller.ts`
- `safetrip-server-api/src/controllers/geofences.controller.ts`
- `safetrip-server-api/src/routes/groups.routes.ts`
- `safetrip-server-api/src/routes/trip-guardian.routes.ts`
- `safetrip-server-api/src/routes/guardian-view.routes.ts`
- `safetrip-server-api/src/routes/guardian-messages.routes.ts`
- `safetrip-server-api/src/routes/locations.routes.ts`
- `safetrip-server-api/src/routes/geofences.routes.ts`

**검토 방법:** Task 5와 동일한 4개 항목으로 §6~§10 엔드포인트 전체 검토.

**추가 주의 사항:**
- §8 가디언에는 이미 `⚠️` 주석이 있는 부분이 있음 — 이 주석이 코드와 실제로 일치하는지도 재확인
- §9.10 위치공유는 `location-sharing.routes.ts`에 `authenticate` 없음 — "선택적" 표기가 정확한지 확인
- §10 지오펜스 생성이 `groups.routes.ts`에 있음 (`POST /groups/:group_id/geofences`) — 명세서 라우트 경로 확인

**출력 형식:** Task 5와 동일한 형식.

---

### Task 7: Explore Part3 — §11~§18 버그 검토

**Files (Read-only):**
- `Master_docs/38_T2_API_명세서_Part3.md`
- `safetrip-server-api/src/controllers/fcm.controller.ts`
- `safetrip-server-api/src/controllers/guides.controller.ts`
- `safetrip-server-api/src/controllers/mofa.controller.ts`
- `safetrip-server-api/src/controllers/event-log.controller.ts`
- `safetrip-server-api/src/controllers/countries.controller.ts`
- `safetrip-server-api/src/routes/fcm.routes.ts`
- `safetrip-server-api/src/routes/guides.routes.ts`
- `safetrip-server-api/src/routes/mofa.routes.ts`
- `safetrip-server-api/src/routes/event-log.routes.ts`
- `safetrip-server-api/src/routes/countries.routes.ts`
- `safetrip-server-api/src/index.ts`

**검토 방법:** Task 5와 동일한 4개 항목으로 §11~§18 검토.

**추가 주의 사항:**
- §12 FCM: `users.routes.ts`에 등록된 FCM 관련 라우트와 `fcm.routes.ts`의 라우트를 구분해서 확인
- §12.2 `PUT /me/fcm-token`의 라우트 순서 버그 ⚠️ 주석이 정확한지 재확인
- §13 MOFA: 캐시 TTL 30분/7일 설정이 실제 서비스 코드와 일치하는지
- §15 국가: `tb_country` 테이블 미존재 이슈가 명세서에 반영되어 있는지
- §16 공통 타입: 실제 enum/type 정의와 일치하는지 (DB 스키마나 TypeScript 타입 파일 참조)

**출력 형식:** Task 5와 동일한 형식.

---

## ━━━━━━━━━━━━ PHASE 2 → 3 전환 ━━━━━━━━━━━━

### Task 8: 결과 통합 (Controller 직접 수행)

> **이 Task는 주 에이전트(Controller)가 Task 5, 6, 7 결과를 받아 직접 수행한다.**

**Step 1:** Task 5~7의 출력에서 불일치 목록을 파트별로 정리한다.

**Step 2:** 불일치가 없는 파트는 스킵. 불일치가 있는 파트는 Task 9~11로 처리.

---

## ━━━━━━━━━━━━ PHASE 3: 수정 ━━━━━━━━━━━━

### Task 9: Part1 수정 (Task 5 결과 기반)

**Files:**
- Modify: `Master_docs/36_T2_API_명세서_Part1.md`

**Step 1:** Task 5 결과에서 Part1의 불일치 목록 확인.

**Step 2:** 각 불일치에 대해 Edit 도구로 수정:

```
수정 원칙:
- Response 필드 불일치: Response 테이블의 해당 행 수정 (필드명/타입/설명)
- HTTP 상태코드 불일치: Error Codes 표의 해당 행 수정
- Request 필드명 불일치: Request Body 테이블의 해당 행 수정
- 인증 표기 불일치: "**인증**: [변경값]" 한 줄만 수정
- 전체 섹션 재작성 금지
```

**Step 3: 수정 검증 (Grep)**

```bash
# 수정한 내용이 적용되었는지 확인 (예: 인증 표기 수정 시)
grep -n "인증" /mnt/d/Project/15_SafeTrip_New/Master_docs/36_T2_API_명세서_Part1.md | head -20
```

---

### Task 10: Part2 수정 (Task 6 결과 기반)

**Files:**
- Modify: `Master_docs/37_T2_API_명세서_Part2.md`

**Step 1~3:** Task 9와 동일한 프로세스. Task 6 결과 기반.

---

### Task 11: Part3 수정 (Task 7 결과 기반)

**Files:**
- Modify: `Master_docs/38_T2_API_명세서_Part3.md`

**Step 1~3:** Task 9와 동일한 프로세스. Task 7 결과 기반.

---

## ━━━━━━━━━━━━ 완료 ━━━━━━━━━━━━

### Task 12: Notion 기록

**Step 1:** 오늘 날짜(2026-03-02) Notion 개발상세 내역 페이지(`316a19580398815cb74bc9d09481cb4b`)에 토글 블록으로 기록.

토글 제목: `HH:MM — API 명세서 파일 분리(35→36/37/38) + 버그 검토 수정 완료`

내용:
- 분리: 35_T2(INDEX) / 36_T2(Part1) / 37_T2(Part2) / 38_T2(Part3)
- 검토 범위: §3~§18 전체, 4개 항목(Response/HTTP/Request/인증)
- 발견 불일치 N건 수정
