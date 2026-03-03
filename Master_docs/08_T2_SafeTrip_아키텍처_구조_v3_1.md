# SafeTrip — 아키텍처 구조 v3.1

> **문서 목적**: SafeTrip 앱의 전체 시스템 아키텍처를 정의한다. 클라이언트(Flutter), 백엔드(NestJS/TypeScript), 데이터베이스(PostgreSQL + PostGIS), 실시간 인프라(Firebase RTDB/Auth/FCM), AI 서비스, 결제/과금 시스템, B2B 프레임워크, 외부 연동(외교부 API, 긴급 구조기관)의 구조와 상호 연결을 포괄한다.
>
> **적용 범위**: SafeTrip 프로젝트의 설계, 개발, QA, 운영, 인프라 전 부문
>
> **기준 문서(상위 문서)**:
> | 문서 | 버전 | 참조 내용 |
> |------|:----:|----------|
> | SafeTrip_비즈니스_원칙 | v5.1 | 역할 체계, 프라이버시 등급, 과금 모델, 여행 기간 정책, B2B 프레임워크 |
> | SafeTrip_마스터_원칙_거버넌스 | v2.0 | 문서 계층, 변경 전파 규칙, 품질 체크리스트 |
> | DB_설계_및_관계 | v3.5 | 54개 테이블 스키마, 13개 도메인, RTDB 스키마 |
> | SafeTrip_위치_데이터_수집_저장_삭제_정책 | v1.0 | 위치 데이터 생명주기, 3단계 삭제 파이프라인 |
>
> **거버넌스 계층**: Tier 2 — 시스템 설계 (System Design)
>
> **최종 수정일**: 2026-03-02 | **버전**: v3.1.3
>
> **변경 이력**:
> - v1.0 (2026-02-07): 초기 작성 — 핵심 아키텍처, API 엔드포인트, 인증 흐름
> - v2.0 (2026-02-28): 전체 기능 원칙 문서 통합 — AI 서비스, SOS/Watchdog 시스템, 채팅 아키텍처, 긴급 구조기관 연동, 오프라인 전략, 보안 아키텍처, 레이어별 상세 설계 확장
> - v3.1 (2026-03-01): DB v3.1 연동 — 50개 테이블/13개 도메인 반영, 결제/과금 아키텍처 신규, B2B 프레임워크 신규, 이동기록 시스템 신규, 위치 데이터 정책 v1.0 통합, AI 과금 체계 확정, 데모 투어 시스템 신규, 데이터 삭제 파이프라인 3단계 확정
> - v3.1.1 (2026-03-01): DB v3.4 정합 보완 — 54개 테이블 반영, [B] 도메인 출석체크 테이블 2개 추가(TB_ATTENDANCE_CHECK, TB_ATTENDANCE_RESPONSE), [C] 도메인 3→5개(TB_GUARDIAN_LOCATION_REQUEST·TB_GUARDIAN_SNAPSHOT 반영), [E] 도메인 TB_LOCATION_SCHEDULE 추가, ERD §5.3 보호자·B2B·위치스케줄 관계도 보완, backend attendance.service.ts 추가, 보호자 API 누락 엔드포인트 추가(가디언 그룹 가입·링크 응답), 출석체크 API 섹션 신규(§19.18), 비즈니스 원칙 v5.1 버전 참조 갱신
> - v3.1.2 (2026-03-02): 비즈니스 원칙 v5.1 기준 불일치 항목 수정 — §15.1 무료 가디언 2명 및 추가 가디언 1,900원 수정, §5.2 [C] 도메인 "v3.2 확장" → "v3.4 반영" 갱신, §5.3 ERD TB_GUARDIAN_LOCATION_REQUEST·SNAPSHOT "(v3.2 신규)" → "(v3.4 반영)" 갱신
> - v3.1.3 (2026-03-02): 비즈니스 원칙 v5.1 기준 불일치 탐색·검증 — v5.0 잔존 없음 확인, 헤더 버전·수정일 v3.1.2/2026-03-02로 갱신 (v3.1.2 적용 후 누락된 헤더 반영)

---

## 목차

