# SafeTrip UAT 테스트 계획 설계서

**작성일**: 2026-02-27
**환경**: Android/iOS 에뮬레이터 + Firebase Emulator
**접근**: 유저 저니 기반 (혼합 방식: 자동화 스크립트 + 수동 체크리스트)
**우선순위 영역**: 온보딩 전체 흐름, 역할별 주요 기능, 가디언 시스템

---

## 1. 목표

사용자 입장에서 역할별 전체 앱 사용 경험을 검증한다.
최초 설치부터 재로그인, 앱 삭제 후 재설치, 초대코드 가입, 가디언 연결까지 실제 사용 시나리오를 커버한다.
Phase 4에서 발견된 스케줄 API 500 에러도 이번 테스트 사이클에서 수정한다.

---

## 2. 테스트 아키텍처

```
┌─────────────────────────────────────────────────────┐
│  Layer 1: API 자동화 스크립트 (TypeScript/curl)      │
│  역할: 데이터 생성/검증, DB 상태 확인, 응답 코드 검증  │
├─────────────────────────────────────────────────────┤
│  Layer 2: Flutter 수동 체크리스트                    │
│  역할: UI 흐름, 화면 전환, 사용성, 에러 메시지 확인    │
└─────────────────────────────────────────────────────┘
```

### 테스트 계정 (Firebase Emulator)

| 역할 | 전화번호 | 용도 |
|------|---------|------|
| Captain | +821099901001 | 여행 생성, 멤버 관리, 리더 이전 |
| Crew #1 | +821099901002 | 초대코드로 가입, Crew 역할 확인 |
| Crew Chief | +821099901003 | Captain이 승격, 권한 확인 |
| Guardian | +821099901004 | 가디언 역할, 승인/메시지 |
| Crew #2 (재설치 테스트) | +821099901005 | 앱 삭제 후 재설치 시나리오 |

---

## 3. Phase별 테스트 계획

### Phase 1: Captain 온보딩

**목표**: 앱 최초 설치부터 첫 여행 생성까지
**에이전트**: Agent 1

#### Layer 1: API 자동화 검증

```
TC-P1-001: Firebase Auth 계정 생성
  - 입력: +821099901001, 인증코드(emulator)
  - 검증: tb_user INSERT 확인, uid 매핑

TC-P1-002: 여행 생성
  - POST /api/v1/trips
  - 검증: tb_trip, tb_group, tb_group_member(role=captain, trip_id NOT NULL)

TC-P1-003: 초대 코드 생성
  - POST /api/v1/groups/:groupId/invite-codes (type=traveler)
  - POST /api/v1/groups/:groupId/invite-codes (type=guardian)
  - 검증: 2종 코드 생성, is_active=true
```

#### Layer 2: 수동 체크리스트

- [ ] 앱 실행 → Splash 화면 정상 표시
- [ ] 역할 선택 화면: Captain / Crew / Guardian 3개 버튼
- [ ] 초대코드 입력 버튼 별도 노출
- [ ] 전화번호 입력 → SMS 인증 코드 수신 (emulator)
- [ ] 프로필 이름 입력 → 저장
- [ ] Captain Setup: 여행 생성 폼 (여행명, 국가, 날짜)
- [ ] 날짜 선택기 정상 동작
- [ ] 국가 검색 자동완성
- [ ] 저장 후 메인 화면(지도) 진입
- [ ] 초대코드 화면 접근 → Traveler/Guardian 코드 표시

---

### Phase 2: 멤버 초대 및 역할별 권한

**목표**: Crew/Crew Chief 가입 흐름과 권한 분리 검증
**에이전트**: Agent 1

#### Layer 1: API 자동화 검증

```
TC-P2-001: Crew 초대코드 가입
  - POST /api/v1/groups/join-by-code/:code (+821099901002)
  - 검증: tb_group_member.member_role='crew', trip_id NOT NULL

TC-P2-002: Crew Chief 승격
  - PATCH /api/v1/groups/:groupId/members/:userId {role: 'crew_chief'}
  - 검증: is_admin=true

TC-P2-003: 권한 분리 테스트
  - Crew Chief: POST /schedules → 200 OK
  - Crew: POST /schedules → 403 Forbidden
  - Crew: GET /users/search → 403 Forbidden
  - Crew: POST /invite-codes → 403 Forbidden

TC-P2-004: 앱 삭제 후 재설치 (Crew #2)
  - Firebase Auth 계정은 유지, .env 삭제 재설정
  - 동일 전화번호 재인증 후 기존 여행 복원 확인
  - 검증: getUserTrips 응답에 기존 여행 포함
```

