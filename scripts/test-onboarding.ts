// scripts/test-onboarding.ts
import * as http from 'http';
import { Pool } from 'pg';

// ─── Config ───────────────────────────────────────────────────────────────────
const CONFIG = {
  serverUrl:       'http://localhost:3001',
  firebaseAuthUrl: 'http://localhost:9099',
  firebaseProject: 'safetrip-urock',
  db: {
    host:     process.env.DB_HOST     ?? 'localhost',
    port:     parseInt(process.env.DB_PORT ?? '5432'),
    database: process.env.DB_NAME     ?? 'safetrip_local',
    user:     process.env.DB_USER     ?? 'safetrip',
    password: process.env.DB_PASSWORD ?? 'safetrip_local_2024',
  },
};

// 테스트용 전화번호 (실제 사용자와 충돌하지 않는 범위)
const TEST_PHONES = {
  newTrip:           '+821099901001',
  newInvite:         '+821099901002',
  newContinue:       '+821099901003',
  existingWithTrip:  '+821099901004',
  existingNoTrip:    '+821099901005',
  anonTest:          '+821099990001',
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

// ─── 타임아웃 헬퍼 ────────────────────────────────────────────────────────────
function withTimeout<T>(promise: Promise<T>, ms = 10000): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`Request timeout after ${ms}ms`)), ms)
    ),
  ]);
}

// ─── HTTP 헬퍼 ──────────────────────────────────────────────────────────────
function httpPost(url: string, body: object, headers?: Record<string, string>): Promise<{status: number; data: any}> {
  return withTimeout(new Promise((resolve, reject) => {
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
        catch (e) {
          console.error(`[HTTP] JSON parse 실패 (status=${res.statusCode}): ${data.substring(0, 200)}`);
          resolve({ status: res.statusCode!, data });
        }
      });
    });
    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  }));
}

function httpGet(url: string, headers?: Record<string, string>): Promise<{status: number; data: any}> {
  return withTimeout(new Promise((resolve, reject) => {
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
        catch (e) {
          console.error(`[HTTP] JSON parse 실패 (status=${res.statusCode}): ${data.substring(0, 200)}`);
          resolve({ status: res.statusCode!, data });
        }
      });
    });
    req.on('error', reject);
    req.end();
  }));
}

// ─── Firebase 에뮬레이터 헬퍼 ─────────────────────────────────────────────────
const Firebase = {
  /** 전화번호로 SMS 인증 요청 → sessionInfo 반환 */
  async sendVerificationCode(phoneNumber: string): Promise<string> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=fake-api-key`;
    const res = await httpPost(url, { phoneNumber, iosReceipt: '' });
    if (!res.data.sessionInfo) throw new Error(`sendVerificationCode 실패: ${JSON.stringify(res.data)}`);
    return res.data.sessionInfo as string;
  },

  /** 에뮬레이터에서 최신 인증번호 조회 */
  async getVerificationCode(phoneNumber: string): Promise<{ code: string; sessionInfo: string }> {
    const url = `${CONFIG.firebaseAuthUrl}/emulator/v1/projects/${CONFIG.firebaseProject}/verificationCodes`;
    const res = await httpGet(url);
    if (!res.data.verificationCodes?.length) throw new Error('verificationCodes 비어 있음');
    const codes: any[] = res.data.verificationCodes;
    const match = [...codes].reverse().find((c: any) => c.phoneNumber === phoneNumber);
    if (!match) throw new Error(`${phoneNumber}의 verificationCode 없음`);
    return { code: match.code as string, sessionInfo: match.sessionInfo as string };
  },

  /** sessionInfo + code → idToken 발급 */
  async signInWithPhone(sessionInfo: string, code: string): Promise<{ idToken: string; localId: string }> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=fake-api-key`;
    const res = await httpPost(url, { sessionInfo, code });
    if (!res.data.idToken) throw new Error(`signInWithPhoneNumber 실패: ${JSON.stringify(res.data)}`);
    return { idToken: res.data.idToken as string, localId: res.data.localId as string };
  },

  /** 전화번호로 ID Token 한 번에 발급 (3단계 통합) */
  async getIdToken(phoneNumber: string): Promise<{ idToken: string; localId: string }> {
    await this.sendVerificationCode(phoneNumber);
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
    return (res.data.users ?? []) as any[];
  },
};

// ─── DB 헬퍼 ──────────────────────────────────────────────────────────────────
let dbPool: Pool | null = null;

function getDb(): Pool {
  if (!dbPool) {
    dbPool = new Pool(CONFIG.db);
    dbPool.on('connect', async (client: any) => {
      await client.query("SET timezone = 'UTC'");
    });
  }
  return dbPool;
}

