# 이벤트 알림 채널 및 설정 가이드

## 개요

SafeTrip 앱의 이벤트 알림 시스템은 이벤트 타입별로 알림 채널을 분리하여 사용자가 설정에서 카테고리별로 알림을 관리할 수 있도록 합니다. 또한 본인/타인 이벤트를 구분하여 표시하고, 같은 ID의 알림은 업데이트하여 알림이 과도하게 쌓이지 않도록 합니다.

## 알림 채널 목록

### 1. foreground_location (기존)
- **설명**: 포어그라운드 서비스 알림
- **생성**: `flutter_background_geolocation` 라이브러리가 자동 생성
- **중요도**: 높음
- **사용자 제어**: 불가 (서비스 유지 필요)
- **알림 ID**: 1 (라이브러리 내부 사용)

### 2. geofence_events
- **설명**: 지오펜스 진입/이탈 알림
- **이벤트 타입**: `geofence`
- **서브타입**: `enter`, `exit`
- **중요도**: 보통
- **사용자 제어**: 가능
- **알림 ID 범위**: 해시 기반 (0-999999)

### 3. sos_events
- **설명**: SOS 긴급 알림
- **이벤트 타입**: `sos`
- **서브타입**: `emergency`, `crime`, `medical`
- **중요도**: 긴급
- **사용자 제어**: 불가 (안전 관련)
- **알림 ID 범위**: 해시 기반 (0-999999)

### 4. session_events
- **설명**: 이동 세션 시작/종료 알림
- **이벤트 타입**: `session`
- **서브타입**: `start`, `end`, `kill`, `premature_end`
- **중요도**: 보통
- **사용자 제어**: 가능
- **알림 ID 범위**: 해시 기반 (0-999999)

### 5. danger_events
- **설명**: 위험 상황 알림 (급가속, 급감속, 과속)
- **이벤트 타입**: `session_event`
- **서브타입**: `rapid_acceleration`, `rapid_deceleration`, `speeding`
- **중요도**: 높음
- **사용자 제어**: 가능
- **알림 ID 범위**: 해시 기반 (0-999999)

### 6. device_status_events
- **설명**: 디바이스 상태 알림
- **이벤트 타입**: `device_status`
- **서브타입**: `battery_warning`, `offline`, `mock_location` 등
- **중요도**: 낮음~높음 (이벤트별 상이)
- **사용자 제어**: 가능
- **알림 ID 범위**: 해시 기반 (0-999999)

## 이벤트 타입별 상세 정보

### geofence (지오펜스 이벤트)

#### enter (진입)
- **조건**: 지오펜스에 진입 시
- **알림 제목 (본인)**: "지오펜스 진입: {지오펜스명}"
- **알림 제목 (타인)**: "{이름}님이 지오펜스에 진입했습니다"
- **알림 채널**: `geofence_events`
- **알림 ID**: `getNotificationId(eventType: 'geofence', eventSubtype: 'enter', userId: userId, relatedId: geofenceId)`

#### exit (이탈)
- **조건**: 지오펜스에서 이탈 시
- **알림 제목 (본인)**: "지오펜스 이탈: {지오펜스명}"
- **알림 제목 (타인)**: "{이름}님이 지오펜스에서 이탈했습니다"
- **알림 채널**: `geofence_events`
- **알림 ID**: `getNotificationId(eventType: 'geofence', eventSubtype: 'exit', userId: userId, relatedId: geofenceId)`

### sos (SOS 긴급 알림)

#### emergency, crime, medical
- **조건**: SOS 알림 발송 시
- **알림 제목 (본인)**: "SOS 긴급 알림"
- **알림 제목 (타인)**: "{이름}님이 SOS 알림을 보냈습니다"
- **알림 채널**: `sos_events`
- **알림 ID**: `getNotificationId(eventType: 'sos', eventSubtype: subtype, userId: userId, relatedId: sosId)`

### session (이동 세션 이벤트)

#### start (시작)
- **조건**: 이동 세션 시작 시
- **알림 제목 (본인)**: "이동 시작"
- **알림 제목 (타인)**: "{이름}님이 이동을 시작했습니다"
- **알림 채널**: `session_events`

#### end (종료)
- **조건**: 이동 세션 종료 시
- **알림 제목 (본인)**: "이동 종료"
- **알림 제목 (타인)**: "{이름}님이 이동을 종료했습니다"
- **알림 채널**: `session_events`

### session_event (위험 상황 이벤트)

#### rapid_acceleration (급가속)
- **조건**: 3초 내 5m/s 이상 속도 증가
- **알림 제목 (본인)**: "급가속 감지"
- **알림 제목 (타인)**: "{이름}님의 급가속이 감지되었습니다"
- **알림 채널**: `danger_events`

#### rapid_deceleration (급감속)
- **조건**: 3초 내 5m/s 이상 속도 감소
- **알림 제목 (본인)**: "급감속 감지"
- **알림 제목 (타인)**: "{이름}님의 급감속이 감지되었습니다"
- **알림 채널**: `danger_events`

#### speeding (과속)
- **조건**: 33.3m/s (120km/h) 초과
- **알림 제목 (본인)**: "과속 감지"
- **알림 제목 (타인)**: "{이름}님의 과속이 감지되었습니다"
- **알림 채널**: `danger_events`

### device_status (디바이스 상태 이벤트)

#### battery_warning (배터리 경고)
- **조건**: 배터리 20%, 10%, 5% 이하
- **알림 제목 (본인)**: "배터리 경고"
- **알림 채널**: `device_status_events`

