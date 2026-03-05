# DB 설계 문서 v3.6 업그레이드 + API 교차검증 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** DB 설계 문서를 v3.5.1→v3.6으로 업그레이드하여 구현에만 존재하던 17개 신규 테이블을 추가하고, API 명세서와 교차검증하여 문서 정합성을 확보한다.

**Architecture:** 기존 v3.5 문서 구조(13개 도메인, 54개 테이블)를 유지하면서 신규 17개 테이블을 각 도메인에 배치하고 도메인 N(AI)을 신설한다. API 명세서 Part 1~3에서 신규 테이블 미반영 부분을 식별하여 갱신한다.

**Tech Stack:** Markdown 문서, PostgreSQL DDL, TypeORM 엔티티 참조

---

## Task 1: DB 설계 문서 — 헤더 및 변경이력 갱신

**Files:**
- Modify: `Master_docs/07_T2_DB_설계_및_관계_v3_5.md` (lines 1~22 YAML frontmatter + lines 24~57 문서 개요)

**Step 1: YAML frontmatter 갱신**
- `version: v3.5.1` → `version: v3.6`
- 변경이력에 v3.6 항목 추가:
```yaml
  - "v3.6 (2026-03-05): 구현 정합 전면 검토 — 엔티티 기준 신규 17개 테이블 추가 (TB_PARENTAL_CONSENT, TB_COUNTRY_SAFETY, TB_GEOFENCE_EVENT, TB_GEOFENCE_PENALTY, TB_MOVEMENT_SESSION, TB_EMERGENCY, TB_EMERGENCY_RECIPIENT, TB_NO_RESPONSE_EVENT, TB_SAFETY_CHECKIN, TB_CHAT_ROOM, TB_FCM_TOKEN, TB_NOTIFICATION_PREFERENCE, TB_REDEEM_CODE, TB_B2B_ORGANIZATION, TB_B2B_ADMIN, TB_B2B_DASHBOARD_CONFIG, TB_AI_USAGE), 도메인 N(AI) 신규, 도메인 A/B/D/E/F/G/H/K/L 테이블 수 갱신, 부록 A 전체 테이블 목록 갱신 (54개→71개), API 명세서 교차검증 반영"
```

**Step 2: §1 문서 개요 갱신**
- 문서 제목: `v3.5.1` → `v3.6`
- §1.3 변경 요약 테이블: `54개` → `71개`, 변경사항 추가

**Step 3: 검증**
- 헤더의 version이 v3.6인지 확인
- 변경이력이 시간순으로 정렬되어 있는지 확인

---

## Task 2: DB 설계 문서 — §3.1 도메인 영역 분류 갱신

**Files:**
- Modify: `Master_docs/07_T2_DB_설계_및_관계_v3_5.md` (lines 87~107)

**Step 1: 도메인 테이블 수 갱신**

| 도메인 | v3.5 | v3.6 | 추가 테이블 |
|--------|:----:|:----:|-----------|
| A | 2 | **3** | +TB_PARENTAL_CONSENT |
| B | 8 | **9** | +TB_COUNTRY_SAFETY |
| D | 3 | **5** | +TB_GEOFENCE_EVENT, TB_GEOFENCE_PENALTY |
| E | 8 | **9** | +TB_MOVEMENT_SESSION |
| F | 5 | **9** | +TB_EMERGENCY, TB_EMERGENCY_RECIPIENT, TB_NO_RESPONSE_EVENT, TB_SAFETY_CHECKIN |
| G | 4 | **5** | +TB_CHAT_ROOM |
| H | 3 | **5** | +TB_FCM_TOKEN, TB_NOTIFICATION_PREFERENCE |
| K | 4 | **5** | +TB_REDEEM_CODE |
| L | 4 | **7** | +TB_B2B_ORGANIZATION, TB_B2B_ADMIN, TB_B2B_DASHBOARD_CONFIG |
| **N** | — | **1** | TB_AI_USAGE (신규 도메인) |

- 도메인 수: 13 → **14개**
- PostgreSQL 합계: 54 → **71개**

**Step 2: 검증**
- 각 도메인 테이블 수 합계 = 71인지 확인

---

## Task 3: DB 설계 문서 — §3.2 ERD 관계도 보완

**Files:**
- Modify: `Master_docs/07_T2_DB_설계_및_관계_v3_5.md` (lines 109~238)

