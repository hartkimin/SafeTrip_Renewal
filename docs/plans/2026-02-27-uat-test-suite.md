# SafeTrip UAT 테스트 스위트 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 사용자 입장에서 역할별(Captain/Crew/Guardian) 전체 앱 사용 경험을 5개 Phase로 자동화 검증하고, Flutter 수동 체크리스트를 작성한다.

**Architecture:** 기존 `scripts/test-onboarding.ts` 패턴을 기반으로 공유 유틸리티를 추출하고, 각 Phase를 독립 TypeScript 스크립트로 작성한다. Layer 1(API 자동화)과 Layer 2(Flutter 수동 체크리스트)를 분리한다.

**Tech Stack:** TypeScript + tsx, Node.js http 모듈, PostgreSQL (pg), Firebase Auth Emulator, Firebase RTDB Emulator

---

## Task 0: 환경 진단 및 실제 이슈 확인

**목적:** 서버 상태, Firebase 에뮬레이터, 스케줄 API 실제 동작을 검증한다.

**Step 1: 환경 상태 확인**

```bash
# 1a. 서버 실행 확인
curl -s http://localhost:3001/health | jq .

# 1b. Firebase Auth 에뮬레이터 확인
curl -s http://localhost:9099/ | head -5

# 1c. PostgreSQL 확인
docker ps --filter "name=postgres" --format "{{.Names}} {{.Status}}"
```

Expected: 서버 `{"status":"ok"}`, postgres Running

**Step 2: 스케줄 API 진단**

```bash
# DB에서 tb_travel_schedule 확인
docker exec safetrip-postgres psql -U safetrip -d safetrip_local \
  -c "SELECT table_name FROM information_schema.tables WHERE table_name LIKE '%schedule%';"

# 서버 로그 확인
tail -50 /tmp/safetrip-backend.log | grep -i "schedule\|error" | head -20
```

**Step 3: 서버 미실행 시 시작**

```bash
cd safetrip-server-api
cp .env.local .env
npm run dev > /tmp/safetrip-backend.log 2>&1 &
sleep 3
curl -s http://localhost:3001/health
```

---

## Task 1: 공유 테스트 유틸리티 생성

**목적:** 모든 Phase 스크립트에서 재사용할 HTTP/Firebase/DB 헬퍼를 분리한다.

**Files:**
- Create: `scripts/test/utils/test-client.ts`

**Step 1: 디렉토리 생성**

```bash
mkdir -p scripts/test/utils
```

**Step 2: `scripts/test/utils/test-client.ts` 작성**

```typescript
// scripts/test/utils/test-client.ts
import * as http from 'http';
import * as https from 'https';
import { Pool } from 'pg';

export const CONFIG = {
  serverUrl:       'http://localhost:3001',
  firebaseAuthUrl: 'http://localhost:9099',
  firebaseRTDBUrl: 'http://localhost:9000',
  firebaseProject: 'safetrip-urock',
  db: {
    host:     process.env.DB_HOST     ?? 'localhost',
    port:     parseInt(process.env.DB_PORT ?? '5432'),
    database: process.env.DB_NAME     ?? 'safetrip_local',
    user:     process.env.DB_USER     ?? 'safetrip',
    password: process.env.DB_PASSWORD ?? 'safetrip_local_2024',
  },
};

export const TEST_PHONES = {
  captain:    '+821099901001',
  crew1:      '+821099901002',
  crewChief:  '+821099901003',
  guardian:   '+821099901004',
  crew2:      '+821099901005',
};

export interface CheckResult {
  label: string;
  passed: boolean;
  detail?: string;
}

export interface PhaseResult {
  phase: string;
  passed: boolean;
  checks: CheckResult[];
  error?: string;
}

export function withTimeout<T>(promise: Promise<T>, ms = 10000): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`Timeout after ${ms}ms`)), ms)
    ),
  ]);
}

export function httpRequest(
  method: string,
  url: string,
  body?: object,
  headers: Record<string, string> = {}
): Promise<{ status: number; data: any }> {
  return withTimeout(new Promise((resolve, reject) => {
    const bodyStr = body ? JSON.stringify(body) : '';
    const parsed = new URL(url);
    const isHttps = parsed.protocol === 'https:';
    const options = {
      hostname: parsed.hostname,
      port:     parseInt(parsed.port || (isHttps ? '443' : '80')),
      path:     parsed.pathname + parsed.search,
      method,
      headers: {
        'Content-Type':   'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
        ...headers,
      },
    };
    const lib = isHttps ? https : http;
    const req = lib.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode!, data: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode!, data }); }
      });
    });
    req.on('error', reject);
    if (bodyStr) req.write(bodyStr);
    req.end();
  }));
}

export const httpPost   = (url: string, body: object, headers?: Record<string, string>) => httpRequest('POST',   url, body, headers);
export const httpGet    = (url: string, headers?: Record<string, string>) => httpRequest('GET',    url, undefined, headers);
export const httpPatch  = (url: string, body: object, headers?: Record<string, string>) => httpRequest('PATCH',  url, body, headers);
export const httpDelete = (url: string, headers?: Record<string, string>) => httpRequest('DELETE', url, undefined, headers);

export const Firebase = {
  async sendVerificationCode(phoneNumber: string): Promise<string> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=fake-api-key`;
    const res = await httpPost(url, { phoneNumber, iosReceipt: '' });
    if (!res.data.sessionInfo) throw new Error(`sendVerificationCode failed: ${JSON.stringify(res.data)}`);
    return res.data.sessionInfo as string;
  },

  async getVerificationCode(phoneNumber: string): Promise<{ code: string; sessionInfo: string }> {
    const url = `${CONFIG.firebaseAuthUrl}/emulator/v1/projects/${CONFIG.firebaseProject}/verificationCodes`;
    const res = await httpGet(url);
    const codes: any[] = res.data.verificationCodes ?? [];
    const match = [...codes].reverse().find(c => c.phoneNumber === phoneNumber);
    if (!match) throw new Error(`No verification code for ${phoneNumber}`);
    return { code: match.code, sessionInfo: match.sessionInfo };
  },

  async signInWithPhone(sessionInfo: string, code: string): Promise<{ idToken: string; localId: string }> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=fake-api-key`;
    const res = await httpPost(url, { sessionInfo, code });
    if (!res.data.idToken) throw new Error(`signIn failed: ${JSON.stringify(res.data)}`);
    return { idToken: res.data.idToken, localId: res.data.localId };
  },

  async getIdToken(phoneNumber: string): Promise<{ idToken: string; localId: string }> {
    await this.sendVerificationCode(phoneNumber);
    const { code, sessionInfo } = await this.getVerificationCode(phoneNumber);
    return this.signInWithPhone(sessionInfo, code);
  },

  async deleteAccount(idToken: string): Promise<void> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:delete?key=fake-api-key`;
    await httpPost(url, { idToken });
  },
};

