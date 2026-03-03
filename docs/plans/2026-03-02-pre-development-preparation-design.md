# SafeTrip 실제 개발 시작 전 사전 준비 설계

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:writing-plans to create the implementation plan.

**Goal:** Flutter PoC 수준의 코드를 프로덕션 품질로 전환하기 위한 기반을 완벽히 다진 후 실제 개발을 시작한다.

**Architecture:** Foundation-First — 기술 부채 해소 → 백엔드 완성 → 개발 환경 → 아키텍처 확정 → 디자인 시스템 순으로 진행. 모든 Phase 완료 후 Flutter 프로덕션 개발 시작.

**Tech Stack:** Node.js/TypeScript 백엔드, Flutter (Dart), PostgreSQL, Firebase (Auth/RTDB/Functions), Stitch MCP (디자인 생성)

---

## 현재 상태 갭 분석

### 완료 영역
- Master_docs: 44개 문서 (비즈니스 원칙 v5.1, DB v3.4.1, API 명세서 §3~§18)
- 백엔드: 19개 컨트롤러, UAT Phase 1~6 통과
- Firebase: 에뮬레이터 + 7명 테스트 유저 시드
- Flutter: 47개 화면 (PoC 수준)

### 갭 (사전 준비 대상)

| 카테고리 | 항목 | 우선도 |
|---------|------|:-----:|
| **버그** | `tb_country` 테이블 없음 → `/api/v1/countries` 500 에러 | P0 |
| **버그** | `GET /users/me` 라우트 순서 → `getMe` handler 도달 불가 (401) | P0 |
| **버그** | `PUT /users/me/fcm-token` → `authenticate` 미들웨어 없음 | P0 |
| **미완성** | 설정화면 일부 모달 미구현 (위치공유 설정, 가디언 과금 UI) | P1 |
| **미완성** | 온보딩 GoRouter 라우팅 조정 (deeplink 보존) | P1 |
| **인프라** | 프로덕션 API URL 미확정 (현재 TBD) | P1 |
| **인프라** | 환경별 설정 체계 없음 (dev/staging/prod) | P1 |
| **인프라** | CI/CD 없음 | P1 |
| **인프라** | Firebase Functions 상태 불명확 | P1 |
| **아키텍처** | Flutter 상태관리 방식 미확정 | P1 |
| **디자인** | 디자인 시스템/Figma 없음 | P1 |

---

## Foundation-First 5단계 로드맵

### Phase 1 — Critical Bug Fixes (백엔드 버그 수정)

**목표:** 알려진 모든 백엔드 버그 수정

**작업 항목:**
1. `tb_country` 테이블 migration SQL 작성 + 국가 데이터 시드
2. `GET /users/me` 라우트 순서 수정 (`/me`를 `/:userId` 앞에 등록)
3. `PUT /users/me/fcm-token` → `authenticate` 미들웨어 추가
4. 설정화면 미완성 모달 구현 (위치공유 설정, 가디언 과금 UI 포함)
5. 온보딩 GoRouter 라우팅 조정 (deeplink 보존, 분기 로직)

**완료 기준:**
- UAT Phase 1~6 재통과
- `/api/v1/countries` 200 OK 응답
- `GET /users/me` 200 OK 응답 (Firebase ID Token 포함 시)

---

### Phase 2 — Backend Completion (백엔드 완성)

**목표:** 백엔드 기능 완성 + 테스트 커버리지 확인

**작업 항목:**
1. `/api/v1/countries` 엔드포인트 정상화 확인 (Phase 1 완료 후)
2. `safetrip-firebase-function/` 검토:
   - 어떤 Functions가 구현되어 있는지 인벤토리
   - 비즈니스 원칙에서 요구하는 Functions 목록과 대조
   - 미구현 Functions 파악 + 구현 계획
3. 백엔드 테스트 커버리지 확인:
   - `safetrip-server-api/src/__tests__/` 현황 파악
   - 커버리지 낮은 핵심 컨트롤러 테스트 추가

