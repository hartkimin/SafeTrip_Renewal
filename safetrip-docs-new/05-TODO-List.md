# SafeTrip 프로젝트 정합성 확보를 위한 할일 목록 (To-Do List)

## 📋 개요
`safetrip-document`에 포함된 검증된 데이터를 기준으로 현재 프로젝트(`safetrip-mobile`, `safetrip-server-api`)에서 누락되었거나 보강이 필요한 작업을 정리한 목록입니다.

---

## 🏗️ 1. 데이터베이스 및 엔티티 (DB & Entities)
- [x] **기본 결제 및 구독 엔티티 확인**: `Payment`, `Subscription` 엔티티는 구현됨.
- [x] **결제 관련 엔티티 보강**: `TB_REDEEM_CODE` (프로모션 코드) 엔티티 구현 완료.
- [x] **SOS 및 안전 체크인 엔티티 추가**: `TB_EMERGENCY_RECIPIENT` (수신자별 상태 관리), `TB_SAFETY_CHECKIN` (보호자 확인 응답) 엔티티 구현 완료.
- [x] **지오펜스 엔티티 확인**: `Geofence`, `PlannedRoute`, `RouteDeviation` 엔티티는 이미 존재함.
- [x] **지오펜스 및 경로 이탈 쿼리 최적화**: PostGIS의 `geometry` 컬럼 및 공간 인덱스 추가 완료. `ST_DWithin`, `ST_Distance`를 이용한 고성능 근접/이탈 감지 로직 구현 완료.

## 🚀 2. 백엔드 API (NestJS API)
- [x] **결제 모듈 (Payments Module) 고도화**: 실제 스토어(App Store, Play Store) 영수증 검증 로직 구조화 및 구독 기간 자동 만료/갱신 배치 작업(`@Cron`) 추가 완료.
- [x] **AI 모듈 (AI Module) 실질 기능 구현**: `AiService` 내에 안전 가이드 생성(LLM API 연동 구조 구현) 및 비정상 위치(갑작스런 경로 이탈, 속도 이상 등) 감지 엔진 구현 완료.
- [x] **오프라인 데이터 동기화 API**: `POST /api/v1/locations/sync` 벌크 업로드 API 구현 완료.
- [x] **FCM 토큰 무효화 관리**: 앱 삭제 또는 로그아웃 시 FCM 토큰을 서버에서 명확히 삭제하고, 유효하지 않은 토큰에 대한 에러 처리를 강화.

## 📱 3. 모바일 앱 (Flutter Mobile)
- [x] **프라이버시 설정 화면 구현**: `lib/screens/trip/screen_trip_privacy.dart` 구현 및 설정 메뉴 연동 완료. (위치 공유 ON/OFF, 공개 범위 설정 지원)
- [x] **가디언 과금 UI**: 유료 가디언(2명 초과) 등록 시 결제 유도 및 결제 완료 후 기능 활성화 처리. (모달 UI 및 가디언 관리 화면 연동 완료)
- [x] **오프라인 모드용 로컬 큐 (sqflite)**: `OfflineSyncService` 구현 및 `LocationService` 연동 완료. (위치 로그 벌크 업로드 지원)
- [x] **SOS 오프라인 큐**: `SOSService`에 `OfflineSyncService` 연동 완료. 네트워크 실패 시 로컬 저장 및 재시도 지원.
- [x] **애니메이션 및 UX 개선**: `marker_animation_manager.dart`를 확장하여 마커의 점프/숨쉬기 애니메이션 외에 좌표 변경 시 부드러운 이동(Interpolation) 효과 적용 완료.

## ⚙️ 4. 인프라 및 운영 (Infra & DevOps)
- [ ] **CI/CD 파이프라인 구축**: GitHub Actions를 이용한 `safetrip-server-api` (ECS/Fargate 등) 및 `safetrip-mobile` (App Center/TestFlight) 자동 배포.
- [ ] **모니터링 강화**: Sentry 또는 Firebase Crashlytics를 통한 에러 추적 고도화 및 CloudWatch 대시보드 구축.
- [ ] **Firebase Functions 최적화**: RTDB 트리거 기반의 PostgreSQL 동기화 로직의 레이턴시를 최소화하기 위한 성능 튜닝.

---

## 🛠️ 우선순위 가이드
1. **P1 (High)**: `sqflite` 기반 오프라인 동기화, SOS/안전 체크인 엔티티 추가, 결제 실구현.
2. **P2 (Medium)**: AI 실질 기능 연동, 프라이버시 설정 UI, 지오펜스 쿼리 최적화.
3. **P3 (Low)**: CI/CD 고도화, 다국어 지원 보강, 애니메이션 디테일 개선.

---

**업데이트 일자**: 2026-03-04  
**버전**: 1.1 (코드베이스 실사 결과 반영)

