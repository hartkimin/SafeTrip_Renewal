# SafeTrip 프로젝트 가이드

## 프로젝트 개요
SafeTrip은 여행 일정과 실시간 위치를 결합하여 여행자 안전을 모니터링하는 Flutter 모바일 앱입니다.
일정 이탈 자동 감지, SOS 긴급알림, 그룹 관리(50명), 오프라인 모드를 핵심 기능으로 합니다.

## 기술 스택
- Frontend: Flutter 3.16+ (Dart), Riverpod, GoRouter
- Backend: Node.js (Express + TypeScript)
- Database: PostgreSQL (PostGIS) + Redis
- Push: Firebase FCM
- Maps: Google Maps API
- Auth: Firebase Authentication
- Storage: Firebase Cloud Storage

## 코드 컨벤션

### Flutter (Dart)
- 파일명: snake_case / 클래스: PascalCase / 변수: camelCase
- 폴더: lib/features/{feature_name}/
- const constructor 최대한 사용
- 하드코딩 금지 → constants.dart 또는 .env

### Backend (TypeScript)
- Controller → Service → Repository 패턴
- API 응답: { success: boolean, data?: any, error?: string }
- 에러: 커스텀 AppError 클래스
- 시크릿 하드코딩 절대 금지

### Database
- snake_case 컬럼명
- 모든 테이블: created_at, updated_at 필수
- soft delete (deleted_at)
- Migration: Prisma

### 보안
- 위치 데이터: E2E 암호화
- API: JWT + Refresh Token
- 통신: TLS 1.3
- GDPR/개인정보보호법 준수

## 도메인 경계 (Agent Team 파일 충돌 방지)

| 에이전트 | 소유 파일/디렉토리 |
|---------|-------------------|
| flutter-developer | safetrip-mobile/lib/, safetrip-mobile/pubspec.yaml, safetrip-mobile/assets/ |
| backend-developer | safetrip-server-api/src/, safetrip-server-api/package.json, scripts/local/ |
| test-engineer | safetrip-mobile/test/, safetrip-mobile/integration_test/, safetrip-server-api/tests/ |
| infra-engineer | scripts/, firebase.json, database.rules.json, storage.rules, .github/workflows/ |
| security-auditor | Read-only (수정 없음) |
| researcher | Read-only (수정 없음) |

## 순차 실행 체인 (의존성 순서)

### 기능 개발
researcher → backend-developer(API 스펙 확정) → flutter-developer(UI 구현) → test-engineer → security-auditor

### DB 변경
backend-developer(스키마+migration) → backend-developer(API) → flutter-developer(모델) → test-engineer

### 배포
test-engineer(전체 테스트) → security-auditor(감사) → infra-engineer(빌드+배포)

## 병렬화 규칙
- 같은 파일을 두 팀원이 동시에 수정하지 않을 것
- 인터페이스(API 스펙, 모델)는 backend가 먼저 확정
- DB 스키마 변경은 backend-developer만 담당

## 커밋 컨벤션
feat: / fix: / refactor: / test: / docs: / chore:
