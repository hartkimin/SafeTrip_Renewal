# 역할 기반 권한 시스템 — 남은 작업 목록

> 마이그레이션 코드 구현 완료 (2026-02-25)
> 원본 계획서: `plan/invite-code-role-permission-plan_v2.md`

---

## 구현 완료 현황 요약

| Phase | 범위 | 상태 |
|-------|------|------|
| Phase 1 | DB 스키마 (로컬) | ✅ 완료 |
| Phase 2 | 백엔드 서비스 (7개 파일) | ✅ 완료 |
| Phase 3 | 백엔드 컨트롤러 (2개 파일) | ✅ 완료 |
| Phase 4 | 백엔드 신규 기능 (6개 파일 신규 + 2개 수정) | ✅ 완료 |
| Phase 5 | Flutter 모델/유틸 (4개 파일) | ✅ 완료 |
| Phase 6 | Flutter 화면/API (6개 파일) | ✅ 완료 |

---

## A. 즉시 필요 — 컴파일/빌드 검증

### A-1. 백엔드 TypeScript 컴파일
- [ ] `cd safetrip-server-api && npm run build`
- [ ] 컴파일 에러 0건 확인
- [ ] 특히 새 파일들의 import 경로 확인:
  - `services/invite-code.service.ts`
  - `services/leader-transfer.service.ts`
  - `controllers/invite-codes.controller.ts`
  - `controllers/leader-transfer.controller.ts`

### A-2. Flutter 정적 분석 & 빌드
- [ ] `cd safetrip-mobile && flutter analyze`
- [ ] `flutter build apk --debug`
- [ ] 분석 에러/경고 0건 확인
- [ ] 빌드 성공 확인

---

## B. 로컬 DB 검증

### B-1. Docker 재빌드
- [ ] `docker-compose down -v`
- [ ] `docker-compose -f docker-compose.local.yml up -d`

### B-2. 스키마 확인
- [ ] TB_GROUP_MEMBER에 `member_role` 컬럼 존재 + CHECK 제약조건
- [ ] TB_GROUP_MEMBER에 `location_sharing_enabled` 컬럼 존재
- [ ] TB_INVITE_CODE 테이블 존재 (code, target_role, max_uses, used_count, expires_at)
- [ ] TB_LOCATION_SHARING 테이블 존재
- [ ] TB_LEADER_TRANSFER_LOG 테이블 존재
- [ ] 인덱스 생성 확인 (idx_group_members_role, idx_invite_code_code 등)

### B-3. 테스트 데이터 확인
```sql
SELECT user_id, member_role, is_admin, is_guardian
FROM tb_group_member
ORDER BY member_role;
-- 예상: leader(1), full(1), normal(2), view_only(1)
```

---

## C. API 엔드포인트 테스트

### C-1. 기존 API 하위호환 (is_admin/is_guardian 가상 필드 반환 확인)

| 엔드포인트 | 확인 사항 |
|------------|----------|
| `GET /groups/:id/members` | 응답에 `member_role` + `is_admin` + `is_guardian` 모두 포함 |
| `GET /groups/:id/my-permission` | 응답에 `member_role` 포함 |
| `GET /users/:id` | `user_role` 필드 정상 (`view_only` → `guardian` 매핑) |
| `POST /groups/join/:code` | 레거시 TB_GROUP.invite_code로 가입 성공 |

### C-2. 새 초대코드 API

| 엔드포인트 | 테스트 시나리오 |
|------------|---------------|
| `POST /:groupId/invite-codes` | role별(full/normal/view_only) 코드 생성 → 코드 형식 확인 (A/M/V + 6자리) |
| `GET /:groupId/invite-codes` | 생성된 코드 목록 조회 |
| `POST /join-by-code/:code` | 코드로 가입 → member_role이 target_role과 일치 확인 |
| `DELETE /:groupId/invite-codes/:codeId` | 비활성화 후 사용 불가 확인 |
| — | 만료 코드 사용 시 에러 확인 |
| — | max_uses 초과 시 에러 확인 |
| — | 권한 없는 사용자(normal/view_only)의 코드 생성 차단 확인 |

### C-3. 리더 양도 API

