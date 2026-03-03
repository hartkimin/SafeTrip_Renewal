# SafeTrip 모니터링 및 로깅 가이드

## 목차

1. [개요](#개요)
2. [로깅 전략](#로깅-전략)
3. [에러 추적](#에러-추적)
4. [성능 모니터링](#성능-모니터링)
5. [알림 설정](#알림-설정)
6. [로그 분석](#로그-분석)

---

## 개요

SafeTrip은 안정적인 서비스를 제공하기 위해 체계적인 로깅과 모니터링 시스템을 구축합니다.

### 모니터링 목표

- **가용성**: 서비스 가동 시간 모니터링
- **성능**: 응답 시간 및 처리량 추적
- **에러**: 에러 발생 및 추적
- **보안**: 의심스러운 활동 감지

---

## 로깅 전략

### 백엔드 로깅

#### Winston 로거 설정

SafeTrip 백엔드는 Winston을 사용하여 로깅합니다.

**설정: `src/utils/logger.ts`**

```typescript
import winston from 'winston';

const logLevel = process.env.LOG_LEVEL || 'info';

export const logger = winston.createLogger({
  level: logLevel,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'safetrip-api-server' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
    // 프로덕션에서는 파일 또는 클라우드 로그 서비스 사용
    ...(process.env.NODE_ENV === 'production' ? [
      new winston.transports.File({ filename: 'error.log', level: 'error' }),
      new winston.transports.File({ filename: 'combined.log' }),
    ] : []),
  ],
});
```

#### 로그 레벨

- **error**: 에러 발생 시
- **warn**: 경고 상황
- **info**: 일반 정보 (기본)
- **debug**: 디버깅 정보
- **verbose**: 상세 정보

#### 로깅 예제

```typescript
import { logger } from '../utils/logger';

// 정보 로그
logger.info('Location saved', { 
  user_id: userId, 
  location_id: locationId,
});

// 에러 로그
logger.error('Failed to save location', { 
  user_id: userId, 
  error: error.message,
  stack: error.stack,
});

// 경고 로그
logger.warn('Rate limit approaching', {
  user_id: userId,
  request_count: count,
});
```

### Flutter 앱 로깅

#### debugPrint 사용

```dart
import 'package:flutter/foundation.dart';

// 디버그 모드에서만 출력
debugPrint('Location updated: $latitude, $longitude');

// 조건부 로깅
if (kDebugMode) {
  print('Debug information');
}
```

#### 로그 레벨 관리

```dart
enum LogLevel { debug, info, warning, error }

class AppLogger {
  static void log(LogLevel level, String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final levelStr = level.toString().split('.').last.toUpperCase();
      debugPrint('[$timestamp] [$levelStr] $message');
      if (data != null) {
        debugPrint('Data: $data');
      }
    }
    
    // 프로덕션에서는 원격 로깅 서비스로 전송
    if (kReleaseMode && level == LogLevel.error) {
      // Firebase Crashlytics 또는 Sentry로 전송
      FirebaseCrashlytics.instance.recordError(
        Exception(message),
        StackTrace.current,
        reason: data?.toString(),
      );
    }
  }
}
```

---

## 에러 추적

### 백엔드 에러 처리

#### 에러 미들웨어

```typescript
// src/middleware/error.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

export const errorHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // 에러 로깅
  logger.error(`Error: ${err.message}`, { 
    stack: err.stack,
    path: req.path,
    method: req.method,
    userId: (req as any).userId,
    ip: req.ip,
  });

  // 에러 응답
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  res.status(statusCode).json({
    success: false,
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};
```

### Flutter 앱 에러 추적

#### Firebase Crashlytics

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// 에러 기록
FirebaseCrashlytics.instance.recordError(
  error,
  stackTrace,
  reason: 'Location update failed',
  fatal: false,
);

// 사용자 정의 로그
FirebaseCrashlytics.instance.log('User action: Location shared');
```

#### 전역 에러 핸들러

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Flutter 프레임워크 에러 처리
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  
  // 비동기 에러 처리
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(MyApp());
}
```

---

## 성능 모니터링

### API 응답 시간 모니터링

#### 미들웨어로 응답 시간 측정

```typescript
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

export const responseTimeLogger = (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('Request completed', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
    });
    
    // 느린 요청 경고
    if (duration > 1000) {
      logger.warn('Slow request detected', {
        method: req.method,
        path: req.path,
        duration: `${duration}ms`,
      });
    }
  });
  
  next();
};
```

### 데이터베이스 쿼리 모니터링

#### 쿼리 로깅

```typescript
const pool = new Pool({
  // ... 기타 설정
});

// 쿼리 실행 전후 로깅
pool.on('query', (query) => {
  const start = Date.now();
  
  query.on('end', () => {
    const duration = Date.now() - start;
    if (duration > 100) { // 100ms 이상인 쿼리만 로깅
      logger.info('Slow query detected', {
        query: query.text,
        duration: `${duration}ms`,
      });
    }
  });
});
```

### Flutter 앱 성능 모니터링

#### 성능 오버레이

```dart
import 'package:flutter/rendering.dart';

void main() {
  // 성능 오버레이 활성화 (디버그 모드)
  debugPaintSizeEnabled = kDebugMode;
  debugRepaintRainbowEnabled = kDebugMode;
  
  runApp(MyApp());
}
```

#### 성능 메트릭 수집

```dart
import 'package:firebase_performance/firebase_performance.dart';

// 트레이스 시작
final trace = FirebasePerformance.instance.newTrace('location_update');
await trace.start();

try {
  // 작업 수행
  await updateLocation();
  trace.setMetric('location_count', 1);
} catch (e) {
  trace.setMetric('error_count', 1);
  rethrow;
} finally {
  await trace.stop();
}
```

---

## 알림 설정

### AWS CloudWatch 알람

#### CPU 사용률 알람

```json
{
  "AlarmName": "HighCPUUsage",
  "MetricName": "CPUUtilization",
  "Namespace": "AWS/ECS",
  "Statistic": "Average",
  "Period": 300,
  "EvaluationPeriods": 2,
  "Threshold": 80,
  "ComparisonOperator": "GreaterThanThreshold",
  "AlarmActions": ["arn:aws:sns:ap-northeast-2:account:alerts"]
}
```

#### 에러율 알람

```typescript
// CloudWatch 커스텀 메트릭
import { CloudWatch } from '@aws-sdk/client-cloudwatch';

const cloudwatch = new CloudWatch({ region: 'ap-northeast-2' });

async function putErrorMetric(count: number) {
  await cloudwatch.putMetricData({
    Namespace: 'SafeTrip/API',
    MetricData: [{
      MetricName: 'ErrorCount',
      Value: count,
      Unit: 'Count',
      Timestamp: new Date(),
    }],
  });
}
```

### 이메일 알림

```typescript
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

const ses = new SESClient({ region: 'ap-northeast-2' });

async function sendAlert(subject: string, message: string) {
  await ses.send(new SendEmailCommand({
    Source: 'alerts@safetrip.io',
    Destination: {
      ToAddresses: ['dev-team@safetrip.io'],
    },
    Message: {
      Subject: { Data: subject },
      Body: { Text: { Data: message } },
    },
  }));
}
```

---

## 로그 분석

### AWS CloudWatch Logs Insights

#### 쿼리 예제

```
# 에러 로그 검색
fields @timestamp, @message
| filter @message like /error/i
| sort @timestamp desc
| limit 100

# 느린 요청 검색
fields @timestamp, @message
| parse @message "duration: *ms" as duration
| filter duration > 1000
| sort duration desc

# 사용자별 요청 수
fields @timestamp, userId
| stats count() by userId
| sort count desc
```

### 로그 집계

```typescript
// 일일 에러 리포트
async function generateDailyErrorReport() {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  
  const errors = await db.query(`
    SELECT 
      error_type,
      COUNT(*) as count,
      MAX(occurred_at) as last_occurrence
    FROM tb_error_log
    WHERE occurred_at >= $1
    GROUP BY error_type
    ORDER BY count DESC
  `, [yesterday]);
  
  logger.info('Daily error report', { errors: errors.rows });
}
```

---

## 모니터링 대시보드

### 주요 메트릭

1. **API 메트릭**
   - 요청 수 (RPS)
   - 응답 시간 (평균, P95, P99)
   - 에러율
   - 상태 코드 분포

2. **데이터베이스 메트릭**
   - 연결 수
   - 쿼리 실행 시간
   - 느린 쿼리 수
   - 트랜잭션 수

3. **시스템 메트릭**
   - CPU 사용률
   - 메모리 사용률
   - 디스크 I/O
   - 네트워크 트래픽

4. **애플리케이션 메트릭**
   - 활성 사용자 수
   - 위치 업데이트 수
   - 지오펜스 이벤트 수
   - FCM 전송 성공률

---

## 참고 문서

- [개발 환경 설정](../01-getting-started/development-setup.md)
- [배포 가이드](../01-getting-started/deployment.md)
- [트러블슈팅 가이드](./troubleshooting-guide.md)

---

**작성일**: 2025-01-15  
**버전**: 1.0