#### Layer 2: 수동 체크리스트

- [ ] Crew 앱: "초대코드로 참가" 화면 진입
- [ ] 코드 입력 → 여행 미리보기 화면 표시
- [ ] 가입 확인 → 메인 화면(멤버 지도)
- [ ] 멤버 목록에서 자신의 역할 표시: "여행자"
- [ ] Captain 앱: 멤버 목록 → Crew #1 → 역할 변경 → Crew Chief
- [ ] Crew Chief 앱 재시작 → 스케줄 추가 버튼 표시
- [ ] Crew Chief: Captain 역할 변경 버튼 미표시(비활성)
- [ ] Crew #2: 앱 삭제 후 재설치 → 동일 번호 로그인 → 여행 목록 복원

---

### Phase 3: 가디언 시스템

**목표**: 가디언 연결, 승인 워크플로우, 양방향 메시지 검증
**에이전트**: Agent 2 (전담)

#### 가디언 플로우 다이어그램

```
Guardian 앱 설치 (+821099901004)
       │ 역할선택: Guardian
       │ 전화번호 인증
       ▼
Guardian 온보딩 완료
       │
       ▼
Traveler(+821099901002) → POST /guardian-approval/request {trip_id, guardian_id}
       │                         │
       │                         ▼
       │              Guardian: GET /guardian-approval/pending
       │                         │
       │                         ▼
       │              Guardian: POST /guardian-approval/:id/approve
       │
       ▼
tb_guardian_link.status = 'accepted'
       │
       ├── Member→Guardian 메시지: POST /guardian-messages/member
       └── Guardian→Captain 메시지: POST /guardian-messages/captain
```

#### Layer 1: API 자동화 검증

```
TC-P3-001: Guardian 온보딩
  - Firebase Auth (+821099901004)
  - 검증: tb_user.member_role 가디언 여부

TC-P3-002: 가디언 승인 요청
  - POST /api/v1/trips/:tripId/guardian-approval/request
  - 검증: tb_guardian_link.status='pending'

TC-P3-003: 가디언 승인
  - POST /api/v1/trips/:tripId/guardian-approval/:requestId/approve
  - 검증: tb_guardian_link.status='accepted'

TC-P3-004: Member → Guardian 메시지
  - POST /api/v1/trips/:tripId/guardian-messages/member
  - 검증: RTDB guardian_messages/{tripId}/member_{id1}_{id2}/messages/{msgId}

TC-P3-005: Guardian → Captain 메시지
  - POST /api/v1/trips/:tripId/guardian-messages/captain
  - 검증: RTDB guardian_messages/{tripId}/captain_{guardianId}/messages/{msgId}

TC-P3-006: 읽음 처리
  - PATCH /guardian-messages/:channelId/:messageId/read
  - 검증: RTDB 해당 메시지 read=true
```

#### Layer 2: 수동 체크리스트

- [ ] Guardian 앱: 역할 선택 "Guardian" → 전화번호 인증
- [ ] Guardian 홈 화면 표시 (연결된 여행자 없음 상태)
- [ ] Traveler 앱: 가디언 연결 요청 화면 → Guardian 전화번호 입력
- [ ] Guardian 앱: 승인 요청 알림 수신
- [ ] Guardian 앱: 승인/거절 버튼 → 승인 선택
- [ ] Traveler 앱: 승인 상태 업데이트 (실시간)
- [ ] Guardian 앱: 연결된 여행자 위치 지도에 표시
- [ ] 1:1 메시지 화면 (Guardian ↔ Member) 채팅 UI
- [ ] Guardian → Captain 메시지 채널 분리 확인
- [ ] 읽음 표시 (체크마크/timestamp)

---

### Phase 4: 일상 사용 기능 (+ 스케줄 버그 수정)

**목표**: 스케줄 CRUD, 지오펜스, 출석체크 검증 + 스케줄 API 500 에러 수정
**에이전트**: Agent 1 + Agent 2

#### 스케줄 버그 수정 선행 작업

- `schedule.service.ts`의 스키마 불일치 분석
- `tb_schedule` 실제 스키마와 서비스 코드 비교
- 필요 시 마이그레이션 또는 서비스 코드 수정

#### Layer 1: API 자동화 검증

```
TC-P4-001: 스케줄 생성 (버그 수정 후)
  - POST /api/v1/groups/:groupId/schedules
  - 검증: 200 OK, tb_schedule INSERT

TC-P4-002: 스케줄 조회/수정/삭제
  - GET, PATCH, DELETE 응답 검증

TC-P4-003: 지오펜스 생성
  - POST /api/v1/groups/:groupId/geofences
  - 검증: RTDB realtime_geofences 동기화

TC-P4-004: 출석체크
  - POST /api/v1/groups/:groupId/attendance/start
  - 검증: tb_event_log INSERT (ATTENDANCE_CHECK)
```

