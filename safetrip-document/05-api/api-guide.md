# SafeTrip API 명세서

## 목차
- [개요](#개요)
- [인증](#인증)
- [사용자 관리](#사용자-관리)
- [여행자 관리](#여행자-관리)
- [보호자 관리](#보호자-관리)
- [FCM 전송](#fcm-전송)
- [위치 관리](#위치-관리)
- [지오펜스](#지오펜스)
- [그룹 관리](#그룹-관리)
- [여행 관리](#여행-관리)
- [가이드](#가이드)
- [이벤트 로그](#이벤트-로그)
- [헬스체크](#헬스체크)
- [에러 처리](#에러-처리)

---

## 개요

### 기본 정보
- **Base URL (Production)**: `https://api.safetrip.io/v1`
- **Base URL (Staging)**: `https://api-staging.safetrip.io/v1`
- **프로토콜**: HTTPS only
- **데이터 형식**: JSON
- **인증 방식**: Firebase ID Token (일부 엔드포인트는 JWT Bearer Token)

### 인증 흐름

SafeTrip은 **Firebase Authentication**을 사용합니다.

```
1. 클라이언트에서 Firebase Authentication으로 로그인
2. Firebase ID Token 획득
3. POST /auth/firebase-verify → 서버에서 토큰 검증 및 사용자 동기화
4. 이후 API 요청 시 Authorization 헤더에 토큰 포함 (필요한 경우)
```

**토큰 사용 예시:**
```bash
# Firebase 인증
curl -X POST https://api.safetrip.io/v1/auth/firebase-verify \
  -H "Content-Type: application/json" \
  -d '{"id_token": "firebase_id_token_here"}'

# API 요청 시 헤더에 토큰 포함 (인증이 필요한 경우)
curl -X GET https://api.safetrip.io/v1/users/me \
  -H "Authorization: Bearer <firebase_id_token>"
```

### HTTP 상태 코드
| 코드 | 의미 | 설명 |
|------|------|------|
| 200 | OK | 요청 성공 |
| 201 | Created | 리소스 생성 성공 |
| 204 | No Content | 요청 성공 (응답 본문 없음) |
| 400 | Bad Request | 잘못된 요청 |
| 401 | Unauthorized | 인증 실패 |
| 403 | Forbidden | 권한 없음 |
| 404 | Not Found | 리소스 없음 |
| 409 | Conflict | 리소스 충돌 (중복 등) |
| 429 | Too Many Requests | 요청 제한 초과 |
| 500 | Internal Server Error | 서버 오류 |

### 응답 형식

모든 API는 다음 형식으로 응답합니다:

**성공 응답:**
```json
{
  "success": true,
  "data": { ... },
  "message": "Optional message"
}
```

**에러 응답:**
```json
{
  "success": false,
  "error": "Error message"
}
```

---

## 인증

### `/auth/firebase-verify` - Firebase ID Token 검증 및 사용자 동기화

Firebase Authentication으로 로그인한 후 ID Token을 서버에서 검증하고 사용자 정보를 동기화합니다.

**메서드**: `POST`  
**경로**: `/api/v1/auth/firebase-verify`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "id_token": "firebase_id_token_here",
  "phone_country_code": "+82"
}
```

**요청 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| id_token | string | ✅ | Firebase ID Token |
| phone_country_code | string | ❌ | 전화번호 국가 코드 (기본값: "+82") |

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "firebase_uid",
    "phone_number": "+821012345678",
    "phone_country_code": "+82",
    "display_name": "홍길동",
    "is_new_user": false,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

**에러 응답:**
- `400`: `id_token is required`
- `400`: `Phone number not found in token`
- `401`: `Invalid or expired token`
- `500`: `Firebase verification failed`

---

### `/auth/logout` - 로그아웃

**메서드**: `POST`  
**경로**: `/api/v1/auth/logout`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "message": "Logout successful"
  }
}
```

---

## 사용자 관리

### `/users/register` - 사용자 등록 (테스트용)

**메서드**: `POST`  
**경로**: `/api/v1/users/register`  
**인증**: ❌ 불필요 (테스트용)

**요청:**
```json
{
  "user_id": "user123",
  "display_name": "홍길동",
  "phone_number": "+821012345678",
  "phone_country_code": "+82"
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "user123",
    "display_name": "홍길동",
    "phone_number": "+821012345678",
    "phone_country_code": "+82",
    "created_at": "2024-01-01T00:00:00Z"
  },
  "message": "User registered successfully"
}
```

---

### `/users/by-phone` - 전화번호로 사용자 조회

**메서드**: `GET`  
**경로**: `/api/v1/users/by-phone?phone_number=+821012345678`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| phone_number | string | ✅ | E.164 형식 전화번호 |

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "user123",
    "phone_number": "+821012345678",
    "display_name": "홍길동"
  }
}
```

---

### `/users/:userId` - 사용자 조회

**메서드**: `GET`  
**경로**: `/api/v1/users/:userId`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "user123",
    "phone_number": "+821012345678",
    "display_name": "홍길동",
    "profile_image_url": "https://...",
    "location_sharing_mode": "precise",
    "location_sharing_enabled": true,
    "geofencing_enabled": true
  }
}
```

---

### `/users/:userId` - 사용자 프로필 업데이트

**메서드**: `PUT`  
**경로**: `/api/v1/users/:userId`  
**인증**: ❌ 불필요 (Firebase 인증 후 사용)

**요청:**
```json
{
  "display_name": "홍길동",
  "profile_image_url": "https://...",
  "location_sharing_mode": "precise"
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "user123",
    "display_name": "홍길동",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/users/me` - 현재 사용자 정보 조회

**메서드**: `GET`  
**경로**: `/api/v1/users/me`  
**인증**: ✅ 필요 (JWT Bearer Token)

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "user123",
    "phone_number": "+821012345678",
    "display_name": "홍길동",
    "profile_image_url": "https://...",
    "location_sharing_mode": "precise",
    "location_sharing_enabled": true,
    "geofencing_enabled": true,
    "last_active_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/users/me` - 현재 사용자 정보 수정

**메서드**: `PATCH`  
**경로**: `/api/v1/users/me`  
**인증**: ✅ 필요 (JWT Bearer Token)

**요청:**
```json
{
  "display_name": "홍길동",
  "profile_image_url": "https://...",
  "location_sharing_mode": "precise",
  "location_sharing_enabled": true
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "user123",
    "display_name": "홍길동",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/users/me/fcm-token` - FCM 토큰 등록/업데이트

**메서드**: `PUT`  
**경로**: `/api/v1/users/me/fcm-token`  
**인증**: ✅ 필요 (JWT Bearer Token)

**요청:**
```json
{
  "device_token": "fcm_token_string",
  "platform": "android",
  "device_id": "device123",
  "device_model": "Samsung Galaxy S21",
  "os_version": "13",
  "app_version": "1.0.0"
}
```

**요청 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| device_token | string | ✅ | FCM 토큰 |
| platform | string | ✅ | "android" 또는 "ios" |
| device_id | string | ❌ | 디바이스 고유 ID |
| device_model | string | ❌ | 디바이스 모델 |
| os_version | string | ❌ | OS 버전 |
| app_version | string | ❌ | 앱 버전 |

**응답:**
```json
{
  "success": true,
  "data": {
    "token_id": "token123",
    "device_token": "fcm_token_string",
    "platform": "android",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/users/me/fcm-token/:tokenId` - FCM 토큰 삭제

**메서드**: `DELETE`  
**경로**: `/api/v1/users/me/fcm-token/:tokenId`  
**인증**: ✅ 필요 (JWT Bearer Token)

**응답:**
```json
{
  "success": true,
  "data": {
    "message": "FCM token deleted successfully"
  }
}
```

---

## 여행자 관리

### `/travelers/register` - 여행자 등록 (테스트용)

**메서드**: `POST`  
**경로**: `/api/v1/travelers/register`  
**인증**: ❌ 불필요 (테스트용)

**요청:**
```json
{
  "user_id": "user123",
  "trip_id": "trip123",
  "group_id": "group123"
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "traveler_id": "traveler123",
    "user_id": "user123",
    "trip_id": "trip123",
    "group_id": "group123"
  },
  "message": "Traveler registered successfully"
}
```

---

### `/travelers/:travelerId/last-location` - 여행자 마지막 위치 조회

**메서드**: `GET`  
**경로**: `/api/v1/travelers/:travelerId/last-location`  
**인증**: ✅ 필요 (JWT Bearer Token - 보호자 권한)

**응답:**
```json
{
  "success": true,
  "data": {
    "location_id": "loc123",
    "user_id": "user123",
    "latitude": 37.5665,
    "longitude": 126.9780,
    "accuracy": 10.5,
    "recorded_at": "2024-01-01T00:00:00Z",
    "address": "서울특별시 강남구",
    "city": "서울",
    "country": "대한민국"
  }
}
```

---

## 보호자 관리

### `/guardians/:guardianId/travelers` - 여행자 목록 조회

**메서드**: `GET`  
**경로**: `/api/v1/guardians/:guardianId/travelers`  
**인증**: ❌ 불필요 (추후 인증 추가 예정)

**응답:**
```json
{
  "success": true,
  "data": [
    {
      "traveler_id": "traveler123",
      "user_id": "user123",
      "display_name": "홍길동",
      "phone_number": "+821012345678",
      "last_location": {
        "latitude": 37.5665,
        "longitude": 126.9780,
        "recorded_at": "2024-01-01T00:00:00Z"
      }
    }
  ]
}
```

---

## FCM 전송

### `/fcm/travelers/:travelerId/notify` - 여행자에게 알림 전송

**메서드**: `POST`  
**경로**: `/api/v1/fcm/travelers/:travelerId/notify`  
**인증**: ✅ 필요 (JWT Bearer Token)

**요청:**
```json
{
  "title": "알림 제목",
  "body": "알림 내용",
  "data": {
    "type": "location_request",
    "group_id": "group123"
  }
}
```

**요청 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| title | string | ✅ | 알림 제목 |
| body | string | ✅ | 알림 내용 |
| data | object | ❌ | 추가 데이터 (키-값 쌍) |

**응답:**
```json
{
  "success": true,
  "data": {
    "message_id": "msg123",
    "success_count": 1,
    "failure_count": 0
  }
}
```

---

## 위치 관리

### `/locations` - 위치 업로드

**메서드**: `POST`  
**경로**: `/api/v1/locations`  
**인증**: ❌ 불필요 (테스트용, 추후 인증 추가 예정)

**요청:**
```json
{
  "user_id": "user123",
  "latitude": 37.5665,
  "longitude": 126.9780,
  "accuracy": 10.5,
  "altitude": 50.0,
  "speed": 5.2,
  "heading": 90.0,
  "battery_level": 85,
  "network_type": "wifi",
  "tracking_mode": "normal",
  "movement_session_id": "session123",
  "is_movement_start": false,
  "is_movement_end": false,
  "activity_type": "in_vehicle",
  "activity_confidence": 75,
  "recorded_at": "2024-01-01T00:00:00Z",
  "group_id": "group123"
}
```

**요청 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| user_id | string | ✅ | 사용자 ID |
| latitude | number | ✅ | 위도 |
| longitude | number | ✅ | 경도 |
| accuracy | number | ❌ | 정확도 (미터) |
| altitude | number | ❌ | 고도 (미터) |
| speed | number | ❌ | 속도 (m/s) |
| heading | number | ❌ | 방향 (도) |
| battery_level | number | ❌ | 배터리 레벨 (0-100) |
| network_type | string | ❌ | 네트워크 타입 |
| tracking_mode | string | ❌ | 추적 모드 |
| movement_session_id | string | ❌ | 이동 세션 ID |
| is_movement_start | boolean | ❌ | 이동 시작 여부 |
| is_movement_end | boolean | ❌ | 이동 종료 여부 |
| activity_type | string | ❌ | 활동 타입 |
| activity_confidence | number | ❌ | 활동 신뢰도 (0-100) |
| recorded_at | string | ❌ | 기록 시간 (ISO 8601) |
| group_id | string | ❌ | 그룹 ID |

**응답:**
```json
{
  "success": true,
  "data": {
    "location_id": "loc123",
    "recorded_at": "2024-01-01T00:00:00Z"
  },
  "message": "Location saved successfully"
}
```

---

### `/locations/latest` - 최신 위치 조회

**메서드**: `GET`  
**경로**: `/api/v1/locations/latest?user_id=user123`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| user_id | string | ✅ | 사용자 ID |

**응답:**
```json
{
  "success": true,
  "data": {
    "location_id": "loc123",
    "user_id": "user123",
    "latitude": 37.5665,
    "longitude": 126.9780,
    "accuracy": 10.5,
    "recorded_at": "2024-01-01T00:00:00Z",
    "address": "서울특별시 강남구",
    "city": "서울",
    "country": "대한민국"
  }
}
```

---

### `/locations/history` - 위치 이력 조회

**메서드**: `GET`  
**경로**: `/api/v1/locations/history?user_id=user123&limit=100`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| user_id | string | ✅ | 사용자 ID |
| limit | number | ❌ | 조회 개수 (기본값: 100) |

**응답:**
```json
{
  "success": true,
  "data": [
    {
      "location_id": "loc123",
      "latitude": 37.5665,
      "longitude": 126.9780,
      "recorded_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

---

### `/locations/users/:userId/movement-sessions/summary` - 이동 세션 요약 리스트 조회

**메서드**: `GET`  
**경로**: `/api/v1/locations/users/:userId/movement-sessions/summary`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| page | number | ❌ | 페이지 번호 (기본값: 1) |
| limit | number | ❌ | 페이지당 개수 (기본값: 20) |
| need_images | string | ❌ | 이미지가 필요한 세션 ID (쉼표로 구분) |
| target_date | string | ❌ | 대상 날짜 (YYYY-MM-DD) |
| timezone_offset | number | ❌ | 시간대 오프셋 (시간 단위, 기본값: 0) |

**응답:**
```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "movement_session_id": "session123",
        "location_count": 150,
        "start_time": "2024-01-01T00:00:00Z",
        "end_time": "2024-01-01T12:00:00Z",
        "start_latitude": 37.5665,
        "start_longitude": 126.9780,
        "end_latitude": 37.5666,
        "end_longitude": 126.9781,
        "start_address": "서울특별시 강남구",
        "end_address": "서울특별시 강남구",
        "total_distance_km": 5.2,
        "is_completed": true,
        "map_image_url": "https://..."
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 10,
      "total_pages": 1
    }
  }
}
```

---

### `/locations/users/:userId/movement-sessions/date-range` - 세션 날짜 범위 조회

**메서드**: `GET`  
**경로**: `/api/v1/locations/users/:userId/movement-sessions/date-range`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| timezone_offset | number | ❌ | 시간대 오프셋 (시간 단위, 기본값: 0) |

**응답:**
```json
{
  "success": true,
  "data": {
    "earliest_date": "2024-01-01",
    "latest_date": "2024-12-31",
    "date_list": ["2024-01-01", "2024-01-02", ...]
  }
}
```

---

### `/locations/users/:userId/movement-sessions/by-date` - 날짜별 세션 리스트 조회

**메서드**: `GET`  
**경로**: `/api/v1/locations/users/:userId/movement-sessions/by-date?date=2024-01-01`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| date | string | ✅ | 날짜 (YYYY-MM-DD 형식) |
| timezone_offset | number | ❌ | 시간대 오프셋 (시간 단위, 기본값: 0) |
| need_images | string | ❌ | 이미지가 필요한 세션 ID (쉼표로 구분) |

**응답:**
```json
{
  "success": true,
  "data": [
    {
      "movement_session_id": "session123",
      "location_count": 150,
      "start_time": "2024-01-01T00:00:00Z",
      "end_time": "2024-01-01T12:00:00Z",
      "start_latitude": 37.5665,
      "start_longitude": 126.9780,
      "end_latitude": 37.5666,
      "end_longitude": 126.9781,
      "start_address": "서울특별시 강남구",
      "end_address": "서울특별시 강남구",
      "total_distance_km": 5.2,
      "is_completed": true
    }
  ]
}
```

---

### `/locations/users/:userId/movement-sessions/:sessionId` - 세션 상세 조회

**메서드**: `GET`  
**경로**: `/api/v1/locations/users/:userId/movement-sessions/:sessionId`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "movement_session_id": "session123",
    "location_count": 150,
    "start_time": "2024-01-01T00:00:00Z",
    "end_time": "2024-01-01T12:00:00Z",
    "start_latitude": 37.5665,
    "start_longitude": 126.9780,
    "end_latitude": 37.5666,
    "end_longitude": 126.9781,
    "start_address": "서울특별시 강남구",
    "end_address": "서울특별시 강남구",
    "total_distance_km": 5.2,
    "is_completed": true,
    "locations": [
      {
        "location_id": "loc123",
        "latitude": 37.5665,
        "longitude": 126.9780,
        "recorded_at": "2024-01-01T00:00:00Z"
      }
    ]
  }
}
```

---

### `/locations/users/:userId/movement-sessions/:sessionId/complete` - 세션 완료 처리

**메서드**: `PATCH`  
**경로**: `/api/v1/locations/users/:userId/movement-sessions/:sessionId/complete`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "latitude": 37.5666,
  "longitude": 126.9781,
  "recorded_at": "2024-01-01T12:00:00Z"
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "movement_session_id": "session123",
    "is_completed": true,
    "completed_at": "2024-01-01T12:00:00Z"
  }
}
```

---

### `/locations/users/:userId/movement-sessions/:sessionId/events` - 세션의 이벤트 목록 조회

**메서드**: `GET`  
**경로**: `/api/v1/locations/users/:userId/movement-sessions/:sessionId/events`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": [
    {
      "event_id": "event123",
      "event_type": "geofence_enter",
      "event_subtype": "place",
      "latitude": 37.5665,
      "longitude": 126.9780,
      "address": "서울특별시 강남구",
      "occurred_at": "2024-01-01T06:00:00Z"
    }
  ]
}
```

---

## 지오펜스

### `/geofences` - 지오펜스 목록 조회

**메서드**: `GET`  
**경로**: `/api/v1/geofences?group_id=group123`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| group_id | string | ✅ | 그룹 ID |

**응답:**
```json
{
  "success": true,
  "data": {
    "geofences": [
      {
        "geofence_id": "geofence123",
        "group_id": "group123",
        "name": "호텔",
        "type": "place",
        "shape_type": "circle",
        "center_latitude": 37.5665,
        "center_longitude": 126.9780,
        "radius_meters": 100,
        "is_active": true
      }
    ],
    "total": 1
  }
}
```

---

### `/geofences/:id` - 지오펜스 상세 조회

**메서드**: `GET`  
**경로**: `/api/v1/geofences/:id?group_id=group123`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| group_id | string | ✅ | 그룹 ID |

**응답:**
```json
{
  "success": true,
  "data": {
    "geofence_id": "geofence123",
    "group_id": "group123",
    "name": "호텔",
    "type": "place",
    "shape_type": "circle",
    "center_latitude": 37.5665,
    "center_longitude": 126.9780,
    "radius_meters": 100,
    "is_active": true,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/geofences/:id` - 지오펜스 수정

**메서드**: `PATCH`  
**경로**: `/api/v1/geofences/:id`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "name": "호텔 (수정)",
  "radius_meters": 150
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "geofence_id": "geofence123",
    "name": "호텔 (수정)",
    "radius_meters": 150,
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/geofences/:id` - 지오펜스 삭제

**메서드**: `DELETE`  
**경로**: `/api/v1/geofences/:id`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "message": "Geofence deleted successfully"
  }
}
```

---

### `/geofences/events` - 지오펜스 이벤트 기록

**메서드**: `POST`  
**경로**: `/api/v1/geofences/events`  
**인증**: ❌ 불필요 (flutter_background_geolocation에서 자동 전송)

**요청:**
```json
{
  "geofence": {
    "identifier": "geofence123",
    "action": "ENTER"
  },
  "location": {
    "coords": {
      "latitude": 37.5665,
      "longitude": 126.9780
    },
    "uuid": "user123"
  },
  "params": {
    "user_id": "user123"
  }
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "event_id": "event123",
    "message": "Geofence event recorded successfully"
  }
}
```

---

## 그룹 관리

### `/groups/join/:invite_code` - 그룹 참여 (초대 코드)

**메서드**: `POST`  
**경로**: `/api/v1/groups/join/:invite_code`  
**인증**: ❌ 불필요

**요청 본문:**
```json
{
  "user_id": "user123"
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "group_id": "group123",
    "group_name": "제주도 여행",
    "member_id": "member123",
    "role": "member"
  }
}
```

---

### `/groups/:group_id/my-permission` - 현재 사용자의 권한 조회

**메서드**: `GET`  
**경로**: `/api/v1/groups/:group_id/my-permission?user_id=user123`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| user_id | string | ✅ | 사용자 ID |

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "user123",
    "can_view_all_locations": true,
    "is_admin": false,
    "can_edit_schedule": true,
    "can_edit_geofence": false
  }
}
```

---

### `/groups/:group_id` - 그룹 상세 조회

**메서드**: `GET`  
**경로**: `/api/v1/groups/:group_id`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "group_id": "group123",
    "group_name": "제주도 여행",
    "invite_code": "ABC123",
    "owner_user_id": "owner123",
    "status": "active",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/groups/:group_id/members` - 그룹 멤버 목록 조회

**메서드**: `GET`  
**경로**: `/api/v1/groups/:group_id/members`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": [
    {
      "member_id": "member123",
      "user_id": "user123",
      "display_name": "홍길동",
      "role": "member",
      "special_role": null,
      "joined_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

---

### `/groups/:group_id/members` - 그룹 멤버 초대

**메서드**: `POST`  
**경로**: `/api/v1/groups/:group_id/members`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "user_id": "user123",
  "role": "member"
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "member_id": "member123",
    "user_id": "user123",
    "role": "member",
    "joined_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/groups/:group_id/members/:user_id` - 멤버 권한 변경

**메서드**: `PATCH`  
**경로**: `/api/v1/groups/:group_id/members/:user_id`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "role": "admin",
  "can_edit_schedule": true,
  "can_edit_geofence": true
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "member_id": "member123",
    "role": "admin",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/groups/:group_id/members/:user_id` - 멤버 제거

**메서드**: `DELETE`  
**경로**: `/api/v1/groups/:group_id/members/:user_id`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "message": "Member removed successfully"
  }
}
```

---

### `/groups/:group_id/schedules` - 일정 목록 조회

**메서드**: `GET`  
**경로**: `/api/v1/groups/:group_id/schedules`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": [
    {
      "schedule_id": "schedule123",
      "group_id": "group123",
      "title": "제주공항 도착",
      "location_coords": {
        "latitude": 33.5112,
        "longitude": 126.4928
      },
      "scheduled_time": "2024-01-01T10:00:00Z",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

---

### `/groups/:group_id/schedules` - 일정 생성

**메서드**: `POST`  
**경로**: `/api/v1/groups/:group_id/schedules`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "title": "제주공항 도착",
  "location_coords": {
    "latitude": 33.5112,
    "longitude": 126.4928
  },
  "scheduled_time": "2024-01-01T10:00:00Z"
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "schedule_id": "schedule123",
    "title": "제주공항 도착",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/groups/:group_id/schedules/:schedule_id` - 일정 수정

**메서드**: `PATCH`  
**경로**: `/api/v1/groups/:group_id/schedules/:schedule_id`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "title": "제주공항 도착 (수정)",
  "scheduled_time": "2024-01-01T11:00:00Z"
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "schedule_id": "schedule123",
    "title": "제주공항 도착 (수정)",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

---

### `/groups/:group_id/schedules/:schedule_id` - 일정 삭제

**메서드**: `DELETE`  
**경로**: `/api/v1/groups/:group_id/schedules/:schedule_id`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "message": "Schedule deleted successfully"
  }
}
```

---

### `/groups/:group_id/geofences` - 지오펜스 생성

**메서드**: `POST`  
**경로**: `/api/v1/groups/:group_id/geofences`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "name": "호텔",
  "type": "place",
  "shape_type": "circle",
  "center_latitude": 37.5665,
  "center_longitude": 126.9780,
  "radius_meters": 100
}
```

**응답:**
```json
{
  "success": true,
  "data": {
    "geofence_id": "geofence123",
    "name": "호텔",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

---

## 여행 관리

### `/trips/groups/:group_id/countries` - 그룹의 국가 코드 목록 조회

**메서드**: `GET`  
**경로**: `/api/v1/trips/groups/:group_id/countries`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "group_id": "group123",
    "countries": [
      {
        "country_code": "KR",
        "country_name_ko": "대한민국",
        "trip_id": "trip123"
      },
      {
        "country_code": "JP",
        "country_name_ko": "일본",
        "trip_id": "trip124"
      }
    ],
    "country_codes": ["KR", "JP"],
    "count": 2
  }
}
```

---

### `/trips/users/:user_id/countries` - 사용자의 국가 코드 목록 조회

**메서드**: `GET`  
**경로**: `/api/v1/trips/users/:user_id/countries`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "user_id": "user123",
    "country_codes": ["KR", "JP", "US"],
    "count": 3
  }
}
```

---

### `/trips/groups/:group_id/timezones` - 그룹의 타임존 정보 조회

**메서드**: `GET`  
**경로**: `/api/v1/trips/groups/:group_id/timezones`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "group_id": "group123",
    "timezones": [
      {
        "country_code": "KR",
        "timezone": "Asia/Seoul",
        "offset_hours": 9
      },
      {
        "country_code": "JP",
        "timezone": "Asia/Tokyo",
        "offset_hours": 9
      }
    ],
    "count": 2
  }
}
```

---

## 가이드

### `/guides/search` - 가이드 검색

**메서드**: `GET`  
**경로**: `/api/v1/guides/search?q=검색어&country=KR`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| q | string | ✅ | 검색어 |
| country | string | ❌ | 국가 코드 (필터링) |

**응답:**
```json
{
  "success": true,
  "data": {
    "query": "검색어",
    "country": "KR",
    "results": [
      {
        "country_code": "KR",
        "title": "대한민국 여행 가이드",
        "content": "..."
      }
    ],
    "count": 1
  }
}
```

---

### `/guides/:countryCode` - 국가별 가이드 조회

**메서드**: `GET`  
**경로**: `/api/v1/guides/:countryCode`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "country_code": "KR",
    "country_name_ko": "대한민국",
    "content": {
      "overview": "...",
      "safety": "...",
      "culture": "..."
    }
  }
}
```

---

### `/guides/:countryCode/emergency` - 긴급 연락처 조회

**메서드**: `GET`  
**경로**: `/api/v1/guides/:countryCode/emergency`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "success": true,
  "data": {
    "country_code": "KR",
    "emergency_contacts": {
      "police": "112",
      "fire": "119",
      "ambulance": "119",
      "tourist_hotline": "1330"
    },
    "embassy_info": {
      "address": "...",
      "phone": "..."
    }
  }
}
```

---

## 이벤트 로그

### `/events` - 이벤트 로그 기록

**메서드**: `POST`  
**경로**: `/api/v1/events`  
**인증**: ❌ 불필요

**요청:**
```json
{
  "user_id": "user123",
  "group_id": "group123",
  "event_type": "geofence_enter",
  "event_subtype": "place",
  "latitude": 37.5665,
  "longitude": 126.9780,
  "address": "서울특별시 강남구",
  "battery_level": 85,
  "battery_is_charging": false,
  "network_type": "wifi",
  "app_version": "1.0.0",
  "geofence_id": "geofence123",
  "movement_session_id": "session123",
  "location_id": "loc123",
  "sos_id": null,
  "event_data": {
    "custom_field": "value"
  },
  "occurred_at": "2024-01-01T00:00:00Z"
}
```

**요청 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| user_id | string | ✅ | 사용자 ID |
| event_type | string | ✅ | 이벤트 타입 |
| group_id | string | ❌ | 그룹 ID |
| event_subtype | string | ❌ | 이벤트 서브타입 |
| latitude | number | ❌ | 위도 |
| longitude | number | ❌ | 경도 |
| address | string | ❌ | 주소 |
| battery_level | number | ❌ | 배터리 레벨 |
| battery_is_charging | boolean | ❌ | 충전 중 여부 |
| network_type | string | ❌ | 네트워크 타입 |
| app_version | string | ❌ | 앱 버전 |
| geofence_id | string | ❌ | 지오펜스 ID |
| movement_session_id | string | ❌ | 이동 세션 ID |
| location_id | string | ❌ | 위치 ID |
| sos_id | string | ❌ | SOS ID |
| event_data | object | ❌ | 추가 이벤트 데이터 |
| occurred_at | string | ❌ | 발생 시간 (ISO 8601) |

**응답:**
```json
{
  "success": true,
  "data": {
    "event_id": "event123",
    "message": "Event log recorded successfully"
  }
}
```

---

### `/events` - 이벤트 로그 조회

**메서드**: `GET`  
**경로**: `/api/v1/events?user_id=user123&event_type=geofence_enter&limit=100&offset=0`  
**인증**: ❌ 불필요

**쿼리 파라미터:**
| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| user_id | string | ❌ | 사용자 ID (필터) |
| group_id | string | ❌ | 그룹 ID (필터) |
| event_type | string | ❌ | 이벤트 타입 (필터) |
| event_subtype | string | ❌ | 이벤트 서브타입 (필터) |
| limit | number | ❌ | 조회 개수 (기본값: 100) |
| offset | number | ❌ | 오프셋 (기본값: 0) |
| since | string | ❌ | 시작 시간 (ISO 8601) |

**응답:**
```json
{
  "success": true,
  "data": {
    "events": [
      {
        "event_id": "event123",
        "user_id": "user123",
        "event_type": "geofence_enter",
        "event_subtype": "place",
        "latitude": 37.5665,
        "longitude": 126.9780,
        "occurred_at": "2024-01-01T00:00:00Z"
      }
    ],
    "count": 1
  }
}
```

---

## 헬스체크

### `/health` - 서버 상태 확인

**메서드**: `GET`  
**경로**: `/health`  
**인증**: ❌ 불필요

**응답:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00Z",
  "database": "connected",
  "firebase": "connected"
}
```

---

## 에러 처리

### 에러 응답 형식

모든 에러는 다음 형식으로 반환됩니다:

```json
{
  "success": false,
  "error": "Error message"
}
```

### 주요 에러 코드

| HTTP 코드 | 에러 메시지 | 설명 |
|----------|------------|------|
| 400 | `{field} is required` | 필수 필드 누락 |
| 400 | `Invalid {field}` | 잘못된 필드 값 |
| 401 | `Invalid or expired token` | 토큰이 유효하지 않음 |
| 401 | `Unauthorized` | 인증 필요 |
| 403 | `Forbidden` | 권한 없음 |
| 404 | `{resource} not found` | 리소스를 찾을 수 없음 |
| 409 | `{resource} already exists` | 리소스 중복 |
| 500 | `Internal server error` | 서버 오류 |

### 에러 처리 예시

```bash
# 필수 필드 누락
curl -X POST https://api.safetrip.io/v1/locations \
  -H "Content-Type: application/json" \
  -d '{"latitude": 37.5665}'

# 응답
{
  "success": false,
  "error": "longitude is required"
}
```

---

## 참고 문서

- [데이터베이스 스키마](../03-database/database-readme.md)
- [Firebase Realtime Database](../04-firebase/firebase-rtdb.md)
- [배포 가이드](../01-getting-started/deployment.md)
- [환경 변수 설정](../01-getting-started/env-config.md)
