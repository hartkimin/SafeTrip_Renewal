# AI 아키텍처 원칙 전면 반영 설계

**날짜**: 2026-03-07
**기준 문서**: DOC-T3-AIF-026 (AI 기능 원칙 v1.1)
**접근법**: Layered AI Service Architecture

---

## 1. 목표

AI 기능 원칙 문서(§2~§14)의 전체 원칙을 서버 + Flutter 코드에 반영한다.
현재 코드베이스의 GAP을 해소하고, 문서의 각 섹션이 코드에 1:1 대응되는 계층 구조를 구축한다.

## 2. 현재 상태 vs 목표 상태

### 2.1 기존 코드 (AS-IS)

| 구성 요소 | 파일 | 상태 |
|----------|------|------|
| AI 접근 제어 | `ai.service.ts` checkAccess() | 미성년자/프라이버시 기본 체크만 |
| LLM 호출 | `ai.service.ts` generateSafetyGuide() | HTTP 직접 호출, 폴백 없음 |
| 데이터 마스킹 | `ai.service.ts` maskForLlm() | 전화번호/이메일만 |
| 캐싱 | 없음 | — |
| 사용 로그 | `tb_ai_usage` (일일 카운터) | 문서 스키마와 불일치 |
| AI 구독 | `tb_subscription` (통합) | AI 전용 테이블 없음 |
| AI 일정 추천 | `ai-suggest.service.ts` | Mock/Stub |

### 2.2 목표 (TO-BE)

| 구성 요소 | 파일 | 문서 근거 |
|----------|------|----------|
| AccessGuard | `core/access-guard.service.ts` | §8, §9, §10 |
| LLMGateway (3단계 폴백) | `core/llm-gateway.service.ts` | §6 |
| DataMasker | `core/data-masker.service.ts` | §5.1 |
| ResponseCache | `core/response-cache.service.ts` | §5.3 |
| UsageLogger | `core/usage-logger.service.ts` | §5.4 |
| SafetyAiService | `safety-ai.service.ts` | §3.1 Safety |
| ConvenienceAiService | `convenience-ai.service.ts` | §3.1 Convenience |
| IntelligenceAiService | `intelligence-ai.service.ts` | §3.1 Intelligence |
| tb_ai_usage_log | `15-schema-ai.sql` + Entity | §12.1 |
| tb_ai_subscription | `15-schema-ai.sql` + Entity | §12.2 |

## 3. DB 스키마 설계

### 3.1 tb_ai_usage_log (§12.1)

문서 §12.1 정의 그대로 구현. 기존 `tb_ai_usage`(일일 카운터)는 병행 유지.

| 컬럼 | 타입 | 설명 |
|------|------|------|
| log_id | UUID PK | — |
| user_id | UUID FK(tb_user) | ON DELETE SET NULL |
| trip_id | UUID FK(tb_trip) | ON DELETE SET NULL |
| ai_type | VARCHAR(20) | safety / convenience / intelligence |
| feature_name | VARCHAR(50) | sos_auto_detect 등 |
| model_used | VARCHAR(50) | gpt-4o, claude-3, rule_based 등 |
| is_cached | BOOLEAN | — |
| is_fallback | BOOLEAN | — |
| fallback_reason | VARCHAR(100) | api_timeout 등 |
| latency_ms | INTEGER | — |
| is_minor_user | BOOLEAN | — |
| privacy_level | VARCHAR(20) | — |
| feedback | SMALLINT | -1/0/1 |
| created_at | TIMESTAMPTZ | — |
| expires_at | TIMESTAMPTZ | 성인 +90일, 미성년자 +30일 |

### 3.2 tb_ai_subscription (§12.2)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| subscription_id | UUID PK | — |
| user_id | UUID FK(tb_user) | ON DELETE CASCADE |
| plan_type | VARCHAR(20) | ai_plus / ai_pro |
| billing_cycle | VARCHAR(10) | monthly / per_trip |
| trip_id | UUID FK(tb_trip) | per_trip 시 사용 |
| status | VARCHAR(20) | active / cancelled / expired / grace_period |
| started_at | TIMESTAMPTZ | — |
| expires_at | TIMESTAMPTZ | — |
| grace_until | TIMESTAMPTZ | 결제 실패 시 3일 유예 |
| payment_id | UUID FK(tb_payment) | — |

## 4. AI Core Layer 설계

### 4.1 AccessGuardService (§8 + §9 + §10)

역할(캡틴/크루장/크루/가디언) × AI 기능 × 구독 상태 매트릭스 기반 접근 제어.

**체크 순서**:
1. 사용자 역할 확인 (tb_group_member.role)
2. 미성년자 여부 확인 (tb_user.birth_date 또는 is_minor 플래그)
3. 프라이버시 등급 확인 (tb_trip.privacy_level)
4. AI 구독 상태 확인 (tb_ai_subscription)
5. 일일 사용량 제한 확인 (tb_ai_usage)

