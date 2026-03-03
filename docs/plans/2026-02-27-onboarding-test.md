# SafeTrip 온보딩 통합 테스트 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** `scripts/test-onboarding.ts` 스크립트로 온보딩 8개 시나리오를 자동 실행하여 각 시나리오의 API 응답과 DB 상태를 검증한다.

**Architecture:** Firebase 에뮬레이터 REST API로 ID Token을 발급하고, 백엔드 `POST /api/v1/auth/firebase-verify`에 실제 HTTP 요청을 보낸다. 각 시나리오 실행 후 직접 PostgreSQL에 쿼리하여 DB 상태를 검증한다. 테스트 간 격리를 위해 각 시나리오 전후에 테스트 데이터를 cleanup한다.

**Tech Stack:** Node.js + TypeScript, `tsx` (ts 직접 실행), `node-fetch` (HTTP), `pg` (PostgreSQL 직접 쿼리)

**Prerequisites:**
- 서버 실행 중: `cd safetrip-server-api && npm run dev`
- Firebase 에뮬레이터 실행 중: `firebase emulators:start`
- PostgreSQL 실행 중 (DB: `safetrip_local`)

---

## 환경 설정 값

```
서버:          http://localhost:3001
Firebase Auth: http://localhost:9099
PostgreSQL:    localhost:5432 / safetrip_local / safetrip / safetrip_local_2024
Firebase PID:  safetrip-urock
```

---

## Task 1: 스크립트 뼈대 + Config 작성

**Files:**
- Create: `scripts/test-onboarding.ts`

**Step 1: 파일 생성 — Config + 타입 정의**

```typescript
// scripts/test-onboarding.ts
import * as https from 'https';
import * as http from 'http';
import { Pool } from 'pg';

// ─── Config ───────────────────────────────────────────────────────────────────
const CONFIG = {
  serverUrl:       'http://localhost:3001',
  firebaseAuthUrl: 'http://localhost:9099',
  firebaseProject: 'safetrip-urock',
  db: {
    host:     'localhost',
    port:     5432,
    database: 'safetrip_local',
    user:     'safetrip',
    password: 'safetrip_local_2024',
  },
};

// 테스트용 전화번호 (실제 사용자와 충돌하지 않는 범위)
const TEST_PHONES = {
  newTrip:           '+821099901001',
  newInvite:         '+821099901002',
  newContinue:       '+821099901003',
  existingWithTrip:  '+821099901004',
  existingNoTrip:    '+821099901005',
  anonTest:          '+821099990001',  // SC-08 Anonymous Auth 테스트
};

// ─── 결과 타입 ────────────────────────────────────────────────────────────────
interface ScenarioResult {
  id:     string;
  name:   string;
  passed: boolean;
  error?: string;
  checks: Array<{ label: string; passed: boolean; detail?: string }>;
}

const results: ScenarioResult[] = [];
```

**Step 2: 스크립트가 타입 에러 없이 컴파일되는지 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts 2>&1 | head -20
```
Expected: 빈 출력 (아직 main 없음) 또는 module not found (pg)

**Step 3: `node-fetch` 없이 내장 http 모듈로 헬퍼 추가 (의존성 추가 불필요)**

```typescript
// ─── HTTP 헬퍼 ──────────────────────────────────────────────────────────────
function httpPost(url: string, body: object, headers?: Record<string, string>): Promise<{status: number; data: any}> {
  return new Promise((resolve, reject) => {
    const bodyStr = JSON.stringify(body);
    const parsed = new URL(url);
    const options = {
      hostname: parsed.hostname,
      port:     parseInt(parsed.port || '80'),
      path:     parsed.pathname + parsed.search,
      method:   'POST',
      headers: {
        'Content-Type':   'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
        ...headers,
      },
    };
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode!, data: JSON.parse(data) }); }
        catch  { resolve({ status: res.statusCode!, data }); }
      });
    });
    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

