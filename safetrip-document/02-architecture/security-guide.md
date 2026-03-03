# SafeTrip 보안 가이드

## 목차

1. [개요](#개요)
2. [인증 및 인가](#인증-및-인가)
3. [데이터 암호화](#데이터-암호화)
4. [API 보안](#api-보안)
5. [데이터베이스 보안](#데이터베이스-보안)
6. [개인정보 보호](#개인정보-보호)
7. [보안 모범 사례](#보안-모범-사례)
8. [보안 감사](#보안-감사)

---

## 개요

SafeTrip은 사용자의 위치 정보와 개인정보를 다루는 안전 플랫폼입니다. 보안은 최우선 과제이며, 다음 영역을 다룹니다:

- **인증 및 인가**: 사용자 신원 확인 및 권한 관리
- **데이터 암호화**: 전송 중 및 저장 중 데이터 보호
- **API 보안**: API 엔드포인트 보호
- **개인정보 보호**: GDPR 및 개인정보보호법 준수

---

## 인증 및 인가

### Firebase Authentication

SafeTrip은 Firebase Authentication을 사용하여 사용자 인증을 처리합니다.

#### 전화번호 인증

```dart
// Flutter 앱
final confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
  phoneNumber,
);

final userCredential = await confirmationResult.confirmOTP(otp);
final idToken = await userCredential.user?.getIdToken();
```

#### 백엔드 토큰 검증

```typescript
// src/middleware/auth.middleware.ts
import { verifyFirebaseIdToken } from '../config/firebase.config';

export const authenticate = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  const idToken = req.headers.authorization?.substring(7);
  
  if (!idToken) {
    return sendError(res, 'Unauthorized: No token provided', 401);
  }

  try {
    const decodedToken = await verifyFirebaseIdToken(idToken);
    req.userId = decodedToken.uid;
    next();
  } catch (error) {
    sendError(res, 'Unauthorized: Invalid or expired token', 401);
  }
};
```

### JWT 토큰 관리

#### 토큰 만료 시간

- **Access Token**: 1시간
- **Refresh Token**: 7일 (필요 시)

#### 토큰 갱신

```typescript
// 토큰 만료 전 갱신
if (tokenExpiresIn < 300) { // 5분 전
  const newToken = await refreshToken(refreshToken);
}
```

### 권한 관리

#### 역할 기반 접근 제어 (RBAC)

```typescript
// 보호자 권한 확인
export const requireGuardianRole = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  const user = await userService.getUserById(req.userId!);
  
  if (user.role !== 'guardian') {
    return sendError(res, 'Forbidden: Guardian role required', 403);
  }
  
  next();
};
```

---

## 데이터 암호화

### 전송 중 암호화 (TLS/SSL)

모든 API 통신은 HTTPS를 사용합니다.

```typescript
// Express.js HTTPS 설정
import https from 'https';
import fs from 'fs';

const options = {
  key: fs.readFileSync('path/to/private-key.pem'),
  cert: fs.readFileSync('path/to/certificate.pem'),
};

const server = https.createServer(options, app);
```

### 저장 중 암호화

#### 민감 정보 암호화

```typescript
import crypto from 'crypto';

const algorithm = 'aes-256-gcm';
const key = Buffer.from(process.env.ENCRYPTION_KEY!, 'hex');

function encrypt(text: string): string {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(algorithm, key, iv);
  
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  const authTag = cipher.getAuthTag();
  
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
}

function decrypt(encryptedData: string): string {
  const [ivHex, authTagHex, encrypted] = encryptedData.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');
  
  const decipher = crypto.createDecipheriv(algorithm, key, iv);
  decipher.setAuthTag(authTag);
  
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}
```

#### 데이터베이스 암호화

AWS RDS는 기본적으로 저장 중 암호화를 지원합니다:

- **암호화 활성화**: RDS 인스턴스 생성 시 `StorageEncrypted=true`
- **암호화 키**: AWS KMS 사용

---

## API 보안

### Rate Limiting

API 요청 빈도를 제한하여 DDoS 공격을 방지합니다.

```typescript
import rateLimit from 'express-rate-limit';

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15분
  max: 100, // 최대 100회 요청
  message: 'Too many requests from this IP, please try again later.',
});

app.use('/api/', apiLimiter);
```

### CORS 설정

```typescript
import cors from 'cors';

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['https://safetrip.io'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
```

### Helmet.js

보안 헤더를 자동으로 설정합니다.

```typescript
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));
```

### 입력 검증

```typescript
import { body, validationResult } from 'express-validator';

export const validateLocation = [
  body('latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude must be between -90 and 90'),
  body('longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude must be between -180 and 180'),
  (req: Request, res: Response, next: NextFunction) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  },
];
```

### SQL Injection 방지

파라미터화된 쿼리 사용:

```typescript
// ❌ 취약한 코드
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ 안전한 코드
const query = `SELECT * FROM users WHERE id = $1`;
const result = await db.query(query, [userId]);
```

---

## 데이터베이스 보안

### 연결 보안

#### SSL 연결

```typescript
const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: {
    rejectUnauthorized: true,
    ca: fs.readFileSync('path/to/ca-certificate.crt'),
  },
});
```

### 자격 증명 관리

#### AWS Secrets Manager 사용

```typescript
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const client = new SecretsManagerClient({ region: 'ap-northeast-2' });

async function getDatabaseCredentials() {
  const command = new GetSecretValueCommand({
    SecretId: 'safetrip/database/credentials',
  });
  
  const response = await client.send(command);
  return JSON.parse(response.SecretString!);
}
```

#### 환경 변수 보호

```bash
# .env 파일은 Git에 커밋하지 않음
# .gitignore에 추가
.env
.env.local
.env.*.local
```

### 접근 제어

#### 데이터베이스 사용자 권한

```sql
-- 읽기 전용 사용자 생성
CREATE USER readonly_user WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE safetrip TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;

-- 애플리케이션 사용자 (읽기/쓰기)
CREATE USER app_user WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE safetrip TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
```

---

## 개인정보 보호

### 위치 정보 보호

#### 정밀도 축소

개인정보 모드에서는 위치 정밀도를 축소합니다:

```typescript
function reduceLocationPrecision(
  latitude: number,
  longitude: number,
  precision: number = 2
): { lat: number; lng: number } {
  const factor = Math.pow(10, precision);
  return {
    lat: Math.round(latitude * factor) / factor,
    lng: Math.round(longitude * factor) / factor,
  };
}
```

### 데이터 보존 정책

#### 자동 삭제

```typescript
// 30일 이상 된 위치 데이터 삭제
async function cleanupOldLocations() {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  await db.query(
    `DELETE FROM tb_location 
     WHERE recorded_at < $1 
     AND user_id NOT IN (
       SELECT user_id FROM tb_user WHERE subscription_status = 'active'
     )`,
    [thirtyDaysAgo]
  );
}
```

### GDPR 준수

#### 데이터 삭제 요청

```typescript
// 사용자 데이터 완전 삭제
async function deleteUserData(userId: string) {
  // 트랜잭션으로 모든 관련 데이터 삭제
  await db.query('BEGIN');
  
  try {
    await db.query('DELETE FROM tb_location WHERE user_id = $1', [userId]);
    await db.query('DELETE FROM tb_geofence WHERE user_id = $1', [userId]);
    await db.query('DELETE FROM tb_user WHERE user_id = $1', [userId]);
    
    await db.query('COMMIT');
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }
}
```

---

## 보안 모범 사례

### 코드 보안

1. **의존성 업데이트**: 정기적으로 보안 패치 확인
```bash
npm audit
npm audit fix
```

2. **보안 스캔**: 정기적인 취약점 스캔
```bash
# Snyk 사용
npx snyk test
npx snyk monitor
```

3. **시크릿 스캔**: Git 히스토리에서 시크릿 검색
```bash
# git-secrets 사용
git secrets --scan
```

### 운영 보안

1. **로그 모니터링**: 의심스러운 활동 감지
2. **정기 백업**: 데이터 백업 및 복구 계획
3. **인시던트 대응**: 보안 사고 대응 절차 수립

### 개발 보안

1. **코드 리뷰**: 보안 취약점 검토
2. **최소 권한 원칙**: 필요한 최소한의 권한만 부여
3. **보안 교육**: 개발팀 보안 인식 교육

---

## 보안 감사

### 정기 감사 항목

1. **인증 시스템**: 토큰 관리 및 만료 정책
2. **암호화**: 전송 중 및 저장 중 암호화 상태
3. **접근 제어**: 권한 관리 및 역할 분리
4. **로그 감사**: 보안 이벤트 로깅 및 모니터링
5. **의존성**: 보안 취약점이 있는 패키지 확인

### 보안 체크리스트

- [ ] 모든 API 엔드포인트에 인증 적용
- [ ] HTTPS 사용 (TLS 1.3)
- [ ] Rate Limiting 적용
- [ ] 입력 검증 및 Sanitization
- [ ] SQL Injection 방지
- [ ] XSS 방지
- [ ] CSRF 보호
- [ ] 시크릿 관리 (AWS Secrets Manager)
- [ ] 로그에서 민감 정보 제거
- [ ] 정기적인 보안 업데이트

---

## 참고 문서

- [환경 변수 설정](../01-getting-started/env-config.md)
- [API 가이드](../05-api/api-guide.md)
- [배포 가이드](../01-getting-started/deployment.md)
- [Firebase 아키텍처](./firebase-architecture.md)

---

**작성일**: 2025-01-15  
**버전**: 1.0

