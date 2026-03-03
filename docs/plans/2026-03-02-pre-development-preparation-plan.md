# SafeTrip 실제 개발 시작 전 사전 준비 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Flutter PoC 코드를 프로덕션 개발로 전환하기 위한 5개 Phase 기반 작업 — 백엔드 버그 수정, 개발 환경 구축, Flutter 아키텍처 확정, 디자인 시스템 생성.

**Architecture:** Foundation-First. Phase 1(버그) → Phase 2(백엔드 완성) → Phase 3(환경 설정) → Phase 4(아키텍처) → Phase 5(디자인 시스템) 순서. 각 Phase 완료 후 검증.

**Tech Stack:** Node.js/TypeScript 백엔드, Flutter/Dart, PostgreSQL, Firebase, GitHub Actions, Stitch MCP (디자인)

---

## 기준 파일

- DB 설계: `Master_docs/07_T2_DB_설계_및_관계_v3_4.md`
- API 명세: `Master_docs/35_T2_API_명세서.md` (INDEX), `36~38_T2_API_명세서_Part1~3.md`
- 화면 원칙: `Master_docs/10_T2_화면구성원칙.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`

---

## ─────────────── PHASE 1: Critical Bug Fixes ───────────────

---

### Task 1: TB_COUNTRY 테이블 생성 + 시드 데이터

**배경:** `countries.service.ts`가 `TB_COUNTRY` 테이블을 쿼리하지만 테이블이 없어 `/api/v1/countries` 500 에러 발생.

**Files:**
- Create: `safetrip-server-api/migrations/20260302_create_tb_country.sql`

**Step 1: 현재 서비스가 쿼리하는 컬럼명 확인**

`safetrip-server-api/src/services/countries.service.ts` 열어서 SELECT 컬럼 확인:
```
country_code, country_name_ko, country_name_en, country_name_local,
flag_emoji, iso_alpha2, is_active (WHERE 절), deleted_at (WHERE 절)
```

**Step 2: Migration 파일 생성**

`safetrip-server-api/migrations/20260302_create_tb_country.sql`:

```sql
-- TB_COUNTRY 생성 및 초기 국가 데이터 시드
-- 참조: Master_docs/07_T2_DB_설계_및_관계_v3_4.md §4.8

CREATE TABLE IF NOT EXISTS tb_country (
    country_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_code        VARCHAR(5) NOT NULL UNIQUE,
    country_name_ko     VARCHAR(100),
    country_name_en     VARCHAR(100) NOT NULL,
    country_name_local  VARCHAR(100),
    flag_emoji          VARCHAR(10),
    iso_alpha2          VARCHAR(2),
    phone_code          VARCHAR(10),
    region              VARCHAR(50),
    mofa_travel_alert   VARCHAR(20) DEFAULT 'none'
                        CHECK (mofa_travel_alert IN ('none','watch','warning','danger','ban')),
    mofa_alert_updated_at TIMESTAMPTZ,
    is_popular          BOOLEAN DEFAULT FALSE,
    sort_order          INTEGER DEFAULT 0,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ,
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_country_code   ON tb_country(country_code);
CREATE INDEX IF NOT EXISTS idx_country_region ON tb_country(region);
CREATE INDEX IF NOT EXISTS idx_country_active ON tb_country(is_active) WHERE is_active = true;

-- ─── 시드 데이터: 주요 43개 국가 ───────────────────────────────────────────
INSERT INTO tb_country (country_code, country_name_ko, country_name_en, country_name_local, flag_emoji, iso_alpha2, phone_code, region, is_popular, sort_order)
VALUES
  -- 아시아 인기 여행지 (is_popular=true)
  ('KR',  '대한민국',     'South Korea',    '한국',           '🇰🇷', 'KR', '+82',  'Asia',    TRUE,  1),
  ('JP',  '일본',         'Japan',          '日本',           '🇯🇵', 'JP', '+81',  'Asia',    TRUE,  2),
  ('CN',  '중국',         'China',          '中国',           '🇨🇳', 'CN', '+86',  'Asia',    TRUE,  3),
  ('TH',  '태국',         'Thailand',       'ประเทศไทย',      '🇹🇭', 'TH', '+66',  'Asia',    TRUE,  4),
  ('VN',  '베트남',       'Vietnam',        'Việt Nam',       '🇻🇳', 'VN', '+84',  'Asia',    TRUE,  5),
  ('SG',  '싱가포르',     'Singapore',      'Singapore',      '🇸🇬', 'SG', '+65',  'Asia',    TRUE,  6),
  ('MY',  '말레이시아',   'Malaysia',       'Malaysia',       '🇲🇾', 'MY', '+60',  'Asia',    TRUE,  7),
  ('PH',  '필리핀',       'Philippines',    'Pilipinas',      '🇵🇭', 'PH', '+63',  'Asia',    TRUE,  8),
  ('ID',  '인도네시아',   'Indonesia',      'Indonesia',      '🇮🇩', 'ID', '+62',  'Asia',    TRUE,  9),
  ('TW',  '대만',         'Taiwan',         '台灣',           '🇹🇼', 'TW', '+886', 'Asia',    TRUE,  10),
  ('HK',  '홍콩',         'Hong Kong',      '香港',           '🇭🇰', 'HK', '+852', 'Asia',    TRUE,  11),
  ('MO',  '마카오',       'Macau',          '澳門',           '🇲🇴', 'MO', '+853', 'Asia',    FALSE, 12),
  ('IN',  '인도',         'India',          'India',          '🇮🇳', 'IN', '+91',  'Asia',    FALSE, 13),
  ('NP',  '네팔',         'Nepal',          'नेपाल',          '🇳🇵', 'NP', '+977', 'Asia',    FALSE, 14),
  ('MM',  '미얀마',       'Myanmar',        'မြန်မာ',          '🇲🇲', 'MM', '+95',  'Asia',    FALSE, 15),
  ('KH',  '캄보디아',     'Cambodia',       'Cambodia',       '🇰🇭', 'KH', '+855', 'Asia',    FALSE, 16),
  ('LA',  '라오스',       'Laos',           'ລາວ',            '🇱🇦', 'LA', '+856', 'Asia',    FALSE, 17),
  -- 유럽
  ('FR',  '프랑스',       'France',         'France',         '🇫🇷', 'FR', '+33',  'Europe',  FALSE, 20),
  ('DE',  '독일',         'Germany',        'Deutschland',    '🇩🇪', 'DE', '+49',  'Europe',  FALSE, 21),
  ('IT',  '이탈리아',     'Italy',          'Italia',         '🇮🇹', 'IT', '+39',  'Europe',  FALSE, 22),
  ('ES',  '스페인',       'Spain',          'España',         '🇪🇸', 'ES', '+34',  'Europe',  FALSE, 23),
  ('GB',  '영국',         'United Kingdom', 'UK',             '🇬🇧', 'GB', '+44',  'Europe',  FALSE, 24),
  ('CH',  '스위스',       'Switzerland',    'Schweiz',        '🇨🇭', 'CH', '+41',  'Europe',  FALSE, 25),
  ('AT',  '오스트리아',   'Austria',        'Österreich',     '🇦🇹', 'AT', '+43',  'Europe',  FALSE, 26),
  ('NL',  '네덜란드',     'Netherlands',    'Nederland',      '🇳🇱', 'NL', '+31',  'Europe',  FALSE, 27),
  -- 북미
  ('US',  '미국',         'United States',  'USA',            '🇺🇸', 'US', '+1',   'Americas', FALSE, 30),
  ('CA',  '캐나다',       'Canada',         'Canada',         '🇨🇦', 'CA', '+1',   'Americas', FALSE, 31),
  ('MX',  '멕시코',       'Mexico',         'México',         '🇲🇽', 'MX', '+52',  'Americas', FALSE, 32),
  -- 오세아니아
  ('AU',  '호주',         'Australia',      'Australia',      '🇦🇺', 'AU', '+61',  'Oceania', FALSE, 40),
  ('NZ',  '뉴질랜드',     'New Zealand',    'New Zealand',    '🇳🇿', 'NZ', '+64',  'Oceania', FALSE, 41),
  -- 중동/아프리카
  ('AE',  '아랍에미리트', 'UAE',            'الإمارات',        '🇦🇪', 'AE', '+971', 'Middle East', FALSE, 50),
  ('TR',  '튀르키예',     'Turkey',         'Türkiye',        '🇹🇷', 'TR', '+90',  'Middle East', FALSE, 51),
  ('EG',  '이집트',       'Egypt',          'مصر',            '🇪🇬', 'EG', '+20',  'Africa',  FALSE, 52),
  ('MA',  '모로코',       'Morocco',        'المغرب',          '🇲🇦', 'MA', '+212', 'Africa',  FALSE, 53)
ON CONFLICT (country_code) DO NOTHING;
```