1. [시스템 아키텍처 개요](#1-시스템-아키텍처-개요)
2. [기술 스택](#2-기술-스택)
3. [클라이언트 아키텍처 (Flutter)](#3-클라이언트-아키텍처-flutter)
4. [백엔드 아키텍처 (NestJS/TypeScript)](#4-백엔드-아키텍처-expresstypescript)
5. [데이터베이스 아키텍처 (PostgreSQL + PostGIS)](#5-데이터베이스-아키텍처-postgresql--postgis)
6. [Firebase 인프라](#6-firebase-인프라)
7. [인증 아키텍처](#7-인증-아키텍처)
8. [실시간 위치 공유 아키텍처](#8-실시간-위치-공유-아키텍처)
9. [이동기록 시스템 아키텍처](#9-이동기록-시스템-아키텍처)
10. [지오펜스 시스템 아키텍처](#10-지오펜스-시스템-아키텍처)
11. [SOS 및 Watchdog 시스템 아키텍처](#11-sos-및-watchdog-시스템-아키텍처)
12. [채팅 시스템 아키텍처](#12-채팅-시스템-아키텍처)
13. [알림 시스템 아키텍처](#13-알림-시스템-아키텍처)
14. [AI 서비스 아키텍처](#14-ai-서비스-아키텍처)
15. [결제 및 과금 아키텍처](#15-결제-및-과금-아키텍처)
16. [B2B 프레임워크 아키텍처](#16-b2b-프레임워크-아키텍처)
17. [데모 투어 시스템 아키텍처](#17-데모-투어-시스템-아키텍처)
18. [외부 서비스 연동](#18-외부-서비스-연동)
19. [API 엔드포인트 구조](#19-api-엔드포인트-구조)
20. [보안 아키텍처](#20-보안-아키텍처)
21. [데이터 생명주기 아키텍처](#21-데이터-생명주기-아키텍처)
22. [오프라인 아키텍처](#22-오프라인-아키텍처)
23. [개발 환경 아키텍처](#23-개발-환경-아키텍처)
24. [프로젝트 디렉토리 구조](#24-프로젝트-디렉토리-구조)
25. [배포 및 인프라 구성](#25-배포-및-인프라-구성)
26. [성능 및 확장성 원칙](#26-성능-및-확장성-원칙)
27. [구현 우선순위](#27-구현-우선순위)
28. [알려진 이슈](#28-알려진-이슈)
29. [검증 체크리스트](#29-검증-체크리스트)

---

## 1. 시스템 아키텍처 개요

### 1.1 전체 시스템 구성도

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Flutter 앱 (Android / iOS)                         │
│                                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────────────┐    │
│  │  인증 화면   │  │  메인 지도    │  │  바텀 시트 (4개 탭)              │    │
│  │  (OTP 인증)  │  │  + 컨트롤    │  │  일정 / 멤버 / 채팅 / 안전가이드  │    │
│  └─────────────┘  └──────────────┘  └─────────────────────────────────┘    │
│          │                │                         │                       │
│  ┌───────┴────────────────┴─────────────────────────┴────────────────────┐  │
│  │                   서비스 레이어 (Services / Managers)                  │  │
│  │  ApiService(Dio) │ FirebaseLocationService │ FcmService │ SosService  │  │
│  │  GroupChatService │ GeofenceManager │ MofaService │ AttendanceService │  │
│  │  PaymentService │ MovementRecordService │ DemoTourService            │  │
│  └───────────────────────────────┬───────────────────────────────────────┘  │
│                                  │                                          │
│  ┌───────────────────────────────┴───────────────────────────────────────┐  │
│  │                   로컬 저장소 / 캐시 레이어                            │  │
│  │  SQLite (오프라인 큐) │ AppCache │ LocationCache │ SharedPreferences  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────┼──────────────────────────────────────────┘
                                   │ HTTP / WebSocket / gRPC
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
          ▼                        ▼                        ▼
┌──────────────────┐   ┌─────────────────────┐   ┌──────────────────────┐
│  NestJS API     │   │  Firebase 서비스      │   │  외부 서비스          │
│  (port 3001)     │   │                     │   │                      │
│  TypeScript      │   │  ├ Firebase Auth     │   │  ├ 외교부 API (MOFA) │
│                  │   │  │  (OTP 인증)       │   │  ├ Nominatim API     │
│  ├ Controllers   │   │  ├ Firebase RTDB     │   │  ├ AI/LLM Provider   │
│  ├ Services      │   │  │  (위치/채팅/지오)  │   │  ├ 구조기관 전화 DB  │
│  ├ Middleware     │   │  ├ Firebase FCM      │   │  ├ 결제 게이트웨이    │
│  ├ Routes        │   │  │  (푸시 알림)       │   │  └ Google Places API │
│  └ Batch Jobs    │   │  └ Firebase Storage  │   │                      │
│                  │   │    (미디어 파일)      │   └──────────────────────┘
└────────┬─────────┘   └──────────┬────────────┘
         │                        │
         │    10분마다 동기화       │
         ▼                        │
┌──────────────────┐              │
│  PostgreSQL 15   │◄─────────────┘
│  + PostGIS       │
│  (port 5432)     │
│                  │
│  54개 테이블      │
│  13개 도메인      │
└──────────────────┘
```

### 1.2 아키텍처 핵심 원칙

| 원칙 | 설명 |
|------|------|
| **안전 최우선** | SOS, 위치 추적, 긴급 알림은 모든 프라이버시 설정을 무시하고 동작한다 |
| **이중 데이터 경로** | 실시간 데이터는 Firebase RTDB, 영속 데이터는 PostgreSQL로 분리 저장한다 |
| **오프라인 복원력** | 핵심 기능(SOS, 위치 기록, 채팅)은 오프라인에서도 큐잉 후 복구 가능하다 |
| **역할 기반 접근 제어** | 캡틴/크루장/크루/가디언 역할에 따라 데이터 접근 범위가 자동 조절된다 |
| **프라이버시 등급 연동** | 안전 최우선/표준/프라이버시 우선 등급에 따라 데이터 수집·공유 범위가 달라진다 |
| **3단계 데이터 삭제** | Soft delete → 익명화 → 물리 삭제(VACUUM)의 법적 준수 파이프라인을 적용한다 |
| **프리미엄 분리** | 안전 기능은 무료, 편의 기능은 AI Plus/Pro 과금으로 분리하여 수익화한다 |

### 1.3 데이터 흐름 요약

| 데이터 유형 | 경로 | 지연 허용 |
|------------|------|:--------:|
| 실시간 위치 | 기기 GPS → Firebase RTDB → Flutter 리스너 | < 3초 |
| 위치 영속 저장 | Firebase RTDB → (10분 배치) → PostgreSQL TB_LOCATION | ≤ 10분 |
| SOS 알림 | Flutter → Firebase RTDB + FCM → 수신자 앱 | < 5초 |
| 채팅 메시지 | Flutter → Firebase RTDB → Flutter 리스너 | < 2초 |
| API 호출 | Flutter → NestJS API → PostgreSQL | < 1초 |
| AI 응답 | Flutter → NestJS API → LLM Provider → Flutter | < 10초 |
| Heartbeat | Flutter → NestJS API → TB_HEARTBEAT | < 5초 |
| 결제 처리 | Flutter → NestJS API → 결제 게이트웨이 → TB_PAYMENT | < 10초 |

---

## 2. 기술 스택

### 2.1 클라이언트

| 영역 | 기술 | 버전/비고 |
|------|------|----------|
| 프레임워크 | Flutter | Dart 언어 |
| 라우팅 | GoRouter | 인증 상태 기반 자동 리다이렉트 |
| HTTP 클라이언트 | Dio | 토큰 자동 갱신 인터셉터 포함 |
| 지도 | flutter_map 또는 Google Maps | 레이어 시스템 (6개 레이어) |
| 위치 추적 | flutter_background_geolocation | 백그라운드 포함 |
| 푸시 알림 | Firebase Messaging (FCM) | 포그라운드 + 백그라운드 |
| 로컬 저장 | SQLite (오프라인 큐) + SharedPreferences | 오프라인 대응 |
| QR 코드 | qr_flutter | 초대코드 QR 생성 |
| 결제 | in_app_purchase / 결제 SDK | 인앱 결제 + PG 연동 |

### 2.2 백엔드

| 영역 | 기술 | 버전/비고 |
|------|------|----------|
| 런타임 | Node.js | TypeScript |
| 웹 프레임워크 | NestJS | port 3001 |
| 데이터베이스 | PostgreSQL 15 | + PostGIS (지리 데이터) |
| DB 드라이버 | pg (node-postgres) | 커넥션 풀 |
| 인증 | Firebase Admin SDK | ID 토큰 검증 |
| 실시간 DB | Firebase Realtime Database | 위치/채팅/지오펜스/Presence |
| 파일 저장 | Firebase Storage | 프로필 이미지, 채팅 미디어 |
| 푸시 알림 | Firebase Cloud Messaging | 서버 사이드 발송 |
| 로거 | Winston 또는 커스텀 logger | 구조화된 로깅 |
| 배치 작업 | node-cron 또는 커스텀 스케줄러 | 위치 동기화, Watchdog, 데이터 정리 |

### 2.3 외부 서비스

| 서비스 | 용도 | 연동 방식 |
|--------|------|----------|
| 외교부 API (MOFA) | 국가별 안전 정보, 여행경보 | REST API |
| Nominatim API | 주소 ↔ 좌표 변환 (지오코딩) | REST API |
| AI/LLM Provider | AI 일정 생성, 안전 어시스턴트, 번역 | REST API |
| 구조기관 전화 DB | 국가별 긴급 전화번호 (119/112/911 등) | 로컬 DB + 주기적 업데이트 |
| 결제 게이트웨이 | AI 프리미엄 과금, 가디언 추가 결제 | REST API |
| Google Places API | AI 주변 추천 (Pro 기능) | REST API |

---

## 3. 클라이언트 아키텍처 (Flutter)

### 3.1 레이어 구조

```
┌──────────────────────────────────────────────┐
│  Screens (화면)                               │
│  ├ auth/        인증 흐름 (로그인, OTP, 프로필)  │
│  ├ onboarding/  온보딩 (8개 시나리오 분기)       │
│  ├ demo/        데모 투어 (3개 프리셋 시나리오)   │
│  ├ main/        메인 지도 + 바텀시트 + 모달      │
│  ├ trip/        여행 관리 (생성, 참가, 가디언)    │
│  ├ movement/    이동기록 (멤버별 경로 조회)       │
│  ├ payment/     결제 (AI 구독, 가디언 추가)      │
│  └ settings/    설정 (프로필, 위치, 알림)         │
├──────────────────────────────────────────────┤
│  Widgets (재사용 UI 컴포넌트)                   │
│  avatar, map_controls, trip_info_card,        │
│  movement_timeline, payment_card 등            │
├──────────────────────────────────────────────┤
│  Services (비즈니스 로직)                       │
│  ├ api_service.dart         HTTP 클라이언트     │
│  ├ firebase_location_service  실시간 위치 (RTDB)│
│  ├ firebase_geofence_service  지오펜스 (RTDB)   │
│  ├ fcm_service.dart          푸시 알림          │
│  ├ sos_service.dart          SOS 시스템         │
│  ├ group_chat_service.dart   채팅              │
│  ├ mofa_service.dart         외교부 API         │
│  ├ attendance_service.dart   출석 체크          │
│  ├ movement_record_service.dart  이동기록 ⭐    │
│  ├ payment_service.dart      결제/구독 ⭐       │
│  └ demo_tour_service.dart    데모 투어 ⭐       │
├──────────────────────────────────────────────┤
│  Managers (상태/라이프사이클 관리)               │
│  ├ session_manager           세션 + 토큰        │
│  ├ user_mode_manager         역할별 UI 분기     │
│  ├ firebase_location_manager 위치 수명주기       │
│  ├ marker_manager            지도 마커 관리      │
│  ├ geofence_map_renderer     지오펜스 렌더링     │
│  ├ camera_controller         지도 카메라         │
│  └ subscription_manager      구독 상태 관리 ⭐   │
├──────────────────────────────────────────────┤
│  Models (데이터 모델)                           │
│  user, geofence, location, schedule, sos,     │
│  payment, subscription, movement_session 등    │
├──────────────────────────────────────────────┤
│  Utils (유틸리티)                               │
│  app_cache, location_cache, phone_parser,     │
│  movement_session_builder 등                   │
├──────────────────────────────────────────────┤
│  Config / Constants (설정 및 상수)              │
│  firebase_emulator_config, map_constants,     │
│  payment_config, ai_tier_config 등             │
└──────────────────────────────────────────────┘
```

### 3.2 화면 계층 구조

```
Layer 0: 스플래시 → 온보딩/데모투어 → 인증 (앱 진입 ~ 인증 완료)
    │
    ▼  인증 완료
Layer 1: 메인 화면 (전체 화면 지도 + 오버레이)
    │  ├ 상단 오버레이: 여행 정보 카드 + 상태 표시
    │  ├ 지도 영역: 6개 레이어 시스템 (멤버·일정·지오펜스·경로·안전·긴급)
    │  ├ 지도 컨트롤: 줌, 내 위치, 레이어 토글
    │  ├ 고정 액션: SOS 버튼 (전 역할) / 긴급 요청 (가디언)
    │  └ 바텀 시트: [일정] [멤버] [채팅] [안전가이드]
    │
    ▼  사용자 액션
Layer 2: 모달 / 하프 시트 (일정 추가, 멤버 초대, 위치 공유 설정, 이동기록 조회 등)
    │
    ▼
Layer 3: 전체 화면 팝업 (여행 생성, 출석 체크, 보호자 홈, 설정, 결제, 이동기록 상세)
```

### 3.3 라우트 경로

```
/                         → splash (리다이렉트 로직)
/onboarding               → 최초 실행 온보딩
/onboarding/main          → 로그인 시작
/demo                     → 데모 투어 시나리오 선택 ⭐
/demo/:scenarioId         → 데모 투어 체험 ⭐
/auth/phone               → 전화번호 입력
/auth/verify              → OTP 인증
/auth/terms               → 약관 동의
/auth/profile             → 프로필 설정
/main                     → 메인 지도 + 컨트롤
/trip/create              → 새 여행 생성
/trip/join                → 초대코드로 참여
/trip/confirm             → 여행 확인
/movement/:userId         → 멤버별 이동기록 ⭐
/movement/:userId/:date   → 일자별 이동기록 상세 ⭐
/payment                  → 결제/구독 관리 ⭐
/payment/subscribe        → AI 구독 선택 ⭐
/permission               → 권한 요청 화면
```

### 3.4 지도 레이어 시스템 (6개 레이어)

```
Layer 6 (최상위) : 긴급 오버레이 (SOS 위치 펄스, 긴급 알림)
Layer 5          : 이벤트 마커 (지오펜스 진입/이탈 이벤트 핀)
Layer 4          : 경로 레이어 (이동 경로, 일정 미리보기 경로, 계획 경로 vs 실제 경로)
Layer 3          : 안전 정보 (안전 히트맵, 위험구역, 안전시설)
Layer 2          : 지오펜스 (safe/watch/danger 구역 시각화)
Layer 1 (기본)   : 멤버 마커 (실시간 위치 + 배터리 + 온라인 상태)
```

각 레이어는 독립적으로 ON/OFF 가능하며, 역할에 따라 기본 활성 레이어가 달라진다.

---

## 4. 백엔드 아키텍처 (NestJS/TypeScript)

### 4.1 디렉토리 구조

```
safetrip-server-api/src/
├── index.ts                      # Express 앱 설정 & 라우트 등록
├── config/
│   ├── database.ts               # PostgreSQL 연결 (pg 라이브러리)
│   ├── env.ts                    # 환경 변수 검증
│   └── firebase.config.ts        # Firebase Admin SDK 초기화
├── middleware/
│   ├── auth.middleware.ts         # JWT/Firebase 인증 + 자동 사용자 생성
│   ├── error.middleware.ts        # 글로벌 에러 핸들링
│   ├── api-key.middleware.ts      # API 키 인증 (외부 연동)
│   ├── guardian-permission.middleware.ts  # 보호자 권한 검증
│   └── subscription.middleware.ts # AI 구독 등급 검증 ⭐
├── controllers/                   # 요청/응답 핸들러
├── routes/                        # URL 라우팅
├── services/
│   ├── auth.service.ts            # 인증 처리
│   ├── trip.service.ts            # 여행 CRUD
│   ├── group.service.ts           # 그룹 관리
│   ├── geofence.service.ts        # 지오펜스 CRUD
│   ├── geofence-scheduler.service.ts  # RTDB ↔ PostgreSQL 동기화
│   ├── location.service.ts        # 위치 데이터 처리
│   ├── movement-record.service.ts # 이동기록 조회/내보내기 ⭐
│   ├── guardian.service.ts        # 보호자 시스템
│   ├── sos.service.ts             # SOS 이벤트 처리
│   ├── watchdog.service.ts        # Heartbeat 감시 ⭐
│   ├── chat.service.ts            # 채팅 메시지 관리
│   ├── notification.service.ts    # 알림 발송
│   ├── schedule.service.ts        # 일정 관리
│   ├── invite-code.service.ts     # 초대코드 생성/사용
│   ├── mofa.service.ts            # 외교부 API 연동
│   ├── ai.service.ts              # AI/LLM 연동
│   ├── fcm.service.ts             # FCM 토큰 관리 & 발송
│   ├── payment.service.ts         # 결제/과금 처리 ⭐
│   ├── subscription.service.ts    # AI 구독 관리 ⭐
│   ├── attendance.service.ts      # 출석체크 관리 ⭐
│   ├── b2b.service.ts             # B2B 계약/초대 관리 ⭐
│   └── data-lifecycle.service.ts  # 데이터 삭제 파이프라인 ⭐
├── batch/                         # 배치 작업 ⭐
│   ├── location-sync.batch.ts     # 위치 동기화 (10분)
│   ├── watchdog.batch.ts          # Heartbeat 감시 (1~5분)
│   ├── stay-point.batch.ts        # 체류 포인트 집계 (5분)
│   ├── data-cleanup.batch.ts      # 데이터 보관 기간 정리 (1일)
│   └── geofence-eval.batch.ts     # 지오펜스 평가 (1분)
├── constants/
│   ├── event-types.ts             # 이벤트 타입 열거
│   ├── event-notification-config.ts  # 알림 규칙 설정
│   └── ai-tier-config.ts         # AI 과금 등급 설정 ⭐
└── utils/
    ├── logger.ts                  # 구조화된 로깅
    └── response.ts                # 응답 포맷 헬퍼
```

### 4.2 미들웨어 파이프라인

```
요청 수신
    │
    ▼
[1] CORS 설정
    │
    ▼
[2] JSON Body Parser
    │
    ▼
[3] auth.middleware.ts
    │  ├ Authorization: Bearer {Firebase ID Token}
    │  ├ Firebase Admin SDK로 토큰 검증
    │  ├ 검증 성공 → req.user에 사용자 정보 주입
    │  └ 사용자 미존재 → TB_USER auto-upsert (자동 생성)
    │
    ▼
[4] guardian-permission.middleware.ts (보호자 라우트만)
    │  └ 보호자-여행자 관계 검증 (TB_GUARDIAN_LINK 기준)
    │
    ▼
[5] subscription.middleware.ts (AI 유료 라우트만) ⭐
    │  └ TB_SUBSCRIPTION 조회 → 등급별 접근 제어
    │
    ▼
[6] Controller → Service → DB
    │
    ▼
[7] error.middleware.ts (글로벌 에러 핸들러)
    │
    ▼
응답 반환
```

### 4.3 배치 작업 (Background Jobs)

| 작업 | 주기 | 설명 |
|------|------|------|
| JOB-01: 위치 동기화 | 10분 | Firebase RTDB `/locations` → PostgreSQL TB_LOCATION 배치 INSERT |
| JOB-02: Watchdog 감시 | 1~5분 (등급별) | Heartbeat 타임아웃 감지 → 의심 점수 계산 → 자동 SOS |
| JOB-03: 체류 포인트 집계 | 5분 | TB_LOCATION → TB_STAY_POINT (10분 이상 체류 클러스터링) |
| JOB-04: 데이터 정리 | 1일 | 보관 기간 경과 데이터 3단계 삭제 (soft → anonymize → VACUUM) |
| JOB-05: 지오펜스 평가 | 1분 | 멤버 위치 vs 지오펜스 경계 비교 → 진입/이탈 이벤트 |
| JOB-06: 알림 만료 정리 | 1일 | expires_at 경과 알림 소프트 삭제 |
| JOB-07: 지오펜스 동기화 | 10분 | Firebase RTDB `/geofences` ↔ PostgreSQL TB_GEOFENCE 양방향 동기화 |
| JOB-08: RTDB → 채팅 배치 | 10분 | Firebase RTDB `/chats` → TB_CHAT_MESSAGE 배치 INSERT |

---

## 5. 데이터베이스 아키텍처 (PostgreSQL + PostGIS)

### 5.1 환경 구성

| 항목 | 값 |
|------|-----|
| DBMS | PostgreSQL 15 + PostGIS |
| 개발 DB | `safetrip_dev` |
| 포트 | 5432 |
| 스키마 파일 | `safetrip-server-api/scripts/local/01-init-schema.sql` |
| 인코딩 | UTF-8 |
| 타임존 | UTC (클라이언트에서 로컬 변환) |

### 5.2 도메인 영역 분류 (13개 도메인, 54개 테이블)

```
┌─────────────────────────────────────────────────────────────┐
│  [A] 사용자 및 인증 (2)                                      │
│    TB_USER, TB_EMERGENCY_CONTACT                            │
├─────────────────────────────────────────────────────────────┤
│  [B] 그룹, 여행 및 출석체크 (8) ⭐ v3.4 확장               │
│    TB_GROUP, TB_TRIP, TB_GROUP_MEMBER, TB_INVITE_CODE,       │
│    TB_TRIP_SETTINGS ⭐, TB_COUNTRY ⭐,                      │
│    TB_ATTENDANCE_CHECK ⭐, TB_ATTENDANCE_RESPONSE ⭐        │
├─────────────────────────────────────────────────────────────┤
│  [C] 보호자(가디언) (5) ⭐ v3.4 반영                         │
│    TB_GUARDIAN, TB_GUARDIAN_LINK ⭐, TB_GUARDIAN_PAUSE,       │
│    TB_GUARDIAN_LOCATION_REQUEST ⭐, TB_GUARDIAN_SNAPSHOT ⭐   │
├─────────────────────────────────────────────────────────────┤
│  [D] 일정 및 지오펜스 (3)                                    │
│    TB_SCHEDULE, TB_TRAVEL_SCHEDULE, TB_GEOFENCE              │
├─────────────────────────────────────────────────────────────┤
│  [E] 위치 및 이동기록 (8) ⭐ v3.4 확장                        │
│    TB_LOCATION_SHARING, TB_LOCATION ⭐, TB_STAY_POINT,       │
│    TB_SESSION_MAP_IMAGE ⭐, TB_PLANNED_ROUTE ⭐,             │
│    TB_ROUTE_DEVIATION ⭐, TB_LOCATION_SCHEDULE ⭐            │
├─────────────────────────────────────────────────────────────┤
│  [F] 안전 및 SOS (5)                                        │
│    TB_HEARTBEAT, TB_SOS_EVENT, TB_POWER_EVENT,               │
│    TB_SOS_RESCUE_LOG, TB_SOS_CANCEL_LOG                      │
├─────────────────────────────────────────────────────────────┤
│  [G] 채팅 (4)                                               │
│    TB_CHAT_MESSAGE, TB_CHAT_POLL, TB_CHAT_POLL_VOTE,         │
│    TB_CHAT_READ_STATUS                                       │
├─────────────────────────────────────────────────────────────┤
│  [H] 알림 (3)                                               │
│    TB_NOTIFICATION, TB_NOTIFICATION_SETTING,                  │
│    TB_EVENT_NOTIFICATION_CONFIG                               │
├─────────────────────────────────────────────────────────────┤
│  [I] 법적 동의 및 개인정보 (6)                               │
│    TB_USER_CONSENT, TB_MINOR_CONSENT,                        │
│    TB_LOCATION_ACCESS_LOG, TB_LOCATION_SHARING_PAUSE_LOG,    │
│    TB_DATA_DELETION_LOG, TB_DATA_PROVISION_LOG                │
├─────────────────────────────────────────────────────────────┤
│  [J] 운영 및 로그 (3)                                       │
│    TB_EVENT_LOG, TB_LEADER_TRANSFER_LOG, TB_EMERGENCY_NUMBER  │
├─────────────────────────────────────────────────────────────┤
│  [K] 결제/과금 (4) ⭐ 신규                                   │
│    TB_PAYMENT, TB_SUBSCRIPTION, TB_BILLING_ITEM,              │
│    TB_REFUND_LOG                                              │
├─────────────────────────────────────────────────────────────┤
│  [L] B2B (4) ⭐ 신규                                        │
│    TB_B2B_CONTRACT, TB_B2B_SCHOOL, TB_B2B_INVITE_BATCH,      │
│    TB_B2B_MEMBER_LOG                                          │
├─────────────────────────────────────────────────────────────┤
│  [M] Firebase RTDB (스키마 문서화) ⭐ 신규                    │
│    /locations, /geofences, /chats, /presence, /realtime_users │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 핵심 ERD 관계

```
TB_USER (PK: user_id — Firebase UID)
  ├── 1:N → TB_GROUP (owner_user_id)
  ├── 1:N → TB_TRIP (created_by)
  ├── 1:N → TB_GROUP_MEMBER (user_id)
  ├── 1:N → TB_GUARDIAN (traveler / guardian)
  ├── 1:N → TB_GUARDIAN_LINK (member_id / guardian_id) ⭐
  ├── 1:N → TB_CHAT_MESSAGE (sender_id)
  ├── 1:N → TB_NOTIFICATION (user_id)
  ├── 1:N → TB_LOCATION (user_id) ⭐
  ├── 1:N → TB_PAYMENT (user_id) ⭐
  └── 1:N → TB_LOCATION_ACCESS_LOG (user_id)

TB_GROUP
  ├── 1:1 → TB_TRIP
  ├── 1:N → TB_GROUP_MEMBER
  ├── 1:N → TB_INVITE_CODE
  ├── 1:N → TB_GEOFENCE
  ├── 1:N → TB_CHAT_MESSAGE
  └── 1:N → TB_EVENT_LOG

TB_TRIP
  ├── 1:N → TB_GROUP_MEMBER (trip_id)
  ├── 1:N → TB_SCHEDULE / TB_TRAVEL_SCHEDULE
  ├── 1:N → TB_GEOFENCE
  ├── 1:N → TB_HEARTBEAT
  ├── 1:N → TB_SOS_EVENT
  ├── 1:N → TB_NOTIFICATION
  ├── 1:N → TB_CHAT_MESSAGE
  ├── 1:N → TB_GUARDIAN_LINK (trip_id) ⭐
  ├── 1:1 → TB_TRIP_SETTINGS (trip_id) ⭐
  ├── 1:N → TB_PLANNED_ROUTE (trip_id) ⭐
  ├── 1:N → TB_ATTENDANCE_CHECK (trip_id) ⭐
  ├── 1:N → TB_LOCATION_SCHEDULE (trip_id) ⭐
  └── N:1 → TB_B2B_CONTRACT (b2b_contract_id, NULL=B2C) ⭐

TB_ATTENDANCE_CHECK ⭐ (v3.4 신규 — 비즈니스 원칙 v5.1 §05.5)
  ├── N:1 → TB_TRIP (trip_id)
  ├── N:1 → TB_GROUP (group_id)
  ├── N:1 → TB_USER (initiated_by: 캡틴/크루장)
  └── 1:N → TB_ATTENDANCE_RESPONSE (check_id)

TB_ATTENDANCE_RESPONSE ⭐
  ├── N:1 → TB_ATTENDANCE_CHECK (check_id)
  └── N:1 → TB_USER (user_id: 응답 멤버)
      -- UNIQUE(check_id, user_id)

TB_SOS_EVENT
  ├── 1:N → TB_SOS_RESCUE_LOG
  ├── 1:N → TB_SOS_CANCEL_LOG
  └── 1:N → TB_DATA_PROVISION_LOG

TB_SUBSCRIPTION ⭐
  └── 1:N → TB_PAYMENT (subscription_id)

TB_PAYMENT ⭐
  ├── 1:N → TB_BILLING_ITEM (payment_id)
  ├── 1:N → TB_REFUND_LOG (payment_id)
  └── N:1 → TB_GUARDIAN_LINK (is_paid 연동)

TB_B2B_SCHOOL ⭐
  └── 1:N → TB_B2B_CONTRACT (school_id)

TB_B2B_CONTRACT ⭐
  └── 1:N → TB_B2B_INVITE_BATCH (contract_id)

TB_B2B_INVITE_BATCH ⭐
  └── 1:N → TB_B2B_MEMBER_LOG (batch_id)

TB_PLANNED_ROUTE ⭐
  └── 1:N → TB_ROUTE_DEVIATION (route_id)

TB_GUARDIAN_LINK ⭐ (v3.1 신규 — trip 단위 멤버 ↔ 가디언 연결)
  ├── N:1 → TB_TRIP (trip_id)
  ├── N:1 → TB_USER (member_id)
  ├── N:1 → TB_USER (guardian_id)
  └── 1:N → TB_GUARDIAN_PAUSE (link_id)

TB_GUARDIAN_LOCATION_REQUEST ⭐ (v3.4 반영)
  ├── N:1 → TB_GROUP (group_id)
  ├── N:1 → TB_USER (guardian_user_id: 요청자)
  └── N:1 → TB_USER (target_user_id: 피요청자)
      -- 비즈니스 원칙 v5.1 시나리오 5: 가디언 긴급 위치 요청

TB_GUARDIAN_SNAPSHOT ⭐ (v3.4 반영)
  ├── N:1 → TB_GROUP (group_id)
  └── N:1 → TB_USER (user_id: 여행자)
      -- 표준 등급, 비공유 시간대 30분 스냅샷 (§05.4)

TB_LOCATION_SCHEDULE ⭐ (v3.4 신규 — 비즈니스 원칙 v5.1 §04.3)
  ├── N:1 → TB_TRIP (trip_id)
  └── N:1 → TB_USER (user_id: 대상 멤버)
      -- specific_date DATE NULLABLE (특정 일자 스케줄 옵션)
```

### 5.4 데이터 생명주기

| 데이터 유형 | 보관 기간 | 근거 |
|-----------|----------|------|
| 사용자 계정 (soft delete) | 삭제 요청 후 7일 유예 → hard delete | 비즈니스 원칙 v5.1 §14.4 |
| 위치 로그 (TB_LOCATION) | 여행 종료 후 90일 | 위치정보법 준수 |
| 위치 접근 이력 | 생성 후 6개월 | 위치정보법 제16조 |
| Heartbeat | 여행 종료 후 90일 | 서비스 운영 |
| SOS 이벤트 | 해소 후 3년 | 법적 보존 의무 |
| 채팅 메시지 | 여행 종료 후 90일 | 서비스 이용약관 |
| 알림 | 생성 후 30일 | 저장 공간 효율 |
| 동의 이력 | 동의 철회 후 5년 | 개인정보보호법 |
| 데이터 제공 이력 | 영구 보존 | 법적 감사 대상 |
| 미성년자 위치 데이터 | 여행 종료 후 30일 | 미성년자 보호 원칙 |
| 결제 이력 | 결제 후 5년 | 전자상거래법 |
| 체류 포인트 (TB_STAY_POINT) | 여행 종료 후 90일 | 위치 데이터 정책 |

---

## 6. Firebase 인프라

### 6.1 Firebase 서비스 구성

```
Firebase 프로젝트
├── Firebase Authentication
│   └── Phone Auth (OTP 인증)
│       ├── verifyPhoneNumber → OTP 발송
│       ├── signInWithCredential → Firebase ID Token 발급
│       └── 토큰 자동 갱신 (Firebase SDK)
│
├── Firebase Realtime Database (RTDB)
│   ├── M1: /locations/{groupId}/{userId}
│   │   └── {lat, lng, timestamp, battery, accuracy, speed}
│   ├── M2: /geofences/{groupId}
│   │   └── {geofenceId, center, radius, type, ...}
│   ├── M3: /chats/{groupId}/{messageId}
│   │   └── {sender, content, type, timestamp, reply_to, ...}
│   ├── M4: /presence/{userId}
│   │   └── {online, lastSeen}
│   └── M5: /realtime_users/{groupId}/{userId} ⭐
│       └── {lat, lng, speed, battery, is_moving, updated_at}
│
├── Firebase Cloud Messaging (FCM)
│   ├── SOS 알림 (최우선 — priority: high)
│   ├── 지오펜스 이벤트 (high)
│   ├── Heartbeat 타임아웃 경고 (high)
│   ├── 채팅 메시지 (normal)
│   ├── 일정 알림 (normal)
│   └── 시스템 알림 (normal)
│
└── Firebase Storage
    ├── /profiles/{userId}/       # 프로필 이미지
    └── /chats/{groupId}/{file}   # 채팅 미디어 (이미지/동영상/파일)
```

### 6.2 RTDB 보안 규칙

```
locations:
  - 사용자는 자신의 위치 데이터만 쓰기 가능
  - 같은 그룹 멤버만 읽기 가능
  - 보호자 관계 검증 필요

chats:
  - 같은 그룹 멤버만 읽기/쓰기 가능
  - 가디언은 접근 불가 (별도 보호자 메시지 채널)

geofences:
  - 캡틴/크루장만 쓰기 가능
  - 같은 그룹 멤버 + 보호자 읽기 가능

realtime_users: ⭐
  - 사용자는 자신의 노드만 쓰기 가능
  - 같은 그룹 멤버만 읽기 가능
```

### 6.3 RTDB ↔ PostgreSQL 동기화

```
Firebase RTDB (실시간, 휘발성)
    │
    │  JOB-01: location-sync.batch.ts (10분마다)
    │  JOB-07: geofence-scheduler (10분마다)
    │  JOB-08: chat-sync.batch.ts (10분마다)
    │
    ▼
PostgreSQL (영속, 분석용)

동기화 대상:
├── /locations → TB_LOCATION (배치 INSERT)
├── /geofences → TB_GEOFENCE (양방향 동기화)
└── /chats → TB_CHAT_MESSAGE (배치 INSERT)
```

---

## 7. 인증 아키텍처

### 7.1 인증 흐름

```
[1] 사용자 → 전화번호 입력 → Firebase Auth (OTP 발송)
         │
[2] OTP 인증 → Firebase ID Token 발급
         │
[3] ID Token → Backend POST /api/v1/auth/login
         │
[4] Backend → Firebase Admin SDK로 토큰 검증
         │
[5] 검증 성공 → TB_USER auto-upsert
    │  └── 사용자 미존재 시 자동 생성 (display_name, phone_number 저장)
    │  └── 미성년자 여부 확인 → minor_status 설정 ⭐
    │
[6] Backend → 인증 완료 응답 (사용자 정보 + 역할 목록 + 구독 상태)
         │
[7] 이후 모든 API 요청: Authorization: Bearer {Firebase ID Token}
         │
[8] 토큰 만료 → Firebase SDK 자동 갱신 (클라이언트)
```

### 7.2 약관 동의 체계

```
인증 완료 후 약관 동의 확인
    │
    ├── 필수 동의 (모두 동의해야 서비스 이용 가능)
    │   ├── 서비스 이용약관 (terms_of_service)
    │   ├── 개인정보처리방침 (privacy_policy)
    │   ├── 위치정보 수집·이용 (location_collection)
    │   └── 위치기반서비스 이용약관 (lbs_terms)
    │
    ├── 조건부 필수 (해당 시에만)
    │   ├── 국외 이전 동의 (international_transfer) — 해외 여행 시
    │   ├── 가디언 위치 공유 동의 (guardian_location_share) — 가디언 연결 시
    │   └── 미성년자 법정대리인 동의 (minor_guardian) — 14세 미만
    │
    └── 선택 동의
        ├── AI 데이터 활용 (ai_data_usage)
        └── 마케팅 (marketing)
```

동의 이력은 TB_USER_CONSENT에 버전별로 영구 기록된다.

---

## 8. 실시간 위치 공유 아키텍처

### 8.1 위치 수집 → 공유 흐름

```
기기 GPS (flutter_background_geolocation)
    │
    │  위치 업데이트 (백그라운드 포함)
    │  주기: 안전최우선 30초 / 표준 60초 / 프라이버시우선 120초
    │
    ▼
Firebase RTDB: /locations/{groupId}/{userId}
    │  {lat, lng, timestamp, battery, accuracy, speed, bearing}
    │
    ├── Flutter 앱 → RTDB onValue 리스너
    │   ├── 같은 그룹 멤버 위치 수신 (실시간)
    │   ├── 지도에 마커로 표시 (애니메이션 이동)
    │   └── 역할별 정보 밀도 차등 적용
    │       ├── 캡틴/크루장: 전체 멤버 위치 + 배터리 + 속도
    │       ├── 크루: 전체 멤버 위치 (기본 정보만)
    │       └── 가디언: 연결 멤버 위치만
    │
    ├── Backend (JOB-01: location-sync.batch.ts)
    │   └── 10분마다 RTDB → PostgreSQL(TB_LOCATION) 배치 저장
    │
    └── Watchdog 시스템
        └── Heartbeat 모니터링 (타임아웃 감지)
```

### 8.2 프라이버시 등급별 위치 동작

| 동작 | 안전 최우선 | 표준 | 프라이버시 우선 |
|------|:---------:|:----:|:----------:|
| 위치 갱신 주기 | 30초 | 60초 | 120초 |
| 이동기록 저장 | 항상 | 공유 시간만 | 공유 시간만 |
| 가디언 실시간 공유 | 항상 ON | 항상 (OFF 시간 저빈도*) | 일정 연동 |
| 가디언 일시중지 | 불가 | 최대 12시간 | 최대 24시간 |
| 비공유 구간 마스킹 | 없음 (항상 공유) | 회색 표시 | 회색 + "데이터 없음" |
| SOS 위치 전송 | ✅ 항상 | ✅ 항상 | ✅ 항상 (예외 없음) |

> *표준 등급의 "저빈도": 스케줄 OFF 시간대에 가디언에게 실시간 스트리밍 대신 30분 간격 스냅샷 제공

### 8.3 위치 데이터 분류 (L1~L5)

| 등급 | 데이터 유형 | 보관 기간 |
|:----:|-----------|----------|
| L1 | 실시간 위치 (RTDB) | 여행 종료 + 90일 |
| L2 | 이동 로그 (TB_LOCATION) | 여행 종료 + 90일 |
| L3 | Heartbeat (TB_HEARTBEAT) | 여행 종료 + 90일 |
| L4 | SOS/안전 이벤트 | 여행 종료 + 3년 |
| L5 | 체류 포인트 (TB_STAY_POINT) | 여행 종료 + 90일 |
| — | 미성년자 위치 데이터 | 여행 종료 + 30일 |

---

## 9. 이동기록 시스템 아키텍처 ⭐ 신규

### 9.1 이동기록 데이터 흐름

```
TB_LOCATION (PostgreSQL)
    │
    ├── movement_session_id (UUID, 논리키)
    │   └── 세션 단위로 이동 경로 그룹핑
    │
    ├── TB_SESSION_MAP_IMAGE (세션별 지도 스냅샷 캐시)
    │   └── Firebase Storage에 이미지 저장, URL 참조
    │
    ├── TB_PLANNED_ROUTE (계획 경로)
    │   └── 일정 기반 예상 이동 경로
    │
    └── TB_ROUTE_DEVIATION (경로 이탈 기록)
        └── 계획 vs 실제 경로 차이 분석
```

### 9.2 이동기록 화면 구조

```
멤버별 이동기록 화면
├── 상단: 날짜 네비게이션 (< 2/28 >)
├── 좌측 패널: 시간 축 타임라인
│   ├── 이동 구간 (파란색)
│   ├── 체류 구간 (초록색, TB_STAY_POINT)
│   ├── 오프라인 구간 (회색)
│   └── SOS/지오펜스 이벤트 핀
└── 우측 패널: 지도
    ├── 해당 일자 이동 경로 폴리라인
    ├── 체류 포인트 마커
    └── 경로 재생 (Play) 기능
```

### 9.3 역할별 이동기록 접근

| 기능 | 캡틴 | 크루장 | 크루 | 가디언 |
|------|:----:|:------:|:----:|:------:|
| 본인 이동기록 | ✅ | ✅ | ✅ | — |
| 멤버 이동기록 | ✅ (전체) | ✅ (그룹) | ❌ | ✅ (연결만) |
| 경로 비교 | ✅ | ✅ | ❌ | ❌ |
| GPX 내보내기 | ✅ (본인) | ✅ (본인) | ✅ (본인) | ❌ |

---

## 10. 지오펜스 시스템 아키텍처

### 10.1 지오펜스 생성 → 감지 흐름

```
캡틴/크루장 → 지오펜스 생성 (API)
    │
    ▼
PostgreSQL (TB_GEOFENCE)
    │  type: safe | watch | danger | stationary
    │  shape_type: circle | polygon
    │
    ▼  10분마다 동기화
Firebase RTDB: /geofences/{groupId}
    │
    ▼
Flutter 앱 (flutter_background_geolocation)
    │  지오펜스 영역 등록
    │  진입/이탈 이벤트 감지 (백그라운드 포함)
    │
    ├── 지오펜스 진입 (GEOFENCE_ENTER)
    │   └── 이벤트 로그 + FCM 알림 → 캡틴/크루장 + 가디언
    │
    └── 지오펜스 이탈 (GEOFENCE_EXIT)
        └── 이벤트 로그 + FCM 알림 → 캡틴/크루장 + 가디언
```

### 10.2 지오펜스 유형별 동작

| 유형 | 용도 | 진입 알림 | 이탈 알림 | 체류 감지 |
|------|------|:--------:|:--------:|:--------:|
| safe | 안전 구역 (호텔, 집합장소) | ✅ | ✅ 경고 | — |
| watch | 감시 구역 (관광지) | ✅ | ✅ | ✅ |
| danger | 위험 구역 (범죄 다발) | ✅ 경고 | — | — |
| stationary | 정류 지점 (일정 장소) | ✅ | ✅ | ✅ |

---

## 11. SOS 및 Watchdog 시스템 아키텍처

### 11.1 SOS 우선순위 계층

```
Layer 5 (최상위)  │ SOS + 자동 SOS
Layer 4           │ 가디언 긴급 위치 요청 (GUARDIAN_LOCATION_REQUEST)
Layer 3           │ 가디언 긴급 알림 (GUARDIAN_ALERT) + Heartbeat Level 3
Layer 2           │ 지오펜스 / 출석 체크 알림
Layer 1 (기본)    │ 일반 알림 (일정 변경, 멤버 합류 등)
```

SOS는 모든 프라이버시 설정, 위치 공유 설정, 가디언 일시 중지를 무시하고 동작한다.

### 11.2 SOS 시나리오 분류

| 시나리오 | 트리거 | 발송 주체 | 자동/수동 |
|----------|--------|----------|----------|
| A. 정상 SOS | 유저가 SOS 버튼 탭 | 크루/캡틴/크루장 | 수동 |
| B. 오프라인 SOS | 인터넷 없이 SOS 탭 | 크루/캡틴/크루장 | 수동 (큐잉) |
| C. Heartbeat 타임아웃 | 서버 통신 두절 | 서버 (자동) | 자동 |
| D. 전원 꺼짐/배터리 고갈 | 배터리 임계치 도달 | 클라이언트 → 서버 | 자동 |
| E. 납치/강제 전원 차단 | Heartbeat 타임아웃 + 조건 충족 | 서버 (에스컬레이션) | 자동 |
| F. 전원 복구 알림 | 기기 전원 복구 | 클라이언트 → 서버 | 자동 (해소) |

### 11.3 Watchdog 시스템 흐름

```
Flutter 앱
    │
    │  Heartbeat 전송 (주기: 안전최우선 1분 / 표준 3분 / 프라이버시우선 5분)
    │  {user_id, trip_id, location, battery, network_type, app_state, motion_state}
    │
    ▼
Backend (JOB-02: watchdog.batch.ts)
    │
    ├── Heartbeat 수신 → TB_HEARTBEAT 저장
    │
    ├── 상태 판정
    │   ├── Online: 마지막 Heartbeat < 5분
    │   ├── 연결 불안정: 5~15분 미수신
    │   └── 오프라인: 15분+ 미수신
    │
    ├── 타임아웃 감지 (Heartbeat × 3 미수신)
    │   │
    │   ├── 의심 점수 계산
    │   │   ├ 마지막 배터리 < 10%  → +20점
    │   │   ├ 마지막 위치가 위험구역 → +30점
    │   │   ├ 심야 시간대 (22:00~06:00) → +15점
    │   │   └ 이전 SOS 이력 있음 → +10점
    │   │
    │   ├── 의심 점수 ≥ 50 → AUTO_SOS 발동
    │   │   └── 그룹 전체 + 가디언에게 FCM 알림
    │   │
    │   └── 의심 점수 < 50 → 캡틴에게만 주의 알림
    │
    └── 전원 이벤트 감지
        ├── LAST_BEACON (배터리 5% 미만 → 마지막 위치 전송)
        ├── SHUTDOWN (정상 종료 감지)
        └── POWER_RECOVERY (전원 복구 → 그룹에 안전 알림)
```

### 11.4 배터리 기반 Heartbeat 주기 조절

| 배터리 잔량 | Heartbeat 주기 변경 |
|:----------:|:------------------:|
| > 20% | 등급별 기본 주기 |
| 10~20% | 기본 × 2 |
| 5~10% | 기본 × 3 |
| < 5% | LAST_BEACON 전송 후 중단 |

### 11.5 SOS → 구조기관 연결 (마지막 1마일)

```
SOS 발동 (앱 내 알림 완료)
    │
    ▼
구조기관 연결 바텀시트 자동 표시
    │
    ├── [📞 현지 경찰] → 현재 위치 기반 자동 번호 선택
    │   └── TB_EMERGENCY_NUMBER (country_code 기준)
    │
    ├── [📞 현지 구급] → 자동 번호 선택
    │
    ├── [📞 한국 대사관/영사콜센터 1335]
    │
    ├── [📋 위치 복사] → 클립보드 (위도, 경도, 주소)
    │
    └── [📱 SMS 전송] → 오프라인 시 SMS 기반 위치 전송
```

---

## 12. 채팅 시스템 아키텍처

### 12.1 채팅 데이터 흐름

```
Flutter (채팅 UI)
    │
    │  메시지 전송
    │
    ▼
Firebase RTDB: /chats/{groupId}/{messageId}
    │  {sender, content, type, timestamp, reply_to, ...}
    │
    ├── RTDB 리스너 → 같은 그룹 멤버에게 실시간 전달
    │
    ├── FCM → 앱이 백그라운드일 때 푸시 알림
    │
    └── Backend (JOB-08) → TB_CHAT_MESSAGE 영속 저장
```

### 12.2 메시지 유형

| 유형 | 설명 | 예시 |
|------|------|------|
| text | 일반 텍스트 | "내일 9시 로비 집합!" |
| image | 이미지 | 사진 첨부 |
| video | 동영상 | 동영상 첨부 |
| file | 파일 | 문서 첨부 |
| location | 위치 공유 카드 | 미니 지도 + 주소 |
| poll | 투표 | "점심 메뉴 투표" |
| system | 시스템 메시지 | "김인솔님이 일정을 추가했습니다" |

### 12.3 시스템 메시지 자동 삽입

채팅은 단순 메시지 교환이 아니라 여행 이벤트가 자동 삽입되는 "소통 허브" 역할을 한다.

| 이벤트 | 시스템 메시지 레벨 | 예시 |
|--------|:----------------:|------|
| 멤버 합류/탈퇴 | INFO | "박학생님이 여행에 참가했습니다" |
| 일정 추가/변경 | SCHEDULE | "새 일정: 14:00 세느강 크루즈" |
| 지오펜스 이탈 | WARNING | "⚠️ 이학생님이 안전 구역을 벗어났습니다" |
| SOS 발동 | CRITICAL | "🆘 박학생님이 SOS를 발송했습니다" |
| 여행 시작/종료 | CELEBRATION | "🎉 도쿄 여행이 시작되었습니다!" |

---

## 13. 알림 시스템 아키텍처

### 13.1 알림 발송 흐름

```
이벤트 발생 (SOS, 지오펜스, 멤버 합류 등)
    │
    ▼
Backend (notification.service.ts)
    │
    ├── TB_EVENT_NOTIFICATION_CONFIG 조회 (그룹별 알림 규칙)
    │   ├── notify_admins: 캡틴/크루장에게 발송 여부
    │   ├── notify_guardians: 가디언에게 발송 여부
    │   ├── notify_members: 일반 멤버에게 발송 여부
    │   └── is_enabled: 해당 이벤트 알림 활성화 여부
    │
    ├── TB_NOTIFICATION_SETTING 조회 (개인별 알림 설정)
    │   └── 사용자가 해당 이벤트 알림을 끈 경우 → 스킵
    │
    ├── TB_NOTIFICATION에 레코드 생성
    │   └── {priority, channel, title, body, deeplink, expires_at}
    │
    └── FCM 발송 (fcm.service.ts)
        ├── priority: high (SOS, 지오펜스, Heartbeat) / normal (일반)
        └── data: {deeplink, event_type, ...}
```

### 13.2 알림 트리거 매트릭스

| 이벤트 | 캡틴 | 크루장 | 크루 | 가디언 |
|--------|:----:|:------:|:----:|:------:|
| SOS 발송 | ✅ | ✅ | ✅ | ✅ |
| 지오펜스 진입/이탈 | ✅ | ✅ | — | ✅ (등급별) |
| 출석 체크 | — | — | ✅ | — |
| 멤버 합류 | ✅ | ✅ | — | — |
| 여행 시작/종료 | ✅ | ✅ | ✅ | ✅ |
| Heartbeat 타임아웃 | ✅ | — | — | ✅ |
| 전원 꺼짐 | ✅ | — | — | ✅ |
| 결제 완료/실패 | — | — | — | — (본인만) |

---

## 14. AI 서비스 아키텍처

### 14.1 AI 설계 원칙

AI는 안전을 강화하고 번거로움을 줄이되, 절대로 사용자를 대체하지 않는다. AI가 생성한 모든 정보에는 항상 "제안" 또는 "초안" 레이블이 붙으며, 사용자의 확인과 승인을 거친다.

### 14.2 AI 기능 맵 및 과금 체계

```
SafeTrip AI 기능 맵
│
├── 🆓 무료 (안전 기능)
│   ├── AI 안전 어시스턴트 (자연어 안전 Q&A) — 무제한
│   ├── AI 안전 브리핑 자동 생성 — 무제한
│   ├── AI 긴급 상황 현지어 카드 — 무제한
│   ├── AI 여행 설정 추천 — 무제한
│   └── AI 스마트 리마인더 (위치 기반 출발 알림) — 무제한
│
├── ⭐ AI Plus (월 4,900원 / 여행당 2,900원)
│   ├── AI 일정 자동 생성 — 무제한 (무료: 여행당 1회)
│   ├── AI 빠른 번역 — 무제한 (무료: 하루 10건)
│   ├── AI 일정 요약 봇 — 무제한 (무료: 여행당 3일)
│   ├── AI 환율 변환 — 무제한 (무료: 하루 5건)
│   ├── AI 상황 인식 안전 팁 — 무제한 (무료: 하루 3건)
│   └── AI 그룹 상태 요약 — 무제한 (무료: 하루 2회)
│
└── 💎 AI Pro (월 9,900원 / 여행당 5,900원)
    ├── AI Plus 전체 기능 포함
    ├── AI 일정 최적화 (동선 재배치 제안)
    ├── AI 스마트 안전 히트맵
    ├── AI 주변 추천 (현재 위치 기반)
    ├── AI 비상 키워드 감지 → 긴급 액션 제안
    └── AI 이상 패턴 감지 (Watchdog 보조)
```

### 14.3 AI 기술 구현 흐름

```
Flutter 앱 → API 호출 (POST /api/v1/ai/{feature})
    │
    ▼
Backend (ai.service.ts)
    │
    ├── subscription.middleware.ts → 구독 등급 확인 ⭐
    │   ├── 무료: 사용량 체크 (일/여행 단위 한도)
    │   ├── AI Plus: 무제한 (편의 기능)
    │   └── AI Pro: 무제한 (전체 기능)
    │
    ├── 컨텍스트 조립
    │   ├── 여행 정보 (국가, 도시, 기간)
    │   ├── 사용자 프로필 (언어, 여행 스타일)
    │   ├── 현재 위치 (해당 시)
    │   └── 외교부 안전 정보 (해당 시)
    │
    ├── LLM Provider 호출 (REST API)
    │   ├── 프롬프트 + 컨텍스트 전송
    │   └── 응답 수신
    │
    ├── 후처리
    │   ├── 출력 포맷팅
    │   ├── 안전 필터링 (유해 콘텐츠 차단)
    │   └── 출처 및 한계 레이블 첨부
    │
    └── 응답 반환 → Flutter 앱
```

### 14.4 AI 오프라인 대응

| 기능 | 오프라인 전략 |
|------|-------------|
| 긴급 현지어 카드 | 로컬 캐시 (여행 시작 시 사전 다운로드) |
| 안전 브리핑 | 마지막 생성 버전 로컬 캐시 |
| 번역 | "오프라인 — 번역 불가" 메시지 표시 |
| 일정 생성 | 텍스트 입력 큐잉 → 온라인 복귀 시 처리 |

---

## 15. 결제 및 과금 아키텍처 ⭐ 신규

### 15.1 과금 모델 개요

```
SafeTrip 과금 구조
│
├── 기본 여행 기능: 완전 무료
│   └── 위치 공유, SOS, 지오펜스, 채팅, 일정 — 무료
│
├── 유료 가디언 추가
│   ├── 무료: 멤버당 2명까지 기본 제공
│   └── 추가: 3명째부터 1명당 1,900원/여행 (TB_GUARDIAN_LINK.is_paid)
│
├── AI 구독 (TB_SUBSCRIPTION)
│   ├── Free: 기본 안전 AI + 편의 AI 제한 사용
│   ├── AI Plus: 월 4,900원 / 여행당 2,900원
│   └── AI Pro: 월 9,900원 / 여행당 5,900원
│
└── B2B 라이선스 (TB_B2B_CONTRACT)
    └── 기관별 별도 계약
```

### 15.2 결제 흐름

```
Flutter (결제 화면)
    │
    ├── 인앱 결제 (Google Play / App Store)
    │   └── in_app_purchase 플러그인
    │
    └── PG 결제 (웹 결제)
        └── 결제 게이트웨이 SDK
    │
    ▼
Backend (payment.service.ts)
    │
    ├── 결제 검증 (영수증 검증)
    │
    ├── TB_PAYMENT 생성
    │   └── {user_id, amount, payment_method, status, ...}
    │
    ├── TB_BILLING_ITEM 생성 (항목별 상세)
    │
    ├── TB_SUBSCRIPTION 생성/갱신 (구독의 경우)
    │   └── {plan_type, start_date, end_date, auto_renew, ...}
    │
    └── 가디언 결제 시 → TB_GUARDIAN_LINK.is_paid = TRUE
```

### 15.3 결제 DB 테이블 관계

```
TB_SUBSCRIPTION (구독 관리)
    │  plan_type: free | ai_plus_monthly | ai_plus_per_trip | ai_pro_monthly | ai_pro_per_trip
    │
    └── 1:N → TB_PAYMENT (subscription_id)
                  │
                  ├── 1:N → TB_BILLING_ITEM (payment_id)
                  └── 1:N → TB_REFUND_LOG (payment_id)
```

---

## 16. B2B 프레임워크 아키텍처 ⭐ 신규

### 16.1 B2B 시스템 구조

```
B2B 계약 체계
    │
    ├── TB_B2B_CONTRACT (B2B 계약)
    │   ├── contract_type: school | corporate | agency | insurance
    │   ├── billing_type: per_trip | monthly | annual
    │   └── 1:N → TB_B2B_INVITE_BATCH
    │
    ├── TB_B2B_SCHOOL (학교 정보 — 수학여행 특화)
    │   └── 1:N → TB_B2B_CONTRACT (school_id)
    │
    ├── TB_B2B_INVITE_BATCH (일괄 초대코드)
    │   ├── role_mapping: {"teacher": "captain", "student": "crew", "parent": "guardian"}
    │   └── 1:N → TB_B2B_MEMBER_LOG (batch_id)
    │
    └── TB_B2B_MEMBER_LOG (B2B 멤버 참여 이력)
```

### 16.2 B2B 역할 매핑

| B2B 고객 | 캡틴 | 크루장 | 크루 | 가디언 |
|---------|------|-------|------|--------|
| 학교 (수학여행) | 인솔 교사 | 부담임/보조 교사 | 학생 | 학부모/학년 부장 |
| 여행사 (패키지) | 여행 가이드 | 보조 가이드 | 참가자 | 참가자 가족 |
| 기업 (출장) | 팀장/관리자 | 부팀장 | 팀원 | 팀원 가족/회사 안전담당자 |
| 보험사 (제휴) | 보험 계약자 | — | 피보험자 | 보험사 모니터링 |

---

## 17. 데모 투어 시스템 아키텍처 ⭐ 신규

### 17.1 데모 투어 개요

회원가입 전 앱의 핵심 기능을 체험할 수 있는 시뮬레이션 환경을 제공한다.

### 17.2 데모 투어 흐름

```
온보딩 화면
    │
    ├── [체험해 보기] 버튼
    │
    ▼
시나리오 선택
    ├── 시나리오 1: 학교 수학여행 (안전 최우선) — 기본 추천
    ├── 시나리오 2: 친구 여행 (표준)
    └── 시나리오 3: 업무 출장 (프라이버시 우선)
    │
    ▼
데모 체험 (DemoTourService)
    ├── 로컬 시뮬레이션 데이터 (서버 미연결)
    ├── 역할 전환 체험 (캡틴 → 크루장 → 크루 → 가디언)
    ├── 핵심 기능 체험
    │   ├── 실시간 위치 (시뮬레이션)
    │   ├── SOS 발동 (시뮬레이션)
    │   ├── 채팅 (시뮬레이션)
    │   └── 지오펜스 (시뮬레이션)
    └── 서버 데이터 기록 없음
    │
    ▼
[회원가입으로 이동] CTA
```

### 17.3 데모 투어 기술 구현

| 항목 | 설명 |
|------|------|
| 데이터 소스 | 로컬 JSON (하드코딩된 시뮬레이션 데이터) |
| 서버 연결 | 없음 (완전 오프라인 동작) |
| 위치 시뮬레이션 | 사전 녹화된 GPS 좌표 배열 재생 |
| 역할 전환 | 데모 내에서 자유롭게 역할 변경 |
| 데이터 저장 | SharedPreferences에 체험 완료 플래그만 저장 |

---

## 18. 외부 서비스 연동

### 18.1 외교부 API (MOFA)

```
Flutter/Backend → 외교부 안전 정보 API
    │
    ├── GET /mofa/info/{countryCode}
    │   └── 여행경보 단계, 안전 공지, 긴급 연락처
    │
    ├── 캐시 전략
    │   ├── 서버: 6시간 캐시 (Redis 또는 인메모리)
    │   └── 클라이언트: 여행 시작 시 사전 다운로드 → 로컬 캐시
    │
    └── 오프라인: 로컬 캐시 데이터 제공
```

### 18.2 Nominatim API (지오코딩)

```
Flutter → 장소 검색 / 좌표 → 주소 변환
    │
    ├── Forward: 주소 → {lat, lng}
    └── Reverse: {lat, lng} → 주소
```

### 18.3 긴급 구조기관 전화번호 DB

```
TB_EMERGENCY_NUMBER (PostgreSQL)
    │  country_code, number_type, phone_number
    │  (general | police | fire | ambulance | coast_guard)
    │
    ├── 로컬 캐시: 여행 국가 데이터 사전 다운로드
    │
    ├── 업데이트 주기: 수동 + 외교부 API 교차 검증
    │
    └── SOS 발동 시: 현재 위치 국가 자동 판별 → 해당 번호 제공
```

### 18.4 Google Places API (AI Pro)

```
Backend (ai.service.ts) → Google Places API
    │
    ├── AI 주변 추천 기능 (AI Pro 전용)
    │   └── 현재 위치 기반 맛집/관광지 추천
    │
    └── 캐시: 동일 좌표 반경 500m 이내 요청 → 30분 캐시
```

---

## 19. API 엔드포인트 구조

### 기본 URL: `http://[host]:3001/api/v1`

모든 `/api/v1/*` 라우트에는 `authenticate` 미들웨어가 적용된다.

### 19.1 인증

```
POST /auth/login              # Firebase ID Token 로그인
POST /auth/logout             # 로그아웃
```

### 19.2 사용자

```
GET  /users/search?q=         # 사용자 검색 (이름/전화)
GET  /users/:userId           # 프로필 조회
PUT  /users/:userId           # 프로필 수정
POST /users/:userId/profile-image  # 프로필 이미지 업로드
```

### 19.3 여행 (Trip)

```
POST /trips                        # 여행 생성 (+ 그룹 자동 생성)
GET  /trips/users/:userId/trips    # 내 여행 목록
GET  /trips/groups/:groupId        # 그룹별 여행 조회
GET  /trips/:tripId                # 여행 상세
POST /trips/join                   # 여행자로 참가
POST /trips/guardian-join          # 보호자로 참가
POST /trips/invite/:inviteCode     # 초대코드로 참가
GET  /trips/:tripId/settings       # 여행 설정 조회 ⭐
PUT  /trips/:tripId/settings       # 여행 설정 수정 ⭐
```

### 19.4 그룹 (Group)

```
POST /groups                       # 그룹 생성
GET  /groups/:groupId              # 그룹 조회
POST /groups/:groupId/members      # 멤버 추가
GET  /groups/:groupId/members      # 멤버 목록
```

### 19.5 지오펜스

```
POST /geofences                         # 지오펜스 생성
GET  /geofences/groups/:groupId         # 그룹 지오펜스 목록
DELETE /geofences/:geofenceId           # 지오펜스 삭제
```

### 19.6 위치

```
POST /locations                         # 위치 저장
GET  /locations/groups/:groupId         # 멤버 위치 조회
```

### 19.7 이동기록 ⭐ 신규

```
GET  /movement/:userId/trips/:tripId              # 멤버 이동기록 조회
GET  /movement/:userId/trips/:tripId/date/:date   # 일자별 이동기록
GET  /movement/:userId/trips/:tripId/sessions      # 이동 세션 목록
GET  /movement/:userId/trips/:tripId/export/gpx    # GPX 내보내기
GET  /movement/compare                             # 멤버 간 경로 비교
```

### 19.8 보호자

```
POST /trips/:tripId/guardians                     # 가디언 링크 생성 { guardian_phone }
GET  /trips/:tripId/guardian-links                # 가디언 연결 목록 ⭐
PATCH /trips/:tripId/guardians/:linkId/respond    # 가디언 링크 수락/거절 { action: 'accepted'|'rejected' } ⭐
DELETE /trips/:tripId/guardians/:linkId           # 가디언 연결 해제
GET  /trips/:tripId/guardian-view                 # 보호자 뷰 (가디언 전용)
POST /trips/:tripId/guardian-messages/member      # 멤버 → 가디언 메시지 { link_id, message } ⭐
POST /trips/:tripId/guardian-messages/guardian    # 가디언 → 멤버 메시지 { link_id, message }
POST /groups/join-by-code/:guardianCode           # 가디언 그룹 가입 (가디언 코드 기반) ⭐
```

### 19.9 이벤트 & 알림

```
POST /events                    # 이벤트 로그
POST /fcm/register              # FCM 토큰 등록
GET  /notifications             # 알림 목록 조회
PUT  /notifications/:id/read    # 알림 읽음 처리
```

### 19.10 일정

```
POST /schedules                 # 일정 생성
GET  /schedules/trips/:tripId   # 여행 일정 목록
PUT  /schedules/:scheduleId     # 일정 수정
DELETE /schedules/:scheduleId   # 일정 삭제
```

### 19.11 초대코드

```
POST /invite-codes              # 초대코드 생성
GET  /invite-codes/:code        # 코드 조회
POST /invite-codes/:code/use    # 코드 사용
```

### 19.12 여행 가이드 & 국가

```
GET  /guides/countries/:code    # 국가별 여행 가이드
GET  /countries                 # 국가 목록
GET  /mofa/info/:code           # 외교부 안전 정보
```

### 19.13 SOS

```
POST /sos                       # SOS 발동
PUT  /sos/:sosId/resolve        # SOS 해소
GET  /sos/trips/:tripId         # SOS 이력 조회
```

### 19.14 리더 이양

```
POST /leader-transfer/:groupId  # 리더 권한 이양
```

### 19.15 AI

```
POST /ai/schedule-generate      # AI 일정 생성
POST /ai/safety-assistant       # AI 안전 어시스턴트
POST /ai/translate              # AI 번역
POST /ai/schedule-optimize      # AI 일정 최적화 (Pro)
POST /ai/safety-briefing        # AI 안전 브리핑
POST /ai/emergency-phrase       # AI 긴급 현지어 카드
POST /ai/nearby-recommend       # AI 주변 추천 (Pro)
POST /ai/currency-convert       # AI 환율 변환
```

### 19.16 결제/구독 ⭐ 신규

```
POST /payments                  # 결제 생성
GET  /payments/history          # 결제 이력 조회
POST /payments/:paymentId/refund # 환불 요청
GET  /subscriptions/me          # 내 구독 조회
POST /subscriptions             # 구독 생성/변경
DELETE /subscriptions/:subId    # 구독 해지
```

### 19.17 B2B ⭐ 신규

```
POST /b2b/contracts             # B2B 계약 생성
GET  /b2b/contracts/:contractId # 계약 상세 조회
POST /b2b/invite-batches        # 일괄 초대코드 생성
GET  /b2b/invite-batches/:batchId/members  # 배치 멤버 현황
```

### 19.18 출석체크 ⭐ v3.4 신규 (비즈니스 원칙 v5.1 §05.5)

```
POST /trips/:tripId/attendance                        # 출석 체크 시작 (캡틴/크루장 전용)
GET  /trips/:tripId/attendance                        # 출석 체크 목록 조회
GET  /trips/:tripId/attendance/:checkId               # 출석 체크 상세 + 응답 현황
POST /trips/:tripId/attendance/:checkId/respond       # 출석 응답 (크루: present | absent | late)
PUT  /trips/:tripId/attendance/:checkId/close         # 출석 체크 마감 (캡틴/크루장 전용)
```

---

## 20. 보안 아키텍처

### 20.1 인증 및 인가

```
┌─────────────────────────────────────────────────┐
│  Layer 1: 전송 보안                               │
│  ├ HTTPS (TLS 1.2+)                             │
│  └ WebSocket Secure (wss://)                     │
├─────────────────────────────────────────────────┤
│  Layer 2: 인증                                    │
│  ├ Firebase Authentication (Phone OTP)           │
│  ├ Firebase ID Token (JWT 형식)                  │
│  └ auth.middleware.ts (서버 사이드 검증)           │
├─────────────────────────────────────────────────┤
│  Layer 3: 인가 (역할 기반 접근 제어)               │
│  ├ 캡틴: 전체 관리 권한                            │
│  ├ 크루장: 일정/지오펜스/출석 관리                   │
│  ├ 크루: 본인 데이터 + 그룹 읽기                    │
│  └ 가디언: 연결 멤버 읽기 전용                      │
├─────────────────────────────────────────────────┤
│  Layer 4: 데이터 보호                              │
│  ├ PostgreSQL: row-level security (역할 기반)     │
│  ├ Firebase RTDB: 보안 규칙 (그룹 기반 접근 제어)   │
│  ├ 위치 데이터: AES-256 암호화 (lat/lng) ⭐        │
│  ├ 개인정보: soft delete + 보관 기간 준수           │
│  └ 결제 데이터: PCI DSS 준수 (게이트웨이 위임) ⭐   │
├─────────────────────────────────────────────────┤
│  Layer 5: 감사 추적 ⭐                             │
│  ├ TB_LOCATION_ACCESS_LOG: 위치 접근 이력          │
│  ├ TB_DATA_PROVISION_LOG: 데이터 제공 이력          │
│  └ TB_DATA_DELETION_LOG: 데이터 삭제 이력           │
└─────────────────────────────────────────────────┘
```

### 20.2 역할별 데이터 접근 매트릭스

| 데이터 | 캡틴 | 크루장 | 크루 | 가디언 |
|--------|:----:|:------:|:----:|:------:|
| 사용자 정보 (본인) | RW | RW | RW | R |
| 그룹 관리 | RW | R | R | — |
| 여행 정보 | RW | R | R | R (연결) |
| 멤버 위치 | R (전체) | R (그룹) | R (본인) | R (연결) |
| 이동기록 | R (전체) | R (그룹) | R (본인) | R (연결) |
| Heartbeat | R (전체) | R (그룹) | — | R (연결) |
| SOS 이벤트 | RW | R | R (본인) | R (연결) |
| 채팅 | RW | RW | RW | — |
| 초대코드 | RW | R | — | — |
| 결제/구독 | — (본인만) | — (본인만) | — (본인만) | — (본인만) |

---

## 21. 데이터 생명주기 아키텍처 ⭐ 신규

### 21.1 3단계 삭제 파이프라인

```
데이터 보관 기간 만료
    │
    ▼
Stage 1: Soft Delete + 익명화 (Day 91)
    │  ├── deleted_at 타임스탬프 설정
    │  ├── 개인 식별 정보 해시 처리
    │  └── 30일 유예 기간 시작
    │
    ▼
Stage 2: 물리 삭제 (Day 120)
    │  └── PostgreSQL DELETE 실행
    │
    ▼
Stage 3: VACUUM (Day 121)
    │  └── 디스크 공간 회수
    │  └── 복구 불가능 상태
    │
    ▼
TB_DATA_DELETION_LOG에 삭제 이력 기록
```

### 21.2 데이터 보관 기간 표

| 데이터 분류 | 보관 기간 | 법적 근거 |
|-----------|----------|----------|
| L1~L3 위치 데이터 | 여행 종료 + 90일 | 위치정보법 |
| L4 SOS/안전 이벤트 | 여행 종료 + 3년 | 법적 보존 의무 |
| L5 체류 포인트 | 여행 종료 + 90일 | 위치정보법 |
| 미성년자 위치 | 여행 종료 + 30일 | 미성년자 보호 원칙 |
| 위치 접근 이력 | 생성 후 6개월 | 위치정보법 제16조 |
| 사용자 계정 | 삭제 요청 후 7일 | 비즈니스 원칙 v5.1 §14.4 |
| 동의 이력 | 동의 철회 후 5년 | 개인정보보호법 |
| 결제 이력 | 결제 후 5년 | 전자상거래법 |
| 데이터 제공 이력 | 영구 보존 | 법적 감사 대상 |

---

## 22. 오프라인 아키텍처

### 22.1 오프라인 전략 개요

SafeTrip은 해외 여행 환경의 네트워크 불안정성을 고려하여, 핵심 기능이 오프라인에서도 동작하도록 설계한다.

```
Flutter 앱
├── SQLite 로컬 큐 (오프라인 큐)
│   ├── 위치 로그 → 온라인 복귀 시 배치 업로드
│   ├── 채팅 메시지 → 온라인 복귀 시 순서 보장 발송
│   ├── SOS 이벤트 → SMS 폴백 + 온라인 복귀 시 서버 전송
│   └── 일정 변경 → 서버 timestamp 기준 충돌 해결
│
├── 로컬 캐시 (사전 다운로드)
│   ├── 긴급 전화번호 DB (여행 국가)
│   ├── 외교부 안전 정보
│   ├── AI 긴급 현지어 카드
│   ├── 일정 데이터
│   ├── 멤버 프로필 정보
│   └── AI 안전 브리핑 (마지막 생성 버전)
│
└── SMS 폴백
    └── SOS 오프라인 발송: SMS로 위치 + 긴급 메시지 전송
```

### 22.2 기능별 오프라인 대응

| 기능 | 오프라인 시 동작 | 복구 전략 |
|------|:---------------:|----------|
| 위치 기록 | ✅ SQLite 로컬 큐 | 온라인 복귀 시 배치 업로드 |
| SOS 발동 | ✅ SMS 폴백 | 온라인 복귀 시 서버에 이벤트 기록 |
| 채팅 | ✅ 로컬 큐잉 | 온라인 복귀 시 순서 보장 발송 |
| 일정 조회 | ✅ 로컬 캐시 | 서버 timestamp 기준 충돌 해결 |
| 긴급 전화번호 | ✅ 로컬 캐시 | 주기적 업데이트 |
| 이동기록 조회 | ✅ 로컬 캐시 (최근 7일) | 온라인 복귀 시 서버 데이터로 갱신 |
| 알림 | ❌ | 온라인 복귀 시 서버에서 일괄 fetch |
| AI 기능 | ❌ (긴급 카드 + 안전 브리핑만 캐시) | 온라인 복귀 시 재요청 |
| 결제 | ❌ | 온라인 복귀 후 결제 진행 |

---

## 23. 개발 환경 아키텍처

### 23.1 로컬 개발 환경 (ngrok 모드)

```
물리 기기 (Android/iOS)
    │ HTTP (port 80)
    ▼
ngrok HTTP 터널 (schemes: [http] 강제)
    │
    ▼
local-proxy.cjs (port 8888)
    │
    ├── /identitytoolkit.googleapis.com/* → Firebase Auth  :9099
    ├── /v0/*                             → Firebase Storage :9199
    ├── WebSocket upgrade                 → Firebase RTDB   :9000
    └── /*                                → Backend API     :3001
```

> **핵심**: ngrok 기본값은 HTTP→HTTPS 307 리다이렉트를 수행한다. Firebase SDK는 이를 따르지 않아 무음 실패가 발생하므로, `schemes: [http]` 설정으로 HTTP 전용 터널을 사용해야 한다.

### 23.2 Firebase 에뮬레이터

| 서비스 | 포트 | 용도 |
|--------|:----:|------|
| Firebase Auth | 9099 | OTP 인증 에뮬레이션 |
| Firebase RTDB | 9000 | 실시간 DB |
| Firebase Storage | 9199 | 파일 저장소 |
| Firebase Emulator UI | 4000 | 에뮬레이터 관리 UI |

시드 데이터: `emulator-data/` 폴더에 7명의 테스트 사용자 데이터가 포함되어 있다.

### 23.3 개발 스크립트

```
scripts/
├── start-dev-ngrok.sh    # ngrok 모드 6단계 실행 스크립트
├── start-local.sh        # 로컬 환경 전체 설정
├── ngrok.yml             # ngrok 단일 HTTP 터널 설정
└── local-proxy.cjs       # 경로 기반 리버스 프록시 (포트 8888)
```

---

## 24. 프로젝트 디렉토리 구조

```
/mnt/d/Project/15_SafeTrip_New/
├── safetrip-mobile/              # Flutter 앱 (Android/iOS)
├── safetrip-server-api/          # Node.js/TypeScript 백엔드 API
├── safetrip-firebase-function/   # Firebase Cloud Functions
├── shared/                       # 공유 TypeScript 타입 & 유틸
├── safetrip-document/            # 프로젝트 문서
├── scripts/                      # 개발 스크립트 (ngrok, 로컬)
├── emulator-data/                # Firebase Emulator 시드 데이터 (7명)
├── docs/                         # 추가 문서
├── plan/                         # 기획 문서
├── firebase.json                 # Firebase 에뮬레이터 설정
├── .firebaserc                   # Firebase 프로젝트 매핑
├── database.rules.json           # RTDB 보안 규칙
├── storage.rules                 # Storage 보안 규칙
├── README.md
├── LOCAL-DEV-SETUP.md            # 로컬 개발 설정 가이드
└── google-services.json          # Google Services 설정
```

---

## 25. 배포 및 인프라 구성

### 25.1 배포 대상

| 컴포넌트 | 배포 환경 | 비고 |
|---------|----------|------|
| Flutter 앱 | Google Play / App Store | Android + iOS |
| NestJS API | 클라우드 서버 (예: AWS EC2 / GCP) | port 3001 |
| PostgreSQL | 클라우드 DB (예: AWS RDS / GCP Cloud SQL) | PostGIS 활성화 |
| Firebase | Google Firebase Console | Auth, RTDB, FCM, Storage |

### 25.2 환경 분리

```
Development  → Firebase Emulator + 로컬 PostgreSQL + ngrok
Staging      → Firebase 스테이징 프로젝트 + 스테이징 DB
Production   → Firebase 프로덕션 + 프로덕션 DB + CDN
```

---

## 26. 성능 및 확장성 원칙

### 26.1 성능 목표

| 지표 | 목표 | 측정 방법 |
|------|------|----------|
| 위치 업데이트 지연 | < 3초 | Firebase RTDB 리스너 수신 시간 |
| SOS 알림 도달 | < 5초 | FCM 발송 → 수신 시간 |
| API 응답 시간 | < 1초 (p95) | NestJS API 응답 시간 |
| 채팅 메시지 전달 | < 2초 | RTDB 쓰기 → 리스너 수신 시간 |
| 앱 콜드 스타트 | < 3초 | 스플래시 → 메인 화면 진입 시간 |
| 결제 처리 | < 10초 | 결제 요청 → 완료 응답 |

### 26.2 확장성 전략

| 병목 | 전략 |
|------|------|
| RTDB 동시 연결 | Firebase Realtime Database는 동시 연결 200K 지원, 필요 시 샤딩 |
| PostgreSQL 위치 로그 | 파티셔닝 (월별) + 인덱스 최적화 + 보관 기간 이후 자동 삭제 |
| FCM 발송 | 배치 발송 (최대 500건/배치) |
| AI API 호출 | 요청 큐잉 + 레이트 리밋 + 캐싱 (동일 질의 캐시) |
| 결제 처리 | 비동기 큐 + 영수증 검증 재시도 |
| TB_LOCATION 대용량 | PostGIS 공간 인덱스 + movement_session_id 기반 파티셔닝 |

---

## 27. 구현 우선순위

### 27.1 Phase별 아키텍처 구현 범위

| Phase | 우선순위 | 구현 범위 |
|:-----:|:-------:|----------|
| Phase 1 | 🔴 P0 | 인증, 여행 CRUD, 그룹 관리, 실시간 위치 공유, 지오펜스, 기본 SOS, FCM 알림, 기본 채팅 |
| Phase 1 | 🟠 P1 | Heartbeat/Watchdog, 채팅 (투표/시스템 메시지), 알림 시스템, 이동기록 기본, 가디언 일시중지, TB_GUARDIAN_LINK 시스템 |
| Phase 2 | 🟡 P2 | AI 서비스 (무료), 동의 관리, 위치정보법 준수 로그, 긴급 구조기관 연동, 미성년자 보호, 결제 시스템 기본, 데모 투어 |
| Phase 3 | 🟢 P3 | AI Plus/Pro (유료 구독), B2B 프레임워크, 법적 감사 기록, 과금 시스템 완성, 3단계 데이터 삭제 파이프라인, 이동기록 고급 (경로 비교, GPX 내보내기) |

---

## 28. 알려진 이슈

| # | 이슈 | 상태 | 설명 |
|:-:|------|:----:|------|
| 1 | TB_TRIP 컬럼 불일치 | ✅ 해결됨 | DB v3.4에서 CHECK 제약조건 적용 완료 |
| 2 | tb_group_member.trip_id NULL | ✅ 해결됨 | NOT NULL 확정 + 마이그레이션 완료 |
| 3 | schedule.service.ts 불일치 | ✅ 해결됨 | DB v3.4에서 TB_TRAVEL_SCHEDULE 스키마 확정 |
| 4 | 비즈니스 원칙 v5.1 스키마 미반영 | ✅ 해결됨 | DB v3.4에서 전면 반영 (v3.4.1: specific_date, refund_policy 보완) |
| 5 | 신규 테이블 미생성 | ✅ 해결됨 | DB v3.4에서 54개 테이블 전면 재설계 |
| 6 | Watchdog 서비스 미구현 | 🟠 미구현 | Phase 1 P1 구현 예정 |
| 7 | AI 서비스 미구현 | 🟡 미구현 | Phase 2 P2 구현 예정 |
| 8 | 결제 시스템 미구현 | 🟡 미구현 | Phase 2 P2 구현 예정 |
| 9 | B2B 시스템 미구현 | 🟢 미구현 | Phase 3 P3 구현 예정 |
| 10 | 3단계 데이터 삭제 파이프라인 미구현 | 🟢 미구현 | Phase 3 P3 구현 예정 |
| 11 | 출석체크 API 미구현 | 🟠 미구현 | Phase 1 P1 구현 예정 (§19.18) |
| 12 | TB_LOCATION_SCHEDULE 특정일자 API 미구현 | 🟡 미구현 | Phase 2 구현 예정 (specific_date 기반 스케줄 조회) |
| 13 | TB_GUARDIAN_LOCATION_REQUEST API 미구현 | 🟠 미구현 | Phase 1 P1 — 가디언 긴급 위치 요청 API 필요 (§19.8 확장) |
| 14 | TB_GUARDIAN_SNAPSHOT API 미구현 | 🟡 미구현 | Phase 2 — 스냅샷 조회 API (표준 등급 비공유 시간대 30분 스냅샷) |

---

## 29. 검증 체크리스트

| # | 체크 항목 | 상태 |
|:-:|----------|:----:|
| 1 | 문서 목적과 적용 범위가 명시되어 있다 | ✅ |
| 2 | 기준 문서(비즈니스 원칙 v5.1, 마스터 거버넌스 v2.0, DB v3.4)가 명시되어 있다 | ✅ |
| 3 | 역할별(캡틴/크루장/크루/가디언) 접근 권한이 정의되어 있다 (§20.2) | ✅ |
| 4 | 프라이버시 등급별(안전 최우선/표준/프라이버시 우선) 동작 차이가 정의되어 있다 (§8.2) | ✅ |
| 5 | 에러 및 엣지케이스 처리가 포함되어 있다 (§28 알려진 이슈) | ✅ |
| 6 | 검증 체크리스트가 포함되어 있다 (§29) | ✅ |
| 7 | 기존 문서 대비 변경/확장 사항이 명시되어 있다 (v2.0 → v3.1 변경 이력, 부록 A) | ✅ |
| 8 | DB 스키마가 필요한 경우 테이블 구조가 포함되어 있다 (§5) | ✅ |
| 9 | 구현 우선순위(P0~P3)와 Phase 배치가 포함되어 있다 (§27) | ✅ |
| 10 | 오프라인 동작이 해당되는 경우 대응 방안이 포함되어 있다 (§22) | ✅ |

---

## 부록 A: 변경 요약

### A.1 v2.0 → v3.1 변경 요약

| 항목 | v2.0 | v3.1 |
|------|------|------|
| 문서 범위 | 전체 시스템 아키텍처 통합 | + 결제/B2B/이동기록/데모투어/데이터 생명주기 |
| 섹션 수 | 24개 | **29개** |
| DB 테이블 | 38개 / 10개 도메인 | **50개 / 13개 도메인** |
| 기준 DB 문서 | DB v2.0 (참조) | **DB v3.1 완전 반영** |
| 결제 아키텍처 | 미포함 | **신규 (§15)** — TB_PAYMENT, TB_SUBSCRIPTION 등 4개 테이블 |
| B2B 아키텍처 | 미포함 | **신규 (§16)** — TB_B2B_CONTRACT 등 4개 테이블 |
| 이동기록 시스템 | 미포함 | **신규 (§9)** — TB_LOCATION, TB_SESSION_MAP_IMAGE 등 |
| 데모 투어 | 미포함 | **신규 (§17)** — 3개 프리셋 시나리오 |
| 데이터 생명주기 | 보관 기간 표만 기술 | **3단계 삭제 파이프라인 (§21)** 전면 확장 |
| AI 과금 체계 | 무료/유료 구분만 | **Free/AI Plus/AI Pro 3단계 구독 모델 확정** |
| 배치 작업 | 5개 | **8개** (JOB-01~08) |
| API 엔드포인트 | 14개 그룹 | **17개 그룹** (+이동기록, 결제, B2B) |
| 보안 아키텍처 | 4계층 | **5계층** (+감사 추적) |
| 위치 데이터 분류 | 미분류 | **L1~L5 등급 분류** (위치 데이터 정책 v1.0 반영) |
| v2.0 알려진 이슈 | 5개 미해결 | **DB 관련 5개 해결** (새로운 구현 이슈 5개) |
| Firebase RTDB | M1~M4 | **M5 추가** (/realtime_users) |
| 가디언 시스템 | TB_GUARDIAN | **TB_GUARDIAN_LINK 신규** (실제 구현 반영) |
| 여행 설정 | TB_TRIP에 혼재 | **TB_TRIP_SETTINGS 분리** |

### A.2 v3.1 → v3.1.1 변경 요약 (DB v3.4 정합)

| 항목 | v3.1 | v3.1.1 |
|------|------|--------|
| 기준 문서 | 비즈니스 원칙 v5.0, DB v3.1 | **v5.1, DB v3.4** |
| DB 테이블 | 50개 / 13개 도메인 | **54개 / 13개 도메인** |
| [B] 도메인 | 6개 (그룹 및 여행) | **8개** — TB_ATTENDANCE_CHECK, TB_ATTENDANCE_RESPONSE 추가 |
| [C] 도메인 | 3개 (v3.2 신규 테이블 미반영) | **5개** — TB_GUARDIAN_LOCATION_REQUEST, TB_GUARDIAN_SNAPSHOT 반영 |
| [E] 도메인 | 7개 (위치 및 이동기록) | **8개** — TB_LOCATION_SCHEDULE 추가 |
| ERD §5.3 | TB_ATTENDANCE_CHECK 관계 없음 | **출석체크·[C]가디언·B2B·위치스케줄 관계도 추가** |
| 보호자 API §19.8 | 4개 엔드포인트 | **8개** — 가디언 그룹 가입·링크 응답·해제 추가 |
| 출석체크 API | 없음 | **신규 §19.18** — 5개 엔드포인트 |
| 알려진 이슈 | 10개 | **14개** — 출석체크 구현·specific_date·가디언 위치요청·스냅샷 API 이슈 추가 |

---

> **본 문서는 SafeTrip 프로젝트의 전체 시스템 아키텍처에 대한 통합 참조 문서이다. 비즈니스 원칙 v5.1, DB 설계 v3.4, 위치 데이터 정책 v1.0을 반영하며, 결제/과금, B2B 프레임워크, 이동기록 시스템, 데모 투어, 출석체크 시스템, 3단계 데이터 삭제 파이프라인을 통합한다. 개별 기능 원칙 문서에서 아키텍처 변경 시 본 문서도 함께 갱신해야 한다.**
