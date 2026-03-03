# API 명세서 파일 분리 + 전체 버그 검토 설계

> **작성일**: 2026-03-02
> **목적**: 6,209줄짜리 API 명세서를 4개 파일로 분리하고, 명세서 내용의 정확성(Response/Request 필드, HTTP 상태코드, 인증 표기)을 백엔드 코드 대조 검토 후 수정

## Goal

`Master_docs/35_T2_API_명세서.md`(6,209줄)를 4개 파일로 분리하고,
Explore 에이전트로 §3~§18의 Response Body, HTTP 상태코드, Request Body 필드명, 인증 표기 정확성을 검토하여 불일치를 Edit 도구로 수정한다.

**원칙**: 백엔드 코드(`safetrip-server-api/src/`) 변경 없음. 명세서 문서만 수정.

## Architecture — 3-Phase

### Phase 1: 파일 분리 (순차)

기존 35번 파일을 4개로 분리:

| 파일명 | 섹션 | 라인 범위 (현재 35번 기준) |
|--------|------|--------------------------|
| `35_T2_API_명세서_INDEX.md` | §1~§2 공통규칙 + 전체 목차 | 1~106 + 신규 목차 |
| `36_T2_API_명세서_Part1.md` | §3 인증, §4 사용자, §5 여행 | 107~1,971 |
| `37_T2_API_명세서_Part2.md` | §6 그룹, §7 초대코드, §8 가디언, §9 위치, §10 지오펜스 | 1,972~5,018 |
| `38_T2_API_명세서_Part3.md` | §11~§18 이동기록~관련문서 | 5,019~6,209 |

기존 `35_T2_API_명세서.md`는 INDEX 내용으로 교체 (본문 삭제, 목차 + 공통규칙만 유지).

### Phase 2: 버그 검토 (병렬 3개 Explore 에이전트)

각 에이전트는 해당 파트의 명세서 파일과 대응하는 백엔드 컨트롤러/라우트 파일을 대조:

| 에이전트 | 검토 대상 파트 | 검토 컨트롤러 |
|----------|---------------|--------------|
| Explore A | Part1 (§3~§5) | auth, users, trips 컨트롤러 |
| Explore B | Part2 (§6~§10) | groups, invite-codes, guardian*, locations, geofences 컨트롤러 |
| Explore C | Part3 (§11~§18) | movement-records, fcm, guides, mofa, leader-transfer, countries 컨트롤러 |

**각 에이전트 검토 항목:**
1. **Response Body 필드**: `res.json()` 반환값과 명세서 Response 테이블 대조
2. **HTTP 상태코드**: `res.status(XXX)` 코드와 명세서 Error Codes 대조
3. **Request Body 필드명**: `req.body.fieldName` 추출과 명세서 Request 테이블 대조
4. **인증 표기**: `authenticate` 미들웨어 유무와 명세서 "인증: 필요/불필요" 대조

**출력 형식:**
```
## [파트명] Explore 결과

### §N 엔드포인트명
- [없음] 불일치 없음
- [있음] 불일치 항목:
  - Response: `fieldName` 명세서에 없음 (코드: res.json({ fieldName }))
  - HTTP: 명세서 200 → 실제 201
  - Request: `trip_id` → 코드에서는 `tripId`
  - 인증: 명세서 "필요" → 실제 미들웨어 없음
```

### Phase 3: 수정 (순차)

Phase 2 결과 기반으로 각 Part 파일에 Edit 도구 적용:
- 불일치 없는 섹션: 스킵
- 불일치 있는 섹션: 해당 테이블 행/셀만 수정
- 전체 재작성 금지

## 파일 경로

```
Master_docs/
├── 35_T2_API_명세서_INDEX.md   (신규 — §1~§2 + 전체 목차)
├── 36_T2_API_명세서_Part1.md   (신규 — §3~§5)
├── 37_T2_API_명세서_Part2.md   (신규 — §6~§10)
├── 38_T2_API_명세서_Part3.md   (신규 — §11~§18)
└── 35_T2_API_명세서.md         (기존 → INDEX 내용으로 교체)
```

## 참조 파일 (읽기 전용)

- `safetrip-server-api/src/controllers/` — 컨트롤러 (Response 구조 확인)
- `safetrip-server-api/src/routes/` — 라우트 (인증 미들웨어 확인)
- `safetrip-server-api/src/index.ts` — 전역 라우트 등록 순서

## Tech Stack

- 분리: Write 도구 (신규 파일 생성) + Edit 도구 (35번 INDEX 교체)
- 검토: Explore 에이전트 3개 병렬 (Grep + Read)
- 수정: Edit 도구 (불일치 부분만 교체)
- 저장: `/mnt/d/Project/15_SafeTrip_New/Master_docs/`