**Step 3: Migration 적용**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api

# PostgreSQL에 migration 적용
psql -U safetrip -d safetrip_local -f migrations/20260302_create_tb_country.sql
```
Expected: `CREATE TABLE`, `CREATE INDEX` x3, `INSERT 34` (혹은 do nothing)

**Step 4: 확인**

```bash
psql -U safetrip -d safetrip_local -c "SELECT country_code, country_name_ko, flag_emoji FROM tb_country ORDER BY sort_order LIMIT 10;"
```
Expected: KR, JP, CN 순으로 10개 국가 출력

**Step 5: API 테스트**

서버가 실행 중이라면:
```bash
curl -s http://localhost:3001/api/v1/countries | jq '.data | length'
```
Expected: `34` (또는 시드 국가 수)

**Step 6: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-server-api/migrations/20260302_create_tb_country.sql
git commit -m "fix: create tb_country table and seed 34 countries

- /api/v1/countries was returning 500 due to missing tb_country table
- Schema matches countries.service.ts query columns
- Seed 34 major countries (Asia, Europe, Americas, Oceania, Middle East)"
```

---

### Task 2: GET /users/me 라우트 순서 버그 수정

**배경:** `users.routes.ts`에서 `GET /:userId`(line 19)가 `router.use(authenticate)`(line 29)보다 먼저 등록되어 있어, `GET /me` 요청이 `/:userId`로 매칭된다 (`userId='me'`). `GET /me`와 `PUT /me/fcm-token`이 실질적으로 사용 불가 상태.

**Files:**
- Modify: `safetrip-server-api/src/routes/users.routes.ts`

**Step 1: 현재 파일 확인**

`safetrip-server-api/src/routes/users.routes.ts` 읽기 — 라우트 등록 순서 파악.

현재 구조 (버그):
```
line 9:  router.post('/register', ...)
line 12: router.get('/by-phone', ...)
line 15: router.get('/search', authenticate, ...)
line 19: router.get('/:userId', getUserById)          ← /me도 여기 매칭됨!
line 22: router.put('/:userId', updateUserProfile)
line 25: router.put('/:userId/fcm-token', ...)        ← /me/fcm-token도 여기!
line 29: router.use(authenticate)                      ← 너무 늦음
line 35: router.get('/me', getMe)                      ← 이미 /:userId에 가로채임
...
```

**Step 2: 수정**

`router.use(authenticate)` 제거하고, 각 `/me` 라우트에 `authenticate`를 인라인으로 추가하며 `/:userId` 앞으로 이동:

```typescript
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { usersController } from '../controllers/users.controller';

const router = Router();

// ─── 인증 불필요 라우트 (구체적인 경로 먼저) ────────────────────────────────

// POST /api/v1/users/register
router.post('/register', usersController.registerUser);

// GET /api/v1/users/by-phone
router.get('/by-phone', usersController.getUserByPhone);

// GET /api/v1/users/search?q=:query (인증 필요)
router.get('/search', authenticate, usersController.searchUsers);

// ─── 인증 필요 /me 라우트 (/:userId 보다 먼저 등록!) ─────────────────────────

// GET /api/v1/users/me
router.get('/me', authenticate, usersController.getMe);

// PATCH /api/v1/users/me
router.patch('/me', authenticate, usersController.updateMe);

// PUT /api/v1/users/me/fcm-token
router.put('/me/fcm-token', authenticate, usersController.updateFcmToken);

// DELETE /api/v1/users/me/fcm-token/:tokenId
router.delete('/me/fcm-token/:tokenId', authenticate, usersController.deleteFcmToken);

// ─── 와일드카드 라우트 (인증 불필요 — /me 다음에 등록) ──────────────────────

// GET /api/v1/users/:userId (테스트용 — 인증 없이)
router.get('/:userId', usersController.getUserById);

// PUT /api/v1/users/:userId (테스트용 — 인증 없이)
router.put('/:userId', usersController.updateUserProfile);

// PUT /api/v1/users/:userId/fcm-token (테스트용 — 인증 없이)
router.put('/:userId/fcm-token', usersController.registerFcmTokenForUser);

// PATCH /api/v1/users/:id/terms (인증 필요)
router.patch('/:id/terms', authenticate, usersController.patchTerms);

export { router as usersRoutes };
```

**Step 3: 서버 재시작 후 테스트**

```bash
# 백엔드 재시작 (터미널 1)
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npm run dev

# 테스트 (터미널 2) — Firebase ID Token 필요
# 에뮬레이터에서 테스트 유저로 토큰 발급 후:
TOKEN="<Firebase_ID_Token>"
curl -H "Authorization: Bearer $TOKEN" http://localhost:3001/api/v1/users/me
```
Expected: `200 OK` + `{ success: true, data: { uid: "...", ... } }`

(이전에는 `:userId='me'`로 매칭되어 유저를 못 찾거나 다른 동작)

**Step 4: TypeScript 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npx tsc --noEmit
```
Expected: 오류 없음

**Step 5: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-server-api/src/routes/users.routes.ts
git commit -m "fix: move /me routes before /:userId wildcard in users.routes.ts

- GET /me was unreachable (matched by GET /:userId with userId='me')
- PUT /me/fcm-token had same issue
- Fix: register /me routes before /:userId, add authenticate inline
- Remove router.use(authenticate) in favor of per-route middleware"
```