function httpGet(url: string, headers?: Record<string, string>): Promise<{status: number; data: any}> {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const options = {
      hostname: parsed.hostname,
      port:     parseInt(parsed.port || '80'),
      path:     parsed.pathname + parsed.search,
      method:   'GET',
      headers:  headers ?? {},
    };
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode!, data: JSON.parse(data) }); }
        catch  { resolve({ status: res.statusCode!, data }); }
      });
    });
    req.on('error', reject);
    req.end();
  });
}
```

**Step 4: 실행 확인**

```bash
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts
```
Expected: 오류 없이 종료

**Step 5: Commit**

```bash
git add scripts/test-onboarding.ts
git commit -m "test: add onboarding test script skeleton with config and HTTP helpers"
```

---

## Task 2: FirebaseHelper — 에뮬레이터로 ID Token 발급

**Files:**
- Modify: `scripts/test-onboarding.ts`

**Background:** Firebase Auth 에뮬레이터는 아래 REST 순서로 phone auth ID Token을 발급한다.
```
1. POST /identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode
   body: { "phoneNumber": "+82...", "iosReceipt": "" }
   → { "sessionInfo": "<session>" }

2. GET /emulator/v1/projects/<pid>/verificationCodes
   → { "verificationCodes": [{ "phoneNumber", "code", "sessionInfo" }] }

3. POST /identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber
   body: { "sessionInfo": "<session>", "code": "<code>" }
   → { "idToken": "<jwt>", "localId": "<uid>" }
```

**Step 1: FirebaseHelper 추가**

```typescript
// ─── Firebase 에뮬레이터 헬퍼 ─────────────────────────────────────────────────
const Firebase = {
  /** 전화번호로 SMS 인증 요청 → sessionInfo 반환 */
  async sendVerificationCode(phoneNumber: string): Promise<string> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=fake-api-key`;
    const res = await httpPost(url, { phoneNumber, iosReceipt: '' });
    if (!res.data.sessionInfo) throw new Error(`sendVerificationCode 실패: ${JSON.stringify(res.data)}`);
    return res.data.sessionInfo;
  },

  /** 에뮬레이터에서 최신 인증번호 조회 */
  async getVerificationCode(phoneNumber: string): Promise<{ code: string; sessionInfo: string }> {
    const url = `${CONFIG.firebaseAuthUrl}/emulator/v1/projects/${CONFIG.firebaseProject}/verificationCodes`;
    const res = await httpGet(url);
    if (!res.data.verificationCodes?.length) throw new Error('verificationCodes 비어 있음');
    // 해당 전화번호의 가장 최근 코드 찾기
    const codes: any[] = res.data.verificationCodes;
    const match = [...codes].reverse().find(c => c.phoneNumber === phoneNumber);
    if (!match) throw new Error(`${phoneNumber}의 verificationCode 없음`);
    return { code: match.code, sessionInfo: match.sessionInfo };
  },

  /** sessionInfo + code → idToken 발급 */
  async signInWithPhone(sessionInfo: string, code: string): Promise<{ idToken: string; localId: string }> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=fake-api-key`;
    const res = await httpPost(url, { sessionInfo, code });
    if (!res.data.idToken) throw new Error(`signInWithPhoneNumber 실패: ${JSON.stringify(res.data)}`);
    return { idToken: res.data.idToken, localId: res.data.localId };
  },

  /** 전화번호로 ID Token 한 번에 발급 (3단계 통합) */
  async getIdToken(phoneNumber: string): Promise<{ idToken: string; localId: string }> {
    await this.sendVerificationCode(phoneNumber);
    // 에뮬레이터가 코드 생성하는 시간 대기
    await new Promise(r => setTimeout(r, 300));
    const { code, sessionInfo } = await this.getVerificationCode(phoneNumber);
    return this.signInWithPhone(sessionInfo, code);
  },

  /** Firebase에서 유저 삭제 (테스트 cleanup) */
  async deleteUser(localId: string): Promise<void> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:delete?key=fake-api-key`;
    await httpPost(url, { localId });
  },

  /** 에뮬레이터 유저 전체 조회 */
  async listUsers(): Promise<any[]> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/projects/${CONFIG.firebaseProject}/accounts:batchGet?maxResults=100`;
    const res = await httpGet(url, { 'Authorization': 'Bearer owner' });
    return res.data.users ?? [];
  },
};
```

**Step 2: 간단한 테스트 실행으로 Firebase 헬퍼 동작 확인**

```typescript
// 파일 하단에 임시로 추가
async function main() {
  console.log('🔥 Firebase 에뮬레이터 연결 테스트...');
  try {
    const { idToken, localId } = await Firebase.getIdToken(TEST_PHONES.newTrip);
    console.log(`✅ ID Token 발급 성공 (uid: ${localId})`);
    console.log(`   Token: ${idToken.substring(0, 40)}...`);
    await Firebase.deleteUser(localId);
    console.log('✅ 테스트 유저 삭제 완료');
  } catch (e) {
    console.error('❌ Firebase 테스트 실패:', e);
  }
}
main();
```

```bash
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts
```
Expected:
```
🔥 Firebase 에뮬레이터 연결 테스트...
✅ ID Token 발급 성공 (uid: xxxx)
   Token: eyJhbGciOiJSUzI1NiIsImtpZCI6...