**Step 1: 각 도메인 ERD 블록에 신규 테이블 관계 추가**

[A] 사용자 및 인증:
```
TB_USER ─── 1:1 → TB_PARENTAL_CONSENT   (user_id)
```

[B] 그룹 및 여행:
```
TB_COUNTRY ─── 1:N → TB_COUNTRY_SAFETY   (country_code)
```

[D] 일정 및 지오펜스:
```
TB_GEOFENCE ─── 1:N → TB_GEOFENCE_EVENT     (geofence_id)
TB_GEOFENCE_EVENT ── 1:N → TB_GEOFENCE_PENALTY (event_id)
```

[E] 위치 및 이동기록:
```
TB_LOCATION ─── N:1 → TB_MOVEMENT_SESSION  (movement_session_id)
```

[F] 안전 및 SOS:
```
TB_EMERGENCY ─── 1:N → TB_EMERGENCY_RECIPIENT (emergency_id)
TB_EMERGENCY ─── N:1 → TB_TRIP                (trip_id)
TB_EMERGENCY ─── N:1 → TB_USER                (user_id)
TB_NO_RESPONSE_EVENT ── N:1 → TB_USER         (user_id)
TB_SAFETY_CHECKIN ── N:1 → TB_USER             (user_id)
```

[G] 채팅:
```
TB_CHAT_ROOM ─── 1:N → TB_CHAT_MESSAGE        (room_id)
TB_CHAT_ROOM ─── N:1 → TB_TRIP                (trip_id)
```

[H] 알림:
```
TB_USER ─── 1:N → TB_FCM_TOKEN                (user_id)
TB_USER ─── 1:N → TB_NOTIFICATION_PREFERENCE   (user_id)
```

[K] 결제/과금:
```
TB_REDEEM_CODE (독립 테이블 — 코드 기반 리딤)
```

[L] B2B:
```
TB_B2B_ORGANIZATION ─── 1:N → TB_B2B_CONTRACT   (org_id)
TB_B2B_ORGANIZATION ─── 1:N → TB_B2B_ADMIN      (org_id)
TB_B2B_ORGANIZATION ─── 1:N → TB_B2B_DASHBOARD_CONFIG (org_id)
```

[N] AI (신규):
```
TB_AI_USAGE ─── N:1 → TB_USER  (user_id)
TB_AI_USAGE ─── N:1 → TB_TRIP  (trip_id)
```

**Step 2: 검증**
- 모든 신규 테이블이 ERD에 표시되었는지 확인

---

## Task 4: DB 설계 문서 — §4 테이블 상세 명세 추가 (17개)

**Files:**
- Modify: `Master_docs/07_T2_DB_설계_및_관계_v3_5.md`

각 테이블에 대해 SQL DDL, 인덱스, 비즈니스 원칙 매핑을 추가한다.
기존 도메인 순서에 맞게 삽입 위치를 결정한다.

**삽입 위치:**
- §4.2 뒤: TB_PARENTAL_CONSENT (§4.2a)
- §4.8 뒤: TB_COUNTRY_SAFETY (§4.8a)
- §4.14 뒤: TB_GEOFENCE_EVENT (§4.14a), TB_GEOFENCE_PENALTY (§4.14b)
- §4.17a 뒤: TB_MOVEMENT_SESSION (§4.17d)
- §4.22b 뒤: TB_EMERGENCY (§4.22c), TB_EMERGENCY_RECIPIENT (§4.22d), TB_NO_RESPONSE_EVENT (§4.22e), TB_SAFETY_CHECKIN (§4.22f)
- §4.23 앞: TB_CHAT_ROOM (§4.22g)
- §4.29 뒤: TB_FCM_TOKEN (§4.29a), TB_NOTIFICATION_PREFERENCE (§4.29b)
- §4.42 뒤: TB_REDEEM_CODE (§4.42a)
- §4.44 앞: TB_B2B_ORGANIZATION (§4.43a), TB_B2B_ADMIN (§4.43b), TB_B2B_DASHBOARD_CONFIG (§4.43c)
- 신규 §4.47a: TB_AI_USAGE (도메인 N)

**DDL 소스:** 엔티티 분석에서 추출한 DDL 사용 (Task Explore 결과)