---

### Task 3: Phase 1 검증 — UAT + API 통합 테스트

**목표:** Phase 1 수정 사항 (tb_country + 라우트 순서)이 기존 UAT를 깨지 않고 새 API도 정상 동작하는지 확인.

**Step 1: 백엔드 서버 실행 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
# 서버 실행 중인지 확인
curl http://localhost:3001/health
```
Expected: `{ "status": "ok" }`

**Step 2: countries API 테스트**

```bash
curl -s http://localhost:3001/api/v1/countries | jq '{ success: .success, count: (.data | length), sample: .data[0:3] }'
```
Expected:
```json
{
  "success": true,
  "count": 34,
  "sample": [
    { "country_code": "KR", "country_name_ko": "대한민국", "flag_emoji": "🇰🇷" },
    ...
  ]
}
```

**Step 3: 기존 UAT 스크립트 실행**

```bash
cd /mnt/d/Project/15_SafeTrip_New
bash scripts/test/run-all-tests.sh
```
Expected: 모든 Phase 1~6 통과

**Step 4: 기존 백엔드 유닛 테스트 실행**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npm test
```
Expected: 4개 테스트 파일 모두 pass (`invite-code`, `permission`, `guardian-link`, `leader-transfer`)

---

## ─────────────── PHASE 2: Backend Completion ───────────────

---

### Task 4: Firebase Functions 인벤토리 + 누락 기능 파악

**배경:** `safetrip-firebase-function/` 에 현재 `index.ts` + `chat-message-trigger.ts`만 존재. 비즈니스 원칙이 요구하는 Functions 목록과 대조하여 추가 구현 필요 여부 파악.

**Files:**
- Read: `safetrip-firebase-function/src/index.ts`
- Read: `safetrip-firebase-function/src/triggers/chat-message-trigger.ts`
- Create: `docs/firebase-functions-inventory.md`

**Step 1: 현재 구현된 Functions 확인**

`safetrip-firebase-function/src/index.ts` 전체 읽기. 현재:
- `helloWorld` — 테스트용 HTTPS 함수
- `onChatMessageCreated` — RTDB 채팅 메시지 생성 시 FCM 알림

**Step 2: 비즈니스 원칙에서 Functions가 필요한 기능 확인**

`Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`에서 §05 SOS, §09 가디언, §13 데이터 삭제 관련 자동화 기능 파악.

일반적으로 필요한 Functions:
- `onChatMessageCreated` ✅ 구현됨
- `scheduledTripCleanup` — 여행 종료 후 데이터 정리 (90일 채팅 삭제 등)
- `onUserDeleted` — 계정 삭제 시 RTDB 정리 (비즈니스 원칙 §14.4 7일 유예)
- `onSosTriggered` — SOS 발동 시 가디언 알림 (또는 백엔드 API에서 처리)

**Step 3: 인벤토리 문서 작성**

`docs/firebase-functions-inventory.md` 생성:

```markdown
# Firebase Functions 인벤토리

## 현재 구현 (2026-03-02)

| 함수명 | 트리거 | 용도 | 상태 |
|--------|--------|------|:----:|
| `helloWorld` | HTTPS onRequest | 테스트용 | ✅ |
| `onChatMessageCreated` | RTDB onCreated | 채팅 메시지 → FCM 알림 | ✅ |

## 필요하지만 미구현

| 함수명 | 트리거 | 용도 | 우선순위 |
|--------|--------|------|:-------:|
| `scheduledTripDataCleanup` | Scheduled (매일 00:00 KST) | 여행 종료 90일 후 채팅 삭제 (§13.1) | P1 |
| `onUserAccountDeletion` | Auth onDelete | 계정 삭제 요청 시 RTDB 정리 (§14.4) | P1 |
| `onTripEnded` | RTDB onUpdate | 여행 종료 시 RTDB 위치 데이터 정리 | P2 |

## 결론

현재 MVP 개발에서 Functions는 채팅 알림만 필요. 스케줄 정리 함수는
Phase 2 개발(데이터 보존 정책 구현) 시 추가 예정.
```

**Step 4: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add docs/firebase-functions-inventory.md
git commit -m "docs: add firebase functions inventory

- Documents currently implemented functions
- Identifies missing functions per business rules v5.1
- Defers non-critical functions to Phase 2 development"
```

---

### Task 5: 백엔드 테스트 커버리지 보강 — countries API

**배경:** 현재 백엔드 테스트 4개 (invite-code, permission, guardian-link, leader-transfer). Phase 1에서 추가된 countries API는 테스트 없음.

**Files:**
- Create: `safetrip-server-api/src/__tests__/countries.service.test.ts`

**Step 1: 기존 테스트 파일 패턴 확인**

`safetrip-server-api/src/__tests__/invite-code.service.test.ts` 읽어서 테스트 구조 파악.

**Step 2: countries 서비스 테스트 작성**

`safetrip-server-api/src/__tests__/countries.service.test.ts`:

```typescript
// safetrip-server-api/src/__tests__/countries.service.test.ts

import { countriesService } from '../services/countries.service';

// DB mock
jest.mock('../config/database', () => ({
  getDatabase: () => ({
    query: jest.fn(),
  }),
}));

import { getDatabase } from '../config/database';

describe('countriesService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getAllCountries', () => {
    it('활성 국가 목록을 반환한다', async () => {
      const mockRows = [
        {
          country_code: 'KR',
          country_name_ko: '대한민국',
          country_name_en: 'South Korea',
          country_name_local: '한국',
          flag_emoji: '🇰🇷',
          iso_alpha2: 'KR',
        },
        {
          country_code: 'JP',
          country_name_ko: '일본',
          country_name_en: 'Japan',
          country_name_local: '日本',
          flag_emoji: '🇯🇵',
          iso_alpha2: 'JP',
        },
      ];

      (getDatabase().query as jest.Mock).mockResolvedValue({ rows: mockRows });

      const result = await countriesService.getAllCountries();

      expect(result).toHaveLength(2);
      expect(result[0].country_code).toBe('KR');
      expect(result[0].country_name_ko).toBe('대한민국');
      expect(result[0].flag_emoji).toBe('🇰🇷');
    });

    it('DB 오류 시 예외를 throw한다', async () => {
      (getDatabase().query as jest.Mock).mockRejectedValue(new Error('relation "tb_country" does not exist'));

      await expect(countriesService.getAllCountries()).rejects.toThrow(
        'relation "tb_country" does not exist'
      );
    });

    it('빈 목록도 정상 반환한다', async () => {
      (getDatabase().query as jest.Mock).mockResolvedValue({ rows: [] });

      const result = await countriesService.getAllCountries();
      expect(result).toHaveLength(0);
    });
  });
});
```

**Step 3: 테스트 실행 — 실패 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npx jest countries.service.test.ts --verbose
```
Expected: PASS (서비스 코드가 이미 올바르게 작성되어 있으므로)

**Step 4: 전체 테스트 실행**

```bash
npm test
```
Expected: 5개 테스트 파일 모두 pass

**Step 5: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-server-api/src/__tests__/countries.service.test.ts
git commit -m "test: add countries service unit tests