✅ 테스트 유저 삭제 완료
```

**Step 3: Commit**

```bash
git add scripts/test-onboarding.ts
git commit -m "test: add Firebase emulator helper for ID token issuance"
```

---

## Task 3: DbHelper — PostgreSQL 직접 검증 헬퍼

**Files:**
- Modify: `scripts/test-onboarding.ts`

**Step 1: DbHelper 추가 (pg Pool 사용)**

```typescript
// ─── DB 헬퍼 ──────────────────────────────────────────────────────────────────
let dbPool: Pool | null = null;

function getDb(): Pool {
  if (!dbPool) {
    dbPool = new Pool(CONFIG.db);
    dbPool.on('connect', async client => {
      await client.query("SET timezone = 'UTC'");
    });
  }
  return dbPool;
}

const Db = {
  /** user_id 또는 phone_number로 tb_user 조회 */
  async getUserByPhone(phoneE164: string): Promise<any | null> {
    const res = await getDb().query(
      `SELECT user_id, phone_number, display_name, created_at, last_verification_at
       FROM tb_user WHERE phone_number = $1 AND deleted_at IS NULL`,
      [phoneE164]
    );
    return res.rows[0] ?? null;
  },

  async getUserById(userId: string): Promise<any | null> {
    const res = await getDb().query(
      `SELECT user_id, phone_number, display_name, created_at, last_verification_at, updated_at
       FROM tb_user WHERE user_id = $1 AND deleted_at IS NULL`,
      [userId]
    );
    return res.rows[0] ?? null;
  },

  /** group_member 수 조회 */
  async getGroupMemberCount(userId: string): Promise<number> {
    const res = await getDb().query(
      `SELECT COUNT(*)::int as cnt FROM tb_group_member WHERE user_id = $1 AND status = 'active'`,
      [userId]
    );
    return res.rows[0]?.cnt ?? 0;
  },

  /** 테스트 유저 및 연관 데이터 삭제 */
  async cleanupUser(phoneE164: string): Promise<void> {
    const user = await this.getUserByPhone(phoneE164);
    if (!user) return;
    const uid = user.user_id;
    // FK 의존 순서대로 삭제
    await getDb().query(`DELETE FROM tb_group_member WHERE user_id = $1`, [uid]);
    await getDb().query(`DELETE FROM tb_user WHERE user_id = $1`, [uid]);
  },

  /** 기존 유저 + trip 세트업 (SC-04, SC-07용) */
  async seedExistingUserWithTrip(phoneE164: string, uid: string): Promise<{ groupId: string; tripId: string }> {
    const db = getDb();
    // 유저 생성
    await db.query(
      `INSERT INTO tb_user (user_id, phone_number, phone_country_code, display_name, last_verification_at, last_active_at)
       VALUES ($1, $2, '+82', '테스트유저', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       ON CONFLICT (user_id) DO UPDATE SET last_verification_at = CURRENT_TIMESTAMP`,
      [uid, phoneE164]
    );
    // 그룹 생성
    const gRes = await db.query(
      `INSERT INTO tb_group (group_id, group_name, owner_user_id, status)
       VALUES (gen_random_uuid(), '테스트그룹', $1, 'active')
       RETURNING group_id`,
      [uid]
    );
    const groupId: string = gRes.rows[0].group_id;
    // trip 생성
    const tRes = await db.query(
      `INSERT INTO tb_trip (trip_id, group_id, country_code, country_name, start_date, end_date, trip_type, status, created_by)
       VALUES (gen_random_uuid(), $1, 'JPN', '일본', CURRENT_DATE, CURRENT_DATE + 7, 'overseas', 'active', $2)
       RETURNING trip_id`,
      [groupId, uid]
    );
    const tripId: string = tRes.rows[0].trip_id;
    // group_member 생성 (trip_id 포함)
    await db.query(
      `INSERT INTO tb_group_member (group_id, user_id, member_role, trip_id, status, joined_at)
       VALUES ($1, $2, 'captain', $3, 'active', CURRENT_TIMESTAMP)`,
      [groupId, uid, tripId]
    );
    return { groupId, tripId };
  },

  /** 기존 유저만 (trip 없음, SC-05, SC-06용) */
  async seedExistingUserNoTrip(phoneE164: string, uid: string): Promise<void> {
    await getDb().query(
      `INSERT INTO tb_user (user_id, phone_number, phone_country_code, display_name, last_verification_at, last_active_at)
       VALUES ($1, $2, '+82', '기존유저', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       ON CONFLICT (user_id) DO UPDATE SET last_verification_at = CURRENT_TIMESTAMP`,
      [uid, phoneE164]
    );
  },

  /** 관련 데이터 전체 cleanup */
  async cleanupByUid(uid: string): Promise<void> {
    const db = getDb();
    await db.query(`DELETE FROM tb_group_member WHERE user_id = $1`, [uid]);
    // trip 삭제 전 group_id 수집
    const trips = await db.query(`SELECT trip_id, group_id FROM tb_trip WHERE created_by = $1`, [uid]);
    for (const row of trips.rows) {
      await db.query(`DELETE FROM tb_trip WHERE trip_id = $1`, [row.trip_id]);
    }
    const groups = await db.query(`SELECT group_id FROM tb_group WHERE owner_user_id = $1`, [uid]);
    for (const row of groups.rows) {
      await db.query(`DELETE FROM tb_group WHERE group_id = $1`, [row.group_id]);
    }
    await db.query(`DELETE FROM tb_user WHERE user_id = $1`, [uid]);
  },

  async close(): Promise<void> {
    if (dbPool) await dbPool.end();
  },
};
```

**Step 2: DB 연결 확인 — main() 수정**

```typescript
async function main() {
  console.log('🗄️  DB 연결 테스트...');
  const user = await Db.getUserByPhone('+82100000000');
  console.log('✅ DB 연결 성공 (유저:', user ? '있음' : '없음', ')');
  await Db.close();
}
```

```bash
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts
```
Expected: `✅ DB 연결 성공 (유저: 없음)`

**Step 3: Commit**

```bash
git add scripts/test-onboarding.ts
git commit -m "test: add DB helper for PostgreSQL verification and seed data"
```

---

## Task 4: ApiHelper + ScenarioRunner 프레임워크

**Files:**
- Modify: `scripts/test-onboarding.ts`

**Step 1: ApiHelper (백엔드 /auth/firebase-verify 호출)**

```typescript
// ─── API 헬퍼 ─────────────────────────────────────────────────────────────────
const Api = {
  /** POST /api/v1/auth/firebase-verify */
  async firebaseVerify(idToken: string, options?: {
    phoneCountryCode?: string;
    isTestDevice?: boolean;
    testPhoneNumber?: string;
  }): Promise<{ status: number; data: any }> {
    const body: Record<string, any> = {
      id_token:           idToken,
      phone_country_code: options?.phoneCountryCode ?? '+82',
    };
    if (options?.isTestDevice) {
      body.is_test_device  = true;
      body.test_phone_number = options.testPhoneNumber;
    }
    return httpPost(`${CONFIG.serverUrl}/api/v1/auth/firebase-verify`, body);
  },
};
```

**Step 2: ScenarioRunner 프레임워크**

```typescript
// ─── 시나리오 러너 ──────────────────────────────────────────────────────────────
type Check = { label: string; passed: boolean; detail?: string };