### 4.2 LLMGatewayService (§6)

3단계 폴백 구조:
- 1차: OpenAI GPT-4o (Convenience/Intelligence) + Anthropic Claude 3 (Safety 문맥분석)
- 2차: 온디바이스 (인터페이스만, Phase 3에서 실제 구현)
- 3차: 규칙 기반 (Safety 전 기능 유지, Convenience 비활성, Intelligence 비활성)

**타임아웃**: Safety 2초, Convenience 5초, Intelligence 10초

### 4.3 DataMaskerService (§5.1)

마스킹 규칙:
- 사용자 이름 → "멤버A", "멤버B" (순번 익명화)
- 전화번호 → 전송 금지
- 이메일 → 전송 금지
- 정확 위치 → 구(區) 수준 그리드 (100m→1km)
- 여행명 → 내부 ID ("trip_a1b2")

### 4.4 ResponseCacheService (§5.3)

인메모리 캐시 (Map + TTL):
- 국가 위험 정보: 6시간
- 장소 추천: 24시간
- 일정 자동 완성: 1시간
- 채팅 요약: 메시지 변경 전까지
- 안전 브리핑: 4시간

### 4.5 UsageLoggerService (§5.4)

매 AI 호출 시 tb_ai_usage_log에 기록. expires_at 자동 계산 (성인 90일 / 미성년자 30일).

## 5. AI Feature Services 설계

### 5.1 SafetyAiService (전원 무료)

- 위험 지역 감지: 외교부 API + DB (기존 /mofa 모듈 연계)
- SOS 자동 판단: 규칙 기반 (비활성 시간 + 가속도)
- 이탈 감지: 지오펜스 300m 초과 (기존 /geofences 연계)
- 집합 지연 감지: 집합 시간 미도착 (기존 /attendance 연계)
- **LLM 미사용** (§7.2 할루시네이션 방지)

### 5.2 ConvenienceAiService

무료: 일정 자동 완성, 이동 시간 추정, 짐 리스트 생성
AI Plus: 장소 추천, AI 챗봇, 실시간 번역, 채팅 요약

### 5.3 IntelligenceAiService (전원 유료)

AI Plus: 여행 인사이트, 패턴 분석, 이동 예측
AI Pro: 맞춤 안전 브리핑, 일정 최적화

## 6. Flutter 변경 사항

### 6.1 AI 접근 제어 서비스 (AiAccessService)
- 서버 access-check API 호출 → 잠금/해제 상태 관리

### 6.2 AI 구독 안내 모달
- AI Plus / AI Pro 가격 및 기능 비교 표시
- 인앱 결제 연동

### 6.3 오프라인 Safety AI 폴백 (§13)
- 로컬 SQLite 이벤트 큐잉
- 온라인 복귀 시 자동 동기화
- 규칙 기반 이탈 감지 (GPS 300m + 10분)
- 온디바이스 모델 인터페이스 (abstract class만)

### 6.4 AI 응답 UI
- 면책 문구: "AI가 생성한 정보로, 실제와 다를 수 있습니다"
- Intelligence: 분석 근거 데이터 표시
- 피드백 버튼 (엄지 업/다운)

## 7. 파일 구조

```
safetrip-server-api/
├── sql/15-schema-ai.sql
├── src/entities/ai.entity.ts (수정: AiUsageLog + AiSubscription)
├── src/entities/index.ts (수정)
└── src/modules/ai/
    ├── ai.module.ts (수정)
    ├── ai.controller.ts (수정)
    ├── ai.service.ts (수정→축소: 오케스트레이터)
    ├── core/
    │   ├── access-guard.service.ts
    │   ├── llm-gateway.service.ts
    │   ├── data-masker.service.ts
    │   ├── response-cache.service.ts
    │   └── usage-logger.service.ts
    ├── safety-ai.service.ts
    ├── convenience-ai.service.ts
    └── intelligence-ai.service.ts

safetrip-mobile/lib/features/ai/
├── services/
│   ├── ai_access_service.dart
│   ├── ai_offline_queue.dart
│   └── on_device_model_interface.dart
├── providers/ai_provider.dart
└── widgets/
    ├── ai_subscription_modal.dart
    ├── ai_feedback_widget.dart
    └── ai_disclaimer_badge.dart
```

## 8. NPM 의존성 추가

- `openai` (GPT-4o 호출)
- `@anthropic-ai/sdk` (Claude 3 호출)

## 9. 환경 변수 추가

- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`

## 10. 테스트 전략

- Unit: AccessGuard, DataMasker, ResponseCache, UsageLogger
- Integration: LLMGateway 폴백 시나리오
- E2E: 접근 제어 (미성년자, 프라이버시, 구독별)
- Flutter Widget: 구독 모달, 피드백 UI
