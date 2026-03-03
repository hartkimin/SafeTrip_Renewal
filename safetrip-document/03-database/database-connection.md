# SafeTrip 데이터베이스 연결 가이드

## 연결 정보

### AWS RDS (Production)

연결 정보는 환경 변수로 관리됩니다. 실제 비밀번호는 `.env` 파일 또는 AWS Secrets Manager에 저장하세요.

- **인스턴스**: `db-safetrip-dev`
- **엔드포인트**: `db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com`
- **데이터베이스**: `DB_SAFETRIP`
- **사용자**: `safetrip_admin`
- **포트**: `5432`
- **리전**: `ap-northeast-2` (서울)

> **보안 주의**: 비밀번호는 절대 코드나 문서에 평문으로 저장하지 마세요. 환경 변수나 AWS Secrets Manager를 사용하세요.

---

## 방법 1: DBeaver (권장)

### 1. DBeaver 설치
- 다운로드: https://dbeaver.io/download/
- Community Edition (무료)

### 2. AWS RDS 연결 설정
1. **새 연결** → **PostgreSQL** 선택
2. **Main** 탭:
   - Host: `db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com`
   - Port: `5432`
   - Database: `DB_SAFETRIP`
   - Username: `safetrip_admin`
   - Password: 환경 변수에서 가져오거나 직접 입력 (저장하지 않음 권장)
3. **SSL** 탭:
   - Use SSL: ✅ 체크
   - SSL Mode: `require`
4. **Test Connection** → **Finish**

### AWS RDS 연결 문자열
```
jdbc:postgresql://db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com:5432/DB_SAFETRIP?ssl=true&sslmode=require
```

---

## 연결 문자열 (Connection String)

### AWS RDS 표준 PostgreSQL 연결 문자열

환경 변수를 사용하는 것을 권장합니다:

```bash
# 환경 변수에서 읽기
postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require
```

직접 사용 시 (비밀번호는 환경 변수로 대체):
```
postgresql://safetrip_admin:${DB_PASSWORD}@db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com:5432/DB_SAFETRIP?sslmode=require
```

### Node.js (pg) - 환경 변수 사용

```javascript
// safetrip-server-api/.env 파일 사용
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});
```

### Python (psycopg2) - 환경 변수 사용

```python
import os
import psycopg2

conn = psycopg2.connect(
    host=os.getenv('DB_HOST'),
    port=int(os.getenv('DB_PORT', 5432)),
    database=os.getenv('DB_NAME'),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD'),
    sslmode="require"
)
```

---

## 방화벽 설정

### AWS RDS 보안 그룹

RDS 인스턴스의 보안 그룹에서 다음을 설정해야 합니다:

1. **인바운드 규칙**:
   - Type: PostgreSQL
   - Port: 5432
   - Source: 허용할 IP 주소 또는 보안 그룹

2. **현재 IP 확인**:
```powershell
(Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
```

3. **보안 그룹 규칙 추가** (AWS Console 또는 CLI):
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 5432 \
  --cidr YOUR_IP_ADDRESS/32
```

---

## 문제 해결

### 연결 타임아웃
- 보안 그룹 규칙 확인 (IP가 허용 목록에 있는지)
- RDS 인스턴스가 실행 중인지 확인
- VPC 및 서브넷 설정 확인

### SSL 오류
- SSL 모드: `require` 또는 `verify-ca` 사용
- 인증서 검증 실패 시: `rejectUnauthorized: false` (개발 환경만)
- 프로덕션에서는 적절한 SSL 인증서 사용

### 인증 실패
- 사용자 이름/비밀번호 확인
- `safetrip_admin`가 `DB_SAFETRIP` 데이터베이스 접근 권한 확인
- 환경 변수 설정 확인

---

## 보안 권장사항

1. **비밀번호 관리**: 
   - 환경 변수 사용 (`.env` 파일, gitignore에 추가)
   - AWS Secrets Manager 사용 (프로덕션 권장)
   - 절대 코드나 문서에 평문으로 저장하지 않기

2. **IP 제한**: 
   - 필요한 IP만 보안 그룹에 허용
   - VPN 또는 Bastion Host 사용 (프로덕션)

3. **SSL 필수**: 
   - 모든 연결에서 SSL 사용
   - `sslmode=require` 설정

4. **최소 권한**: 
   - 애플리케이션용 사용자는 최소 권한만 부여
   - 읽기 전용 사용자는 별도 생성

5. **정기적인 비밀번호 변경**: 
   - 프로덕션 환경에서는 정기적으로 비밀번호 변경

---

## 빠른 연결 테스트

### psql 명령어 - 환경 변수 사용

```powershell
# 환경 변수 설정
$env:PGPASSWORD='YOUR_PASSWORD_FROM_ENV'
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" `
  -h db-safetrip-dev.cfwmiyowoiwn.ap-northeast-2.rds.amazonaws.com `
  -p 5432 `
  -U safetrip_admin `
  -d DB_SAFETRIP `
  -c "SELECT version();"
