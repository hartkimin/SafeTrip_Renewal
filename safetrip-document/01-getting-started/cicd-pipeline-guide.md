# SafeTrip CI/CD 파이프라인 가이드

## 목차

1. [개요](#개요)
2. [GitHub Actions 설정](#github-actions-설정)
3. [테스트 자동화](#테스트-자동화)
4. [빌드 자동화](#빌드-자동화)
5. [배포 자동화](#배포-자동화)
6. [코드 품질 검사](#코드-품질-검사)
7. [보안 스캔](#보안-스캔)

---

## 개요

SafeTrip은 GitHub Actions를 사용하여 CI/CD 파이프라인을 구축합니다.

### 파이프라인 단계

1. **코드 품질 검사**: Lint, Formatting
2. **테스트 실행**: 단위 테스트, 통합 테스트
3. **보안 스캔**: 의존성 취약점 검사
4. **빌드**: Docker 이미지 빌드
5. **배포**: AWS ECS/Fargate 배포

---

## GitHub Actions 설정

### 워크플로우 구조

```
.github/
└── workflows/
    ├── test.yml          # 테스트 실행
    ├── build.yml         # 빌드 및 배포
    └── security.yml      # 보안 스캔
```

### 기본 워크플로우

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
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
          channel: 'beta'

      - name: Get dependencies
        run: |
          cd safetrip-mobile
          flutter pub get

      - name: Run tests
        run: |
          cd safetrip-mobile
          flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./safetrip-mobile/coverage/lcov.info
          flags: flutter

  backend-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: safetrip-server-api/package-lock.json

      - name: Install dependencies
        run: |
          cd safetrip-server-api
          npm ci

      - name: Run tests
        run: |
          cd safetrip-server-api
          npm test -- --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./safetrip-server-api/coverage/lcov.info
          flags: backend
```

---

## 테스트 자동화

### Flutter 테스트

```yaml
  flutter-test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      
      - name: Install dependencies
        run: |
          cd safetrip-mobile
          flutter pub get
      
      - name: Run unit tests
        run: |
          cd safetrip-mobile
          flutter test
      
      - name: Run integration tests
        run: |
          cd safetrip-mobile
          flutter test integration_test/
        if: matrix.os == 'ubuntu-latest'
```

### 백엔드 테스트

```yaml
  backend-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: safetrip_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: |
          cd safetrip-server-api
          npm ci
      
      - name: Run tests
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_NAME: safetrip_test
          DB_USER: postgres
          DB_PASSWORD: postgres
        run: |
          cd safetrip-server-api
          npm test
```

---

## 빌드 자동화

### Docker 이미지 빌드

**`.github/workflows/build.yml`**

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]
    tags:
      - 'v*'

jobs:
  build-backend:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build, tag, and push image to Amazon ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: safetrip-api
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -f safetrip-server-api/Dockerfile safetrip-server-api/
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

  build-flutter:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'

      - name: Get dependencies
        run: |
          cd safetrip-mobile
          flutter pub get

      - name: Build Android APK
        run: |
          cd safetrip-mobile
          flutter build apk --release

      - name: Build Android App Bundle
        run: |
          cd safetrip-mobile
          flutter build appbundle --release

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: android-build
          path: |
            safetrip-mobile/build/app/outputs/flutter-apk/app-release.apk
            safetrip-mobile/build/app/outputs/bundle/release/app-release.aab
```

---

## 배포 자동화

### AWS ECS 배포

```yaml
  deploy-backend:
    needs: build-backend
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster safetrip-cluster \
            --service safetrip-api \
            --force-new-deployment \
            --region ap-northeast-2

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster safetrip-cluster \
            --services safetrip-api \
            --region ap-northeast-2
```

### 환경별 배포

```yaml
  deploy:
    strategy:
      matrix:
        environment: [staging, production]
    steps:
      - name: Deploy to ${{ matrix.environment }}
        run: |
          if [ "${{ matrix.environment }}" == "production" ]; then
            CLUSTER_NAME="safetrip-prod-cluster"
            SERVICE_NAME="safetrip-api-prod"
          else
            CLUSTER_NAME="safetrip-staging-cluster"
            SERVICE_NAME="safetrip-api-staging"
          fi
          
          aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service $SERVICE_NAME \
            --force-new-deployment
```

---

## 코드 품질 검사

### Lint 검사

```yaml
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Flutter lint
        run: |
          cd safetrip-mobile
          flutter analyze
      
      - name: Backend lint
        run: |
          cd safetrip-server-api
          npm run lint
```

### 코드 포맷팅

```yaml
  format-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Check Flutter formatting
        run: |
          cd safetrip-mobile
          flutter format --set-exit-if-changed .
      
      - name: Check backend formatting
        run: |
          cd safetrip-server-api
          npx prettier --check "src/**/*.ts"
```

---

## 보안 스캔

### 의존성 취약점 검사

**`.github/workflows/security.yml`**

```yaml
name: Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  schedule:
    - cron: '0 0 * * 0' # 매주 일요일

jobs:
  dependency-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run npm audit
        run: |
          cd safetrip-server-api
          npm audit --audit-level=moderate
      
      - name: Run Snyk scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  code-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run CodeQL Analysis
        uses: github/codeql-action/analyze@v2
        with:
          languages: typescript, dart
```

### 시크릿 스캔

```yaml
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run TruffleHog
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
```

---

## 배포 승인 프로세스

### 수동 승인

```yaml
  deploy-production:
    needs: [build, test]
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://api.safetrip.io
    
    steps:
      - name: Deploy to production
        run: |
          # 배포 스크립트 실행
          ./deploy.ps1
```

GitHub 환경 설정에서 승인자를 지정하면 배포 전 승인이 필요합니다.

---

## 알림 설정

### Slack 알림

```yaml
  notify:
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Notify Slack
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'Deployment ${{ job.status }}'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 참고 문서

- [배포 가이드](./deployment.md)
- [테스트 가이드](../07-guides/testing-guide.md)
- [보안 가이드](../02-architecture/security-guide.md)

---

**작성일**: 2025-01-15  
**버전**: 1.0