export function createPool(): Pool {
  return new Pool(CONFIG.db);
}

export async function dbQuery(pool: Pool, sql: string, params: any[] = []): Promise<any[]> {
  const res = await pool.query(sql, params);
  return res.rows;
}

export function apiPost(path: string, body: object, idToken?: string) {
  const headers: Record<string, string> = {};
  if (idToken) headers['Authorization'] = `Bearer ${idToken}`;
  return httpPost(`${CONFIG.serverUrl}${path}`, body, headers);
}

export function apiGet(path: string, idToken?: string) {
  const headers: Record<string, string> = {};
  if (idToken) headers['Authorization'] = `Bearer ${idToken}`;
  return httpGet(`${CONFIG.serverUrl}${path}`, headers);
}

export function apiPatch(path: string, body: object, idToken?: string) {
  const headers: Record<string, string> = {};
  if (idToken) headers['Authorization'] = `Bearer ${idToken}`;
  return httpPatch(`${CONFIG.serverUrl}${path}`, body, headers);
}

export function apiDelete(path: string, idToken?: string) {
  const headers: Record<string, string> = {};
  if (idToken) headers['Authorization'] = `Bearer ${idToken}`;
  return httpDelete(`${CONFIG.serverUrl}${path}`, headers);
}

export async function verifyWithServer(idToken: string, displayName: string): Promise<string> {
  const res = await apiPost('/api/v1/auth/firebase-verify', { displayName }, idToken);
  if (res.status !== 200 && res.status !== 201) {
    throw new Error(`firebase-verify failed (${res.status}): ${JSON.stringify(res.data)}`);
  }
  return res.data.userId ?? res.data.user?.user_id;
}

export function printResults(results: PhaseResult[]): void {
  console.log('\n══════════════════════════════════════════');
  console.log('  SafeTrip UAT 테스트 결과');
  console.log('══════════════════════════════════════════');
  let totalPass = 0, totalFail = 0;
  for (const r of results) {
    const icon = r.passed ? '✅' : '❌';
    console.log(`\n${icon} ${r.phase}`);
    if (r.error) console.log(`   ERROR: ${r.error}`);
    for (const c of r.checks) {
      const ci = c.passed ? '  ✓' : '  ✗';
      console.log(`${ci} ${c.label}${c.detail ? ` — ${c.detail}` : ''}`);
    }
    if (r.passed) totalPass++; else totalFail++;
  }
  console.log(`\n══════════════════════════════════════════`);
  console.log(`  합계: ${totalPass}/${totalPass + totalFail} 통과`);
  console.log('══════════════════════════════════════════\n');
  if (totalFail > 0) process.exit(1);
}
```

**Step 3: 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New
npx tsx --no-warnings scripts/test/utils/test-client.ts 2>&1 | head -5
# Expected: 에러 없음
```

---

## Task 2: Phase 1 — Captain 온보딩 자동화 스크립트

**목적:** Captain이 Firebase 인증부터 여행 생성, 초대 코드 발급까지 완료하는지 검증한다.

**Files:**
- Create: `scripts/test/phase1-captain-onboarding.ts`

**Step 1: Firebase Auth 에뮬레이터 계정 초기화**

```bash
curl -s -X DELETE \
  "http://localhost:9099/emulator/v1/projects/safetrip-urock/accounts" \
  -H "Authorization: Bearer owner"
# Expected: {}
```

**Step 2: `scripts/test/phase1-captain-onboarding.ts` 작성**