```

### 연결 확인 쿼리

#### 기본 연결 테스트
```sql
-- PostgreSQL 버전 확인
SELECT version();

-- PostGIS 확장 확인
SELECT postgis_version();

-- 테이블 개수 확인 (30개 테이블)
SELECT COUNT(*) AS total_tables 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'TB_%';
```

#### 테이블 목록 확인
```sql
-- 모든 테이블 목록 조회
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
```

#### 확장 프로그램 확인
```sql
-- 설치된 확장 프로그램 확인
SELECT 
    extname AS extension_name,
    extversion AS version
FROM pg_extension
WHERE extname IN ('postgis', 'uuid-ossp', 'pg_trgm')
ORDER BY extname;
```

#### 샘플 데이터 확인
```sql
-- 사용자 테이블 확인 (TB_USER)
SELECT 
    COUNT(*) AS user_count,
    COUNT(*) FILTER (WHERE last_verification_at IS NOT NULL) AS verified_users,
    COUNT(*) FILTER (WHERE deleted_at IS NULL) AS active_users
FROM TB_USER;

-- 여행 테이블 확인 (TB_TRIP)
SELECT 
    COUNT(*) AS trip_count,
    COUNT(*) FILTER (WHERE status = 'active') AS active_trips,
    COUNT(DISTINCT country_code) AS country_count
FROM TB_TRIP;

-- 국가 정보 확인 (TB_COUNTRY)
SELECT 
    country_code,
    country_name_ko,
    currency_code,
    mofa_risk_level
FROM TB_COUNTRY
WHERE is_active = true
ORDER BY country_name_ko
LIMIT 10;
```

#### PostGIS 기능 테스트
```sql
-- PostGIS 공간 함수 테스트
SELECT 
    ST_Distance(
        ST_SetSRID(ST_MakePoint(126.9780, 37.5665), 4326)::geography,
        ST_SetSRID(ST_MakePoint(139.6503, 35.6762), 4326)::geography
    ) AS distance_meters;
    
-- 결과: 약 1,301km (서울 ↔ 도쿄)
```

#### 인덱스 확인
```sql
-- 주요 인덱스 확인
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename LIKE 'TB_%'
ORDER BY tablename, indexname;
```

---

## 연결 후 확인 체크리스트

연결 후 다음 항목들을 확인하세요:

- [ ] PostgreSQL 버전 확인 (14 이상)
- [ ] PostGIS 확장 설치 확인
- [ ] 테이블 개수 확인 (30개)
- [ ] 주요 테이블 확인 (TB_USER, TB_TRIP, TB_LOCATION 등)
- [ ] 인덱스 확인 (특히 PostGIS GIST 인덱스)
- [ ] 샘플 데이터 확인 (있는 경우)

---

## 참고 문서

- [데이터베이스 스키마 문서](./database-readme.md)
- [데이터베이스 설정 가이드](./database-setup.md)
- [Firebase Realtime Database](../04-firebase/firebase-rtdb.md)
- [SQL 스키마 파일](./database-schema.sql)
- [DBML 스키마 파일](./database-schema.dbml)
- [환경 변수 설정](../01-getting-started/env-config.md)
