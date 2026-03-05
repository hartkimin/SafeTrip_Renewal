# SafeTrip API 명세 요약 (New)

## 📋 개요
SafeTrip 백엔드 서버는 NestJS 기반의 RESTful API를 제공합니다. 모든 엔드포인트는 기본적으로 `v1/` 접두사를 사용하며, 인증은 Firebase ID Token을 기반으로 합니다.

### 인증 방식
- **Firebase ID Token**: 클라이언트에서 Firebase SDK를 통해 발급받은 토큰을 `Authorization: Bearer <ID_TOKEN>` 헤더에 포함하여 전송합니다.

---

## 🛤️ 주요 엔드포인트 목록

### 1. 인증 및 사용자 (Authentication & Users)
- `POST /auth/firebase-verify`: Firebase ID Token 검증 및 사용자 동기화.
- `GET /users/me`: 현재 로그인한 사용자의 프로필 조회.
- `PUT /users/me/fcm-token`: FCM 푸시 토큰 등록 및 업데이트.

### 2. 위치 및 이동 (Locations & Movements)
- `POST /locations`: 실시간 위치 업로드 (PostgreSQL 영구 저장용).
- `GET /locations/latest`: 특정 사용자의 마지막 위치 조회.
- `GET /locations/history`: 위치 이동 이력 조회.
- `GET /locations/users/{userId}/movement-sessions`: 이동 세션(시작~종료) 요약 정보 조회.

### 3. 그룹 및 여행 (Groups & Trips)
- `POST /groups/join/{invite_code}`: 초대 코드로 그룹 참여.
- `GET /groups/{group_id}/members`: 그룹 내 멤버 목록 및 실시간 상태 조회.
- `GET /groups/{group_id}/schedules`: 그룹 여행 일정 목록 조회.
- `POST /groups/{group_id}/geofences`: 새로운 지오펜스 구역 생성.

### 4. 안전 및 긴급 (Safety & Emergency)
- `POST /events`: 통합 이벤트 로그 기록 (지오펜스 진입/이탈, 배터리 경고 등).
- `GET /guides/{countryCode}`: 특정 국가의 안전 가이드 및 긴급 연락처 조회.
- `GET /mofa/risk`: 외교부 여행 경보 정보 조회.

### 5. 기타 (Guides & System)
- `GET /health`: 서버 상태 및 DB/Firebase 연결 확인.
- `GET /exchange-rate`: 국가별 실시간 환율 정보 조회.

---

## 🛠️ 상세 명세 확인
전체 OpenAPI 명세(YAML)는 다음 경로에서 확인할 수 있습니다.
- `safetrip-document/05-api/api-specification.yaml`
- `safetrip-server-api/swagger.json` (Swagger UI: http://localhost:3001/api-docs)

---

**작성일**: 2026-03-04  
**버전**: 1.0 (NestJS 최적화 반영)
