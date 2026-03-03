
### Path: /api/v1/users/me/fcm-token
#### [PUT] /api/v1/users/me/fcm-token
**Summary**: FCM 토큰 등록/갱신 (본인)


### Path: /api/v1/users/me/fcm-token/{tokenId}
#### [DELETE] /api/v1/users/me/fcm-token/{tokenId}
**Summary**: FCM 토큰 비활성화 (본인)
**Parameters**:
- tokenId (path): string


### Path: /api/v1/users/{userId}/fcm-token
#### [PUT] /api/v1/users/{userId}/fcm-token
**Summary**: 테스트용 특정 사용자 FCM 토큰 등록/갱신
**Parameters**:
- userId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/events
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/events
**Summary**: 9.9 이동 세션 이벤트 목록 조회
**Parameters**:
- userId (path): string
- sessionId (path): string


### Path: /api/v1/api/v1/geofences/events
#### [POST] /api/v1/api/v1/geofences/events
**Summary**: 10.6 지오펜스 이벤트 기록


### Path: /api/v1/emergencies
#### [POST] /api/v1/emergencies
**Summary**: 긴급 상황 생성 (SOS 포함, 5분 쿨다운)


### Path: /api/v1/emergencies/trip/{tripId}
#### [GET] /api/v1/emergencies/trip/{tripId}
**Summary**: 긴급 상황 이력 조회
**Parameters**:
- tripId (path): string


### Path: /api/v1/emergencies/{emergencyId}/resolve
#### [PATCH] /api/v1/emergencies/{emergencyId}/resolve
**Summary**: 긴급 상황 해제
**Parameters**:
- emergencyId (path): string


### Path: /api/v1/emergencies/{emergencyId}/acknowledge
#### [PATCH] /api/v1/emergencies/{emergencyId}/acknowledge
**Summary**: 긴급 상황 확인
**Parameters**:
- emergencyId (path): string


### Path: /api/v1/emergencies/contacts
#### [GET] /api/v1/emergencies/contacts
**Summary**: 비상 연락처 목록

#### [POST] /api/v1/emergencies/contacts
**Summary**: 비상 연락처 추가


### Path: /api/v1/emergencies/contacts/{contactId}
#### [DELETE] /api/v1/emergencies/contacts/{contactId}
**Summary**: 비상 연락처 삭제
**Parameters**:
- contactId (path): string


### Path: /api/v1/chats/trip/{tripId}/rooms
#### [GET] /api/v1/chats/trip/{tripId}/rooms
**Summary**: 채팅방 목록 조회
**Parameters**:
- tripId (path): string


### Path: /api/v1/chats/rooms/{roomId}/messages
#### [GET] /api/v1/chats/rooms/{roomId}/messages
**Summary**: 채팅 메시지 조회 (커서 기반)
**Parameters**:
- roomId (path): string
- cursor (query): string
- limit (query): number

#### [POST] /api/v1/chats/rooms/{roomId}/messages
**Summary**: 채팅 메시지 전송
**Parameters**:
- roomId (path): string


### Path: /api/v1/chats/rooms/{roomId}/read
#### [POST] /api/v1/chats/rooms/{roomId}/read
**Summary**: 읽음 상태 갱신
**Parameters**:
- roomId (path): string


### Path: /api/v1/fcm/send
#### [POST] /api/v1/fcm/send
**Summary**: 단일 기기 푸시 발송 (테스트)


### Path: /api/v1/fcm/send-multicast
#### [POST] /api/v1/fcm/send-multicast
**Summary**: 다중 기기 푸시 발송 (테스트)


### Path: /api/v1/fcm/history
#### [GET] /api/v1/fcm/history
**Summary**: 내 알림 이력 조회
**Parameters**:
- page (query): string
- limit (query): string


### Path: /api/v1/fcm/history/unread-count
#### [GET] /api/v1/fcm/history/unread-count
**Summary**: 안 읽은 알림 개수 조회


### Path: /api/v1/fcm/history/{notificationId}/read
#### [POST] /api/v1/fcm/history/{notificationId}/read
**Summary**: 알림 읽음 처리
**Parameters**:
- notificationId (path): string


