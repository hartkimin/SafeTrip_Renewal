# SafeTrip 테스트 가이드

## 목차

1. [개요](#개요)
2. [Flutter 앱 테스트](#flutter-앱-테스트)
3. [백엔드 API 테스트](#백엔드-api-테스트)
4. [통합 테스트](#통합-테스트)
5. [테스트 커버리지](#테스트-커버리지)
6. [모의 데이터 (Mock)](#모의-데이터-mock)
7. [CI/CD 통합](#cicd-통합)

---

## 개요

SafeTrip 프로젝트는 Flutter 모바일 앱과 Node.js 백엔드 API로 구성되어 있습니다. 각 컴포넌트에 대한 테스트 전략과 방법을 설명합니다.

### 테스트 목표

- **단위 테스트**: 개별 함수/메서드의 정확성 검증
- **통합 테스트**: 여러 컴포넌트 간 상호작용 검증
- **E2E 테스트**: 사용자 시나리오 기반 전체 플로우 검증
- **성능 테스트**: 응답 시간 및 처리량 검증

---

## Flutter 앱 테스트

### 환경 설정

Flutter 테스트는 `flutter_test` 패키지를 사용합니다. `pubspec.yaml`에 이미 포함되어 있습니다.

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
```

### 단위 테스트

#### 위젯 테스트

위젯 테스트는 UI 컴포넌트의 렌더링과 상호작용을 검증합니다.

**예제: `test/widget_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_geofence/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 위젯 빌드
    await tester.pumpWidget(const MyApp());

    // 초기 상태 확인
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // 버튼 탭
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // 상태 변경 확인
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
```

#### 서비스 테스트

서비스 로직은 모의 객체(Mock)를 사용하여 테스트합니다.

**예제: 위치 서비스 테스트**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app_geofence/services/location_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([LocationService])
void main() {
  group('LocationService', () {
    test('위치 저장 성공', () async {
      // Mock 설정
      final mockService = MockLocationService();
      
      // 테스트 실행
      when(mockService.saveLocation(any))
          .thenAnswer((_) async => {'success': true});
      
      final result = await mockService.saveLocation({
        'latitude': 37.5665,
        'longitude': 126.9780,
      });
      
      // 검증
      expect(result['success'], true);
      verify(mockService.saveLocation(any)).called(1);
    });
  });
}
```

### 통합 테스트

통합 테스트는 실제 디바이스나 에뮬레이터에서 실행됩니다.

**예제: `integration_test/app_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app_geofence/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('앱 통합 테스트', () {
    testWidgets('로그인 플로우', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 로그인 화면 확인
      expect(find.text('로그인'), findsOneWidget);

      // 전화번호 입력
      await tester.enterText(find.byType(TextField), '01012345678');
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      // OTP 입력 화면 확인
      expect(find.text('인증번호 입력'), findsOneWidget);
    });
  });
}
```

### 테스트 실행

```bash
# 단위 테스트 실행
flutter test

# 특정 테스트 파일 실행
flutter test test/widget_test.dart

# 통합 테스트 실행
flutter test integration_test/

# 커버리지 포함 테스트
flutter test --coverage
```

---

## 백엔드 API 테스트

### 환경 설정

백엔드는 Jest를 사용하여 테스트합니다.

**설정: `jest.config.js`**

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/index.ts',
  ],
};
```

### 단위 테스트

#### 서비스 테스트

**예제: `src/services/__tests__/location.service.test.ts`**

```typescript
import { locationService } from '../location.service';
import { getDatabase } from '../../config/database';
import { logger } from '../../utils/logger';

jest.mock('../../config/database');
jest.mock('../../utils/logger');

describe('LocationService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('saveLocation', () => {
    it('위치 저장 성공', async () => {
      const mockDb = {
        query: jest.fn().mockResolvedValue({
          rows: [{ location_id: '123', recorded_at: new Date() }],
        }),
      };
      (getDatabase as jest.Mock).mockReturnValue(mockDb);

      const locationData = {
        user_id: 'user123',
        latitude: 37.5665,
        longitude: 126.9780,
      };

      const result = await locationService.saveLocation(locationData);

      expect(result.location_id).toBe('123');
      expect(mockDb.query).toHaveBeenCalled();
    });

    it('위치 저장 실패 시 에러 처리', async () => {
      const mockDb = {
        query: jest.fn().mockRejectedValue(new Error('Database error')),
      };
      (getDatabase as jest.Mock).mockReturnValue(mockDb);

      await expect(
        locationService.saveLocation({
          user_id: 'user123',
          latitude: 37.5665,
          longitude: 126.9780,
        })
      ).rejects.toThrow('Database error');
    });
  });
});
```

#### 컨트롤러 테스트

**예제: `src/controllers/__tests__/users.controller.test.ts`**

```typescript
import { Request, Response } from 'express';
import { getCurrentUser } from '../users.controller';
import { userService } from '../../services/user.service';

jest.mock('../../services/user.service');

describe('UsersController', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;

  beforeEach(() => {
    mockRequest = {
      userId: 'user123',
    };
    mockResponse = {
      json: jest.fn(),
      status: jest.fn().mockReturnThis(),
    };
  });

  describe('getCurrentUser', () => {
    it('현재 사용자 정보 조회 성공', async () => {
      const mockUser = {
        user_id: 'user123',
        phone_number: '01012345678',
      };
      (userService.getUserById as jest.Mock).mockResolvedValue(mockUser);

      await getCurrentUser(
        mockRequest as Request,
        mockResponse as Response
      );

      expect(mockResponse.json).toHaveBeenCalledWith({
        success: true,
        data: mockUser,
      });
    });
  });
});
```

### API 통합 테스트

**예제: `src/__tests__/api.integration.test.ts`**

```typescript
import request from 'supertest';
import app from '../index';

describe('API 통합 테스트', () => {
  describe('GET /health', () => {
    it('헬스체크 성공', async () => {
      const response = await request(app).get('/health');
      
      expect(response.status).toBe(200);
      expect(response.body.status).toBe('ok');
    });
  });

  describe('GET /api/v1/users/me', () => {
    it('인증 없이 접근 시 401 반환', async () => {
      const response = await request(app).get('/api/v1/users/me');
      
      expect(response.status).toBe(401);
    });

    it('유효한 토큰으로 접근 시 사용자 정보 반환', async () => {
      // Firebase ID Token 생성 (테스트용)
      const token = 'valid-test-token';
      
      const response = await request(app)
        .get('/api/v1/users/me')
        .set('Authorization', `Bearer ${token}`);
      
      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });
  });
});
```

### 테스트 실행

```bash
# 모든 테스트 실행
npm test

# 특정 테스트 파일 실행
npm test -- location.service.test.ts

# 커버리지 포함 테스트
npm test -- --coverage

# Watch 모드
npm test -- --watch
```

---

## 통합 테스트

### E2E 테스트 시나리오

주요 사용자 시나리오를 테스트합니다:

1. **사용자 등록 및 로그인**
   - 전화번호 인증
   - Firebase 인증 토큰 발급
   - 사용자 프로필 생성

2. **위치 공유**
   - 백그라운드 위치 추적 시작
   - 위치 데이터 저장
   - 실시간 위치 조회

3. **지오펜스 관리**
   - 지오펜스 생성
   - 진입/이탈 이벤트 감지
   - 알림 전송

4. **그룹 관리**
   - 그룹 생성
   - 멤버 초대
   - 그룹 채팅

### 테스트 데이터베이스

통합 테스트는 별도의 테스트 데이터베이스를 사용합니다.

```typescript
// test-setup.ts
process.env.DB_NAME = 'safetrip_test';
process.env.NODE_ENV = 'test';
```

---

## 테스트 커버리지

### 목표 커버리지

- **단위 테스트**: 80% 이상
- **통합 테스트**: 주요 플로우 100%
- **E2E 테스트**: 핵심 시나리오 100%

### 커버리지 확인

```bash
# Flutter
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# 백엔드
npm test -- --coverage
```

---

## 모의 데이터 (Mock)

### Flutter Mock

**`mockito` 패키지 사용**

```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([LocationService, FirebaseDatabase])
void main() {
  // Mock 객체 생성
  final mockLocationService = MockLocationService();
  final mockFirebaseDatabase = MockFirebaseDatabase();
}
```

### 백엔드 Mock

**Jest Mock 사용**

```typescript
// Firebase Admin SDK Mock
jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  auth: jest.fn(() => ({
    verifyIdToken: jest.fn(),
  })),
}));

// 데이터베이스 Mock
jest.mock('../config/database', () => ({
  getDatabase: jest.fn(),
}));
```

---

## CI/CD 통합

### GitHub Actions 예제

**`.github/workflows/test.yml`**

```yaml
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  flutter-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info

  backend-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: cd safetrip-server-api && npm install
      - run: cd safetrip-server-api && npm test -- --coverage
```

---

## 참고 문서

- [Flutter 테스트 공식 문서](https://docs.flutter.dev/testing)
- [Jest 공식 문서](https://jestjs.io/)
- [API 가이드](../05-api/api-guide.md)
- [개발 환경 설정](../01-getting-started/development-setup.md)

---

**작성일**: 2025-01-15  
**버전**: 1.0