- Tests getAllCountries normal case, DB error case, empty list case
- Brings countries API into test coverage"
```

---

## ─────────────── PHASE 3: Development Environment ───────────────

---

### Task 6: 백엔드 환경별 설정 파일 체계 구축

**배경:** 현재 `.env`와 `.env.local`만 존재. staging/production 환경 파일 없어 배포 시 수동으로 환경변수를 설정해야 함.

**Files:**
- Create: `safetrip-server-api/.env.staging`
- Create: `safetrip-server-api/.env.production`
- Create: `safetrip-server-api/.env.example`
- Modify: `safetrip-server-api/.gitignore` (production 환경 파일 제외 확인)

**Step 1: 현재 .gitignore 확인**

```bash
grep -n "\.env" /mnt/d/Project/15_SafeTrip_New/safetrip-server-api/.gitignore
```
`.env.production`이 gitignore에 있는지 확인. 없으면 추가.

**Step 2: .env.staging 생성**

`safetrip-server-api/.env.staging`:

```bash
# SafeTrip Backend - Staging Environment
NODE_ENV=staging
PORT=3001

# PostgreSQL (Staging DB — 실제 값으로 채울 것)
DB_HOST=YOUR_STAGING_DB_HOST
DB_PORT=5432
DB_NAME=safetrip_staging
DB_USER=safetrip
DB_PASSWORD=YOUR_STAGING_DB_PASSWORD
DB_SSL=true

# JWT
JWT_SECRET=YOUR_STAGING_JWT_SECRET_MINIMUM_32_CHARS

# Firebase (Staging 프로젝트 — 실제 값으로 채울 것)
FIREBASE_PROJECT_ID=safetrip-urock
FIREBASE_CLIENT_EMAIL=YOUR_STAGING_SERVICE_ACCOUNT_EMAIL
FIREBASE_PRIVATE_KEY="YOUR_STAGING_PRIVATE_KEY"
FIREBASE_DATABASE_URL=https://safetrip-urock-default-rtdb.asia-southeast1.firebasedatabase.app
# 에뮬레이터 설정 없음 (실제 Firebase 사용)
```

**Step 3: .env.production 생성**

`safetrip-server-api/.env.production`:

```bash
# SafeTrip Backend - Production Environment
# ⚠️ 이 파일은 절대 git에 커밋하지 않는다
NODE_ENV=production
PORT=3001

# PostgreSQL (Production DB — 실제 값으로 채울 것)
DB_HOST=YOUR_PROD_DB_HOST
DB_PORT=5432
DB_NAME=safetrip_prod
DB_USER=safetrip
DB_PASSWORD=YOUR_PROD_DB_PASSWORD
DB_SSL=true

# JWT
JWT_SECRET=YOUR_PROD_JWT_SECRET_MINIMUM_32_CHARS

# Firebase (Production 프로젝트)
FIREBASE_PROJECT_ID=safetrip-urock
FIREBASE_CLIENT_EMAIL=YOUR_PROD_SERVICE_ACCOUNT_EMAIL
FIREBASE_PRIVATE_KEY="YOUR_PROD_PRIVATE_KEY"
FIREBASE_DATABASE_URL=https://safetrip-urock-default-rtdb.asia-southeast1.firebasedatabase.app
```

**Step 4: .env.example 생성 (git에 포함)**

`safetrip-server-api/.env.example`:

```bash
# SafeTrip Backend - Environment Variables Template
# cp .env.example .env  → 개발 시작 전 복사 후 실제 값으로 채울 것
NODE_ENV=development
PORT=3001

DB_HOST=localhost
DB_PORT=5432
DB_NAME=safetrip_local
DB_USER=safetrip
DB_PASSWORD=your_db_password
DB_SSL=false

JWT_SECRET=your_jwt_secret_minimum_32_chars

FIREBASE_PROJECT_ID=safetrip-urock
FIREBASE_CLIENT_EMAIL=your_service_account_email
FIREBASE_PRIVATE_KEY="your_private_key"
FIREBASE_DATABASE_URL=http://127.0.0.1:9000/?ns=safetrip-urock-default-rtdb
```

**Step 5: .gitignore 업데이트 확인**

`safetrip-server-api/.gitignore` 열어서 아래 항목 있는지 확인. 없으면 추가:

```
.env
.env.local
.env.staging
.env.production
```

단, `.env.example`은 gitignore에 포함하지 않는다.

**Step 6: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-server-api/.env.example safetrip-server-api/.gitignore
# .env.staging, .env.production은 .gitignore에 있으므로 staging만 track
git commit -m "chore: add backend environment files structure

- Add .env.example template for new developers
- Add .env.staging and .env.production (gitignored)
- Separate dev/staging/prod environment configuration"
```

---

### Task 7: Flutter 환경별 설정 + 프로덕션 준비

**배경:** 현재 Flutter는 `.env`와 `.env.local`만 있고 `flutter_dotenv`로 런타임 로드. staging/production 환경 파일 추가 필요.

**Files:**
- Create: `safetrip-mobile/.env.staging`
- Create: `safetrip-mobile/.env.production`
- Create: `safetrip-mobile/.env.example`
- Create: `docs/flutter-env-guide.md`

**Step 1: 현재 .env 파일 확인**

`safetrip-mobile/.env` 읽어서 어떤 변수가 있는지 확인. 현재:
- `API_SERVER_URL`
- `USE_FIREBASE_EMULATOR`
- `FIREBASE_EMULATOR_HOST`
- `FIREBASE_AUTH_EMULATOR_URL`
- `FIREBASE_RTDB_EMULATOR_URL`
- `FIREBASE_STORAGE_EMULATOR_URL`

**Step 2: .env.staging 생성**

`safetrip-mobile/.env.staging`:

```bash
# SafeTrip Flutter - Staging Environment
# 사용: cp .env.staging .env → flutter run
API_SERVER_URL=https://api-staging.safetrip.app/api/v1

# Firebase (실제 Firebase 사용 — 에뮬레이터 없음)
USE_FIREBASE_EMULATOR=false
FIREBASE_EMULATOR_HOST=
FIREBASE_AUTH_EMULATOR_URL=
FIREBASE_RTDB_EMULATOR_URL=
FIREBASE_STORAGE_EMULATOR_URL=
```

**Step 3: .env.production 생성**

`safetrip-mobile/.env.production`:

```bash
# SafeTrip Flutter - Production Environment
# ⚠️ 이 파일은 절대 git에 커밋하지 않는다
API_SERVER_URL=https://api.safetrip.app/api/v1

USE_FIREBASE_EMULATOR=false
FIREBASE_EMULATOR_HOST=
FIREBASE_AUTH_EMULATOR_URL=
FIREBASE_RTDB_EMULATOR_URL=
FIREBASE_STORAGE_EMULATOR_URL=
```

**Step 4: .env.example 생성**

`safetrip-mobile/.env.example`:

