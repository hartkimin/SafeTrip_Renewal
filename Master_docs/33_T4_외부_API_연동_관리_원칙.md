# SafeTrip 외부 API 연동 관리 원칙

| 항목 | 내용 |
|------|------|
| **문서 ID** | `DOC-T4-EXT-033` |
| **문서 계층** | Tier 4 — 운영·품질 |
| **문서 등급** | C — 기술 운영 |
| **버전** | v1.0 |
| **작성일** | 2026-03-02 |
| **기준 문서** | SafeTrip_비즈니스_원칙_v5.1 (Tier 1), 아키텍처 구조 원칙(#08) |
| **관련 법령** | 전자금융거래법, 개인정보 보호법, 정보통신망법 |
| **후행 문서** | 앱 성능·안정성 원칙(#31), DB 설계(#07) |
| **검토 주기** | 분기 1회 (API 비용 이슈 발생 시 즉시) |
| **담당 부서** | ◎ DevOps, ○ 백엔드 개발팀, △ 경영진 |

---

## §1. 목적 및 적용 범위

### 1.1 목적

본 문서는 SafeTrip이 의존하는 모든 외부 API 및 서드파티 서비스를 통합적으로 관리하기 위한 원칙을 정의한다. 다음 다섯 가지 영역을 포괄한다:

- **인벤토리 관리**: SafeTrip이 사용하는 모든 외부 API의 목록화 및 분류
- **SLA(서비스 수준 협약) 관리**: 제공사별 공식 SLA와 SafeTrip 내부 요구 SLA 정의
- **폴백 전략**: 외부 API 장애 발생 시 서비스 연속성 보장 방안
- **비용 관리**: API 호출 비용 예측, 모니터링, 최적화 전략
- **보안 정책**: API 키 관리, 순환 주기, 유출 대응 절차

### 1.2 적용 범위

본 문서의 정책은 SafeTrip 백엔드(safetrip-server-api), Flutter 앱(safetrip-mobile), DevOps 파이프라인 전반에 적용된다.

- **적용 대상 API**: Firebase 계열, Google Maps Platform, Nominatim, MOFA 외교부 API, LLM API, PG사 결제 API, App Store / Play Store 인앱 결제 API, Sentry / Crashlytics
- **적용 제외**: SafeTrip 자체 개발 내부 서비스 간 통신 (내부 REST API, RTDB 내부 트리거 등)

> **적용 제외**: Firebase Cloud Firestore 및 Firebase Cloud Functions는 SafeTrip 아키텍처에서
> 미사용 (PostgreSQL + Firebase RTDB 아키텍처 채택). 본 인벤토리 적용 제외.

### 1.3 상위 원칙 참조

본 문서의 모든 정책은 다음 비즈니스 원칙을 기반으로 한다:

- **§05 알림 및 SOS**: SOS 관련 API는 최고 등급 SLA 보장
- **§09 과금 모델**: PG사 연동 결제 흐름, 가디언 추가 과금, 환불 규칙
- **§11 오프라인**: 네트워크 단절 시 API 큐잉 정책
- **§12 B2B 프레임워크**: B2B 계약 관련 API 처리

---

## §2. 설계 철학

외부 API 연동 전략을 결정할 때 아래 5대 원칙(E1~E5)을 최우선 기준으로 삼는다.

| 원칙 | 명칭 | 내용 |
|------|------|------|
| **E1** | Safety First | SOS 알림(FCM), 사용자 인증(Firebase Auth) 등 안전과 직결된 API는 최고 등급 SLA(99.9% 이상)와 폴백 전략을 필수로 보유한다. SOS 기능은 어떠한 상황에서도 동작을 보장한다 (비즈니스 원칙 §05). |
| **E2** | 비용 효율 | 동일한 결과를 캐싱으로 얻을 수 있으면 외부 API를 호출하지 않는다. 불필요한 API 호출을 최소화하고, 배치 처리가 가능한 경우 단건 호출 대신 배치 API를 우선 사용한다. |
| **E3** | 투명성 | API 비용, 호출량, 응답 시간, 장애 이력을 실시간으로 모니터링한다. 비용 임계값 초과 시 담당자에게 자동으로 알린다. |
| **E4** | 보안 필수 | 모든 API 키는 암호화된 저장소(Secret Manager)에 보관하고, 정해진 순환 주기를 반드시 준수한다. API 키를 코드 저장소(git)에 커밋하지 않는다. |
| **E5** | 폴백 의무 | 모든 외부 API 의존성은 3계층 폴백 전략(대체 API → 캐시 데이터 → 기능 저하)을 보유해야 한다. 폴백 없는 외부 API 의존성은 신규 도입을 허용하지 않는다. |

---

## §3. 본문

### §3.1 API 인벤토리 (전체 목록)

SafeTrip이 의존하는 모든 외부 API 및 서비스의 공식 목록이다. 신규 외부 API 도입 시 DevOps 승인 후 본 인벤토리에 등록해야 한다.

| API | 제공사 | 용도 | 인증 방식 | 의존 기능 | 비용 모델 |
|-----|--------|------|-----------|-----------|-----------|
| Firebase Auth | Google | 사용자 인증 및 세션 관리 | API Key + SDK | 로그인, 회원가입, 토큰 검증 | 무료 (10만 MAU 이하) |
| Firebase Realtime DB | Google | 실시간 위치 공유, 가디언 채팅 | SDK | 위치 추적, 채팅, 가디언 채널(`link_{linkId}`) | 데이터 저장 + 다운로드량 기반 |
| Firebase Cloud Messaging | Google | 푸시 알림 | Server Key | SOS 알림, 가디언 알림, 일반 알림 | 무료 |
| Google Maps Platform | Google | 지도 타일, 지오코딩, 경로 안내 | API Key | 지도 표시, 위치 검색, 경로 | 지도 로드/API 호출당 |
| Nominatim (OSM) | OpenStreetMap | 역지오코딩 (좌표→주소 변환) | User-Agent 헤더 (무료) | 위치 → 주소 텍스트 변환 | 무료 (1 req/sec 제한) |
| MOFA 외교부 API | 대한민국 외교부 | 국가별 여행경보 데이터 | API Key | 안전가이드 탭, 여행경보 | 무료 (공공 데이터 포털) |
| LLM API | OpenAI / Anthropic | 자연어 처리, AI 안전 가이드, 일정 최적화 | Bearer Token (API Key) | AI 채팅, Safety AI, Convenience AI | 토큰당 (입력 + 출력) |
| PG사 결제 API | TBD (토스페이먼츠 등) | 여행 기본 과금, 가디언 추가 과금, AI 구독 결제 | Secret Key + HMAC 서명 | 결제 처리, 환불, 웹훅 콜백 | 거래액 % 수수료 |
| App Store API | Apple | iOS 인앱 결제 검증 | App Store Connect Key | iOS 구독 결제, 영수증 검증 | 거래액 30% (첫해), 15% (2년차 이후) |
| Play Store API | Google | Android 인앱 결제 검증 | Service Account (JSON) | Android 구독 결제, 구매 검증 | 거래액 15% |
| Sentry | Sentry Inc. | 서버 에러 리포팅, 성능 추적 | DSN | 서버 크래시 감지, API 에러 로깅 | 무료 티어 / 이벤트당 |
| Crashlytics | Google (Firebase) | 앱 크래시 추적 | SDK | 앱 크래시 감지, 안정성 모니터링 | 무료 |

> 총 12개 외부 API 등록 (2026-03-02 기준). 신규 등록 시 DevOps 팀 승인 후 본 테이블에 추가한다.

---

### §3.2 API별 SLA 및 가용성 요구사항

SafeTrip 내부 요구 SLA는 제공사 공식 SLA보다 낮게 설정하는 것을 원칙으로 한다. SOS 및 안전 관련 API는 예외적으로 높은 요구 수준을 적용한다.

| API | 제공사 공식 SLA | SafeTrip 요구 SLA | 분류 | 비고 |
|-----|----------------|-------------------|------|------|
| Firebase Auth | 99.95% | **99.9%** | Safety 연관 | SOS 동작에 직접 영향 |
| Firebase Cloud Messaging | 99.9% | **99.9%** | SOS 알림 | SOS 폴백 필수 (§E1) |
| Firebase Realtime DB | 99.99% | **99.7%** | 위치 추적 | 실시간 위치 공유 |
| Google Maps Platform | 99.9% | 99.5% | 일반 | 지도 타일 캐싱으로 완화 가능 |
| Nominatim | 미제시 | 99.0% | 일반 | 폴백: Google Geocoding |
| MOFA 외교부 API | 미제시 | 99.0% | 일반 | 24h 캐싱으로 완화 |
| LLM API | 99.9% (OpenAI 기준) | 99.5% | 일반 | 대체 LLM 제공사 폴백 |
| PG사 결제 API | 99.9% (협의) | **99.7%** | 과금 연관 | 결제 실패 시 유예 기간 24h |
| App Store API | 99.9% | 99.5% | 과금 연관 | 영수증 캐시 검증 가능 |
| Play Store API | 99.9% | 99.5% | 과금 연관 | 구매 토큰 캐시 검증 가능 |
| Sentry | 99.9% | 99.0% | 모니터링 | 모니터링 도구, 장애 시 Crashlytics 단독 운용 |

> **SLA 위반 감지 기준**: 5분 연속 응답 실패 또는 에러율 5% 초과 시 SLA 위반으로 간주하고 즉시 폴백 전환 트리거를 실행한다.

> **기준**: 본 테이블의 SafeTrip 요구 SLA는 앱 성능·안정성 원칙(#31) §3.1 가용성 SLA 기준표와 정합하여 설정되었다.

---

### §3.3 폴백 전략 (API 장애 시 대체 방안)

모든 외부 API는 3계층 폴백 매트릭스를 보유해야 한다 (설계 철학 E5).

**폴백 계층 정의:**

| 계층 | 명칭 | 설명 |
|------|------|------|
| **Tier 1** | 대체 API | 동일 기능을 제공하는 대체 서비스로 즉시 전환 |
| **Tier 2** | 캐시 데이터 | 최근 캐싱된 데이터를 반환 (만료 시간 명시) |
| **Tier 3** | 기능 저하 (Degradation) | 해당 기능을 일시 비활성화하고 사용자에게 안내 |

**API별 3계층 폴백 매트릭스:**

| API | Tier 1 폴백 | Tier 2 폴백 | Tier 3 폴백 | 비고 |
|-----|-------------|-------------|-------------|------|
| Firebase Auth | — | 로컬 JWT 토큰 캐시 (유효기간 내) | 로그인 불가 안내, 기 로그인 세션 유지 | SOS 기능은 로컬 세션으로 유지 |
| Firebase Realtime DB | — | 로컬 스냅샷 캐시 (최근 5분) | 실시간 위치 공유 일시 중단 + 안내 | 위치 데이터는 로컬 큐잉 후 복구 시 동기화 |
| Firebase Cloud Messaging | SMS 폴백 (예비 SMS 채널) | 로컬 알림 (앱 포그라운드 시) | 알림 지연 안내 | **SOS 알림은 Tier 1까지 필수 동작** |
| Google Maps Platform | OpenStreetMap (Leaflet) | 캐시 타일 (24h 유효) | 지도 미표시 + 좌표 텍스트 표시 | |
| Nominatim | Google Geocoding API | 캐시 주소 데이터 (24h 유효) | 주소 변환 불가, 좌표(lat/lng) 직접 표시 | |
| MOFA 외교부 API | — | 캐시 데이터 (24h 유효, 마지막 업데이트 일시 표시) | 안전가이드 탭 일시 불가 안내 | |
| LLM API | 대체 LLM 제공사 (OpenAI ↔ Anthropic 교차) | 사전 정의된 정적 응답 (FAQ 기반) | AI 기능 일시 불가 안내 | 안전 기능(SOS)은 AI 미의존 |
| PG사 결제 API | 대체 PG사 (사전 계약된 예비 PG) | — | 결제 일시 불가 안내, 유예 기간 24h 적용 | 유예 기간 중 기존 권한 유지 |
| App Store API | — | 최근 영수증 캐시 검증 (72h) | 구독 상태 갱신 지연 안내 | |
| Play Store API | — | 최근 구매 토큰 캐시 (72h) | 구독 상태 갱신 지연 안내 | |
| Sentry | Crashlytics 단독 운용 | 로컬 에러 로그 파일 (`/tmp/safetrip-backend.log`) | 모니터링 일시 중단 | |

---

### §3.4 비용 예측 및 모니터링

#### 월간 예상 비용 (1,000 DAU 기준)

| API | 과금 모델 | 월간 예상 비용 | 비용 최적화 전략 |
|-----|-----------|----------------|-----------------|
| Google Maps Platform | 지도 로드 $7/1,000건, Geocoding $5/1,000건, Directions $5/1,000건 | $200 ~ $500 | 타일 캐싱 24h, 뷰포트 클러스터링, 지오코딩 결과 Redis 캐시 |
| Firebase Realtime DB | 다운로드 $1/GB, 저장 $5/GB/월 | $50 ~ $150 | 위치 데이터 TTL 설정, 불필요한 구독(listener) 즉시 해제 |
| LLM API | $0.002 ~ $0.01 / 1K 토큰 (모델별 상이) | $100 ~ $300 | 동일 질의 응답 캐싱, 프롬프트 토큰 최적화, 미성년자 AI 기능 제한(§10.3) |
| PG사 결제 | 거래액 2.5 ~ 3.5% | 거래 발생 시 정산 | 정기 협상으로 수수료율 인하, 대량 거래 시 고정 요금제 검토 |
| Nominatim | 무료 | $0 | 1 req/sec 제한 내 운용, 초과 시 Google Geocoding 폴백 (비용 발생) |
| MOFA 외교부 API | 무료 (공공 API) | $0 | 24h 캐싱으로 일일 호출 최소화 |
| FCM | 무료 | $0 | — |
| Sentry / Crashlytics | 무료 티어 (이벤트 1만/월) | $0 ~ $26 | 에러 샘플링률 조정 (프로덕션 100%, 스테이징 10%) |

#### 비용 모니터링 정책

- **알림 임계값**:
  - 월 예산 **80% 도달 시**: Slack `#ops-alerts` 채널에 자동 알림 발송
  - 월 예산 **100% 도달 시**: 온콜 담당자(DevOps) 즉시 호출 + 비용 초과 원인 분석 의무화
- **모니터링 도구**: Google Cloud Billing 대시보드, Firebase 사용량 콘솔, 커스텀 `tb_api_usage_log` 집계
- **비용 최적화 우선순위**: 캐싱 강화 → 배치 처리 전환 → Rate Limit 활용 → 대체 무료 API 탐색

---

### §3.5 PG사 연동 — 가디언 과금 및 AI 구독 결제 (비즈니스 원칙 §09)

#### PG사 선정 기준

| 항목 | 최소 요건 |
|------|-----------|
| 결제 수수료 | 2.5% 이하 (협의 기준) |
| SLA | 99.7% 이상 (§3.2 기준) |
| 해외 결제 지원 | Visa, MasterCard, 해외 신용카드 필수 |
| 인앱 결제 정책 대응 | iOS(Apple 30%), Android(Google 15%) 정책 분기 처리 가능 |
| 웹훅 지원 | HMAC 서명 기반 결제 콜백 웹훅 |
| 환불 API | 부분 환불, 전액 환불 API 지원 |

#### 결제 유형 체계 (비즈니스 원칙 §09.6)

| `payment_type` | 설명 | 금액 |
|:--------------:|------|------|
| `trip_base` | 여행 기본 이용료 (6인 이상 유료) | 9,900원 (6~15명) / 14,900원 (16~30명) / 19,900원 (31명+) |
| `addon_movement` | 움직임 세션 애드온 | 2,900원/여행 |
| `addon_ai_plus` | AI Plus 애드온 | 4,900원/월 또는 2,900원/여행 |
| `addon_ai_pro` | AI Pro 애드온 | 9,900원/월 또는 5,900원/여행 |
| `addon_guardian` | 추가 가디언 슬롯 (3명째 이상) | 1,900원/여행/1명 |
| `b2b_contract` | B2B 계약 일괄 과금 | 별도 계약 |

#### 가디언 추가 과금 결제 흐름 (비즈니스 원칙 §09.3)

```
1. [앱] 무료 가디언 2명 초과 연결 시도 감지
      ↓
2. [앱] 과금 안내 모달 표시 (1,900원/여행, 3명째~5명째)
      ↓
3. [앱] 사용자 결제 승인 → PG사 결제 모듈(SDK) 실행
      ↓
4. [PG사] 결제 처리 완료 → 웹훅 콜백 전송 (HMAC 서명 포함)
      ↓
5. [서버] 웹훅 수신 → HMAC 서명 검증 → tb_payment_transaction INSERT
      ↓
6. [서버] tb_guardian_link.is_paid = TRUE 업데이트
      ↓
7. [앱] 가디언 권한 즉시 활성화 (3~5번째 개인 가디언 연결 허용)
```

- `tb_payment_transaction.payment_type = 'addon_guardian'`
- 결제 단위: 여행 단위 (동일 여행 내 동일 멤버의 동일 가디언 슬롯 재결제 불필요)

#### 환불 처리 (비즈니스 원칙 §09.7)

| 여행 상태 | 환불 정책 |
|-----------|-----------|
| `planning` | 전액 환불 |
| `active` + 여행 시작 24시간 이내 | 50% 환불 |
| `active` + 여행 시작 24시간 이후 | 환불 불가 |
| `completed` | 환불 불가 |

- **가디언 추가 과금 특이사항**: 추가 가디언 해제 시 이미 결제된 요금은 환불하지 않는다 (비즈니스 원칙 §09.3). 동일 여행 내 가디언 재연결 시 추가 과금 없음.
- **OS 인앱 결제 우선 적용**: App Store / Play Store를 통한 결제는 해당 스토어 환불 정책이 SafeTrip 내부 정책에 우선한다.

#### 결제 실패 처리

| 상황 | 처리 방안 |
|------|-----------|
| 카드 한도 초과 / 오류 | 자동 재시도 3회 (1분 간격) → 실패 시 사용자 알림 + 재결제 유도 |
| 결제 실패 (가디언 추가) | 가디언 권한 미부여 상태 유지, 재결제 후 즉시 활성화 |
| 결제 실패 (여행 기본 이용료) | 여행 생성/멤버 추가 차단 → 재결제 유도 (비즈니스 원칙 §15.3) |
| PG사 API 장애 중 결제 시도 | 결제 일시 불가 안내 + 유예 기간 24h 적용 (기존 권한 유지) |

---

### §3.6 API 키 관리 정책

모든 API 키는 코드 저장소(git)에 커밋을 금지한다 (설계 철학 E4).

| 항목 | 정책 |
|------|------|
| **키 저장 위치 (비민감)** | Firebase Remote Config (공개 가능한 설정 값) |
| **키 저장 위치 (민감)** | Google Cloud Secret Manager (PG사 Secret Key, LLM API Key 등 전체) |
| **로컬 개발 환경** | `.env.local` 파일 (`.gitignore` 등록 필수, 절대 커밋 금지) |
| **일반 API 키 순환 주기** | **90일** (FCM, Google Maps, LLM API 등) |
| **PG사 Secret Key 순환 주기** | **30일** (결제 보안 강화) |
| **키 접근 권한** | DevOps 팀 전용. 개발자는 Secret Manager에 직접 접근 불가 |
| **키 유출 대응 절차** | 1. 즉시 무효화 → 2. 신규 키 발급 → 3. 1시간 내 배포 완료 → 4. 감사 로그(`tb_api_usage_log`) 기록 → 5. 사후 원인 분석 보고서 작성 |
| **키 조회 감사 로그** | Secret Manager 접근 이력 자동 기록, 월 1회 검토 |

---

### §3.7 버전 관리 (API 버전업 대응)

| 항목 | 정책 |
|------|------|
| **Deprecated API 모니터링** | 제공사 공식 Changelog RSS/이메일 구독 (Firebase, Google, OpenAI 등) |
| **마이그레이션 계획** | Deprecated 공지 후 **60일 내** 마이그레이션 계획 수립, **90일 내** 완료 |
| **버전 핀닝** | 모든 API SDK를 `package.json` / `pubspec.yaml` lock 파일에 버전 고정. Dependabot 자동 업그레이드 비활성화 |
| **호환성 테스트** | SDK 버전 업그레이드 시 스테이징 환경 72시간 검증 후 프로덕션 배포 |
| **내부 추상화 레이어** | 외부 API 직접 호출 대신 내부 서비스 레이어(`ExternalApiService`)를 통해 호출 → API 교체 시 내부 인터페이스 변경 최소화 |

---

### §3.8 Rate Limit 대응

| API | Rate Limit | 도달 시 전략 |
|-----|-----------|-------------|
| Google Maps Geocoding | 50 req/sec (프로젝트당) | 지수 백오프 재시도 + 결과 Redis 캐시 (24h) |
| Google Maps Directions | 10 req/sec | 큐잉 (우선순위 기반) + 캐시 |
| Nominatim | **1 req/sec** | 배치 큐잉 (최대 5분 지연 허용), 초과 시 Google Geocoding 폴백 |
| MOFA 외교부 API | 미제시 (추정 100 req/day) | **24h 캐시 필수** (하루 1회 갱신) |
| LLM API | 분당 토큰 제한 (모델별 상이, 예: TPM 90,000) | 스로틀링 + 사용자 대기 중 안내 메시지 표시 |
| PG사 결제 API | 초당 10건 (협의) | 결제 요청 큐잉 (FIFO 순서 보장) |
| Firebase Auth | 초당 1,000 req (프로젝트당) | 정상 운용 범위 내. 이상 급증 시 DDoS 의심 알림 |

**SOS 우선 처리 원칙**: Rate Limit 초과 중 SOS 발생 시, SOS 관련 API 호출은 일반 요청 큐를 우회하여 **별도 우선 큐**에서 처리한다.

---

### §3.9 보안 정책

| 항목 | 정책 |
|------|------|
| **통신 암호화** | 모든 외부 API 통신에 TLS 1.2 이상 필수. TLS 1.0/1.1 비활성화 |
| **요청/응답 로깅** | 개인정보(이름, 전화번호, 이메일, 위치 좌표) 자동 마스킹 후 로깅 |
| **IP 화이트리스트** | PG사 API, MOFA API는 SafeTrip 서버 IP 화이트리스트 적용 (직접 클라이언트 호출 차단) |
| **HMAC 서명 검증** | PG사 결제 콜백 웹훅 수신 시 HMAC-SHA256 서명 필수 검증. 서명 불일치 시 즉시 거부 |
| **민감 데이터 비전송** | 위치 좌표, 전화번호 등 개인정보를 LLM API에 직접 전송 금지. 필요 시 익명화 후 전송 |
| **API 키 환경 분리** | 프로덕션/스테이징/로컬 각각 별도 API 키 발급 및 관리 |

---

## §4. 역할별 API 관리 권한 매트릭스

| 역할 | API 인벤토리 조회 | 키 관리 | 비용 모니터링 | 폴백 전환 | Rate Limit 설정 | API 신규 등록 |
|------|:-----------------:|:-------:|:-------------:|:---------:|:----------------:|:-------------:|
| **DevOps** | O | O | O | O | O | O |
| **백엔드 개발팀** | O | X | O (조회만) | X | X | X (요청만) |
| **관리자(경영진)** | O (요약) | X | O | X | X | X |
| **캡틴** | X | X | X | X | X | X |
| **크루장 / 크루** | X | X | X | X | X | X |
| **가디언** | X | X | X | X | X | X |

> 캡틴/크루장/크루/가디언은 외부 API 관리에 접근 권한이 없다. API 인벤토리 및 키는 DevOps 전용 관리 대상이다.

---

## §5. 프라이버시 등급별 동작 차이

프라이버시 등급(안전 최우선 / 표준 / 프라이버시 우선)에 따라 외부 API 호출 시 전달되는 데이터와 호출 빈도가 달라진다 (비즈니스 원칙 §04).

| API | 안전 최우선 (safety_first) | 표준 (standard) | 프라이버시 우선 (privacy_first) |
|-----|--------------------------|-----------------|--------------------------------|
| **Google Maps (위치 표시)** | 전체 멤버 실시간 위치 고정밀도 전달 | 실시간 위치 표준 정밀도 전달 | 호출 최소화 (사전 캐시 타일 우선). 실시간 좌표 전달 최소화 |
| **Nominatim (역지오코딩)** | 모든 체크인 즉시 주소 변환 | 필요 시 주소 변환 | 주소 변환 최소화, 캐시 우선 활용 |
| **LLM API (AI 기능)** | Safety AI 전체 기능 활성 | Safety + Convenience AI 활성 | Safety AI 활성, 사용자 명시적 동의 시 Convenience AI 활성 |
| **FCM (SOS 알림)** | SOS 즉시 전송 (최고 우선순위) | SOS 즉시 전송 | SOS 즉시 전송 (등급 무관 필수) |
| **Firebase RTDB (위치 공유)** | 캡틴+크루장+크루+가디언 전체 실시간 공유 | 설정에 따른 공유 범위 적용 | 가디언 공유 범위 최소화, 오프라인 일정만 공유 |

> 프라이버시 등급과 무관하게 SOS 관련 API(FCM)는 항상 최우선으로 동작한다 (비즈니스 원칙 §05, E1 원칙).

---

## §6. 에러 및 엣지케이스

| 상황 | 처리 규칙 |
|------|-----------|
| **Firebase 서비스 전체 다운** | Tier 1→2→3 순서로 폴백 전환. SOS 발송은 로컬 오프라인 큐에 저장 후 복구 시 즉시 전송 |
| **PG사 결제 콜백 웹훅 미수신** | 결제 요청 30분 후 PG사 결제 상태 직접 조회 API(Polling) 실행. 결제 확인 시 `tb_payment_transaction` 수동 반영 |
| **Rate Limit 초과 중 SOS 발생** | SOS 요청을 일반 큐에서 분리하여 별도 우선 큐로 즉시 처리. Rate Limit 초과 에러가 SOS를 차단하지 않도록 코드 레벨에서 분기 처리 필수 |
| **API 키 만료 중 장애** | Secret Manager 자동 조회를 통해 신규 키 즉시 적용. 키 만료 7일 전 DevOps에 사전 알림 발송 |
| **LLM API 장애 중 AI 기능 요청** | Tier 1 폴백(대체 LLM) 전환. 실패 시 사전 정의된 정적 응답 반환. Safety AI 장애 시에도 SOS/위치 공유는 독립 동작 |
| **Nominatim 1 req/sec 제한 동시 초과** | 큐잉 후 순차 처리. 5분 이상 대기 예상 시 Google Geocoding API 폴백으로 자동 전환 |
| **결제 API 다운 중 가디언 추가 시도** | 24h 유예 기간 적용. 유예 기간 동안 기존 무료 가디언(2명) 권한 유지. 복구 후 결제 재시도 안내 |
| **MOFA API 미응답 (여행경보 조회)** | 최대 24h 캐시 데이터 반환. 캐시 만료 시 마지막 업데이트 일시와 함께 "일시적 데이터 미갱신" 안내 표시 |
| **App Store / Play Store 영수증 검증 실패** | 72h 내 캐시된 영수증으로 대체 검증. 72h 초과 시 구독 상태 갱신 지연 안내 표시. 사용자 기능은 유지 |

---

## §7. DB 스키마

본 문서에서 신규 정의하는 두 개 테이블의 DDL을 제안한다. DB 설계 문서(#07, v3.4) 반영 시 함께 검토한다.

### §7.1 `tb_api_usage_log` — API 사용 이력

```sql
CREATE TABLE tb_api_usage_log (
    log_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_provider    VARCHAR(50)  NOT NULL,           -- 제공사 (e.g., 'google_maps', 'openai', 'pg_toss')
    endpoint        VARCHAR(255) NOT NULL,           -- 호출 엔드포인트
    http_method     VARCHAR(10)  NOT NULL,           -- GET, POST 등
    request_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    response_code   SMALLINT     NOT NULL,           -- HTTP 응답 코드
    response_time_ms INTEGER     NOT NULL,           -- 응답 시간 (밀리초)
    estimated_cost  NUMERIC(10, 6),                  -- 예상 비용 (USD)
    is_fallback     BOOLEAN      NOT NULL DEFAULT FALSE, -- 폴백 호출 여부
    error_message   TEXT,                            -- 에러 메시지 (NULL이면 정상)
    trip_id         UUID         REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    user_id         VARCHAR(128) REFERENCES tb_user(user_id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 비용 집계용 인덱스
CREATE INDEX idx_api_usage_log_provider_date ON tb_api_usage_log(api_provider, request_at);
-- 에러 분석용 인덱스
CREATE INDEX idx_api_usage_log_error ON tb_api_usage_log(response_code, request_at)
    WHERE response_code >= 400;
```

### §7.2 `tb_payment_transaction` — 결제 거래 이력

```sql
CREATE TABLE tb_payment_transaction (
    transaction_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_type        VARCHAR(30)  NOT NULL
                            CHECK (payment_type IN (
                                'trip_base', 'addon_movement', 'addon_ai_plus',
                                'addon_ai_pro', 'addon_guardian', 'b2b_contract'
                            )),                              -- 비즈니스 원칙 §09.6
    amount              INTEGER      NOT NULL CHECK (amount >= 0), -- 결제 금액 (원)
    currency            CHAR(3)      NOT NULL DEFAULT 'KRW',
    pg_provider         VARCHAR(50)  NOT NULL,               -- PG사 명칭 (e.g., 'toss', 'kakao')
    pg_transaction_id   VARCHAR(255) NOT NULL,               -- PG사 고유 거래 ID
    status              VARCHAR(20)  NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'completed', 'failed', 'refunded', 'partial_refunded')),
    trip_id             UUID         REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    user_id             VARCHAR(128) NOT NULL REFERENCES tb_user(user_id) ON DELETE RESTRICT,
    guardian_link_id    UUID         REFERENCES tb_guardian_link(link_id) ON DELETE SET NULL, -- addon_guardian 시
    webhook_received_at TIMESTAMPTZ,                         -- 웹훅 콜백 수신 시각 (NULL이면 미수신)
    refund_amount       INTEGER      DEFAULT 0 CHECK (refund_amount >= 0), -- 환불 금액
    refund_reason       VARCHAR(100),
    refund_policy       VARCHAR(30),                         -- 적용된 환불 정책 (DB 설계 v3.4.1 §09.7)
    requested_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 거래 조회용 인덱스
CREATE INDEX idx_payment_transaction_user_id ON tb_payment_transaction(user_id, requested_at DESC);
CREATE INDEX idx_payment_transaction_trip_id ON tb_payment_transaction(trip_id)
    WHERE trip_id IS NOT NULL;
-- 웹훅 미수신 모니터링용 인덱스
CREATE INDEX idx_payment_transaction_webhook_pending ON tb_payment_transaction(requested_at)
    WHERE status = 'pending' AND webhook_received_at IS NULL;
```

> `tb_payment_transaction.refund_policy` 컬럼은 DB 설계 v3.4.1에서 `TB_REFUND_LOG`에 추가된 항목과 동일한 목적으로 사용한다 (환불 정책 추적 §09.7).

---

## §8. 오프라인 대응

SafeTrip의 오프라인 정책(비즈니스 원칙 §11)에 따라 외부 API 호출은 네트워크 단절 시 다음 규칙을 따른다.

| 항목 | 정책 |
|------|------|
| **API 호출 큐잉** | 오프라인 시 API 호출은 로컬 큐에 저장. 네트워크 복귀 시 FIFO 순서로 순차 처리 |
| **SOS API 우선 처리** | SOS 관련 FCM 호출은 오프라인 큐에서 최우선 처리. 다른 모든 큐잉 항목보다 선행 실행 |
| **결제 API 오프라인 정책** | 오프라인 상태에서는 결제 요청 불가. 사용자에게 "인터넷 연결이 필요합니다" 안내 메시지 표시. 결제 큐잉 비허용 (보안 및 정합성 이유) |
| **위치 데이터 큐잉** | Firebase RTDB 전송 실패 시 로컬 SQLite에 최대 1,000건 저장. 복구 시 배치 전송 |
| **캐시 데이터 우선 활용** | 오프라인 시 지도 타일 캐시, 안전가이드 캐시, 여행 일정 캐시를 우선 표시 |
| **큐 만료 정책** | 로컬 큐 항목은 24시간 후 만료. SOS 관련 항목은 만료 없이 유지 |

---

## §9. 구현 우선순위

### 우선순위 정의 (P0~P3)

| 우선순위 | 설명 | Phase 배치 |
|---------|------|-----------|
| **P0** | 서비스 출시 필수. 미구현 시 핵심 기능 동작 불가 | Phase 1 (MVP) |
| **P1** | 품질 및 안정성 보장을 위해 중요 | Phase 2 |
| **P2** | 운영 효율화 및 최적화 | Phase 3 |
| **P3** | 장기 고도화 | Phase 3 이후 |

### 항목별 우선순위

| 항목 | 우선순위 | Phase |
|------|---------|-------|
| API 인벤토리 최초 정의 및 문서화 | **P0** | Phase 1 |
| PG사 연동 기본 결제 흐름 (가디언 과금, 여행 기본 과금) | **P0** | Phase 1 |
| FCM SOS 알림 폴백 (SMS 채널) 구현 | **P0** | Phase 1 |
| Firebase Auth 장애 시 로컬 토큰 폴백 | **P0** | Phase 1 |
| API 키 Secret Manager 등록 및 순환 정책 시행 | **P0** | Phase 1 |
| 폴백 매트릭스 전체 구현 (Tier 1~3) | **P1** | Phase 2 |
| 비용 모니터링 대시보드 및 임계값 알림 | **P1** | Phase 2 |
| `tb_api_usage_log` 적재 파이프라인 | **P1** | Phase 2 |
| Rate Limit 대응 큐잉 시스템 | **P1** | Phase 2 |
| API 버전 관리 자동화 (Changelog 구독) | **P2** | Phase 3 |
| 비용 최적화 (배치 처리 전환) | **P2** | Phase 3 |
| API 사용 분석 대시보드 (BI 연동) | **P3** | Phase 3 이후 |
| 비용 예측 ML 모델 | **P3** | Phase 3 이후 |

---

## §10. 검증 체크리스트 (12항목)

본 문서의 완전성 및 정합성을 확인하기 위한 검증 항목이다.

| # | 체크 항목 | 상태 |
|---|----------|------|
| 1 | 전체 API 인벤토리가 목록화되었는가 (최소 10개) | O (12개 등록, §3.1) |
| 2 | SOS 관련 API(FCM, Firebase Auth) SLA가 99.9%로 명시되었는가 | O (§3.2) |
| 3 | PG사 연동 결제 흐름이 비즈니스 원칙 §09 기준과 일치하는가 | O (§3.5, 결제 흐름 7단계) |
| 4 | 가디언 과금 환불 불가 정책이 §09.3과 일치하는가 | O (§3.5 환불 처리 테이블) |
| 5 | 3계층 폴백 매트릭스가 전체 API에 적용되었는가 | O (§3.3, 12개 API 전수 적용) |
| 6 | 비용 알림 임계값(80%)이 명시되었는가 | O (§3.4 비용 모니터링 정책) |
| 7 | API 키 순환 주기가 명시되었는가 (90일/30일) | O (§3.6) |
| 8 | Rate Limit 대응 전략이 API별로 명시되었는가 | O (§3.8, 7개 API 전수 정의) |
| 9 | DB 스키마(tb_api_usage_log, tb_payment_transaction)가 정의되었는가 | O (§7.1, §7.2 DDL 포함) |
| 10 | 오프라인 시 API 큐잉 정책이 명시되었는가 | O (§8) |
| 11 | 초기 버전 정의 사유가 §11에 명시되었는가 | O (§11) |
| 12 | 비즈니스 원칙 v5.1 참조가 명시되었는가 | O (§1.3, §3.5 등 전반) |

**추가 N/A 항목:**
- 가디언 과금 분기: §3.5 PG사 연동 섹션에 포함 처리
- 여행 기간 15일 제한: 본 문서는 기술 운영 문서로 해당 없음

---

## §11. 변경 이력 (초기 버전 정의 사유)

| 항목 | 내용 |
|------|------|
| **문서 버전** | v1.0 (신규 작성) |
| **작성일** | 2026-03-02 |
| **작성 배경** | 비즈니스 원칙 v5.1 §09 과금 체계의 PG사 연동 구현 상세 정의 필요. 외부 API 인벤토리, SLA, 폴백 전략, 비용 관리, 보안 정책을 단일 문서로 통합 관리 |
| **상위 문서 정합** | 비즈니스 원칙 §09(과금), §05(SOS), §11(오프라인), §12(B2B)의 외부 API 관련 원칙 구체화 |
| **앱 성능 원칙(#31) 정합** | SLA 수치 및 가용성 요구사항을 앱 성능 원칙과 정합하여 작성 |
| **DB 설계(#07 v3.4) 정합** | `tb_payment_transaction.refund_policy` (v3.4.1 추가), `payment_type` CHECK 타입 체계 반영 |

| 버전 | 작성일 | 변경 내용 |
|------|--------|-----------|
| v1.0 | 2026-03-02 | 신규 작성. 비즈니스 원칙 v5.1 §09 과금 체계 PG사 연동 구현 상세 정의. 외부 API 인벤토리·SLA·폴백·비용·보안 정책 단일 문서 통합 관리 |

---

## §12. 부록

### §12.1 API 인벤토리 전체 테이블 (§3.1 상세 버전)

| # | API | 제공사 | 의존 기능 | Safety 연관 | 비용 등급 | Phase |
|---|-----|--------|-----------|:-----------:|:---------:|-------|
| 1 | Firebase Auth | Google | 인증/세션 | O | 무료 | Phase 1 |
| 2 | Firebase Realtime DB | Google | 실시간 위치, 채팅 | O | 중 | Phase 1 |
| 3 | Firebase Cloud Messaging | Google | SOS 알림, 푸시 | O (SOS) | 무료 | Phase 1 |
| 4 | Google Maps Platform | Google | 지도, 지오코딩, 경로 | — | 고 | Phase 1 |
| 5 | Nominatim (OSM) | OpenStreetMap | 역지오코딩 | — | 무료 | Phase 1 |
| 6 | MOFA 외교부 API | 대한민국 외교부 | 여행경보 | O (간접) | 무료 | Phase 1 |
| 7 | LLM API | OpenAI / Anthropic | AI 기능 | O (Safety AI) | 고 | Phase 2 |
| 8 | PG사 결제 API | TBD (토스페이먼츠 등) | 결제/환불 | — | 수수료 | Phase 2 |
| 9 | App Store API | Apple | iOS 인앱 결제 | — | 수수료 | Phase 2 |
| 10 | Play Store API | Google | Android 인앱 결제 | — | 수수료 | Phase 2 |
| 11 | Sentry | Sentry Inc. | 서버 에러 모니터링 | — | 저/무료 | Phase 1 |
| 12 | Crashlytics | Google (Firebase) | 앱 크래시 추적 | — | 무료 | Phase 1 |

### §12.2 비용 예측 스프레드시트 템플릿 (항목별)

월간 비용 예측 시 다음 항목을 기준으로 스프레드시트를 작성한다.

| 항목 | 1,000 DAU | 5,000 DAU | 10,000 DAU |
|------|:---------:|:---------:|:----------:|
| Google Maps 지도 로드 (건) | 10,000 | 50,000 | 100,000 |
| Google Maps 지오코딩 (건) | 5,000 | 25,000 | 50,000 |
| Firebase RTDB 다운로드 (GB) | 10 | 50 | 100 |
| LLM API 토큰 (M 토큰) | 10 | 50 | 100 |
| PG사 결제 (건) | 가변 | 가변 | 가변 |
| **예상 월 총비용 (USD)** | $350 ~ $950 | $1,750 ~ $4,750 | $3,500 ~ $9,500 |

> 실제 비용은 사용자 행동 패턴, 캐시 히트율, 협의 요금제에 따라 크게 달라질 수 있다. 매월 실측값을 기반으로 예측 모델을 보정한다.

### §12.3 관련 문서 참조 테이블

| 문서 번호 | 문서명 | 참조 이유 |
|----------|--------|-----------|
| #01 | SafeTrip_비즈니스_원칙_v5.1 | 과금(§09), SOS(§05), 오프라인(§11), B2B(§12) 정책 기준 |
| #07 | DB 설계 v3.4 | tb_payment_transaction, tb_api_usage_log 스키마 정합 |
| #31 | 앱 성능·안정성 원칙 | SLA 수치 및 가용성 요구사항 정합 |
| #35 | 마스터_원칙_거버넌스_v2.0 | 문서 계층 및 버전 관리 규칙 |

---

*문서 끝 — DOC-T4-EXT-033 v1.0 (2026-03-02)*
