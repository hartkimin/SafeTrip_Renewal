# SafeTrip 프로젝트 개요 (New)

## 📋 프로젝트 요약
SafeTrip은 해외 여행 중 실시간 위치 공유, 지오펜스 알림, SOS 긴급 구조 서비스를 제공하는 하이브리드 안전 플랫폼입니다.

| 항목 | 내용 |
|------|------|
| **모바일 앱** | Flutter (iOS, Android) |
| **백엔드 API** | NestJS (Node.js, TypeScript) |
| **실시간 통신** | Firebase Realtime Database (RTDB), FCM |
| **데이터베이스** | PostgreSQL 14+ (AWS RDS), PostGIS (공간 쿼리) |
| **인프라** | AWS (RDS, ECS), Firebase (Auth, RTDB, Functions, Storage) |

---

## 🏗️ 아키텍처 개요 (Hybrid Architecture)

SafeTrip은 실시간성과 영구 저장, 공간 계산을 모두 만족하기 위해 하이브리드 아키텍처를 채택하고 있습니다.

### 1. 서비스 역할 분리
- **Firebase RTDB**: 실시간 위치 스트림, 지오펜스 활성 정보, 그룹 채팅 메시지, 읽음 상태.
- **PostgreSQL (PostGIS)**: 사용자/여행/그룹 마스터 데이터, 전체 위치 이력, 지오펜스 정의, 공간 계산 (ST_Contains, ST_Distance).
- **Firebase Functions**: RTDB와 PostgreSQL 간의 데이터 동기화 및 비즈니스 로직 처리.
- **NestJS API Server**: 주요 비즈니스 로직, REST API 엔드포인트, 외부 API 연동 (외교부, 구글 맵 등).

### 2. 데이터 흐름
1. **위치 데이터**: 모바일 앱 → Firebase RTDB (최신) → 백엔드 동기화 → PostgreSQL (이력).
2. **지오펜스**: PostgreSQL (정의) → Firebase RTDB (동기화) → 모바일 앱 (실시간 수신/감지).
3. **SOS**: 모바일 앱 → API + Firebase RTDB + SMS → 보호자/그룹원 (즉시 알림).

---

## 📂 프로젝트 구조

### 1. `safetrip-mobile/` (Flutter 앱)
- **Pattern**: Service-Manager-Screen (Clean Architecture 점진적 도입 중)
- **Map**: `flutter_map` (OpenStreetMap 기반)
- **Location**: `flutter_background_geolocation` (백그라운드 추적)
- **Routing**: `go_router` v14

### 2. `safetrip-server-api/` (NestJS 백엔드)
- **Framework**: NestJS v10+
- **ORM**: TypeORM
- **Database**: PostgreSQL + PostGIS
- **Auth**: Firebase ID Token 검증

### 3. `safetrip-firebase-function/` (Firebase Cloud Functions)
- **Language**: TypeScript
- **Role**: RTDB 트리거 기반 데이터 처리 및 백엔드 동기화

---

## 🛡️ 주요 보안 및 프라이버시 원칙
- **프라이버시 등급**: 사용자가 직접 위치 공유 주기 및 정확도(정확 좌표 vs 100m 반경) 설정 가능.
- **미성년자 보호**: 만 14세 미만 사용자의 경우 법정대리인 동의 필수.
- **계정 삭제**: 요청 시 7일간의 유예 기간 후 완전 삭제 (PostgreSQL + Firebase).

---

**작성일**: 2026-03-04  
**버전**: 1.0 (검증 데이터 기반)
