# TB_EVENT_LOG 이벤트 타입 정의서

## 개요

`TB_EVENT_LOG` 테이블에 기록되는 모든 이벤트 타입과 서브타입을 정의합니다.

**중요**: 서버는 `event_type`과 `event_subtype` 검증을 하지 않으므로, 새로운 이벤트 추가 시 서버 수정이 필요 없습니다.

---

## 이벤트 타입 (event_type)

### 1. geofence
**설명**: 지오펜스 관련 이벤트

**이벤트 타입**: `geofence`

**서브타입 (event_subtype)**:
- `enter`: 지오펜스 진입
- `exit`: 지오펜스 이탈
- `dwell`: 지오펜스 체류

---

#### 1-1. geofence (subtype: enter)
**설명**: 지오펜스 진입 이벤트

**조건**:
- 이전 위치가 지오펜스 밖이고 현재 위치가 지오펜스 안일 때
- `trigger_on_enter = true`인 활성 지오펜스에 진입 시

**필수 필드**:
- `geofence_id`: 지오펜스 ID
- `latitude`, `longitude`: 진입 위치

**event_data 예시**:
```json
{
  "geofence_name": "호텔 주변",
  "geofence_type": "safe",
  "geofence_description": "안전 구역",
  "previous_location": {
    "latitude": 37.5665,
    "longitude": 126.9780
  }
}
```

---

#### 1-2. geofence (subtype: exit)
**설명**: 지오펜스 이탈 이벤트

**조건**:
- 이전 위치가 지오펜스 안이고 현재 위치가 지오펜스 밖일 때
- `trigger_on_exit = true`인 활성 지오펜스에서 이탈 시

**필수 필드**:
- `geofence_id`: 지오펜스 ID
- `latitude`, `longitude`: 이탈 위치

**event_data 예시**:
```json
{
  "geofence_name": "호텔 주변",
  "geofence_type": "safe",
  "previous_location": {
    "latitude": 37.5665,
    "longitude": 126.9780
  }
}
```

---

#### 1-3. geofence (subtype: dwell)
**설명**: 지오펜스 체류 이벤트

**조건**:
- 지오펜스 내에서 `dwell_time_seconds` 이상 체류 시

**필수 필드**:
- `geofence_id`: 지오펜스 ID

---

### 2. session
**설명**: 이동 세션 관련 이벤트

**이벤트 타입**: `session`

**서브타입 (event_subtype)**:
- `start`: 이동 세션 시작
- `end`: 이동 세션 종료 (정상 종료)
- `kill`: 세션 타임아웃 종료
- `premature_end`: 세션 조기 종료

---

#### 4-1. session (subtype: start)
**설명**: 이동 세션 시작

**조건**:
- 사용자가 정지 상태에서 이동 상태로 전환될 때

**필수 필드**:
- `movement_session_id`: 이동 세션 ID
- `latitude`, `longitude`: 세션 시작 위치

**event_data 예시**:
```json
{
  "is_real_moving": true,
  "is_moving": true,
  "activity": {
    "type": "in_vehicle",
    "confidence": 75
  }
}
```

---

#### 4-2. session (subtype: end)
**설명**: 이동 세션 종료

**조건**:
- 사용자가 이동 상태에서 정지 상태로 전환될 때

**필수 필드**:
- `movement_session_id`: 이동 세션 ID
- `latitude`, `longitude`: 세션 종료 위치

**event_data 예시**:
```json
{
  "is_real_moving": false,
  "is_moving": false
}
```

---

#### 4-3. session (subtype: kill)
**설명**: 세션 타임아웃 종료

**조건**:
- 이동 중이지만 8분간 위치 수집이 없을 때 (타임아웃)

**필수 필드**:
- `movement_session_id`: 이동 세션 ID
- `latitude`, `longitude`: 마지막 위치

**event_data 예시**:
```json
{
  "is_real_moving": false,
  "is_moving": false,
  "timeout_minutes": 8
}
```

---

#### 4-4. session (subtype: premature_end)
**설명**: 세션 조기 종료

**조건**:
- 예상 종료 시각 전에 세션이 종료될 때

**필수 필드**:
- `movement_session_id`: 이동 세션 ID
- `latitude`, `longitude`: 종료 위치

---

### 6. session_event
**설명**: 이동 상태 이벤트

**조건**:
- 이동 세션이 활성화된 상태에서 발생하는 이벤트

**필수 필드**:
- `movement_session_id`: 이동 세션 ID