```bash
# SafeTrip Flutter - Environment Variables Template
# 환경별 사용법:
#   개발:        cp .env.example .env  →  bash ../scripts/start-local.sh --env 로 IP 채우기
#   Staging:     cp .env.staging .env
#   Production:  cp .env.production .env
API_SERVER_URL=http://10.0.2.2:3001

USE_FIREBASE_EMULATOR=true
FIREBASE_EMULATOR_HOST=10.0.2.2
FIREBASE_AUTH_EMULATOR_URL=
FIREBASE_RTDB_EMULATOR_URL=
FIREBASE_STORAGE_EMULATOR_URL=
```

**Step 5: Flutter env 가이드 문서 작성**

`docs/flutter-env-guide.md`:

```markdown
# Flutter 환경 설정 가이드

## 환경별 .env 파일 전환

| 환경 | 명령어 |
|------|--------|
| 로컬 (에뮬레이터) | `bash ../scripts/start-local.sh --env` (IP 자동 감지) |
| 로컬 (ngrok) | `bash ../scripts/start-dev-ngrok.sh` |
| Staging | `cp .env.staging .env` |
| Production | `cp .env.production .env` |

## 빌드 명령어

```bash
# 개발 (에뮬레이터)
flutter run

# Staging APK
cp .env.staging .env && flutter build apk --release

# Production APK
cp .env.production .env && flutter build apk --release
```

## gitignore 정책

```
.env          (git 제외 — 로컬/민감 정보 포함)
.env.staging  (git 제외 — staging 서버 URL)
.env.production (git 제외 — production 서버 URL)
.env.example  (git 포함 — 템플릿)
```
```

**Step 6: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-mobile/.env.example docs/flutter-env-guide.md
git commit -m "chore: add Flutter environment files structure and guide

- Add .env.example template
- Add .env.staging and .env.production (gitignored)
- Add docs/flutter-env-guide.md for environment switching instructions"
```

---

### Task 8: GitHub Actions CI/CD 기본 파이프라인

**배경:** CI/CD 없음. PR 시 자동으로 백엔드 테스트 + Flutter 정적 분석 실행.

**Files:**
- Create: `.github/workflows/backend-test.yml`
- Create: `.github/workflows/flutter-analyze.yml`

**Step 1: .github/workflows 디렉토리 확인**

```bash
ls -la /mnt/d/Project/15_SafeTrip_New/.github/workflows/ 2>/dev/null || echo "디렉토리 없음"
```

없으면 생성:
```bash
mkdir -p /mnt/d/Project/15_SafeTrip_New/.github/workflows
```

**Step 2: 백엔드 테스트 워크플로우 생성**

`.github/workflows/backend-test.yml`:

```yaml
name: Backend Tests

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'safetrip-server-api/**'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'safetrip-server-api/**'

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: safetrip
          POSTGRES_PASSWORD: safetrip_test
          POSTGRES_DB: safetrip_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: safetrip-server-api/package-lock.json

      - name: Install dependencies
        working-directory: safetrip-server-api
        run: npm ci

      - name: TypeScript type check
        working-directory: safetrip-server-api
        run: npx tsc --noEmit

      - name: Run tests
        working-directory: safetrip-server-api
        run: npm test
        env:
          NODE_ENV: test
          DB_HOST: localhost
          DB_PORT: 5432
          DB_NAME: safetrip_test
          DB_USER: safetrip
          DB_PASSWORD: safetrip_test
          DB_SSL: false
          JWT_SECRET: test-jwt-secret-32-chars-minimum
          FIREBASE_PROJECT_ID: test-project
          FIREBASE_CLIENT_EMAIL: test@test.iam.gserviceaccount.com
          FIREBASE_PRIVATE_KEY: "-----BEGIN RSA PRIVATE KEY-----\ntest\n-----END RSA PRIVATE KEY-----"
          FIREBASE_DATABASE_URL: http://localhost:9000
```

**Step 3: Flutter 분석 워크플로우 생성**

`.github/workflows/flutter-analyze.yml`:

```yaml
name: Flutter Analyze

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'safetrip-mobile/**'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'safetrip-mobile/**'

jobs:
  analyze:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'

      - name: Install dependencies
        working-directory: safetrip-mobile
        run: flutter pub get

      - name: Create .env for CI
        working-directory: safetrip-mobile
        run: |
          cat > .env << 'EOF'
          API_SERVER_URL=http://localhost:3001
          USE_FIREBASE_EMULATOR=false
          FIREBASE_EMULATOR_HOST=
          FIREBASE_AUTH_EMULATOR_URL=
          FIREBASE_RTDB_EMULATOR_URL=
          FIREBASE_STORAGE_EMULATOR_URL=
          EOF

      - name: Flutter analyze
        working-directory: safetrip-mobile
        run: flutter analyze --no-fatal-infos
```

**Step 4: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add .github/workflows/backend-test.yml .github/workflows/flutter-analyze.yml
git commit -m "ci: add GitHub Actions workflows for backend tests and flutter analyze

- backend-test.yml: runs on changes to safetrip-server-api/
  - TypeScript type check
  - Jest unit tests with PostgreSQL service
- flutter-analyze.yml: runs on changes to safetrip-mobile/
  - flutter analyze with no fatal infos"
```

---

## ─────────────── PHASE 4: Flutter Architecture Planning ───────────────

---

### Task 9: ARCHITECTURE.md 작성 — 상태 관리 + 폴더 구조 결정

**배경:** Flutter 아키텍처 의사결정 문서 없음. 프로덕션 코드 시작 전 팀 합의 필요.

**Files:**
- Create: `docs/ARCHITECTURE.md`

**Step 1: 현재 Flutter 상태 관리 확인**

`safetrip-mobile/pubspec.yaml` 읽어서 현재 사용 중인 상태 관리 패키지 확인:

```bash
grep -E "provider|riverpod|bloc|getx|mobx|redux" safetrip-mobile/pubspec.yaml
```

**Step 2: ARCHITECTURE.md 작성**

`docs/ARCHITECTURE.md`:

