# 초대코드 원칙 적용 설계

| 항목 | 내용 |
|------|------|
| 기준 문서 | 23_T3_초대코드_원칙 v1.1 |
| 접근 방식 | A: 전용 InviteCodesModule 분리 |
| 범위 | P0 + P1 + API 경로 마이그레이션 |
| 대상 | Backend (NestJS) + Flutter 클라이언트 |

---

## 1. DB 스키마 변경

### 마이그레이션

```sql
-- model_type 컬럼 추가 (§02.3, §13.1)
ALTER TABLE tb_invite_code
  ADD COLUMN IF NOT EXISTS model_type VARCHAR(20) DEFAULT 'direct';

-- b2b_batch_id 부분 인덱스 추가 (§13.1)
CREATE INDEX IF NOT EXISTS idx_invite_code_batch
  ON tb_invite_code(b2b_batch_id) WHERE b2b_batch_id IS NOT NULL;
```

### 엔티티 변경

`InviteCode` 엔티티에 `modelType` 추가:
- `model_type VARCHAR(20) DEFAULT 'direct'` — `direct` | `system`
- DB 컬럼명 `used_count`는 유지 (TypeORM `name: 'used_count'`로 매핑)

---

## 2. 새 모듈 구조

```
src/modules/invite-codes/
├── invite-codes.module.ts
├── invite-codes.controller.ts
├── invite-codes.service.ts
└── dto/
    └── create-invite-code.dto.ts
```

### API 엔드포인트 (§14.1)

| 메서드 | 경로 | 설명 | 권한 |
|--------|------|------|------|
| POST | /trips/:tripId/invite-codes | 코드 생성 | 캡틴, 크루장(crew만) |
| GET | /trips/:tripId/invite-codes | 활성 코드 목록 | 캡틴(전체), 크루장(본인만) |
| POST | /invite-codes/validate | 사전 검증 | 인증된 사용자 |
| POST | /invite-codes/use | 합류 처리 | 인증된 사용자 |
| PATCH | /trips/:tripId/invite-codes/:codeId/deactivate | 비활성화 | 캡틴, 생성 크루장 |

레거시 라우트(groups/join-by-code, trips/invite/accept 등)는 새 서비스로 위임.

---

## 3. 비즈니스 로직

### 3.1 코드 생성 (createCode) — §03, §04

1. 요청자 권한 확인 (§04.1 매트릭스)
   - captain → crew_chief/crew/guardian 모두 가능
   - crew_chief → crew만 가능
   - 나머지 → 403
2. 활성 코드 수 제한 (§04.2)
   - captain: 역할당 최대 10개
   - crew_chief: 최대 5개
3. 기본값 적용 (§03.2)
   - expires_hours 미지정 → 72시간
   - max_uses 미지정 → 1
   - direct 타입에서 max_uses=NULL 불허
4. 7자리 코드 생성 (§03.1)
   - 31개 문자셋 (O/0/I/l 제외)
   - 최대 5회 충돌 재시도
5. tripId + groupId 모두 설정

### 3.2 8단계 검증 + 합류 (useCode) — §05, §11

트랜잭션 내에서 처리:

| 단계 | 검증 | 에러 코드 |
|------|------|---------|
| 1 | 코드 존재 | ERR_CODE_NOT_FOUND |
| 2 | is_active = TRUE | ERR_CODE_INACTIVE |
| 3 | NOW() < expires_at | ERR_CODE_EXPIRED |
| 4 | used_count < max_uses OR NULL | ERR_CODE_EXHAUSTED |
| 5 | trip.status ∈ {scheduled, ongoing} | ERR_TRIP_INVALID |
| 6 | 중복 참여 아닌지 | ERR_ALREADY_MEMBER |
| 7 | 정원 미초과 | ERR_TRIP_FULL |
| 8 | 역할 배정 가능 | ERR_ROLE_UNAVAILABLE |
| +α | 탈퇴 후 재참여 쿨다운 | ERR_REJOIN_COOLDOWN |
| +β | 멤버-가디언 중복 | ERR_GUARDIAN_MEMBER_OVERLAP |

트랜잭션 내 합류 처리:
- tb_group_member INSERT
- used_count + 1
- B2B면 tb_b2b_member_log INSERT

### 3.3 코드 입력 정규화 (§06.1)

모든 코드 조회 전 `code = code.toUpperCase()`.

### 3.4 코드 목록 조회 (listCodes) — §04.1

- captain: 해당 trip의 모든 코드
- crew_chief: created_by = userId인 코드만

### 3.5 비활성화 (deactivateCode) — §04.1

- captain: 모든 코드 비활성화 가능
- crew_chief: 본인 생성 코드만 비활성화 가능

---

## 4. Flutter 클라이언트 변경

### api_service.dart 경로 전환

| 메서드 | 기존 경로 | 새 경로 |
|--------|---------|--------|
| createInviteCode | /groups/:gid/invite-codes | /trips/:tid/invite-codes |
| getInviteCodesByGroup | /groups/:gid/invite-codes | /trips/:tid/invite-codes |
| deactivateInviteCode | /invite-codes/:cid | /trips/:tid/invite-codes/:cid/deactivate |
| previewInviteCode | /trips/invite/:code | /invite-codes/validate |
| acceptInvite | /trips/invite/accept | /invite-codes/use |

### UI 파라미터 변경

- invite_modal.dart: groupId → tripId
- invite_code_management_modal.dart: groupId → tripId
- screen_trip_join_code.dart: 자동 대문자 변환 추가

---

## 5. 테스트 전략

### 단위 테스트

1. 7자리 코드 형식 (혼동 문자 제외)
2. 8단계 검증 각 단계별 실패 케이스
3. 권한 매트릭스 (크루장 → crew_chief 코드 생성 거부)
4. 트랜잭션 롤백 (합류 중 에러 시 used_count 미증가)
5. 만료 경계값 (1초 전/후)
6. 활성 코드 수 제한
7. 대문자 정규화

### 통합 테스트

8. 전체 플로우: 생성 → validate → use → 멤버 확인
9. ERR_ALREADY_MEMBER
10. ERR_REJOIN_COOLDOWN
11. ERR_GUARDIAN_MEMBER_OVERLAP
