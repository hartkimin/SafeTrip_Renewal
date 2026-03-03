# SafeTrip Backend API 명세서 작성 설계

> **작성일**: 2026-03-02
> **목적**: 백엔드 API의 Request/Response JSON 포맷을 문서화하여 Flutter-백엔드 통합 개발을 지원

## Goal

백엔드 `safetrip-server-api`의 모든 API 엔드포인트에 대해 실제 코드를 분석하여
Request Body, Response Body, Error Codes를 포함한 완전한 API 명세서를 작성한다.

**원칙**:
- 코드베이스(controllers, routes)를 직접 분석하여 실제 구현 기반으로 작성
- 기존 Master_docs 마크다운 포맷 준수
- 전체 재작성이 아닌 실제 구현 추출 방식

## Architecture

- **방식**: Explore 에이전트로 백엔드 코드 분석 → 마크다운 문서 생성
- **형식**: Master_docs 표준 (메타데이터 테이블, 섹션 구조)
- **파일명**: `Master_docs/35_T2_API_명세서.md`

## 문서 구조

| 섹션 | 내용 | 엔드포인트 수 |
|------|------|:---:|
| §1 | 문서 헤더 + 메타데이터 | — |
| §2 | 공통 규칙 (URL, Auth, 에러 코드, 페이지네이션) | — |
| §3 | Auth (로그인, 로그아웃, 프로필 갱신, 토큰 갱신) | ~4 |
| §4 | Users (조회, 수정, 이미지 업로드, 검색) | ~5 |
| §5 | Trips (CRUD, 멤버 관리, 설정, Preview) | ~12 |
| §6 | Groups (생성, 조회, 멤버 추가) | ~4 |
| §7 | Guardians (링크 생성·응답·메시지, 가디언 뷰) | ~7 |
| §8 | Locations (저장, 조회, 위치 공유) | ~4 |
| §9 | Geofences (생성, 조회, 삭제) | ~3 |
| §10 | Movement Records (이동기록, 세션, GPX 내보내기) | ~5 |
| §11 | FCM (토큰 등록) | ~1 |
| §12 | Guides / MOFA (국가 안전 가이드) | ~3 |
| §13 | Invite Codes (생성, 검증) | ~2 |
| §14 | Leader Transfer (리더십 양도) | ~2 |
| §15 | Trip Terms (약관 동의) | ~1 |
| §16 | 공통 타입 정의 (역할 Enum, 상태 Enum) | — |

## 각 엔드포인트 항목 형식

```markdown
#### [METHOD] /[path]

**인증 필요**: 있음/없음
**설명**: 한 줄 설명

**Path Parameters** (해당 시)
| 파라미터 | 타입 | 설명 |
|---------|------|------|
| tripId | string (UUID) | 여행 ID |

**Query Parameters** (해당 시)
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|:----:|------|
| q | string | ✅ | 검색어 |

**Request Body** (POST/PUT/PATCH)
| 필드 | 타입 | 필수 | 설명 |
|------|------|:----:|------|
| fieldName | string | ✅ | 설명 |

**Response** 200
| 필드 | 타입 | 설명 |
|------|------|------|
| fieldName | string | 설명 |

**Error Codes**
| Code | 설명 |
|------|------|
| 400 | 요청 형식 오류 |
| 401 | 인증 실패 |
| 403 | 권한 없음 |
| 404 | 리소스 없음 |
| 500 | 서버 오류 |
```

## 분석 대상 파일

### 컨트롤러 (주 분석 대상)
- `safetrip-server-api/src/controllers/` — 19개 컨트롤러
- `safetrip-server-api/src/routes/` — 21개 라우트 파일

### 서비스 (참조용)
- `safetrip-server-api/src/services/` — 25개 서비스 (응답 구조 확인)

### 미들웨어 (참조용)
- `safetrip-server-api/src/middleware/auth.middleware.ts` — 인증 헤더 형식

## 기준 문서

- `Master_docs/08_T2_SafeTrip_아키텍처_구조_v3_0.md` — §19 기존 엔드포인트 목록
- `Master_docs/07_T2_DB_설계_및_관계_v3_4.md` — 테이블 필드 참조

## Tech Stack

- 분석: Explore 에이전트 (Read, Grep 도구로 controllers/*.ts 순차 분석)
- 생성: Write 도구로 `Master_docs/35_T2_API_명세서.md` 직접 생성
- 저장 경로: `/mnt/d/Project/15_SafeTrip_New/Master_docs/35_T2_API_명세서.md`
