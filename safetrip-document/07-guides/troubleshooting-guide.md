# SafeTrip 트러블슈팅 가이드

## 목차

1. [일반적인 문제](#일반적인-문제)
2. [Flutter 앱 문제](#flutter-앱-문제)
3. [백엔드 API 문제](#백엔드-api-문제)
4. [데이터베이스 문제](#데이터베이스-문제)
5. [Firebase 문제](#firebase-문제)
6. [배포 문제](#배포-문제)
7. [성능 문제](#성능-문제)

---

## 일반적인 문제

### 개발 환경 설정 오류

#### 문제: Node.js 버전 불일치

**증상**
```
Error: The engine "node" is incompatible with this module
```

**해결 방법**
```bash
# Node.js 버전 확인
node --version

# nvm 사용 시 버전 변경
nvm install 18
nvm use 18

# 또는 프로젝트 루트에 .nvmrc 파일 생성
echo "18" > .nvmrc
nvm use
```

#### 문제: Flutter SDK 버전 불일치

**증상**
```
Error: The current Flutter SDK version is 3.8.0, but a higher version is required.
```

**해결 방법**
```bash
# Flutter 버전 확인
flutter --version

# Flutter 업그레이드
flutter upgrade

# pubspec.yaml의 SDK 버전 확인
# environment:
#   sdk: ^3.10.0
```

### 의존성 설치 오류

#### 문제: npm install 실패

**증상**
```
npm ERR! code ELIFECYCLE
npm ERR! errno 1
```

**해결 방법**
```bash
# 캐시 삭제 후 재설치
npm cache clean --force
rm -rf node_modules package-lock.json
npm install

# 또는 yarn 사용
yarn install
```

#### 문제: Flutter pub get 실패

**증상**
```
Error: Could not find a file named "pubspec.yaml"
```

**해결 방법**
```bash
# 올바른 디렉토리로 이동
cd safetrip-mobile

# 의존성 재설치
flutter clean
flutter pub get

# pubspec.lock 삭제 후 재시도
rm pubspec.lock
flutter pub get
```

---

## Flutter 앱 문제

### 빌드 오류

#### 문제: Android 빌드 실패

**증상**
```
Execution failed for task ':app:mergeDebugResources'
```

**해결 방법**
```bash
# Flutter 클린
flutter clean

# Android 빌드 캐시 삭제
cd android
./gradlew clean
cd ..

# 재빌드
flutter build apk
```

#### 문제: iOS 빌드 실패

**증상**
```
Error: CocoaPods not installed
```

**해결 방법**
```bash
# CocoaPods 설치
sudo gem install cocoapods

# Pod 설치
cd ios
pod install
pod repo update
cd ..

# 재빌드
flutter build ios
```

### 런타임 오류

#### 문제: Firebase 초기화 실패

**증상**
```
[core/no-app] No Firebase App '[DEFAULT]' has been created
```

**해결 방법**
1. `google-services.json` (Android) 또는 `GoogleService-Info.plist` (iOS) 파일 확인
2. 파일이 올바른 위치에 있는지 확인:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
3. Firebase 초기화 코드 확인:
```dart
await Firebase.initializeApp();
```

#### 문제: 위치 권한 오류

**증상**
```
Location permission denied
```

**해결 방법**
1. `AndroidManifest.xml` 확인:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

2. `Info.plist` 확인 (iOS):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>위치 정보가 필요합니다</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>백그라운드 위치 추적이 필요합니다</string>
```

3. 앱 설정에서 권한 확인

#### 문제: Google Maps 표시 안 됨

**증상**
```
지도가 표시되지 않거나 빈 화면
```

**해결 방법**
1. Google Maps API 키 확인
2. API 키 제한 설정 확인 (Android/iOS 패키지명)
3. API 활성화 확인:
   - Maps SDK for Android
   - Maps SDK for iOS
4. `AndroidManifest.xml` 확인:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

### 성능 문제

#### 문제: 앱이 느리게 실행됨

**해결 방법**
```bash
# 프로필 모드로 실행하여 성능 분석
flutter run --profile

# 성능 오버레이 활성화
flutter run --profile --dart-define=FLUTTER_WEB_USE_SKIA=true
```

---

## 백엔드 API 문제

### 서버 시작 오류

#### 문제: 포트 이미 사용 중

**증상**
```
Error: listen EADDRINUSE: address already in use :::3000
```

**해결 방법**
```bash
# 포트 사용 중인 프로세스 확인 (Windows)
netstat -ano | findstr :3000

# 프로세스 종료
taskkill /PID <PID> /F

# 또는 다른 포트 사용
PORT=3001 npm run dev
```

#### 문제: 환경 변수 누락

**증상**
```
Error: Missing required environment variable: DB_HOST
```

**해결 방법**
1. `.env` 파일 확인
2. `.env.example` 참고하여 필요한 변수 추가
3. 환경 변수 검증 코드 확인: `src/config/env.ts`

### 데이터베이스 연결 오류

#### 문제: 데이터베이스 연결 실패

**증상**
```
Error: connect ECONNREFUSED
```

**해결 방법**
1. 데이터베이스 서버 상태 확인
2. 연결 정보 확인:
   - `DB_HOST`
   - `DB_PORT`
   - `DB_NAME`
   - `DB_USER`
   - `DB_PASSWORD`
3. 방화벽/보안 그룹 설정 확인 (AWS RDS)
4. 연결 문자열 테스트:
```bash
psql -h <DB_HOST> -U <DB_USER> -d <DB_NAME>
```

#### 문제: PostGIS 확장 오류

**증상**
```
Error: extension "postgis" does not exist
```

**해결 방법**
```sql
-- PostGIS 확장 설치
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
```

### 인증 오류

#### 문제: JWT 토큰 검증 실패

**증상**
```
Error: Unauthorized: Invalid or expired token
```

**해결 방법**
1. 토큰 만료 시간 확인
2. `JWT_SECRET` 환경 변수 확인
3. Firebase ID Token 검증 로직 확인: `src/middleware/auth.middleware.ts`

#### 문제: Firebase 인증 실패

**증상**
```
Error: Firebase ID Token verification failed
```

**해결 방법**
1. Firebase 프로젝트 설정 확인
2. 환경 변수 확인:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_PRIVATE_KEY`
   - `FIREBASE_CLIENT_EMAIL`
3. Firebase Admin SDK 초기화 확인: `src/config/firebase.config.ts`

---

## 데이터베이스 문제

### 연결 문제

#### 문제: 타임아웃 오류

**증상**
```
Error: Connection timeout
```

**해결 방법**
1. RDS 보안 그룹 설정 확인
2. VPC 설정 확인
3. 연결 풀 설정 조정:
```typescript
const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20, // 최대 연결 수
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### 쿼리 성능 문제

#### 문제: 느린 쿼리

**해결 방법**
1. 인덱스 확인:
```sql
-- 인덱스 확인
SELECT * FROM pg_indexes WHERE tablename = 'tb_location';

-- 인덱스 생성
CREATE INDEX idx_location_user_recorded 
ON tb_location(user_id, recorded_at DESC);
```

2. EXPLAIN ANALYZE 사용:
```sql
EXPLAIN ANALYZE
SELECT * FROM tb_location 
WHERE user_id = 'user123' 
ORDER BY recorded_at DESC 
LIMIT 100;
```

3. 쿼리 최적화:
   - 불필요한 JOIN 제거
   - LIMIT 사용
   - 적절한 WHERE 조건 사용

---

## Firebase 문제

### Realtime Database 문제

#### 문제: 데이터 동기화 실패

**증상**
```
데이터가 실시간으로 업데이트되지 않음
```

**해결 방법**
1. Firebase 규칙 확인:
```json
{
  "rules": {
    "realtime_locations": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
}
```

2. 네트워크 연결 확인
3. Firebase 초기화 확인

#### 문제: 권한 오류

**증상**
```
Error: PERMISSION_DENIED
```

**해결 방법**
1. Firebase Authentication 상태 확인
2. 사용자 인증 토큰 확인
3. Firebase Security Rules 확인

### FCM 푸시 알림 문제

#### 문제: 알림이 전송되지 않음

**해결 방법**
1. FCM 토큰 확인:
```typescript
// 토큰 등록 확인
GET /api/v1/users/me/fcm-token
```

2. Firebase 프로젝트 설정 확인
3. 서버 로그 확인:
```bash
# 로그 확인
docker logs <container-id>
```

---

## 배포 문제

### Docker 빌드 오류

#### 문제: 빌드 실패

**증상**
```
Error: failed to solve: process "/bin/sh -c npm install" did not complete successfully
```

**해결 방법**
1. Dockerfile 확인
2. `.dockerignore` 확인
3. 빌드 캐시 삭제:
```bash
docker build --no-cache -t safetrip-api .
```

### AWS ECS 배포 오류

#### 문제: 서비스 업데이트 실패

**증상**
```
Error: Service update failed
```

**해결 방법**
1. ECS 태스크 로그 확인:
```bash
aws logs tail /ecs/safetrip-api --follow
```

2. 태스크 정의 확인:
```bash
aws ecs describe-task-definition --task-definition safetrip-api
```

3. 환경 변수 확인 (AWS Secrets Manager)

#### 문제: 이미지 푸시 실패

**증상**
```
Error: no basic auth credentials
```

**해결 방법**
1. AWS ECR 로그인 확인:
```bash
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com
```

2. IAM 권한 확인

---

## 성능 문제

### API 응답 시간 지연

#### 문제: 느린 API 응답

**해결 방법**
1. 데이터베이스 쿼리 최적화
2. 캐싱 적용:
```typescript
// Redis 캐싱 예제
import Redis from 'ioredis';
const redis = new Redis(process.env.REDIS_URL);

async function getCachedData(key: string) {
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);
  
  const data = await fetchData();
  await redis.setex(key, 3600, JSON.stringify(data));
  return data;
}
```

3. 연결 풀 크기 조정
4. 로드 밸런싱 설정

### 메모리 누수

#### 문제: 메모리 사용량 증가

**해결 방법**
1. 메모리 프로파일링:
```bash
node --inspect dist/index.js
```

2. 연결 풀 관리 확인
3. 이벤트 리스너 정리 확인

---

## 로그 확인

### 백엔드 로그

```bash
# 로컬 개발
npm run dev

# Docker 컨테이너 로그
docker logs <container-id> -f

# AWS ECS 로그
aws logs tail /ecs/safetrip-api --follow
```

### Flutter 앱 로그

```bash
# 디바이스 로그 확인
flutter logs

# 특정 태그 필터링
adb logcat -s flutter
```

---

## 추가 도움말

- [개발 환경 설정](../01-getting-started/development-setup.md)
- [환경 변수 설정](../01-getting-started/env-config.md)
- [배포 가이드](../01-getting-started/deployment.md)
- [API 가이드](../05-api/api-guide.md)

---

**작성일**: 2025-01-15  
**버전**: 1.0