**Step 1: 각 도메인별로 신규 테이블 DDL 블록을 삽입**

(각 테이블의 DDL은 이미 엔티티 분석에서 추출 완료 — 엔티티와 1:1 매핑)

**Step 2: 검증**
- §4 전체 테이블 수가 71개인지 확인
- 각 DDL에 PK, FK, 인덱스, CHECK 제약이 포함되어 있는지 확인

---

## Task 5: DB 설계 문서 — §5 인덱스, §7 접근 매트릭스, §9 마이그레이션, §10 이슈, §11 우선순위 갱신

**Files:**
- Modify: `Master_docs/07_T2_DB_설계_및_관계_v3_5.md`

**Step 1: §5 인덱스 전체 목록에 신규 테이블 인덱스 추가**
- `idx_geofence_event_trip`, `idx_emergency_trip`, `idx_emergency_user`, `idx_emergency_recipient_emergency`, `idx_safety_checkins_user`, `idx_fcm_token_user`, `idx_ai_usage_user_date` 등

**Step 2: §7 역할별 접근 매트릭스에 신규 테이블 행 추가**
- TB_EMERGENCY: captain RW, crew_chief R, crew R(본인), guardian R(연결)
- TB_CHAT_ROOM: captain RW, crew_chief R, crew R, guardian —
- TB_AI_USAGE: 전 역할 R(본인)
- 기타 신규 테이블 접근 규칙

**Step 3: §9 마이그레이션 목록에 v3.6 섹션 추가**
```markdown
### 9.6 v3.6 구현 정합 마이그레이션 (예정)
```
- 17개 테이블 생성 마이그레이션 파일 목록

**Step 4: §10 알려진 이슈에 v3.6 해소 항목 추가**
- "구현에만 존재하던 17개 테이블 문서 미반영" → ✅ v3.6 해소

**Step 5: §11 구현 우선순위에 신규 테이블 배치**
- P0: TB_EMERGENCY (SOS 핵심), TB_CHAT_ROOM (채팅 컨테이너)
- P1: TB_GEOFENCE_EVENT/PENALTY, TB_FCM_TOKEN, TB_AI_USAGE
- P2: TB_B2B_ORGANIZATION/ADMIN/DASHBOARD, TB_REDEEM_CODE
- P3: TB_PARENTAL_CONSENT, TB_NOTIFICATION_PREFERENCE, TB_MOVEMENT_SESSION

**Step 6: 검증**
- §5 인덱스 수 증가 확인
- §7 매트릭스 행 수 증가 확인

---

## Task 6: DB 설계 문서 — 부록 A 전체 테이블 목록 갱신

**Files:**
- Modify: `Master_docs/07_T2_DB_설계_및_관계_v3_5.md` (lines 2596~2665)

**Step 1: 부록 A 테이블 목록에 17개 신규 테이블 추가**
- 번호 55~71번으로 추가
- 도메인, v3.6 상태(신규), 출처 문서 기재

**Step 2: 부록 B 기능 원칙 문서 → 테이블 매핑 갱신**
- 신규 테이블이 참조하는 원칙 문서 매핑 추가

**Step 3: 검증**
- 부록 A 테이블 수 = 71개 확인
- RTDB 노드 5개 유지 확인

---

## Task 7: API 명세서 교차검증 — Part 1 (Auth, Users, Trips)

**Files:**
- Read & verify: `Master_docs/36_T2_API_명세서_Part1.md`
- Modify if discrepancies found

**Step 1: TB_USER 컬럼 검증**
- deletion_requested_at, deleted_at 컬럼이 User 응답 스키마에 있는지 확인
- TB_PARENTAL_CONSENT 관련 엔드포인트 존재 여부 확인

**Step 2: TB_TRIP 컬럼 검증**
- reactivated_at, reactivation_count 컬럼이 Trip 응답 스키마에 있는지 확인
- b2b_contract_id, has_minor_members 반영 여부 확인

**Step 3: 불일치 발견 시 해당 부분 업데이트**

**Step 4: 검증**
- Part 1의 테이블 참조가 DB v3.6과 일치하는지 확인

---

## Task 8: API 명세서 교차검증 — Part 2 (Groups, Guardians, Locations, Geofences)

**Files:**
- Read & verify: `Master_docs/37_T2_API_명세서_Part2.md`
- Modify if discrepancies found