```typescript
// scripts/test/phase1-captain-onboarding.ts
import * as fs from 'fs';
import {
  Firebase, apiPost, apiGet, createPool, dbQuery,
  TEST_PHONES, PhaseResult, CheckResult, printResults
} from './utils/test-client';

async function runPhase1(): Promise<PhaseResult> {
  const pool = createPool();
  const checks: CheckResult[] = [];
  let captainIdToken = '';
  let captainUserId = '';
  let groupId = '';
  let tripId = '';

  try {
    // ── 1. Firebase 인증 ────────────────────────────────────────────
    console.log('[Phase1] Captain Firebase 인증...');
    const auth = await Firebase.getIdToken(TEST_PHONES.captain);
    captainIdToken = auth.idToken;
    checks.push({ label: 'Captain Firebase 인증 성공', passed: true, detail: `uid: ${auth.localId}` });

    // ── 2. 서버 firebase-verify ────────────────────────────────────
    console.log('[Phase1] 서버 인증 (firebase-verify)...');
    const verifyRes = await apiPost('/api/v1/auth/firebase-verify',
      { displayName: '테스트 캡틴' }, captainIdToken);
    const passedVerify = verifyRes.status === 200 || verifyRes.status === 201;
    captainUserId = verifyRes.data?.userId ?? verifyRes.data?.user?.user_id ?? '';
    checks.push({
      label: 'firebase-verify 200/201',
      passed: passedVerify,
      detail: `status=${verifyRes.status}, userId=${captainUserId}`,
    });
    if (!passedVerify) throw new Error(`firebase-verify failed: ${JSON.stringify(verifyRes.data)}`);

    // ── 3. DB tb_user 확인 ────────────────────────────────────────
    console.log('[Phase1] DB tb_user 확인...');
    const users = await dbQuery(pool,
      `SELECT user_id, phone_number FROM tb_user WHERE phone_number = $1`,
      [TEST_PHONES.captain]);
    checks.push({ label: 'tb_user INSERT 확인', passed: users.length > 0, detail: `rows: ${users.length}` });
    if (users.length === 0) throw new Error('tb_user not created');
    captainUserId = users[0].user_id;

    // ── 4. 여행 생성 ──────────────────────────────────────────────
    console.log('[Phase1] 여행 생성...');
    const tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1);
    const nextWeek  = new Date(); nextWeek.setDate(nextWeek.getDate() + 7);
    const tripRes = await apiPost('/api/v1/trips', {
      trip_name: 'UAT 테스트 여행',
      country_code: 'JP',
      country_name: '일본',
      destination_city: '도쿄',
      trip_type: 'leisure',
      start_date: tomorrow.toISOString().split('T')[0],
      end_date:   nextWeek.toISOString().split('T')[0],
    }, captainIdToken);
    const passedTrip = tripRes.status === 200 || tripRes.status === 201;
    tripId  = tripRes.data?.trip?.trip_id  ?? tripRes.data?.tripId  ?? '';
    groupId = tripRes.data?.group?.group_id ?? tripRes.data?.groupId ?? '';
    checks.push({
      label: '여행 생성 200/201',
      passed: passedTrip,
      detail: `status=${tripRes.status}, tripId=${tripId}`,
    });
    if (!passedTrip) throw new Error(`trip create failed: ${JSON.stringify(tripRes.data)}`);

    // ── 5. DB 레코드 확인 ─────────────────────────────────────────
    const trips = await dbQuery(pool, `SELECT trip_id FROM tb_trip WHERE trip_id = $1`, [tripId]);
    checks.push({ label: 'tb_trip 레코드 존재', passed: trips.length > 0 });

    const members = await dbQuery(pool,
      `SELECT member_role, trip_id FROM tb_group_member WHERE group_id = $1 AND user_id = $2`,
      [groupId, captainUserId]);
    checks.push({
      label: 'Captain member_role = captain',
      passed: members[0]?.member_role === 'captain',
      detail: `role=${members[0]?.member_role}`,
    });
    checks.push({
      label: 'tb_group_member.trip_id NOT NULL',
      passed: members[0]?.trip_id != null,
      detail: `trip_id=${members[0]?.trip_id}`,
    });

    // ── 6. 초대 코드 생성 ─────────────────────────────────────────
    console.log('[Phase1] 초대 코드 생성...');
    const travelerCodeRes = await apiPost(
      `/api/v1/groups/${groupId}/invite-codes`,
      { role_type: 'traveler', max_uses: 20 },
      captainIdToken
    );
    const travelerCode = travelerCodeRes.data?.code ?? travelerCodeRes.data?.invite_code?.code ?? '';
    checks.push({
      label: 'Traveler 초대 코드 생성',
      passed: travelerCodeRes.status === 200 || travelerCodeRes.status === 201,
      detail: `code=${travelerCode}`,
    });

    const guardianCodeRes = await apiPost(
      `/api/v1/groups/${groupId}/invite-codes`,
      { role_type: 'guardian', max_uses: 5 },
      captainIdToken
    );
    const guardianCode = guardianCodeRes.data?.code ?? guardianCodeRes.data?.invite_code?.code ?? '';
    checks.push({
      label: 'Guardian 초대 코드 생성',
      passed: guardianCodeRes.status === 200 || guardianCodeRes.status === 201,
      detail: `code=${guardianCode}`,
    });

    // ── 상태 저장 ─────────────────────────────────────────────────
    fs.writeFileSync('/tmp/safetrip-test-state.json', JSON.stringify({
      captainIdToken, captainUserId, groupId, tripId, travelerCode, guardianCode,
    }, null, 2));
    console.log('[Phase1] 상태 저장 → /tmp/safetrip-test-state.json');

    return { phase: 'Phase 1: Captain 온보딩', passed: checks.every(c => c.passed), checks };
  } catch (error: any) {
    return { phase: 'Phase 1: Captain 온보딩', passed: false, checks, error: error.message };
  } finally {
    await pool.end();
  }
}

runPhase1().then(result => printResults([result]));
```

**Step 3: 실행 및 확인**

```bash
npx tsx scripts/test/phase1-captain-onboarding.ts
```

Expected:
```
✅ Phase 1: Captain 온보딩
  ✓ Captain Firebase 인증 성공
  ✓ firebase-verify 200/201
  ✓ tb_user INSERT 확인
  ✓ 여행 생성 200/201
  ✓ tb_trip 레코드 존재
  ✓ Captain member_role = captain
  ✓ tb_group_member.trip_id NOT NULL
  ✓ Traveler 초대 코드 생성
  ✓ Guardian 초대 코드 생성
합계: 1/1 통과
```

---

## Task 3: Phase 2 — 멤버 초대 및 역할별 권한 검증

**Files:**
- Create: `scripts/test/phase2-member-roles.ts`
- Read: `/tmp/safetrip-test-state.json`

**Step 1: `scripts/test/phase2-member-roles.ts` 작성**