const Db = {
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

  async getGroupMemberCount(userId: string): Promise<number> {
    const res = await getDb().query(
      `SELECT COUNT(*)::int as cnt FROM tb_group_member WHERE user_id = $1 AND status = 'active'`,
      [userId]
    );
    return (res.rows[0]?.cnt ?? 0) as number;
  },

  async cleanupByUid(uid: string): Promise<void> {
    const db = getDb();
    // 그룹 오너 기준으로 모든 연관 데이터 삭제 (FK 순서: member → trip → group → user)
    const groups = await db.query(`SELECT group_id FROM tb_group WHERE owner_user_id = $1`, [uid]);
    for (const row of groups.rows) {
      await db.query(`DELETE FROM tb_group_member WHERE group_id = $1`, [row.group_id]);
      await db.query(`DELETE FROM tb_trip WHERE group_id = $1`, [row.group_id]);
      await db.query(`DELETE FROM tb_group WHERE group_id = $1`, [row.group_id]);
    }
    await db.query(`DELETE FROM tb_group_member WHERE user_id = $1`, [uid]); // 남은 멤버십 제거
    await db.query(`DELETE FROM tb_user WHERE user_id = $1`, [uid]);
  },

  async seedExistingUserWithTrip(phoneE164: string, uid: string): Promise<{ groupId: string; tripId: string }> {
    const db = getDb();
    await db.query(
      `INSERT INTO tb_user (user_id, phone_number, phone_country_code, display_name, last_verification_at, last_active_at)
       VALUES ($1, $2, '+82', '테스트유저', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       ON CONFLICT (user_id) DO UPDATE SET last_verification_at = CURRENT_TIMESTAMP`,
      [uid, phoneE164]
    );
    const gRes = await db.query(
      `INSERT INTO tb_group (group_id, group_name, owner_user_id, invite_code, status)
       VALUES (gen_random_uuid(), '테스트그룹', $1, substr(md5(random()::text), 1, 8), 'active')
       RETURNING group_id`,
      [uid]
    );
    const groupId = gRes.rows[0].group_id as string;
    const tRes = await db.query(
      `INSERT INTO tb_trip (trip_id, group_id, country_code, country_name, start_date, end_date, trip_type, status, created_by)
       VALUES (gen_random_uuid(), $1, 'JPN', '일본', CURRENT_DATE, CURRENT_DATE + 7, 'overseas', 'active', $2)
       RETURNING trip_id`,
      [groupId, uid]
    );
    const tripId = tRes.rows[0].trip_id as string;
    await db.query(
      `INSERT INTO tb_group_member (group_id, user_id, member_role, trip_id, status, joined_at)
       VALUES ($1, $2, 'captain', $3, 'active', CURRENT_TIMESTAMP)`,
      [groupId, uid, tripId]
    );
    return { groupId, tripId };
  },

  async seedExistingUserNoTrip(phoneE164: string, uid: string): Promise<void> {
    await getDb().query(
      `INSERT INTO tb_user (user_id, phone_number, phone_country_code, display_name, last_verification_at, last_active_at)
       VALUES ($1, $2, '+82', '기존유저', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
       ON CONFLICT (user_id) DO UPDATE SET last_verification_at = CURRENT_TIMESTAMP`,
      [uid, phoneE164]
    );
  },

  async close(): Promise<void> {
    if (dbPool) {
      await dbPool.end();
      dbPool = null;
    }
  },
};

// ─── API 헬퍼 ─────────────────────────────────────────────────────────────────
const Api = {
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
      body.is_test_device   = true;
      body.test_phone_number = options.testPhoneNumber;
    }
    return httpPost(`${CONFIG.serverUrl}/api/v1/auth/firebase-verify`, body);
  },
};

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

// ─── 시나리오 SC-01~03 ────────────────────────────────────────────────────────

async function sc01_newUser_newTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.newTrip;
  // cleanup 이전 실행 잔재
  const existing = await Db.getUserByPhone(phone);
  if (existing) await Db.cleanupByUid(existing.user_id);

  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const dbUser = await Db.getUserByPhone(phone);
  const memberCount = dbUser ? await Db.getGroupMemberCount(dbUser.user_id) : -1;

  // cleanup
  await Firebase.deleteUser(localId);
  if (dbUser) await Db.cleanupByUid(dbUser.user_id);

  return [
    check('HTTP 200',          res.status === 200,           `status=${res.status}`),
    check('success=true',      res.data?.success === true),
    check('is_new_user=true',  res.data?.data?.is_new_user === true),
    check('user_id 반환',       !!res.data?.data?.user_id),
    check('tb_user INSERT됨',  !!dbUser,                      dbUser ? '확인' : 'tb_user 없음'),
    check('display_name 빈값', dbUser?.display_name === '',   `actual='${dbUser?.display_name}'`),
    check('group_member 없음', memberCount === 0,             `count=${memberCount}`),
  ];
}

