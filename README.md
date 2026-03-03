# SafeTrip

해외 여행 안전 플랫폼

## 프로젝트 소개

SafeTrip은 해외 여행 중 발생할 수 있는 안전 문제를 해결하는 모바일 안전 플랫폼입니다. 실시간 위치 공유, SOS 긴급 알림, 지오펜스 관리, 그룹 채팅 등 핵심 기능을 제공합니다.

**공식 웹사이트**: https://safetrip.io

## 프로젝트 구조

```
SafeTrip/
├── safetrip-mobile/   # Flutter 모바일 앱
├── safetrip-server-api/  # Node.js 백엔드 API (AWS ECS/Fargate)
├── safetrip-firebase-function/  # Firebase Cloud Functions
├── shared/            # 공통 TypeScript 타입 및 유틸리티
└── safetrip-document/  # 프로젝트 문서
```

### 주요 구성 요소

- **safetrip-mobile**: Flutter 기반 모바일 앱 (Android/iOS)
  - 실시간 위치 공유
  - 지오펜스 관리
  - SOS 긴급 알림
  - 그룹 채팅
  - 여행 기록

- **safetrip-server-api**: Node.js + TypeScript 백엔드 API
  - RESTful API 서버
  - PostgreSQL 데이터베이스 연동
  - Firebase Admin SDK (FCM)
  - AWS ECS/Fargate 배포

- **safetrip-firebase-function**: Firebase Cloud Functions
  - 서버리스 함수
  - 이벤트 트리거

## 빠른 시작

### 개발 환경 설정

자세한 개발 환경 설정은 [개발 환경 설정](./safetrip-document/01-getting-started/development-setup.md)를 참고하세요.

### 환경 변수 설정

환경 변수 설정 방법은 [환경 변수 설정](./safetrip-document/01-getting-started/env-config.md)를 참고하세요.

## 주요 문서

자세한 문서는 [safetrip-document/README.md](./safetrip-document/README.md)를 참고하세요.

### 시작하기
- [개발 환경 설정](./safetrip-document/01-getting-started/development-setup.md) - 개발 환경 구축 가이드
- [환경 변수 설정](./safetrip-document/01-getting-started/env-config.md) - 환경 변수 설정 가이드
- [배포 가이드](./safetrip-document/01-getting-started/deployment.md) - 배포 방법 및 절차

### 아키텍처
- [Firebase 아키텍처](./safetrip-document/02-architecture/firebase-architecture.md) - Firebase + AWS RDS PostgreSQL 아키텍처
- [데이터베이스 스키마](./safetrip-document/03-database/database-readme.md) - 데이터베이스 스키마 설명
- [데이터베이스 설정](./safetrip-document/03-database/database-setup.md) - 데이터베이스 설정 가이드

### API 및 개발
- [API 가이드](./safetrip-document/05-api/api-guide.md) - SafeTrip API 사용 가이드
- [외부 통합](./safetrip-document/02-architecture/external-integrations.md) - 외부 서비스 통합 가이드
- [Google Maps API 설정](./safetrip-document/07-guides/google-maps-api-setup.md) - Google Maps API 설정

### 이벤트 및 알림
- [이벤트 로그 타입](./safetrip-document/06-events/event-log-types.md) - 이벤트 로그 타입 정의
- [이벤트 알림 채널](./safetrip-document/06-events/event-notification-channels.md) - 이벤트 알림 채널 설정

## 기술 스택

### 모바일 앱
- **프레임워크**: Flutter
- **언어**: Dart
- **상태 관리**: Provider / Riverpod
- **지도**: Google Maps Flutter
- **실시간 통신**: Firebase Realtime Database

### 백엔드
- **런타임**: Node.js 18+
- **언어**: TypeScript
- **프레임워크**: Express.js
- **데이터베이스**: PostgreSQL (AWS RDS) + PostGIS
- **인증**: JWT
- **푸시 알림**: Firebase Cloud Messaging (FCM)

### 인프라
- **컨테이너**: Docker
- **컨테이너 레지스트리**: AWS ECR
- **컨테이너 오케스트레이션**: AWS ECS/Fargate
- **실시간 데이터베이스**: Firebase Realtime Database
- **클라우드 함수**: Firebase Cloud Functions


## 라이선스

[라이선스 정보 추가]

## 기여

[기여 가이드 추가]