| 엔드포인트 | 테스트 시나리오 |
|------------|---------------|
| `POST /:groupId/transfer-leadership` | leader → full 멤버에게 양도 성공 |
| — | 양도 후 기존 leader의 role이 `full`로 변경 확인 |
| — | 양도 후 대상자의 role이 `leader`로 변경 확인 |
| — | TB_GROUP.owner_user_id 변경 확인 |
| — | leader가 아닌 사용자의 양도 시도 차단 확인 |
| `GET /:groupId/transfer-history` | 양도 이력 조회 |

---

## D. 프로덕션 데이터 마이그레이션 (★ 배포 시 필수)

> 원본 계획서 §5.2 "Phase 2 — 기존 데이터 이관" 참조
> 로컬 01-init-schema.sql은 새 DB용이므로, 프로덕션은 별도 마이그레이션 스크립트 필요

### D-1. 사전 준비
- [ ] AWS RDS 스냅샷 생성
- [ ] 마이그레이션 스크립트 작성 (`scripts/migration/migrate-member-role.sql`)

### D-2. 데이터 이관 스크립트 (요약)
```sql
BEGIN;

-- 1. member_role 컬럼 추가 (이미 없는 경우)
ALTER TABLE TB_GROUP_MEMBER
ADD COLUMN IF NOT EXISTS member_role VARCHAR(20) DEFAULT 'normal';

-- 2. 기본값: 모든 멤버를 'normal'로
UPDATE TB_GROUP_MEMBER SET member_role = 'normal' WHERE member_role IS NULL;

-- 3. is_admin=TRUE → 'full'
UPDATE TB_GROUP_MEMBER SET member_role = 'full'
WHERE is_admin = TRUE AND status = 'active';

-- 4. is_guardian=TRUE → 'view_only' (admin이 아닌 경우만)
UPDATE TB_GROUP_MEMBER SET member_role = 'view_only'
WHERE is_guardian = TRUE AND is_admin = FALSE AND status = 'active';

-- 5. 그룹 owner → 'leader'
UPDATE TB_GROUP_MEMBER SET member_role = 'leader'
WHERE (group_id, user_id) IN (
  SELECT group_id, owner_user_id FROM TB_GROUP WHERE owner_user_id IS NOT NULL
) AND status = 'active';

-- 6. leader 없는 그룹에 가장 오래된 admin을 leader로
-- (원본 계획서 §5.2 참조 - 전체 스크립트)

-- 7. TB_GUARDIAN → TB_GROUP_MEMBER 통합
-- (원본 계획서 §5.2 참조 - INSERT INTO ... ON CONFLICT)

-- 8. 검증 쿼리
-- (원본 계획서 §5.2 참조)

COMMIT;
```

### D-3. 검증 쿼리
- [ ] `SELECT COUNT(*) FROM TB_GROUP_MEMBER WHERE member_role IS NULL AND status = 'active'` → **0**
- [ ] leader 없는 활성 그룹 (멤버 있는 경우) → **0**
- [ ] `is_admin = TRUE AND member_role NOT IN ('leader', 'full')` → **0**
- [ ] `is_guardian = TRUE AND member_role != 'view_only' AND member_role NOT IN ('leader', 'full')` → **0**

---

## E. 미구현 기능 (원본 계획서에 포함, 이번 범위에서 의도적 제외)

### E-1. 외부 의존성 (별도 작업 필요)

| 기능 | 제외 이유 | 향후 작업 |
|------|----------|----------|
| 카카오 SDK 연동 (`shareInviteCodeViaKakao`) | 외부 플랫폼 의존 | pubspec.yaml + AndroidManifest + Info.plist + KakaoSdk.init() |
| Firebase Console RTDB Rules 변경 | Firebase Console 직접 설정 필요 | `location_sharing` 경로 Rules 추가 |

### E-2. 미구현 UI 화면 (신규 개발 필요)

| 화면 | 설명 | 우선순위 |
|------|------|---------|
| 리더 양도 UI | 멤버 목록에서 full 역할 멤버 선택 → 양도 확인 다이얼로그 | 🟡 중간 |
| 위치 공유 관리 UI | 마스터 ON/OFF 토글 + 개별 멤버별 공유 설정 토글 | 🟡 중간 |
| 초대코드 관리 화면 | 생성된 코드 목록 조회 / 비활성화 (invite_modal에 기본 기능은 포함됨) | 🟢 낮음 |

### E-3. Deprecation 작업 (장기)