async function sc02_newUser_inviteCode(): Promise<Check[]> {
  const phone = TEST_PHONES.newInvite;
  const existing = await Db.getUserByPhone(phone);
  if (existing) await Db.cleanupByUid(existing.user_id);

  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const dbUser = await Db.getUserByPhone(phone);

  await Firebase.deleteUser(localId);
  if (dbUser) await Db.cleanupByUid(dbUser.user_id);

  return [
    check('HTTP 200',         res.status === 200,   `status=${res.status}`),
    check('is_new_user=true', res.data?.data?.is_new_user === true),
    check('tb_user INSERT됨', !!dbUser),
  ];
}

async function sc03_newUser_continueTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.newContinue;
  const existing = await Db.getUserByPhone(phone);
  if (existing) await Db.cleanupByUid(existing.user_id);

  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const dbUser = await Db.getUserByPhone(phone);
  const memberCount = dbUser ? await Db.getGroupMemberCount(dbUser.user_id) : -1;

  await Firebase.deleteUser(localId);
  if (dbUser) await Db.cleanupByUid(dbUser.user_id);

  // 서버는 정상 응답, 클라이언트가 다이얼로그 처리 (continueTrip + is_new_user = error)
  return [
    check('HTTP 200',         res.status === 200),
    check('is_new_user=true', res.data?.data?.is_new_user === true,
      '신규유저 continueTrip — 서버 정상처리, 클라이언트가 오류 다이얼로그 표시'),
    check('group_member 없음', memberCount === 0, `count=${memberCount}`),
  ];
}

async function sc04_existingUser_withTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.existingWithTrip;

  // 기존 Firebase 유저 생성 + DB seed
  const { idToken: _t, localId: uid } = await Firebase.getIdToken(phone);
  // DB cleanup (혹시 남아있는 데이터)
  const ex = await Db.getUserByPhone(phone);
  if (ex && ex.user_id !== uid) await Db.cleanupByUid(ex.user_id);

  await Db.seedExistingUserWithTrip(phone, uid);

  // 잠깐 대기 — last_verification_at 변화 확인용
  const before = await Db.getUserById(uid);
  await new Promise(r => setTimeout(r, 100));

  // 같은 전화번호로 다시 인증 요청
  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const after = await Db.getUserById(localId);
  const memberCount = await Db.getGroupMemberCount(localId);

  // cleanup
  await Firebase.deleteUser(localId);
  await Db.cleanupByUid(localId);

  return [
    check('HTTP 200',                     res.status === 200, `status=${res.status}`),
    check('is_new_user=false',            res.data?.data?.is_new_user === false),
    check('user_role=traveler (captain→traveler via _determineUserRole)',
      res.data?.data?.user_role === 'traveler',
      `actual=${res.data?.data?.user_role}`),
    check('group_member 있음',             memberCount > 0, `count=${memberCount}`),
    check('last_verification_at 업데이트', after?.last_verification_at !== before?.last_verification_at),
  ];
}

async function sc05_existingUser_noTrip(): Promise<Check[]> {
  const phone = TEST_PHONES.existingNoTrip;

  const { idToken: _t, localId: uid } = await Firebase.getIdToken(phone);
  const ex = await Db.getUserByPhone(phone);
  if (ex && ex.user_id !== uid) await Db.cleanupByUid(ex.user_id);

  await Db.seedExistingUserNoTrip(phone, uid);
  const before = await Db.getUserById(uid);
  await new Promise(r => setTimeout(r, 100));

  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const after = await Db.getUserById(localId);
  const memberCount = await Db.getGroupMemberCount(localId);

  await Firebase.deleteUser(localId);
  await Db.cleanupByUid(localId);

  return [
    check('HTTP 200',                     res.status === 200,   `status=${res.status}`),
    check('is_new_user=false',            res.data?.data?.is_new_user === false),
    check('user_role=traveler',           res.data?.data?.user_role === 'traveler',
      `actual=${res.data?.data?.user_role}`),
    check('group_member 없음',            memberCount === 0,    `count=${memberCount}`),
    check('last_verification_at 업데이트', after?.last_verification_at !== before?.last_verification_at),
  ];
}

