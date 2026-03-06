# SafeTrip Backend API 명세서 — INDEX

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T2-API-035` |
| **문서 계층** | Tier 2 — 시스템 설계 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |
| **기준 문서** | 아키텍처_구조_v3_0 (#08), DB_설계_v3_4 (#07) |
| **관련 문서** | 프로젝트_구조 (#34), 외부_API_연동 (#33) |

---

## 전체 파트 목차

| 파트 | 파일 | 섹션 | 엔드포인트 수 (약) |
|------|------|------|:---:|
| INDEX (이 파일) | `35_T2_API_명세서.md` | §1 목적, §2 공통규칙 | — |
| Part 1 | [36_T2_API_명세서_Part1.md](./36_T2_API_명세서_Part1.md) | §3 인증, §4 사용자, §5 여행 | 35개 |
| Part 2 | [37_T2_API_명세서_Part2.md](./37_T2_API_명세서_Part2.md) | §6 그룹, §7 초대코드, §8 가디언, §9 위치, §10 지오펜스 | 55개 |
| Part 3 | [38_T2_API_명세서_Part3.md](./38_T2_API_명세서_Part3.md) | §11~§18 이동기록·FCM·안전가이드·리더십·국가·공통타입·이력·참조 | 30개 |
| **Part Admin** | [39_T2_API_명세서_Admin.md](./39_T2_API_명세서_Admin.md) | §A1~§A5 사용자관리·여행관리·SOS관리·결제관리·이벤트로그 (Backoffice 전용) | 10개 |

> 총 **약 120개 이상** 엔드포인트 — 19개 컨트롤러 분석 기반

---

## §1. 목적 및 적용 범위

본 문서는 `safetrip-server-api` 백엔드의 모든 REST API 엔드포인트에 대해
Request Body, Response JSON, Error Codes를 정의한다. Flutter 클라이언트 개발 시
백엔드 코드를 직접 읽지 않아도 이 문서만으로 API 통합이 가능하도록 한다.

**기준**: 실제 컨트롤러 코드 기반. 코드 변경 시 이 문서도 함께 갱신.

| 대상 | 포함 여부 |
|------|----------|
| `safetrip-server-api` REST API | ✅ 전체 포함 |
| Firebase RTDB 스키마 | ✗ (#07 DB 설계 문서 참조) |
| FCM Payload 상세 | △ 등록 API만 포함 |

---

## §2. 공통 규칙

### 2.1 기본 URL

| 환경 | URL |
|------|-----|
| 로컬 (Android 에뮬레이터) | `http://10.0.2.2:3001/api/v1` |
| 로컬 (ngrok) | `https://[ngrok-id].ngrok-free.app/api/v1` |
| 프로덕션 | TBD |

### 2.2 인증 헤더

모든 `/api/v1/*` 엔드포인트(로그인 제외)에 필수:

```
Authorization: Bearer <Firebase_ID_Token>
```

- 토큰 종류: **Firebase ID Token** (JWT). `firebase.auth().currentUser.getIdToken()`으로 Flutter 클라이언트에서 발급.
- `authenticate` 미들웨어가 토큰을 검증하고 `req.userId`(Firebase UID), `req.user`(decoded token — `uid`, `phone_number` 등)를 주입한다.
- 토큰 미포함 또는 `Bearer ` 접두사 없는 경우: `401 Unauthorized: No token provided`
- 토큰 서명 검증 실패 또는 만료: `401 Unauthorized: Invalid or expired token`
- 인증 통과 후 `tb_user`에 해당 UID가 없으면 자동 INSERT (phone_number 기반 auto-upsert).

### 2.3 공통 에러 응답 포맷

```json
{
  "success": false,
  "error": "에러 메시지 설명"
}
```

> **참고**: 개발(development) 환경에서는 `stack` 필드가 추가로 포함된다.
>
> ```json
> {
>   "success": false,
>   "error": "에러 메시지 설명",
>   "stack": "Error: ...\n    at ..."
> }
> ```

### 2.4 공통 에러 코드

| HTTP Code | 의미 |
|:---------:|------|
| 400 | Bad Request — 요청 형식 오류, 필수 필드 누락 |
| 401 | Unauthorized — 인증 토큰 없음 또는 만료 |
| 403 | Forbidden — 권한 부족 (인증은 됐지만 접근 불가) |
| 404 | Not Found — 리소스 없음 |
| 409 | Conflict — 중복 데이터 (이미 존재) |
| 429 | Too Many Requests — Rate limit 초과 |
| 500 | Internal Server Error — 서버 내부 오류 |

### 2.5 Rate Limiting

`express-rate-limit v7` 기반. 응답 헤더는 `RateLimit-*` (draft-7 표준, `X-RateLimit-*` 레거시 헤더 미사용).

| Limiter | 적용 대상 | 윈도우 | 최대 요청 수 | 용도 |
|---------|----------|--------|------------|------|
| `generalLimiter` | 전체 `/api/v1/*` (`/health` 제외) | 15분 | 500회 / IP | DDoS 완화 |
| `authLimiter` | 인증 엔드포인트 (`/api/v1/auth/*`) | 15분 | 20회 / IP | 브루트포스 방지 |
| `locationLimiter` | 위치 업데이트 엔드포인트 | 1분 | 120회 / IP | 실시간 추적 허용 (최대 2회/초) |

Rate limit 초과 시 응답:

```json
{
  "success": false,
  "error": "Too many requests",
  "message": "Rate limit exceeded (500 req / 15min). Please try again later."
}
```

---
