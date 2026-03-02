# Firebase Functions 인벤토리

> 작성일: 2026-03-02 | 참조: 비즈니스 원칙 v5.1

---

## 현재 구현 (2026-03-02)

| 함수명 | 트리거 | 경로/엔드포인트 | 용도 | 상태 |
|--------|--------|----------------|------|:----:|
| `helloWorld` | HTTPS onRequest | `GET /helloWorld` | 테스트용 헬스체크 | 구현됨 |
| `onChatMessageCreated` | RTDB onCreated | `realtime_messages/{groupId}/{messageId}` | 채팅 메시지 생성 시 그룹 멤버 전체에게 FCM 멀티캐스트 푸시 알림 전송 (발신자 제외) | 구현됨 |

### onChatMessageCreated 구현 세부사항

- 파일: `safetrip-firebase-function/src/triggers/chat-message-trigger.ts`
- 토큰 소스: `realtime_tokens/{groupId}/{userId}/token`
- FCM 우선순위: iOS `apns-priority: 10` (high), Android `priority: high`
- 메시지 본문 최대 길이: 100자 (초과 시 `...` 말줄임 처리)
- 실패 토큰 제거 로직: TODO 상태 (미구현)

---

## 필요하지만 미구현

| 함수명 | 트리거 | 주기/조건 | 용도 | 우선순위 | 비즈니스 원칙 |
|--------|--------|----------|------|:-------:|-------------|
| `scheduledDataCleanup` | Cloud Scheduler | 매일 00:00 KST | 여행 종료 후 90일 경과한 채팅 메시지·위치 데이터 익명화, 추가 90일 후 물리 삭제 | P1 | §13.1 데이터 유형별 보존 기간 |
| `scheduledMinorDataCleanup` | Cloud Scheduler | 매일 00:00 KST | 미성년자 위치 데이터 여행 종료 후 30일 경과 시 삭제 | P1 | §13.1 미성년자 위치 데이터 (30일) |
| `onUserAccountDeletion` | Firebase Auth onDelete | 계정 삭제 이벤트 | 계정 삭제 확정 시 RTDB 개인 데이터(프로필·기기 토큰) 정리; 7일 유예 후 만료 처리는 서버 스케줄러 담당 | P1 | §14.4 계정 삭제(탈퇴) 시 데이터 처리 |
| `scheduledAccountDeletionExpiry` | Cloud Scheduler | 매일 02:00 KST | `tb_user.deletion_requested_at` 기준 7일 유예 만료 계정 자동 처리 (즉시삭제/익명화 분기) | P2 | §14.4, 비즈니스 원칙 구현 항목 #51 |
| `onTripStatusChanged` | RTDB onUpdate | `trips/{tripId}/status` 변경 시 | 여행 `completed` 전환 시 실시간 위치 공유 중지 트리거, 가디언 스냅샷 30일 만료 예약 | P2 | §13.1 가디언 스냅샷 (30일), §14.2 여행 삭제 연쇄 처리 |
| `scheduledAttendanceDeadline` | Cloud Scheduler | 1분 간격 (또는 RTDB 트리거) | 출석 체크 `deadline_at` 경과 시 미응답자 자동 `absent` 처리, 캡틴에게 요약 알림 발송 | P2 | §05.3 출석 체크, 비즈니스 원칙 구현 항목 #46 |
| `onGuardianAlert` | HTTPS onCall 또는 RTDB 트리거 | 가디언 긴급 알림 이벤트 | `GUARDIAN_ALERT` 이벤트 발생 시 연결된 멤버에게 고우선순위 FCM 알림 전송 | P2 | §05.2 가디언 긴급 알림 |
| `onSOSTriggered` | RTDB onCreated | `sos_events/{tripId}/{sosId}` | SOS 발생 시 전체 멤버·가디언에게 고우선순위 FCM 즉시 발송 (프라이버시 등급 무관 위치 강제 포함) | P1 | §05.1 SOS, 비즈니스 원칙 구현 항목 #19 |

---

## MVP 개발 계획

### MVP 범위 (현재 구현 + 즉시 필요)

현재 채팅 알림(`onChatMessageCreated`)이 구현되어 있으며 MVP에서 필요한 핵심 기능이다.

`onSOSTriggered`는 비즈니스 원칙 상 P1 이지만, SOS 기능 자체가 MVP 이후 Phase로 분류되어 있으므로 함께 연기한다.

### Phase 2 — 프로덕션 런치 전 필수

- `scheduledDataCleanup`: GDPR/개인정보보호법 준수를 위해 프로덕션 런치 전 반드시 구현
- `onUserAccountDeletion`: Firebase Auth 연동 계정 삭제 처리
- `scheduledAccountDeletionExpiry`: 7일 유예 만료 자동 처리

### Phase 3 — 서비스 안정화 후

- `onTripStatusChanged`: 여행 종료 연쇄 처리
- `scheduledAttendanceDeadline`: 출석 체크 자동화
- `onGuardianAlert`: 가디언 긴급 알림
- `scheduledMinorDataCleanup`: 미성년자 데이터 단축 보존

---

## 참조

- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- Firebase Functions 소스: `safetrip-firebase-function/src/`
- Firebase 에뮬레이터 데이터: `emulator-data/`
- DB 설계: `Master_docs/07_T2_DB_설계_및_관계_v3_4.md` (§13 관련 테이블: `tb_user.deletion_requested_at`)
