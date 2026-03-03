# SafeTrip 데이터베이스 설정 가이드

## AWS RDS PostgreSQL + PostGIS 생성

### 1단계: AWS RDS 인스턴스 생성

#### 방법 1: AWS CLI 사용

```bash
# RDS 인스턴스 생성
aws rds create-db-instance \
  --db-instance-identifier db-safetrip-dev \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 14.9 \
  --master-username safetrip_admin \
  --master-user-password YOUR_SECURE_PASSWORD \
  --allocated-storage 100 \
  --storage-type gp3 \
  --storage-encrypted \
  --vpc-security-group-ids sg-xxxxxxxxx \
  --db-subnet-group-name safetrip-db-subnet-group \
  --backup-retention-period 7 \
  --multi-az \
  --publicly-accessible \
  --region ap-northeast-2
```

#### 방법 2: AWS Console 사용

1. [AWS Console](https://console.aws.amazon.com/rds/) 접속
2. **데이터베이스 생성** 클릭
3. **PostgreSQL** 선택
4. 설정:
   - **템플릿**: 프로덕션 또는 개발/테스트
   - **DB 인스턴스 식별자**: `db-safetrip-dev`
   - **마스터 사용자 이름**: `safetrip_admin`
   - **마스터 암호**: 강력한 비밀번호 설정
   - **DB 인스턴스 클래스**: `db.t3.medium` (또는 필요에 따라)
   - **스토리지**: `100 GB`, `gp3`
   - **가용성 및 내구성**: 필요에 따라 Multi-AZ 선택
   - **VPC**: 기존 VPC 선택 또는 새로 생성
   - **퍼블릭 액세스**: 개발 환경은 `예`, 프로덕션은 `아니오`
   - **보안 그룹**: PostgreSQL 포트(5432) 허용하는 보안 그룹 선택
5. **데이터베이스 생성** 클릭

### 2단계: 데이터베이스 및 사용자 생성

RDS 인스턴스 생성 후, 연결하여 데이터베이스와 사용자를 생성합니다:

```bash
# RDS 엔드포인트로 연결
psql -h db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com \
     -U postgres \
     -d postgres
```

PostgreSQL에 연결 후:

```sql
-- 데이터베이스 생성
CREATE DATABASE DB_SAFETRIP;

-- 데이터베이스에 연결
\c DB_SAFETRIP

-- 사용자 생성 (이미 마스터 사용자가 있으면 생략 가능)
CREATE USER safetrip_admin WITH PASSWORD 'YOUR_SECURE_PASSWORD';

-- 권한 부여
GRANT ALL PRIVILEGES ON DATABASE DB_SAFETRIP TO safetrip_admin;
GRANT ALL PRIVILEGES ON SCHEMA public TO safetrip_admin;
```

### 3단계: PostGIS 확장 설치

```sql
-- DB_SAFETRIP 데이터베이스에 연결
\c DB_SAFETRIP

-- PostGIS 확장 설치
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 확장 확인
SELECT * FROM pg_extension WHERE extname IN ('postgis', 'uuid-ossp', 'pg_trgm');

-- PostGIS 버전 확인
SELECT PostGIS_Version();
```

### 4단계: 스키마 생성

#### 방법 1: SQL 파일 직접 실행

```bash
# psql 사용
psql -h db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com \
     -U safetrip_admin \
     -d DB_SAFETRIP \
     -f safetrip-document/database_schema.sql
```

#### 방법 2: 단계별 실행

```sql
-- 1. 확장 설치 확인
SELECT postgis_version();
SELECT gen_random_uuid(); -- UUID 함수 테스트

-- 2. 스키마 파일 실행
-- database_schema.sql 파일의 내용을 순서대로 실행
-- 참고: 모든 테이블은 TB_ 접두사를 사용합니다 (예: TB_USER, TB_TRIP)
```

### 5단계: 연결 테스트

```sql
-- 테이블 목록 확인 (30개 테이블)
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'TB_%'
ORDER BY table_name;

-- 테이블 개수 확인
SELECT COUNT(*) AS total_tables
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'TB_%';

-- PostGIS 기능 테스트
SELECT ST_Distance(
  ST_SetSRID(ST_MakePoint(139.6503, 35.6762), 4326)::geography,
  ST_SetSRID(ST_MakePoint(139.6504, 35.6763), 4326)::geography
) as distance_meters;

-- 예상 결과: 약 100-150m

-- 주요 테이블 확인
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('TB_USER', 'TB_TRIP', 'TB_LOCATION', 'TB_SOS_ALERT', 'TB_GROUP')
ORDER BY table_name;
```

---

## 로컬 개발 환경 (Docker)

### Docker Compose로 로컬 PostgreSQL + PostGIS 실행

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgis/postgis:14-3.3
    container_name: safetrip-postgres
    environment:
      POSTGRES_DB: safetrip
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./safetrip-document/database_schema.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

```bash
# Docker Compose 실행
docker-compose up -d

# 로그 확인
docker-compose logs -f postgres

# PostgreSQL 연결
docker exec -it safetrip-postgres psql -U postgres -d safetrip
```

---

## 스키마 검증

```sql
-- 1. 모든 테이블 확인 (30개)
SELECT COUNT(*) as table_count
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'TB_%'
  AND table_type = 'BASE TABLE';

-- 2. PostGIS 확장 확인
SELECT 
  extname as extension_name,
  extversion as version
FROM pg_extension 
WHERE extname IN ('postgis', 'uuid-ossp', 'pg_trgm');

-- 3. 모든 테이블 목록 확인 (30개)
SELECT 
    table_name,
    (SELECT COUNT(*) 
     FROM information_schema.columns 
     WHERE table_schema = 'public' 
       AND table_name = t.table_name) AS column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_name LIKE 'TB_%'
ORDER BY table_name;

-- 4. 인덱스 확인
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename LIKE 'TB_%'
ORDER BY tablename, indexname;

-- 5. 외래 키 확인
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name LIKE 'TB_%'
ORDER BY tc.table_name;

-- 6. PostGIS 함수 테스트
SELECT 
  ST_Distance(
    ST_SetSRID(ST_MakePoint(139.6503, 35.6762), 4326)::geography,
    ST_SetSRID(ST_MakePoint(139.6504, 35.6763), 4326)::geography
  ) as distance_meters;

-- 7. UUID 생성 테스트
SELECT gen_random_uuid() as test_uuid;
```

---

## 환경 변수 설정

### 백엔드 API 환경 변수

```env
# safetrip-server-api/.env
DB_HOST=db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com
DB_PORT=5432
DB_NAME=DB_SAFETRIP
DB_USER=safetrip_admin
DB_PASSWORD=YOUR_SECURE_PASSWORD
DB_SSL=true
```

자세한 환경 변수 설정은 [환경 변수 설정](../01-getting-started/env-config.md)를 참고하세요.

---

## 백업 및 복원

### 자동 백업

AWS RDS는 자동 백업을 지원합니다:

```bash
# 백업 정책 확인
aws rds describe-db-instances \
  --db-instance-identifier db-safetrip-dev \
  --query 'DBInstances[0].BackupRetentionPeriod'

# 수동 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier db-safetrip-dev \
  --db-snapshot-identifier safetrip-manual-snapshot-$(date +%Y%m%d)
```

### 수동 백업/복원

```bash
# 백업
pg_dump "host=db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com port=5432 dbname=DB_SAFETRIP user=safetrip_admin sslmode=require" \
  -F c \
  -f safetrip_backup.dump

# 복원
pg_restore "host=db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com port=5432 dbname=DB_SAFETRIP user=safetrip_admin sslmode=require" \
  -d DB_SAFETRIP \
  safetrip_backup.dump
```

---

## 모니터링 및 최적화

### 성능 모니터링

```sql
-- 활성 연결 수
SELECT count(*) FROM pg_stat_activity;

-- 느린 쿼리 확인
SELECT 
  pid,
  now() - pg_stat_activity.query_start AS duration,
  query,
  state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
  AND state = 'active';

-- 테이블 크기
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE 'TB_%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 인덱스 사용률
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan as index_scans,
  idx_tup_read as tuples_read,
  idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND tablename LIKE 'TB_%'
ORDER BY idx_scan DESC;
```

### AWS RDS 모니터링

AWS Console에서 다음 메트릭을 모니터링할 수 있습니다:
- CPU 사용률
- 메모리 사용률
- 연결 수
- 읽기/쓰기 IOPS
- 스토리지 사용량

---

## 보안 설정

### 보안 그룹 설정

RDS 인스턴스의 보안 그룹에서 다음을 허용해야 합니다:
- **인바운드 규칙**: PostgreSQL 포트(5432)를 허용하는 IP 주소만 허용
- **아웃바운드 규칙**: 필요에 따라 설정

### SSL 연결

모든 연결은 SSL을 사용해야 합니다:

```env
DB_SSL=true
```

연결 문자열에 `sslmode=require`를 포함하세요.

---

## 문제 해결

### 연결 문제

```bash
# RDS 인스턴스 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier db-safetrip-dev

# 연결 테스트
psql "host=db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com port=5432 dbname=DB_SAFETRIP user=safetrip_admin sslmode=require" \
  -c "SELECT version();"
```

### PostGIS 설치 문제

```sql
-- 확장 목록 확인
SELECT * FROM pg_available_extensions WHERE name LIKE 'postgis%';

-- PostGIS 설치
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- 버전 확인
SELECT PostGIS_Version();
```

### 권한 문제

```sql
-- 사용자 권한 확인
SELECT 
  grantee, 
  privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name = 'TB_USER';

-- 권한 부여
GRANT ALL PRIVILEGES ON DATABASE DB_SAFETRIP TO safetrip_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO safetrip_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO safetrip_admin;
```

---

## 다음 단계

1. ✅ 데이터베이스 생성 완료
2. ⏭️ [데이터베이스 연결](./database-connection.md) 설정
3. ⏭️ [Firebase Realtime Database](../04-firebase/firebase-rtdb.md) 설정
4. ⏭️ 백엔드 API 환경 변수 설정
5. ⏭️ 모바일 앱 연동

---

## 참고 문서

- [데이터베이스 연결 가이드](./database-connection.md)
- [데이터베이스 스키마 문서](./database-readme.md)
- [Firebase Realtime Database](../04-firebase/firebase-rtdb.md)
- [SQL 스키마 파일](./database-schema.sql)
- [DBML 스키마 파일](./database-schema.dbml)