#### offline (오프라인)
- **조건**: 30분 이상 위치 업데이트 없음
- **알림 제목 (타인)**: "{이름}님이 오프라인 상태가 되었습니다"
- **알림 채널**: `device_status_events`

## 알림 ID 생성 규칙

### 생성 방식
알림 ID는 간단한 해시 기반으로 생성됩니다:

```dart
int getNotificationId({
  required String eventType,
  String? eventSubtype,
  String? relatedId,  // geofence_id, movement_session_id 등
  required String userId,  // 이벤트 발생한 사용자 ID
}) {
  final key = '$eventType:${eventSubtype ?? ''}:$userId:${relatedId ?? ''}';
  return key.hashCode.abs() % 1000000;  // 0-999999 범위
}
```

### 동작 원리
- **같은 조합**: 같은 이벤트 타입 + 서브타입 + 사용자 ID + 관련 ID 조합이면 같은 ID 반환 → 알림 업데이트
- **다른 조합**: 다른 조합이면 다른 ID 반환 → 새 알림 생성

### 예시
```dart
// 같은 지오펜스에 같은 사용자가 여러 번 진입
getNotificationId(
  eventType: 'geofence',
  eventSubtype: 'enter',
  userId: 'user-123',
  relatedId: 'geofence-456',
) 
// → 항상 같은 ID 반환 → 알림 업데이트

// 다른 지오펜스에 진입
getNotificationId(
  eventType: 'geofence',
  eventSubtype: 'enter',
  userId: 'user-123',
  relatedId: 'geofence-789',  // 다른 지오펜스
)
// → 다른 ID 반환 → 새 알림 생성

// 다른 사용자가 같은 지오펜스에 진입
getNotificationId(
  eventType: 'geofence',
  eventSubtype: 'enter',
  userId: 'user-999',  // 다른 사용자
  relatedId: 'geofence-456',
)
// → 다른 ID 반환 → 새 알림 생성
```

## 본인/타인 구분 방법

### 1. 제목 구분
- **본인 이벤트**: 간단한 제목 (예: "지오펜스 진입: 호텔 주변")
- **타인 이벤트**: "이름님이..." 형식 (예: "김철수님이 지오펜스에 진입했습니다")

### 2. 아이콘 구분 (향후 구현)
- **본인 이벤트**: 기본 아이콘 (`@mipmap/ic_launcher`)
- **타인 이벤트**: 다른 아이콘 (예: `@drawable/ic_user_event`)

### 3. 색상 구분 (향후 구현)
- **본인 이벤트**: 기본 색상 (파란색 계열)
- **타인 이벤트**: 다른 색상 (주황색 또는 초록색 계열)

### 사용자 이름 조회
타인 이벤트의 경우 Firebase Realtime Database에서 사용자 이름을 조회합니다:
- **경로**: `realtime_locations/{groupId}/{userId}/user_name`
- **캐싱**: 메모리 캐시 사용 (앱 재시작 시 초기화)

## 알림 채널 매핑 테이블

| 이벤트 타입 | 서브타입 | 채널 ID | 중요도 | 사용자 제어 |
|------------|---------|---------|--------|------------|
| geofence | enter | geofence_events | 보통 | 가능 |
| geofence | exit | geofence_events | 보통 | 가능 |
| sos | emergency | sos_events | 긴급 | 불가 |
| sos | crime | sos_events | 긴급 | 불가 |
| sos | medical | sos_events | 긴급 | 불가 |
| session | start | session_events | 보통 | 가능 |
| session | end | session_events | 보통 | 가능 |
| session | kill | session_events | 보통 | 가능 |
| session_event | rapid_acceleration | danger_events | 높음 | 가능 |
| session_event | rapid_deceleration | danger_events | 높음 | 가능 |
| session_event | speeding | danger_events | 높음 | 가능 |
| device_status | battery_warning | device_status_events | 보통 | 가능 |
| device_status | offline | device_status_events | 높음 | 가능 |
| device_status | mock_location | device_status_events | 높음 | 가능 |

## 구현 파일

### 앱 (Flutter)
- `safetrip-mobile/lib/constants/notification_config.dart` - 알림 채널 및 ID 상수
- `safetrip-mobile/lib/services/notification_service.dart` - 알림 서비스 클래스
- `safetrip-mobile/lib/main.dart` - 알림 서비스 초기화 및 FCM 핸들러

### 서버 (TypeScript)
- `safetrip-server-api/src/constants/event-notification-config.ts` - 이벤트별 알림 설정
- `safetrip-server-api/src/services/event-notification.service.ts` - 알림 발송 서비스

## 사용자 설정 경로

Android에서 알림 채널을 관리하는 경로:
```
설정 > 앱 > SafeTrip > 알림
```

각 채널별로 다음을 설정할 수 있습니다:
- 알림 켜기/끄기
- 중요도 조정
- 사운드 설정
- 진동 설정

## 알림 업데이트 동작

같은 알림 ID가 사용되면:
1. 기존 알림이 업데이트됩니다 (새 알림이 생성되지 않음)
2. 제목과 본문이 최신 내용으로 변경됩니다
3. 시간이 업데이트됩니다

이를 통해:
- 같은 이벤트가 반복 발생해도 알림이 쌓이지 않습니다
- 최신 상태를 바로 확인할 수 있습니다
- 알림 목록이 깔끔하게 유지됩니다

## 참고 문서

- [이벤트 타입 정의서](./event-log-types.md) - 모든 이벤트 타입 및 서브타입 상세 정보
- [데이터베이스 스키마](../03-database/database-schema.dbml) - TB_EVENT_LOG, TB_NOTIFICATION 테이블 구조