### Path: /api/v1/payments/transaction
#### [POST] /api/v1/payments/transaction
**Summary**: 결제 시작


### Path: /api/v1/payments/transaction/{id}/verify
#### [POST] /api/v1/payments/transaction/{id}/verify
**Summary**: 영수증 검증 및 결제 완료
**Parameters**:
- id (path): string


### Path: /api/v1/payments/transactions
#### [GET] /api/v1/payments/transactions
**Summary**: 결제 이력 조회


### Path: /api/v1/payments/subscription
#### [GET] /api/v1/payments/subscription
**Summary**: 활성 구독 조회

#### [POST] /api/v1/payments/subscription
**Summary**: 구독 생성


### Path: /api/v1/b2b/organizations
#### [GET] /api/v1/b2b/organizations
**Summary**: B2B 조직 목록


### Path: /api/v1/b2b/organizations/{orgId}
#### [GET] /api/v1/b2b/organizations/{orgId}
**Summary**: B2B 조직 상세
**Parameters**:
- orgId (path): string


### Path: /api/v1/b2b/organizations/{orgId}/contracts
#### [GET] /api/v1/b2b/organizations/{orgId}/contracts
**Summary**: 조직 계약 목록
**Parameters**:
- orgId (path): string


### Path: /api/v1/b2b/organizations/{orgId}/admins
#### [GET] /api/v1/b2b/organizations/{orgId}/admins
**Summary**: 조직 관리자 목록
**Parameters**:
- orgId (path): string


### Path: /api/v1/b2b/organizations/{orgId}/dashboard-config
#### [GET] /api/v1/b2b/organizations/{orgId}/dashboard-config
**Summary**: 대시보드 설정 조회
**Parameters**:
- orgId (path): string

#### [POST] /api/v1/b2b/organizations/{orgId}/dashboard-config
**Summary**: 대시보드 설정 저장
**Parameters**:
- orgId (path): string


### Path: /api/v1/countries
#### [GET] /api/v1/countries
**Summary**: 활성 국가 목록 조회


### Path: /api/v1/guides/search
#### [GET] /api/v1/guides/search
**Summary**: 가이드 검색
**Parameters**:
- q (query): string
- country (query): string


### Path: /api/v1/guides/{countryCode}
#### [GET] /api/v1/guides/{countryCode}
**Summary**: 국가별 가이드 조회
**Parameters**:
- countryCode (path): string


### Path: /api/v1/guides/{countryCode}/emergency
#### [GET] /api/v1/guides/{countryCode}/emergency
**Summary**: 긴급 연락처 조회
**Parameters**:
- countryCode (path): string


### Path: /api/v1/events
#### [POST] /api/v1/events
**Summary**: 이벤트 로그 기록

#### [GET] /api/v1/events
**Summary**: 이벤트 로그 조회


### Path: /api/v1/mofa/country/{countryCode}/summary
#### [GET] /api/v1/mofa/country/{countryCode}/summary
**Summary**: 국가 종합 요약 (MOFA)
**Parameters**:
- countryCode (path): string


### Path: /api/v1/mofa/country/{countryCode}/safety
#### [GET] /api/v1/mofa/country/{countryCode}/safety
**Summary**: 국가 안전 정보 (MOFA)
**Parameters**:
- countryCode (path): string


### Path: /api/v1/mofa/country/{countryCode}/entry
#### [GET] /api/v1/mofa/country/{countryCode}/entry
**Summary**: 국가 입국 정보 (MOFA)
**Parameters**:
- countryCode (path): string


### Path: /api/v1/mofa/country/{countryCode}/medical
#### [GET] /api/v1/mofa/country/{countryCode}/medical
**Summary**: 국가 의료 정보 (MOFA)
**Parameters**:
- countryCode (path): string


### Path: /api/v1/mofa/country/{countryCode}/contacts
#### [GET] /api/v1/mofa/country/{countryCode}/contacts
**Summary**: 국가 연락처 정보 (MOFA)
**Parameters**:
- countryCode (path): string