```markdown
# SafeTrip Flutter Architecture Decisions

> 마지막 업데이트: 2026-03-02
>
> 이 문서는 프로덕션 Flutter 개발의 기술적 의사결정을 기록한다.

---

## 1. 상태 관리: Riverpod

**결정:** `flutter_riverpod` v2.x

**이유:**
- SafeTrip은 역할(캡틴/크루장/크루/가디언) + 프라이버시 등급(3종)에 따라
  동일 화면에서 UI 분기가 많음 → Provider 트리 세밀 관리 필요
- Riverpod의 `family`/`autoDispose` modifier로 여행별 상태 격리 가능
- 테스트 시 `ProviderContainer`로 mock injection 용이
- PoC 코드에서 `setState` + 직접 서비스 호출 패턴 → 교체

**마이그레이션 전략:**
- Phase 1: 신규 화면은 Riverpod 사용
- Phase 2: 기존 PoC 화면을 순차적으로 Riverpod으로 전환

---

## 2. 폴더 구조: Feature-Based

```
safetrip-mobile/lib/
├── core/
│   ├── constants/          (기존 constants/ 이동)
│   ├── theme/              (DESIGN.md 기반 토큰: colors, typography, spacing)
│   ├── network/            (Dio 클라이언트 설정, 인터셉터)
│   ├── error/              (공통 에러 처리, AppException 클래스)
│   └── utils/              (기존 utils/ 이동)
│
├── features/
│   ├── auth/               (로그인, 프로필 설정, 약관 동의)
│   │   ├── data/           (repository, API 호출)
│   │   ├── domain/         (use case, entity)
│   │   └── presentation/   (screens, widgets, providers)
│   ├── trip/               (여행 CRUD, 멤버 관리, 여행 선택)
│   ├── guardian/           (가디언 관리, 메시지, 대시보드)
│   ├── location/           (지도, 실시간 위치, 지오펜스)
│   ├── chat/               (채팅탭, 메시지 목록)
│   ├── guide/              (안전가이드, MOFA 탭)
│   ├── settings/           (설정 메뉴, 프로필 화면)
│   └── onboarding/         (스플래시, 웰컴, 역할 선택, 초대코드)
│
├── shared/
│   ├── widgets/            (기존 widgets/ — AppButton, AppCard 등 공통 컴포넌트)
│   ├── models/             (기존 models/ — User, Schedule, Guardian 등)
│   └── services/           (기존 services/ 중 공통: FCM, API base, etc.)
│
├── router/                 (기존 GoRouter 설정 유지)
└── main.dart
```

**마이그레이션 전략:**
- 기존 `lib/` 구조는 건드리지 않고 병행 운영
- 신규 화면은 `features/` 하위에 작성
- 기존 화면은 Sprint별로 순차 이동

---

## 3. 네트워크 레이어: Dio

**결정:** `dio` v5.x + 커스텀 인터셉터

**인터셉터 구성:**
```dart
// core/network/api_client.dart
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_SERVER_URL'] ?? 'http://10.0.2.2:3001',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(AuthInterceptor());  // Firebase ID Token 자동 주입
    _dio.interceptors.add(LogInterceptor());   // 개발 환경 로깅
  }
}

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

---

## 4. 코드 품질 기준

**Linter:** `flutter_lints` + 추가 규칙 (`analysis_options.yaml`)
**포맷터:** `dart format` (line length 100)
**CI:** GitHub Actions (`flutter-analyze.yml`) — PR 시 자동 실행

**추가 규칙 (analysis_options.yaml에 추가 예정):**
- `prefer_const_constructors: true`
- `prefer_final_fields: true`
- `avoid_print: true` (debugPrint 사용)

---

## 5. 의존성 주입

Riverpod의 `Provider`/`StateNotifierProvider`/`FutureProvider`를 활용.
별도 DI 프레임워크 사용 안 함 (YAGNI).

---

## 참조

- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 화면구성원칙: `Master_docs/10_T2_화면구성원칙.md`
- API 명세서: `Master_docs/35~38_T2_API_명세서_*.md`
```

**Step 3: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add docs/ARCHITECTURE.md
git commit -m "docs: add Flutter architecture decisions document

- State management: Riverpod v2.x (role/privacy-grade UI branching)
- Folder structure: Feature-based with migration strategy
- Network layer: Dio + AuthInterceptor for Firebase token injection
- Code quality: flutter_lints + additional rules"
```

---

### Task 10: Flutter Feature-Based 폴더 구조 스캐폴딩

**목표:** 새 아키텍처의 빈 폴더 구조를 생성하여 프로덕션 코드 시작 준비.

**Files:**
- Create: `safetrip-mobile/lib/core/` (하위 구조)
- Create: `safetrip-mobile/lib/features/` (하위 구조)
- Create: `safetrip-mobile/lib/shared/` (하위 구조)

**Step 1: core/ 구조 생성**

각 폴더에 `.gitkeep` 파일 생성 (git tracking용):

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/lib

mkdir -p core/{constants,theme,network,error,utils}
mkdir -p features/{auth,trip,guardian,location,chat,guide,settings,onboarding}/{data,domain,presentation}
mkdir -p shared/{widgets,models,services}

# git tracking용 .gitkeep
find core features shared -type d -exec touch {}/.gitkeep \;
```

**Step 2: core/network/api_client.dart 기본 파일 생성**

`safetrip-mobile/lib/core/network/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// SafeTrip API 클라이언트
/// Firebase ID Token을 자동으로 헤더에 주입한다.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: dotenv.env['API_SERVER_URL'] ?? 'http://10.0.2.2:3001',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.addAll([
    _AuthInterceptor(),
  ]);
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // 토큰 발급 실패 시 요청 계속 (서버가 401 반환)
    }
    handler.next(options);
  }
}
```

**Step 3: analysis_options.yaml 업데이트**

`safetrip-mobile/analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    missing_required_param: error
    missing_return: error

linter:
  rules:
    avoid_print: true               # debugPrint 사용
    prefer_const_constructors: true
    prefer_final_fields: true
    prefer_single_quotes: true
    sort_constructors_first: true
    use_super_parameters: true
```

**Step 4: Flutter analyze 실행**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze
```
Expected: `api_client.dart`에서 일부 warning 가능. Error 없어야 함.

**Step 5: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-mobile/lib/core safetrip-mobile/lib/features safetrip-mobile/lib/shared
git add safetrip-mobile/analysis_options.yaml
git commit -m "chore: scaffold feature-based folder structure for production Flutter

