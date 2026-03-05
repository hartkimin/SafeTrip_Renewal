# SafeTrip 데이터베이스 스키마 명세 (New)

## 📋 설계 원칙
SafeTrip은 PostgreSQL 14+와 PostGIS 확장을 사용하여 관계형 데이터 및 지리 공간 데이터를 관리합니다.

### 명명 규칙
- **테이블**: `tb_` 접두사를 사용한 Snake Case (예: `tb_user`, `tb_trip`).
- **PK**: `uuid` (UUID v4) 또는 `varchar(128)` (Firebase UID).
- **공통 컬럼**: `created_at`, `updated_at` 타임스탬프 포함.

---

## 🏗️ 테이블 목록 및 상세 (총 31개)

### 1. 사용자 및 관계 (Users & Relations)
- **`tb_user`**: 사용자 프로필, 프라이버시 설정, 계정 상태.
- **`tb_guardian`**: 보호자-여행자 관계 및 권한 설정.
- **`tb_device_token`**: FCM 푸시 알림용 디바이스 토큰 관리.

### 2. 여행 및 그룹 (Trips & Groups)
- **`tb_trip`**: 개별 여행 정보, 국가 코드, 기간.
- **`tb_group`**: 그룹 여행 정보, 초대 코드(Invite Code).
- **`tb_group_member`**: 그룹별 멤버 역할(Captain, Crew, Guardian) 및 권한.
- **`tb_travel_schedule`**: 그룹 여행 일정 및 장소 정보.

### 3. 위치 및 공간 데이터 (Locations & PostGIS)
- **`tb_location`**: 실시간 위치 이력 (PostGIS `geom` 필드 포함).
- **`tb_geofence`**: 지오펜스 구역 정의 (원형 또는 다각형).
- **`tb_planned_route`**: 여행 계획 경로 (LineString).
- **`tb_route_deviation`**: 경로 이탈 감지 기록.
- **`tb_session_map_image`**: 이동 세션별 지도 이미지 경로 (Firebase Storage).

### 4. 안전 및 알림 (Safety & Events)
- **`tb_sos_alert`**: SOS 긴급 알림 발생 정보.
- **`tb_sos_recipient`**: SOS 알림 수신자 및 응답 상태.
- **`tb_event_log`**: 통합 이벤트 로그 (지오펜스, 배터리, 앱 상태 등).
- **`tb_notification`**: 발송된 알림(푸시, SMS) 이력.
- **`tb_safety_checkin`**: 안전 여부 확인 요청 및 응답 기록.

### 5. 국가 및 가이드 (Country & Static Data)
- **`tb_country`**: 전 세계 국가 기본 정보, 긴급 연락처, 문화 팁.
- **`tb_country_region`**: 국가 내 주요 도시 및 지역 정보.
- **`tb_mofa_risk`**: 외교부 여행 경보 단계 및 설명.
- **`tb_weather_data`**: 실시간 기상 상태 및 예보 정보.
- **`tb_exchange_rate`**: 국가별 실시간 환율 정보 (KRW/USD 기준).

---

## 🗄️ 관계도 (ERD 요약)
- **`tb_user` (1)** ↔ **`tb_trip` (N)**
- **`tb_group` (1)** ↔ **`tb_group_member` (N)** ↔ **`tb_user` (1)**
- **`tb_user` (1)** ↔ **`tb_location` (N)** (PostGIS `geom` 활용)
- **`tb_sos_alert` (1)** ↔ **`tb_sos_recipient` (N)**

---

**상세 SQL 스크립트**: `safetrip-document/03-database/database-schema.sql`  
**작성일**: 2026-03-04  
**버전**: 1.0 (PostgreSQL + PostGIS 최적화 반영)