**Step 1: 누락 섹션 식별**
- §6.F 출석체크(Attendance): TB_ATTENDANCE_CHECK/RESPONSE API 존재 여부
- §8.E 가디언 위치 요청/스냅샷: TB_GUARDIAN_LOCATION_REQUEST/SNAPSHOT API 존재 여부
- §9.11 경로 계획: TB_PLANNED_ROUTE/ROUTE_DEVIATION API 존재 여부
- §10 지오펜스: TB_GEOFENCE_EVENT/PENALTY 관련 응답 스키마

**Step 2: 누락 섹션에 대한 참조 주석 또는 "TODO" 마커 추가**
(전체 엔드포인트 스펙 작성은 별도 작업으로 분리 — 이번 작업 범위는 교차검증)

**Step 3: DB 테이블명/컬럼명 불일치 수정**
- TB_DEVICE_TOKEN vs TB_FCM_TOKEN 명칭 확인
- TB_EMERGENCY vs TB_SOS_EVENT 관계 명확화

**Step 4: 검증**
- Part 2의 모든 테이블 참조가 DB v3.6과 일치

---

## Task 9: API 명세서 교차검증 — Part 3

**Files:**
- Read & verify: `Master_docs/38_T2_API_명세서_Part3.md`
- Modify if discrepancies found

**Step 1: 누락 확인**
- §11 이동기록: TB_MOVEMENT_SESSION 참조 여부
- §12 FCM: TB_FCM_TOKEN 참조 여부
- Chat 섹션: TB_CHAT_ROOM 참조 여부
- AI 섹션: TB_AI_USAGE 참조 여부
- B2B 섹션: TB_B2B_ORGANIZATION/ADMIN/DASHBOARD 참조 여부
- Payment 섹션: TB_REDEEM_CODE 참조 여부

**Step 2: 불일치 발견 시 업데이트**

**Step 3: §16 공통 타입 정의에 누락된 enum 추가**
- payment_type, plan_type, item_type enum
- refund_policy enum
- ai_feature_type enum

**Step 4: 검증**
- Part 3의 모든 테이블 참조가 DB v3.6과 일치

---

## Task 10: 관련 문서 교차검증

**Files:**
- Read & verify: `safetrip-document/02-architecture/external-integrations.md`
- Read & verify: `safetrip-document/05-api/API_연동_문서.md`
- Read & verify: `safetrip-document/05-api/API_테스트_현황_보고서.md`
- Modify if discrepancies found

**Step 1: 외부 연동 문서에서 TB_COUNTRY_SAFETY 참조 확인**
- MOFA API → TB_COUNTRY_SAFETY 매핑이 문서화되어 있는지 확인

**Step 2: API 연동 문서에서 TB_COUNTRY_SAFETY 데이터 구조 확인**

**Step 3: 불일치 발견 시 업데이트**

---

## Task 11: 메모리 파일 갱신

**Files:**
- Modify: `/home/hartk/.claude/projects/-mnt-d-Project-15-SafeTrip-New/memory/MEMORY.md`

**Step 1: "DB 설계 문서" 섹션 갱신**
- 버전: v3.5.1 → v3.6
- 테이블 수: 54 → 71
- v3.6 변경사항 요약 추가

**Step 2: 검증**
- MEMORY.md가 200줄 이내인지 확인

---

## Task 12: Notion 개발상세 내역 기록

**Step 1: 오늘 날짜(2026-03-05) 페이지에 작업 내역 기록**
- 토글: "HH:MM — DB 설계 문서 v3.6 업그레이드 + API 교차검증"
- 내용: 신규 17개 테이블 추가, API 명세서 교차검증 결과

---

## 작업 의존성

```
Task 1 (헤더) ─┐
Task 2 (도메인) ├─→ Task 4 (테이블 명세) ─→ Task 5 (인덱스/매트릭스) ─→ Task 6 (부록)
Task 3 (ERD)  ─┘
                                                                        ↓
                                        Task 7 (API Part 1) ─┐
                                        Task 8 (API Part 2) ─├─→ Task 10 (관련 문서)
                                        Task 9 (API Part 3) ─┘         ↓
                                                                   Task 11 (메모리)
                                                                        ↓
                                                                   Task 12 (Notion)
```

Tasks 1-3 병렬 가능, Tasks 7-9 병렬 가능.
