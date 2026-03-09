# Safety Guide Tab Design — Phase 1

| 항목 | 내용 |
|------|------|
| **문서 ID** | DESIGN-2026-03-07-SAFETY-GUIDE |
| **작성일** | 2026-03-07 |
| **기준 문서** | `21_T3_안전가이드_원칙.md` v1.1 |
| **구현 범위** | Phase 1 전체 (P0 + P1) |
| **아키텍처** | 레이어드 캐시 (서버 PostgreSQL + 클라이언트 SQLite) |

---

## 1. 구현 범위

### Phase 1 포함 항목

| 우선순위 | 항목 | 비고 |
|---------|------|------|
| **P0** | 6개 서브탭 기본 UI 표시 | 런칭 필수 |
| **P0** | MOFA API 연동 (6개 엔드포인트) | 런칭 필수 |
| **P0** | 원터치 긴급전화 버튼 | 안전 직결 |
| **P0** | 오프라인 긴급연락처 캐시 | 안전 직결 |
| **P1** | 컨텍스트 기반 국가 자동 선택 | 핵심 UX |
| **P1** | API 캐시 전략 (24시간 TTL, 폴백) | 안정성 |
| **P1** | API 장애 시 폴백 UX | 안정성 |

### Phase 1 제외 항목 (Phase 2/3)

- 여행 유형별 강조 서브탭 (P1, Phase 2)
- AI 안전 어시스턴트 (P2, Phase 3)
- 자동 경보 알림 연동 (P2, Phase 2)
- 국가별 안전 점수 대시보드 (P3)
- 맞춤 보험 연동 (P3)

---

## 2. 설계 원칙 매핑

| 원칙 | 구현 방법 |
|------|----------|
| **S1 컨텍스트 우선** | `CountryContextProvider`가 active 여행/가디언/GPS 순으로 국가 자동 선택 |
| **S2 MOFA 신뢰성** | Guides 서비스가 MOFA 서비스를 단일 소스로 사용. 데이터 편집 금지 |
| **S3 오프라인 안정성** | 2단 캐시: 서버 PostgreSQL (24h TTL) + 클라이언트 SQLite. 긴급연락처 영구 캐시 |
| **S4 여행 유형 적응** | Phase 2로 이관 |
| **S5 역할 무관 동등 접근** | 안전가이드 API에 권한 체크 없음. 인증된 모든 사용자 접근 가능 |
| **S6 즉시 행동** | 원터치 전화 버튼 (56dp, 빨강). 탭 진입 1초 내 긴급연락처 노출 |

---

## 3. 백엔드 아키텍처

### 3.1 DB 마이그레이션

```sql
-- 07-schema-safety-guide.sql

CREATE TABLE tb_safety_guide_cache (
    id              BIGSERIAL PRIMARY KEY,
    country_code    VARCHAR(3)   NOT NULL,
    data_type       VARCHAR(30)  NOT NULL,
    content         JSONB        NOT NULL,
    fetched_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_cache_country_type UNIQUE (country_code, data_type)
);

CREATE INDEX idx_safety_cache_country ON tb_safety_guide_cache (country_code);
CREATE INDEX idx_safety_cache_expires ON tb_safety_guide_cache (expires_at);

CREATE TABLE tb_emergency_contact (
    id              BIGSERIAL PRIMARY KEY,
    country_code    VARCHAR(3)   NOT NULL,
    contact_type    VARCHAR(20)  NOT NULL,
    phone_number    VARCHAR(30)  NOT NULL,
    description_ko  VARCHAR(100),
    is_24h          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_emergency_contact_country ON tb_emergency_contact (country_code);

-- 시드 데이터: 영사콜센터
INSERT INTO tb_emergency_contact (country_code, contact_type, phone_number, description_ko, is_24h)
VALUES ('ALL', 'consulate_call_center', '+82-2-3210-0404', '영사콜센터 (24시간)', TRUE);
```

### 3.2 Guides 모듈 구조

```
guides/
├── guides.module.ts
├── guides.controller.ts
├── guides.service.ts
├── entities/
│   ├── safety-guide-cache.entity.ts
│   └── emergency-contact.entity.ts
└── dto/
    ├── guide-overview.dto.ts
    ├── guide-safety.dto.ts
    ├── guide-medical.dto.ts
    ├── guide-entry.dto.ts
    ├── guide-emergency.dto.ts
    └── guide-local-life.dto.ts
```

### 3.3 API 엔드포인트

| 메서드 | 경로 | 용도 |
|--------|------|------|
| `GET` | `/api/v1/guides/:countryCode` | 전체 6탭 통합 응답 |
| `GET` | `/api/v1/guides/:countryCode/overview` | 개요 |
| `GET` | `/api/v1/guides/:countryCode/safety` | 안전 |
| `GET` | `/api/v1/guides/:countryCode/medical` | 의료 |
| `GET` | `/api/v1/guides/:countryCode/entry` | 입국 |
| `GET` | `/api/v1/guides/:countryCode/emergency` | 긴급연락 |
| `GET` | `/api/v1/guides/:countryCode/local-life` | 현지생활 |

### 3.4 캐시 흐름