**서브타입 (event_subtype)**:
- `rapid_acceleration`: 급가속
- `rapid_deceleration`: 급감속
- `speeding`: 과속

**event_data 예시 (rapid_acceleration)**:
```json
{
  "speed": {
    "previous": 10.5,
    "current": 18.2
  },
  "acceleration": 2.57,
  "time_delta": 3
}
```

**event_data 예시 (speeding)**:
```json
{
  "speed": {
    "current": 35.5
  },
  "speed_limit": 33.3,
  "exceeded_by": 2.2
}
```

---

### 7. device_status
**설명**: 디바이스 상태 이벤트

**조건**:
- 디바이스 상태 변화 또는 경고 발생 시

**서브타입 (event_subtype)**:
- `battery_warning`: 배터리 경고 (20%, 10%, 5%)
- `mock_location`: Mock 위치 감지
- `location_permission_denied`: 위치 권한 거부
- `network_change`: 네트워크 상태 변화
- `app_lifecycle`: 앱 생명주기 변화
- `location_sharing_enabled`: 위치 공유 활성화
- `location_sharing_disabled`: 위치 공유 비활성화
- `geofencing_enabled`: 지오펜싱 활성화
- `geofencing_disabled`: 지오펜싱 비활성화

**event_data 예시 (battery_warning)**:
```json
{
  "battery": {
    "level": 15,
    "is_charging": false,
    "warning_level": 20
  }
}
```

**event_data 예시 (network_change)**:
```json
{
  "network": {
    "previous_type": "wifi",
    "current_type": "mobile",
    "connectivity_status": "connected"
  }
}
```

**event_data 예시 (location_sharing_enabled)**:
```json
{
  "location_sharing": {
    "previous_value": false,
    "current_value": true,
    "changed_at": "2024-01-15T10:30:00Z"
  }
}
```

**event_data 예시 (online):**
```json
{
  "status": "online"
}
```

**event_data 예시 (offline):**
```json
{
  "status": "offline"
}
```

**참고**: 
- 각 사용자는 자신의 온라인/오프라인 상태만 기록합니다.
- 위치 정보, 배터리 정보 등은 포함하지 않습니다.

---

### 8. sos
**설명**: SOS 긴급 알림

**조건**:
- SOS 알림이 발송될 때

**필수 필드**:
- `sos_id`: SOS 알림 ID
- `latitude`, `longitude`: SOS 발송 위치

**서브타입 (event_subtype)**:
- `emergency`: 일반 긴급 상황
- `crime`: 범죄
- `medical`: 의료 응급

**event_data 예시**:
```json
{
  "alert_type": "emergency",
  "trigger_method": "manual",
  "user_message": "도와주세요"
}
```

---

## 이벤트 서브타입 (event_subtype) 전체 목록

### geofence 관련
- `enter`: 지오펜스 진입
- `exit`: 지오펜스 이탈
- `dwell`: 지오펜스 체류

### session_event 관련
- `rapid_acceleration`: 급가속 (3초 내 5m/s 이상 증가)
- `rapid_deceleration`: 급감속 (3초 내 5m/s 이상 감소)
- `speeding`: 과속 (33.3m/s = 120km/h 초과)

### device_status 관련
- `battery_warning`: 배터리 경고 (20%, 10%, 5%)
- `mock_location`: Mock 위치 감지
- `location_permission_denied`: 위치 권한 거부
- `network_change`: 네트워크 상태 변화 (wifi ↔ mobile ↔ none)
- `app_lifecycle`: 앱 생명주기 변화
- `location_sharing_enabled`: 위치 공유 활성화
- `location_sharing_disabled`: 위치 공유 비활성화
- `geofencing_enabled`: 지오펜싱 활성화
- `geofencing_disabled`: 지오펜싱 비활성화
- `online`: 온라인 상태 전환 (RTDB updated_at 기반, 30분 이내 업데이트) - 각 사용자는 자신의 상태만 기록
- `offline`: 오프라인 상태 전환 (RTDB updated_at 기반, 30분 이상 업데이트 없음) - 각 사용자는 자신의 상태만 기록

### sos 관련
- `emergency`: 일반 긴급 상황
- `crime`: 범죄
- `medical`: 의료 응급

---

## 공통 필드

모든 이벤트에 포함 가능한 필드:

