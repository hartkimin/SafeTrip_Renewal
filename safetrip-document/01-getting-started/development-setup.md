# SafeTrip 개발 환경 구축 가이드

## 📋 목차

1. [사전 요구사항](#사전-요구사항)
2. [필수 도구 설치](#필수-도구-설치)
3. [프로젝트 클론 및 초기 설정](#프로젝트-클론-및-초기-설정)
4. [백엔드 개발 환경 설정](#백엔드-개발-환경-설정)
5. [모바일 앱 개발 환경 설정](#모바일-앱-개발-환경-설정)
6. [Firebase Functions 개발 환경 설정](#firebase-safetrip-firebase-function-개발-환경-설정)
7. [로컬 데이터베이스 설정](#로컬-데이터베이스-설정)
8. [Firebase 에뮬레이터 설정](#firebase-에뮬레이터-설정)
9. [개발 서버 실행](#개발-서버-실행)
10. [문제 해결](#문제-해결)

---

## 사전 요구사항

### 필수 계정
- **AWS** 계정 (RDS, ECS, Secrets Manager 사용)
- **Firebase** 프로젝트
- **GitHub** 계정 (또는 Git 저장소)

### 시스템 요구사항
- **OS**: Windows 10+, macOS 10.15+, Ubuntu 20.04+
- **RAM**: 최소 8GB (권장: 16GB)
- **디스크 공간**: 최소 20GB 여유 공간

---

## 필수 도구 설치

### 1. Node.js 및 npm

**Windows (PowerShell):**
```powershell
# Chocolatey 사용
choco install nodejs-lts

# 또는 공식 설치 파일 다운로드
# https://nodejs.org/
```

**macOS:**
```bash
# Homebrew 사용
brew install node@18

# 또는 공식 설치 파일 다운로드
```

**Linux (Ubuntu/Debian):**
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**설치 확인:**
```bash
node --version  # v18.x.x 이상
npm --version   # 9.x.x 이상
```

---

### 2. Flutter SDK

**Windows:**
```powershell
# Chocolatey 사용
choco install flutter

# 또는 수동 설치
# https://docs.flutter.dev/get-started/install/windows
```

**macOS:**
```bash
# Homebrew 사용
brew install --cask flutter

# 또는 수동 설치
```

**Linux:**
```bash
# 수동 설치
# https://docs.flutter.dev/get-started/install/linux
```

**설치 확인:**
```bash
flutter doctor
```

**필수 설정:**
```bash
# Android Studio 설치 (Android 개발용)
# Xcode 설치 (macOS, iOS 개발용)
flutter doctor --android-licenses  # Android 라이선스 동의
```

---

### 3. Docker (로컬 데이터베이스용)

**Windows:**
- [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) 다운로드 및 설치

**macOS:**
```bash
brew install --cask docker
```

**Linux:**
```bash
sudo apt-get install docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
```

**설치 확인:**
```bash
docker --version
docker-compose --version
```

---

### 4. AWS CLI

**Windows (PowerShell):**
```powershell
# MSI 설치 파일 다운로드
# https://aws.amazon.com/cli/

# 또는 Chocolatey 사용
choco install awscli
```

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**설정:**
```bash
aws configure
# AWS Access Key ID 입력
# AWS Secret Access Key 입력
# Default region name: ap-northeast-2
# Default output format: json
```

**설치 확인:**
```bash
aws --version
aws sts get-caller-identity
```

---

### 5. Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

**설치 확인:**
```bash
firebase --version
```

---

### 6. Git

**Windows:**
```powershell
choco install git
```

**macOS:**
```bash
brew install git
```

**Linux:**
```bash
sudo apt-get install git
```

**설정:**
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

## 프로젝트 클론 및 초기 설정

### 1. 저장소 클론

```bash
git clone https://github.com/your-org/SafeTrip.git
cd SafeTrip
```

### 2. 프로젝트 구조 확인

```bash
# 프로젝트 구조 확인
ls -la
# safetrip-mobile/, safetrip-server-api/, safetrip-firebase-function/, safetrip-document/ 폴더 확인
```

---

## 백엔드 개발 환경 설정

### Node.js 백엔드 (Express + TypeScript)

#### 1. 의존성 설치

```bash
cd safetrip-server-api
npm install
```

#### 2. 환경 변수 설정

```bash
# .env.example을 복사하여 .env 생성
cp .env.example .env

# .env 파일 편집 (필요한 값 입력)
# 자세한 내용은 ENV_CONFIG.md 참고
```

**주요 환경 변수:**
```env
NODE_ENV=development
PORT=3001
DB_HOST=localhost
DB_PORT=5432
DB_NAME=safetrip
DB_USER=safetrip_user
DB_PASSWORD=local_password
DB_SSL=false
FIREBASE_PROJECT_ID=safetrip-urock
FIREBASE_DATABASE_URL=https://safetrip-urock-default-rtdb.firebaseio.com
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

#### 3. 데이터베이스 스키마 생성

```bash
# 로컬 PostgreSQL에 스키마 실행
psql -h localhost -U safetrip_user -d safetrip -f ../safetrip-document/database_schema.sql

# 또는 Docker 내부에서 실행
docker exec -i safetrip-postgres psql -U safetrip_user -d safetrip < ../safetrip-document/database_schema.sql
```

#### 4. 개발 서버 실행

```bash
# 개발 모드 (Hot Reload)
npm run dev

# 또는
npm start
```

**확인:**
- API 서버: http://localhost:3001
- Health Check: http://localhost:3001/health

---

## 모바일 앱 개발 환경 설정

### Flutter 프로젝트 설정

#### 1. 의존성 설치

```bash
cd safetrip-mobile
flutter pub get
```

#### 2. Firebase 설정 파일 추가

**Android:**
- `android/app/google-services.json` 파일 추가
- Firebase Console에서 다운로드

**iOS:**
- `ios/Runner/GoogleService-Info.plist` 파일 추가
- Firebase Console에서 다운로드

#### 3. 환경 변수 설정

```bash
# .env 파일 생성
cp .env.example .env

# .env 파일 편집
# API_BASE_URL=http://localhost:3001/v1
# GOOGLE_MAPS_API_KEY_IOS=your_ios_key
# GOOGLE_MAPS_API_KEY_ANDROID=your_android_key
```

#### 4. Google Maps API 키 설정

**Android:**
`android/app/src/main/AndroidManifest.xml`:
```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
    </application>
</manifest>
```

**iOS:**
`ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    return true
}
```

#### 5. 개발 서버 실행

```bash
# 연결된 기기 확인
flutter devices

# 실행
flutter run

# 특정 기기 선택
flutter run -d <device-id>
```

**Android 에뮬레이터:**
```bash
# Android Studio에서 AVD Manager 실행
# 또는 명령어로 실행
emulator -avd Pixel_5_API_33
```

**iOS 시뮬레이터 (macOS만):**
```bash
open -a Simulator
```

---

## Firebase Functions 개발 환경 설정

### Cloud Functions 설정

#### 1. 의존성 설치

```bash
cd safetrip-firebase-function
npm install
```

#### 2. 환경 변수 설정

**로컬 개발용:**

`.env.local` 파일 생성:
```env
DATABASE_URL=postgresql://safetrip_user:password@localhost:5432/safetrip
FIREBASE_PROJECT_ID=your_project_id
```

**Firebase Functions 환경 변수 설정:**

```bash
firebase functions:config:set \
  db.host="YOUR_DB_HOST" \
  db.port="5432" \
  db.name="safetrip" \
  db.user="safetrip_user" \
  db.password="YOUR_PASSWORD"
```

#### 3. 로컬 에뮬레이터 실행

```bash
# Firebase 에뮬레이터 시작
firebase emulators:start

# 특정 기능만 실행
firebase emulators:start --only functions
```

---

## 로컬 데이터베이스 설정

### Docker Compose 사용 (권장)

**프로젝트 루트에 `docker-compose.yml` 생성:**

```yaml
version: '3.8'

services:
  postgres:
    image: postgis/postgis:14-3.3
    container_name: safetrip-postgres
    environment:
      POSTGRES_DB: safetrip
      POSTGRES_USER: safetrip_user
      POSTGRES_PASSWORD: safetrip_dev_password
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U safetrip_user"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

**실행:**
```bash
# Docker Compose 실행
docker-compose up -d

# 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f postgres
```

**데이터베이스 초기화:**
```bash
# 스키마 생성
psql -h localhost -U safetrip_user -d safetrip -f safetrip-document/database_schema.sql

# 또는 Docker 내부에서 실행
docker exec -i safetrip-postgres psql -U safetrip_user -d safetrip < safetrip-document/database_schema.sql
```

**정리:**
```bash
# 컨테이너 중지
docker-compose down

# 데이터까지 삭제
docker-compose down -v
```

---

## Firebase 에뮬레이터 설정

### 에뮬레이터 시작

```bash
# 모든 에뮬레이터 시작
firebase emulators:start

# 특정 에뮬레이터만 시작
firebase emulators:start --only firestore,functions

# UI 포함
firebase emulators:start --ui
```

**에뮬레이터 포트:**
- Firebase UI: http://localhost:4000
- Firestore: localhost:8080
- Realtime Database: localhost:9000
- Functions: localhost:5001

### 에뮬레이터 데이터 초기화

```bash
# 에뮬레이터 데이터 내보내기
firebase emulators:export ./emulator-data

# 에뮬레이터 데이터 가져오기
firebase emulators:start --import ./emulator-data
```

---

## 개발 서버 실행

### 전체 개발 환경 실행 순서

#### 1. 데이터베이스 시작

```bash
# Docker Compose로 PostgreSQL 시작
docker-compose up -d
```

#### 2. 백엔드 API 서버 시작

```bash
cd safetrip-server-api
npm run dev
```

**확인:**
- API 서버: http://localhost:3001
- Health Check: http://localhost:3001/health

#### 3. Flutter 앱 실행

```bash
cd safetrip-mobile
flutter run
```

#### 4. Firebase 에뮬레이터 (선택사항)

```bash
cd safetrip-firebase-function
firebase emulators:start
```

---

## 문제 해결

### 일반적인 문제

#### 1. Node.js 버전 불일치

**문제**: `npm install` 실패 또는 호환성 오류

**해결:**
```bash
# Node.js 버전 확인
node --version

# nvm 사용 시 버전 변경
nvm install 18
nvm use 18
```

#### 2. Flutter 의존성 오류

**문제**: `flutter pub get` 실패

**해결:**
```bash
# Flutter 캐시 정리
flutter clean
flutter pub get

# Flutter 업그레이드
flutter upgrade
```

#### 3. 데이터베이스 연결 실패

**문제**: PostgreSQL 연결 오류

**해결:**
```bash
# Docker 컨테이너 상태 확인
docker-compose ps

# PostgreSQL 로그 확인
docker-compose logs postgres

# 연결 테스트
psql -h localhost -U safetrip_user -d safetrip
```

#### 4. Firebase 설정 파일 누락

**문제**: Firebase 초기화 오류

**해결:**
- Android: `android/app/google-services.json` 확인
- iOS: `ios/Runner/GoogleService-Info.plist` 확인
- Firebase Console에서 파일 다운로드

#### 5. Google Maps API 키 오류

**문제**: 지도가 표시되지 않음

**해결:**
- Android: `AndroidManifest.xml`에서 API 키 확인
- iOS: `AppDelegate.swift`에서 API 키 확인
- Google Cloud Console에서 API 키 활성화 확인

#### 6. 포트 충돌

**문제**: 포트가 이미 사용 중

**해결:**
```bash
# Windows
netstat -ano | findstr :3001
taskkill /PID <PID> /F

# macOS/Linux
lsof -ti:3001 | xargs kill -9
```

---

## 개발 환경 체크리스트

### 초기 설정 완료 확인

- [ ] Node.js 18+ 설치 확인
- [ ] Flutter SDK 설치 확인
- [ ] Docker 설치 확인
- [ ] AWS CLI 설치 및 설정 확인
- [ ] Firebase CLI 설치 및 로그인 확인
- [ ] 프로젝트 클론 완료
- [ ] 백엔드 의존성 설치 완료
- [ ] 모바일 앱 의존성 설치 완료
- [ ] 환경 변수 파일 생성 완료
- [ ] 로컬 데이터베이스 설정 완료
- [ ] Firebase 설정 파일 추가 완료
- [ ] Google Maps API 키 설정 완료

### 개발 서버 실행 확인

- [ ] PostgreSQL 컨테이너 실행 확인
- [ ] 백엔드 API 서버 실행 확인
- [ ] Flutter 앱 실행 확인
- [ ] Firebase 에뮬레이터 실행 확인 (선택사항)

---

## 참고 문서

- [환경 변수 설정](../01-getting-started/env-config.md) - 환경 변수 설정 가이드
- [데이터베이스 설정](../03-database/database-setup.md) - 데이터베이스 설정 가이드
- [데이터베이스 연결](../03-database/database-connection.md) - 데이터베이스 연결 가이드
- [API 가이드](../05-api/api-guide.md) - API 사용 가이드
- [배포 가이드](../01-getting-started/deployment.md) - 배포 가이드

---

**작성일**: 2025-01-15  
**버전**: 2.0 (AWS 기준)
