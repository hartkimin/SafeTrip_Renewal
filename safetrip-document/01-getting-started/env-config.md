# SafeTrip 환경 변수 설정 가이드

## 📋 목차

1. [개요](#개요)
2. [백엔드 환경 변수](#백엔드-환경-변수)
3. [모바일 앱 환경 변수](#모바일-앱-환경-변수)
4. [AWS Secrets Manager](#aws-secrets-manager)
5. [환경별 설정](#환경별-설정)
6. [보안 권장사항](#보안-권장사항)

---

## 개요

SafeTrip 프로젝트는 여러 환경 변수를 사용합니다. 각 환경 변수는 프로젝트별로 분리되어 관리됩니다.

### 환경 변수 파일 위치

```
SafeTrip/
├── safetrip-server-api/.env              # 백엔드 환경 변수
├── safetrip-mobile/.env            # 모바일 앱 환경 변수
└── .env.example                 # 각 프로젝트별 예시 파일
```

---

## 백엔드 환경 변수

### 파일 위치: `safetrip-server-api/.env`

### 필수 환경 변수

```env
# ============================================
# 기본 설정
# ============================================
NODE_ENV=development
PORT=3001
API_VERSION=v1

# ============================================
# 데이터베이스 (AWS RDS PostgreSQL)
# ============================================
DB_HOST=your-rds-endpoint.region.rds.amazonaws.com
DB_PORT=5432
DB_NAME=safetrip
DB_USER=safetrip_user
DB_PASSWORD=your_password
DB_SSL=true

# 또는 연결 문자열 사용
DATABASE_URL=postgresql://safetrip_user:password@your-rds-endpoint:5432/safetrip?sslmode=require

# ============================================
# Firebase
# ============================================
FIREBASE_PROJECT_ID=safetrip-urock
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@xxxxx.iam.gserviceaccount.com
FIREBASE_DATABASE_URL=https://safetrip-urock-default-rtdb.firebaseio.com

# ============================================
# Google Maps Platform
# ============================================
GOOGLE_MAPS_API_KEY=your_google_maps_api_key

# ============================================
# 로깅
# ============================================
LOG_LEVEL=debug
LOG_FORMAT=json

# ============================================
# CORS
# ============================================
CORS_ORIGIN=http://localhost:5173,http://localhost:3001
```

### 환경 변수 설명

| 변수명 | 타입 | 필수 | 설명 | 예시 |
|--------|------|------|------|------|
| `NODE_ENV` | string | ✅ | 실행 환경 | `development`, `staging`, `production` |
| `PORT` | number | ✅ | 서버 포트 | `3001` |
| `DB_HOST` | string | ✅ | AWS RDS 엔드포인트 | `your-rds-endpoint.region.rds.amazonaws.com` |
| `DB_PORT` | number | ✅ | 데이터베이스 포트 | `5432` |
| `DB_NAME` | string | ✅ | 데이터베이스 이름 | `safetrip` |
| `DB_USER` | string | ✅ | 데이터베이스 사용자 | `safetrip_user` |
| `DB_PASSWORD` | string | ✅ | 데이터베이스 비밀번호 | - |
| `DB_SSL` | boolean | ✅ | SSL 사용 여부 | `true` (AWS RDS 필수) |
| `FIREBASE_PROJECT_ID` | string | ✅ | Firebase 프로젝트 ID | `safetrip-urock` |
| `FIREBASE_DATABASE_URL` | string | ✅ | Firebase Realtime Database URL | `https://...firebaseio.com` |
| `GOOGLE_MAPS_API_KEY` | string | ✅ | Google Maps API 키 | - |
| `LOG_LEVEL` | string | ❌ | 로그 레벨 | `debug`, `info`, `warn`, `error` |

---

## 모바일 앱 환경 변수

### 파일 위치: `safetrip-mobile/.env`

**주의**: Flutter는 `flutter_dotenv` 패키지를 사용합니다.

```env
# ============================================
# API 설정
# ============================================
API_BASE_URL=https://api-staging.safetrip.io/v1
API_TIMEOUT=30000

# ============================================
# Google Maps Platform
# ============================================
GOOGLE_MAPS_API_KEY_IOS=your_ios_maps_key
GOOGLE_MAPS_API_KEY_ANDROID=your_android_maps_key

# ============================================
# 기타 설정
# ============================================
ENABLE_LOGGING=true
LOG_LEVEL=debug
```

**참고**: Firebase 설정은 `google-services.json` (Android) 및 `GoogleService-Info.plist` (iOS) 파일에서 자동 로드됩니다.

### Flutter 코드에서 사용

**pubspec.yaml:**
```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

**main.dart:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

// 사용 예시
final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.safetrip.io/v1';
```

### Android 설정

**android/app/src/main/AndroidManifest.xml:**
```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="${GOOGLE_MAPS_API_KEY_ANDROID}"/>
    </application>
</manifest>
```

### iOS 설정

**ios/Runner/AppDelegate.swift:**
```swift
import GoogleMaps

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY_IOS") as? String {
        GMSServices.provideAPIKey(apiKey)
    }
    return true
}
```

---

## AWS Secrets Manager

### Secret Manager 사용 (프로덕션)

**Secret 생성:**
```bash
# AWS CLI로 Secret 생성
aws secretsmanager create-secret \
  --name safetrip-api-db-credentials \
  --secret-string '{
    "DB_HOST": "your-rds-endpoint.region.rds.amazonaws.com",
    "DB_PORT": "5432",
    "DB_NAME": "safetrip",
    "DB_USER": "safetrip_user",
    "DB_PASSWORD": "your_password",
    "DB_SSL": "true"
  }' \
  --region ap-northeast-2

# Secret 버전 추가
aws secretsmanager put-secret-value \
  --secret-id safetrip-api-db-credentials \
  --secret-string '{
    "DB_HOST": "new-rds-endpoint.region.rds.amazonaws.com",
    "DB_PORT": "5432",
    "DB_NAME": "safetrip",
    "DB_USER": "safetrip_user",
    "DB_PASSWORD": "new_password",
    "DB_SSL": "true"
  }' \
  --region ap-northeast-2
```

**Secret 목록:**
```bash
aws secretsmanager list-secrets --region ap-northeast-2
```

**Secret 값 읽기:**
```bash
aws secretsmanager get-secret-value \
  --secret-id safetrip-api-db-credentials \
  --region ap-northeast-2 \
  --query SecretString --output text
```

### ECS Task Definition에서 Secret 사용

**task-definition.json:**
```json
{
  "containerDefinitions": [
    {
      "secrets": [
        {
          "name": "DB_HOST",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:safetrip-api-db-credentials:DB_HOST::"
        },
        {
          "name": "DB_PORT",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:safetrip-api-db-credentials:DB_PORT::"
        },
        {
          "name": "DB_NAME",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:safetrip-api-db-credentials:DB_NAME::"
        },
        {
          "name": "DB_USER",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:safetrip-api-db-credentials:DB_USER::"
        },
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:safetrip-api-db-credentials:DB_PASSWORD::"
        },
        {
          "name": "DB_SSL",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:safetrip-api-db-credentials:DB_SSL::"
        }
      ]
    }
  ]
}
```

### 애플리케이션에서 Secret Manager 사용

**Node.js:**
```typescript
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const client = new SecretsManagerClient({ region: 'ap-northeast-2' });

async function getSecret(secretName: string): Promise<any> {
  const command = new GetSecretValueCommand({ SecretId: secretName });
  const response = await client.send(command);
  return JSON.parse(response.SecretString || '{}');
}

// 사용
const dbCredentials = await getSecret('safetrip-api-db-credentials');
const dbHost = dbCredentials.DB_HOST;
```

**IAM 권한:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:safetrip-api-db-credentials-*"
    }
  ]
}
```

---

## 환경별 설정

### Development (개발 환경)

```env
NODE_ENV=development
PORT=3001
API_BASE_URL=http://localhost:3001/v1
DB_HOST=localhost
DB_PORT=5432
DB_NAME=safetrip
DB_USER=safetrip_user
DB_PASSWORD=local_password
DB_SSL=false
LOG_LEVEL=debug
```

### Staging (스테이징 환경)

```env
NODE_ENV=staging
PORT=3001
API_BASE_URL=https://api-staging.safetrip.io/v1
DB_HOST=staging-rds-endpoint.region.rds.amazonaws.com
DB_PORT=5432
DB_NAME=safetrip
DB_USER=safetrip_user
DB_PASSWORD=staging_password
DB_SSL=true
LOG_LEVEL=info
```

### Production (프로덕션 환경)

**주의**: 프로덕션 환경에서는 AWS Secrets Manager 사용 필수

```env
NODE_ENV=production
PORT=3001
API_BASE_URL=https://api.safetrip.io/v1
# 데이터베이스 자격 증명은 AWS Secrets Manager에서 로드
LOG_LEVEL=warn
```

---

## 보안 권장사항

### 1. `.env` 파일 보안

**`.gitignore`에 추가:**
```
.env
.env.local
.env.*.local
*.key
*.pem
google-services.json
GoogleService-Info.plist
```

### 2. 환경 변수 검증

**백엔드에서 환경 변수 검증:**
```typescript
import * as dotenv from 'dotenv';
dotenv.config();

const requiredEnvVars = [
  'DB_HOST',
  'DB_PORT',
  'DB_NAME',
  'DB_USER',
  'DB_PASSWORD',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_DATABASE_URL',
  'GOOGLE_MAPS_API_KEY',
];

requiredEnvVars.forEach((varName) => {
  if (!process.env[varName]) {
    throw new Error(`Missing required environment variable: ${varName}`);
  }
});
```

### 3. AWS Secrets Manager 사용

- 프로덕션 환경에서는 반드시 AWS Secrets Manager 사용
- 민감한 정보 (비밀번호, API 키)는 Secrets Manager에 저장
- 로컬 개발 환경에서만 `.env` 파일 사용
- ECS Task Definition에서 Secret 참조 사용

### 4. 환경 변수 암호화

- 민감한 환경 변수는 암호화하여 저장
- CI/CD 파이프라인에서 Secrets Manager 사용
- 로컬 환경 변수는 암호화된 파일로 관리 (선택사항)

### 5. 접근 권한 관리

- 최소 권한 원칙 적용
- IAM 역할별로 필요한 Secret만 접근 권한 부여
- 정기적으로 Secret 접근 로그 확인 (CloudTrail)

---

## 환경 변수 체크리스트

### 개발 환경 설정 시

- [ ] `.env.example` 파일 생성
- [ ] `.env` 파일 생성 (`.gitignore` 확인)
- [ ] 필수 환경 변수 모두 설정
- [ ] 환경 변수 값 검증 로직 추가
- [ ] 로컬 개발 환경 테스트

### 배포 전 확인

- [ ] 프로덕션 환경 변수 AWS Secrets Manager에 저장
- [ ] 환경별 설정 분리 (development, staging, production)
- [ ] 민감한 정보 `.env` 파일에서 제거
- [ ] ECS Task Definition에 Secret 참조 추가
- [ ] IAM 역할 권한 확인
- [ ] 환경 변수 문서화 (이 문서)
- [ ] 보안 검토 완료

---

## 참고 문서

- [개발 환경 설정](../01-getting-started/development-setup.md) - 개발 환경 구축 가이드
- [배포 가이드](../01-getting-started/deployment.md) - 배포 가이드
- [데이터베이스 연결](../03-database/database-connection.md) - 데이터베이스 연결 가이드
- [AWS Secrets Manager 문서](https://docs.aws.amazon.com/secretsmanager/)

---

**작성일**: 2025-01-15  
**버전**: 2.0 (AWS Secrets Manager 기준)
