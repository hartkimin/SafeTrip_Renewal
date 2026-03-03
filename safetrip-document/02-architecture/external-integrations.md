# SafeTrip 외부 연동 시스템

## 📋 목차

1. [개요](#개요)
2. [Firebase 서비스](#firebase-서비스)
3. [지도 및 위치 서비스](#지도-및-위치-서비스)
4. [구현 위치](#구현-위치)
5. [환경 변수 설정](#환경-변수-설정)
6. [비용 정리](#비용-정리)

---

## 개요

SafeTrip은 해외 여행 안전 플랫폼으로, 다음과 같은 외부 서비스와 연동합니다:

| 카테고리 | 서비스 | 용도 | 필수 여부 |
|---------|--------|------|----------|
| **인증/알림** | Firebase Authentication | 전화번호 인증 | ✅ 필수 |
| **인증/알림** | Firebase Cloud Messaging (FCM) | 푸시 알림 | ✅ 필수 |
| **데이터베이스** | Firebase Realtime Database | 실시간 위치 공유, 그룹 채팅 | ✅ 필수 |
| **스토리지** | Firebase Storage | 지도 이미지 저장 | ✅ 필수 |
| **지도** | Google Maps Flutter SDK | 지도 표시 | ✅ 필수 |
| **지도** | Google Maps Static API | 지도 이미지 생성 | ✅ 필수 |
| **지오코딩** | Flutter geocoding 패키지 | 좌표 → 주소 변환 (앱) | ✅ 필수 |
| **지오코딩** | OpenStreetMap Nominatim API | 좌표 → 주소 변환 (서버) | ✅ 필수 |
| **위치 추적** | flutter_background_geolocation | 백그라운드 위치 추적 | ✅ 필수 |

---

## Firebase 서비스

### 1. Firebase Authentication

**용도:**
- 전화번호 인증 (Firebase Phone Authentication)
- 사용자 인증 상태 관리
- ID Token 발급 및 검증

**구현 위치:**
- `safetrip-mobile/lib/services/` (Flutter 앱)
- `safetrip-server-api/src/config/firebase.config.ts` (서버 검증)
- `safetrip-server-api/src/controllers/auth.controller.ts` (인증 API)

**Flutter 패키지:**
```yaml
dependencies:
  firebase_auth: ^5.0.0
```

**비용:**
- 무료 (Firebase 기본 제공)

**API 엔드포인트:**
- `POST /api/v1/auth/firebase-verify` - Firebase ID Token 검증 및 사용자 동기화

---

### 2. Firebase Cloud Messaging (FCM)

**용도:**
- SOS 긴급 알림 (우선순위 1)
- 위치 업데이트 알림
- 그룹 메시지 알림
- 이벤트 알림

**구현 위치:**
- `safetrip-mobile/lib/services/` (Flutter 앱 - FCM 수신)
- `safetrip-server-api/src/services/fcm.service.ts` (서버 - FCM 발송)
- `safetrip-server-api/src/controllers/fcm.controller.ts` (FCM API)

**Flutter 패키지:**
```yaml
dependencies:
  firebase_messaging: ^15.0.0
  flutter_local_notifications: ^17.2.4
```

**비용:**
- 무료 (Firebase 기본 제공)

**API 엔드포인트:**
- `POST /api/v1/fcm/travelers/:travelerId/notify` - 여행자에게 알림 전송

---

### 3. Firebase Realtime Database

**용도:**
- 실시간 위치 공유 (`realtime_locations`)
- 실시간 지오펜스 정보 (`realtime_geofences`)
- 그룹 채팅 메시지 (`realtime_messages`)
- 메시지 읽음 상태 (`realtime_message_reads`)
- FCM 토큰 관리 (`realtime_tokens`)

**구현 위치:**
- `safetrip-mobile/lib/services/firebase_location_service.dart` (위치 업로드)
- `safetrip-mobile/lib/services/group_chat_service.dart` (채팅)
- `safetrip-server-api/src/services/location.service.ts` (위치 동기화)
- `safetrip-server-api/src/config/firebase.config.ts` (서버 연결)

**Flutter 패키지:**
```yaml
dependencies:
  firebase_database: ^11.0.0
```

**비용:**
- 사용량 기반 (무료 티어: 1GB 저장, 10GB/월 전송)
- 초과 시: $5/GB 저장, $1/GB 전송

**자세한 내용**: [Firebase Realtime Database](../04-firebase/firebase-rtdb.md)

---

### 4. Firebase Storage

**용도:**
- 이동 세션 지도 이미지 저장
- 이미지 캐싱 및 CDN 제공

**구현 위치:**
- `safetrip-server-api/src/services/map-image.service.ts` (이미지 업로드/조회)

**Flutter 패키지:**
```yaml
dependencies:
  firebase_storage: ^12.0.0
```

**비용:**
- 사용량 기반 (무료 티어: 5GB 저장, 1GB/일 다운로드)
- 초과 시: $0.026/GB 저장, $0.12/GB 다운로드

---

## 지도 및 위치 서비스

### 5. Google Maps Flutter SDK

**용도:**
- 지도 표시
- 마커 표시
- 폴리라인 그리기
- 카메라 제어

**구현 위치:**
- `safetrip-mobile/lib/screens/main/screen_main.dart` (메인 지도)
- `safetrip-mobile/lib/managers/` (지도 관리자들)

**Flutter 패키지:**
```yaml
dependencies:
  google_maps_flutter: ^2.5.0
```

**비용:**
- 월 $200 무료 크레딧
- 초과 시: Maps SDK $7/1,000회
- **예상 월 비용**: $0-200 (무료 크레딧 내 사용 시)

**API 키 설정:**
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/AppDelegate.swift`

---

### 6. Google Maps Static API

**용도:**
- 이동 세션 경로 지도 이미지 생성
- Base64 인코딩된 이미지 반환
- Firebase Storage에 저장

**구현 위치:**
- `safetrip-server-api/src/services/map-image.service.ts`

**API 사용:**
```typescript
const baseUrl = 'https://maps.googleapis.com/maps/api/staticmap';
const url = `${baseUrl}?size=800x400&path=weight:3|color:0x0000FF|enc:${polyline}&key=${apiKey}`;
```

**비용:**
- 월 $200 무료 크레딧
- 초과 시: Static Maps API $2/1,000회
- **예상 월 비용**: $0-50 (무료 크레딧 내 사용 시)

**환경 변수:**
```env
GOOGLE_MAPS_API_KEY=your_api_key_here
```

---

### 7. Flutter geocoding 패키지

**용도:**
- 좌표 → 주소 변환 (앱 내)
- 주소 → 좌표 변환 (앱 내)
- 국가 코드 조회

**구현 위치:**
- `safetrip-mobile/lib/services/geocoding_service.dart`

**Flutter 패키지:**
```yaml
dependencies:
  geocoding: ^3.0.0
```

**비용:**
- 무료 (기기 내 지오코딩 사용)

---

### 8. OpenStreetMap Nominatim API

**용도:**
- 서버에서 좌표 → 주소 변환 (역지오코딩)
- 위치 기록 시 주소 정보 저장

**구현 위치:**
- `safetrip-server-api/src/services/geocoding.service.ts`

**API 사용:**
```typescript
const response = await fetch(
  `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=18&addressdetails=1`,
  {
    headers: {
      'User-Agent': 'SafeTrip-API-Server/1.0',
    },
  }
);
```

**비용:**
- 무료 (Rate Limit: 초당 1회 요청 권장)

**주의사항:**
- User-Agent 헤더 필수
- 과도한 요청 시 IP 차단 가능

---

### 9. flutter_background_geolocation

**용도:**
- 백그라운드 위치 추적
- 지오펜스 이벤트 감지
- 이동 세션 자동 시작/종료
- 배터리 최적화

**구현 위치:**
- `safetrip-mobile/lib/services/location_service.dart`
- `safetrip-mobile/lib/services/geofence_manager.dart`

**Flutter 패키지:**
```yaml
dependencies:
  flutter_background_geolocation: ^4.18.2
```

**비용:**
- 무료 (오픈소스 라이브러리)

**주요 기능:**
- 백그라운드 위치 추적
- 지오펜스 진입/이탈 감지
- 배터리 최적화 모드
- 이동 감지 (Activity Recognition)

---

## 구현 위치

### Backend 서비스

```
safetrip-server-api/src/services/
├── fcm.service.ts              # FCM 알림 발송
├── geocoding.service.ts       # OpenStreetMap 역지오코딩
├── map-image.service.ts        # Google Maps Static API (지도 이미지 생성)
└── location.service.ts         # Firebase RTDB 위치 동기화
```

### Backend 컨트롤러

```
safetrip-server-api/src/controllers/
├── auth.controller.ts          # Firebase 인증
├── fcm.controller.ts           # FCM 알림
└── locations.controller.ts     # 위치 관리
```

### Backend 설정

```
safetrip-server-api/src/config/
├── firebase.config.ts          # Firebase Admin SDK 초기화
└── database.ts                 # PostgreSQL 연결
```

### Mobile 서비스

```
safetrip-mobile/lib/services/
├── geocoding_service.dart      # Flutter geocoding 패키지
├── firebase_location_service.dart  # Firebase RTDB 위치 업로드
├── group_chat_service.dart     # Firebase RTDB 채팅
└── location_service.dart       # flutter_background_geolocation
```

### Mobile 화면/매니저

```
safetrip-mobile/lib/
├── screens/main/screen_main.dart  # Google Maps 지도 표시
├── managers/
│   ├── geofence_map_renderer.dart  # 지오펜스 지도 렌더링
│   ├── marker_manager.dart         # 마커 관리
│   └── camera_controller.dart      # 카메라 제어
```

---

## 환경 변수 설정

### Backend `.env`

```env
# Firebase
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_CLIENT_EMAIL=your_client_email
FIREBASE_PRIVATE_KEY=your_private_key
FIREBASE_DATABASE_URL=https://your-project-default-rtdb.firebaseio.com

# Google Maps
GOOGLE_MAPS_API_KEY=your_google_maps_api_key

# PostgreSQL
DB_HOST=your_rds_endpoint
DB_PORT=5432
DB_NAME=safetrip
DB_USER=safetrip_user
DB_PASSWORD=your_password
DB_SSL=true

# 서버
NODE_ENV=production
PORT=3001
```

### Mobile `.env`

```env
# Firebase는 google-services.json (Android) / GoogleService-Info.plist (iOS)에서 자동 로드

# Google Maps
GOOGLE_MAPS_API_KEY=your_google_maps_api_key

# API 서버
API_BASE_URL=https://api.safetrip.io/v1
```

### Firebase 설정 파일

**Android:**
- `safetrip-mobile/android/app/google-services.json`

**iOS:**
- `safetrip-mobile/ios/Runner/GoogleService-Info.plist`

---

## 비용 정리

### 월 예상 비용 (초기 단계)

| 서비스 | 월 예상 비용 | 비고 |
|--------|-------------|------|
| **Firebase Authentication** | 무료 | 기본 제공 |
| **Firebase FCM** | 무료 | 기본 제공 |
| **Firebase RTDB** | $0-10 | 1GB 저장, 10GB 전송 내 무료 |
| **Firebase Storage** | $0-5 | 5GB 저장, 1GB/일 다운로드 내 무료 |
| **Google Maps Flutter SDK** | $0-200 | 월 $200 무료 크레딧 |
| **Google Maps Static API** | $0-50 | 월 $200 무료 크레딧 내 |
| **OpenStreetMap Nominatim** | 무료 | Rate Limit 준수 시 |
| **flutter_background_geolocation** | 무료 | 오픈소스 |
| **Flutter geocoding** | 무료 | 기기 내 지오코딩 |
| **총 예상** | **$0-265** | 무료 크레딧 활용 시 |

### 월 예상 비용 (성장 단계 - 사용자 10만명)

| 서비스 | 월 예상 비용 | 비고 |
|--------|-------------|------|
| **Firebase RTDB** | $50-200 | 사용량 증가 |
| **Firebase Storage** | $20-100 | 이미지 저장 증가 |
| **Google Maps Flutter SDK** | $200-500 | 무료 크레딧 초과 시 |
| **Google Maps Static API** | $50-200 | 지도 이미지 생성 증가 |
| **총 예상** | **$320-1,000** | 사용량에 따라 변동 |

---

## 연동 흐름도

### 1. 사용자 인증 흐름

```
모바일 앱
  ↓ (전화번호 입력)
Firebase Authentication
  ↓ (SMS OTP 발송 - Firebase 자동 처리)
사용자 (OTP 수신)
  ↓ (OTP 코드 입력)
Firebase Authentication
  ↓ (ID Token 발급)
모바일 앱
  ↓ (ID Token 전송)
Backend API (/auth/firebase-verify)
  ↓ (토큰 검증 및 사용자 동기화)
PostgreSQL (사용자 정보 저장)
```

---

### 2. 위치 업로드 흐름

```
모바일 앱 (flutter_background_geolocation)
  ↓ (위치 수집)
Firebase RTDB (realtime_locations)
  ↓ (실시간 동기화)
다른 사용자 앱 (실시간 위치 표시)
  ↓ (서버 동기화)
Backend API (주기적 동기화)
  ↓ (주소 변환 - OpenStreetMap)
PostgreSQL (위치 이력 저장)
```

---

### 3. FCM 알림 흐름

```
Backend API (/fcm/travelers/:travelerId/notify)
  ↓ (FCM 메시지 생성)
Firebase Cloud Messaging
  ↓ (푸시 알림 전송)
모바일 앱 (Firebase Messaging)
  ↓ (로컬 알림 표시)
사용자
```

---

### 4. 지도 이미지 생성 흐름

```
Backend API (이동 세션 완료)
  ↓ (위치 데이터 조회)
Google Maps Static API
  ↓ (지도 이미지 생성)
Base64 인코딩
  ↓ (Firebase Storage 업로드)
Firebase Storage
  ↓ (URL 반환)
PostgreSQL (URL 저장)
```

---

## 참고 자료

- [Firebase Realtime Database 가이드](../04-firebase/firebase-rtdb.md)
- [Firebase 아키텍처](../02-architecture/firebase-architecture.md)
- [API 가이드](../05-api/api-guide.md)
- [배포 가이드](../01-getting-started/deployment.md)

---

**작성일**: 2025-01-15  
**버전**: 3.0 (실제 사용 서비스만 반영)