async function sc06_existingUser_inviteCode(): Promise<Check[]> {
  // 기존 유저 + 여행 없음 + inviteCode entry
  // 서버 응답은 SC-05와 동일 — entry는 서버가 처리하지 않고 클라이언트가 라우팅 분기
  const phone = TEST_PHONES.existingNoTrip;

  const { idToken: _t, localId: uid } = await Firebase.getIdToken(phone);
  const ex = await Db.getUserByPhone(phone);
  if (ex && ex.user_id !== uid) await Db.cleanupByUid(ex.user_id);

  await Db.seedExistingUserNoTrip(phone, uid);
  const before = await Db.getUserById(uid);
  await new Promise(r => setTimeout(r, 100));

  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const after = await Db.getUserById(localId);

  await Firebase.deleteUser(localId);
  await Db.cleanupByUid(localId);

  return [
    check('HTTP 200',                     res.status === 200,   `status=${res.status}`),
    check('is_new_user=false',            res.data?.data?.is_new_user === false),
    check('user_id 반환',                  !!res.data?.data?.user_id),
    check('last_verification_at 업데이트', after?.last_verification_at !== before?.last_verification_at),
    // 서버는 entry 파라미터를 받지 않음 — 클라이언트가 inviteCode 경로로 분기 처리
  ];
}

async function sc07_existingUser_continueTrip(): Promise<Check[]> {
  // 기존 유저 + 여행 있음 + continueTrip entry
  // 서버는 기존 레코드를 보존하며 is_new_user=false 반환
  const phone = TEST_PHONES.existingWithTrip;

  const { idToken: _t, localId: uid } = await Firebase.getIdToken(phone);
  const ex = await Db.getUserByPhone(phone);
  if (ex && ex.user_id !== uid) await Db.cleanupByUid(ex.user_id);

  await Db.seedExistingUserWithTrip(phone, uid);

  const { idToken, localId } = await Firebase.getIdToken(phone);
  const res = await Api.firebaseVerify(idToken);
  const memberCount = await Db.getGroupMemberCount(localId);

  await Firebase.deleteUser(localId);
  await Db.cleanupByUid(localId);

  return [
    check('HTTP 200',           res.status === 200,   `status=${res.status}`),
    check('is_new_user=false',  res.data?.data?.is_new_user === false),
    check('user_role=traveler (captain→traveler via _determineUserRole)',
      res.data?.data?.user_role === 'traveler',
      `actual=${res.data?.data?.user_role}`),
    check('group_member 보존됨', memberCount > 0,    `count=${memberCount}`),
  ];
}

async function sc08_testDevice_anonymous(): Promise<Check[]> {
  // Flutter 앱에서 테스트 번호(01099990001)는 Firebase Phone Auth를 건너뛰고
  // Anonymous Auth를 사용한다. 백엔드는 is_test_device=true + test_phone_number로 처리한다.

  // 이전 실행 잔재 cleanup (test_phone_number로 생성된 DB 유저)
  const prevUser = await Db.getUserByPhone(TEST_PHONES.anonTest);
  if (prevUser) await Db.cleanupByUid(prevUser.user_id);

  const anonUrl = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;
  const anonRes = await httpPost(anonUrl, {}); // 빈 body → anonymous signUp
  const idToken = anonRes.data?.idToken  as string | undefined;
  const localId = anonRes.data?.localId  as string | undefined;

  if (!idToken) {
    return [check('Anonymous ID Token 발급', false,
      `에뮬레이터 응답: ${JSON.stringify(anonRes.data)}`)];
  }

  // 클라이언트가 실제로 보내는 것: id_token + is_test_device + test_phone_number
  const res = await Api.firebaseVerify(idToken, {
    isTestDevice:    true,
    testPhoneNumber: TEST_PHONES.anonTest,
  });

  // cleanup
  if (localId) await Firebase.deleteUser(localId);
  const newUser = await Db.getUserByPhone(TEST_PHONES.anonTest);
  if (newUser) await Db.cleanupByUid(newUser.user_id);

  return [
    check('HTTP 200',          res.status === 200,                      `status=${res.status}`),
    check('success=true',      res.data?.success === true),
    check('is_new_user=true',  res.data?.data?.is_new_user === true,
      `actual=${res.data?.data?.is_new_user}`),
    check('user_id 반환',       !!res.data?.data?.user_id),
  ];
}

async function main() {
  console.log('\n🧪 SafeTrip 온보딩 통합 테스트 시작\n');
  console.log(`  서버:     ${CONFIG.serverUrl}`);
  console.log(`  Firebase: ${CONFIG.firebaseAuthUrl}`);
  console.log(`  DB:       ${CONFIG.db.host}:${CONFIG.db.port}/${CONFIG.db.database}\n`);

  // 서버 헬스 체크
  const health = await httpGet(`${CONFIG.serverUrl}/health`).catch(() => ({ status: 0, data: null }));
  if (health.status !== 200) {
    console.error('❌ 서버가 응답하지 않습니다. npm run dev를 먼저 실행하세요.');
    process.exit(1);
  }
  console.log('  ✅ 서버 연결 확인\n');

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