function check(label: string, condition: boolean, detail?: string): Check {
  return { label, passed: condition, detail };
}

async function runScenario(
  id: string,
  name: string,
  fn: () => Promise<Check[]>
): Promise<void> {
  process.stdout.write(`\n[${id}] ${name} ... `);
  try {
    const checks = await fn();
    const failed  = checks.filter(c => !c.passed);
    const passed  = failed.length === 0;
    results.push({ id, name, passed, checks });
    if (passed) {
      console.log('✅ PASS');
    } else {
      console.log('❌ FAIL');
      for (const c of failed) {
        console.log(`     ✗ ${c.label}${c.detail ? ': ' + c.detail : ''}`);
      }
    }
  } catch (e: any) {
    results.push({ id, name, passed: false, error: e.message, checks: [] });
    console.log('💥 ERROR:', e.message);
  }
}
```

**Step 3: Reporter**

```typescript
// ─── 결과 리포터 ──────────────────────────────────────────────────────────────
function printReport(): void {
  console.log('\n' + '═'.repeat(60));
  console.log('  SafeTrip 온보딩 테스트 결과');
  console.log('═'.repeat(60));
  let pass = 0, fail = 0;
  for (const r of results) {
    const icon = r.passed ? '✅' : '❌';
    console.log(`  ${icon}  [${r.id}] ${r.name}`);
    if (!r.passed) {
      if (r.error) console.log(`         💥 ${r.error}`);
      for (const c of r.checks.filter(c => !c.passed)) {
        console.log(`         ✗ ${c.label}${c.detail ? ': ' + c.detail : ''}`);
      }
      fail++;
    } else {
      pass++;
    }
  }
  console.log('═'.repeat(60));
  console.log(`  합계: ${pass} PASS, ${fail} FAIL (전체 ${results.length})`);
  console.log('═'.repeat(60) + '\n');
}
```

**Step 4: 빈 main() 추가하여 프레임워크 동작 확인**

```typescript
async function main() {
  await runScenario('SC-00', '프레임워크 동작 확인', async () => {
    return [check('항상 PASS', true)];
  });
  printReport();
  await Db.close();
}
main().catch(console.error);
```

```bash
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts
```
Expected:
```
[SC-00] 프레임워크 동작 확인 ... ✅ PASS
═══════...
  ✅  [SC-00] 프레임워크 동작 확인
  합계: 1 PASS, 0 FAIL (전체 1)
