# SafeTrip 배포 가이드

## 📋 목차

1. [개요](#개요)
2. [배포 전 준비사항](#배포-전-준비사항)
3. [백엔드 API 배포 (AWS ECS/Fargate)](#백엔드-api-배포-aws-ecsfargate)
4. [Firebase Functions 배포](#firebase-safetrip-firebase-function-배포)
5. [모바일 앱 배포](#모바일-앱-배포)
6. [환경별 배포](#환경별-배포)
7. [롤백 방법](#롤백-방법)
8. [배포 확인](#배포-확인)
9. [문제 해결](#문제-해결)

---

## 개요

SafeTrip 프로젝트는 다음과 같은 구성 요소로 배포됩니다:

| 구성 요소 | 배포 대상 | 기술 스택 |
|----------|----------|----------|
| **백엔드 API** | AWS ECS/Fargate | Node.js + TypeScript |
| **데이터베이스** | AWS RDS PostgreSQL | PostgreSQL + PostGIS |
| **Firebase Functions** | Firebase Cloud Functions | TypeScript |
| **모바일 앱** | Google Play / App Store | Flutter |

### 배포 아키텍처

```
┌─────────────────────────────────────────┐
│         모바일 앱 (Google Play/App Store) │
│              iOS / Android               │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│         백엔드 API (AWS ECS/Fargate)     │
│         https://api.safetrip.io         │
└─────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
┌──────────┐  ┌──────────┐  ┌──────────────┐
│AWS RDS   │  │Firebase  │  │Firebase      │
│PostgreSQL│  │Functions │  │Realtime DB   │
│          │  │          │  │              │
└──────────┘  └──────────┘  └──────────────┘
```

---

## 배포 전 준비사항

### 1. 필수 도구 설치

```bash
# AWS CLI
aws --version

# Docker
docker --version

# PowerShell (Windows)
pwsh --version
```

### 2. AWS 계정 설정

```bash
# AWS CLI 인증
aws configure

# AWS 계정 ID 확인
aws sts get-caller-identity

# 리전 설정 (ap-northeast-2 - 서울)
aws configure set region ap-northeast-2
```

### 3. AWS 리소스 준비

#### ECS 클러스터 생성

```bash
aws ecs create-cluster \
  --cluster-name safetrip-cluster \
  --region ap-northeast-2
```

#### ECR 리포지토리 생성

```bash
aws ecr create-repository \
  --repository-name safetrip-api \
  --region ap-northeast-2 \
  --image-scanning-configuration scanOnPush=true
```

#### RDS PostgreSQL 인스턴스

자세한 내용은 [데이터베이스 설정](../03-database/database-setup.md)를 참고하세요.

### 4. Firebase 프로젝트 설정

```bash
# Firebase 로그인
firebase login

# 프로젝트 선택
firebase use safetrip-urock

# 프로젝트 확인
firebase projects:list
```

### 5. 환경 변수 및 Secret 설정

**AWS Secrets Manager에 저장:**

```bash
# 데이터베이스 자격 증명
aws secretsmanager create-secret \
  --name safetrip-api-db-credentials \
  --secret-string '{
    "DB_HOST": "your-rds-endpoint",
    "DB_PORT": "5432",
    "DB_NAME": "safetrip",
    "DB_USER": "safetrip_user",
    "DB_PASSWORD": "your-password",
    "DB_SSL": "true"
  }' \
  --region ap-northeast-2
```

**자세한 내용**: [환경 변수 설정](../01-getting-started/env-config.md)

---

## 백엔드 API 배포 (AWS ECS/Fargate)

### 자동 배포 (권장)

프로젝트에는 PowerShell 배포 스크립트가 포함되어 있습니다:

```powershell
# safetrip-server-api 디렉토리에서 실행
cd safetrip-server-api
.\deploy.ps1
```

**VS Code 단축키**: `Ctrl+Shift+3`

배포 스크립트는 다음 작업을 자동으로 수행합니다:

1. ✅ AWS CLI 및 Docker 확인
2. ✅ AWS 자격 증명 확인
3. ✅ ECR 리포지토리 생성/확인
4. ✅ Docker 이미지 빌드
5. ✅ ECR 로그인
6. ✅ 이미지 푸시
7. ✅ ECS 클러스터 확인
8. ✅ VPC 및 서브넷 정보 조회
9. ✅ 보안 그룹 생성/확인
10. ✅ ECS Task Execution Role 생성/확인
11. ✅ CloudWatch Logs 그룹 생성
12. ✅ Task Definition 생성/등록
13. ✅ ECS 서비스 생성/업데이트

### 수동 배포

#### 1. Dockerfile 확인

**`safetrip-server-api/Dockerfile`:**

```dockerfile
FROM node:18-alpine

WORKDIR /app

# 의존성 파일 복사
COPY package*.json ./
COPY tsconfig.json ./

# 모든 의존성 설치 (빌드에 devDependencies 필요)
RUN npm ci

# 소스 코드 복사
COPY src ./src

# TypeScript 빌드
RUN npm run build

# 프로덕션 의존성만 재설치
RUN npm ci --only=production && npm cache clean --force

# 환경 변수
ENV NODE_ENV=production

# 포트 노출
EXPOSE 3001

# 서버 실행
CMD ["node", "dist/index.js"]
```

#### 2. Docker 이미지 빌드

```bash
cd safetrip-server-api

# 이미지 빌드
docker build -t safetrip-api:latest .
```

#### 3. ECR에 이미지 푸시

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  289753176475.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 태깅
docker tag safetrip-api:latest \
  289753176475.dkr.ecr.ap-northeast-2.amazonaws.com/safetrip-api:latest

# 이미지 푸시
docker push \
  289753176475.dkr.ecr.ap-northeast-2.amazonaws.com/safetrip-api:latest
```

#### 4. Task Definition 생성

```bash
# Task Definition JSON 파일 생성 후
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json \
  --region ap-northeast-2
```

#### 5. ECS 서비스 생성/업데이트

```bash
# 서비스 생성 (최초 1회)
aws ecs create-service \
  --cluster safetrip-cluster \
  --service-name safetrip-api-service \
  --task-definition safetrip-api-task \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx,subnet-yyy],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --region ap-northeast-2

# 서비스 업데이트 (이미 존재하는 경우)
aws ecs update-service \
  --cluster safetrip-cluster \
  --service safetrip-api-service \
  --task-definition safetrip-api-task \
  --force-new-deployment \
  --region ap-northeast-2
```

### 배포 확인

```bash
# 서비스 상태 확인
aws ecs describe-services \
  --cluster safetrip-cluster \
  --services safetrip-api-service \
  --region ap-northeast-2

# 태스크 상태 확인
aws ecs list-tasks \
  --cluster safetrip-cluster \
  --service-name safetrip-api-service \
  --region ap-northeast-2

# 로그 확인
aws logs tail /ecs/safetrip-api-task --follow --region ap-northeast-2

# Health Check
curl http://YOUR_PUBLIC_IP:3001/health
```

---

## Firebase Functions 배포

### 1. Firebase Functions 설정

**`safetrip-firebase-function/package.json`:**

```json
{
  "name": "safetrip-functions",
  "scripts": {
    "build": "tsc",
    "deploy": "firebase deploy --only functions"
  }
}
```

### 2. 환경 변수 설정

```bash
# Firebase Functions 환경 변수 설정
firebase functions:config:set \
  db.host="YOUR_DB_HOST" \
  db.port="5432" \
  db.name="safetrip" \
  db.user="safetrip_user" \
  db.password="YOUR_DB_PASSWORD"

# 또는 Secret Manager 사용 (권장)
firebase functions:secrets:set DB_PASSWORD
firebase functions:secrets:set JWT_SECRET
```

### 3. 배포

```bash
cd safetrip-firebase-function

# 빌드
npm run build

# 특정 함수만 배포
firebase deploy --only functions:syncLocation
firebase deploy --only functions:sendSOSNotification

# 모든 함수 배포
firebase deploy --only functions
```

### 4. 배포 확인

```bash
# 함수 목록 확인
firebase functions:list

# 함수 로그 확인
firebase functions:log

# 특정 함수 로그
firebase functions:log --only syncLocation
```

---

## 모바일 앱 배포

### Android (Google Play)

#### 1. 앱 서명 키 생성

```bash
cd safetrip-mobile/android

# 키스토어 생성
keytool -genkey -v \
  -keystore safetrip-release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias safetrip
```

#### 2. `android/app/build.gradle` 설정

```gradle
android {
    signingConfigs {
        release {
            storeFile file('safetrip-release-key.jks')
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias 'safetrip'
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### 3. APK/AAB 빌드

```bash
cd safetrip-mobile

# APK 빌드
flutter build apk --release

# AAB 빌드 (권장)
flutter build appbundle --release
```

#### 4. Google Play Console 업로드

1. [Google Play Console](https://play.google.com/console) 접속
2. 앱 선택 또는 새 앱 생성
3. **프로덕션** → **새 버전 만들기**
4. AAB 파일 업로드
5. 출시 정보 입력 및 검토

### iOS (App Store)

#### 1. Xcode 프로젝트 설정

```bash
cd safetrip-mobile/ios

# Xcode 열기
open Runner.xcworkspace
```

**Xcode에서:**
1. **Signing & Capabilities** → **Team** 선택
2. **Bundle Identifier** 설정 (`com.safetrip.app`)
3. **Automatically manage signing** 체크

#### 2. 빌드 및 아카이브

```bash
cd safetrip-mobile

# iOS 빌드
flutter build ios --release

# Xcode에서 Archive 생성
# Product → Archive → Distribute App
```

#### 3. App Store Connect 업로드

1. [App Store Connect](https://appstoreconnect.apple.com) 접속
2. 앱 선택 또는 새 앱 생성
3. **TestFlight** 또는 **App Store** 탭
4. **+ 버전** 클릭
5. 빌드 업로드 및 정보 입력

---

## 환경별 배포

### Development (개발 환경)

**로컬 개발:**
```bash
cd safetrip-server-api
npm run dev
```

**설정:**
- API URL: `http://localhost:3001`
- 데이터베이스: 로컬 PostgreSQL 또는 개발용 RDS 인스턴스
- 로그 레벨: `debug`

### Staging (스테이징 환경)

**배포:**
```powershell
# deploy.ps1에서 환경 변수 변경 후 실행
cd safetrip-server-api
.\deploy.ps1
```

**설정:**
- API URL: `https://api-staging.safetrip.io`
- 데이터베이스: 스테이징 RDS 인스턴스
- 로그 레벨: `info`

### Production (프로덕션 환경)

**배포:**
```powershell
# deploy.ps1에서 프로덕션 설정 확인 후 실행
cd safetrip-server-api
.\deploy.ps1
```

**설정:**
- API URL: `https://api.safetrip.io`
- 데이터베이스: 프로덕션 RDS 인스턴스
- 로그 레벨: `warn`

**주의사항:**
- 프로덕션 배포는 반드시 코드 리뷰 후 진행
- 배포 전 테스트 환경에서 검증 완료
- 배포 후 모니터링 필수

---

## 롤백 방법

### ECS 서비스 롤백

```bash
# 이전 Task Definition 리비전 확인
aws ecs describe-task-definition \
  --task-definition safetrip-api-task \
  --region ap-northeast-2

# 이전 리비전으로 서비스 업데이트
aws ecs update-service \
  --cluster safetrip-cluster \
  --service safetrip-api-service \
  --task-definition safetrip-api-task:REVISION_NUMBER \
  --force-new-deployment \
  --region ap-northeast-2
```

### Firebase Functions 롤백

```bash
# 이전 버전 확인
firebase functions:list

# 특정 함수 롤백 (수동 배포)
firebase deploy --only functions:functionName
```

---

## 배포 확인

### 1. Health Check

```bash
# API Health Check
curl http://YOUR_PUBLIC_IP:3001/health

# 예상 응답
{
  "status": "ok",
  "timestamp": "2025-01-15T10:00:00Z",
  "database": "connected",
  "firebase": "connected"
}
```

### 2. API 엔드포인트 확인

```bash
# 인증 API 테스트
curl -X POST http://YOUR_PUBLIC_IP:3001/api/v1/auth/firebase-verify \
  -H "Content-Type: application/json" \
  -d '{"id_token": "firebase_id_token_here"}'
```

### 3. 로그 확인

```bash
# ECS 로그
aws logs tail /ecs/safetrip-api-task --follow --region ap-northeast-2

# Firebase Functions 로그
firebase functions:log --limit 100
```

### 4. 모니터링 확인

- [AWS ECS Console](https://console.aws.amazon.com/ecs)
- [AWS CloudWatch](https://console.aws.amazon.com/cloudwatch)
- [Firebase Console](https://console.firebase.google.com)
- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)

---

## 문제 해결

### 일반적인 문제

#### 1. 배포 실패

**문제**: ECS 배포 실패

**해결:**
```bash
# 로그 확인
aws logs tail /ecs/safetrip-api-task --follow --region ap-northeast-2

# Docker 이미지 빌드 테스트
docker build -t test-image .
docker run -p 3001:3001 test-image

# ECR 로그인 확인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  289753176475.dkr.ecr.ap-northeast-2.amazonaws.com
```

#### 2. 환경 변수 누락

**문제**: 환경 변수가 설정되지 않음

**해결:**
```bash
# Task Definition 확인
aws ecs describe-task-definition \
  --task-definition safetrip-api-task \
  --region ap-northeast-2 \
  --query 'taskDefinition.containerDefinitions[0].environment'

# Secrets Manager 확인
aws secretsmanager list-secrets --region ap-northeast-2
```

#### 3. 데이터베이스 연결 실패

**문제**: RDS 연결 실패

**해결:**
```bash
# RDS 인스턴스 확인
aws rds describe-db-instances --region ap-northeast-2

# 보안 그룹 확인
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=safetrip-api-sg" \
  --region ap-northeast-2

# VPC 및 서브넷 확인
aws ec2 describe-vpcs --region ap-northeast-2
aws ec2 describe-subnets --region ap-northeast-2
```

#### 4. 함수 배포 실패

**문제**: Firebase Functions 배포 실패

**해결:**
```bash
# 빌드 확인
cd safetrip-firebase-function
npm run build

# 로그 확인
firebase functions:log

# 환경 변수 확인
firebase functions:config:get
```

### 추가 도움말

- [개발 환경 설정](../01-getting-started/development-setup.md) - 개발 환경 구축
- [환경 변수 설정](../01-getting-started/env-config.md) - 환경 변수 설정
- [데이터베이스 설정](../03-database/database-setup.md) - 데이터베이스 설정
- [AWS ECS 문서](https://docs.aws.amazon.com/ecs)
- [Firebase Functions 문서](https://firebase.google.com/docs/functions)

---

**작성일**: 2025-01-15  
**버전**: 2.0 (AWS ECS/Fargate 기준)