- Create core/, features/, shared/ directory structure
- Add ApiClient with Firebase ID Token interceptor
- Update analysis_options.yaml with stricter lint rules
- Ready for feature-based production development"
```

---

## ─────────────── PHASE 5: Design System ───────────────

---

### Task 11: DESIGN.md + Stitch로 디자인 토큰 확정

**배경:** 디자인 시스템 문서 없음. Flutter에 `app_tokens.dart` 등 코드 내 상수만 존재.
Stitch MCP를 활용해 AI로 디자인 시스템을 생성한다.

**Files:**
- Create: `docs/DESIGN.md`
- Create: `safetrip-mobile/lib/core/theme/app_colors.dart`
- Create: `safetrip-mobile/lib/core/theme/app_typography.dart`
- Create: `safetrip-mobile/lib/core/theme/app_spacing.dart`
- Create: `safetrip-mobile/lib/core/theme/app_theme.dart`

**Step 1: 비즈니스 원칙에서 디자인 관련 요구사항 확인**

`Master_docs/10_T2_화면구성원칙.md`에서:
- 역할별 색상 분류 (§4.2)
- 프라이버시 등급별 UI 차이 (§4.x)
- 바텀시트 규칙 (§4.3)

**Step 2: Stitch로 디자인 시스템 생성**

Stitch MCP(`mcp__stitch__generate_screen_from_text`)를 사용해 SafeTrip 브랜드 아이덴티티를 기반으로 디자인 시스템을 생성한다.

프롬프트 예시:
```
SafeTrip — a travel safety app with group travel management.
Design system should convey trust and safety.
Primary color: deep blue (#1A56DB) with safety green (#10B981) accent.
Role-based colors: captain=blue, crew-leader=indigo, crew=slate, guardian=green.
Privacy levels: safety-first (high contrast), standard, privacy-first (minimal data).
Clean, modern Material 3 inspired design.
```

**Step 3: DESIGN.md 작성**

`docs/DESIGN.md`:

```markdown
# SafeTrip Design System

> 버전: v1.0 | 최초 작성: 2026-03-02

---

## 색상 팔레트

### 브랜드 컬러
| 토큰명 | 값 | 용도 |
|--------|-----|------|
| `primaryBlue` | `#1A56DB` | 주요 CTA, 앱바 |
| `primaryDark` | `#1E3A8A` | 강조, 활성 상태 |
| `safetyGreen` | `#10B981` | 안전 상태, 성공 |
| `warningYellow` | `#F59E0B` | 경고, 주의 |
| `dangerRed` | `#EF4444` | SOS, 위험, 삭제 |

### 역할별 컬러 (비즈니스 원칙 §03.1)
| 역할 | 색상 | HEX |
|------|------|-----|
| 캡틴 | Blue | `#1A56DB` |
| 크루장 | Indigo | `#4F46E5` |
| 크루 | Slate | `#64748B` |
| 가디언 | Emerald | `#059669` |

### 프라이버시 등급별 UI (비즈니스 원칙 §04)
| 등급 | 설명 | 지도 위치 표시 |
|------|------|-------------|
| 안전최우선 | 모든 멤버 위치 공개 | 정밀 위치 |
| 표준 | 기본 공유 | 일반 정밀도 |
| 프라이버시우선 | 최소 공유 | 구역 수준만 |

### 시맨틱 컬러
| 토큰명 | Light | 용도 |
|--------|-------|------|
| `surface` | `#FFFFFF` | 카드, 바텀시트 배경 |
| `surfaceVariant` | `#F8FAFC` | 보조 배경 |
| `onSurface` | `#0F172A` | 본문 텍스트 |
| `onSurfaceVariant` | `#64748B` | 보조 텍스트 |
| `outline` | `#E2E8F0` | 경계선 |

---

## 타이포그래피

| 토큰명 | Size | Weight | 용도 |
|--------|:----:|:------:|------|
| `displayLarge` | 32 | Bold | 화면 제목 |
| `headlineMedium` | 24 | SemiBold | 섹션 제목 |
| `titleLarge` | 20 | SemiBold | 카드 제목, 앱바 |
| `titleMedium` | 16 | Medium | 부제목, 라벨 |
| `bodyLarge` | 16 | Regular | 본문 |
| `bodyMedium` | 14 | Regular | 부연 설명 |
| `bodySmall` | 12 | Regular | 캡션, 메타 정보 |
| `labelLarge` | 14 | SemiBold | 버튼 텍스트 |

**폰트 패밀리:** Pretendard (한국어), Inter (영문) — 없을 시 시스템 기본

---

## 스페이싱 시스템 (4px 기반)

| 토큰명 | 값 | 용도 |
|--------|:--:|------|
| `xs` | 4px | 아이콘과 텍스트 간격 |
| `sm` | 8px | 관련 요소 간격 |
| `md` | 16px | 일반 패딩, 컴포넌트 간격 |
| `lg` | 24px | 섹션 간격 |
| `xl` | 32px | 화면 상단 여백 |
| `screenPadding` | 20px | 화면 좌우 패딩 |
| `bottomSheetHandle` | 4px × 44px | 바텀시트 핸들 |

---

## 컴포넌트 규칙

### 버튼
- Primary: `primaryBlue` 배경, 흰 텍스트, 높이 52px, radius 12px
- Secondary: 흰 배경 + `primaryBlue` 테두리
- Destructive: `dangerRed` 배경
- 최소 터치 영역: 48×48px (접근성)

### 바텀시트 (Master_docs/11_T2_바텀시트_동작_규칙.md 준수)
- 핸들: 가운데 정렬, 4×44px, `outline` 색상
- 기본 높이: 화면의 50%
- 최대 높이: 화면의 90%
- 드래그로 확장/축소 지원

### 카드
- 배경: `surface`, radius: 16px
- 그림자: `BoxShadow(blurRadius: 8, color: black.withOpacity(0.06))`
- 패딩: 16px

---

## SOS UI 규칙 (비즈니스 원칙 §05.1)

- SOS 버튼: 항상 화면에 노출, `dangerRed` (#EF4444)
- SOS 발동 화면: 전체 화면 오버레이, 빨간 배경
- 활성 SOS 상태: 헤더에 지속적으로 표시

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-02 | v1.0 | 최초 작성 — 기본 토큰, 역할별/등급별 색상 |
```

**Step 4: Flutter 테마 파일 생성**

`safetrip-mobile/lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// SafeTrip 색상 시스템
/// 참조: docs/DESIGN.md
abstract class AppColors {
  // ─ 브랜드 컬러 ──────────────────────────────────
  static const primaryBlue    = Color(0xFF1A56DB);
  static const primaryDark    = Color(0xFF1E3A8A);
  static const safetyGreen    = Color(0xFF10B981);
  static const warningYellow  = Color(0xFFF59E0B);
  static const dangerRed      = Color(0xFFEF4444);

  // ─ 역할별 컬러 (비즈니스 원칙 §03.1) ─────────────
  static const captain     = Color(0xFF1A56DB);  // 캡틴
  static const crewLeader  = Color(0xFF4F46E5);  // 크루장
  static const crew        = Color(0xFF64748B);  // 크루
  static const guardian    = Color(0xFF059669);  // 가디언

  // ─ 시맨틱 컬러 ──────────────────────────────────
  static const surface           = Color(0xFFFFFFFF);
  static const surfaceVariant    = Color(0xFFF8FAFC);
  static const onSurface         = Color(0xFF0F172A);
  static const onSurfaceVariant  = Color(0xFF64748B);
  static const outline           = Color(0xFFE2E8F0);
  static const outlineVariant    = Color(0xFFF1F5F9);

  // ─ 프라이버시 등급별 위치 색상 ──────────────────────
  static const privacySafetyFirst  = Color(0xFF1A56DB);  // 안전최우선: 정밀 위치
  static const privacyStandard     = Color(0xFF64748B);  // 표준: 일반 정밀도
  static const privacyFirst        = Color(0xFF94A3B8);  // 프라이버시우선: 구역만
}
```

`safetrip-mobile/lib/core/theme/app_spacing.dart`:

```dart
/// SafeTrip 스페이싱 시스템 (4px 기반)
/// 참조: docs/DESIGN.md
abstract class AppSpacing {
  static const double xs            = 4.0;
  static const double sm            = 8.0;
  static const double md            = 16.0;
  static const double lg            = 24.0;
  static const double xl            = 32.0;
  static const double screenPadding = 20.0;

  // 바텀시트
  static const double bottomSheetHandleWidth  = 44.0;
  static const double bottomSheetHandleHeight = 4.0;
  static const double bottomSheetRadius       = 20.0;
}
```

**Step 5: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add docs/DESIGN.md
git add safetrip-mobile/lib/core/theme/
git commit -m "feat: add design system — DESIGN.md + Flutter theme tokens

- DESIGN.md: color palette, typography, spacing, component rules
- AppColors: brand colors + role-based + privacy-level colors
- AppSpacing: 4px-based spacing system
- Follows business rules v5.1 §03.1 role colors, §04 privacy levels"
```

---

### Task 12: Stitch로 주요 화면 목업 15개 생성

**목표:** 비즈니스 원칙 v5.1 기반 15개 핵심 화면의 AI 목업 생성 후 `docs/design/screens/`에 저장.

**Files:**
- Create: `docs/design/screens/` (Stitch 생성 이미지 저장 폴더)
- Create: `docs/design/stitch-prompts.md` (생성에 사용한 프롬프트 기록)

**Step 1: Stitch MCP 도구 확인**

Stitch MCP 도구 목록 확인: `mcp__stitch__*` 도구 사용 가능한지 체크.

**Step 2: docs/design/screens 디렉토리 생성**

```bash
mkdir -p /mnt/d/Project/15_SafeTrip_New/docs/design/screens
```

**Step 3: Stitch로 핵심 화면 생성**

아래 15개 화면을 `mcp__stitch__generate_screen_from_text`로 생성:

**온보딩 플로우 (4개):**
1. `01-splash.png` — 스플래시 (SafeTrip 로고, 로딩)
2. `02-welcome.png` — 웰컴 슬라이드 (앱 가치, 역할 소개)
3. `03-role-select.png` — 역할 선택 (캡틴/크루/가디언 카드)
4. `04-profile-setup.png` — 프로필 설정 (이름, 프로필 사진)

**여행 핵심 (4개):**
5. `05-main-map.png` — 메인 지도 (하단 탭바, 멤버 위치 마커)
6. `06-trip-create.png` — 여행 생성 (제목, 날짜, 국가 선택)
7. `07-member-tab.png` — 멤버탭 (역할별 목록, 가디언 섹션)
8. `08-schedule-tab.png` — 일정탭 (날짜별 일정 리스트, 추가 버튼)

**가디언 (2개):**
9. `09-guardian-home.png` — 가디언 홈 (연결된 멤버 여행 현황)
10. `10-guardian-message.png` — 가디언 메시지 (멤버→가디언 메시지 채팅)

**설정/기타 (3개):**
11. `11-settings.png` — 설정 메인 (계정, 위치공유, 가디언, 개인정보)
12. `12-profile.png` — 프로필 화면 (역할별 정보)
13. `13-safety-guide.png` — 안전가이드 (MOFA 탭, 국가별 안전 정보)

**SOS + 초대 (2개):**
14. `14-sos.png` — SOS 발동 화면 (빨간 배경, 발동 버튼)
15. `15-invite-code.png` — 초대코드 (코드 입력/공유)

**Step 4: stitch-prompts.md 기록**

`docs/design/stitch-prompts.md` 생성 — 각 화면 생성에 사용한 프롬프트 기록.

**Step 5: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add docs/design/
git commit -m "design: add screen mockups via Stitch (15 screens)

- Onboarding flow: splash, welcome, role-select, profile-setup
- Trip core: main map, trip-create, member-tab, schedule-tab
- Guardian: guardian-home, guardian-message
- Settings: settings-main, profile, safety-guide
- SOS + invite code screens"
```

---

## ─────────────── Go/No-go 체크리스트 ───────────────

### Task 13: 최종 검증 — 프로덕션 개발 시작 준비 확인

**이 체크리스트를 모두 통과해야 Flutter 프로덕션 개발 시작 가능.**

**Step 1: 기술 기반 검증**

```bash
# 1. tb_country 테이블 존재 확인
psql -U safetrip -d safetrip_local -c "\d tb_country"
# Expected: 테이블 구조 출력

# 2. countries API 정상 확인
curl -s http://localhost:3001/api/v1/countries | jq '.success'
# Expected: true

# 3. GET /users/me 정상 확인 (token 필요)
curl -H "Authorization: Bearer $TOKEN" http://localhost:3001/api/v1/users/me | jq '.success'
# Expected: true

# 4. 전체 UAT 재확인
bash /mnt/d/Project/15_SafeTrip_New/scripts/test/run-all-tests.sh
# Expected: 모든 Phase pass
```

**Step 2: 환경 설정 검증**

```bash
# 5. 백엔드 환경 파일 존재
ls -la /mnt/d/Project/15_SafeTrip_New/safetrip-server-api/.env*
# Expected: .env, .env.local, .env.example (+ gitignored .env.staging, .env.production)

# 6. Flutter 환경 파일 존재
ls -la /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/.env*
# Expected: .env, .env.local, .env.example

# 7. CI/CD 파일 존재
ls /mnt/d/Project/15_SafeTrip_New/.github/workflows/
# Expected: backend-test.yml, flutter-analyze.yml
```

**Step 3: 아키텍처 검증**

```bash
# 8. ARCHITECTURE.md 존재
ls /mnt/d/Project/15_SafeTrip_New/docs/ARCHITECTURE.md

# 9. Flutter 폴더 구조 검증
ls /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/lib/core/
ls /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/lib/features/

# 10. flutter analyze clean
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze
# Expected: No issues found!
```

**Step 4: 디자인 시스템 검증**

```bash
# 11. DESIGN.md 존재
ls /mnt/d/Project/15_SafeTrip_New/docs/DESIGN.md

# 12. 화면 목업 파일 수 확인
ls /mnt/d/Project/15_SafeTrip_New/docs/design/screens/ | wc -l
# Expected: 15개 이상

# 13. Flutter 테마 파일 존재
ls /mnt/d/Project/15_SafeTrip_New/safetrip-mobile/lib/core/theme/
# Expected: app_colors.dart, app_typography.dart, app_spacing.dart, app_theme.dart
```

**Step 5: 최종 Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add docs/ARCHITECTURE.md docs/DESIGN.md docs/design/
git commit -m "docs: complete pre-development preparation

Go/No-go checklist passed:
✅ tb_country table + 34 countries seeded
✅ GET /users/me route ordering fixed
✅ Firebase Functions inventoried
✅ Backend/Flutter env structure (dev/staging/prod)
✅ GitHub Actions CI/CD pipelines
✅ ARCHITECTURE.md (Riverpod, feature-based, Dio)
✅ Feature-based folder structure scaffolded
✅ DESIGN.md + Flutter theme tokens
✅ 15 screen mockups via Stitch

Ready to start Flutter production development."
```

---

## 실행 완료 기준

| Phase | 완료 기준 |
|-------|----------|
| P1 버그 수정 | `/api/v1/countries` 200 OK, `GET /me` 200 OK, UAT 재통과 |
| P2 백엔드 완성 | Firebase Functions 인벤토리 완성, 백엔드 테스트 5개 pass |
| P3 환경 설정 | 환경별 .env 파일 생성, GitHub Actions 워크플로우 동작 |
| P4 아키텍처 | ARCHITECTURE.md 완성, feature-based 폴더 스캐폴딩, flutter analyze clean |
| P5 디자인 | DESIGN.md 완성, 15개 목업, Flutter 테마 토큰 |
| **최종** | **Go/No-go 체크리스트 13개 항목 모두 ✅** |
