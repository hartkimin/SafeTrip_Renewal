# 초대코드 + 역할 권한 + 위치 공유 관리 시스템 — 구현 계획서

> 작성일: 2026-02-25
> 버전: v2.0 (전면 재작성 — 마이그레이션 충돌 Zero 목표)
> 상태: 계획 수립 완료 (구현 전)

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [현재 상태 분석 (AS-IS)](#2-현재-상태-분석-as-is)
3. [목표 상태 설계 (TO-BE)](#3-목표-상태-설계-to-be)
4. [역할 시스템 상세 설계](#4-역할-시스템-상세-설계)
5. [데이터베이스 마이그레이션](#5-데이터베이스-마이그레이션)
6. [백엔드 변경 상세 (파일별)](#6-백엔드-변경-상세-파일별)
7. [Flutter 변경 상세 (파일별)](#7-flutter-변경-상세-파일별)
8. [Firebase 변경 상세](#8-firebase-변경-상세)
9. [초대코드 시스템 설계](#9-초대코드-시스템-설계)
10. [리더 양도 기능 설계](#10-리더-양도-기능-설계)
11. [위치 공유 관리 설계](#11-위치-공유-관리-설계)
12. [카카오톡 SDK 연동](#12-카카오톡-sdk-연동)
13. [API 설계](#13-api-설계)
14. [마이그레이션 실행 순서](#14-마이그레이션-실행-순서)
15. [플랫폼별 배포 체크리스트](#15-플랫폼별-배포-체크리스트)

---

## 1. 프로젝트 개요

### 1.1 기술 스택

| 레이어 | 기술 | 위치 |
|--------|------|------|
| **모바일** | Flutter 3.10+ (Dart) | `safetrip-mobile/` |
| **백엔드** | Node.js + Express + TypeScript | `safetrip-server-api/` |
| **데이터베이스** | PostgreSQL 14+ + PostGIS | AWS RDS |
| **인증** | Firebase Auth (전화번호 기반) | Firebase Console |
| **실시간** | Firebase Realtime Database | Firebase Console |
| **파일저장** | Firebase Storage | Firebase Console |
| **푸시** | Firebase Cloud Messaging (FCM) | Firebase Console |
| **호스팅** | AWS (EC2/ECS) | AWS Console |

### 1.2 핵심 설계 원칙

- **user_id = VARCHAR(128)** — Firebase Auth UID는 문자열이며 UUID가 아님
- **하위호환**: 기존 API 응답 형태 최대한 보존, 클라이언트 점진적 마이그레이션
- **Zero-downtime**: DB 마이그레이션은 ADD COLUMN → 데이터 이관 → DROP COLUMN 순서
- **트랜잭션 안전**: 모든 마이그레이션 스크립트는 BEGIN/COMMIT으로 감싸기

### 1.3 확정 결정 사항 (7개)

| # | 결정 | 상세 |
|:-:|------|------|
| 1 | 리더 양도 기능 포함 | 리더→다른 full 멤버에게 양도, API + UI 모두 구현 |
| 2 | 초대코드 기본 7일 만료 | `expires_at = created_at + INTERVAL '7 days'` |
| 3 | 사용 제한 기본 50회 | `max_uses = 50` (여행 그룹 특성상 적정치) |
| 4 | 위치 공유 기본 전체 ON | 가입 시 모든 멤버와 양방향 공유 활성화 |
| 5 | 카카오톡 SDK 연동 | 신규 통합 (현재 미설치) |
| 6 | TB_GUARDIAN → view_only 통합 | 보호자 테이블을 역할 시스템에 병합 |
| 7 | full → leader는 양도만 | 직접 승격 불가, 리더 양도 프로세스를 통해서만 |

---

## 2. 현재 상태 분석 (AS-IS)

### 2.1 현재 DB 스키마 (TB_GROUP_MEMBER)

```sql
CREATE TABLE TB_GROUP_MEMBER (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- ⚠️ 현재 권한 모델 (BOOLEAN 기반)
    is_admin BOOLEAN DEFAULT FALSE,
    can_edit_schedule BOOLEAN DEFAULT FALSE,
    can_edit_geofence BOOLEAN DEFAULT FALSE,
    can_view_all_locations BOOLEAN DEFAULT TRUE,
    can_attendance_check BOOLEAN DEFAULT TRUE,

    -- ⚠️ 보호자 역할 (독립 플래그)
    is_guardian BOOLEAN DEFAULT FALSE NOT NULL,
    traveler_user_id VARCHAR(128) REFERENCES TB_USER(user_id),

    status VARCHAR(20) DEFAULT 'active',
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMPTZ,
    UNIQUE(group_id, user_id)
);
```

### 2.2 현재 TB_GUARDIAN (독립 테이블)

```sql
CREATE TABLE TB_GUARDIAN (
    guardian_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    traveler_user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id),
    guardian_user_id VARCHAR(128) REFERENCES TB_USER(user_id),
    trip_id UUID REFERENCES TB_TRIP(trip_id),
    guardian_type VARCHAR(20) DEFAULT 'primary',
    can_view_location BOOLEAN DEFAULT TRUE,
    can_request_checkin BOOLEAN DEFAULT TRUE,
    can_receive_sos BOOLEAN DEFAULT TRUE,
    invite_status VARCHAR(20) DEFAULT 'pending',
    guardian_invite_code VARCHAR(8) UNIQUE,
    guardian_phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    UNIQUE(traveler_user_id, guardian_user_id, trip_id)
);
```

### 2.3 현재 TB_GROUP (invite_code 컬럼)

```sql
-- TB_GROUP에 이미 invite_code 존재 (VARCHAR(8), UNIQUE)
invite_code VARCHAR(8) UNIQUE NOT NULL,
invite_link TEXT,
```

### 2.4 현재 권한 판별 로직 (코드 기반 분석)

#### 권한 판별 흐름
```
is_admin = TRUE  → "관리자" (스케줄/지오펜스/공지 등 전체 권한)
is_guardian = TRUE → "보호자" (위치 모니터링 특화)
else             → "여행자" (일반 멤버)
```

#### is_admin 사용 위치 (57+ 참조, 7개 파일)

| 파일 | 참조 수 | 핵심 로직 |
|------|---------|----------|
| `groups.service.ts` | 30 | 멤버 조회/추가/권한 변경/초대코드 가입 |
| `groups.controller.ts` | 15 | 권한 검증, 멤버 관리 API |
| `trips.controller.ts` | 5 | 그룹 생성자 설정, 보호자 가입, 권한 체크 |
| `permission.service.ts` | 3 | `isGroupAdmin()`, `getGroupMemberRole()` |
| `schedule.service.ts` | 2 | 일정 편집 권한 fallback |
| `event-notification.service.ts` | 1 | `notify_admins` 수신자 쿼리 |
| `traveler.service.ts` | 1 | 멤버 INSERT 시 `is_admin` 설정 |

#### is_guardian 사용 위치 (25+ 참조, 5개 파일)

| 파일 | 참조 수 | 핵심 로직 |
|------|---------|----------|
| `user.service.ts` | 12 | 4개 메서드에서 동일 패턴으로 `user_role` 판정 |
| `groups.service.ts` | 7 | 멤버 필터링, 반환값에 포함 |
| `permission.service.ts` | 2 | 역할 판별 |
| `event-notification.service.ts` | 1 | `notify_guardians` 수신자 쿼리 |
| `trips.controller.ts` | 1 | 보호자 가입 시 `is_guardian = TRUE` 설정 |

#### traveler_user_id 사용 위치 (5개 파일)

| 파일 | 핵심 로직 |
|------|----------|
| `guardian.service.ts` | 보호자↔여행자 매핑 전체 |
| `groups.service.ts` | 멤버 목록 반환 시 포함 |
| `event-notification.service.ts` | 보호자 알림 수신자 필터 |
| `trips.controller.ts` | 보호자 가입 시 설정 |
| `groups.controller.ts` | 멤버 관리 |

### 2.5 현재 Flutter 상태

#### UserRole Enum (user.dart)
```dart
enum UserRole {
  traveler, // 여행자
  guardian, // 보호자
}
```

#### AppCache (app_cache.dart)
- SharedPreferences 키: `user_id`, `user_name`, `user_role`, `phone_number`, `group_id`
- `user_role`은 `'traveler'` 또는 `'guardian'` 문자열

#### Guardian 전용 API (api_service.dart — 13개 메서드)
```
getTravelers()                    → /api/v1/guardians/:id/travelers
verifyGuardianInviteCode()        → /api/v1/guardians/verify-code/:code
verifyGuardianPhone()             → /api/v1/guardians/verify-phone
getGuardianInviteCodeByTrip()     → /api/v1/trips/guardian-invite/:code
joinTripAsGuardian()              → /api/v1/trips/guardian-join
requestGuardianApproval()         → /api/v1/trips/guardian-approval/request
checkGuardianApprovalStatus()     → /api/v1/trips/guardian-approval/status
getGuardianPendingApprovals()     → /api/v1/trips/guardian-approval/pending
approveGuardianRequest()          → /api/v1/trips/guardian-approval/:id/approve
rejectGuardianRequest()           → /api/v1/trips/guardian-approval/:id/reject
cancelGuardianApproval()          → /api/v1/trips/guardian-approval/cancel
(geofence notify_guardians)       → 지오펜스 생성 시 보호자 알림 옵션
```

#### GuardianFilter (guardian_filter.dart)
- `is_guardian` 필드 직접 참조하여 클라이언트 측 멤버 필터링
- `traveler_user_id` 필드 참조

#### InviteModal (invite_modal.dart)
- 현재: 전화번호 입력 + 기존 invite_code/invite_link 표시
- 역할 선택 UI 없음

---

## 3. 목표 상태 설계 (TO-BE)

### 3.1 4-tier 역할 시스템

```
leader    → 그룹 소유자 (1명, 양도 가능)
full      → 공동관리자 (리더와 동등한 관리 권한)
normal    → 일반 여행자 (기본 역할)
view_only → 모니터링 전용 (기존 guardian 통합)
```

### 3.2 역할 매핑 (AS-IS → TO-BE)

| AS-IS | TO-BE | 비고 |
|-------|-------|------|
| `is_admin = TRUE` + `owner_user_id` | `leader` | 그룹 생성자 |
| `is_admin = TRUE` + NOT owner | `full` | 공동 관리자 |
| `is_guardian = FALSE` + `is_admin = FALSE` | `normal` | 일반 여행자 |
| `is_guardian = TRUE` | `view_only` | 보호자 → 모니터링 전용 |
| TB_GUARDIAN (독립 테이블) | TB_GROUP_MEMBER + `view_only` | 테이블 통합 |

### 3.3 목표 TB_GROUP_MEMBER 스키마

```sql
CREATE TABLE TB_GROUP_MEMBER (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- ✅ 새 역할 시스템
    member_role VARCHAR(20) NOT NULL DEFAULT 'normal'
        CHECK (member_role IN ('leader', 'full', 'normal', 'view_only')),

    -- ✅ 기존 세부 권한 유지 (역할과 독립적으로 세밀한 제어)
    can_edit_schedule BOOLEAN DEFAULT FALSE,
    can_edit_geofence BOOLEAN DEFAULT FALSE,
    can_view_all_locations BOOLEAN DEFAULT TRUE,
    can_attendance_check BOOLEAN DEFAULT TRUE,

    -- ✅ 위치 공유 마스터 스위치
    location_sharing_enabled BOOLEAN DEFAULT TRUE,

    -- ✅ view_only 전용 (기존 guardian 필드 흡수)
    traveler_user_id VARCHAR(128) REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 상태
    status VARCHAR(20) DEFAULT 'active',
    joined_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMPTZ,

    -- ⛔ 삭제 예정 (마이그레이션 완료 후)
    -- is_admin BOOLEAN (Phase 3에서 DROP)
    -- is_guardian BOOLEAN (Phase 3에서 DROP)

    UNIQUE(group_id, user_id)
);
```

---

## 4. 역할 시스템 상세 설계

### 4.1 권한 매트릭스

| 권한 | leader | full | normal | view_only |
|------|--------|------|--------|-----------|
| 멤버 초대 (초대코드 생성) | ✅ | ✅ | ❌ | ❌ |
| 멤버 제거 | ✅ | ✅ | ❌ | ❌ |
| 역할 변경 (normal↔view_only) | ✅ | ✅ | ❌ | ❌ |
| full 승격/해제 | ✅ | ❌ | ❌ | ❌ |
| 리더 양도 | ✅ | ❌ | ❌ | ❌ |
| 일정 편집 | ✅ | ✅ | ⚙️ | ❌ |
| 지오펜스 편집 | ✅ | ✅ | ⚙️ | ❌ |
| 공지 작성 | ✅ | ✅ | ❌ | ❌ |
| 위치 조회 (전체) | ✅ | ✅ | ⚙️ | 🔒 |
| 출석체크 시작 | ✅ | ✅ | ❌ | ❌ |
| 그룹 채팅 | ✅ | ✅ | ✅ | ❌ |
| SOS 수신 | ✅ | ✅ | ✅ | ✅ |
| 위치 공유 마스터 ON/OFF | ✅ | ✅ | ✅ | ✅ |

- ⚙️ = `can_edit_schedule` / `can_edit_geofence` / `can_view_all_locations` 개별 권한에 따라
- 🔒 = `traveler_user_id`가 지정된 경우 해당 여행자만, NULL이면 전체

### 4.2 역할 전환 규칙

```
normal → full       : leader만 가능
full → normal       : leader만 가능
normal → view_only  : leader, full 가능
view_only → normal  : leader, full 가능
full → leader       : ⛔ 리더 양도 프로세스를 통해서만
leader → full       : 리더 양도 시 자동 전환 (양도자)
leader → (탈퇴)     : ⛔ 불가 (먼저 양도 필요)
```

### 4.3 역할별 기본 세부 권한

| 역할 | can_edit_schedule | can_edit_geofence | can_view_all_locations | can_attendance_check |
|------|:-:|:-:|:-:|:-:|
| leader | TRUE | TRUE | TRUE | TRUE |
| full | TRUE | TRUE | TRUE | TRUE |
| normal | FALSE | FALSE | TRUE | TRUE |
| view_only | FALSE | FALSE | FALSE | TRUE |

---

## 5. 데이터베이스 마이그레이션

### 5.1 Phase 1 — 컬럼 추가 (무중단, 기존 로직 영향 없음)

**플랫폼**: PostgreSQL (AWS RDS)
**위험도**: 🟢 없음 (ADD COLUMN은 기존 쿼리에 영향 없음)

```sql
-- ============================================================================
-- Phase 1: 새 컬럼 추가 (기존 is_admin/is_guardian은 유지)
-- 실행 플랫폼: AWS RDS PostgreSQL
-- ============================================================================
BEGIN;

-- 1-1. TB_GROUP_MEMBER에 member_role 추가
ALTER TABLE TB_GROUP_MEMBER
ADD COLUMN IF NOT EXISTS member_role VARCHAR(20) DEFAULT 'normal';

ALTER TABLE TB_GROUP_MEMBER
ADD CONSTRAINT chk_member_role
CHECK (member_role IN ('leader', 'full', 'normal', 'view_only'));

-- 1-2. location_sharing_enabled 추가
ALTER TABLE TB_GROUP_MEMBER
ADD COLUMN IF NOT EXISTS location_sharing_enabled BOOLEAN DEFAULT TRUE;

-- 1-3. 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_group_members_role
ON TB_GROUP_MEMBER(member_role);

CREATE INDEX IF NOT EXISTS idx_group_members_role_group
ON TB_GROUP_MEMBER(group_id, member_role);

COMMIT;
```

### 5.2 Phase 2 — 데이터 이관 (트랜잭션 내 실행)

**플랫폼**: PostgreSQL (AWS RDS)
**위험도**: 🟡 중간 (데이터 변환, 반드시 트랜잭션)

```sql
-- ============================================================================
-- Phase 2: 데이터 이관 — is_admin/is_guardian → member_role
-- 실행 플랫폼: AWS RDS PostgreSQL
-- ⚠️ 반드시 백업 후 실행
-- ============================================================================
BEGIN;

-- 2-1. leader 설정 (그룹 소유자이면서 is_admin인 멤버)
UPDATE TB_GROUP_MEMBER gm
SET member_role = 'leader'
FROM TB_GROUP g
WHERE gm.group_id = g.group_id
  AND gm.user_id = g.owner_user_id
  AND gm.is_admin = TRUE
  AND gm.status = 'active';

-- 2-2. full 설정 (is_admin이지만 소유자가 아닌 멤버)
UPDATE TB_GROUP_MEMBER gm
SET member_role = 'full'
WHERE gm.is_admin = TRUE
  AND gm.member_role != 'leader'  -- 이미 leader로 설정된 건 제외
  AND gm.status = 'active';

-- 2-3. view_only 설정 (is_guardian인 멤버)
UPDATE TB_GROUP_MEMBER gm
SET member_role = 'view_only'
WHERE gm.is_guardian = TRUE
  AND gm.member_role NOT IN ('leader', 'full')  -- 관리자이면서 보호자인 경우 관리자 유지
  AND gm.status = 'active';

-- 2-4. normal 설정 (나머지)
UPDATE TB_GROUP_MEMBER gm
SET member_role = 'normal'
WHERE gm.member_role = 'normal'  -- DEFAULT값인 경우 (명시적 재설정)
  AND gm.is_admin = FALSE
  AND gm.is_guardian = FALSE
  AND gm.status = 'active';

-- 2-5. leader 없는 그룹 보정 (owner가 멤버에 없는 경우)
-- owner_user_id가 멤버로 존재하면 leader 부여
UPDATE TB_GROUP_MEMBER gm
SET member_role = 'leader'
FROM TB_GROUP g
WHERE gm.group_id = g.group_id
  AND gm.user_id = g.owner_user_id
  AND gm.status = 'active'
  AND NOT EXISTS (
    SELECT 1 FROM TB_GROUP_MEMBER gm2
    WHERE gm2.group_id = g.group_id
    AND gm2.member_role = 'leader'
    AND gm2.status = 'active'
  );

-- 2-6. 그래도 leader 없는 그룹은 가장 오래된 admin을 leader로
UPDATE TB_GROUP_MEMBER
SET member_role = 'leader'
WHERE member_id IN (
    SELECT DISTINCT ON (g.group_id) gm.member_id
    FROM TB_GROUP g
    LEFT JOIN TB_GROUP_MEMBER gm ON g.group_id = gm.group_id AND gm.status = 'active'
    WHERE NOT EXISTS (
        SELECT 1 FROM TB_GROUP_MEMBER gm2
        WHERE gm2.group_id = g.group_id
        AND gm2.member_role = 'leader'
        AND gm2.status = 'active'
    )
    AND gm.member_id IS NOT NULL
    ORDER BY g.group_id, gm.joined_at ASC
);

-- 2-7. TB_GUARDIAN → TB_GROUP_MEMBER 통합 (accepted 상태만)
-- 이미 TB_GROUP_MEMBER에 존재하는 보호자는 역할만 업데이트
-- TB_GROUP_MEMBER에 없는 보호자는 INSERT
-- ※ TB_GUARDIAN.trip_id → TB_TRIP.group_id를 통해 group_id 매핑

INSERT INTO TB_GROUP_MEMBER (group_id, user_id, member_role, traveler_user_id, status, joined_at)
SELECT DISTINCT
    t.group_id,
    g.guardian_user_id,
    'view_only',
    g.traveler_user_id,
    'active',
    COALESCE(g.accepted_at, g.created_at)
FROM TB_GUARDIAN g
JOIN TB_TRIP t ON g.trip_id = t.trip_id
WHERE g.invite_status = 'accepted'
  AND g.guardian_user_id IS NOT NULL
  AND t.group_id IS NOT NULL
ON CONFLICT (group_id, user_id) DO UPDATE SET
    member_role = CASE
        WHEN EXCLUDED.member_role = 'view_only'
         AND TB_GROUP_MEMBER.member_role NOT IN ('leader', 'full')
        THEN 'view_only'
        ELSE TB_GROUP_MEMBER.member_role  -- 기존 관리자 역할 유지
    END,
    traveler_user_id = COALESCE(EXCLUDED.traveler_user_id, TB_GROUP_MEMBER.traveler_user_id);

-- 2-8. 검증 쿼리
DO $$
DECLARE
    groups_without_leader INT;
    mismatched_roles INT;
BEGIN
    -- leader 없는 활성 그룹 확인
    SELECT COUNT(*) INTO groups_without_leader
    FROM TB_GROUP g
    WHERE g.status = 'active'
    AND NOT EXISTS (
        SELECT 1 FROM TB_GROUP_MEMBER gm
        WHERE gm.group_id = g.group_id
        AND gm.member_role = 'leader'
        AND gm.status = 'active'
    )
    AND EXISTS (
        SELECT 1 FROM TB_GROUP_MEMBER gm
        WHERE gm.group_id = g.group_id
        AND gm.status = 'active'
    );

    IF groups_without_leader > 0 THEN
        RAISE WARNING 'WARNING: % active groups have no leader', groups_without_leader;
    END IF;

    -- is_admin=TRUE인데 member_role이 leader/full이 아닌 건 확인
    SELECT COUNT(*) INTO mismatched_roles
    FROM TB_GROUP_MEMBER
    WHERE is_admin = TRUE
    AND member_role NOT IN ('leader', 'full')
    AND status = 'active';

    IF mismatched_roles > 0 THEN
        RAISE WARNING 'WARNING: % records have is_admin=TRUE but role is not leader/full', mismatched_roles;
    END IF;
END $$;

COMMIT;
```

### 5.3 Phase 3 — 레거시 컬럼 제거 (백엔드 전환 완료 후)

**플랫폼**: PostgreSQL (AWS RDS)
**위험도**: 🔴 높음 (반드시 모든 코드가 member_role 기반으로 전환된 후)
**시점**: 백엔드 + Flutter 코드 전환 완료 + 충분한 검증 후

```sql
-- ============================================================================
-- Phase 3: 레거시 컬럼 삭제
-- ⚠️ 반드시 모든 코드가 member_role 기반으로 전환되었는지 확인 후 실행
-- ⚠️ Phase 2 완료 후 최소 1주 모니터링 후 실행 권장
-- ============================================================================
BEGIN;

-- 3-1. 레거시 인덱스 삭제
DROP INDEX IF EXISTS idx_group_members_is_admin;
DROP INDEX IF EXISTS idx_group_members_is_guardian;

-- 3-2. 레거시 컬럼 삭제
ALTER TABLE TB_GROUP_MEMBER DROP COLUMN IF EXISTS is_admin;
ALTER TABLE TB_GROUP_MEMBER DROP COLUMN IF EXISTS is_guardian;

-- 3-3. TB_GUARDIAN 테이블 보존 (참조용, rename)
ALTER TABLE TB_GUARDIAN RENAME TO TB_GUARDIAN_LEGACY;
-- ※ 완전 삭제는 6개월 후 권장

COMMIT;
```

### 5.4 새 테이블: TB_INVITE_CODE

**플랫폼**: PostgreSQL (AWS RDS)

```sql
-- ============================================================================
-- 초대코드 테이블 (Phase 1에서 함께 생성)
-- ============================================================================
CREATE TABLE TB_INVITE_CODE (
    invite_code_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,

    -- 코드 정보
    code VARCHAR(7) NOT NULL UNIQUE,  -- Prefix(1) + Random(6) = 7자
    target_role VARCHAR(20) NOT NULL DEFAULT 'normal'
        CHECK (target_role IN ('full', 'normal', 'view_only')),

    -- 제한
    max_uses INTEGER DEFAULT 50,
    used_count INTEGER DEFAULT 0,

    -- 유효기간
    expires_at TIMESTAMPTZ NOT NULL,

    -- 생성자
    created_by VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id),

    -- 상태
    is_active BOOLEAN DEFAULT TRUE,

    -- 메타데이터
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_used_count CHECK (used_count <= max_uses)
);

CREATE INDEX idx_invite_code_code ON TB_INVITE_CODE(code) WHERE is_active = TRUE;
CREATE INDEX idx_invite_code_group ON TB_INVITE_CODE(group_id);
CREATE INDEX idx_invite_code_expires ON TB_INVITE_CODE(expires_at);

COMMENT ON TABLE TB_INVITE_CODE IS '역할별 초대코드 관리';
COMMENT ON COLUMN TB_INVITE_CODE.code IS '형식: Prefix(A=full, M=normal, V=view_only) + 6자리 랜덤 영숫자';
COMMENT ON COLUMN TB_INVITE_CODE.target_role IS '이 코드로 가입 시 부여되는 역할';
```

### 5.5 새 테이블: TB_LOCATION_SHARING

**플랫폼**: PostgreSQL (AWS RDS)

```sql
-- ============================================================================
-- 위치 공유 관계 테이블 (Phase 1에서 함께 생성)
-- ============================================================================
CREATE TABLE TB_LOCATION_SHARING (
    sharing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,

    -- 공유 방향: user → target
    user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,
    target_user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id) ON DELETE CASCADE,

    -- 상태
    is_sharing BOOLEAN DEFAULT TRUE,

    -- 메타데이터
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(group_id, user_id, target_user_id)
);

CREATE INDEX idx_location_sharing_user ON TB_LOCATION_SHARING(group_id, user_id) WHERE is_sharing = TRUE;
CREATE INDEX idx_location_sharing_target ON TB_LOCATION_SHARING(group_id, target_user_id) WHERE is_sharing = TRUE;

COMMENT ON TABLE TB_LOCATION_SHARING IS '멤버 간 위치 공유 관계 (2-layer: 마스터 스위치 + 개별 설정)';
COMMENT ON COLUMN TB_LOCATION_SHARING.is_sharing IS 'user가 target에게 자기 위치를 공유하는지 여부';
```

### 5.6 새 테이블: TB_LEADER_TRANSFER_LOG

**플랫폼**: PostgreSQL (AWS RDS)

```sql
-- ============================================================================
-- 리더 양도 이력 테이블 (Phase 1에서 함께 생성)
-- ============================================================================
CREATE TABLE TB_LEADER_TRANSFER_LOG (
    transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES TB_GROUP(group_id) ON DELETE CASCADE,
    from_user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id),
    to_user_id VARCHAR(128) NOT NULL REFERENCES TB_USER(user_id),
    transferred_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_leader_transfer_group ON TB_LEADER_TRANSFER_LOG(group_id);
```

---

## 6. 백엔드 변경 상세 (파일별)

### 6.1 `permission.service.ts` — 🔴 필수 변경

**파일**: `safetrip-server-api/src/services/permission.service.ts` (102줄)
**변경량**: 쿼리 2개 수정

#### 변경 1: `isGroupAdmin()` (Line ~33)
```typescript
// AS-IS
const result = await db.query(
  `SELECT member_id FROM tb_group_member
   WHERE group_id = $1 AND user_id = $2 AND is_admin = TRUE AND status = 'active'`,
  [groupId, userId]
);

// TO-BE
const result = await db.query(
  `SELECT member_id FROM tb_group_member
   WHERE group_id = $1 AND user_id = $2
   AND member_role IN ('leader', 'full') AND status = 'active'`,
  [groupId, userId]
);
```

#### 변경 2: `getGroupMemberRole()` (Line ~57)
```typescript
// AS-IS
const result = await db.query(
  `SELECT is_admin, is_guardian FROM tb_group_member
   WHERE group_id = $1 AND user_id = $2 AND status = 'active'`,
  [groupId, userId]
);
if (result.rows.length === 0) return null;
const { is_admin, is_guardian } = result.rows[0];
if (is_admin) return 'admin';
if (is_guardian) return 'guardian';
return 'traveler';

// TO-BE
const result = await db.query(
  `SELECT member_role FROM tb_group_member
   WHERE group_id = $1 AND user_id = $2 AND status = 'active'`,
  [groupId, userId]
);
if (result.rows.length === 0) return null;
return result.rows[0].member_role; // 'leader'|'full'|'normal'|'view_only'
```

#### 추가: 새 헬퍼 메서드들
```typescript
// 권한 레벨 체크 (leader/full만 가능한 작업용)
async canManageGroup(groupId: string, userId: string): Promise<boolean> {
  const result = await db.query(
    `SELECT member_id FROM tb_group_member
     WHERE group_id = $1 AND user_id = $2
     AND member_role IN ('leader', 'full') AND status = 'active'`,
    [groupId, userId]
  );
  return result.rows.length > 0;
}

// leader 전용 작업 체크
async isGroupLeader(groupId: string, userId: string): Promise<boolean> {
  const result = await db.query(
    `SELECT member_id FROM tb_group_member
     WHERE group_id = $1 AND user_id = $2
     AND member_role = 'leader' AND status = 'active'`,
    [groupId, userId]
  );
  return result.rows.length > 0;
}
```

### 6.2 `user.service.ts` — 🔴 필수 변경

**파일**: `safetrip-server-api/src/services/user.service.ts` (311줄)
**변경량**: 동일 패턴 4곳 → 1개 공통 함수로 추출 (DRY 개선)

#### AS-IS (4개 메서드에 동일 코드 반복)
```typescript
// getUserById(), getOrCreateUserFromFirebase(), getUserByPhoneNumber(), updateUser()
// 모두 동일한 패턴:
const roleResult = await db.query(
  `SELECT is_guardian FROM tb_group_member
   WHERE user_id = $1 AND status = 'active' AND is_guardian = TRUE LIMIT 1`,
  [userId]
);
const user_role = roleResult.rows.length > 0 ? 'guardian' : 'traveler';
```

#### TO-BE (공통 함수 추출)
```typescript
// 새 private helper
private async _determineUserRole(db: any, userId: string): Promise<string> {
  const result = await db.query(
    `SELECT member_role FROM tb_group_member
     WHERE user_id = $1 AND status = 'active'
     ORDER BY CASE member_role
       WHEN 'leader' THEN 1
       WHEN 'full' THEN 2
       WHEN 'normal' THEN 3
       WHEN 'view_only' THEN 4
     END ASC LIMIT 1`,
    [userId]
  );
  if (result.rows.length === 0) return 'traveler';
  const role = result.rows[0].member_role;
  return role === 'view_only' ? 'guardian' : 'traveler';
  // ※ 하위호환: Flutter가 'guardian'/'traveler'를 기대하므로 매핑
  // Flutter 업데이트 후 실제 member_role 반환으로 전환
}
```

**하위호환 주의**: Flutter의 `UserRole` enum이 `traveler`/`guardian`만 있으므로, API 응답에서는 `view_only` → `'guardian'`으로 매핑하여 반환. Flutter 업데이트 후 단계적으로 실제 역할명으로 전환.

### 6.3 `event-notification.service.ts` — 🔴 필수 변경

**파일**: `safetrip-server-api/src/services/event-notification.service.ts` (1175줄)
**변경량**: `_getRecipients()` 메서드 내 쿼리 2개 수정

#### 변경 1: `notify_guardians` 수신자 쿼리 (Line ~493)
```sql
-- AS-IS
AND gm.is_guardian = TRUE
AND (gm.traveler_user_id = $2 OR gm.traveler_user_id IS NULL)

-- TO-BE
AND gm.member_role = 'view_only'
AND (gm.traveler_user_id = $2 OR gm.traveler_user_id IS NULL)
```

#### 변경 2: `notify_admins` 수신자 쿼리 (Line ~516)
```sql
-- AS-IS
AND gm.is_admin = TRUE

-- TO-BE
AND gm.member_role IN ('leader', 'full')
```

**event-notification-config.ts는 변경 불필요**: `notify_guardians`, `notify_admins` 등의 설정 필드명은 그대로 유지. 이들은 개념적 수신자 그룹 이름이며, 실제 SQL 쿼리만 변경.

### 6.4 `groups.service.ts` — 🔴 필수 변경 (최대 규모)

**파일**: `safetrip-server-api/src/services/groups.service.ts`
**변경량**: 30+ 참조 변경

#### 주요 변경 패턴

**패턴 A: 멤버 조회 SELECT 문** (is_admin, is_guardian 반환)
```sql
-- AS-IS
SELECT gm.*, gm.is_admin, gm.is_guardian, gm.traveler_user_id ...

-- TO-BE (하위호환 유지)
SELECT gm.*, gm.member_role,
  CASE WHEN gm.member_role IN ('leader', 'full') THEN TRUE ELSE FALSE END as is_admin,
  CASE WHEN gm.member_role = 'view_only' THEN TRUE ELSE FALSE END as is_guardian,
  gm.traveler_user_id ...
```
> ⚠️ **하위호환**: `is_admin`과 `is_guardian`을 가상 컬럼으로 반환하여 Flutter가 점진적으로 마이그레이션할 수 있도록 함

**패턴 B: 멤버 INSERT 문** (새 멤버 추가)
```sql
-- AS-IS
INSERT INTO tb_group_member (group_id, user_id, is_admin, is_guardian, ...)
VALUES ($1, $2, FALSE, FALSE, ...)

-- TO-BE
INSERT INTO tb_group_member (group_id, user_id, member_role, ...)
VALUES ($1, $2, 'normal', ...)
```

**패턴 C: 관리자 권한 체크**
```sql
-- AS-IS
WHERE gm.is_admin = TRUE

-- TO-BE
WHERE gm.member_role IN ('leader', 'full')
```

**패턴 D: 보호자 필터링 (멤버 목록에서 보호자 제외)**
```sql
-- AS-IS
AND gm.is_guardian = FALSE

-- TO-BE
AND gm.member_role != 'view_only'
```

**패턴 E: `checkMemberPermission()` 반환값**
```typescript
// AS-IS (Line ~429)
hasRequiredPermission: member.is_admin

// TO-BE
hasRequiredPermission: ['leader', 'full'].includes(member.member_role)
```

**패턴 F: `joinGroupByInviteCode()` — 초대코드 가입 확장**
```typescript
// AS-IS: TB_GROUP.invite_code로 가입, is_admin = FALSE로 INSERT

// TO-BE: 2가지 경로
// 경로 1: 기존 TB_GROUP.invite_code → member_role = 'normal'
// 경로 2: TB_INVITE_CODE.code → member_role = target_role
```

### 6.5 `groups.controller.ts` — 🔴 필수 변경

**파일**: `safetrip-server-api/src/controllers/groups.controller.ts`
**변경량**: 15+ 참조 변경

#### 주요 변경점
1. `joinGroupByInviteCode` — TB_INVITE_CODE 조회 로직 추가
2. `updateMemberPermissions` — `is_admin` → `member_role` 파라미터 변경
3. `inviteGroupMember` — 역할 지정 파라미터 추가
4. 모든 권한 체크 — `is_admin` → `member_role IN ('leader', 'full')`

### 6.6 `trips.controller.ts` — 🟡 변경 필요

**파일**: `safetrip-server-api/src/controllers/trips.controller.ts`
**변경량**: 5 참조 변경

| Line | AS-IS | TO-BE |
|------|-------|-------|
| ~205 | `is_admin: true` (그룹 생성자) | `member_role: 'leader'` |
| ~414 | `is_admin: false` (일반 가입) | `member_role: 'normal'` |
| ~488 | `is_admin: false` (일반 가입) | `member_role: 'normal'` |
| ~498 | `is_guardian = TRUE` (보호자 가입) | `member_role: 'view_only'` |
| ~897,941 | `!permission.is_admin` | `!['leader','full'].includes(permission.member_role)` |

### 6.7 `traveler.service.ts` — 🟡 변경 필요

**파일**: `safetrip-server-api/src/services/traveler.service.ts`
**변경량**: 1 참조 변경

```sql
-- AS-IS (Line ~17)
INSERT INTO tb_group_member (..., is_admin, ...) VALUES (..., $X, ...)

-- TO-BE
INSERT INTO tb_group_member (..., member_role, ...) VALUES (..., $X, ...)
```

### 6.8 `schedule.service.ts` — 🟡 변경 필요

**파일**: `safetrip-server-api/src/services/schedule.service.ts`
**변경량**: 2 참조 변경

```typescript
// AS-IS (Lines ~501, ~848)
!permission.can_edit_schedule && !permission.is_admin

// TO-BE
!permission.can_edit_schedule && !['leader', 'full'].includes(permission.member_role)
```

### 6.9 `guardian.service.ts` — 🟠 단계적 deprecation

**파일**: `safetrip-server-api/src/services/guardian.service.ts` (270줄)
**전략**: Phase 2 동안 기존 기능 유지, Phase 3 이후 점진적 제거

- `createGuardianInvite()` → 새 `inviteCodeService.createInviteCode(targetRole='view_only')` 로 대체
- `getGuardianByInviteCode()` → TB_INVITE_CODE 기반으로 전환
- `verifyGuardianInviteCode()` → 기존 코드 하위호환 유지 + 새 시스템 병행
- `verifyGuardianPhone()` → 보호자 가입 워크플로우에서 유지 (view_only 역할로 변경)

### 6.10 새 파일: `invite-code.service.ts`

```typescript
// safetrip-server-api/src/services/invite-code.service.ts
export const inviteCodeService = {
  // 초대코드 생성 (leader/full만 가능)
  async createInviteCode(params: {
    groupId: string;
    createdBy: string;
    targetRole: 'full' | 'normal' | 'view_only';
    maxUses?: number;     // default: 50
    expiresInDays?: number; // default: 7
  }): Promise<{ code: string; expires_at: string }>,

  // 초대코드 검증 및 사용
  async useInviteCode(code: string, userId: string): Promise<{
    groupId: string;
    targetRole: string;
    success: boolean;
    error?: string;
  }>,

  // 초대코드 비활성화
  async deactivateInviteCode(codeId: string): Promise<void>,

  // 그룹별 초대코드 목록
  async getInviteCodesByGroup(groupId: string): Promise<InviteCode[]>,
};
```

### 6.11 새 파일: `leader-transfer.service.ts`

```typescript
// safetrip-server-api/src/services/leader-transfer.service.ts
export const leaderTransferService = {
  // 리더 양도 실행 (트랜잭션)
  async transferLeadership(params: {
    groupId: string;
    fromUserId: string;  // 현재 leader
    toUserId: string;    // 대상 (반드시 full 역할)
  }): Promise<{ success: boolean; error?: string }>,

  // 양도 이력 조회
  async getTransferHistory(groupId: string): Promise<TransferLog[]>,
};
```

### 6.12 새 라우트 파일들

```typescript
// safetrip-server-api/src/routes/invite-codes.routes.ts
router.post('/:group_id/invite-codes', inviteCodesController.createInviteCode);
router.get('/:group_id/invite-codes', inviteCodesController.getInviteCodes);
router.delete('/:group_id/invite-codes/:code_id', inviteCodesController.deactivateInviteCode);
router.post('/join/:code', inviteCodesController.joinByInviteCode);

// safetrip-server-api/src/routes/leader-transfer.routes.ts
router.post('/:group_id/transfer-leadership', leaderTransferController.transferLeadership);
router.get('/:group_id/transfer-history', leaderTransferController.getTransferHistory);
```

---

## 7. Flutter 변경 상세 (파일별)

### 7.1 `models/user.dart` — 🔴 필수 변경

```dart
// AS-IS
enum UserRole {
  traveler,
  guardian,
}

// TO-BE (하위호환 유지)
enum UserRole {
  leader,
  full,
  normal,
  view_only,
  traveler,   // ⚠️ 하위호환 (서버가 'traveler' 반환 시)
  guardian,   // ⚠️ 하위호환 (서버가 'guardian' 반환 시)
}

extension UserRoleExtension on UserRole {
  bool get isAdmin => this == UserRole.leader || this == UserRole.full;
  bool get isGuardian => this == UserRole.view_only || this == UserRole.guardian;
  bool get isTraveler => this == UserRole.normal || this == UserRole.traveler;

  // 하위호환 매핑
  static UserRole fromString(String role) {
    switch (role) {
      case 'leader': return UserRole.leader;
      case 'full': return UserRole.full;
      case 'normal': return UserRole.normal;
      case 'view_only': return UserRole.view_only;
      case 'guardian': return UserRole.guardian; // 레거시
      case 'traveler': return UserRole.traveler; // 레거시
      default: return UserRole.normal;
    }
  }
}
```

### 7.2 `utils/app_cache.dart` — 🟡 변경 필요

```dart
// user_role 저장값 확장
// AS-IS: 'traveler' | 'guardian'
// TO-BE: 'leader' | 'full' | 'normal' | 'view_only' | 'traveler' | 'guardian'
// ※ SharedPreferences key는 동일 ('user_role')
// ※ 값만 확장, 기존 캐시된 값은 UserRoleExtension.fromString()으로 안전하게 처리
```

### 7.3 `utils/guardian_filter.dart` — 🟡 변경 필요

```dart
// AS-IS
final isGuardian = currentUserMember['is_guardian'] == true;

// TO-BE (하위호환)
final isGuardian = currentUserMember['is_guardian'] == true
    || currentUserMember['member_role'] == 'view_only';
```
> 서버가 하위호환 필드(`is_guardian`)를 반환하는 동안은 양쪽 모두 체크

### 7.4 `screens/auth/screen_4_role.dart` — 🟡 변경 필요

역할 선택 화면에서 새 역할 시스템 반영 (해당되는 경우)

### 7.5 `services/api_service.dart` — 🟠 단계적 변경 (대규모)

#### 즉시 추가할 새 API 메서드
```dart
// 초대코드 생성
Future<Map<String, dynamic>> createInviteCode({
  required String groupId,
  required String targetRole,  // 'full' | 'normal' | 'view_only'
  int? maxUses,
  int? expiresInDays,
});

// 새 초대코드로 가입
Future<Map<String, dynamic>> joinByInviteCode(String code);

// 리더 양도
Future<Map<String, dynamic>> transferLeadership({
  required String groupId,
  required String toUserId,
});

// 카카오톡 공유
Future<void> shareInviteCodeViaKakao({
  required String code,
  required String groupName,
  required String targetRole,
});
```

#### 점진적 deprecation 대상 (13개 guardian API 메서드)
```dart
// Phase 2 동안 유지, Phase 3 이후 제거
@Deprecated('Use joinByInviteCode() instead')
Future<Map<String, dynamic>> joinTripAsGuardian(...);

@Deprecated('Use createInviteCode(targetRole: "view_only") instead')
Future<Map<String, dynamic>> requestGuardianApproval(...);
// ... 나머지 11개 메서드
```

### 7.6 `screens/main/bottom_sheets/modals/invite_modal.dart` — 🔴 전면 개편

```dart
// TO-BE: 역할별 초대코드 생성 + 카카오톡 공유 UI
class InviteModal extends StatefulWidget {
  // 기존: inviteCode, inviteLink
  // 추가: 역할 선택 UI, 초대코드 생성 버튼, 카카오 공유 버튼

  // UI 구성:
  // 1. 역할 선택 (라디오: 공동관리자/일반멤버/모니터링전용)
  // 2. 초대코드 생성 버튼
  // 3. 생성된 코드 표시
  // 4. 공유 방법 선택 (복사 / 카카오톡 / 일반 공유)
}
```

### 7.7 위치 관련 파일들 (location_service.dart, firebase_location_service.dart)

- `location_sharing_enabled` SharedPreferences 키는 기존 그대로 유지
- 서버에서 `TB_GROUP_MEMBER.location_sharing_enabled` 마스터 스위치와 동기화
- per-member 공유 제어는 TB_LOCATION_SHARING + Firebase RTDB 연동

---

## 8. Firebase 변경 상세

### 8.1 Firebase Auth — 변경 없음

Firebase Auth는 전화번호 인증만 담당하며, 역할/권한 정보는 PostgreSQL에서 관리.
**UID 형식**: 28자 영숫자 문자열 (예: `aBcDeFgHiJkLmNoPqRsTuVwXyZ12`)

### 8.2 Firebase Realtime Database (RTDB) — 🟡 구조 확장

**현재 RTDB 구조** (위치 공유 상태):
```json
{
  "users": {
    "{userId}": {
      "location_sharing_enabled": true,
      "geofencing_enabled": true,
      "last_location": { ... },
      "battery_level": 85,
      ...
    }
  }
}
```

**추가할 RTDB 구조** (위치 공유 관계):
```json
{
  "location_sharing": {
    "{groupId}": {
      "{userId}": {
        "master_enabled": true,
        "sharing_with": {
          "{targetUserId}": true,
          "{targetUserId2}": true
        }
      }
    }
  }
}
```

**Firebase RTDB Rules 변경**:
```json
{
  "rules": {
    "location_sharing": {
      "$groupId": {
        "$userId": {
          ".read": "auth != null",
          ".write": "auth.uid === $userId"
        }
      }
    }
  }
}
```

**변경 플랫폼**: Firebase Console → Realtime Database → Rules

### 8.3 Firebase Cloud Messaging (FCM) — 변경 없음

푸시 알림 자체는 변경 없음. 수신자 결정 로직이 백엔드(`event-notification.service.ts`)에 있으므로 백엔드 변경으로 자동 반영.

### 8.4 Firebase Storage — 변경 없음

---

## 9. 초대코드 시스템 설계

### 9.1 코드 형식

```
[Prefix][6-digit Random]
 └ 1자   └ 6자 (A-Z, 0-9)

Prefix:
  A = full (Admin, 공동관리자)
  M = normal (Member, 일반멤버)
  V = view_only (Viewer, 모니터링전용)

예시:
  A7K3M9X → full 역할 초대
  M2J8N4P → normal 역할 초대
  VQ5R1T6 → view_only 역할 초대
```

### 9.2 코드 생성 알고리즘

```typescript
function generateInviteCode(targetRole: string): string {
  const prefixMap: Record<string, string> = {
    'full': 'A',
    'normal': 'M',
    'view_only': 'V',
  };
  const prefix = prefixMap[targetRole] || 'M';
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = prefix;
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code; // 7자
}
```

### 9.3 코드 사용 플로우

```
1. Leader/Full이 초대코드 생성
   POST /api/v1/groups/:groupId/invite-codes
   { targetRole: 'normal', maxUses: 50, expiresInDays: 7 }

2. 코드 공유 (복사/카카오톡/일반공유)

3. 수신자가 코드 입력
   POST /api/v1/groups/join/:code

4. 서버 검증:
   a. TB_INVITE_CODE에서 code 조회
   b. is_active = TRUE 확인
   c. used_count < max_uses 확인
   d. expires_at > NOW() 확인
   e. 이미 가입된 멤버인지 확인

5. 가입 처리:
   a. TB_GROUP_MEMBER INSERT (member_role = target_role)
   b. TB_INVITE_CODE.used_count += 1
   c. TB_LOCATION_SHARING 초기화 (전체 멤버와 양방향 공유)
   d. Firebase RTDB 동기화
```

### 9.4 기존 TB_GROUP.invite_code와의 관계

| 항목 | TB_GROUP.invite_code | TB_INVITE_CODE |
|------|---------------------|----------------|
| 용도 | 그룹 고유 코드 (변경 불가) | 역할별 초대 코드 (다수 생성 가능) |
| 역할 | 항상 `normal` | `full` / `normal` / `view_only` |
| 만료 | 없음 | 기본 7일 |
| 사용 제한 | 없음 | 기본 50회 |
| 생존 | **유지** (하위호환) | 신규 |

> 기존 `TB_GROUP.invite_code`는 그룹 식별 목적으로 유지. 새 시스템은 `TB_INVITE_CODE` 사용.

---

## 10. 리더 양도 기능 설계

### 10.1 양도 조건

```
전제:
  - 요청자 = 현재 leader
  - 대상자 = 현재 full 역할 + active 상태

불가:
  - normal/view_only에게 직접 양도 불가
  - 그룹에 full 멤버가 없으면 양도 불가 (먼저 승격 필요)
```

### 10.2 양도 프로세스 (단일 트랜잭션)

```sql
BEGIN;

-- 1. 대상자가 full인지 확인
SELECT member_role FROM tb_group_member
WHERE group_id = $1 AND user_id = $2 AND member_role = 'full' AND status = 'active';

-- 2. 현재 leader를 full로 변경
UPDATE tb_group_member SET member_role = 'full'
WHERE group_id = $1 AND user_id = $3 AND member_role = 'leader';

-- 3. 대상자를 leader로 변경
UPDATE tb_group_member SET member_role = 'leader'
WHERE group_id = $1 AND user_id = $2 AND member_role = 'full';

-- 4. TB_GROUP.owner_user_id 변경
UPDATE tb_group SET owner_user_id = $2
WHERE group_id = $1;

-- 5. 양도 이력 기록
INSERT INTO tb_leader_transfer_log (group_id, from_user_id, to_user_id)
VALUES ($1, $3, $2);

COMMIT;
```

### 10.3 API

```
POST /api/v1/groups/:groupId/transfer-leadership
Authorization: Bearer {token}
Body: { "to_user_id": "firebase-uid-string" }

Response 200:
{
  "success": true,
  "message": "리더 권한이 양도되었습니다",
  "new_leader": { "user_id": "...", "display_name": "..." },
  "previous_leader_role": "full"
}

Error 403: "리더만 양도할 수 있습니다"
Error 400: "대상자가 full 역할이 아닙니다"
```

### 10.4 Flutter UI

```
설정 > 그룹 관리 > 리더 양도
  → full 멤버 목록 표시
  → 선택 후 확인 다이얼로그
  → "정말로 [이름]에게 리더 권한을 양도하시겠습니까?"
  → 양도 완료 후 자신은 full로 전환
```

---

## 11. 위치 공유 관리 설계

### 11.1 2-Layer 모델

```
Layer 1: 마스터 스위치 (TB_GROUP_MEMBER.location_sharing_enabled)
  └ TRUE: 위치 공유 활성화 (기본값)
  └ FALSE: 모든 위치 공유 중단 (Layer 2 무시)

Layer 2: 개별 공유 설정 (TB_LOCATION_SHARING)
  └ user_id → target_user_id 방향의 공유 관계
  └ is_sharing = TRUE/FALSE
```

### 11.2 가입 시 초기화

새 멤버 가입 시:
1. `TB_GROUP_MEMBER.location_sharing_enabled = TRUE` (마스터 ON)
2. `TB_LOCATION_SHARING`에 기존 모든 활성 멤버와 양방향 레코드 생성 (모두 `is_sharing = TRUE`)
3. Firebase RTDB에 `location_sharing/{groupId}/{userId}/master_enabled = true` + `sharing_with` 동기화

```sql
-- 새 멤버(newUserId) 가입 시 위치 공유 초기화
INSERT INTO TB_LOCATION_SHARING (group_id, user_id, target_user_id, is_sharing)
SELECT
    $1,           -- group_id
    $2,           -- 새 멤버 (→ 기존 멤버에게 공유)
    gm.user_id,   -- 기존 멤버
    TRUE
FROM TB_GROUP_MEMBER gm
WHERE gm.group_id = $1 AND gm.status = 'active' AND gm.user_id != $2
UNION ALL
SELECT
    $1,           -- group_id
    gm.user_id,   -- 기존 멤버 (→ 새 멤버에게 공유)
    $2,           -- 새 멤버
    TRUE
FROM TB_GROUP_MEMBER gm
WHERE gm.group_id = $1 AND gm.status = 'active' AND gm.user_id != $2
ON CONFLICT (group_id, user_id, target_user_id) DO NOTHING;
```

### 11.3 위치 조회 권한 판단 로직

```typescript
async canViewLocation(groupId: string, viewerId: string, targetId: string): Promise<boolean> {
  // 1. viewer의 마스터 스위치 확인 (불필요 — viewer는 보는 쪽)
  // 2. target의 마스터 스위치 확인
  const targetMember = await getGroupMember(groupId, targetId);
  if (!targetMember.location_sharing_enabled) return false;

  // 3. target → viewer 방향 공유 설정 확인
  const sharing = await getLocationSharing(groupId, targetId, viewerId);
  if (!sharing || !sharing.is_sharing) return false;

  // 4. view_only의 경우 traveler_user_id 제한 체크
  const viewerMember = await getGroupMember(groupId, viewerId);
  if (viewerMember.member_role === 'view_only' && viewerMember.traveler_user_id) {
    return viewerMember.traveler_user_id === targetId;
  }

  return true;
}
```

---

## 12. 카카오톡 SDK 연동

### 12.1 현재 상태

`pubspec.yaml`에 카카오 SDK **없음**. 신규 통합 필요.

### 12.2 Flutter 설정

#### pubspec.yaml 추가
```yaml
dependencies:
  kakao_flutter_sdk_share: ^1.9.0  # 카카오 공유 (메시지 전송)
  kakao_flutter_sdk_common: ^1.9.0 # 공통 모듈
```

#### Android 설정 (`android/app/src/main/AndroidManifest.xml`)
```xml
<manifest>
  <application>
    <!-- 카카오 SDK -->
    <activity android:name="com.kakao.sdk.flutter.AuthCodeHandlerActivity"
      android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:host="oauth" android:scheme="kakao{NATIVE_APP_KEY}" />
      </intent-filter>
    </activity>
  </application>

  <!-- 카카오톡 앱 쿼리 -->
  <queries>
    <package android:name="com.kakao.talk" />
  </queries>
</manifest>
```

#### iOS 설정 (`ios/Runner/Info.plist`)
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>kakao{NATIVE_APP_KEY}</string>
    </array>
  </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>kakaokompassauth</string>
  <string>kakaolink</string>
  <string>kakaotalk</string>
</array>
```

### 12.3 Kakao Developers 설정

**플랫폼**: [Kakao Developers](https://developers.kakao.com/)

1. 애플리케이션 등록
2. 플랫폼 등록:
   - Android: 패키지명 + 키 해시
   - iOS: 번들 ID
3. 카카오링크(메시지 API) 활성화
4. Native App Key 발급

### 12.4 공유 구현

```dart
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

Future<void> shareInviteViaKakao({
  required String code,
  required String groupName,
  required String targetRole,
}) async {
  final roleLabel = {
    'full': '공동관리자',
    'normal': '일반멤버',
    'view_only': '모니터링전용',
  }[targetRole] ?? '멤버';

  final template = FeedTemplate(
    content: Content(
      title: 'SafeTrip 그룹 초대',
      description: '$groupName 그룹에 $roleLabel(으)로 초대합니다.',
      imageUrl: Uri.parse('https://safetrip.app/assets/invite-card.png'),
      link: Link(
        webUrl: Uri.parse('https://safetrip.app/invite/$code'),
        mobileWebUrl: Uri.parse('https://safetrip.app/invite/$code'),
      ),
    ),
    buttons: [
      Button(
        title: '초대 수락하기',
        link: Link(
          webUrl: Uri.parse('https://safetrip.app/invite/$code'),
          mobileWebUrl: Uri.parse('https://safetrip.app/invite/$code'),
        ),
      ),
    ],
  );

  // 카카오톡 설치 여부 확인
  if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
    await ShareClient.instance.shareDefault(template: template);
  } else {
    // 웹 공유 fallback
    await launchUrl(await WebSharerClient.instance.makeDefaultUrl(template: template));
  }
}
```

### 12.5 초기화

```dart
// main.dart
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 기존 초기화...
  await Firebase.initializeApp();

  // 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '');

  runApp(const SafeTripApp());
}
```

---

## 13. API 설계

### 13.1 새 API 엔드포인트

| Method | Path | 설명 | 권한 |
|--------|------|------|------|
| POST | `/api/v1/groups/:groupId/invite-codes` | 초대코드 생성 | leader, full |
| GET | `/api/v1/groups/:groupId/invite-codes` | 초대코드 목록 | leader, full |
| DELETE | `/api/v1/groups/:groupId/invite-codes/:codeId` | 초대코드 비활성화 | leader, full |
| POST | `/api/v1/groups/join/:code` | 초대코드로 가입 | 인증된 사용자 |
| POST | `/api/v1/groups/:groupId/transfer-leadership` | 리더 양도 | leader |
| GET | `/api/v1/groups/:groupId/transfer-history` | 양도 이력 | leader, full |
| GET | `/api/v1/groups/:groupId/location-sharing` | 공유 설정 조회 | 멤버 |
| PATCH | `/api/v1/groups/:groupId/location-sharing` | 공유 설정 변경 | 멤버 (자기 것만) |
| PATCH | `/api/v1/groups/:groupId/members/:userId/role` | 역할 변경 | leader (full↔normal), leader/full (normal↔view_only) |

### 13.2 기존 API 하위호환 전략

| 기존 API | 변경 | 하위호환 |
|----------|------|---------|
| `GET /groups/:id/members` | 응답에 `member_role` 추가 | `is_admin`/`is_guardian` 가상 필드 유지 |
| `POST /groups/join/:code` | TB_INVITE_CODE 우선 조회 | 못 찾으면 TB_GROUP.invite_code fallback |
| `PATCH /groups/:id/members/:uid` | `member_role` 파라미터 추가 | `is_admin` 파라미터도 계속 수용 |
| `GET /groups/:id/my-permission` | `member_role` 반환 추가 | `is_admin`/`is_guardian` 유지 |
| `GET /users/:id` | `user_role` 매핑 | `view_only` → `'guardian'` 반환 (하위호환) |

---

## 14. 마이그레이션 실행 순서

### Phase 1: 기반 구축 (무중단, 기존 기능 영향 Zero)

```
순서    작업                                          플랫폼          위험도
─────────────────────────────────────────────────────────────────────
1-1    DB 백업                                       AWS RDS         🟢
1-2    TB_GROUP_MEMBER에 member_role 컬럼 추가         AWS RDS         🟢
1-3    TB_GROUP_MEMBER에 location_sharing_enabled 추가  AWS RDS         🟢
1-4    TB_INVITE_CODE 테이블 생성                      AWS RDS         🟢
1-5    TB_LOCATION_SHARING 테이블 생성                  AWS RDS         🟢
1-6    TB_LEADER_TRANSFER_LOG 테이블 생성               AWS RDS         🟢
1-7    인덱스 생성                                     AWS RDS         🟢
1-8    Firebase RTDB Rules 업데이트                     Firebase Console 🟢
```

### Phase 2: 데이터 이관 + 백엔드 전환 (핵심)

```
순서    작업                                          플랫폼          위험도
─────────────────────────────────────────────────────────────────────
2-1    is_admin/is_guardian → member_role 데이터 이관    AWS RDS         🟡
2-2    TB_GUARDIAN → TB_GROUP_MEMBER 통합               AWS RDS         🟡
2-3    검증 쿼리 실행 (leader 없는 그룹 등)              AWS RDS         🟢
2-4    permission.service.ts 변경                      Backend Server  🟡
2-5    user.service.ts 변경 (하위호환 매핑)              Backend Server  🟡
2-6    event-notification.service.ts 변경               Backend Server  🟡
2-7    groups.service.ts 변경 (하위호환 가상필드 포함)     Backend Server  🔴
2-8    groups.controller.ts 변경                       Backend Server  🟡
2-9    trips.controller.ts 변경                        Backend Server  🟡
2-10   schedule.service.ts 변경                        Backend Server  🟡
2-11   traveler.service.ts 변경                        Backend Server  🟡
2-12   invite-code.service.ts 신규 생성                 Backend Server  🟢
2-13   leader-transfer.service.ts 신규 생성             Backend Server  🟢
2-14   새 라우트 등록                                   Backend Server  🟢
2-15   백엔드 배포 + 통합 테스트                         Backend Server  🟡
```

### Phase 3: Flutter 전환

```
순서    작업                                          플랫폼          위험도
─────────────────────────────────────────────────────────────────────
3-1    UserRole enum 확장                              Flutter         🟡
3-2    AppCache 하위호환 처리                            Flutter         🟢
3-3    GuardianFilter 수정                             Flutter         🟢
3-4    api_service.dart 새 메서드 추가                   Flutter         🟢
3-5    InviteModal 전면 개편                            Flutter         🟡
3-6    카카오 SDK 설치 및 설정                            Flutter + 플랫폼 🟡
3-7    리더 양도 UI 구현                                Flutter         🟡
3-8    위치 공유 관리 UI 구현                             Flutter         🟡
3-9    guardian API 메서드 @Deprecated 마킹              Flutter         🟢
3-10   Flutter 앱 빌드 + 테스트                          Flutter         🟡
```

### Phase 4: 정리 (충분한 검증 후)

```
순서    작업                                          플랫폼          위험도
─────────────────────────────────────────────────────────────────────
4-1    하위호환 가상 필드 제거 (is_admin, is_guardian)     Backend Server  🟡
4-2    Flutter 레거시 UserRole 제거 (traveler, guardian)  Flutter         🟡
4-3    guardian API 메서드 완전 제거                      Both            🟡
4-4    DB: is_admin, is_guardian 컬럼 DROP               AWS RDS         🔴
4-5    DB: TB_GUARDIAN → TB_GUARDIAN_LEGACY 유지          AWS RDS         🟢
4-6    guardian.service.ts deprecated 메서드 제거         Backend Server  🟡
```

---

## 15. 플랫폼별 배포 체크리스트

### 15.1 PostgreSQL (AWS RDS)

- [ ] Phase 1 실행 전 DB 스냅샷 생성
- [ ] Phase 1 DDL 실행 (member_role, location_sharing_enabled, 새 테이블 3개)
- [ ] Phase 2 데이터 이관 실행 (트랜잭션)
- [ ] 검증 쿼리 실행:
  - [ ] `SELECT COUNT(*) FROM TB_GROUP_MEMBER WHERE member_role IS NULL AND status = 'active'` → 0
  - [ ] leader 없는 활성 그룹 → 0 (멤버 있는 경우)
  - [ ] `is_admin = TRUE AND member_role NOT IN ('leader', 'full')` → 0
  - [ ] `is_guardian = TRUE AND member_role != 'view_only' AND member_role NOT IN ('leader', 'full')` → 0
- [ ] Phase 3 (레거시 DROP)은 Phase 2 완료 후 최소 1주 검증 후 실행

### 15.2 Backend Server (AWS EC2/ECS)

- [ ] TypeScript 컴파일 에러 없음
- [ ] 단위 테스트 통과
- [ ] 기존 API 응답 형태 하위호환 검증:
  - [ ] `GET /groups/:id/members` → `is_admin`, `is_guardian`, `member_role` 모두 반환
  - [ ] `GET /users/:id` → `user_role` 필드 정상 (view_only → guardian 매핑)
  - [ ] `POST /groups/join/:code` → 기존 TB_GROUP.invite_code + 새 TB_INVITE_CODE 둘 다 작동
- [ ] 새 API 엔드포인트 정상 작동:
  - [ ] POST /invite-codes (생성)
  - [ ] POST /join/:code (가입)
  - [ ] POST /transfer-leadership (양도)
- [ ] event-notification.service.ts → 보호자/관리자 알림 수신자 정상
- [ ] 배포 (Rolling update / Blue-Green)

### 15.3 Firebase Console

- [ ] Realtime Database Rules 업데이트 (`location_sharing` 경로 추가)
- [ ] RTDB 구조 검증 (기존 `users/` 경로 영향 없음)
- [ ] FCM 변경 없음 확인

### 15.4 Kakao Developers Console

- [ ] 애플리케이션 등록
- [ ] Android 플랫폼 등록 (패키지명 + 키해시)
- [ ] iOS 플랫폼 등록 (번들 ID)
- [ ] 카카오링크 API 활성화
- [ ] Native App Key 발급 → `.env` 파일에 추가

### 15.5 Flutter 앱

- [ ] `pubspec.yaml` 의존성 추가 (`kakao_flutter_sdk_share`, `kakao_flutter_sdk_common`)
- [ ] Android `AndroidManifest.xml` 카카오 설정 추가
- [ ] iOS `Info.plist` 카카오 URL Scheme 추가
- [ ] `main.dart`에 `KakaoSdk.init()` 추가
- [ ] UserRole enum 확장 + extension 검증
- [ ] 기존 화면들의 guardian/traveler 분기 로직이 새 역할로 정상 동작
- [ ] InviteModal 역할 선택 + 코드 생성 + 카카오 공유 검증
- [ ] 리더 양도 UI 검증 (full 멤버에게만 양도 가능)
- [ ] 위치 공유 관리 UI 검증 (마스터 ON/OFF + 개별 토글)
- [ ] 앱 빌드 (Android APK/AAB + iOS IPA)

### 15.6 AWS 배포 순서 (권장)

```
1. DB Phase 1 (컬럼/테이블 추가) — 무중단
2. DB Phase 2 (데이터 이관) — 유지보수 시간 권장
3. Backend 배포 (하위호환 모드)
4. 검증 (1~3일)
5. Flutter 앱 빌드 및 배포 (앱스토어/플레이스토어)
6. 검증 (1~2주)
7. DB Phase 3 (레거시 컬럼 제거) — 유지보수 시간 권장
```

---

## 부록 A: 영향받는 전체 파일 목록

### Backend (17개 파일)

| # | 파일 | 변경 유형 | 우선순위 |
|:-:|------|----------|---------|
| 1 | `services/permission.service.ts` | 수정 | 🔴 |
| 2 | `services/user.service.ts` | 수정 | 🔴 |
| 3 | `services/event-notification.service.ts` | 수정 | 🔴 |
| 4 | `services/groups.service.ts` | 수정 | 🔴 |
| 5 | `controllers/groups.controller.ts` | 수정 | 🔴 |
| 6 | `controllers/trips.controller.ts` | 수정 | 🟡 |
| 7 | `services/traveler.service.ts` | 수정 | 🟡 |
| 8 | `services/schedule.service.ts` | 수정 | 🟡 |
| 9 | `services/guardian.service.ts` | deprecation | 🟠 |
| 10 | `routes/guardians.routes.ts` | deprecation | 🟠 |
| 11 | `routes/groups.routes.ts` | 확장 | 🟡 |
| 12 | `services/invite-code.service.ts` | **신규** | 🟢 |
| 13 | `services/leader-transfer.service.ts` | **신규** | 🟢 |
| 14 | `controllers/invite-codes.controller.ts` | **신규** | 🟢 |
| 15 | `controllers/leader-transfer.controller.ts` | **신규** | 🟢 |
| 16 | `routes/invite-codes.routes.ts` | **신규** | 🟢 |
| 17 | `routes/leader-transfer.routes.ts` | **신규** | 🟢 |

### Flutter (12+ 파일)

| # | 파일 | 변경 유형 | 우선순위 |
|:-:|------|----------|---------|
| 1 | `models/user.dart` | 수정 | 🔴 |
| 2 | `utils/app_cache.dart` | 수정 | 🟡 |
| 3 | `utils/guardian_filter.dart` | 수정 | 🟡 |
| 4 | `services/api_service.dart` | 확장 + deprecation | 🔴 |
| 5 | `screens/.../invite_modal.dart` | 전면 개편 | 🔴 |
| 6 | `screens/auth/screen_4_role.dart` | 수정 | 🟡 |
| 7 | `screens/trip/screen_trip_join_code.dart` | 수정 | 🟡 |
| 8 | `main.dart` | KakaoSdk 초기화 추가 | 🟡 |
| 9 | `pubspec.yaml` | 의존성 추가 | 🟡 |
| 10 | `android/app/src/main/AndroidManifest.xml` | 카카오 설정 | 🟡 |
| 11 | `ios/Runner/Info.plist` | 카카오 설정 | 🟡 |
| 12 | (새) 리더 양도 화면 | **신규** | 🟡 |
| 13 | (새) 위치 공유 관리 화면 | **신규** | 🟡 |

### Database (6개 DDL 작업)

| # | 작업 | Phase |
|:-:|------|-------|
| 1 | TB_GROUP_MEMBER에 member_role 추가 | Phase 1 |
| 2 | TB_GROUP_MEMBER에 location_sharing_enabled 추가 | Phase 1 |
| 3 | TB_INVITE_CODE 테이블 생성 | Phase 1 |
| 4 | TB_LOCATION_SHARING 테이블 생성 | Phase 1 |
| 5 | TB_LEADER_TRANSFER_LOG 테이블 생성 | Phase 1 |
| 6 | is_admin / is_guardian 컬럼 DROP | Phase 3 |

### Firebase (1개)

| # | 작업 | 플랫폼 |
|:-:|------|--------|
| 1 | RTDB Rules에 `location_sharing` 경로 추가 | Firebase Console |

### 외부 서비스 (1개)

| # | 작업 | 플랫폼 |
|:-:|------|--------|
| 1 | 카카오 앱 등록 및 API 키 발급 | Kakao Developers |

---

## 부록 B: 마이그레이션 충돌 분석 매트릭스

### B.1 잠재적 충돌 포인트와 해결 전략

| # | 충돌 포인트 | 원인 | 해결 전략 | 위험도 |
|:-:|------------|------|----------|--------|
| 1 | Phase 2 중 API 호출 | `is_admin` 쿼리와 `member_role` 쿼리 혼재 | Phase 2 데이터 이관은 유지보수 시간에 실행, 또는 DB trigger로 양쪽 동기화 | 🟡 |
| 2 | Flutter가 `is_guardian` 기대 | 서버가 `member_role`만 반환 시 | 하위호환 가상 필드 (`is_admin`, `is_guardian`)를 SELECT에 포함 | 🟢 해결 |
| 3 | 기존 TB_GROUP.invite_code와 TB_INVITE_CODE 충돌 | 같은 코드 형식 사용 시 | TB_INVITE_CODE는 7자(prefix+6), TB_GROUP.invite_code는 8자 → 길이로 구분 가능. 추가로 TB_INVITE_CODE 먼저 조회, 없으면 TB_GROUP fallback | 🟢 해결 |
| 4 | guardian.service.ts의 TB_GUARDIAN 쿼리 | Phase 3에서 TB_GUARDIAN 제거 시 | Phase 2 동안 guardian.service.ts 유지, Phase 3에서만 제거 | 🟢 해결 |
| 5 | `user_role` 응답값 변경 | Flutter가 `'traveler'`/`'guardian'`만 파싱 | 서버에서 `view_only` → `'guardian'` 매핑 반환 (하위호환) | 🟢 해결 |
| 6 | `checkMemberPermission()` 반환 구조 | `is_admin` 필드 의존 | `member_role` 추가 + `is_admin` 가상 필드 유지 | 🟢 해결 |
| 7 | leader 없는 그룹 발생 | 데이터 이관 시 owner_user_id 불일치 | Phase 2에서 다중 fallback 로직 (owner → 최초 admin → 최초 멤버) | 🟢 해결 |
| 8 | 동시 리더 양도 | 2명이 동시에 양도 요청 | 트랜잭션 + SELECT FOR UPDATE로 동시성 제어 | 🟢 해결 |
| 9 | SharedPreferences 캐시 | 앱 업데이트 후 구 캐시값 | `UserRoleExtension.fromString()`이 레거시 값 안전하게 처리 | 🟢 해결 |
| 10 | 카카오 SDK 초기화 실패 | API 키 미설정 | try-catch로 감싸고, 실패 시 카카오 공유 버튼 비활성화 | 🟢 해결 |

### B.2 데이터 무결성 검증 쿼리

```sql
-- 마이그레이션 후 실행할 검증 쿼리 모음

-- 1. member_role이 NULL인 활성 멤버 (0이어야 함)
SELECT COUNT(*) as null_roles
FROM TB_GROUP_MEMBER
WHERE member_role IS NULL AND status = 'active';

-- 2. 활성 그룹 중 leader 없는 그룹 (0이어야 함, 멤버 있는 경우)
SELECT g.group_id, g.group_name
FROM TB_GROUP g
WHERE g.status = 'active'
AND EXISTS (SELECT 1 FROM TB_GROUP_MEMBER gm WHERE gm.group_id = g.group_id AND gm.status = 'active')
AND NOT EXISTS (SELECT 1 FROM TB_GROUP_MEMBER gm WHERE gm.group_id = g.group_id AND gm.member_role = 'leader' AND gm.status = 'active');

-- 3. 한 그룹에 leader가 2명 이상인 경우 (0이어야 함)
SELECT group_id, COUNT(*) as leader_count
FROM TB_GROUP_MEMBER
WHERE member_role = 'leader' AND status = 'active'
GROUP BY group_id
HAVING COUNT(*) > 1;

-- 4. is_admin/is_guardian와 member_role 불일치 (0이어야 함)
SELECT COUNT(*) as mismatches
FROM TB_GROUP_MEMBER
WHERE status = 'active'
AND (
    (is_admin = TRUE AND member_role NOT IN ('leader', 'full'))
    OR (is_guardian = TRUE AND member_role NOT IN ('view_only', 'leader', 'full'))
);

-- 5. owner_user_id와 leader 불일치
SELECT g.group_id, g.owner_user_id, gm.user_id as leader_user_id
FROM TB_GROUP g
JOIN TB_GROUP_MEMBER gm ON g.group_id = gm.group_id AND gm.member_role = 'leader' AND gm.status = 'active'
WHERE g.owner_user_id != gm.user_id AND g.status = 'active';
```

---

> **END OF DOCUMENT**
> 이 계획서는 코드베이스 전체 감사(backend 7개 서비스 + 6개 컨트롤러/라우트 + Flutter 24개 파일 + DB 스키마 + Firebase 구조)를 기반으로 작성되었습니다.