```

**Step 5: Commit**

```bash
git add scripts/test-onboarding.ts
git commit -m "test: add API helper and scenario runner framework"
```

---

## Task 5: SC-01~03 — 신규 유저 시나리오 3개

**Files:**
- Modify: `scripts/test-onboarding.ts`

**SC-01: 신규 유저 + 새 여행 만들기**
```
기대: is_new_user=true, tb_user INSERT, display_name=''
```

**SC-02: 신규 유저 + 초대 코드 참여**
```
기대: is_new_user=true, tb_user INSERT
```

**SC-03: 신규 유저 + 기존 여행 돌아가기**
```
기대: is_new_user=true (서버는 정상 응답, 클라이언트가 오류 처리)
     tb_group_member 없음 (여행 없음)
```

**Step 1: 3개 시나리오 추가**

```typescript
async function sc01_newUser_newTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.newTrip;
  // cleanup (이전 실행 잔재 제거)
  await Db.cleanupUser(phone);

  // 1. Firebase 에뮬레이터에서 ID Token 발급
  const { idToken, localId } = await Firebase.getIdToken(phone);

  // 2. 백엔드 API 호출
  const res = await Api.firebaseVerify(idToken);

  // 3. DB 검증
  const dbUser = await Db.getUserByPhone(phone);
  const memberCount = dbUser ? await Db.getGroupMemberCount(dbUser.user_id) : -1;

  // cleanup
  await Firebase.deleteUser(localId);
  if (dbUser) await Db.cleanupByUid(dbUser.user_id);

  return [
    check('HTTP 200',          res.status === 200,       `status=${res.status}`),
    check('success=true',      res.data?.success === true),
    check('is_new_user=true',  res.data?.data?.is_new_user === true),
    check('user_id 반환',       !!res.data?.data?.user_id),
    check('tb_user INSERT됨',  !!dbUser,                  dbUser ? '확인' : 'tb_user 없음'),
    check('display_name 빈값', dbUser?.display_name === ''),
    check('group_member 없음', memberCount === 0,         `count=${memberCount}`),
  ];
}

async function sc02_newUser_inviteCode(): Promise<Check[]> {
  const phone = TEST_PHONES.newInvite;
  await Db.cleanupUser(phone);

  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const dbUser = await Db.getUserByPhone(phone);

  await Firebase.deleteUser(localId);
  if (dbUser) await Db.cleanupByUid(dbUser.user_id);

  return [
    check('HTTP 200',         res.status === 200,      `status=${res.status}`),
    check('is_new_user=true', res.data?.data?.is_new_user === true),
    check('tb_user INSERT됨', !!dbUser),
  ];
}

