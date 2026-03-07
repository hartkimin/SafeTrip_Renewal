# 초대코드 아키텍처 원칙 정합성 수정 설계

---

## 문서 헤더

| 항목 | 내용 |
|------|------|
| **문서 목적** | 23_T3_초대코드_원칙 v1.1 대비 기존 구현의 불일치 10건 수정 설계 |
| **작성일** | 2026-03-07 |
| **기준 문서** | 23_T3_초대코드_원칙 v1.1 (DOC-T3-INV-023) |
| **접근 방식** | Approach B — 계층별 배치 수정 (DB→Entity→DTO→Service→Controller→Test) |

---

## 수정 대상 10건 요약

| # | 심각도 | 원칙 조항 | 불일치 내용 |
|---|--------|----------|------------|
| 1 | HIGH | §14.1 | validate 엔드포인트 @Public → 인증 필요 |
| 2 | HIGH | §13.1 | 컬럼명 used_count → current_uses 변경 |
| 3 | MEDIUM | §03.2 | expires_hours 상한 168 미검증 |
| 4 | MEDIUM | §03.3 | max_uses 상한 100 미검증 |
| 5 | MEDIUM | §04.1 | 크루장 고급 설정(max_uses, expires_hours) 제한 누락 |
| 6 | MEDIUM | §13.1 | SQL NOT NULL 제약 누락 (code, target_role, expires_at) |
| 7 | LOW | §05 Step 8 | 크루장 정원/가디언 한도 미검증 |
| 8 | LOW | §14.2 | createCode 응답에 qr_url 미포함 |
| 9 | LOW | §14.1 | listCodes 활성 코드 필터링 없음 |
| 10 | LOW | §12.3 | Rate Limiting 미구현 |

---

## 계층별 수정 설계

### Layer 1: DB 마이그레이션

**파일**: `sql/migration-invite-code-verification-fix.sql`

```sql
-- #2: 컬럼명 변경 used_count → current_uses
ALTER TABLE tb_invite_code RENAME COLUMN used_count TO current_uses;

-- #6: NOT NULL 제약 추가
ALTER TABLE tb_invite_code ALTER COLUMN code SET NOT NULL;
ALTER TABLE tb_invite_code ALTER COLUMN target_role SET NOT NULL;
ALTER TABLE tb_invite_code ALTER COLUMN expires_at SET NOT NULL;
```

**01-schema-user-group-trip.sql 업데이트**: 동일하게 반영

### Layer 2: Entity 수정

**파일**: `src/entities/invite-code.entity.ts`

- `usedCount` → `currentUses` (프로퍼티명)
- `used_count` → `current_uses` (DB 컬럼 매핑)
- `nullable: true` 제거: code, targetRole, expiresAt

### Layer 3: DTO 검증 강화

**파일**: `src/modules/invite-codes/dto/create-invite-code.dto.ts`

- `max_uses`: `@Max(100)` 추가 (#4)
- `expires_hours`: `@Max(168)` 추가 (#3)

### Layer 4: Service 비즈니스 로직

**파일**: `src/modules/invite-codes/invite-codes.service.ts`

- **#5 크루장 제한**: crew_chief일 때 max_uses/expires_hours 커스텀 값 무시 (기본값 강제)
- **#7 Step 8 역할 정원**: 크루장 최대 인원수 검증 로직 추가
- **#8 qr_url**: createCode 응답에 `qr_url` 필드 추가
- **#9 listCodes 필터**: isActive=true인 코드만 기본 반환 (옵션: include_inactive 파라미터)
- **#2 컬럼명**: 서비스 내 `usedCount` → `currentUses` 전부 교체

### Layer 5: Controller 수정

**파일**: `src/modules/invite-codes/invite-codes.controller.ts`

- **#1**: validate 엔드포인트에서 `@Public()` 제거
- **#10**: Rate Limiting — `@Throttle()` 데코레이터 적용 (validate, use 엔드포인트)

### Layer 6: 테스트 보강

**파일**: `src/modules/invite-codes/invite-codes.service.spec.ts`

추가할 테스트 케이스:
- expires_hours > 168 거부
- max_uses > 100 거부
- 크루장이 커스텀 max_uses/expires_hours 설정 시 기본값 적용 확인
- 크루장 정원 초과 시 ERR_ROLE_UNAVAILABLE
- listCodes 비활성 코드 미포함 확인
- createCode 응답에 qr_url 포함 확인

---

## Rate Limiting 설계 (#10)

NestJS `@nestjs/throttler` 패키지 활용:
- validate 엔드포인트: 1분당 10회 (IP 기준)
- use 엔드포인트: 1분당 5회 (사용자 기준)
- 초과 시 429 Too Many Requests 반환

---

## 변경 영향 범위

| 파일 | 변경 유형 |
|------|----------|
| sql/migration-invite-code-verification-fix.sql | 신규 생성 |
| sql/01-schema-user-group-trip.sql | 수정 (NOT NULL, 컬럼명) |
| src/entities/invite-code.entity.ts | 수정 (컬럼명, nullable) |
| src/modules/invite-codes/dto/create-invite-code.dto.ts | 수정 (Max 추가) |
| src/modules/invite-codes/invite-codes.service.ts | 수정 (6건 로직 변경) |
| src/modules/invite-codes/invite-codes.controller.ts | 수정 (@Public 제거, @Throttle 추가) |
| src/modules/invite-codes/invite-codes.service.spec.ts | 수정 (테스트 케이스 추가) |
| src/app.module.ts | 수정 (ThrottlerModule 등록 — 미등록 시) |