- `user_id` (필수): 사용자 ID
- `group_id` (선택): 그룹 ID (자동 조회)
- `latitude`, `longitude` (선택): 이벤트 발생 위치
- `address` (선택): 주소 (Reverse Geocoding)
- `battery_level` (선택): 배터리 레벨 (0-100)
- `battery_is_charging` (선택): 배터리 충전 중 여부
- `network_type` (선택): 네트워크 타입 (wifi, mobile, none)
- `app_version` (선택): 앱 버전 (예: 1.0.0+1)
- `event_data` (선택): 이벤트별 상세 정보 (JSONB)
- `occurred_at` (선택): 이벤트 발생 시각 (기본값: 현재 시간)

---

## 이벤트 알림 정책

이벤트가 `TB_EVENT_LOG`에 저장된 후, 설정에 따라 푸시 알림이 발송됩니다. 알림 발송은 `event-notification.service.ts`에서 처리됩니다.

### 알림 정책 종류

#### 1. 발송 정책 (send_policy)
- `always`: 항상 알림 발송
- `cooldown`: 쿨다운 시간 내에는 알림 발송 안 함

#### 2. 쿨다운 (cooldown)
- **기준**: `TB_NOTIFICATION` 테이블 (알림 발송 시간)
- **목적**: 같은 이벤트라도 알림 발송 간격 제어
- **동작**: 마지막 알림 발송 시간으로부터 N초 경과 여부 확인
- **예시**: `session_event:rapid_acceleration` - 5분 쿨다운

#### 3. 중복 금지 (prevent_duplicate)
- **기준**: `TB_EVENT_LOG` 테이블 (이벤트 저장 시간)
- **목적**: 앱 재시작 시 같은 이벤트가 중복 저장되는 것 방지
- **동작**: 최근 N초 내 같은 이벤트가 저장되었는지 확인
- **예시**: `geofence:enter` - 5분 내 중복 금지

#### 4. 이전 이벤트 필요 (requires_previous_event)
- **목적**: 특정 이벤트가 발생하기 전에 선행 이벤트가 있어야 알림 발송
- **예시**: `geofence:exit` - `geofence:enter` 이벤트가 먼저 발생해야 알림 발송

### 알림 발송 처리 순서

1. **이전 이벤트 의존성 체크** (`requires_previous_event`)
   - 선행 이벤트가 없으면 알림 발송 중단

2. **쿨다운 체크** (`send_policy === 'cooldown'`)
   - 쿨다운 시간 내이면 알림 발송 중단

3. **중복 금지 체크** (`prevent_duplicate`)
   - 최근 N초 내 같은 이벤트가 있으면 알림 발송 중단

4. **알림 발송**
   - 모든 체크를 통과하면 알림 발송

### 전체 이벤트별 알림 설정

