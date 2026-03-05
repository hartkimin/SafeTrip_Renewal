# SafeTrip 외부 연동 시스템

## 📋 목차

1. [개요](#개요)
2. [Firebase 서비스](#firebase-서비스)
3. [지도 및 위치 서비스](#지도-및-위치-서비스)
4. [공공/AI 및 결제 서비스](#공공ai-및-결제-서비스)
5. [구현 위치](#구현-위치)
6. [환경 변수 설정](#환경-변수-설정)
7. [비용 정리](#비용-정리)

---

## 개요

SafeTrip은 해외 여행 안전 플랫폼으로, 다음과 같은 외부 서비스와 연동합니다:

| 카테고리 | 서비스 | 용도 | 필수 여부 |
|---------|--------|------|----------|
| **인증/알림** | Firebase Authentication | 전화번호 인증 | ✅ 필수 |
| **인증/알림** | Firebase Cloud Messaging (FCM) | 푸시 알림 | ✅ 필수 |
| **데이터베이스** | Firebase Realtime Database | 실시간 위치 공유, 그룹 채팅, 지오펜스 | ✅ 필수 |
| **스토리지** | Firebase Storage | 미디어 파일(이미지 등) 저장 | ✅ 필수 |
| **지도** | flutter_map (OpenStreetMap) | 지도 및 마커/폴리라인 표시 | ✅ 필수 |
| **지오코딩** | Flutter geocoding 패키지 | 기기 내 좌표 → 주소 변환 | ✅ 필수 |
| **위치 추적** | flutter_background_geolocation | 백그라운드 위치 추적, 지오펜싱 | ✅ 필수 |
| **공공데이터** | 외교부 국가별 기본정보 API | 여행경보, 안전정보, 대사관 연락처 제공 | ✅ 필수 |
| **AI** | OpenAI API (GPT-3.5-turbo 등) | 여행 지역별 맞춤 안전 가이드 생성 | ⚠️ 선택 |
| **결제** | Apple App Store / Google Play Store | 인앱 결제 (가디언 슬롯, 프리미엄 구독) | ✅ 필수 |

---

## Firebase 서비스

### 1. Firebase Authentication

**용도:**
- 전화번호 기반 인증 (Firebase Phone Authentication)
- 사용자 세션 및 인증 상태 관리
- 안전한 서버 통신을 위한 ID Token 발급 및 검증

**구현 위치:**
- `safetrip-mobile/lib/services/auth/` (Flutter 앱)
- `safetrip-server-api/src/modules/auth/` (NestJS 서버)

**Flutter 패키지:**
```yaml
dependencies:
  firebase_auth: ^5.0.0
```

**비용:**
- 무료 (Firebase 기본 제공, SMS 발송량에 따라 추가 요금 발생 가능)

---

### 2. Firebase Cloud Messaging (FCM)

**용도:**
- SOS 긴급 알림 (우선순위 최고)
- 위치 업데이트 및 시스템 이벤트 푸시 알림
- 그룹 채팅 알림

**구현 위치:**
- `safetrip-mobile/lib/services/` (앱 FCM 토큰 관리 및 수신)
- `safetrip-server-api/src/modules/notifications/` (서버 푸시 발송)

**Flutter 패키지:**
```yaml
dependencies:
  firebase_messaging: ^15.0.0
  flutter_local_notifications: ^17.2.4
```

---

### 3. Firebase Realtime Database (RTDB)

**용도:**
- 실시간 위치 공유 상태 동기화
- 실시간 지오펜스 및 출석(Attendance) 상태
- 오프라인 지원 및 그룹 채팅 메시지 실시간 동기화

**구현 위치:**
- `safetrip-mobile/lib/services/firebase_location_service.dart`
- `safetrip-server-api/src/modules/locations/`

**비용:**
- 사용량 기반 (무료 티어: 1GB 저장, 10GB/월 다운로드)

---

### 4. Firebase Storage

**용도:**
- 사용자 프로필 이미지 업로드
- 채팅 중 전송되는 미디어 파일 보관

**구현 위치:**
- `safetrip-mobile/lib/services/` (업로드)
- `safetrip-server-api/src/` (이미지/파일 처리)

---

## 지도 및 위치 서비스

### 5. flutter_map (OpenStreetMap 기반)

**용도:**
- 메인 화면 지도 타일 렌더링
- 여행자 마커 및 이동 경로(폴리라인) 애니메이션 표시

**구현 위치:**
- `safetrip-mobile/lib/screens/main/`
- `safetrip-mobile/lib/services/session_path_manager.dart`

**Flutter 패키지:**
```yaml
dependencies:
  flutter_map: ^8.2.2
  latlong2: ^0.9.1
  flutter_map_marker_cluster: ^8.2.2
```

**비용:**
- 무료 (OpenStreetMap 타일 서버 사용 시 비용 없음, 상용 타일 사용 시 별도 책정)

---

### 6. flutter_background_geolocation

**용도:**
- 앱이 백그라운드/종료 상태일 때 위치 추적
- 지오펜스(Geofence) 진입 및 이탈 감지 이벤트
- 배터리 소모 최적화(움직임 감지 연동)

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

---

### 7. Flutter geocoding 및 역지오코딩

**용도:**
- 기기 내에서 좌표를 실제 주소명으로 변환 (역지오코딩)
- 주소 검색 시 좌표 변환 (정지오코딩)

**구현 위치:**
- `safetrip-mobile/lib/services/geocoding_service.dart`

**Flutter 패키지:**
```yaml
dependencies:
  geocoding: ^3.0.0
```

---

## 공공/AI 및 결제 서비스

### 8. 외교부 공공데이터 API (MOFA)

**용도:**
- 국가별 여행경보, 기본정보, 대사관 연락처, 비자 정보 제공
- `https://apis.data.go.kr/1262000` 공공데이터포털 연동
- 조회 결과는 `TB_COUNTRY_SAFETY` 테이블에 캐시/저장 (DB 설계 문서 v3.6 §4.8a 참조)

**구현 위치:**
- `safetrip-server-api/src/modules/mofa/mofa.service.ts`
- `safetrip-server-api/src/entities/country-safety.entity.ts` (TB_COUNTRY_SAFETY 엔티티)

**비용:**
- 무료 (API 인증키 필요)

---

### 9. OpenAI API (AI 서비스)

**용도:**
- 사용자의 여행지, 상황에 맞춘 지능형 안전 가이드 생성
- 잠재적 위험 상황 분석 (Anomaly Detection 연동 예정)
- AI 구독 플랜(AI Plus/Pro) 사용자 대상 장소 추천 및 브리핑

**구현 위치:**
- `safetrip-server-api/src/modules/ai/ai.service.ts`

**비용:**
- 종량제 과금 (토큰 사용량에 따라 부과)

---

### 10. Apple App Store & Google Play Store

**용도:**
- 가디언 슬롯 추가 요금 결제 (`guardian_fee`)
- 프리미엄 AI 구독 (`guardian_premium`)
- 서버에서 스토어 영수증(Receipt) 검증 후 서비스 권한 부여

**구현 위치:**
- `safetrip-server-api/src/modules/payments/payments.service.ts`

**비용:**
- 각 스토어 정책에 따른 수수료 부과 (보통 15~30%)

---

## 구현 위치

### Backend 구조 (NestJS)

```
safetrip-server-api/src/modules/
├── ai/                # OpenAI 연동 및 사용량 관리
├── auth/              # Firebase 토큰 검증 및 사용자 인증
├── locations/         # 위치 데이터 관리 및 동기화
├── mofa/              # 외교부 공공데이터 API 연동
├── notifications/     # FCM 푸시 발송 로직
└── payments/          # 스토어 영수증 검증 및 구독/슬롯 결제 관리
```

### Mobile 구조 (Flutter)

```
safetrip-mobile/lib/services/
├── auth/                       # Firebase Auth
├── api_service.dart            # API 서버 통신 (Dio)
├── firebase_location_service.dart  # RTDB 위치/지오펜스 동기화
├── geofence_manager.dart       # 백그라운드 지오펜스 로직
├── location_service.dart       # 백그라운드 위치 추적
├── mofa_service.dart           # 안전가이드 화면용 서비스 (API 경유)
└── offline_sync_service.dart   # 오프라인 데이터 캐싱 및 동기화
```

---

## 환경 변수 설정

### Backend `.env`

```env
# Firebase
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_CLIENT_EMAIL=your_client_email
FIREBASE_PRIVATE_KEY=your_private_key

# Database
DB_HOST=your_db_endpoint
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=password
DB_DATABASE=safetrip

# 공공데이터 및 AI
MOFA_API_KEY=your_public_data_portal_key
LLM_API_KEY=your_openai_api_key

# 인앱 결제 검증용
APPLE_SHARED_SECRET=your_apple_secret
```

### Mobile `.env`

```env
API_BASE_URL=https://api.safetrip.io/v1
# Firebase는 google-services.json / GoogleService-Info.plist 에서 로드
```

---

## 비용 정리

### 예상 유지비용

| 서비스 | 월 예상 비용 | 비고 |
|--------|-------------|------|
| **Firebase Auth & FCM** | 무료 | 기본 티어 제공 |
| **Firebase RTDB / Storage** | $0 ~ $10+ | 초기 무료, 사용자 증가 시 사용량 기반 증가 |
| **OpenStreetMap (flutter_map)** | 무료 | 무료 타일 서버 기준 |
| **외교부 공공데이터 API** | 무료 | 공공데이터 |
| **OpenAI API** | $0 ~ $50+ | 토큰 사용량 기반 종량제. 구독자 수에 비례 |
| **스토어 수수료** | 매출의 15~30% | 인앱 결제 발생 시 스토어 자체 차감 |

---

## 연동 흐름도

### 1. 사용자 인증 흐름
```
모바일 앱 → Firebase Authentication (SMS OTP) → ID Token 발급
→ Backend API (/auth/firebase-verify) → DB 동기화 (PostgreSQL)
```

### 2. 위치 수집 및 동기화 흐름
```
모바일 앱 (flutter_background_geolocation) → Firebase RTDB (실시간 노출)
→ Backend API (일정 주기별 DB 영구 저장)
```

### 3. AI 안전 가이드 생성 흐름
```
모바일 앱 → Backend API (/ai/safety-guide)
→ OpenAI API (Prompt 전송 및 결과 파싱) → 클라이언트에 응답
```

### 4. 인앱 결제 흐름
```
모바일 앱 (스토어 자체 결제) → 영수증(Receipt) 토큰 획득
→ Backend API (/payments/verify) → Apple/Google 서버 검증 
→ DB 권한(구독/슬롯) 업데이트 → 기능 잠금 해제
```

---

**작성일**: 2026-03-04  
**버전**: 4.1 (DB 설계 v3.6 교차검증 반영 — TB_COUNTRY_SAFETY 참조 추가)
