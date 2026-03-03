---
date: '2026-03-01'
tags:
  - SafeTrip
  - DB
  - 리뷰
  - 정합성
status: completed
---

# SafeTrip DB 설계 v3.4 재검토 리뷰

> 대상 문서: `Master_docs/07_T2_DB_설계_및_관계_v3_4.md`
> 기준 문서: `01_T1_SafeTrip_비즈니스_원칙_v5.0.md`, `Master_SafeTrip_마스터_원칙_거버넌스_v2_0.md`
> 검토일: 2026-03-01

---

## 이슈 전체 목록

| # | 이슈명 | 심각도 | 테이블/위치 | 상태 |
|:-:|-------|:------:|-----------|:----:|
| C-1 | NOT NULL + ON DELETE SET NULL 충돌 | 🔴 CRITICAL | TB_USER_CONSENT, TB_MINOR_CONSENT, TB_CHAT_POLL | 미해결 |
| C-2 | 삭제 유예기간 7일 vs 30일 불일치 | 🔴 CRITICAL | §4.1 주석 vs §6 표 | 미해결 |
| H-1 | TB_ATTENDANCE 도메인 F vs B 불일치 | 🟠 HIGH | §4.22a/b vs 부록A | 미해결 |
| H-2 | §3.1 E도메인 목록에서 TB_LOCATION_SCHEDULE 누락 | 🟠 HIGH | §3.1 도메인 표 | 미해결 |
| H-3 | §3.1에서 "v3.3 / 51개" 오기 | 🟠 HIGH | line 88, 106 | 미해결 |
| H-4 | ERD에 신규 3개 테이블 관계 없음 | 🟠 HIGH | §3.2 ERD | 미해결 |
| H-5 | TB_LOCATION_SCHEDULE에 timezone 없음 | 🟠 HIGH | §4.15a | 미해결 |
| H-6 | destination_country_code와 country_code 중복 | 🟠 HIGH | §4.4 TB_TRIP | 미해결 |
| M-1 | TB_LOCATION에 trip_id 없어 접근제어 복잡 | 🟡 MEDIUM | §4.16 TB_LOCATION | 미해결 |
| M-2 | TB_LOCATION_SHARING UNIQUE 제약 없음 | 🟡 MEDIUM | §4.15 | 미해결 |
| M-3 | TB_SOS_EVENT.resolved_by FK 누락 | 🟡 MEDIUM | §4.19 | 미해결 |
| M-4 | TB_CHAT_MESSAGE reply_to_id/pinned_by/deleted_by FK 누락 | 🟡 MEDIUM | §4.23 | 미해결 |
| M-5 | TB_GUARDIAN.consent_id FK 불명확 | 🟡 MEDIUM | §4.9 | 미해결 |
| M-6 | B2B 테이블 전방 참조 (SQL 생성 순서) | 🟡 MEDIUM | §4.4, §4.6 | 미해결 |
| M-7 | TB_GUARDIAN 레거시 deprecation 계획 없음 | 🟡 MEDIUM | §4.9 | 미해결 |
| L-1 | 마이그레이션 적용 상태 불명확 | 🟢 LOW | §9.2~9.4 | 미해결 |
| L-2 | 부록 A 테이블 번호 비연속 (C 도메인 분산) | 🟢 LOW | 부록 A | 미해결 |
| L-3 | TB_GUARDIAN_PAUSE 비정규화 동기화 정책 미명시 | 🟢 LOW | §4.11 | 미해결 |
| L-4 | 재활성화 24시간 조건 서비스 레이어 처리 미명시 | 🟢 LOW | §4.4 TB_TRIP | 미해결 |

---

## CRITICAL 상세

### [C-1] NOT NULL + ON DELETE SET NULL 충돌

PostgreSQL에서 NOT NULL 컬럼에 ON DELETE SET NULL을 지정하면, 참조 사용자가 삭제될 때
constraint violation이 발생하여 사용자 삭제 자체가 실패한다.

```sql
-- TB_USER_CONSENT (현재 — 오류)
user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE SET NULL,

-- TB_MINOR_CONSENT (현재 — 오류)
user_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE SET NULL,

-- TB_CHAT_POLL (현재 — 오류)
creator_id VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE SET NULL,
```

**수정 방향**:

```sql
-- TB_USER_CONSENT, TB_MINOR_CONSENT: 법적 보존 목적 → 사용자 삭제를 RESTRICT하거나
-- 소프트 삭제 유예 기간 후 별도 처리 (user_id를 익명화 처리)
user_id VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE RESTRICT,
-- 또는 soft-delete 방식으로 user_id를 익명값으로 업데이트 후 참조 제거

-- TB_CHAT_POLL: creator 정보 손실 허용
creator_id VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
-- NOT NULL 제거
```

관련 마이그레이션: `migration-v3.4-fk-chat-refund-provision.sql` 에 포함 권고.

---