```
요청 수신 → tb_safety_guide_cache 조회
    │
    ├── 캐시 히트 (expires_at > now()) → 즉시 반환
    │
    └── 캐시 미스/만료 → MOFA 서비스 호출
            │
            ├── 성공 → 캐시 갱신 (UPSERT) → 반환
            │
            └── 실패 → 만료 캐시 반환 + stale:true 플래그
                    │
                    └── 캐시도 없음 → 하드코딩 기본값 (영사콜센터) + 에러 배너
```

### 3.5 통합 응답 포맷

```json
{
  "data": {
    "overview": { ... },
    "safety": { ... },
    "medical": { ... },
    "entry": { ... },
    "emergency": { ... },
    "localLife": { ... }
  },
  "meta": {
    "countryCode": "JPN",
    "cached": true,
    "stale": false,
    "fetchedAt": "2026-03-07T10:00:00Z",
    "expiresAt": "2026-03-08T10:00:00Z"
  }
}
```

---

## 4. 모바일 아키텍처

### 4.1 디렉토리 구조

```
lib/features/safety_guide/
├── data/
│   ├── safety_guide_repository.dart
│   ├── safety_guide_api_service.dart
│   └── safety_guide_cache_service.dart
├── models/
│   ├── guide_overview.dart
│   ├── guide_safety.dart
│   ├── guide_medical.dart
│   ├── guide_entry.dart
│   ├── guide_emergency.dart
│   └── guide_local_life.dart
├── providers/
│   ├── safety_guide_providers.dart
│   └── country_context_provider.dart
├── presentation/
│   ├── safety_guide_bottom_sheet.dart
│   ├── tabs/
│   │   ├── overview_tab.dart
│   │   ├── safety_tab.dart
│   │   ├── medical_tab.dart
│   │   ├── entry_tab.dart
│   │   ├── emergency_tab.dart
│   │   └── local_life_tab.dart
│   └── widgets/
│       ├── country_selector_widget.dart
│       ├── travel_alert_badge.dart
│       ├── emergency_call_button.dart
│       ├── offline_banner.dart
│       └── stale_data_banner.dart
```

### 4.2 컨텍스트 국가 자동 선택

```
[1] Active 여행 확인 → trip.country_code
[2] 가디언 → 연결 멤버의 여행 목적지
[3] GPS 허용 → reverse geocoding → 국가 코드
[4] 모두 해당 없음 → 자유 탐색 (검색 UI)
[5] 수동 변경 → 세션 종료 시 컨텍스트 복원
```

### 4.3 오프라인 캐시

| 우선순위 | 데이터 | TTL |
|---------|-------|-----|
| 1순위 | 긴급연락처 | 영구 |
| 2순위 | 여행경보 단계 | 24h |
| 3순위 | 대사관 위치 | 24h |
| 4순위 | 응급 가이드 | 24h |
| 5순위 | 국가 기본 정보 | 24h |

### 4.4 원터치 긴급전화 버튼

- 높이: 최소 56dp
- 색상: `#E53935` (빨강) + 흰 전화기 아이콘
- 동작: `url_launcher` → `tel:` URI → 즉시 다이얼
- 전화 권한 미허용: `permission_handler` → 시스템 다이얼로그
- 오프라인: SQLite 캐시 번호 사용

---

## 5. 에러 처리 및 엣지케이스

### 5.1 API 에러 (문서 §6.1)

| 상황 | 처리 |
|------|------|
| MOFA timeout/500 | 캐시 폴백 + 황색 배너 |
| 캐시 없음 + API 오류 | 하드코딩 영사콜센터 + 빨간 배너 |
| 국가 미지원 | "정보 준비 중" + 영사콜센터 |
| 파싱 오류 | 섹션별 "정보를 불러오지 못했습니다." |

### 5.2 컨텍스트 엣지케이스 (문서 §6.2)

| 상황 | 처리 |
|------|------|
| 복수 active 여행 | 시작일 최근 여행 선택 |
| 가디언 복수 멤버 | 최근 active 여행 멤버 기준 |
| 국가 코드 없음 | 자유 탐색 + 토스트 |
| 여행 종료 | 3시간 유지 → 자유 탐색 |
| 수동 변경 중 여행 시작 | 즉시 컨텍스트 복원 |

### 5.3 긴급전화 엣지케이스 (문서 §6.3)

| 상황 | 처리 |
|------|------|
| 전화 권한 미허용 | 권한 요청 다이얼로그 |
| 오프라인 | 캐시 번호로 발신 |
| 번호 미등록 | 영사콜센터 대체 |

### 5.4 여행금지 경고 (4단계)

`travel_alert_level == 4` → 상단 빨간 배너 표시

---

## 6. 기존 코드 충돌 분석

| 기존 코드 | 충돌 여부 | 대응 |
|----------|----------|------|
| `bottom_sheet_4_guide.dart` | 대체 필요 | 새 `safety_guide_bottom_sheet.dart`로 교체 |
| `guides.controller.ts` (스켈레톤) | 확장 | 기존 3 엔드포인트 → 7 엔드포인트로 확장 |
| `guides.service.ts` (스켈레톤) | 확장 | MOFA 주입 + 캐시 로직 추가 |
| `mofa.service.ts` | 유지 | 내부 데이터 소스로만 사용, 공개 API 유지 |
| `travel_guide_service.dart` (스텁) | 대체 | `safety_guide_api_service.dart`로 교체 |
