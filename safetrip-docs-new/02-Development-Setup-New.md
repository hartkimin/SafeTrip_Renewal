# SafeTrip 개발 환경 구축 가이드 (New)

## 📋 목차
1. [사전 요구사항](#사전-요구사항)
2. [필수 도구 설치](#필수-도구-설치)
3. [백엔드 설정 (safetrip-server-api)](#백엔드-설정)
4. [모바일 앱 설정 (safetrip-mobile)](#모바일-앱-설정)
5. [데이터베이스 설정 (PostgreSQL + PostGIS)](#데이터베이스-설정)
6. [Firebase 에뮬레이터 설정](#firebase-에뮬레이터-설정)

---

## 사전 요구사항
- **Node.js**: v18.x 이상
- **Flutter SDK**: ^3.10.0 이상
- **Docker**: 로컬 PostgreSQL 및 PostGIS 실행용
- **Firebase CLI**: 에뮬레이터 및 Cloud Functions 관리용
- **AWS CLI**: RDS 및 S3 접근 설정용

---

## 필수 도구 설치

### 1. Node.js 및 npm
```bash
# Node.js 18 LTS 버전 설치 권장
node --version  # v18.x.x 이상 확인
```

### 2. Flutter SDK
```bash
flutter doctor  # Flutter 및 Android/iOS 개발 환경 확인
```

### 3. Docker (PostgreSQL + PostGIS)
```bash
docker --version
docker-compose --version
```

---

## 백엔드 설정 (safetrip-server-api)

### 1. 의존성 설치
```bash
cd safetrip-server-api
npm install
```

### 2. 환경 변수 설정
`.env.example`을 복사하여 `.env` 파일을 생성하고 필요한 값을 입력합니다.
```env
NODE_ENV=development
PORT=3001
DB_HOST=localhost
DB_PORT=5432
DB_NAME=safetrip
DB_USER=safetrip_user
DB_PASSWORD=local_password
FIREBASE_PROJECT_ID=safetrip-urock
```

### 3. 개발 서버 실행
```bash
npm run start:dev  # NestJS Watch 모드 실행
```

---

## 모바일 앱 설정 (safetrip-mobile)

### 1. 의존성 설치
```bash
cd safetrip-mobile
flutter pub get
```

### 2. 환경 변수 설정
`.env` 파일을 생성하고 API 서버 주소를 설정합니다.
```env
API_SERVER_URL=http://localhost:3001/v1
USE_FIREBASE_EMULATOR=true
```

### 3. 실행
```bash
flutter run  # 연결된 에뮬레이터 또는 기기에서 실행
```
*참고: `flutter_map`을 사용하므로 별도의 Google Maps API 키 설정은 필수가 아니나, Geocoding 서비스를 위해 필요할 수 있습니다.*

---

## 데이터베이스 설정 (PostgreSQL + PostGIS)

### 1. Docker Compose 실행
프로젝트 루트 또는 `safetrip-server-api` 폴더에서 실행 (기존 `docker-compose.yml` 참조).
```bash
docker-compose up -d  # PostgreSQL + PostGIS 컨테이너 시작
```

### 2. 스키마 초기화
`safetrip-document/03-database/database-schema.sql` 파일을 실행하여 테이블을 생성합니다.
```bash
docker exec -i safetrip-postgres psql -U safetrip_user -d safetrip < safetrip-document/03-database/database-schema.sql
```

---

## Firebase 에뮬레이터 설정

### 1. 에뮬레이터 실행
`safetrip-firebase-function` 폴더 또는 루트에서 실행합니다.
```bash
firebase emulators:start --import=./emulator-data --export-on-exit
```

### 2. 주요 포트
- **Firebase UI**: http://localhost:4000
- **RTDB**: http://localhost:9000
- **Auth**: http://localhost:9099
- **Functions**: http://localhost:5001

---

**작성일**: 2026-03-04  
**버전**: 1.0 (NestJS + Flutter 최적화)