### [C-2] 삭제 유예기간 불일치

| 위치 | 기술 내용 |
|------|----------|
| §4.1 TB_USER 주석 | "7일 유예 후 hard delete" |
| §6 데이터 보관 표 | "삭제 요청 후 30일 유예 → hard delete" |

비즈니스 원칙 v5.0 §14 확인 후 통일 필요.
현재 MEMORY.md는 "7일 유예"로 기록되어 있으나 §6 표는 30일.

---

## HIGH 상세

### [H-1] TB_ATTENDANCE_CHECK/RESPONSE 도메인 불일치

```
§4 배치: [F] 도메인(안전 및 SOS) 아래 — §4.22a/b
§3.1 표: F=5개(TB_HEARTBEAT~TB_SOS_CANCEL_LOG), B=6개(TB_GROUP~TB_COUNTRY)
         → 출석 체크 2개가 어디에도 카운트되지 않음
부록 A:  #53/#54 → 도메인 B 표기
```

**해결 방향**: 비즈니스 원칙 §05.5 "출석 체크"는 SOS와 별개 기능으로 정의됨.
도메인 B로 확정하면:
- §4.22a/b를 [B] 도메인 섹션으로 이동
- §3.1 B행 카운트 6 → 8로 수정
- ERD [B] 도메인에 관계 추가

---

### [H-2] §3.1 E도메인 핵심 테이블 목록 누락

```
현재:
  E 행 | 7 | TB_LOCATION_SHARING, TB_LOCATION, TB_STAY_POINT,
             TB_SESSION_MAP_IMAGE, TB_PLANNED_ROUTE, TB_ROUTE_DEVIATION
             ← 6개 나열 (TB_LOCATION_SCHEDULE 누락)

수정:
  E 행 | 7 | ..., TB_ROUTE_DEVIATION, **TB_LOCATION_SCHEDULE**
```

---

### [H-3] §3.1 버전/테이블 수 오기

```
현재:
  line 88:  "SafeTrip v3.3의 51개 PostgreSQL 테이블은 13개 도메인 영역으로 분류된다."
  line 106: "PostgreSQL 합계: 51개 독립 테이블"

수정:
  line 88:  "SafeTrip v3.4의 54개 PostgreSQL 테이블은 13개 도메인 영역으로 분류된다."
  line 106: "PostgreSQL 합계: 54개 독립 테이블"
```

---

### [H-4] ERD §3.2에 신규 테이블 관계 없음

다음 3개 테이블의 ERD 관계가 §3.2에 없음:

```
TB_LOCATION_SCHEDULE 추가 필요:
  TB_LOCATION_SCHEDULE ─── N:1 → TB_TRIP (trip_id)
                        ─── N:1 → TB_USER (user_id)

TB_ATTENDANCE_CHECK 추가 필요:
  TB_ATTENDANCE_CHECK ─── N:1 → TB_TRIP  (trip_id)
                      ─── N:1 → TB_GROUP (group_id)
                      ─── 1:N → TB_ATTENDANCE_RESPONSE (check_id)

TB_ATTENDANCE_RESPONSE 추가 필요:
  TB_ATTENDANCE_RESPONSE ─── N:1 → TB_ATTENDANCE_CHECK (check_id)
                         ─── N:1 → TB_USER (user_id)
```

---

### [H-5] TB_LOCATION_SCHEDULE timezone 컬럼 없음

국제 여행 시 TIME 타입만으로는 현지 시간 기준 공유 판정이 불가능하다.
TB_TRAVEL_SCHEDULE에는 `timezone VARCHAR(50)` 컬럼이 있는 것과 비대칭.

```sql
-- 수정 제안
ALTER TABLE tb_location_schedule
  ADD COLUMN timezone VARCHAR(50) DEFAULT 'Asia/Seoul';
```

또는 share_start/share_end를 TIMESTAMPTZ 기반으로 재설계.

---

### [H-6] TB_TRIP의 destination_country_code와 country_code 중복

```sql
destination        VARCHAR(200),
destination_city   VARCHAR(200),
destination_country_code VARCHAR(10),  -- 의미?
country_code       VARCHAR(10),        -- 의미?
country_name       VARCHAR(100),       -- 비정규화
```

- `destination_country_code`와 `country_code`가 같은 값을 저장하는지 불명확
- `country_name`은 `TB_COUNTRY`의 비정규화인지?
- 역할 구분을 문서에 명시하거나 하나로 통합 필요

---

## MEDIUM 상세

### [M-1] TB_LOCATION trip_id 부재 → 접근제어 쿼리 복잡

```sql
-- 현재: user_id만 존재
-- 가디언이 "이 여행의 위치 기록"을 조회하려면:
SELECT l.* FROM tb_location l
JOIN tb_group_member gm ON gm.user_id = l.user_id
  AND gm.trip_id = $tripId
  AND gm.status = 'active'
WHERE l.user_id = $memberId
  AND l.recorded_at BETWEEN $trip.start_date AND $trip.end_date;
-- 날짜 조인 + 다중 JOIN 필요
```

