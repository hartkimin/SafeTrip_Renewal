# DB 설계 문서 v3.6 업그레이드 + 교차검증 설계

**날짜**: 2026-03-05
**상태**: 승인됨
**범위**: DB 설계 문서 v3.5.1 → v3.6 업그레이드, API 명세서 교차검증, 관련 문서 업데이트

---

## 1. 배경

SafeTrip 백엔드 구현(TypeORM 엔티티 24개 파일, SQL DDL 12개 파일)과 DB 설계 문서(v3.5.1, 54개 테이블) 간 정합성 검토 결과, **구현에만 존재하는 ~17개 신규 테이블**이 발견되었다. 이를 DB 설계 문서에 반영하고 API 명세서와 교차검증하여 전체 문서 정합성을 확보한다.

## 2. 핵심 변경사항

### 2.1 신규 테이블 17개 추가 (54개 → 71개)

| # | 테이블 | 도메인 | 엔티티 파일 |
|:-:|--------|:------:|-----------|
| 1 | TB_PARENTAL_CONSENT | A | user.entity.ts |
| 2 | TB_COUNTRY_SAFETY | B | country-safety.entity.ts |
| 3 | TB_GEOFENCE_EVENT | D | geofence.entity.ts |
| 4 | TB_GEOFENCE_PENALTY | D | geofence.entity.ts |
| 5 | TB_MOVEMENT_SESSION | E | location.entity.ts |
| 6 | TB_EMERGENCY | F | emergency.entity.ts |
| 7 | TB_EMERGENCY_RECIPIENT | F | emergency.entity.ts |
| 8 | TB_NO_RESPONSE_EVENT | F | emergency.entity.ts |
| 9 | TB_SAFETY_CHECKIN | F | emergency.entity.ts |
| 10 | TB_CHAT_ROOM | G | chat.entity.ts |
| 11 | TB_FCM_TOKEN | H | notification.entity.ts |
| 12 | TB_NOTIFICATION_PREFERENCE | H | notification.entity.ts |
| 13 | TB_REDEEM_CODE | K | payment.entity.ts |
| 14 | TB_B2B_ORGANIZATION | L | b2b.entity.ts |
| 15 | TB_B2B_ADMIN | L | b2b.entity.ts |
| 16 | TB_B2B_DASHBOARD_CONFIG | L | b2b.entity.ts |
| 17 | TB_AI_USAGE | N(신규) | ai.entity.ts |

### 2.2 도메인 변경
- 도메인 수: 13개 → **14개** (N: AI 신규)
- 도메인별 테이블 수 갱신

### 2.3 교차검증 대상 문서
- API 명세서 Part 1~3
- 외부 연동 문서
- API 연동 문서
- API 테스트 보고서

## 3. 작업 순서

1. DB 설계 문서 v3.6 작성 (헤더, 도메인, ERD, 테이블 명세, 인덱스, 부록)
2. API 명세서 Part 1~3 교차검증 + 업데이트
3. 관련 문서 교차검증 + 업데이트
4. 메모리 파일 갱신

## 4. 성공 기준
- 모든 엔티티 테이블이 DB 설계 문서에 정의됨
- API 명세서가 DB 설계 문서와 테이블명/컬럼명 일치
- 메모리 파일이 최신 버전 반영
