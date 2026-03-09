# P0 비즈니스 원칙 정합성 감사 — 수정 설계서

> **문서 목적**: 비즈니스 원칙 v5.1의 P0 Critical 항목 대비 기존 코드 정합성 감사 결과 및 수정 설계
> **기준 문서**: `01_T1_SafeTrip_비즈니스_원칙_v5.1.md`, §17 검증 체크리스트
> **작성일**: 2026-03-07

---

## 1. 감사 범위 및 결과 요약

### 감사 대상 모듈
- Trips (trips.service.ts, trips.controller.ts)
- Groups (groups.service.ts, groups.controller.ts)
- Guardians (guardians.service.ts, guardians.controller.ts)
- Emergencies/SOS (emergencies.service.ts)
- Locations (locations.service.ts)

### 결과 요약

| 결과 | 항목 수 |
|------|:-------:|
| ✅ PASS | 20개 |
| ⚠️ PARTIAL | 6개 |
| ❌ FAIL | 9개 |

---

## 2. 수정 대상 (접근법 A: 서버 비즈니스 로직 검증 6건 우선)

### F4: 캡틴 탈퇴 시 위임 강제 (§07.2, §17#8, #9)
- **파일**: `groups.service.ts` → `removeMember()`
- **현재**: 캡틴이 아무 제약 없이 탈퇴 가능
- **수정**:
  - active/planning 상태 + 다른 멤버 있음 → "리더 위임 먼저" 에러
  - active/planning 상태 + 혼자 → "여행 종료/삭제 먼저" 에러
  - completed 상태 → 위임 없이 탈퇴 허용

### F5: 멤버+가디언 겸직 방지 (§01.2, §17#4)
- **파일**: `groups.service.ts` → `addMember()`, `guardians.service.ts` → `createLink()`
- **현재**: 동일 여행 내 여행멤버이면서 가디언 등록 가능
- **수정**:
  - addMember() 시 해당 유저가 이미 가디언인지 체크
  - createLink() 시 해당 유저가 이미 멤버인지 체크

### F6: UNIQUE(group_id, user_id) 역할 중복 방지 보강 (§17#3)
- **파일**: `groups.service.ts` → `addMember()`
- **현재**: captain만 중복 검사
- **수정**: 동일 user_id가 동일 trip에 이미 active 멤버로 존재하면 거부
  - 실제로는 UNIQUE(group_id, user_id) DB 제약이 이미 처리하지만, 명시적 에러 메시지 필요

### F7: 전체 가디언 여행당 2명 상한 검증 (§03.1, §17#7)
- **파일**: `guardians.service.ts` → `createLink()`
- **현재**: 전체 가디언 상한 검증 없음
- **수정**: `guardianType === 'group'`인 링크가 2개 이상이면 거부

### F8: 개인 가디언 카운트 시 guardian_type 분리 (§03.1, §17#6)
- **파일**: `guardians.service.ts` → `createLink()` 내 quota 카운트
- **현재**: guardian_type 구분 없이 전체 카운트
- **수정**: `guardianType: 'personal'` 조건 추가하여 개인 가디언만 카운트

### F9: 멤버 탈퇴 시 공개범위 자동 정리 (§08.5)
- **파일**: `groups.service.ts` → `removeMember()` 또는 별도 메서드
- **현재**: 탈퇴한 멤버 ID가 다른 멤버의 visibility_member_ids에 잔존
- **수정**: removeMember() 후 tb_location_sharing의 visibility_member_ids에서 해당 유저 제거

---

## 3. 테스트 전략

각 수정 건에 대해 기존 테스트 파일(*.spec.ts)에 테스트 케이스 추가:

| 수정 | 테스트 시나리오 |
|------|---------------|
| F4 | 캡틴이 active 여행에서 탈퇴 시도 → 403, 혼자일 때 → 403, completed → 200 |
| F5 | 가디언이 같은 여행의 멤버로 추가 시도 → 400, 멤버가 같은 여행의 가디언으로 → 400 |
| F6 | 이미 active 멤버인 유저를 같은 여행에 추가 → 400 |
| F7 | 전체 가디언 3번째 추가 시도 → 400 |
| F8 | 개인 가디언 2명 + 전체 가디언 1명 → 개인 3번째 추가 → 400 (전체는 무관) |
| F9 | 멤버 탈퇴 후 다른 멤버의 visibility_member_ids에서 제거됨 확인 |

---

## 4. 영향 범위

- **수정 파일**: 3개 (groups.service.ts, guardians.service.ts, locations.service.ts 또는 groups.service.ts)
- **신규 파일**: 없음
- **DB 변경**: 없음 (애플리케이션 레벨 검증만)
- **API 변경**: 없음 (기존 엔드포인트의 검증 강화만)
