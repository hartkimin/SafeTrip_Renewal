# SafeTrip 문서

## 📚 문서 목록

### 시작하기
- **[개발 환경 설정](./01-getting-started/development-setup.md)**
  - 개발 환경 구축 가이드
  - 필수 도구 설치
  - 프로젝트별 개발 환경 설정
  - 로컬 데이터베이스 설정
  - Firebase 에뮬레이터 설정

- **[환경 변수 설정](./01-getting-started/env-config.md)**
  - 환경 변수 설정 가이드
  - 백엔드, 모바일 환경 변수
  - AWS Secrets Manager 사용법
  - 보안 권장사항

- **[배포 가이드](./01-getting-started/deployment.md)**
  - 배포 가이드
  - 백엔드 API 배포 (AWS ECS/Fargate)
  - Firebase Functions 배포
  - 모바일 앱 배포 (Google Play/App Store)
  - 환경별 배포 및 롤백 방법

- **[CI/CD 파이프라인 가이드](./01-getting-started/cicd-pipeline-guide.md)**
  - GitHub Actions 설정
  - 테스트 자동화
  - 빌드 및 배포 자동화
  - 코드 품질 검사

### 아키텍처 및 설계
- **[Firebase 아키텍처](./02-architecture/firebase-architecture.md)**
  - Firebase Realtime Database + AWS RDS PostgreSQL 아키텍처
  - 서비스 분리 전략
  - 데이터 동기화 패턴
  - PostGIS 필요성 분석

- **[외부 통합](./02-architecture/external-integrations.md)**
  - 외부 서비스 통합 가이드
  - Firebase, Google Maps, Geocoding 등
  - API 키 관리 및 설정

- **[보안 가이드](./02-architecture/security-guide.md)**
  - 인증 및 인가
  - 데이터 암호화
  - API 보안
  - 개인정보 보호
  - 보안 모범 사례

### 데이터베이스
- **[데이터베이스 개요](./03-database/database-readme.md)**
  - 데이터베이스 스키마 전체 설명
  - 테이블 구조 및 관계
  - 비즈니스 로직 설명
  - PostgreSQL과 RTDB 역할 구분

- **[데이터베이스 설정](./03-database/database-setup.md)**
  - AWS RDS PostgreSQL 설정 가이드
  - PostGIS 확장 설치
  - 스키마 생성 방법

- **[데이터베이스 연결](./03-database/database-connection.md)**
  - 데이터베이스 클라이언트 연결 가이드
  - DBeaver, pgAdmin 등 연결 방법
  - 연결 문자열 정보

- **[Firebase Realtime Database](./04-firebase/firebase-rtdb.md)**
  - Firebase Realtime Database 구조 및 사용법
  - 실시간 데이터 동기화 가이드
  - Flutter 및 백엔드 사용 예제

### API
- **[API 가이드](./05-api/api-guide.md)**
  - SafeTrip API 사용 가이드
  - API 엔드포인트 설명
  - 요청/응답 예제
  - 웹훅 이벤트

### 이벤트 및 알림
- **[이벤트 로그 타입](./06-events/event-log-types.md)**
  - 이벤트 로그 타입 정의
  - 이벤트 분류 및 구조

- **[이벤트 알림 채널](./06-events/event-notification-channels.md)**
  - 이벤트 알림 채널 설정
  - 알림 전송 전략

### 가이드
- **[Google Maps API 설정](./07-guides/google-maps-api-setup.md)**
  - Google Maps API 키 설정 가이드
  - Flutter 및 백엔드 설정 방법

- **[Flutter 구현 가능성 분석](./07-guides/flutter-implementation-feasibility.md)**
  - Flutter 기능 구현 가능성 분석
  - 기술적 제약사항 및 해결 방안

- **[테스트 가이드](./07-guides/testing-guide.md)**
  - Flutter 앱 테스트
  - 백엔드 API 테스트
  - 통합 테스트
  - 테스트 커버리지
  - 모의 데이터 (Mock)

- **[트러블슈팅 가이드](./07-guides/troubleshooting-guide.md)**
  - 일반적인 문제 해결
  - Flutter 앱 문제
  - 백엔드 API 문제
  - 데이터베이스 문제
  - Firebase 문제
  - 배포 문제

- **[모니터링 및 로깅 가이드](./07-guides/monitoring-logging-guide.md)**
  - 로깅 전략
  - 에러 추적
  - 성능 모니터링
  - 알림 설정
  - 로그 분석

---

## 📁 관련 파일 위치

### 스키마 파일
- `./03-database/database-schema.dbml` - DBML 형식 스키마 (ERD 시각화용)
- `./03-database/database-schema.sql` - PostgreSQL DDL 스크립트

### API 스펙
- `./05-api/api-specification.yaml` - OpenAPI 3.0 스펙
- `./05-api/safetrip-api.postman-collection.json` - Postman 컬렉션

### 스크립트
- `../safetrip-server-api/scripts/` - 데이터베이스 설정 및 관리 스크립트
  - 데이터베이스 분석 스크립트
  - 필드 사용 분석 리포트

---

## 🚀 빠른 시작

### 1. 개발 환경 설정
- [개발 환경 설정](./01-getting-started/development-setup.md) 참고

### 2. 환경 변수 설정
- [환경 변수 설정](./01-getting-started/env-config.md) 참고

### 3. 데이터베이스 설정
- [데이터베이스 설정](./03-database/database-setup.md) 참고
- [데이터베이스 연결](./03-database/database-connection.md) 참고

### 4. API 사용
- [API 가이드](./05-api/api-guide.md) 참고

---

## 📖 문서 업데이트

문서는 프로젝트와 함께 업데이트됩니다. 최신 정보는 각 문서를 참고하세요.
