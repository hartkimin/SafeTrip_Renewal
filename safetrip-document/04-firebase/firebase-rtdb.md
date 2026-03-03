# Firebase Realtime Database 가이드

## 📋 목차

1. [개요](#개요)
2. [데이터 구조](#데이터-구조)
3. [주요 경로 및 용도](#주요-경로-및-용도)
4. [Flutter 앱에서의 사용](#flutter-앱에서의-사용)
5. [백엔드에서의 사용](#백엔드에서의-사용)
6. [보안 규칙](#보안-규칙)
7. [성능 최적화](#성능-최적화)

---

## 개요

SafeTrip은 **하이브리드 데이터베이스 아키텍처**를 사용합니다:

- **PostgreSQL (AWS RDS)**: 영구 저장 데이터 (사용자, 여행, 결제, 이벤트 로그 등)
- **Firebase Realtime Database (RTDB)**: 실시간 동기화 데이터 (위치, 지오펜스, 채팅 등)

### 왜 RTDB를 사용하나요?

1. **실시간 동기화**: 여러 클라이언트 간 즉각적인 데이터 동기화
2. **오프라인 지원**: 네트워크 불안정 시에도 로컬 캐시 사용
3. **낮은 지연시간**: 실시간 위치 업데이트에 최적화
4. **자동 동기화**: 별도의 폴링이나 웹소켓 관리 불필요

---

## 데이터 구조

### 전체 구조

```
Firebase Realtime Database
├── realtime_locations/          # 실시간 위치 정보
│   └── {groupId}/
│       └── {userId}/
│           ├── user_id
│           ├── user_name
│           ├── latitude
│           ├── longitude
│           ├── accuracy
│           ├── battery
│           ├── movement_session_id
│           ├── current_geofence_id
│           ├── timestamp
│           └── updated_at
│
├── realtime_geofences/         # 실시간 지오펜스
│   └── {groupId}/
│       └── {geofenceId}/
│           ├── geofence_id
│           ├── name
│           ├── type
│           ├── center_latitude
│           ├── center_longitude
│           ├── radius_meters
│           └── is_active
│
├── realtime_messages/          # 그룹 채팅 메시지
│   └── {groupId}/
│       └── {messageId}/
│           ├── message_id
│           ├── sender_user_id
│           ├── sender_name
│           ├── message_type
│           ├── message_text
│           ├── timestamp
│           └── created_at
│
├── realtime_message_reads/    # 메시지 읽음 상태
│   └── {messageId}/
│       └── {userId}/
│           └── read_at
│
└── realtime_tokens/            # FCM 토큰
    └── {groupId}/
        └── {userId}/
            └── fcm_token
```

---

## 주요 경로 및 용도

### 1. 실시간 위치 (`realtime_locations`)

**경로**: `realtime_locations/{groupId}/{userId}`

**용도**: 그룹 내 사용자들의 실시간 위치 정보 공유

**데이터 구조**:
```json
{
  "user_id": "user123",
  "user_name": "홍길동",
  "latitude": 37.5665,
  "longitude": 126.9780,
  "accuracy": 10.5,
  "altitude": 50.0,
  "speed": 5.2,
  "heading": 90.0,
  "battery": 85,
  "is_charging": false,
  "activity_type": "in_vehicle",
  "is_moving": true,
  "movement_session_id": "session123",
  "movement_session_created_at": "2024-01-01T00:00:00Z",
  "current_geofence_id": "geofence123",
  "geofence_entered_at": 1704067200000,
  "location_sharing_enabled": true,
  "mock_detected_at": null,
  "last_location_latitude": 37.5664,
  "last_location_longitude": 126.9779,
  "last_location_timestamp": 1704067200000,
  "timestamp": 1704067200000,
  "updated_at": 1704067200000
}
```

**특징**:
- 위치 업데이트 시 전체 객체를 `set()`으로 교체
- `updated_at`은 `ServerValue.timestamp`로 서버 시간 사용
- 오프라인 판단은 `updated_at` 기준으로 수행

### 2. 실시간 지오펜스 (`realtime_geofences`)

**경로**: `realtime_geofences/{groupId}/{geofenceId}`

**용도**: 그룹의 활성 지오펜스 정보 실시간 동기화

**데이터 구조**:
```json
{
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
```

**특징**:
- PostgreSQL에서 생성/수정된 지오펜스가 RTDB에 동기화됨
- Flutter 앱에서 실시간으로 지오펜스 변경 감지
- 백그라운드 지오펜스 모니터링에 사용

### 3. 그룹 채팅 메시지 (`realtime_messages`)

**경로**: `realtime_messages/{groupId}/{messageId}`

**용도**: 그룹 내 실시간 채팅

**데이터 구조**:
```json
{
  "message_id": "msg123",
  "sender_user_id": "user123",
  "sender_name": "홍길동",
  "message_type": "text",
  "message_text": "안녕하세요",
  "latitude": null,
  "longitude": null,
  "media_url": null,
  "reply_to_message_id": null,
  "is_deleted": false,
  "timestamp": 1704067200000,
  "created_at": "2024-01-01T00:00:00Z"
}
```

**메시지 타입**:
- `text`: 일반 텍스트 메시지
- `image`: 이미지 메시지
- `location`: 위치 공유 메시지
- `system`: 시스템 메시지

### 4. 메시지 읽음 상태 (`realtime_message_reads`)

**경로**: `realtime_message_reads/{messageId}/{userId}`

**용도**: 메시지 읽음 상태 추적

**데이터 구조**:
```json
{
  "read_at": 1704067200000
}
```

### 5. FCM 토큰 (`realtime_tokens`)

**경로**: `realtime_tokens/{groupId}/{userId}`

**용도**: 그룹별 FCM 토큰 관리

**데이터 구조**:
```json
{
  "fcm_token": "fcm_token_string",
  "updated_at": 1704067200000
}
```

---

## Flutter 앱에서의 사용

### 패키지 설치

```yaml
# pubspec.yaml
dependencies:
  firebase_database: ^10.3.0
```

### 위치 업데이트

```dart
import 'package:firebase_database/firebase_database.dart';
import 'package:app_geofence/services/firebase_location_service.dart';

// 위치 업데이트
await FirebaseLocationService().updateRealtimeLocation(
  groupId: 'group123',
  userId: 'user123',
  userName: '홍길동',
  latitude: 37.5665,
  longitude: 126.9780,
  battery: 85,
  movementSessionId: 'session123',
);
```

### 위치 리스닝

```dart
// 그룹 전체 위치 리스닝
FirebaseLocationService()
  .listenGroupLocations('group123')
  .listen((locations) {
    // locations: Map<String, dynamic>
    // {userId: {location data}, ...}
  });

// 특정 사용자 위치 변경만 리스닝 (권장)
FirebaseLocationService()
  .listenUserLocationChanges('group123')
  .listen((change) {
    // change: {userId: {location data}}
    // 변경된 사용자만 받음
  });
```

### 지오펜스 리스닝

```dart
import 'package:app_geofence/services/firebase_geofence_service.dart';

// 지오펜스 추가 감지
FirebaseGeofenceService()
  .listenGeofenceAdded('group123')
  .listen((geofence) {
    // 새로운 지오펜스 추가됨
  });

// 지오펜스 변경 감지
FirebaseGeofenceService()
  .listenGeofenceChanged('group123')
  .listen((geofence) {
    // 지오펜스 정보 변경됨
  });
```

### 채팅 메시지

```dart
import 'package:app_geofence/services/group_chat_service.dart';

// 메시지 전송
await GroupChatService().sendMessage(
  groupId: 'group123',
  senderUserId: 'user123',
  senderName: '홍길동',
  messageText: '안녕하세요',
);

// 메시지 리스닝
GroupChatService()
  .listenMessages('group123')
  .listen((messages) {
    // 새로운 메시지 수신
  });
```

---

## 백엔드에서의 사용

### 환경 변수 설정

```env
# safetrip-server-api/.env
FIREBASE_DATABASE_URL=https://safetrip-urock-default-rtdb.asia-northeast1.firebasedatabase.app
FIREBASE_PROJECT_ID=safetrip-urock
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@safetrip-urock.iam.gserviceaccount.com
```

### 지오펜스 조회

```typescript
// safetrip-server-api/src/services/geofence.service.ts
import { getFirebaseApp } from '../config/firebase.config';

async getGeofencesFromRTDB(groupId: string) {
  const firebaseApp = getFirebaseApp();
  if (!firebaseApp || !process.env.FIREBASE_DATABASE_URL) {
    throw new Error('FIREBASE_DATABASE_URL not configured');
  }
  
  const dbRef = firebaseApp.database();
  const snapshot = await dbRef
    .ref(`realtime_geofences/${groupId}`)
    .once('value');
  
  return snapshot.val();
}
```

### 위치 정보 조회

```typescript
async getLocationFromRTDB(groupId: string, userId: string) {
  const firebaseApp = getFirebaseApp();
  const dbRef = firebaseApp.database();
  
  const snapshot = await dbRef
    .ref(`realtime_locations/${groupId}/${userId}`)
    .once('value');
  
  return snapshot.val();
}
```

---

## 보안 규칙

Firebase Console에서 다음 보안 규칙을 설정하세요:

```json
{
  "rules": {
    "realtime_locations": {
      "$groupId": {
        "$userId": {
          ".read": "auth != null && root.child('groups').child($groupId).child('members').child(auth.uid).exists()",
          ".write": "auth != null && $userId === auth.uid"
        }
      }
    },
    "realtime_geofences": {
      "$groupId": {
        ".read": "auth != null && root.child('groups').child($groupId).child('members').child(auth.uid).exists()",
        ".write": "auth != null && root.child('groups').child($groupId).child('owner').val() === auth.uid"
      }
    },
    "realtime_messages": {
      "$groupId": {
        "$messageId": {
          ".read": "auth != null && root.child('groups').child($groupId).child('members').child(auth.uid).exists()",
          ".write": "auth != null && root.child('groups').child($groupId).child('members').child(auth.uid).exists()"
        }
      }
    },
    "realtime_tokens": {
      "$groupId": {
        "$userId": {
          ".read": "auth != null && $userId === auth.uid",
          ".write": "auth != null && $userId === auth.uid"
        }
      }
    }
  }
}
```

---

## 성능 최적화

### 1. 리스너 최적화

**❌ 비효율적**: 전체 그룹 위치를 매번 받기
```dart
// 모든 사용자 위치를 매번 받음
listenGroupLocations(groupId).listen((allLocations) {
  // 전체 데이터 처리
});
```

**✅ 효율적**: 변경된 사용자만 받기
```dart
// 변경된 사용자만 받음
listenUserLocationChanges(groupId).listen((change) {
  // 변경된 사용자만 업데이트
});
```

### 2. 데이터 최소화

- 필요한 필드만 업데이트
- `update()` 사용으로 부분 업데이트
- 불필요한 데이터는 저장하지 않기

### 3. 오프라인 처리

```dart
// 오프라인 지속성 활성화
FirebaseDatabase.instance.setPersistenceEnabled(true);
FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000); // 10MB
```

### 4. 리스너 정리

```dart
StreamSubscription? _locationSubscription;

@override
void initState() {
  super.initState();
  _locationSubscription = FirebaseLocationService()
    .listenUserLocationChanges(groupId)
    .listen((change) {
      // 처리
    });
}

@override
void dispose() {
  _locationSubscription?.cancel();
  super.dispose();
}
```

---

## PostgreSQL과의 동기화

### 데이터 흐름

1. **위치 데이터**:
   - Flutter 앱 → RTDB (실시간)
   - Flutter 앱 → PostgreSQL (배치 또는 주기적)
   - RTDB는 실시간 동기화용, PostgreSQL은 영구 저장용

2. **지오펜스 데이터**:
   - 백엔드 API → PostgreSQL (생성/수정)
   - 백엔드 API → RTDB (동기화)
   - Flutter 앱 → RTDB (읽기만)

3. **채팅 메시지**:
   - Flutter 앱 → RTDB (실시간)
   - RTDB → PostgreSQL (선택적, 백업용)

### 동기화 전략

- **RTDB 우선**: 실시간 동기화가 필요한 데이터는 RTDB 사용
- **PostgreSQL 보완**: 영구 저장 및 복잡한 쿼리는 PostgreSQL 사용
- **이중 저장**: 중요한 데이터는 두 곳 모두 저장 (백업)

---

## 문제 해결

### 연결 실패

```dart
// Firebase 초기화 확인
await Firebase.initializeApp();

// RTDB URL 확인
final database = FirebaseDatabase.instance;
debugPrint('Database URL: ${database.databaseURL}');
```

### 데이터 동기화 지연

- 네트워크 상태 확인
- 오프라인 지속성 활성화
- 리스너가 올바르게 설정되었는지 확인

### 권한 오류

- Firebase 보안 규칙 확인
- 사용자 인증 상태 확인
- 그룹 멤버십 확인

---

## 참고 문서

- [Firebase Realtime Database 공식 문서](https://firebase.google.com/docs/database)
- [Flutter Firebase Database 패키지](https://pub.dev/packages/firebase_database)
- [데이터베이스 스키마 문서](../03-database/database-readme.md)
- [Firebase 아키텍처](../02-architecture/firebase-architecture.md)

