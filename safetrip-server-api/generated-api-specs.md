
### Path: /api/v1/trips
#### [POST] /api/v1/trips
**Summary**: 여행 생성 (그룹+captain+채팅방 자동 생성)

#### [GET] /api/v1/trips
**Summary**: 내 여행 목록 조회


### Path: /api/v1/trips/{tripId}
#### [GET] /api/v1/trips/{tripId}
**Summary**: 여행 상세 조회
**Parameters**:
- tripId (path): string

#### [PATCH] /api/v1/trips/{tripId}
**Summary**: 여행 수정
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/preview/{code}
#### [GET] /api/v1/trips/preview/{code}
**Summary**: 초대 코드로 여행 미리보기
**Parameters**:
- code (path): string


### Path: /api/v1/trips/invite/{inviteCode}
#### [GET] /api/v1/trips/invite/{inviteCode}
**Summary**: 여행자용 초대 코드로 여행 정보 조회
**Parameters**:
- inviteCode (path): string


### Path: /api/v1/trips/verify-invite-code/{code}
#### [GET] /api/v1/trips/verify-invite-code/{code}
**Summary**: 초대 코드 유효성 검증
**Parameters**:
- code (path): string


### Path: /api/v1/trips/join
#### [POST] /api/v1/trips/join
**Summary**: 초대 코드로 그룹에 참여


### Path: /api/v1/trips/{tripId}/schedules
#### [GET] /api/v1/trips/{tripId}/schedules
**Summary**: 여행 일정 목록 조회
**Parameters**:
- tripId (path): string

#### [POST] /api/v1/trips/{tripId}/schedules
**Summary**: 일정 추가
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/schedules/items
#### [POST] /api/v1/trips/{tripId}/schedules/items
**Summary**: 일정 아이템 추가
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/invite
#### [POST] /api/v1/trips/{tripId}/invite
**Summary**: 여행 초대 생성
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/invite/accept
#### [POST] /api/v1/trips/invite/accept
**Summary**: 초대 수락


### Path: /api/v1/trips/guardian/request
#### [POST] /api/v1/trips/guardian/request
**Summary**: 가디언 승인 요청


### Path: /api/v1/trips/guardian/approval-status
#### [GET] /api/v1/trips/guardian/approval-status
**Summary**: 내 가디언 승인 상태 조회


### Path: /api/v1/trips/{tripId}/guardians
#### [POST] /api/v1/trips/{tripId}/guardians
**Summary**: 가디언 추가 (초대)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/{linkId}/respond
#### [PATCH] /api/v1/trips/{tripId}/guardians/{linkId}/respond
**Summary**: 가디언 연결 수락/거절
**Parameters**:
- tripId (path): string
- linkId (path): string


### Path: /api/v1/trips/{tripId}/guardians/{linkId}
#### [DELETE] /api/v1/trips/{tripId}/guardians/{linkId}
**Summary**: 가디언 연결 취소/끊기
**Parameters**:
- tripId (path): string
- linkId (path): string


### Path: /api/v1/trips/{tripId}/guardians/me
#### [GET] /api/v1/trips/{tripId}/guardians/me
**Summary**: 나의 가디언 목록 조회 (여행자 시점)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/pending
#### [GET] /api/v1/trips/{tripId}/guardians/pending
**Summary**: 대기 중인 가디언 초대 목록 조회 (가디언 시점)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/linked-members
#### [GET] /api/v1/trips/{tripId}/guardians/linked-members
**Summary**: 연결된 멤버 목록 조회 (가디언 시점)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/{linkId}/location-request
#### [POST] /api/v1/trips/{tripId}/guardians/{linkId}/location-request
**Summary**: 긴급 위치 요청 (시간당 3회 제한)
**Parameters**:
- linkId (path): string
- tripId (path): string


### Path: /api/v1/trips/{tripId}/guardians/location-request/{requestId}
#### [PATCH] /api/v1/trips/{tripId}/guardians/location-request/{requestId}
**Summary**: 위치 요청 응답
**Parameters**:
- requestId (path): string


### Path: /api/v1/trips/{tripId}/guardians/{linkId}/snapshots
#### [GET] /api/v1/trips/{tripId}/guardians/{linkId}/snapshots
**Summary**: 30분 스냅샷 목록
**Parameters**:
- linkId (path): string


### Path: /api/v1/trips/{tripId}/locations/batch
#### [POST] /api/v1/trips/{tripId}/locations/batch
**Summary**: 9.A.1 위치 데이터 저장 (단건/다건 배치)
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/locations
#### [GET] /api/v1/trips/{tripId}/locations
**Summary**: 9.A.2 특정 멤버의 위치 이력 조회
**Parameters**:
- tripId (path): string
- user_id (query): string
- start_time (query): string
- end_time (query): string


### Path: /api/v1/trips/{tripId}/locations/latest
#### [GET] /api/v1/trips/{tripId}/locations/latest
**Summary**: 9.A.3 그룹 멤버 최신 위치 조회
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/locations/sharing-settings
#### [GET] /api/v1/trips/{tripId}/locations/sharing-settings
**Summary**: 9.A.4 내 위치 공유 설정 조회
**Parameters**:
- tripId (path): string

#### [PATCH] /api/v1/trips/{tripId}/locations/sharing-settings
**Summary**: 9.A.5 내 위치 공유 설정 변경
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/locations/schedules
#### [POST] /api/v1/trips/{tripId}/locations/schedules
**Summary**: 일정 기반 공유 스케줄 설정
**Parameters**:
- tripId (path): string


### Path: /api/v1/trips/{tripId}/locations/stay-points
#### [GET] /api/v1/trips/{tripId}/locations/stay-points
**Summary**: 체류 지점 조회
**Parameters**:
- tripId (path): string


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


### Path: /api/v1/api/v1/groups/{group_id}/geofences
#### [POST] /api/v1/api/v1/groups/{group_id}/geofences
**Summary**: 10.1 지오펜스 생성 (그룹 멤버 등재 확인, 권한 확인 생략)
**Parameters**:
- group_id (path): string


### Path: /api/v1/api/v1/geofences
#### [GET] /api/v1/api/v1/geofences
**Summary**: 10.2 지오펜스 목록 조회
**Parameters**:
- group_id (query): string


### Path: /api/v1/api/v1/geofences/{id}
#### [GET] /api/v1/api/v1/geofences/{id}
**Summary**: 10.3 지오펜스 상세 조회
**Parameters**:
- id (path): string
- group_id (query): string

#### [PATCH] /api/v1/api/v1/geofences/{id}
**Summary**: 10.4 지오펜스 수정
**Parameters**:
- id (path): string
- group_id (query): string

#### [DELETE] /api/v1/api/v1/geofences/{id}
**Summary**: 10.5 지오펜스 삭제
**Parameters**:
- id (path): string
- group_id (query): string


### Path: /api/v1/api/v1/geofences/events
#### [POST] /api/v1/api/v1/geofences/events
**Summary**: 10.6 지오펜스 이벤트 기록