**완료 기준:**
- 모든 엔드포인트 정상 동작
- Firebase Functions 인벤토리 문서화 완료
- 테스트 pass

---

### Phase 3 — Development Environment (개발 환경 설정)

**목표:** dev/staging/prod 환경 분리 + CI/CD 기본 파이프라인

**작업 항목:**

**백엔드 환경 설정:**
```
safetrip-server-api/
├── .env.development   (Firebase Emulator, localhost DB)
├── .env.staging       (Firebase Staging 프로젝트)
└── .env.production    (Firebase Production, 프로덕션 DB)
```

**Flutter 환경 설정:**
```
safetrip-mobile/
├── env/
│   ├── .env.development
│   ├── .env.staging
│   └── .env.production
```
빌드: `flutter build apk --dart-define-from-file=env/.env.staging`

**CI/CD (GitHub Actions):**
```
.github/workflows/
├── backend-test.yml    (PR 시 백엔드 테스트 자동 실행)
└── flutter-analyze.yml (PR 시 flutter analyze 실행)
```

**프로덕션 URL 결정:**
- 클라우드 서비스 선택 (AWS/GCP/Railway 등)
- URL 결정 후 `.env.production` 에 기록

**완료 기준:**
- `flutter build apk --dart-define-from-file=env/.env.staging` 성공
- GitHub Actions CI 파이프라인 정상 동작
- 프로덕션 URL 확정 + 문서화

---

### Phase 4 — Flutter Architecture Planning (아키텍처 확정)

**목표:** 프로덕션 Flutter 코드의 구조적 기반 확정

**의사결정 항목:**

**1. 상태 관리 라이브러리**

| 옵션 | 장점 | 단점 |
|------|------|------|
| **Riverpod** (추천) | 역할/등급별 UI 분기 세밀하게 관리, 테스트 용이 | 학습 곡선 |
| Provider | 간단한 경우 충분 | 복잡한 의존성에 제한적 |
| BLoC | 이벤트 기반 명확 | 보일러플레이트 많음 |

**2. 폴더 구조 (Feature-based 권장)**
```
lib/
├── core/               (공통: 색상, 텍스트 스타일, 에러 처리)
├── features/
│   ├── auth/           (로그인, 프로필 설정)
│   ├── trip/           (여행 CRUD, 멤버 관리)
│   ├── guardian/       (가디언 관리, 메시지)
│   ├── location/       (지도, 위치 공유)
│   ├── chat/           (채팅탭)
│   ├── guide/          (안전가이드)
│   └── settings/       (설정)
├── shared/             (공통 위젯, 유틸리티)
└── router/             (GoRouter 설정)
```

**3. 네트워크 레이어**
- Dio + Retrofit 기반 API 클라이언트
- Firebase ID Token 자동 주입 인터셉터

**4. 코드 품질**
- `analysis_options.yaml` — very_good_analysis 기반 규칙
- `dart format` + `flutter analyze` CI 통합

**산출물:**
- `ARCHITECTURE.md` (의사결정 기록)
- `analysis_options.yaml` 업데이트
- Feature-based 폴더 구조 빈 스캐폴딩

**완료 기준:**
- `ARCHITECTURE.md` 작성 완료
- `flutter analyze` 오류 없음
- 폴더 구조 스캐폴딩 완료

---

### Phase 5 — Design System (Stitch 활용)

**목표:** Flutter 개발에 바로 활용 가능한 디자인 시스템 + 화면 목업

**작업 항목:**

**1. 디자인 토큰 확정**
```
컬러 팔레트:
  - Primary, Secondary, Accent
  - 역할별 색상 (캡틴/크루장/크루/가디언)
  - 시맨틱 색상 (SOS 빨강, 안전 초록, 경고 노랑)
  - 다크/라이트 모드 (1차: 라이트만)

타이포그래피:
  - H1~H4, Body1/2, Caption, Label
  - font family 결정

스페이싱:
  - 4px 기반 배수 시스템
  - 화면 패딩, 컴포넌트 간격
```