```typescript
// scripts/test/phase2-member-roles.ts
import * as fs from 'fs';
import {
  Firebase, apiPost, apiGet, apiPatch, createPool, dbQuery,
  TEST_PHONES, PhaseResult, CheckResult, printResults
} from './utils/test-client';

async function runPhase2(): Promise<PhaseResult> {
  const state = JSON.parse(fs.readFileSync('/tmp/safetrip-test-state.json', 'utf8'));
  const pool = createPool();
  const checks: CheckResult[] = [];

  try {
    // ── 1. Crew #1 가입 ────────────────────────────────────────────
    console.log('[Phase2] Crew #1 Firebase 인증 및 가입...');
    const crew1Auth = await Firebase.getIdToken(TEST_PHONES.crew1);
    await apiPost('/api/v1/auth/firebase-verify', { displayName: '테스트 크루1' }, crew1Auth.idToken);

    const joinRes = await apiPost(
      `/api/v1/groups/join-by-code/${state.travelerCode}`,
      {}, crew1Auth.idToken
    );
    checks.push({
      label: 'Crew #1 초대코드 가입 200',
      passed: joinRes.status === 200 || joinRes.status === 201,
      detail: `status=${joinRes.status}`,
    });

    const crew1UserId = (await dbQuery(pool,
      `SELECT user_id FROM tb_user WHERE phone_number = $1`,
      [TEST_PHONES.crew1]))[0]?.user_id;

    const crew1Members = await dbQuery(pool,
      `SELECT member_role, trip_id FROM tb_group_member WHERE group_id = $1 AND user_id = $2`,
      [state.groupId, crew1UserId]);
    checks.push({
      label: 'Crew #1 member_role = crew',
      passed: crew1Members[0]?.member_role === 'crew',
      detail: `role=${crew1Members[0]?.member_role}`,
    });
    checks.push({
      label: 'Crew #1 trip_id NOT NULL',
      passed: crew1Members[0]?.trip_id != null,
      detail: `trip_id=${crew1Members[0]?.trip_id}`,
    });

    // ── 2. Crew Chief 가입 및 승격 ────────────────────────────────
    console.log('[Phase2] Crew Chief 가입 및 승격...');
    const ccAuth = await Firebase.getIdToken(TEST_PHONES.crewChief);
    await apiPost('/api/v1/auth/firebase-verify', { displayName: '테스트 크루치프' }, ccAuth.idToken);
    await apiPost(`/api/v1/groups/join-by-code/${state.travelerCode}`, {}, ccAuth.idToken);

    const ccUserId = (await dbQuery(pool,
      `SELECT user_id FROM tb_user WHERE phone_number = $1`,
      [TEST_PHONES.crewChief]))[0]?.user_id;

    const promoteRes = await apiPatch(
      `/api/v1/groups/${state.groupId}/members/${ccUserId}`,
      { member_role: 'crew_chief' },
      state.captainIdToken
    );
    checks.push({
      label: 'Captain이 Crew Chief 승격 200',
      passed: promoteRes.status === 200,
      detail: `status=${promoteRes.status}`,
    });

    const ccMembers = await dbQuery(pool,
      `SELECT member_role, is_admin FROM tb_group_member WHERE group_id = $1 AND user_id = $2`,
      [state.groupId, ccUserId]);
    checks.push({
      label: 'Crew Chief is_admin = true',
      passed: ccMembers[0]?.is_admin === true,
      detail: `role=${ccMembers[0]?.member_role}, is_admin=${ccMembers[0]?.is_admin}`,
    });

    // ── 3. 권한 분리 테스트 ───────────────────────────────────────
    console.log('[Phase2] 권한 분리 테스트...');

    // Crew가 초대코드 생성 시도 → 403
    const crewInviteRes = await apiPost(
      `/api/v1/groups/${state.groupId}/invite-codes`,
      { role_type: 'traveler' }, crew1Auth.idToken
    );
    checks.push({
      label: 'Crew 초대코드 생성 → 403',
      passed: crewInviteRes.status === 403,
      detail: `status=${crewInviteRes.status}`,
    });

    // Crew가 유저 검색 → 403
    const crewSearchRes = await apiGet('/api/v1/users/search?q=테스트', crew1Auth.idToken);
    checks.push({
      label: 'Crew 유저 검색 → 403',
      passed: crewSearchRes.status === 403,
      detail: `status=${crewSearchRes.status}`,
    });

    // Crew Chief가 Captain 강등 시도 → 403
    const ccChangeCaptainRes = await apiPatch(
      `/api/v1/groups/${state.groupId}/members/${state.captainUserId}`,
      { member_role: 'crew' }, ccAuth.idToken
    );
    checks.push({
      label: 'Crew Chief → Captain 강등 시도 → 403',
      passed: ccChangeCaptainRes.status === 403,
      detail: `status=${ccChangeCaptainRes.status}`,
    });

    // Captain: 유저 검색 → 200
    const captainSearchRes = await apiGet('/api/v1/users/search?q=테스트', state.captainIdToken);
    checks.push({
      label: 'Captain 유저 검색 → 200',
      passed: captainSearchRes.status === 200,
      detail: `count=${captainSearchRes.data?.users?.length ?? 'N/A'}`,
    });

    // ── 상태 업데이트 ─────────────────────────────────────────────
    const updatedState = { ...state, crew1IdToken: crew1Auth.idToken, crew1UserId, ccIdToken: ccAuth.idToken, ccUserId };
    fs.writeFileSync('/tmp/safetrip-test-state.json', JSON.stringify(updatedState, null, 2));

    return { phase: 'Phase 2: 멤버 초대 및 역할 권한', passed: checks.every(c => c.passed), checks };
  } catch (error: any) {
    return { phase: 'Phase 2: 멤버 초대 및 역할 권한', passed: false, checks, error: error.message };
  } finally {
    await pool.end();
  }
}

runPhase2().then(result => printResults([result]));
```

**Step 2: 실행**

```bash
npx tsx scripts/test/phase2-member-roles.ts
```

Expected: 8개 체크 통과

---

## Task 4: Phase 3 — 가디언 시스템 검증

**Files:**
- Create: `scripts/test/phase3-guardian-system.ts`

**Step 1: `scripts/test/phase3-guardian-system.ts` 작성**