async function sc03_newUser_continueTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.newContinue;
  await Db.cleanupUser(phone);

  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const dbUser = await Db.getUserByPhone(phone);
  const memberCount = dbUser ? await Db.getGroupMemberCount(dbUser.user_id) : -1;

  await Firebase.deleteUser(localId);
  if (dbUser) await Db.cleanupByUid(dbUser.user_id);

  // 서버는 정상 응답 (is_new_user=true), 클라이언트가 다이얼로그 처리함
  return [
    check('HTTP 200',         res.status === 200),
    check('is_new_user=true', res.data?.data?.is_new_user === true,
      '신규 유저가 continueTrip 선택 — 서버는 정상처리, 클라이언트가 오류 다이얼로그 표시'),
    check('group_member 없음', memberCount === 0, `count=${memberCount}`),
  ];
}
```

**Step 2: main() 업데이트**

```typescript
async function main() {
  await runScenario('SC-01', '신규유저 + 새여행만들기',      sc01_newUser_newTrip);
  await runScenario('SC-02', '신규유저 + 초대코드참여',      sc02_newUser_inviteCode);
  await runScenario('SC-03', '신규유저 + 기존여행돌아가기', sc03_newUser_continueTrip);
  printReport();
  await Db.close();
}
```

**Step 3: 실행 확인**

```bash
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts
```
Expected: 3개 시나리오 모두 PASS

**Step 4: Commit**

```bash
git add scripts/test-onboarding.ts
git commit -m "test: add SC-01~03 new user scenarios"
```

---

## Task 6: SC-04~05 — 기존 유저 + 새 여행 만들기

**Background:**
- SC-04: 기존 유저 + group_member 있음 → `is_new_user=false`, `user_role=captain`
- SC-05: 기존 유저 + group_member 없음 → `is_new_user=false`, `user_role=traveler`

**Step 1: 시나리오 추가**

```typescript
async function sc04_existingUser_withTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.existingWithTrip;
  // 테스트용 UID를 먼저 Firebase에 생성
  const { idToken: tmpToken, localId: uid } = await Firebase.getIdToken(phone);
  // DB에 유저 + trip 세팅
  await Db.seedExistingUserWithTrip(phone, uid);
  // 같은 UID로 다시 인증 (last_verification_at 업데이트 테스트)
  const before = await Db.getUserById(uid);
  await new Promise(r => setTimeout(r, 100)); // 타임스탬프 차이 보장
  const { idToken } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const after = await Db.getUserById(uid);
  const memberCount = await Db.getGroupMemberCount(uid);

  await Firebase.deleteUser(uid);
  await Db.cleanupByUid(uid);

  return [
    check('HTTP 200',                     res.status === 200),
    check('is_new_user=false',            res.data?.data?.is_new_user === false),
    check('user_role=captain',            res.data?.data?.user_role === 'captain',
      `actual=${res.data?.data?.user_role}`),
    check('group_member 있음',             memberCount > 0, `count=${memberCount}`),
    check('last_verification_at 업데이트', after?.last_verification_at !== before?.last_verification_at),
  ];
}

async function sc05_existingUser_noTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.existingNoTrip;
  const { idToken: tmpToken, localId: uid } = await Firebase.getIdToken(phone);
  await Db.seedExistingUserNoTrip(phone, uid);
  const { idToken } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const dbUser = await Db.getUserById(uid);
  const memberCount = await Db.getGroupMemberCount(uid);

  await Firebase.deleteUser(uid);
  await Db.cleanupByUid(uid);

  return [
    check('HTTP 200',          res.status === 200),
    check('is_new_user=false', res.data?.data?.is_new_user === false),
    check('user_role=traveler', res.data?.data?.user_role === 'traveler',
      `actual=${res.data?.data?.user_role}`),
    check('group_member 없음', memberCount === 0),
  ];
}
```

**Step 2: main() 에 추가**

```typescript
await runScenario('SC-04', '기존유저+여행있음+새여행만들기',  sc04_existingUser_withTrip);
await runScenario('SC-05', '기존유저+여행없음+새여행만들기',  sc05_existingUser_noTrip);
```

**Step 3: 실행 확인**

```bash
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts
```
Expected: SC-04, SC-05 PASS

**Step 4: Commit**

```bash
git add scripts/test-onboarding.ts
git commit -m "test: add SC-04~05 existing user scenarios"
```

---

## Task 7: SC-06~07 — 기존 유저 + 초대코드/기존여행 돌아가기

**Background:**
- SC-06: 기존 유저 + no trip + `inviteCode` → `is_new_user=false`
- SC-07: 기존 유저 + trip 있음 + `continueTrip` → `is_new_user=false`, `user_role=captain`

**Step 1: 시나리오 추가**

```typescript
async function sc06_existingUser_inviteCode(): Promise<Check[]> {
  // SC-05와 동일한 상태 (기존 유저 + no trip), entry만 다름 (클라이언트 관심사)
  // 서버 응답은 SC-05와 동일 — entry는 클라이언트가 처리
  const phone = TEST_PHONES.existingNoTrip;
  const { idToken: _, localId: uid } = await Firebase.getIdToken(phone);
  await Db.seedExistingUserNoTrip(phone, uid);
  const { idToken } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);

  await Firebase.deleteUser(uid);
  await Db.cleanupByUid(uid);

  return [
    check('HTTP 200',          res.status === 200),
    check('is_new_user=false', res.data?.data?.is_new_user === false),
    // 서버는 entry를 받지 않음 — 클라이언트가 inviteCode 경로로 분기 처리
    check('user_id 반환',       !!res.data?.data?.user_id),
  ];
}