### [M-2] TB_LOCATION_SHARING UNIQUE 제약 없음

```sql
-- 추가 권고
ALTER TABLE tb_location_sharing
  ADD CONSTRAINT uq_location_sharing UNIQUE (user_id, trip_id, target_user_id);
-- visibility_type='all'인 경우 target_user_id=NULL이므로 부분 인덱스로 처리 필요
```

### [M-3] TB_SOS_EVENT.resolved_by FK 누락

```sql
-- 현재
resolved_by  VARCHAR(128),  -- FK 없음

-- 수정
resolved_by  VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
```

### [M-4] TB_CHAT_MESSAGE 관련 컬럼 FK 누락

```sql
reply_to_id  BIGINT,         -- 추가: REFERENCES tb_chat_message(message_id) ON DELETE SET NULL
pinned_by    VARCHAR(128),   -- 추가: REFERENCES tb_user(user_id) ON DELETE SET NULL
deleted_by   VARCHAR(128),   -- 추가: REFERENCES tb_user(user_id) ON DELETE SET NULL
```

### [M-5] TB_GUARDIAN.consent_id FK 불명확

```sql
consent_id UUID,  -- 참조 테이블 명시 없음
-- 추가: REFERENCES tb_minor_consent(consent_id) ON DELETE SET NULL
```

### [M-6] B2B 전방 참조 — SQL 생성 순서 주의

TB_TRIP, TB_INVITE_CODE (도메인 B)가 TB_B2B_CONTRACT, TB_B2B_INVITE_BATCH (도메인 L)를 참조.
단일 SQL 파일 실행 시 도메인 L을 먼저 생성해야 함. 마이그레이션 파일 순서 문서화 필요.

### [M-7] TB_GUARDIAN 레거시 deprecation 계획

"향후 TB_GUARDIAN_LINK로 완전 마이그레이션 예정"이라고만 명시됨.
Phase 및 타임라인, 실제 서비스 레이어에서의 사용 여부를 명시해야 함.

---

## LOW 상세

### [L-1] 마이그레이션 파일 적용 상태

§9.2~9.4의 마이그레이션 파일이 "예정"으로 표기되어 있으나, 스키마 정의는 이미 v3.4로 확정됨.
각 마이그레이션 파일에 ✅ 적용됨 / ⏳ 예정 / ❌ 미적용 상태를 명시할 것.

### [L-2] 부록 A 순서 불일치

C 도메인 테이블이 #9~#11과 #50~#51에 분산됨.
재정렬: TB_GUARDIAN_LOCATION_REQUEST(#12), TB_GUARDIAN_SNAPSHOT(#13)으로 이동 권고.

### [L-3] TB_GUARDIAN_PAUSE 비정규화 동기화 정책

v3.4에서 비정규화 목적으로 `group_id`, `guardian_user_id` 추가.
`link_id → TB_GUARDIAN_LINK.guardian_id`와 불일치 방지를 위한 트리거 또는 서비스 레이어 동기화 정책을 문서에 명시해야 함.

### [L-4] 재활성화 24시간 조건 서비스 레이어 처리

```sql
CONSTRAINT chk_reactivation_count CHECK (reactivation_count <= 1)
```

횟수(≤1)만 DB로 강제, 24시간 이내 조건은 서비스 레이어 처리.
이 설계 결정을 §4.4 주석에 명시할 것.

---

## 우선순위별 수정 계획

| 우선순위 | 이슈 | 마이그레이션 파일 제안 |
|:-------:|------|---------------------|
| 🔴 즉시 | C-1: NOT NULL 충돌 | `migration-v3.4-fix-not-null-on-delete.sql` |
| 🔴 즉시 | C-2: 유예기간 확정 | 문서 수정만 필요 |
| 🟠 빠른 | H-1~H-4: 문서 불일치 | 문서 수정 (§3.1, §3.2, 부록 A) |
| 🟠 빠른 | H-5: timezone 추가 | `migration-v3.4-location-schedule-timezone.sql` |
| 🟠 빠른 | H-6: country_code 중복 정리 | 문서 + 스키마 정리 |
| 🟡 보통 | M-2: UNIQUE 제약 | `migration-v3.4-location-sharing-unique.sql` |
| 🟡 보통 | M-3, M-4, M-5: FK 추가 | 기존 `migration-v3.4-fk-*` 파일에 통합 |
| 🟢 나중 | L-1~L-4: 문서 품질 | 다음 문서 리뷰 시 |

---

> 본 리뷰는 비즈니스 원칙 v5.0과의 교차 검토 결과이며,
> 마스터 원칙 거버넌스 v2.0의 변경 전파 규칙에 따라 해당 이슈 해소 후
> 07_T2_DB_설계_및_관계를 v3.5로 버전업할 것을 권고합니다.