```typescript
// scripts/test/phase3-guardian-system.ts
import * as fs from 'fs';
import {
  Firebase, apiPost, apiGet, httpGet,
  createPool, dbQuery, CONFIG,
  TEST_PHONES, PhaseResult, CheckResult, printResults
} from './utils/test-client';

async function getRTDB(path: string): Promise<any> {
  const url = `${CONFIG.firebaseRTDBUrl}/${path}.json?ns=${CONFIG.firebaseProject}`;
  const res = await httpGet(url, { Authorization: 'Bearer owner' });
  return res.data;
}

async function runPhase3(): Promise<PhaseResult> {
  const state = JSON.parse(fs.readFileSync('/tmp/safetrip-test-state.json', 'utf8'));
  const pool = createPool();
  const checks: CheckResult[] = [];

  try {
    // ── 1. Guardian 온보딩 ────────────────────────────────────────
    console.log('[Phase3] Guardian Firebase 인증...');
    const guardianAuth = await Firebase.getIdToken(TEST_PHONES.guardian);
    const guardianVerify = await apiPost('/api/v1/auth/firebase-verify',
      { displayName: '테스트 가디언' }, guardianAuth.idToken);
    const guardianUserId = guardianVerify.data?.userId ?? guardianVerify.data?.user?.user_id;
    checks.push({
      label: 'Guardian tb_user 생성',
      passed: (guardianVerify.status === 200 || guardianVerify.status === 201) && !!guardianUserId,
      detail: `userId=${guardianUserId}`,
    });

    // ── 2. Guardian 초대코드 가입 ─────────────────────────────────
    console.log('[Phase3] Guardian 초대코드 가입...');
    const guardianJoinRes = await apiPost(
      `/api/v1/groups/join-by-code/${state.guardianCode}`,
      {}, guardianAuth.idToken
    );
    checks.push({
      label: 'Guardian 초대코드 가입 200',
      passed: guardianJoinRes.status === 200 || guardianJoinRes.status === 201,
      detail: `status=${guardianJoinRes.status}`,
    });

    const guardianMembers = await dbQuery(pool,
      `SELECT member_role FROM tb_group_member WHERE group_id = $1 AND user_id = $2`,
      [state.groupId, guardianUserId]);
    checks.push({
      label: 'Guardian member_role = guardian',
      passed: guardianMembers[0]?.member_role === 'guardian',
      detail: `role=${guardianMembers[0]?.member_role}`,
    });

    // ── 3. Traveler → Guardian 승인 요청 ─────────────────────────
    console.log('[Phase3] 가디언 승인 요청...');
    const approvalReqRes = await apiPost(
      `/api/v1/trips/${state.tripId}/guardian-approval/request`,
      { guardian_id: guardianUserId },
      state.crew1IdToken
    );
    const approvalRequestId = approvalReqRes.data?.request_id ?? approvalReqRes.data?.requestId;
    checks.push({
      label: '가디언 승인 요청 생성',
      passed: approvalReqRes.status === 200 || approvalReqRes.status === 201,
      detail: `status=${approvalReqRes.status}, requestId=${approvalRequestId}`,
    });

    const pendingLinks = await dbQuery(pool,
      `SELECT status FROM tb_guardian_link WHERE guardian_id = $1 AND member_id = $2`,
      [guardianUserId, state.crew1UserId]);
    checks.push({
      label: 'tb_guardian_link status = pending',
      passed: pendingLinks[0]?.status === 'pending',
      detail: `status=${pendingLinks[0]?.status}`,
    });

    // ── 4. Guardian 승인 ─────────────────────────────────────────
    console.log('[Phase3] 가디언 승인...');
    const pendingRes = await apiGet(
      `/api/v1/trips/${state.tripId}/guardian-approval/pending`,
      guardianAuth.idToken
    );
    const pendingList: any[] = pendingRes.data?.requests ?? pendingRes.data ?? [];
    const requestId = pendingList[0]?.request_id ?? approvalRequestId;

    const approveRes = await apiPost(
      `/api/v1/trips/${state.tripId}/guardian-approval/${requestId}/approve`,
      {}, guardianAuth.idToken
    );
    checks.push({
      label: '가디언 승인 200',
      passed: approveRes.status === 200,
      detail: `status=${approveRes.status}`,
    });

    const acceptedLinks = await dbQuery(pool,
      `SELECT status FROM tb_guardian_link WHERE guardian_id = $1 AND member_id = $2`,
      [guardianUserId, state.crew1UserId]);
    checks.push({
      label: 'tb_guardian_link status = accepted',
      passed: acceptedLinks[0]?.status === 'accepted',
      detail: `status=${acceptedLinks[0]?.status}`,
    });

    // ── 5. 멤버 → 가디언 메시지 (RTDB) ──────────────────────────
    console.log('[Phase3] 멤버→가디언 메시지...');
    const msgText = 'UAT 테스트 메시지';
    const memberMsgRes = await apiPost(
      `/api/v1/trips/${state.tripId}/guardian-messages/member`,
      { message: msgText, link_id: `${state.crew1UserId}_${guardianUserId}` },
      state.crew1IdToken
    );
    checks.push({
      label: '멤버→가디언 메시지 전송 200',
      passed: memberMsgRes.status === 200 || memberMsgRes.status === 201,
      detail: `status=${memberMsgRes.status}`,
    });

    await new Promise(r => setTimeout(r, 500));
    const ids = [state.crew1UserId, guardianUserId].sort();
    const channelKey = `member_${ids[0]}_${ids[1]}`;
    const rtdbMessages = await getRTDB(`guardian_messages/${state.tripId}/${channelKey}/messages`);
    const hasMessage = rtdbMessages && Object.values(rtdbMessages as Record<string, any>)
      .some((m: any) => m.text === msgText);
    checks.push({
      label: 'RTDB 멤버→가디언 메시지 존재',
      passed: !!hasMessage,
      detail: `channel: ${channelKey}`,
    });

    // ── 6. 가디언 → Captain 메시지 ──────────────────────────────
    console.log('[Phase3] 가디언→Captain 메시지...');
    const captainMsgRes = await apiPost(
      `/api/v1/trips/${state.tripId}/guardian-messages/captain`,
      { message: 'Captain에게 UAT 메시지' },
      guardianAuth.idToken
    );
    checks.push({
      label: '가디언→Captain 메시지 200',
      passed: captainMsgRes.status === 200 || captainMsgRes.status === 201,
      detail: `status=${captainMsgRes.status}`,
    });

    const captainChannelKey = `captain_${guardianUserId}`;
    const captainMessages = await getRTDB(
      `guardian_messages/${state.tripId}/${captainChannelKey}/messages`
    );
    const hasCaptainMsg = captainMessages && Object.values(captainMessages as Record<string, any>)
      .some((m: any) => m.text === 'Captain에게 UAT 메시지');
    checks.push({
      label: 'RTDB 가디언→Captain 메시지 존재',
      passed: !!hasCaptainMsg,
      detail: `channel: ${captainChannelKey}`,
    });

    // ── 상태 업데이트 ─────────────────────────────────────────────
    const updatedState = { ...state, guardianIdToken: guardianAuth.idToken, guardianUserId };
    fs.writeFileSync('/tmp/safetrip-test-state.json', JSON.stringify(updatedState, null, 2));

    return { phase: 'Phase 3: 가디언 시스템', passed: checks.every(c => c.passed), checks };
  } catch (error: any) {
    return { phase: 'Phase 3: 가디언 시스템', passed: false, checks, error: error.message };
  } finally {
    await pool.end();
  }
}

runPhase3().then(result => printResults([result]));
```