async function sc07_existingUser_continueTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.existingWithTrip;
  const { idToken: _, localId: uid } = await Firebase.getIdToken(phone);
  await Db.seedExistingUserWithTrip(phone, uid);
  const { idToken } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const memberCount = await Db.getGroupMemberCount(uid);

  await Firebase.deleteUser(uid);
  await Db.cleanupByUid(uid);

  return [
    check('HTTP 200',          res.status === 200),
    check('is_new_user=false', res.data?.data?.is_new_user === false),
    check('user_role=captain', res.data?.data?.user_role === 'captain',
      `actual=${res.data?.data?.user_role}`),
    check('group_member 보존됨', memberCount > 0, `count=${memberCount}`),
  ];
}
```

**Step 2: main() 에 추가**

```typescript
await runScenario('SC-06', '기존유저+여행없음+초대코드참여',       sc06_existingUser_inviteCode);
await runScenario('SC-07', '기존유저+여행있음+기존여행돌아가기',   sc07_existingUser_continueTrip);
```

**Step 3: 실행 확인**

```bash
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts
```
Expected: SC-06, SC-07 PASS

**Step 4: Commit**

```bash
git add scripts/test-onboarding.ts
git commit -m "test: add SC-06~07 existing user + invite/continue scenarios"
```

---

## Task 8: SC-08 — 테스트 번호 Anonymous Auth (버그 탐지)

**Background:**
Flutter 앱에서 테스트 번호(`01099990001`)는 Firebase Phone Auth를 건너뛰고 Anonymous Auth를 사용한다.
Anonymous 토큰에는 `phone_number` 필드가 없다. 현재 백엔드 `auth.controller.ts`는
`decodedToken.phone_number`가 없으면 400을 반환한다 → 이 시나리오는 **버그 탐지** 목적이다.

클라이언트는 `test_phone_number` 파라미터를 함께 전송하지만 백엔드가 이를 처리하지 않는다.

**Step 1: SC-08 추가**

```typescript
async function sc08_testDevice_anonymous(): Promise<Check[]> {
  // Firebase 에뮬레이터에서 Anonymous 로그인 (REST API)
  const anonUrl = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;
  const anonRes = await httpPost(anonUrl, {}); // body 없으면 anonymous
  const idToken  = anonRes.data?.idToken;
  const localId  = anonRes.data?.localId;

  if (!idToken) {
    // anonymous sign-up 실패 — 에뮬레이터 설정 확인
    return [check('Anonymous ID Token 발급', false, `에뮬레이터 응답: ${JSON.stringify(anonRes.data)}`)];
  }

  // 클라이언트가 실제로 보내는 것: id_token + test_phone_number
  const res = await Api.firebaseVerify(idToken, {
    isTestDevice:    true,
    testPhoneNumber: TEST_PHONES.anonTest,
  });

  if (localId) await Firebase.deleteUser(localId);

  const isBackendHandled = res.status === 200 && res.data?.success === true;
  const isExpected400    = res.status === 400; // 현재 예상되는 버그 동작

  return [
    check(
      'Anonymous Auth 처리 여부',
      isBackendHandled,
      isExpected400
        ? '❗ 예상된 버그: 백엔드가 anonymous 토큰의 phone_number 없음으로 400 반환. ' +
          'auth.controller.ts에서 test_phone_number 파라미터 처리 필요'
        : `HTTP ${res.status}: ${JSON.stringify(res.data)}`
    ),
  ];
}
```

**Step 2: main() 에 추가**

```typescript
await runScenario('SC-08', '테스트번호 Anonymous Auth (버그탐지)', sc08_testDevice_anonymous);
```

**Step 3: 실행 확인 — 예상 결과**

```bash
npx tsx --tsconfig safetrip-server-api/tsconfig.json scripts/test-onboarding.ts
```
Expected:
```
[SC-08] 테스트번호 Anonymous Auth (버그탐지) ... ❌ FAIL
     ✗ Anonymous Auth 처리 여부: ❗ 예상된 버그: ...
