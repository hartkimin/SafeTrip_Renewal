# SafeTrip 데이터베이스 스키마 문서

## 📋 목차

1. [개요](#개요)
2. [기술 스택](#기술-스택)
3. [테이블 목록](#테이블-목록)
4. [ERD](#erd)
5. [설치 및 설정](#설치-및-설정)
6. [주요 쿼리 예제](#주요-쿼리-예제)
7. [성능 최적화](#성능-최적화)
8. [보안 및 프라이버시](#보안-및-프라이버시)

---

## 개요

SafeTrip은 **하이브리드 데이터베이스 아키텍처**를 사용합니다:

- **PostgreSQL (AWS RDS)**: 영구 저장 데이터 (사용자, 여행, 결제, 이벤트 로그 등)
- **Firebase Realtime Database (RTDB)**: 실시간 동기화 데이터 (위치, 지오펜스, 채팅 등)

### PostgreSQL (AWS RDS)

**주요 특징**:
- PostgreSQL 14+ 기반
- PostGIS 확장을 통한 위치 데이터 최적화
- 31개 테이블로 전체 기능 지원
- 시계열 파티셔닝을 통한 확장성 확보
- GDPR/CCPA 준수 설계

**역할**:
- 사용자 계정 및 프로필 관리
- 여행 정보 및 일정 관리
- 이벤트 로그 및 감사 추적
- 복잡한 쿼리 및 분석
- 국가 정보 및 가이드 데이터

### Firebase Realtime Database (RTDB)

**주요 특징**:
- 실시간 동기화
- 오프라인 지원
- 낮은 지연시간
- 자동 동기화

**역할**:
- 실시간 위치 정보 공유
- 실시간 지오펜스 동기화
- 그룹 채팅 메시지
- FCM 토큰 관리

자세한 내용은 [Firebase Realtime Database 가이드](../04-firebase/firebase-rtdb.md)를 참고하세요.

---

## 기술 스택

### 데이터베이스
- **PostgreSQL 14+**: 메인 RDBMS
- **PostGIS**: 지리 공간 데이터 처리
- **pg_trgm**: 전문 검색 최적화

### 확장 도구
> **참고**: 현재 프로덕션에서는 사용하지 않으며, 향후 확장 계획에 포함되어 있습니다.
- **Redis**: 실시간 위치 캐싱 (계획됨)
- **Elasticsearch**: 로그 및 분석 (계획됨)
- **PgBouncer**: 연결 풀링 (계획됨)

---

## 테이블 목록

> **참고**: 모든 테이블 이름은 `tb_` 접두사를 사용합니다 (예: `tb_user`, `tb_trip`). 문서에서는 가독성을 위해 대문자로 표기할 수 있습니다.

### 1. 핵심 테이블 (5개)

| 테이블 | 설명 | 주요 컬럼 |
|--------|------|-----------|
| `TB_USER` | 사용자 계정 및 프로필 | user_id (VARCHAR(128), Firebase Auth UID), phone_number, display_name, location_sharing_mode |
| `TB_TRIP` | 여행 컨텍스트 | trip_id, user_id, group_id, country_code, start_date, trip_type, billing_status |
| `TB_GROUP` | 그룹 여행 | group_id, group_name, invite_code, owner_user_id |
| `TB_GROUP_MEMBER` | 그룹 멤버십 | member_id, group_id, user_id, role, special_role |
| `TB_GUARDIAN` | 보호자 관계 | guardian_id, traveler_user_id, guardian_user_id, guardian_type |

### 2. 위치 및 안전 (6개)

| 테이블 | 설명 | 주요 컬럼 |
|--------|------|-----------|
| `TB_LOCATION` | 실시간 위치 기록 | location_id, user_id, latitude, longitude, geom, tracking_mode, movement_session_id, activity_type, activity_confidence |
| `TB_SOS_ALERT` | 긴급 알림 | sos_id, user_id, alert_type, trigger_method, status, escalation_level |
| `TB_SOS_RECIPIENT` | SOS 수신자 | recipient_id, sos_id, recipient_user_id, recipient_type, channels |
| `TB_GEOFENCE` | 지오펜스 구역 | geofence_id, group_id, name, type, shape_type, polygon_geom, is_active |
| ~~`TB_GEOFENCE_EVENT`~~ | ~~지오펜스 이벤트~~ | ~~TB_EVENT_LOG로 통합됨~~ |
| `TB_SAFETY_CHECKIN` | 안전 체크인 | checkin_id, user_id, checkin_type, status, requested_by_user_id |

### 3. 소통 및 활동 (4개)

| 테이블 | 설명 | 주요 컬럼 |
|--------|------|-----------|
| `TB_GROUP_MESSAGE` | 그룹 채팅 | message_id, group_id, sender_user_id, message_text, created_at |
| `TB_MESSAGE_READ` | 메시지 읽음 | read_id, message_id, user_id, read_at |
| `TB_GROUP_NOTICE` | 그룹 공지 | notice_id, group_id, title, content, priority, created_by_user_id |
| `TB_NOTICE_READ` | 공지 확인 | read_id, notice_id, user_id, read_at |

### 4. 결제 및 구독 (4개) ⚠️ 미사용

> **참고**: 다음 테이블들은 스키마에 정의되어 있으나, 현재 백엔드 코드에서 사용되지 않습니다. 향후 결제 기능 구현 시 사용 예정입니다.

| 테이블 | 설명 | 주요 컬럼 |
|--------|------|-----------|
| `TB_SUBSCRIPTION` | 구독 정보 | subscription_id, user_id, plan_type, status, start_date, end_date |
| `TB_PAYMENT` | 결제 내역 | payment_id, user_id, subscription_id, amount, payment_method, external_payment_id |
| `TB_REDEEM_CODE` | 리딤 코드 | code_id, code, code_type, discount_amount, expires_at |
| `TB_CODE_REDEMPTION` | 코드 사용 내역 | redemption_id, code_id, user_id, redeemed_at |

### 5. 시스템 및 로그 (7개)

| 테이블 | 설명 | 주요 컬럼 |
|--------|------|-----------|
| `TB_NOTIFICATION` | 알림 로그 | notification_id, user_id, notification_type, channel, status |
| `TB_ACTIVITY_LOG` | 활동 로그 | log_id, user_id, activity_type, details, occurred_at |
| `TB_DEVICE_TOKEN` | 디바이스 토큰 | token_id, user_id, device_token, platform, device_name |
| `TB_PLANNED_ROUTE` | 계획 경로 | route_id, trip_id, route_path, start_location, end_location |
| `TB_ROUTE_DEVIATION` | 경로 이탈 기록 | deviation_id, route_id, user_id, location_id, deviation_distance_meters |
| `TB_TRAVEL_SCHEDULE` | 여행 일정 | schedule_id, trip_id, group_id, title, location_coords, scheduled_time |
| `tb_session_map_image` | 세션별 지도 이미지 캐시 | session_id, user_id, map_image_url, map_image_base64 |

### 6. 국가 및 마스터 데이터 (6개)

| 테이블 | 설명 | 주요 컬럼 |
|--------|------|-----------|
| `TB_COUNTRY` | 국가 기본 정보 | country_code, country_name_ko, country_name_en, currency_code, emergency_police, embassies |
| `TB_COUNTRY_REGION` | 국가 내 지역 정보 | region_id, country_code, region_name, region_code, latitude, longitude |
| `TB_MOFA_RISK` | 외교부 위험 정보 | risk_id, country_code, region_code, risk_level, risk_description, is_current |
| `TB_WEATHER_DATA` | 날씨 정보 | weather_id, country_code, region_id, temperature, weather_condition, forecast_type |
| `TB_EXCHANGE_RATE` | 환율 정보 | rate_id, country_code, currency_code, rate_to_usd, rate_to_krw, valid_date |

**총 테이블 수**: 31개

---

## ERD

### 핵심 관계도

```
TB_USER (1) -----> (N) TB_TRIP
                      |
                      | (N) -----> (1) TB_GROUP (1) -----> (N) TB_GROUP_MEMBER
                      |
                      +----> (N) TB_TRAVEL_SCHEDULE
                      |
                      +----> (N) TB_PLANNED_ROUTE -----> (N) TB_ROUTE_DEVIATION

TB_USER (1) -----> (N) TB_LOCATION
  |
  +----> (N) TB_GUARDIAN
  |
  +----> (N) TB_SOS_ALERT -----> (N) TB_SOS_RECIPIENT
  |
  +----> (N) TB_SAFETY_CHECKIN
  |
  +----> (N) TB_GEOFENCE -----> TB_EVENT_LOG (지오펜스 이벤트 통합)
  |
  +----> (N) TB_SESSION_MAP_IMAGE

TB_GROUP (1) -----> (N) TB_GEOFENCE
```

### 주요 관계

1. **TB_USER → TB_TRIP**: 1:N (한 사용자가 여러 여행)
2. **TB_TRIP → TB_GROUP**: N:1 (여러 여행이 하나의 그룹에 속함, 선택적)
3. **TB_GROUP → TB_GROUP_MEMBER**: 1:N (그룹당 여러 멤버)
4. **TB_USER → TB_LOCATION**: 1:N (사용자의 위치 이력)
5. **TB_USER → TB_SOS_ALERT**: 1:N (사용자의 긴급 알림)
6. **TB_SOS_ALERT → TB_SOS_RECIPIENT**: 1:N (SOS 알림 수신자)
7. **TB_USER ↔ TB_USER (TB_GUARDIAN)**: N:M (보호자 관계)
8. **TB_TRIP → TB_PLANNED_ROUTE**: 1:N (여행 경로 계획)
9. **TB_PLANNED_ROUTE → TB_ROUTE_DEVIATION**: 1:N (경로 이탈 기록)
10. **TB_TRIP → TB_TRAVEL_SCHEDULE**: 1:N (여행 일정)

---

## 설치 및 설정

### 1. PostgreSQL 설치

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install postgresql-14 postgresql-contrib-14

# PostGIS 설치
sudo apt install postgresql-14-postgis-3
```

### 2. 데이터베이스 생성

```bash
# PostgreSQL 접속
sudo -u postgres psql

# 데이터베이스 생성
CREATE DATABASE safetrip;

# 사용자 생성
CREATE USER safetrip_user WITH PASSWORD 'your_secure_password';

# 권한 부여
GRANT ALL PRIVILEGES ON DATABASE safetrip TO safetrip_user;
```

### 3. 스키마 적용

```bash
# 스키마 파일 실행
psql -U safetrip_user -d safetrip -f database_schema.sql
```

### 4. 확인

```sql
-- 테이블 목록 확인
\dt

-- 확장 확인
\dx

-- 샘플 쿼리
SELECT * FROM TB_COUNTRY LIMIT 5;
```

---

## 주요 쿼리 예제

### 1. 사용자 생성

```sql
INSERT INTO tb_user (user_id, phone_number, phone_country_code, display_name, language)
VALUES ('firebase_auth_uid_123456789', '+821012345678', '+82', '김철수', 'ko')
RETURNING user_id;
-- user_id는 Firebase Auth UID (VARCHAR(128))를 사용합니다
```

### 2. 여행 시작

```sql
INSERT INTO tb_trip (user_id, country_code, country_name, start_date, end_date, trip_type)
VALUES (
    'firebase_auth_uid_123456789',  -- VARCHAR(128), Firebase Auth UID
    'JPN',
    '일본',
    '2024-04-01',
    '2024-04-07',
    'personal'
)
RETURNING trip_id;
```

### 3. 위치 기록

```sql
INSERT INTO tb_location (
    user_id, 
    latitude, 
    longitude, 
    accuracy, 
    battery_level,
    movement_session_id,
    is_movement_start,
    activity_type,
    activity_confidence
)
VALUES (
    'firebase_auth_uid_123456789',  -- Firebase Auth UID (VARCHAR(128))
    37.5665,
    126.9780,
    10.0,
    85,
    '550e8400-e29b-41d4-a716-446655440000'::uuid,  -- movement_session_id (UUID)
    false,  -- is_movement_start
    'walking',  -- activity_type
    85  -- activity_confidence (0-100)
);
-- PostGIS geom 자동 생성 (트리거: update_location_geom)
-- i_idx 자동 증가 (트리거: set_location_idx)
```

### 4. SOS 발송

```sql
-- SOS 알림 생성
INSERT INTO tb_sos_alert (user_id, trip_id, alert_type, trigger_method, latitude, longitude)
VALUES (
    'firebase_auth_uid_123456789',  -- VARCHAR(128)
    '550e8400-e29b-41d4-a716-446655440000'::uuid,
    'emergency',
    'manual',
    37.5665,
    126.9780
)
RETURNING sos_id;

-- 수신자 추가
INSERT INTO tb_sos_recipient (sos_id, recipient_user_id, recipient_type, channels)
VALUES (
    '550e8400-e29b-41d4-a716-446655440000'::uuid,
    'firebase_auth_uid_987654321',  -- VARCHAR(128)
    'guardian',
    '{"push": true, "sms": true}'::jsonb
);
```

### 5. 그룹 생성 및 멤버 초대

```sql
-- 그룹 생성
INSERT INTO tb_group (group_name, invite_code, owner_user_id)
VALUES (
    '백팩커 동남아',
    'ABC12345',
    'firebase_auth_uid_123456789'  -- VARCHAR(128)
)
RETURNING group_id;

-- 여행을 그룹에 연결
UPDATE tb_trip
SET group_id = '550e8400-e29b-41d4-a716-446655440000'::uuid
WHERE trip_id = '660e8400-e29b-41d4-a716-446655440000'::uuid;

-- 멤버 추가
INSERT INTO tb_group_member (group_id, user_id, role)
VALUES (
    '550e8400-e29b-41d4-a716-446655440000'::uuid,
    'firebase_auth_uid_987654321',  -- VARCHAR(128)
    'member'
);
```

### 6. 지오펜스 생성 (원형)

```sql
INSERT INTO tb_geofence (
    group_id,
    name,
    type,
    shape_type,
    center_latitude,
    center_longitude,
    radius_meters,
    is_always_active,
    trigger_on_enter,
    trigger_on_exit
)
VALUES (
    '550e8400-e29b-41d4-a716-446655440000'::uuid,
    '호텔 주변 안전 구역',
    'safe',
    'circle',
    37.5665,
    126.9780,
    500,
    true,
    true,
    true
);
-- 참고: 지오펜스는 PostgreSQL에 저장되며, Firebase Realtime Database와 동기화됩니다
```

### 7. 근처 위치 검색 (PostGIS)

```sql
-- 특정 지점 1km 이내의 위치 조회
SELECT
    l.location_id,
    l.latitude,
    l.longitude,
    l.activity_type,
    ST_Distance(l.geom, ST_SetSRID(ST_MakePoint(126.9780, 37.5665), 4326)::geography) AS distance_meters
FROM tb_location l
WHERE ST_DWithin(
    l.geom,
    ST_SetSRID(ST_MakePoint(126.9780, 37.5665), 4326)::geography,
    1000
)
ORDER BY distance_meters ASC;
```

### 8. 사용자 활동 타임라인

```sql
SELECT
    l.recorded_at,
    l.latitude,
    l.longitude,
    l.address,
    l.battery_level,
    l.movement_session_id,
    l.activity_type,
    l.activity_confidence
FROM tb_location l
WHERE l.user_id = 'firebase_auth_uid_123456789'  -- VARCHAR(128)
ORDER BY l.recorded_at DESC
LIMIT 100;
```

### 9. 그룹 채팅 조회

```sql
SELECT
    gm.message_id,
    u.display_name,
    gm.message_text,
    gm.created_at,
    CASE
        WHEN mr.read_id IS NOT NULL THEN true
        ELSE false
    END AS is_read
FROM TB_GROUP_MESSAGE gm
JOIN TB_USER u ON gm.sender_user_id = u.user_id
LEFT JOIN TB_MESSAGE_READ mr ON gm.message_id = mr.message_id
    AND mr.user_id = '00000000-0000-0000-0000-000000000001'
WHERE gm.group_id = '00000000-0000-0000-0000-000000000005'
ORDER BY gm.created_at DESC
LIMIT 50;
```

### 10. 구독 상태 확인 ⚠️ 미사용

> **참고**: 다음 쿼리는 스키마에 정의된 테이블을 사용하지만, 현재 백엔드 코드에서 사용되지 않습니다.

```sql
SELECT
    s.subscription_id,
    s.plan_type,
    s.status,
    s.start_date,
    s.end_date,
    EXTRACT(EPOCH FROM (s.end_date - CURRENT_TIMESTAMP)) / 86400 AS days_remaining
FROM tb_subscription s
WHERE s.user_id = 'firebase_auth_uid_123456789'  -- VARCHAR(128)
    AND s.status IN ('active', 'grace')
ORDER BY s.created_at DESC
LIMIT 1;
```

### 11. 국가 정보 조회 (Country_Context)

#### 11.1 기본 국가 정보 조회

```sql
-- 특정 국가의 기본 정보 조회
SELECT
    country_code,
    iso_alpha2,
    country_name_en,
    country_name_ko,
    country_name_local,
    flag_emoji,
    continent,
    primary_language,
    timezone,
    currency_code,
    currency_symbol
FROM TB_COUNTRY
WHERE country_code = 'JPN';
```

#### 11.2 외교부 위험 정보 조회 (MOFA_Risk)

```sql
-- 위험도가 보통 이상인 국가 조회
SELECT
    country_name_ko,
    country_code,
    mofa_risk_level,
    mofa_risk_description,
    mofa_alert_url,
    mofa_last_update
FROM TB_COUNTRY
WHERE mofa_risk_level IN ('medium', 'high', 'very_high')
    AND is_active = true
ORDER BY
    CASE mofa_risk_level
        WHEN 'very_high' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END;

-- 최근 업데이트된 위험 정보 조회
SELECT
    country_name_ko,
    mofa_risk_level,
    mofa_risk_description,
    mofa_last_update
FROM TB_COUNTRY
WHERE mofa_last_update > NOW() - INTERVAL '7 days'
    AND is_active = true
ORDER BY mofa_last_update DESC;
```

#### 11.3 대사관 정보 검색 (JSONB)

```sql
-- 특정 국가의 모든 대사관 정보 조회
SELECT
    country_name_ko,
    country_code,
    embassies
FROM TB_COUNTRY
WHERE country_code = 'JPN';

-- JSONB 배열에서 특정 도시의 대사관 검색
SELECT
    country_name_ko,
    embassy->>'name' AS embassy_name,
    embassy->>'city' AS city,
    embassy->>'address' AS address,
    embassy->>'phone' AS phone,
    embassy->>'emergency_phone' AS emergency_phone,
    embassy->>'email' AS email
FROM TB_COUNTRY,
     jsonb_array_elements(embassies) AS embassy
WHERE country_code = 'JPN'
    AND embassy->>'city' = 'Tokyo';

-- 24시간 긴급 연락처가 있는 대사관 검색
SELECT
    country_name_ko,
    embassy->>'name' AS embassy_name,
    embassy->>'emergency_phone' AS emergency_phone,
    embassy->>'city' AS city
FROM TB_COUNTRY,
     jsonb_array_elements(embassies) AS embassy
WHERE embassy->>'emergency_phone' IS NOT NULL
ORDER BY country_name_ko;
```

#### 11.4 긴급 연락처 조회

```sql
-- 특정 국가의 모든 긴급 연락처
SELECT
    country_name_ko,
    country_code,
    emergency_police,
    emergency_fire,
    emergency_ambulance,
    emergency_coast_guard,
    emergency_tourist_police
FROM TB_COUNTRY
WHERE country_code = 'USA';

-- 국가별 긴급 연락처 목록 (여행 준비용)
SELECT
    country_name_ko,
    flag_emoji,
    CONCAT('Police: ', COALESCE(emergency_police, 'N/A'),
           ' | Fire: ', COALESCE(emergency_fire, 'N/A'),
           ' | Ambulance: ', COALESCE(emergency_ambulance, 'N/A')) AS emergency_numbers
FROM TB_COUNTRY
WHERE is_active = true
ORDER BY country_name_ko;
```

#### 11.5 언어 정보 검색

```sql
-- 영어가 통용되는 국가 검색
SELECT
    country_name_ko,
    country_code,
    primary_language,
    common_languages,
    language_tips
FROM TB_COUNTRY
WHERE common_languages @> '["English"]'
    AND is_active = true;

-- 특정 언어를 사용하는 국가 검색
SELECT
    country_name_ko,
    primary_language,
    common_languages
FROM TB_COUNTRY
WHERE primary_language = 'Japanese'
    OR common_languages @> '["Japanese"]';
```

#### 11.6 시간대 및 시차 계산

```sql
-- 특정 국가의 현재 시각 계산
SELECT
    country_name_ko,
    timezone,
    utc_offset,
    NOW() AT TIME ZONE 'UTC' AT TIME ZONE timezone AS country_current_time,
    NOW() AS server_time
FROM TB_COUNTRY
WHERE country_code = 'JPN';

-- 한국과의 시차 계산
SELECT
    country_name_ko,
    timezone,
    utc_offset,
    dst_info->>'has_dst' AS has_dst,
    EXTRACT(HOUR FROM (NOW() AT TIME ZONE timezone - NOW() AT TIME ZONE 'Asia/Seoul')) AS time_diff_hours
FROM TB_COUNTRY
WHERE is_active = true
ORDER BY country_name_ko;

-- DST(서머타임) 적용 국가 조회
SELECT
    country_name_ko,
    timezone,
    dst_info->>'has_dst' AS has_dst,
    dst_info->>'start_date' AS dst_start,
    dst_info->>'end_date' AS dst_end,
    dst_info->>'offset_change' AS time_change
FROM TB_COUNTRY
WHERE dst_info->>'has_dst' = 'true'
    AND is_active = true;
```

#### 11.7 통화 및 환율 정보

```sql
-- 특정 통화를 사용하는 국가 조회
SELECT
    country_name_ko,
    currency_code,
    currency_name,
    currency_symbol,
    exchange_rate_usd
FROM TB_COUNTRY
WHERE currency_code = 'JPY';

-- 환율 계산 (USD 기준)
SELECT
    country_name_ko,
    currency_code,
    currency_symbol,
    exchange_rate_usd,
    ROUND(100 * exchange_rate_usd, 2) AS price_of_100_usd
FROM TB_COUNTRY
WHERE country_code IN ('JPN', 'USA', 'KOR')
ORDER BY exchange_rate_usd DESC;

-- 최근 환율 업데이트 확인
SELECT
    country_name_ko,
    currency_code,
    exchange_rate_usd,
    last_synced_at
FROM TB_COUNTRY
WHERE last_synced_at IS NOT NULL
    AND is_active = true
ORDER BY last_synced_at DESC
LIMIT 10;
```

#### 11.8 비자 정보 조회

```sql
-- 비자 면제 국가 조회
SELECT
    country_name_ko,
    country_code,
    visa_required,
    visa_free_duration,
    entry_requirements
FROM TB_COUNTRY
WHERE visa_required = false
    AND is_active = true
ORDER BY visa_free_duration DESC NULLS LAST;

-- 한국인 비자 면제 국가 검색
SELECT
    country_name_ko,
    visa_free_duration,
    visa_exemption_countries
FROM TB_COUNTRY
WHERE visa_exemption_countries @> '["KOR"]'
    AND is_active = true
ORDER BY country_name_ko;
```

#### 11.9 여행 안전 팁 검색 (JSONB)

```sql
-- 특정 국가의 모든 안전 팁 조회
SELECT
    country_name_ko,
    safety_tips
FROM TB_COUNTRY
WHERE country_code = 'JPN';

-- 특정 카테고리의 안전 팁 검색
SELECT
    country_name_ko,
    safety_tips->>'general' AS general_tips,
    safety_tips->>'transportation' AS transport_tips,
    safety_tips->>'scams' AS scam_warnings
FROM TB_COUNTRY
WHERE country_code = 'USA';

-- 사기 주의 정보가 있는 국가 검색
SELECT
    country_name_ko,
    safety_tips->>'scams' AS scam_warnings,
    mofa_risk_level
FROM TB_COUNTRY
WHERE safety_tips ? 'scams'
    AND safety_tips->>'scams' IS NOT NULL
    AND is_active = true;
```

#### 11.10 여행 팁 조회 (JSONB)

```sql
-- 특정 국가의 모든 여행 팁
SELECT
    country_name_ko,
    travel_tips->>'best_time_to_visit' AS best_time,
    travel_tips->>'must_visit' AS must_visit,
    travel_tips->>'local_cuisine' AS cuisine,
    travel_tips->>'shopping' AS shopping
FROM TB_COUNTRY
WHERE country_code = 'JPN';

-- 교통 정보 조회
SELECT
    country_name_ko,
    driving_side,
    international_license_accepted,
    public_transport_info,
    transportation_tips
FROM TB_COUNTRY
WHERE country_code IN ('JPN', 'GBR', 'USA');
```

#### 11.11 의료 및 건강 정보

```sql
-- 예방접종 필요 국가 조회
SELECT
    country_name_ko,
    vaccination_requirements,
    health_insurance_required,
    medical_facilities_quality,
    common_health_risks
FROM TB_COUNTRY
WHERE vaccination_requirements IS NOT NULL
    AND vaccination_requirements != '[]'
    AND is_active = true;

-- 특정 예방접종이 필요한 국가 검색
SELECT
    country_name_ko,
    vaccination_requirements
FROM TB_COUNTRY,
     jsonb_array_elements_text(vaccination_requirements) AS vaccine
WHERE vaccine = 'Yellow Fever'
    AND is_active = true;

-- 의료 시설 품질별 국가 분류
SELECT
    medical_facilities_quality,
    COUNT(*) AS country_count,
    string_agg(country_name_ko, ', ' ORDER BY country_name_ko) AS countries
FROM TB_COUNTRY
WHERE is_active = true
    AND medical_facilities_quality IS NOT NULL
GROUP BY medical_facilities_quality;
```

#### 11.12 문화 및 관습 정보

```sql
-- 특정 국가의 문화 정보 조회
SELECT
    country_name_ko,
    cultural_notes,
    taboos,
    etiquette_tips,
    tipping_culture
FROM TB_COUNTRY
WHERE country_code = 'JPN';

-- 팁 문화가 있는 국가 검색
SELECT
    country_name_ko,
    tipping_culture,
    cost_level
FROM TB_COUNTRY
WHERE tipping_culture ILIKE '%required%'
    OR tipping_culture ILIKE '%expected%'
    AND is_active = true;
```

#### 11.13 통신 및 인터넷 정보

```sql
-- 국가별 통신 환경 조회
SELECT
    country_name_ko,
    sim_availability,
    roaming_info,
    wifi_availability,
    internet_censorship
FROM TB_COUNTRY
WHERE country_code IN ('CHN', 'JPN', 'USA');

-- 인터넷 검열이 있는 국가 조회
SELECT
    country_name_ko,
    internet_censorship,
    mofa_risk_level
FROM TB_COUNTRY
WHERE internet_censorship IS NOT NULL
    AND internet_censorship != 'None'
    AND is_active = true;
```

#### 11.14 전압 및 플러그 타입

```sql
-- 전압/플러그 타입별 국가 그룹화
SELECT
    voltage,
    plug_types,
    string_agg(country_name_ko, ', ' ORDER BY country_name_ko) AS countries
FROM TB_COUNTRY
WHERE is_active = true
GROUP BY voltage, plug_types
ORDER BY voltage;

-- 한국과 다른 전압을 사용하는 국가
SELECT
    country_name_ko,
    voltage,
    frequency,
    plug_types
FROM TB_COUNTRY
WHERE voltage != '220V'
    AND is_active = true;
```

#### 11.15 복합 검색 (여행 준비 체크리스트)

```sql
-- 특정 국가의 여행 준비 정보 종합
SELECT
    -- 기본 정보
    country_name_ko AS "국가명",
    flag_emoji AS "국기",

    -- 위험도
    mofa_risk_level AS "외교부_위험단계",

    -- 비자
    CASE
        WHEN visa_required = false THEN '면제 (' || COALESCE(visa_free_duration::text, 'N/A') || '일)'
        ELSE '필요'
    END AS "비자",

    -- 예방접종
    CASE
        WHEN vaccination_requirements IS NULL OR vaccination_requirements = '[]' THEN '불필요'
        ELSE '필요 (상세 확인 필요)'
    END AS "예방접종",

    -- 통화
    currency_code || ' (' || currency_symbol || ')' AS "통화",

    -- 전압
    voltage || ', ' || plug_types AS "전압_플러그",

    -- 시간대
    timezone || ' (UTC' || utc_offset || ')' AS "시간대",

    -- 언어
    primary_language AS "주_언어",

    -- 긴급 연락처
    CONCAT('경찰:', emergency_police, ' 화재:', emergency_fire, ' 응급:', emergency_ambulance) AS "긴급_연락처"

FROM TB_COUNTRY
WHERE country_code = 'JPN';
```

#### 11.16 GIN 인덱스를 활용한 전문 검색

```sql
-- 대사관 정보에서 특정 텍스트 검색 (예: 전화번호 일부)
SELECT
    country_name_ko,
    embassy->>'name' AS embassy_name,
    embassy->>'phone' AS phone
FROM TB_COUNTRY,
     jsonb_array_elements(embassies) AS embassy
WHERE embassy @> '{"phone": "+81-3-3452-7611"}'::jsonb;

-- 안전 팁에서 키워드 검색 (GIN 인덱스 활용)
SELECT
    country_name_ko,
    safety_tips->'general' AS general_safety
FROM TB_COUNTRY
WHERE safety_tips @> '{"general": ["Avoid walking alone at night"]}'::jsonb;

-- 여행 팁 중 특정 속성 검색
SELECT
    country_name_ko,
    travel_tips->>'best_time_to_visit' AS best_time
FROM TB_COUNTRY
WHERE travel_tips ? 'best_time_to_visit'
    AND is_active = true;
```

#### 11.17 데이터 품질 관리

```sql
-- 데이터 품질 점수로 필터링
SELECT
    country_name_ko,
    data_quality_score,
    CASE
        WHEN data_quality_score >= 90 THEN '매우 높음'
        WHEN data_quality_score >= 70 THEN '높음'
        WHEN data_quality_score >= 50 THEN '보통'
        ELSE '낮음'
    END AS quality_level,
    last_synced_at
FROM TB_COUNTRY
WHERE is_active = true
ORDER BY data_quality_score DESC;

-- 업데이트가 필요한 국가 조회 (30일 이상 미동기화)
SELECT
    country_name_ko,
    last_synced_at,
    AGE(NOW(), last_synced_at) AS time_since_sync
FROM TB_COUNTRY
WHERE last_synced_at < NOW() - INTERVAL '30 days'
    OR last_synced_at IS NULL
ORDER BY last_synced_at ASC NULLS FIRST;
```

---

## 성능 최적화

### 1. 인덱스 전략

```sql
-- 위치 데이터 공간 인덱스 (이미 스키마에 생성됨)
CREATE INDEX idx_locations_geom ON tb_location USING GIST(geom);

-- 시계열 데이터 복합 인덱스 (이미 스키마에 생성됨)
CREATE INDEX idx_locations_user_time ON tb_location(user_id, recorded_at DESC);

-- 전문 검색 인덱스
CREATE INDEX idx_group_messages_text ON tb_group_message
USING GIN(to_tsvector('korean', message_text));
```

### 2. 파티셔닝

```sql
-- 위치 데이터 월별 파티셔닝 (향후 확장 시)
CREATE TABLE tb_location_2024_04 PARTITION OF tb_location
FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');

CREATE TABLE tb_location_2024_05 PARTITION OF tb_location
FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');
```

### 3. 쿼리 최적화

```sql
-- 실행 계획 확인
EXPLAIN ANALYZE
SELECT * FROM tb_location
WHERE user_id = 'firebase_auth_uid_123456789'  -- VARCHAR(128)
    AND recorded_at > NOW() - INTERVAL '7 days';

-- 슬로우 쿼리 로깅
ALTER DATABASE safetrip SET log_min_duration_statement = 1000;
```

### 4. 연결 풀링

> **참고**: 현재는 Node.js `pg` Pool을 사용하며, PgBouncer는 향후 확장 시 고려 예정입니다.

```typescript
// 현재 구현: Node.js pg Pool
const pool = new Pool({
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

```bash
# 향후 확장 시 PgBouncer 설정 예시
[databases]
safetrip = host=localhost port=5432 dbname=safetrip

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
```

---

## 보안 및 프라이버시

### 1. 민감 데이터 암호화

```sql
-- 애플리케이션 레벨에서 암호화 권장
-- phone_number, location 데이터는 AES-256으로 암호화
```

### 2. 데이터 보존 정책

```sql
-- 위치 데이터 30일 후 자동 삭제
DELETE FROM tb_location
WHERE recorded_at < NOW() - INTERVAL '30 days';

-- 활동 로그 90일 후 자동 삭제
DELETE FROM tb_activity_log
WHERE occurred_at < NOW() - INTERVAL '90 days';
```

### 3. 접근 제어

```sql
-- 읽기 전용 사용자 생성
CREATE USER safetrip_readonly WITH PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE safetrip TO safetrip_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO safetrip_readonly;

-- 분석용 사용자 (마스킹)
CREATE VIEW users_masked AS
SELECT
    user_id,
    LEFT(phone_number, 3) || '****' || RIGHT(phone_number, 4) AS phone_number,
    display_name,
    created_at
FROM tb_user;

GRANT SELECT ON users_masked TO safetrip_analyst;
```

### 4. 백업 및 복구

```bash
# 전체 백업
pg_dump -U safetrip_user safetrip > safetrip_backup_$(date +%Y%m%d).sql

# 특정 테이블 백업
pg_dump -U safetrip_user -t users -t trips safetrip > safetrip_core_backup.sql

# 복구
psql -U safetrip_user safetrip < safetrip_backup_20240315.sql
```

---

## 모니터링

### 1. 데이터베이스 상태

```sql
-- 활성 연결 수
SELECT count(*) FROM pg_stat_activity;

-- 데이터베이스 크기
SELECT pg_size_pretty(pg_database_size('safetrip'));

-- 테이블 크기
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### 2. 슬로우 쿼리

```sql
-- 슬로우 쿼리 확인 (pg_stat_statements 확장 필요)
SELECT
    query,
    calls,
    total_time,
    mean_time,
    max_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

### 3. 인덱스 사용률

```sql
-- 사용되지 않는 인덱스
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

---

## 다음 단계

### 즉시 구현
- [ ] PostgreSQL + PostGIS 설치
- [ ] 스키마 적용
- [ ] 시드 데이터 추가
- [ ] 마이그레이션 도구 설정

### 성능 최적화
- [ ] Redis 캐싱 레이어 (계획됨)
- [ ] 읽기 복제본 설정
- [ ] 파티셔닝 전략 수립

### 보안 강화
- [ ] 암호화 전략 구현
- [ ] 데이터 보존 자동화
- [ ] 백업 및 복구 자동화

### 모니터링
- [ ] 성능 모니터링 대시보드
- [ ] 알림 시스템 구축
- [ ] 로그 분석 파이프라인

---

## 참고 자료

- [PostgreSQL 공식 문서](https://www.postgresql.org/docs/)
- [PostGIS 문서](https://postgis.net/documentation/)
- [SafeTrip 데이터베이스 스키마](./database-schema.sql)
- [SafeTrip DBML 스키마](./database-schema.dbml)

---

**작성일**: 2024-03-15
**버전**: 1.0
**작성자**: SafeTrip Development Team