**Step 2: 실행**

```bash
npx tsx scripts/test/phase3-guardian-system.ts
```

Expected: 10개 체크 통과

---

## Task 5: 스케줄 API 진단 및 수정

**목적:** 스케줄 API 500 에러 원인 파악 및 수정 (필요 시).

**Files:**
- Read: `safetrip-server-api/src/controllers/groups.controller.ts`
- Modify: `safetrip-server-api/src/controllers/groups.controller.ts` (필요 시)

**Step 1: 실제 스케줄 API 호출 테스트**

```bash
# 상태에서 값 추출
GROUP_ID=$(python3 -c "import json; d=json.load(open('/tmp/safetrip-test-state.json')); print(d['groupId'])")
TOKEN=$(python3 -c "import json; d=json.load(open('/tmp/safetrip-test-state.json')); print(d['captainIdToken'])")
USER_ID=$(python3 -c "import json; d=json.load(open('/tmp/safetrip-test-state.json')); print(d['captainUserId'])")

curl -s -X POST "http://localhost:3001/api/v1/groups/${GROUP_ID}/schedules" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"${USER_ID}\",\"title\":\"진단 테스트\",\"schedule_type\":\"sightseeing\",\"start_time\":\"2026-03-02T09:00:00Z\"}" | jq .
```

**Step 2: 에러 분석 및 수정**

- `404 relation "tb_travel_schedule" does not exist` →
  ```bash
  docker exec safetrip-postgres psql -U safetrip -d safetrip_local -f /path/to/01-init-schema.sql
  ```
- `500 checkMemberPermission` → `groups.controller.ts`에서 user_id 파라미터 처리 확인

  ```bash
  grep -n "user_id\|userId" safetrip-server-api/src/controllers/groups.controller.ts | grep -A3 "createSchedule"
  ```

  수정 예시 (user_id가 req.body에서만 읽히는 경우):
  ```typescript
  // groups.controller.ts ~line 480
  const userId = (req as any).user?.userId ?? req.body.user_id;
  ```

**Step 3: 수정 후 서버 재시작**

```bash
pkill -f "tsx watch" 2>/dev/null || true
cd safetrip-server-api && npm run dev > /tmp/safetrip-backend.log 2>&1 &
sleep 3
```

---

## Task 6: Phase 4 — 일상 사용 기능 자동화 스크립트

**Files:**
- Create: `scripts/test/phase4-daily-features.ts`

**Step 1: `scripts/test/phase4-daily-features.ts` 작성**

```typescript
// scripts/test/phase4-daily-features.ts
import * as fs from 'fs';
import {
  apiPost, apiGet, apiPatch, apiDelete,
  createPool, dbQuery,
  PhaseResult, CheckResult, printResults
} from './utils/test-client';

async function runPhase4(): Promise<PhaseResult> {
  const state = JSON.parse(fs.readFileSync('/tmp/safetrip-test-state.json', 'utf8'));
  const pool = createPool();
  const checks: CheckResult[] = [];
  let scheduleId = '';

  try {
    // ── 1. 스케줄 생성 ────────────────────────────────────────────
    console.log('[Phase4] 스케줄 생성...');
    const scheduleRes = await apiPost(
      `/api/v1/groups/${state.groupId}/schedules`,
      {
        user_id: state.captainUserId,
        title: 'UAT 도쿄 타워 방문',
        schedule_type: 'sightseeing',
        start_time: '2026-03-02T09:00:00Z',
        end_time: '2026-03-02T11:00:00Z',
        location_name: '도쿄 타워',
        location_address: '1 Chome-4-1 Shibakoen, Minato City, Tokyo',
        location_coords: { latitude: 35.6586, longitude: 139.7454 },
        timezone: 'Asia/Tokyo',
      },
      state.captainIdToken
    );
    scheduleId = scheduleRes.data?.schedule_id ?? scheduleRes.data?.scheduleId ?? '';
    checks.push({
      label: '스케줄 생성 200/201',
      passed: scheduleRes.status === 200 || scheduleRes.status === 201,
      detail: `status=${scheduleRes.status}, scheduleId=${scheduleId}`,
    });

    if (scheduleId) {
      const rows = await dbQuery(pool,
        `SELECT title FROM tb_travel_schedule WHERE schedule_id = $1`, [scheduleId]);
      checks.push({
        label: 'tb_travel_schedule INSERT 확인',
        passed: rows.length > 0,
        detail: `title=${rows[0]?.title}`,
      });
    }

    // ── 2. 스케줄 목록 조회 ───────────────────────────────────────
    console.log('[Phase4] 스케줄 목록 조회...');
    const listRes = await apiGet(
      `/api/v1/groups/${state.groupId}/schedules`,
      state.captainIdToken
    );
    checks.push({
      label: '스케줄 목록 200',
      passed: listRes.status === 200,
      detail: `count=${Array.isArray(listRes.data) ? listRes.data.length : 'N/A'}`,
    });

    // ── 3. 스케줄 수정 ────────────────────────────────────────────
    if (scheduleId) {
      console.log('[Phase4] 스케줄 수정...');
      const updateRes = await apiPatch(
        `/api/v1/groups/${state.groupId}/schedules/${scheduleId}`,
        { title: 'UAT 도쿄 타워 방문 (수정됨)', user_id: state.captainUserId },
        state.captainIdToken
      );
      checks.push({
        label: '스케줄 수정 200',
        passed: updateRes.status === 200,
        detail: `status=${updateRes.status}`,
      });
    }

    // ── 4. 지오펜스 생성 ──────────────────────────────────────────
    console.log('[Phase4] 지오펜스 생성...');
    const geofenceRes = await apiPost(
      `/api/v1/groups/${state.groupId}/geofences`,
      {
        name: 'UAT 호텔 지오펜스',
        type: 'safe',
        shape_type: 'circle',
        center_latitude: 35.6762,
        center_longitude: 139.6503,
        radius_meters: 200,
        trigger_on_enter: true,
        trigger_on_exit: true,
        is_always_active: true,
      },
      state.captainIdToken
    );
    checks.push({
      label: '지오펜스 생성 200/201',
      passed: geofenceRes.status === 200 || geofenceRes.status === 201,
      detail: `status=${geofenceRes.status}`,
    });

    // ── 5. 출석체크 시작 ──────────────────────────────────────────
    console.log('[Phase4] 출석체크 시작...');
    const attendanceRes = await apiPost(
      `/api/v1/groups/${state.groupId}/attendance/start`,
      {}, state.captainIdToken
    );
    checks.push({
      label: '출석체크 시작 200',
      passed: attendanceRes.status === 200 || attendanceRes.status === 201,
      detail: `status=${attendanceRes.status}`,
    });

    // ── 6. 스케줄 삭제 ────────────────────────────────────────────
    if (scheduleId) {
      console.log('[Phase4] 스케줄 삭제...');
      const deleteRes = await apiDelete(
        `/api/v1/groups/${state.groupId}/schedules/${scheduleId}?user_id=${state.captainUserId}`,
        state.captainIdToken
      );
      checks.push({
        label: '스케줄 삭제 200',
        passed: deleteRes.status === 200,
        detail: `status=${deleteRes.status}`,
      });

      const deletedRows = await dbQuery(pool,
        `SELECT deleted_at FROM tb_travel_schedule WHERE schedule_id = $1`, [scheduleId]);
      checks.push({
        label: '스케줄 soft delete 확인',
        passed: deletedRows[0]?.deleted_at != null,
      });
    }

    return { phase: 'Phase 4: 일상 사용 기능', passed: checks.every(c => c.passed), checks };
  } catch (error: any) {
    return { phase: 'Phase 4: 일상 사용 기능', passed: false, checks, error: error.message };
  } finally {
    await pool.end();
  }
}

runPhase4().then(result => printResults([result]));
```

