
### Path: /api/v1/auth/firebase-verify
#### [POST] /api/v1/auth/firebase-verify
**Summary**: Firebase Token verify & User UPSERT


### Path: /api/v1/auth/logout
#### [POST] /api/v1/auth/logout
**Summary**: 로그아웃 처리


### Path: /api/v1/auth/verify
#### [POST] /api/v1/auth/verify
**Summary**: 토큰 검증 + 사용자 정보 반환


### Path: /api/v1/auth/register
#### [POST] /api/v1/auth/register
**Summary**: 온보딩 완료 처리


### Path: /api/v1/auth/consent
#### [POST] /api/v1/auth/consent
**Summary**: 동의 기록


### Path: /api/v1/auth/account
#### [DELETE] /api/v1/auth/account
**Summary**: 계정 삭제 요청 (7일 유예)


### Path: /api/v1/auth/cancel-deletion
#### [POST] /api/v1/auth/cancel-deletion
**Summary**: 계정 삭제 취소


### Path: /api/v1/users/register
#### [POST] /api/v1/users/register
**Summary**: 테스트용 사용자 등록


### Path: /api/v1/users/by-phone
#### [GET] /api/v1/users/by-phone
**Summary**: 전화번호로 사용자 조회
**Parameters**:
- phone_number (query): string
- phone_country_code (query): string


### Path: /api/v1/users/search
#### [GET] /api/v1/users/search
**Summary**: 사용자 검색
**Parameters**:
- q (query): string


### Path: /api/v1/users/me
#### [GET] /api/v1/users/me
**Summary**: 내 프로필 조회

#### [PATCH] /api/v1/users/me
**Summary**: 내 프로필 수정


### Path: /api/v1/users/me/location-sharing
#### [PATCH] /api/v1/users/me/location-sharing
**Summary**: 위치 공유 모드 변경


### Path: /api/v1/users/me/device
#### [POST] /api/v1/users/me/device
**Summary**: 디바이스 등록/갱신


### Path: /api/v1/users/me/fcm-token
#### [PUT] /api/v1/users/me/fcm-token
**Summary**: FCM 토큰 등록/갱신 (본인)


### Path: /api/v1/users/me/fcm-token/{tokenId}
#### [DELETE] /api/v1/users/me/fcm-token/{tokenId}
**Summary**: FCM 토큰 비활성화 (본인)
**Parameters**:
- tokenId (path): string


### Path: /api/v1/users/{userId}
#### [GET] /api/v1/users/{userId}
**Summary**: 특정 사용자 조회 (userId)
**Parameters**:
- userId (path): string

#### [PUT] /api/v1/users/{userId}
**Summary**: 테스트용 특정 사용자 프로필 수정
**Parameters**:
- userId (path): string


### Path: /api/v1/users/{userId}/fcm-token
#### [PUT] /api/v1/users/{userId}/fcm-token
**Summary**: 테스트용 특정 사용자 FCM 토큰 등록/갱신
**Parameters**:
- userId (path): string


### Path: /api/v1/users/{id}/terms
#### [PATCH] /api/v1/users/{id}/terms
**Summary**: 약관 동의 기록
**Parameters**:
- id (path): string


### Path: /api/v1/groups/users/{userId}/recent-groups
#### [GET] /api/v1/groups/users/{userId}/recent-groups
**Summary**: 최근 그룹 조회
**Parameters**:
- userId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/summary
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/summary
**Summary**: 9.4 이동 세션 요약 목록 조회
**Parameters**:
- userId (path): string
- need_images (query): string
- target_date (query): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/date-range
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/date-range
**Summary**: 9.5 이동 세션 날짜 범위 조회
**Parameters**:
- userId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/by-date
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/by-date
**Summary**: 9.6 날짜별 이동 세션 목록 조회
**Parameters**:
- userId (path): string
- date (query): string
- need_images (query): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}
**Summary**: 9.7 이동 세션 상세 조회
**Parameters**:
- userId (path): string
- sessionId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/complete
#### [PATCH] /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/complete
**Summary**: 9.8 이동 세션 완료 처리
**Parameters**:
- userId (path): string
- sessionId (path): string


### Path: /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/events
#### [GET] /api/v1/api/v1/locations/users/{userId}/movement-sessions/{sessionId}/events
**Summary**: 9.9 이동 세션 이벤트 목록 조회
**Parameters**:
- userId (path): string
- sessionId (path): string