#### Layer 2: 수동 체크리스트

- [ ] 스케줄 추가 모달 → 날짜/시간/장소 입력
- [ ] 스케줄 목록에 새 항목 표시
- [ ] 스케줄 수정 → 저장
- [ ] 스케줄 삭제 → 목록에서 제거
- [ ] 지오펜스 생성 (호텔, 200m)
- [ ] 에뮬레이터 위치 mock → 지오펜스 진입 이벤트 확인
- [ ] Captain: 출석체크 시작 버튼
- [ ] Crew 앱: 출석체크 알림 수신 → 응답
- [ ] Captain 앱: 출석 결과 화면

---

### Phase 5: 엣지 케이스

**목표**: 재로그인, 앱 삭제/재설치, 초대코드 직접 가입 검증
**에이전트**: Agent 2

#### 시나리오

```
EC-001: 앱 삭제 후 재설치
  - 기존 Crew 계정 앱 삭제
  - 새 설치 → 역할 선택 없이 "초대코드 입력"
  - 동일 초대코드 입력 → 기존 여행 복원 확인
  - 검증: tb_group_member 중복 없음

EC-002: 토큰 만료 재로그인
  - 장시간 후 앱 재시작 (emulator 시간 조작)
  - 자동 토큰 갱신 또는 재로그인 유도 확인
  - 검증: 기존 상태(여행, 역할) 유지

EC-003: 초대코드로 역할 선택 없이 직접 가입
  - Splash → "초대코드 입력" (역할 선택 건너뜀)
  - Traveler 코드 입력 → 가입 완료
  - 검증: member_role='crew' 자동 할당

EC-004: Captain 역할 이전
  - Captain이 Crew Chief에게 리더십 이전
  - 원 Captain 권한 확인: is_admin=false
  - 새 Captain 확인: is_admin=true, member_role='captain'
```

#### Layer 2: 수동 체크리스트

- [ ] 앱 삭제 후 재설치 → 코드로 직접 가입
- [ ] 재로그인 시 이전 여행 목록 자동 복원
- [ ] 역할 선택 없는 초대코드 가입 흐름
- [ ] 리더 이전 후 원 Captain 앱 권한 변경 확인

---

## 4. 에이전트 팀 구성

| 에이전트 | 담당 Phase | 주요 도구 |
|---------|-----------|---------|
| Agent 1 | Phase 1, 2, 4 API 자동화 | curl/axios, psql, Firebase RTDB |
| Agent 2 | Phase 3 (가디언 전담), Phase 5 | curl/axios, Firebase RTDB |
| Agent 3 | Phase 4 스케줄 버그 분석 및 수정 | Read, Edit, Bash |

---

## 5. 자동화 스크립트 구조

```
scripts/
  test/
    phase1-captain-onboarding.ts   # Captain 온보딩 API 검증
    phase2-member-roles.ts          # 멤버 권한 분리 검증
    phase3-guardian-system.ts       # 가디언 플로우 전체
    phase4-daily-features.ts        # 스케줄/지오펜스/출석
    phase5-edge-cases.ts            # 엣지 케이스
    utils/
      api-client.ts                 # 공통 HTTP 클라이언트
      db-checker.ts                 # PostgreSQL 상태 검증
      firebase-checker.ts           # RTDB 상태 검증
```

---

## 6. 성공 기준

| Phase | 합격 기준 |
|-------|---------|
| Phase 1 | Captain 온보딩 완료, 여행 생성 API 200, 2종 초대코드 생성 |
| Phase 2 | Crew 가입 후 trip_id NOT NULL, 권한 403/200 정확히 분리 |
| Phase 3 | Guardian link status='accepted', RTDB 메시지 경로 정확 |
| Phase 4 | 스케줄 API 500→200 수정 완료, 지오펜스/출석체크 이벤트 기록 |
| Phase 5 | 재설치 후 기존 여행 복원, 중복 member 레코드 없음 |

---

## 7. 알려진 이슈 (사전 인지)

- `schedule.service.ts`: `tb_schedule` 스키마 불일치 → Phase 4에서 수정 포함
- Firebase Auth emulator SMS: `http://localhost:4000/auth` 에서 코드 확인 필요
- Android emulator API URL: `10.0.2.2:3001` (localhost 아님)