| 이벤트 타입 | 서브타입 | 알림 발송 | 발송 정책 | 쿨다운 | 중복 금지 | 중복 금지 시간 | 이전 이벤트 필요 | 본인 | 보호자 | 관리자 | 그룹 | 우선순위 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| geofence | enter | ✅ | always | - | ✅ | 300초 (5분) | - | ✅ | ❌ | ❌ | ✅ | normal |
| geofence | exit | ✅ | always | - | ❌ | - | geofence:enter | ✅ | ❌ | ❌ | ✅ | normal |
| sos | (null) | ✅ | always | - | ❌ | - | - | ✅ | ✅ | ✅ | ✅ | urgent |
| sos | emergency | ✅ | always | - | ❌ | - | - | ✅ | ✅ | ✅ | ✅ | urgent |
| sos | crime | ✅ | always | - | ❌ | - | - | ✅ | ✅ | ✅ | ✅ | urgent |
| sos | medical | ✅ | always | - | ❌ | - | - | ✅ | ✅ | ✅ | ✅ | urgent |
| session | start | ✅ | always | - | ❌ | - | - | ✅ | ❌ | ✅ | ❌ | normal |
| session | end | ✅ | always | - | ❌ | - | session:start | ✅ | ❌ | ✅ | ❌ | normal |
| session | kill | ✅ | always | - | ❌ | - | session:start | ✅ | ❌ | ✅ | ❌ | normal |
| session | premature_end | ✅ | always | - | ❌ | - | session:start | ✅ | ❌ | ❌ | ❌ | normal |
| session_event | rapid_acceleration | ✅ | cooldown | 300초 (5분) | ❌ | - | - | ✅ | ✅ | ❌ | ❌ | high |
| session_event | rapid_deceleration | ✅ | cooldown | 300초 (5분) | ❌ | - | - | ✅ | ✅ | ❌ | ❌ | high |
| session_event | speeding | ✅ | cooldown | 1800초 (30분) | ❌ | - | - | ✅ | ✅ | ❌ | ❌ | high |
| device_status | battery_warning | ✅ | always | - | ❌ | - | - | ✅ | ❌ | ❌ | ❌ | normal |
| device_status | battery_charging | ❌ | - | - | ❌ | - | - | ❌ | ❌ | ❌ | ❌ | low |
| device_status | mock_location | ✅ | cooldown | 1800초 (30분) | ❌ | - | - | ❌ | ✅ | ✅ | ❌ | high |
| device_status | location_permission_denied | ✅ | cooldown | 1800초 (30분) | ❌ | - | - | ✅ | ✅ | ❌ | ❌ | normal |
| device_status | network_change | ✅ | cooldown | 600초 (10분) | ❌ | - | - | ❌ | ❌ | ❌ | ❌ | low |
| device_status | app_lifecycle | ✅ | cooldown | 300초 (5분) | ❌ | - | - | ❌ | ❌ | ❌ | ❌ | low |
| device_status | location_sharing_enabled | ✅ | always | - | ❌ | - | - | ❌ | ✅ | ❌ | ❌ | low |
| device_status | location_sharing_disabled | ✅ | always | - | ❌ | - | - | ❌ | ✅ | ❌ | ❌ | normal |
| device_status | geofencing_enabled | ✅ | always | - | ❌ | - | - | ❌ | ✅ | ❌ | ❌ | low |
| device_status | geofencing_disabled | ✅ | always | - | ❌ | - | - | ❌ | ✅ | ❌ | ❌ | normal |
| device_status | online | ✅ | always | - | ❌ | - | - | ❌ | ✅ | ✅ | ❌ | normal |
| device_status | offline | ✅ | always | - | ❌ | - | - | ❌ | ✅ | ✅ | ❌ | high |

### 설정 파일 위치

- **서버 설정**: `safetrip-server-api/src/constants/event-notification-config.ts`
- **서비스 구현**: `safetrip-server-api/src/services/event-notification.service.ts`

---

## 새로운 이벤트 추가 가이드

### 1. 이벤트 타입 추가
새로운 `event_type`을 추가할 때:
- 서버 수정 불필요 (검증 없음)
- 앱에서 바로 사용 가능
- 이 문서에 추가하여 관리

### 2. 이벤트 서브타입 추가
기존 `event_type`에 새로운 `event_subtype`을 추가할 때:
- 서버 수정 불필요
- 앱에서 바로 사용 가능
- 이 문서에 추가하여 관리

### 3. 문서 업데이트
새로운 이벤트 추가 시:
1. 이 문서에 `event_type` 또는 `event_subtype` 추가
2. 설명, 조건, 필수 필드, event_data 예시 작성
3. 관련 코드 위치 명시 (선택사항)

---

## 이벤트 기록 위치

### 앱 (Flutter)
- `safetrip-mobile/lib/services/location_service.dart`: 위치 관련 이벤트
- `safetrip-mobile/lib/services/device_status_service.dart`: 디바이스 상태 이벤트
- `safetrip-mobile/lib/services/geofence_manager.dart`: 지오펜스 이벤트
- `safetrip-mobile/lib/services/api_service.dart`: `recordEvent()` 메서드

### 서버 (TypeScript)
- `safetrip-server-api/src/services/geofence.service.ts`: 지오펜스 이벤트 기록
- `safetrip-server-api/src/services/event-log.service.ts`: 이벤트 로그 저장
- `safetrip-server-api/src/controllers/event-log.controller.ts`: API 엔드포인트

---

## 변경 이력

- 2024-01-15: 초기 문서 작성
- 2024-01-15: `location_sharing_enabled`, `location_sharing_disabled` 추가
- 2024-01-15: `geofencing_enabled`, `geofencing_disabled` 추가 (예정)
- 2025-12-18: `battery_charging` 이벤트 제거 (위치 수집 의존성 문제로 인해 제거)
- 2025-12-18: 이벤트 알림 정책 섹션 추가 (쿨다운, 중복 금지 정책 포함)

---

## 참고

- 데이터베이스 스키마: `safetrip-document/database_schema.dbml` (TB_EVENT_LOG 테이블)
- API 엔드포인트: `POST /api/v1/events`
- 서버 검증: `event_type`과 `event_subtype` 검증 없음 (자유롭게 추가 가능)