**Step 2: 실행**

```bash
npx tsx scripts/test/phase4-daily-features.ts
```

Expected: 7개 체크 통과

---

## Task 7: Phase 5 — 엣지 케이스 검증

**Files:**
- Create: `scripts/test/phase5-edge-cases.ts`

**Step 1: `scripts/test/phase5-edge-cases.ts` 작성**

```typescript
// scripts/test/phase5-edge-cases.ts
import * as fs from 'fs';
import {
  Firebase, apiPost, apiGet, apiPatch,
  createPool, dbQuery,
  TEST_PHONES, PhaseResult, CheckResult, printResults
} from './utils/test-client';

async function runPhase5(): Promise<PhaseResult> {
  const state = JSON.parse(fs.readFileSync('/tmp/safetrip-test-state.json', 'utf8'));
  const pool = createPool();
  const checks: CheckResult[] = [];

  try {
    // ── EC-001: 앱 삭제 후 재설치 시뮬레이션 ─────────────────────
    console.log('[Phase5] EC-001: 재설치 시뮬레이션...');
    // "재설치" = 새 idToken 발급 (동일 전화번호)
    const crew2Auth1 = await Firebase.getIdToken(TEST_PHONES.crew2);
    await apiPost('/api/v1/auth/firebase-verify', { displayName: '크루2' }, crew2Auth1.idToken);
    await apiPost(`/api/v1/groups/join-by-code/${state.travelerCode}`, {}, crew2Auth1.idToken);

    const crew2UserId = (await dbQuery(pool,
      `SELECT user_id FROM tb_user WHERE phone_number = $1`,
      [TEST_PHONES.crew2]))[0]?.user_id;

    // "앱 재설치" = 새 idToken (동일 계정 재인증)
    const crew2Auth2 = await Firebase.getIdToken(TEST_PHONES.crew2);
    const verifyRes = await apiPost('/api/v1/auth/firebase-verify',
      { displayName: '크루2' }, crew2Auth2.idToken);
    const restoredUserId = verifyRes.data?.userId ?? verifyRes.data?.user?.user_id;

    const tripsRes = await apiGet(
      `/api/v1/trips/users/${restoredUserId}/trips`,
      crew2Auth2.idToken
    );
    const trips: any[] = tripsRes.data?.trips ?? tripsRes.data ?? [];
    checks.push({
      label: 'EC-001: 재설치 후 기존 여행 복원',
      passed: trips.some((t: any) => t.trip_id === state.tripId),
      detail: `found trips: ${trips.length}`,
    });

    const dupCheck = await dbQuery(pool,
      `SELECT COUNT(*)::int as cnt FROM tb_group_member WHERE group_id = $1 AND user_id = $2`,
      [state.groupId, crew2UserId]);
    checks.push({
      label: 'EC-001: 중복 tb_group_member 없음',
      passed: dupCheck[0]?.cnt === 1,
      detail: `count=${dupCheck[0]?.cnt}`,
    });

    // ── EC-002: 초대코드 직접 가입 (역할 선택 없음) ───────────────
    console.log('[Phase5] EC-002: 초대코드 직접 가입...');
    const anonPhone = '+821099990099';
    const anonAuth = await Firebase.getIdToken(anonPhone);
    await apiPost('/api/v1/auth/firebase-verify', { displayName: '익명 테스터' }, anonAuth.idToken);

    const anonJoinRes = await apiPost(
      `/api/v1/groups/join-by-code/${state.travelerCode}`,
      {}, anonAuth.idToken
    );
    checks.push({
      label: 'EC-002: 초대코드 직접 가입 200',
      passed: anonJoinRes.status === 200 || anonJoinRes.status === 201,
      detail: `status=${anonJoinRes.status}`,
    });

    const anonUserId = (await dbQuery(pool,
      `SELECT user_id FROM tb_user WHERE phone_number = $1`, [anonPhone]))[0]?.user_id;
    const anonMembers = await dbQuery(pool,
      `SELECT member_role FROM tb_group_member WHERE group_id = $1 AND user_id = $2`,
      [state.groupId, anonUserId]);
    checks.push({
      label: 'EC-002: 자동 role=crew 할당',
      passed: anonMembers[0]?.member_role === 'crew',
      detail: `role=${anonMembers[0]?.member_role}`,
    });

    // ── EC-003: Captain 역할 이전 ─────────────────────────────────
    console.log('[Phase5] EC-003: Captain 역할 이전...');
    const transferRes = await apiPost(
      `/api/v1/groups/${state.groupId}/transfer-leadership`,
      { new_captain_user_id: state.ccUserId },
      state.captainIdToken
    );
    checks.push({
      label: 'EC-003: 역할 이전 200',
      passed: transferRes.status === 200,
      detail: `status=${transferRes.status}`,
    });

    const oldCaptainRow = await dbQuery(pool,
      `SELECT member_role FROM tb_group_member WHERE group_id = $1 AND user_id = $2`,
      [state.groupId, state.captainUserId]);
    checks.push({
      label: 'EC-003: 원 Captain 강등됨',
      passed: oldCaptainRow[0]?.member_role !== 'captain',
      detail: `role=${oldCaptainRow[0]?.member_role}`,
    });

    const newCaptainRow = await dbQuery(pool,
      `SELECT member_role FROM tb_group_member WHERE group_id = $1 AND user_id = $2`,
      [state.groupId, state.ccUserId]);
    checks.push({
      label: 'EC-003: 새 Captain 승격됨',
      passed: newCaptainRow[0]?.member_role === 'captain',
      detail: `role=${newCaptainRow[0]?.member_role}`,
    });

    // 정리
    await Firebase.deleteAccount(anonAuth.idToken);

    return { phase: 'Phase 5: 엣지 케이스', passed: checks.every(c => c.passed), checks };
  } catch (error: any) {
    return { phase: 'Phase 5: 엣지 케이스', passed: false, checks, error: error.message };
  } finally {
    await pool.end();
  }
}

runPhase5().then(result => printResults([result]));
```

