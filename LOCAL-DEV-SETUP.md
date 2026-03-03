# SafeTrip 로컬 개발 환경 구축 가이드

> AWS/Firebase 프로덕션 환경에 영향 없이 로컬에서 개발 및 마이그레이션 테스트

---

## 목차

1. [전체 아키텍처](#1-전체-아키텍처)
2. [사전 요구사항](#2-사전-요구사항)
3. [Step 1: PostgreSQL 로컬 실행](#3-step-1-postgresql-로컬-실행)
4. [Step 2: Firebase Emulator 실행](#4-step-2-firebase-emulator-실행)
5. [Step 3: 백엔드 서버 실행](#5-step-3-백엔드-서버-실행)
6. [Step 4: Flutter 앱 연결](#6-step-4-flutter-앱-연결)
7. [마이그레이션 테스트](#7-마이그레이션-테스트)
8. [유용한 명령어](#8-유용한-명령어)
9. [트러블슈팅](#9-트러블슈팅)

---

## 1. 전체 아키텍처

```
┌─────────────────────────────────────────────────┐
│                  로컬 머신                        │
│                                                   │
│  ┌──────────────┐    ┌────────────────────────┐  │
│  │  Flutter App  │───▶│  Backend (localhost:3001)│  │
│  │  (에뮬레이터) │    │  npm run dev             │  │
│  └──────┬───────┘    └──────┬──────┬──────────┘  │
│         │                    │      │              │
│         │                    │      │              │
│  ┌──────▼───────┐    ┌──────▼──┐ ┌─▼───────────┐ │
│  │  Firebase     │    │PostgreSQL│ │ Firebase     │ │
│  │  Emulator     │    │ Docker   │ │ Admin SDK    │ │
│  │  :4000 (UI)   │    │ :5432    │ │ → Emulator   │ │
│  │  :9099 (Auth) │    └─────────┘ └─────────────┘ │
│  │  :9000 (RTDB) │                                 │
│  │  :9199 (Stor) │                                 │
│  └──────────────┘                                  │
│                                                    │
│  ┌──────────────┐  (선택사항)                       │
│  │  pgAdmin 4   │                                  │
│  │  :5050       │                                  │
│  └──────────────┘                                  │
└────────────────────────────────────────────────────┘

프로덕션 환경 (AWS/Firebase)은 전혀 건드리지 않음!
```

### 대체 매핑

| 프로덕션 | 로컬 대체 | 포트 |
|----------|-----------|------|
| AWS RDS PostgreSQL | Docker PostgreSQL + PostGIS | 5432 |
| Firebase Auth | Firebase Auth Emulator | 9099 |
| Firebase RTDB | Firebase RTDB Emulator | 9000 |
| Firebase Storage | Firebase Storage Emulator | 9199 |
| Firebase Functions | Firebase Functions Emulator | 5001 |
| Firebase Emulator UI | — | 4000 |
| AWS ECS (백엔드) | `npm run dev` (로컬) | 3001 |
| pgAdmin (선택) | Docker pgAdmin 4 | 5050 |

---

## 2. 사전 요구사항

### 필수 설치

```bash
# 1. Docker Desktop (PostgreSQL 실행용)
# https://www.docker.com/products/docker-desktop/
docker --version   # Docker 20.10+

# 2. Node.js 18+ (백엔드 실행용)
node --version     # v18.x 이상

# 3. Firebase CLI (Emulator 실행용)
npm install -g firebase-tools
firebase --version  # 13.x 이상

# 4. Flutter SDK (앱 실행용)
flutter --version  # 3.10+

# 5. Java 11+ (Firebase Emulator 내부 요구사항)
java -version      # 11 이상
```

### 선택 설치

```bash
# PostgreSQL 클라이언트 (SQL 스크립트 직접 실행용)
# Windows: https://www.postgresql.org/download/windows/
# 또는 Docker 내부에서 psql 사용 가능
psql --version
```

---

## 3. Step 1: PostgreSQL 로컬 실행

### 3.1 Docker Compose 실행

```bash
cd D:\Project\15_SafeTrip_New\safetrip-server-api

# PostgreSQL 시작 (백그라운드)
docker compose -f docker-compose.local.yml up -d

# 상태 확인
docker compose -f docker-compose.local.yml ps

# 로그 확인
docker compose -f docker-compose.local.yml logs postgres
```

### 3.2 DB 연결 확인

```bash
# 방법 1: Docker 내부 psql
docker exec -it safetrip-postgres-local psql -U safetrip -d safetrip_local

# 방법 2: 로컬 psql (설치된 경우)
psql -h localhost -p 5432 -U safetrip -d safetrip_local
# 비밀번호: safetrip_local_2024

# 테스트 쿼리
SELECT COUNT(*) FROM TB_USER;          -- 10
SELECT COUNT(*) FROM TB_GROUP;         -- 3
SELECT COUNT(*) FROM TB_GROUP_MEMBER;  -- 11
SELECT COUNT(*) FROM TB_GUARDIAN;      -- 3
```

### 3.3 pgAdmin 사용 (선택)

```bash
# pgAdmin 포함하여 시작
docker compose -f docker-compose.local.yml --profile tools up -d

# 브라우저에서 열기: http://localhost:5050
# Email: admin@safetrip.local
# Password: admin1234
# 서버 추가: Host=postgres, Port=5432, DB=safetrip_local, User=safetrip
```

### 3.4 DB 초기화 (데이터 리셋)

```bash
# 볼륨 삭제 후 재시작 (모든 데이터 초기화)
docker compose -f docker-compose.local.yml down -v
docker compose -f docker-compose.local.yml up -d
```

---

## 4. Step 2: Firebase Emulator 실행

### 4.1 Firebase 로그인 (최초 1회)

```bash
cd D:\Project\15_SafeTrip_New

# Firebase 로그인
firebase login

# 프로젝트 확인
firebase projects:list
```

### 4.2 Emulator 실행

```bash
cd D:\Project\15_SafeTrip_New

# 에뮬레이터 시작
firebase emulators:start

# 또는 특정 에뮬레이터만 실행
firebase emulators:start --only auth,database,storage
```

### 4.3 Emulator UI 확인

브라우저에서 열기: **http://localhost:4000**

| 서비스 | URL | 설명 |
|--------|-----|------|
| Emulator UI | http://localhost:4000 | 전체 대시보드 |
| Auth | http://localhost:4000/auth | 사용자 관리 |
| RTDB | http://localhost:4000/database | 데이터 확인 |
| Storage | http://localhost:4000/storage | 파일 확인 |

### 4.4 테스트 사용자 생성 (Auth Emulator)

Emulator UI (http://localhost:4000/auth) 에서:
1. **Add user** 클릭
2. Phone Number: `+82 01011111111`
3. UID: `user_leader_01` (seed 데이터와 일치)
4. 나머지 테스트 사용자도 같은 방식으로 추가

> **팁**: Firebase Auth Emulator는 실제 SMS를 보내지 않으므로 아무 전화번호나 사용 가능합니다.

---

## 5. Step 3: 백엔드 서버 실행

### 5.1 환경변수 설정

```bash
cd D:\Project\15_SafeTrip_New\safetrip-server-api

# .env.local을 .env로 복사
cp .env.local .env

# 또는 Windows에서:
copy .env.local .env
```

### 5.2 의존성 설치 및 실행

```bash
# 의존성 설치
npm install

# 개발 모드 실행 (파일 변경 시 자동 재시작)
npm run dev
```

### 5.3 서버 동작 확인

```bash
# Health check
curl http://localhost:3001/health

# 또는 브라우저에서 http://localhost:3001/health
```

### 5.4 Firebase Emulator 연동 확인

`.env`에 아래가 설정되어 있으면 `firebase-admin` SDK가 자동으로 에뮬레이터 사용:

```env
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
FIREBASE_DATABASE_EMULATOR_HOST=127.0.0.1:9000
```

---

## 6. Step 4: Flutter 앱 연결

### 6.1 환경변수 설정

```bash
cd D:\Project\15_SafeTrip_New\safetrip-mobile

# .env.local을 .env로 복사
cp .env.local .env
```

### 6.2 main.dart 수정 (Firebase Emulator 연결)

`lib/main.dart`에서 `Firebase.initializeApp()` 후에 추가:

```dart
import 'config/firebase_emulator_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();

  // ★ Firebase Emulator 연결 (로컬 개발용)
  await FirebaseEmulatorConfig.connectIfNeeded();

  // ... 나머지 초기화
}
```

### 6.3 API 서버 URL 확인

`safetrip-mobile/.env`의 `API_SERVER_URL` 값:

| 실행 환경 | API_SERVER_URL |
|-----------|----------------|
| Android 에뮬레이터 | `http://10.0.2.2:3001` |
| iOS 시뮬레이터 | `http://localhost:3001` |
| 물리적 기기 (같은 WiFi) | `http://192.168.x.x:3001` (PC IP) |

PC IP 확인:
```bash
# Windows
ipconfig

# macOS/Linux
ifconfig | grep "inet "
```

### 6.4 앱 실행

```bash
cd D:\Project\15_SafeTrip_New\safetrip-mobile
flutter run
```

---

## 7. 마이그레이션 테스트

### 7.1 테스트 시나리오 개요

seed 데이터에 포함된 시나리오:

| 그룹 | 시나리오 | 예상 결과 |
|------|---------|----------|
| 제주도 가족여행 | owner+admin, admin, 일반, 보호자 | leader(1) + full(1) + normal(2) + view_only(1) |
| 오너탈퇴그룹 | owner=inactive, 유일 admin | admin → fallback leader |
| 보호자전용그룹 | admin+guardian 동시 | admin 우선 → leader |

### 7.2 Phase 1 실행 (컬럼/테이블 추가)

```bash
# Docker psql로 실행
docker exec -i safetrip-postgres-local psql -U safetrip -d safetrip_local \
  < scripts/local/migration-phase1.sql

# 또는 로컬 psql
psql -h localhost -U safetrip -d safetrip_local -f scripts/local/migration-phase1.sql
```

**예상 출력**: 모든 check_item이 `true`

### 7.3 Phase 2 실행 (데이터 이관)

```bash
docker exec -i safetrip-postgres-local psql -U safetrip -d safetrip_local \
  < scripts/local/migration-phase2.sql
```

**예상 출력**:
```
 member_role | count
-------------+-------
 leader      |     3  (각 그룹 1명)
 full        |     1  (user_admin_02)
 normal      |     3  (일반 여행자들)
 view_only   |     2  (보호자들)

 Groups without leader: 0
 Groups with multiple leaders: 0
 is_admin mismatch: 0
 is_guardian mismatch: 0
 All validations: OK
```

### 7.4 백엔드 코드 변경 테스트

Phase 2 완료 후:
1. 백엔드 코드를 v2.0 계획서에 따라 변경
2. `npm run dev`로 서버 재시작
3. API 테스트:

```bash
# 멤버 목록 조회 (하위호환 필드 확인)
curl http://localhost:3001/api/v1/groups/11111111-1111-1111-1111-111111111111/members

# 응답에 is_admin, is_guardian, member_role 모두 포함되어야 함
```

### 7.5 Phase 3 실행 (레거시 제거)

```bash
docker exec -i safetrip-postgres-local psql -U safetrip -d safetrip_local \
  < scripts/local/migration-phase3.sql
```

### 7.6 롤백 (처음부터 다시 테스트)

```bash
# 방법 1: 마이그레이션만 롤백 (seed 데이터 유지)
docker exec -i safetrip-postgres-local psql -U safetrip -d safetrip_local \
  < scripts/local/migration-rollback.sql

# 방법 2: 전체 DB 초기화 (처음부터)
docker compose -f docker-compose.local.yml down -v
docker compose -f docker-compose.local.yml up -d
# seed 데이터가 자동으로 다시 로드됨
```

---

## 8. 유용한 명령어

### Docker 관련

```bash
# PostgreSQL 시작/중지
docker compose -f docker-compose.local.yml up -d
docker compose -f docker-compose.local.yml down

# 전체 초기화 (데이터 삭제)
docker compose -f docker-compose.local.yml down -v

# DB 접속
docker exec -it safetrip-postgres-local psql -U safetrip -d safetrip_local

# DB 로그 확인
docker compose -f docker-compose.local.yml logs -f postgres
```

### Firebase Emulator 관련

```bash
# 에뮬레이터 시작
firebase emulators:start

# 데이터 내보내기 (에뮬레이터 데이터 저장)
firebase emulators:export ./emulator-data

# 저장된 데이터로 시작
firebase emulators:start --import=./emulator-data
```

### 백엔드 관련

```bash
# 개발 모드 (자동 재시작)
npm run dev

# 빌드
npm run build

# 린트
npm run lint
```

### SQL 직접 실행

```bash
# Docker 내부 psql
docker exec -it safetrip-postgres-local psql -U safetrip -d safetrip_local

# SQL 파일 실행
docker exec -i safetrip-postgres-local psql -U safetrip -d safetrip_local < [파일경로]

# 단일 쿼리 실행
docker exec -it safetrip-postgres-local psql -U safetrip -d safetrip_local \
  -c "SELECT * FROM TB_GROUP_MEMBER WHERE status = 'active';"
```

---

## 9. 트러블슈팅

### 포트 충돌

```bash
# 사용 중인 포트 확인 (Windows)
netstat -ano | findstr :5432
netstat -ano | findstr :3001
netstat -ano | findstr :9099

# 해결: docker-compose.local.yml에서 포트 변경
# 예: "5433:5432" 로 변경 후 .env.local의 DB_PORT도 5433으로
```

### Docker PostgreSQL 연결 실패

```bash
# 컨테이너 상태 확인
docker compose -f docker-compose.local.yml ps

# 헬스체크 확인
docker inspect safetrip-postgres-local | grep -A5 Health

# 컨테이너 재시작
docker compose -f docker-compose.local.yml restart postgres
```

### Firebase Emulator 시작 실패

```bash
# Java 버전 확인 (11+ 필요)
java -version

# Firebase CLI 업데이트
npm install -g firebase-tools

# 캐시 정리 후 재시도
firebase emulators:start --clear-cache
```

### Flutter에서 백엔드 연결 실패

1. **Android 에뮬레이터**: `API_SERVER_URL=http://10.0.2.2:3001`
2. **물리적 기기**: PC와 같은 WiFi, PC IP 사용
3. **방화벽 확인**: Windows 방화벽에서 포트 3001 허용

```bash
# Windows 방화벽 포트 열기 (관리자 권한)
netsh advfirewall firewall add rule name="SafeTrip Dev" dir=in action=allow protocol=TCP localport=3001
```

### 마이그레이션 SQL 오류

```bash
# 현재 스키마 확인
docker exec -it safetrip-postgres-local psql -U safetrip -d safetrip_local \
  -c "\d tb_group_member"

# member_role 컬럼 있는지 확인
docker exec -it safetrip-postgres-local psql -U safetrip -d safetrip_local \
  -c "SELECT column_name FROM information_schema.columns WHERE table_name='tb_group_member';"

# 롤백 후 재시도
docker exec -i safetrip-postgres-local psql -U safetrip -d safetrip_local \
  < scripts/local/migration-rollback.sql
```

---

## 전체 시작 순서 (Quick Start)

```bash
# 터미널 1: PostgreSQL
cd D:\Project\15_SafeTrip_New\safetrip-server-api
docker compose -f docker-compose.local.yml up -d

# 터미널 2: Firebase Emulator
cd D:\Project\15_SafeTrip_New
firebase emulators:start

# 터미널 3: Backend
cd D:\Project\15_SafeTrip_New\safetrip-server-api
cp .env.local .env     # 최초 1회
npm install            # 최초 1회
npm run dev

# 터미널 4: Flutter
cd D:\Project\15_SafeTrip_New\safetrip-mobile
cp .env.local .env     # 최초 1회
flutter run
```

---

## 외부 네트워크 공유 (ngrok)

물리 기기 + 외부 네트워크에서 로컬 개발 환경에 접속할 때 사용합니다.

### 아키텍처

```
물리 기기 (외부 네트워크)
    ↓ HTTP (schemes: [http], 리다이렉트 없음)
ngrok (단일 터널)
    ↓
local-proxy.cjs :8888  ← 경로 기반 라우팅
    ├─ /identitytoolkit.googleapis.com/* → Firebase Auth  :9099
    ├─ /v0/*                            → Firebase Storage :9199
    ├─ WebSocket                        → Firebase RTDB   :9000
    └─ /*                               → Backend API     :3001
```

> ngrok 무료 플랜은 HTTP 터널 1개에 단일 도메인만 허용합니다.
> `local-proxy.cjs`가 URL 경로를 분석해 각 서비스로 라우팅합니다.

### 사전 준비 (최초 1회)

1. [ngrok.com](https://ngrok.com) 무료 계정 가입
2. authtoken 발급: Dashboard → Your Authtoken
3. WSL2에 환경변수 설정:
   ```bash
   echo 'export NGROK_AUTHTOKEN=your_token_here' >> ~/.bashrc
   source ~/.bashrc
   ```

### 시작

```bash
cd /mnt/d/Project/15_SafeTrip_New
bash scripts/start-dev-ngrok.sh
```

스크립트가 자동으로 (6단계):
1. 사전 요구사항 확인 (ngrok, Node.js, Firebase CLI, Java)
2. Firebase Emulator 시작 (`--import=./emulator-data` 적용)
3. Backend API 시작
4. 로컬 리버스 프록시 시작 (`scripts/local-proxy.cjs`, 포트 8888)
5. ngrok HTTP 터널 시작 (→ 포트 8888)
6. `safetrip-mobile/.env` 에 ngrok URL 자동 기입 (4개 env var 모두 동일 URL)

### 물리 기기 앱 실행

```bash
cd safetrip-mobile
flutter run
```

### 물리 기기 로그인 방법

| 단계 | 내용 |
|------|------|
| 1 | 앱에서 전화번호 입력 |
| 2 | PC 브라우저에서 http://localhost:4000/auth 열기 |
| 3 | 해당 전화번호 행의 "SMS Code" 확인 |
| 4 | 앱에서 코드 입력 → 로그인 완료 |

### 주의사항

- ngrok URL은 세션마다 변경됨 → 스크립트 재실행 시 `.env` 자동 갱신
- Firebase RTDB WebSocket 연결은 프록시의 `upgrade` 핸들러를 통해 라우팅됨
- ngrok 무료 플랜: 분당 40 요청 제한 (개발 테스트 충분)
- 종료: `pkill -f "ngrok start" && pkill -f local-proxy.cjs`

---

## 전체 종료 순서

```bash
# Flutter: Ctrl+C
# Backend: Ctrl+C
# Firebase Emulator: Ctrl+C
# PostgreSQL:
docker compose -f docker-compose.local.yml down
```