```
만약 PASS라면 백엔드가 이미 처리하고 있는 것 → 리포트 확인

**Step 4: Commit**

```bash
git add scripts/test-onboarding.ts
git commit -m "test: add SC-08 anonymous auth test device scenario (bug detection)"
```

---

## Task 9: 전체 실행 + 결과 확인 + 리포트 정리

**Step 1: 최종 main() 정리**

```typescript
async function main() {
  console.log('\n🧪 SafeTrip 온보딩 통합 테스트 시작\n');
  console.log(`  서버:    ${CONFIG.serverUrl}`);
  console.log(`  Firebase: ${CONFIG.firebaseAuthUrl}`);
  console.log(`  DB:       ${CONFIG.db.host}:${CONFIG.db.port}/${CONFIG.db.database}\n`);

  // 서버 헬스 체크
  const health = await httpGet(`${CONFIG.serverUrl}/health`).catch(() => ({ status: 0, data: null }));
  if (health.status !== 200) {
    console.error('❌ 서버가 응답하지 않습니다. npm run dev를 먼저 실행하세요.');
    process.exit(1);
  }

  await runScenario('SC-01', '신규유저 + 새여행만들기',              sc01_newUser_newTrip);
  await runScenario('SC-02', '신규유저 + 초대코드참여',              sc02_newUser_inviteCode);
  await runScenario('SC-03', '신규유저 + 기존여행돌아가기',          sc03_newUser_continueTrip);
  await runScenario('SC-04', '기존유저+여행있음 + 새여행만들기',     sc04_existingUser_withTrip);
  await runScenario('SC-05', '기존유저+여행없음 + 새여행만들기',     sc05_existingUser_noTrip);
  await runScenario('SC-06', '기존유저+여행없음 + 초대코드참여',     sc06_existingUser_inviteCode);
  await runScenario('SC-07', '기존유저+여행있음 + 기존여행돌아가기', sc07_existingUser_continueTrip);
  await runScenario('SC-08', '테스트번호 Anonymous Auth (버그탐지)', sc08_testDevice_anonymous);

  printReport();
  await Db.close();
  process.exit(results.every(r => r.passed) ? 0 : 1);
}

main().catch(e => { console.error(e); process.exit(1); });
```

**Step 2: package.json에 테스트 스크립트 추가 (scripts/ 루트)**

`safetrip-server-api/package.json`의 `"scripts"`에 추가:
```json
"test:onboarding": "tsx ../scripts/test-onboarding.ts"
```

**Step 3: 전체 실행**

```bash
cd safetrip-server-api && npm run test:onboarding
```

Expected:
```
🧪 SafeTrip 온보딩 통합 테스트 시작
...
══════════════════════════════════════════════════════════
  SafeTrip 온보딩 테스트 결과
══════════════════════════════════════════════════════════
  ✅  [SC-01] 신규유저 + 새여행만들기
  ✅  [SC-02] 신규유저 + 초대코드참여
  ✅  [SC-03] 신규유저 + 기존여행돌아가기
  ✅  [SC-04] 기존유저+여행있음 + 새여행만들기
  ✅  [SC-05] 기존유저+여행없음 + 새여행만들기
  ✅  [SC-06] 기존유저+여행없음 + 초대코드참여
  ✅  [SC-07] 기존유저+여행있음 + 기존여행돌아가기
  ❌  [SC-08] 테스트번호 Anonymous Auth (버그탐지)
══════════════════════════════════════════════════════════
  합계: 7 PASS, 1 FAIL (전체 8)
══════════════════════════════════════════════════════════
```

**Step 4: Commit**

```bash
git add scripts/test-onboarding.ts safetrip-server-api/package.json
git commit -m "test: finalize onboarding integration test with full 8 scenarios"
```

---

## 참고: 서버 사전 실행 명령

```bash
# 터미널 1: Firebase 에뮬레이터
cd /mnt/d/Project/15_SafeTrip_New
firebase emulators:start --project safetrip-urock

# 터미널 2: 백엔드 서버
cd safetrip-server-api
npm run dev

# 터미널 3: 테스트 실행
npm run test:onboarding
```