**Step 2: 실행**

```bash
npx tsx scripts/test/phase5-edge-cases.ts
```

Expected: 6개 체크 통과

---

## Task 8: Flutter 수동 체크리스트 문서 작성

**Files:**
- Create: `docs/test/flutter-manual-checklist.md`

**Step 1: 디렉토리 생성**

```bash
mkdir -p docs/test
```

**Step 2: 체크리스트 작성 (도구로 파일 생성)**

내용: 위 설계 문서의 수동 체크리스트 항목을 마크다운으로 저장

섹션 구조:
1. 준비사항 (에뮬레이터 설정, .env, 서버 실행)
2. Phase 1: Captain 온보딩 UI (10개 항목)
3. Phase 2: Crew/Crew Chief UI (8개 항목)
4. Phase 3: Guardian UI (12개 항목)
5. Phase 4: 일상 기능 UI (10개 항목)
6. Phase 5: 엣지 케이스 UI (4개 항목)
7. 알려진 이슈 & 주의사항

**Step 3: 확인**

```bash
wc -l docs/test/flutter-manual-checklist.md
# Expected: 80+ lines
```

---

## Task 9: 통합 테스트 실행기 및 최종 실행

**Files:**
- Create: `scripts/test/run-all-tests.sh`

**Step 1: `scripts/test/run-all-tests.sh` 작성 (셸 스크립트, 안전한 고정 인자)**

```bash
#!/usr/bin/env bash
# scripts/test/run-all-tests.sh
# 모든 Phase를 순서대로 실행

set -e
BASE="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$BASE"

echo ""
echo "====== SafeTrip UAT 테스트 스위트 시작 ======"
echo ""

PASS=0
FAIL=0

run_phase() {
  local name="$1"
  local script="$2"
  echo ""
  echo "──── $name ────"
  if npx tsx "$script"; then
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
}

run_phase "Phase 1: Captain 온보딩"    "scripts/test/phase1-captain-onboarding.ts"
run_phase "Phase 2: 멤버 역할 권한"    "scripts/test/phase2-member-roles.ts"
run_phase "Phase 3: 가디언 시스템"     "scripts/test/phase3-guardian-system.ts"
run_phase "Phase 4: 일상 사용 기능"    "scripts/test/phase4-daily-features.ts"
run_phase "Phase 5: 엣지 케이스"       "scripts/test/phase5-edge-cases.ts"

echo ""
echo "====== 최종 결과: ${PASS}/5 Phase 통과 ======"
echo ""
[ "$FAIL" -eq 0 ] || exit 1
```

**Step 2: 실행 권한 부여 및 전체 실행**

```bash
chmod +x scripts/test/run-all-tests.sh

# 사전 조건 확인
curl -s http://localhost:3001/health
curl -s "http://localhost:9099/emulator/v1/projects/safetrip-urock/config" | head -3

# 전체 실행
bash scripts/test/run-all-tests.sh 2>&1 | tee /tmp/uat-results.txt
```

**Step 3: Notion에 기록**

Notion 페이지 `314a19580398808fb3d2e36b5187e358`에 2026-02-27 개발사항 페이지 추가:
- 테스트 스위트 파일 목록
- 각 Phase 통과/실패 결과
- 수정된 버그 내역 (스케줄 API 포함)

---

## 파일 구조 요약

```
scripts/
  test/
    utils/
      test-client.ts              # 공유 HTTP/Firebase/DB 헬퍼
    phase1-captain-onboarding.ts  # Phase 1 자동화
    phase2-member-roles.ts        # Phase 2 자동화
    phase3-guardian-system.ts     # Phase 3 자동화
    phase4-daily-features.ts      # Phase 4 자동화
    phase5-edge-cases.ts          # Phase 5 자동화
    run-all-tests.sh              # 전체 실행 스크립트

docs/
  plans/
    2026-02-27-uat-test-plan-design.md  # 설계 문서 (기존)
    2026-02-27-uat-test-suite.md        # 이 구현 계획
  test/
    flutter-manual-checklist.md          # Flutter 수동 체크리스트

/tmp/
  safetrip-test-state.json  # Phase 간 상태 공유 (런타임)
  uat-results.txt           # 최종 결과 로그
```

---

## 실행 순서

```
Task 0 → Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 → Task 7 → Task 8 → Task 9
(진단)   (유틸)  (Phase1) (Phase2) (Phase3) (수정)   (Phase4) (Phase5) (문서)   (전체실행)
```

각 Phase 스크립트는 이전 Phase가 `/tmp/safetrip-test-state.json`을 생성한 후 실행해야 한다.