| 대상 | 작업 | 시점 |
|------|------|------|
| `guardian.service.ts` | `@Deprecated` 마킹 | Phase 4 진입 시 |
| `guardians.routes.ts` | `@Deprecated` 마킹 | Phase 4 진입 시 |
| Flutter guardian API 메서드 (13개) | `@Deprecated` 주석 | 새 시스템 안정화 후 |

---

## F. Phase 4 — 레거시 정리 (최소 1~2주 모니터링 후)

> 원본 계획서 §14 "Phase 4: 정리" 참조
> ⚠️ 충분한 모니터링 확인 후에만 실행

| # | 작업 | 위험도 |
|---|------|--------|
| F-1 | 백엔드: SELECT의 가상 필드 제거 (`is_admin`, `is_guardian` CASE WHEN 제거) | 🟡 |
| F-2 | Flutter: 레거시 UserRole 값 제거 (`traveler`, `guardian` enum) | 🟡 |
| F-3 | Flutter: guardian API 메서드 완전 제거 | 🟡 |
| F-4 | DB: `is_admin`, `is_guardian` 컬럼 DROP | 🔴 |
| F-5 | DB: `TB_GUARDIAN` → `TB_GUARDIAN_LEGACY` rename (6개월 후 삭제) | 🟢 |
| F-6 | Backend: `guardian.service.ts` deprecated 메서드 제거 | 🟡 |

---

## G. 배포 순서 (권장)

```
 1. 백엔드 TypeScript 컴파일 검증          ← A-1
 2. Flutter 빌드 검증                     ← A-2
 3. 로컬 Docker DB 검증                   ← B
 4. 로컬 API 테스트 (curl/Postman)         ← C
 5. 프로덕션 DB 스냅샷 생성                ← D-1
 6. 프로덕션 DB Phase 1 (스키마 추가)       ← 무중단
 7. 프로덕션 DB Phase 2 (데이터 이관)       ← 유지보수 시간 권장
 8. 검증 쿼리 실행                        ← D-3
 9. 백엔드 서버 배포 (Rolling/Blue-Green)
10. 백엔드 API 통합 테스트                 ← C 재실행
11. Flutter 앱 빌드 + 스토어 배포
12. 1~2주 모니터링
13. Phase 4 레거시 정리 (선택)              ← F
```

---

## 참고: 이번 마이그레이션에서 수정된 파일 전체 목록

### Backend (safetrip-server-api/src/)

| 파일 | 유형 |
|------|------|
| `scripts/local/01-init-schema.sql` | 수정 |
| `scripts/local/02-seed-test-data.sql` | 수정 |
| `services/permission.service.ts` | 수정 |
| `services/user.service.ts` | 수정 |
| `services/groups.service.ts` | 수정 |
| `services/event-notification.service.ts` | 수정 |
| `services/schedule.service.ts` | 수정 |
| `services/traveler.service.ts` | 수정 |
| `controllers/groups.controller.ts` | 수정 |
| `controllers/trips.controller.ts` | 수정 |
| `routes/groups.routes.ts` | 수정 |
| `services/invite-code.service.ts` | **신규** |
| `services/leader-transfer.service.ts` | **신규** |
| `controllers/invite-codes.controller.ts` | **신규** |
| `controllers/leader-transfer.controller.ts` | **신규** |
| `routes/invite-codes.routes.ts` | **신규** |
| `routes/leader-transfer.routes.ts` | **신규** |

### Flutter (safetrip-mobile/lib/)

| 파일 | 유형 |
|------|------|
| `models/user.dart` | 수정 (UserRole enum 확장 + extension) |
| `screens/auth/screen_4_role.dart` | 수정 (중복 enum 제거) |
| `utils/app_cache.dart` | 수정 (memberRole 필드 추가) |
| `utils/guardian_filter.dart` | 수정 (member_role 체크 추가) |
| `services/api_service.dart` | 확장 (6개 API 메서드 추가) |
| `screens/main/screen_main.dart` | 수정 (guardian 필터 + role 판단) |
| `screens/main/bottom_sheets/modals/invite_modal.dart` | 개편 (역할별 초대코드 UI) |
| `screens/trip/screen_trip_join_code.dart` | 수정 (새 초대코드 시스템 연동) |
| `managers/firebase_location_manager.dart` | 수정 (guardian 체크 확장) |
| `screens/main/screen_attendance_check.dart` | 수정 (isAdmin 체크 확장) |

### 기타

| 파일 | 유형 |
|------|------|
| `database.rules.json` | 수정 (location_sharing 경로 추가) |