**2. Stitch로 생성할 주요 화면 (15개)**
```
온보딩 플로우 (4개):
  - 스플래시
  - 웰컴 (가치 슬라이드)
  - 역할 선택
  - 프로필 설정

여행 핵심 (4개):
  - 메인 지도 화면 (탭 포함)
  - 여행 생성/편집
  - 멤버 탭
  - 일정 탭

가디언 (2개):
  - 가디언 홈 대시보드
  - 멤버→가디언 메시지

설정/기타 (3개):
  - 설정 메인
  - 프로필 화면
  - 안전가이드

SOS (1개):
  - SOS 발동 화면

초대코드 (1개):
  - 초대코드 입력/공유
```

**3. DESIGN.md 작성**
- 컬러/타이포/스페이싱 토큰 정의
- 공통 컴포넌트 스펙 (버튼, 카드, 바텀시트)
- 역할별 UI 차이 명세
- 프라이버시 등급별 UI 차이 명세

**4. app_tokens.dart 업데이트**
- DESIGN.md 기반으로 Flutter 토큰 파일 갱신

**완료 기준:**
- `DESIGN.md` 완성 (비즈니스 원칙 v5.1 §04 프라이버시 등급별 UI 차이 반영)
- 15개 화면 목업 이미지 저장 (`docs/design/screens/`)
- `app_tokens.dart` v2 완성
- 역할별(캡틴/크루/가디언)/등급별 UI 차이 반영 확인

---

## Go/No-go 체크리스트

Flutter 프로덕션 개발 시작 전 모든 항목 ✅ 확인:

### 기술 기반
- [ ] `tb_country` 테이블 존재 + `/api/v1/countries` 200 OK
- [ ] `GET /users/me` 정상 동작 (401 없음)
- [ ] `PUT /users/me/fcm-token` 인증 정상
- [ ] 백엔드 전체 UAT 재통과
- [ ] Firebase Functions 인벤토리 완성

### 개발 환경
- [ ] 환경별 빌드 설정 완료 (`dart-define-from-file`)
- [ ] CI/CD 기본 파이프라인 동작 (테스트 + 분석)
- [ ] 프로덕션 URL 결정 + 문서화

### 아키텍처
- [ ] 상태 관리 라이브러리 결정 (`ARCHITECTURE.md`)
- [ ] Feature-based 폴더 구조 스캐폴딩 완료
- [ ] Lint 설정 완료 + `flutter analyze` clean

### 디자인
- [ ] `DESIGN.md` 완성 (토큰 정의)
- [ ] 15개 주요 화면 목업 완성
- [ ] 역할별/프라이버시 등급별 UI 차이 반영
- [ ] `app_tokens.dart` v2 적용

---

## 예상 산출물 목록

```
수정/신규 파일:
├── safetrip-server-api/
│   ├── migrations/[timestamp]-add-tb-country.sql
│   ├── src/routes/users.routes.ts           (라우트 순서 수정)
│   ├── src/__tests__/                       (테스트 추가)
│   └── .env.development/.env.staging/.env.production
│
├── safetrip-mobile/
│   ├── env/.env.development/staging/production
│   ├── lib/core/                            (신규 — 디자인 토큰)
│   ├── lib/features/                        (신규 — feature-based 구조)
│   ├── analysis_options.yaml                (업데이트)
│   └── app_tokens.dart                      (v2)
│
├── .github/workflows/
│   ├── backend-test.yml
│   └── flutter-analyze.yml
│
└── docs/
    ├── DESIGN.md                            (신규)
    ├── ARCHITECTURE.md                      (신규)
    └── design/screens/                      (신규 — Stitch 목업 15개)
```

---

## 참조 문서

- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- DB 설계: `Master_docs/07_T2_DB_설계_및_관계_v3_4.md`
- API 명세서: `Master_docs/35_T2_API_명세서.md` (INDEX), `36~38_T2_API_명세서_Part1~3.md`
- 화면구성원칙: `Master_docs/10_T2_화면구성원칙.md`
- 아키텍처: `Master_docs/08_T2_SafeTrip_아키텍처_구조_v3_0.md`
