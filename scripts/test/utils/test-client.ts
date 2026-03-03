// scripts/test/utils/test-client.ts
import * as http from 'http';
import * as https from 'https';

// pg is resolved from safetrip-server-api/node_modules via NODE_PATH
import { Pool, PoolConfig } from 'pg';

// ─── Config ──────────────────────────────────────────────────────────────────

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
  } as PoolConfig,
};

// ─── 테스트 전화번호 ──────────────────────────────────────────────────────────

export const TEST_PHONES = {
  captain:    '+821099901001',
  crew1:      '+821099901002',
  crewChief:  '+821099901003',
  guardian:   '+821099901004',
  crew2:      '+821099901005',
};

// ─── 공통 타입 ────────────────────────────────────────────────────────────────

export interface CheckResult {
  label:   string;
  passed:  boolean;
  detail?: string;
}

export interface PhaseResult {
  phase:   string;
  passed:  boolean;
  checks:  CheckResult[];
  error?:  string;
}

// ─── 타임아웃 헬퍼 ───────────────────────────────────────────────────────────

export function withTimeout<T>(promise: Promise<T>, ms = 15000): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(() => reject(new Error(`Request timeout after ${ms}ms`)), ms)
    ),
  ]);
}

// ─── 저수준 HTTP 헬퍼 (Node.js 내장 모듈만 사용) ────────────────────────────

export function httpRequest(
  method: string,
  url: string,
  body?: object,
  headers?: Record<string, string>,
): Promise<{ status: number; data: any }> {
  return withTimeout(new Promise((resolve, reject) => {
    const bodyStr  = body ? JSON.stringify(body) : '';
    const parsed   = new URL(url);
    const useHttps = parsed.protocol === 'https:';
    const port     = parsed.port
      ? parseInt(parsed.port)
      : useHttps ? 443 : 80;

    const reqHeaders: Record<string, string | number> = {
      ...(headers ?? {}),
    };
    if (body) {
      reqHeaders['Content-Type']   = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(bodyStr);
    }

    const options = {
      hostname: parsed.hostname,
      port,
      path:     parsed.pathname + parsed.search,
      method:   method.toUpperCase(),
      headers:  reqHeaders,
    };

    const transport = useHttps ? https : http;
    const req = transport.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode!, data: JSON.parse(data) });
        } catch {
          console.error(
            `[HTTP] JSON parse 실패 (status=${res.statusCode}): ${data.substring(0, 300)}`
          );
          resolve({ status: res.statusCode!, data });
        }
      });
    });

    req.on('error', reject);

    if (body) {
      req.write(bodyStr);
    }
    req.end();
  }));
}

export const httpPost = (
  url: string,
  body: object,
  headers?: Record<string, string>,
) => httpRequest('POST', url, body, headers);

export const httpGet = (
  url: string,
  headers?: Record<string, string>,
) => httpRequest('GET', url, undefined, headers);

export const httpPatch = (
  url: string,
  body: object,
  headers?: Record<string, string>,
) => httpRequest('PATCH', url, body, headers);

export const httpDelete = (
  url: string,
  body?: object,
  headers?: Record<string, string>,
) => httpRequest('DELETE', url, body, headers);

// ─── Firebase 에뮬레이터 헬퍼 ────────────────────────────────────────────────

export const Firebase = {
  /** 전화번호로 SMS 인증 요청 → sessionInfo 반환 */
  async sendVerificationCode(phoneNumber: string): Promise<string> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=fake-api-key`;
    const res = await httpPost(url, { phoneNumber, iosReceipt: '' });
    if (!res.data.sessionInfo) {
      throw new Error(`sendVerificationCode 실패: ${JSON.stringify(res.data)}`);
    }
    return res.data.sessionInfo as string;
  },

  /** 에뮬레이터에서 최신 인증번호 조회 */
  async getVerificationCode(
    phoneNumber: string,
  ): Promise<{ code: string; sessionInfo: string }> {
    const url = `${CONFIG.firebaseAuthUrl}/emulator/v1/projects/${CONFIG.firebaseProject}/verificationCodes`;
    const res = await httpGet(url);
    if (!res.data.verificationCodes?.length) {
      throw new Error('verificationCodes 비어 있음');
    }
    const codes: any[] = res.data.verificationCodes as any[];
    const match = [...codes].reverse().find((c: any) => c.phoneNumber === phoneNumber);
    if (!match) {
      throw new Error(`${phoneNumber}의 verificationCode 없음`);
    }
    return { code: match.code as string, sessionInfo: match.sessionInfo as string };
  },

  /** sessionInfo + code → idToken 발급 */
  async signInWithPhone(
    sessionInfo: string,
    code: string,
  ): Promise<{ idToken: string; localId: string }> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=fake-api-key`;
    const res = await httpPost(url, { sessionInfo, code });
    if (!res.data.idToken) {
      throw new Error(`signInWithPhoneNumber 실패: ${JSON.stringify(res.data)}`);
    }
    return {
      idToken:  res.data.idToken  as string,
      localId:  res.data.localId  as string,
    };
  },

  /** 전화번호로 ID Token 한 번에 발급 (3단계 통합) */
  async getIdToken(
    phoneNumber: string,
  ): Promise<{ idToken: string; localId: string }> {
    const sessionInfo = await this.sendVerificationCode(phoneNumber);
    // 에뮬레이터가 코드를 기록할 시간을 줍니다
    await new Promise<void>((r) => setTimeout(r, 300));
    const { code } = await this.getVerificationCode(phoneNumber);
    return this.signInWithPhone(sessionInfo, code);
  },

  /** Firebase 계정 삭제 (테스트 cleanup) */
  async deleteAccount(idToken: string): Promise<void> {
    const url = `${CONFIG.firebaseAuthUrl}/identitytoolkit.googleapis.com/v1/accounts:delete?key=fake-api-key`;
    await httpPost(url, { idToken });
  },

};

// ─── DB 헬퍼 ──────────────────────────────────────────────────────────────────

/** 새 Pool 인스턴스를 생성합니다. 테스트가 끝나면 pool.end()를 호출하세요. */
export function createPool(): Pool {
  const pool = new Pool(CONFIG.db);
  pool.on('connect', async (client: any) => {
    await client.query("SET timezone = 'UTC'");
  });
  return pool;
}

/** SQL 쿼리를 실행하고 rows 배열을 반환합니다. */
export async function dbQuery(
  pool: Pool,
  sql: string,
  params?: any[],
): Promise<any[]> {
  const result = await pool.query(sql, params);
  return result.rows;
}

// ─── API 헬퍼 (서버 호출) ────────────────────────────────────────────────────

function authHeaders(idToken?: string): Record<string, string> {
  if (!idToken) return {};
  return { Authorization: `Bearer ${idToken}` };
}

export function apiPost(
  path: string,
  body: object,
  idToken?: string,
): Promise<{ status: number; data: any }> {
  return httpPost(
    `${CONFIG.serverUrl}${path}`,
    body,
    authHeaders(idToken),
  );
}

export function apiGet(
  path: string,
  idToken?: string,
): Promise<{ status: number; data: any }> {
  return httpGet(
    `${CONFIG.serverUrl}${path}`,
    authHeaders(idToken),
  );
}

export function apiPatch(
  path: string,
  body: object,
  idToken?: string,
): Promise<{ status: number; data: any }> {
  return httpPatch(
    `${CONFIG.serverUrl}${path}`,
    body,
    authHeaders(idToken),
  );
}

export function apiDelete(
  path: string,
  idToken?: string,
): Promise<{ status: number; data: any }> {
  return httpDelete(
    `${CONFIG.serverUrl}${path}`,
    undefined,
    authHeaders(idToken),
  );
}

// ─── 결과 출력 ────────────────────────────────────────────────────────────────

export function printResults(results: PhaseResult[]): void {
  const SEP = '='.repeat(60);
  console.log('\n' + SEP);
  console.log('  SafeTrip UAT 테스트 결과');
  console.log(SEP);

  let passCount = 0;
  let failCount = 0;

  for (const r of results) {
    const icon = r.passed ? 'PASS' : 'FAIL';
    console.log(`  [${icon}]  ${r.phase}`);

    if (!r.passed) {
      if (r.error) {
        console.log(`         ERROR: ${r.error}`);
      }
      for (const c of r.checks.filter((c) => !c.passed)) {
        const detail = c.detail ? ': ' + c.detail : '';
        console.log(`         FAIL  ${c.label}${detail}`);
      }
      failCount++;
    } else {
      // 통과한 체크 항목 수 표시
      console.log(`         (${r.checks.length}개 체크 통과)`);
      passCount++;
    }
  }

  console.log(SEP);
  console.log(
    `  합계: ${passCount} PASS, ${failCount} FAIL (전체 ${results.length})`,
  );
  console.log(SEP + '\n');

  if (failCount > 0) {
    process.exit(1);
  }
}

// ─── 이 파일을 직접 실행 시 셀프 체크 ──────────────────────────────────────

if (require.main === module) {
  (async () => {
    console.log('[test-client.ts] 셀프 체크 시작');

    // withTimeout 동작 확인
    const val = await withTimeout(Promise.resolve(42), 1000);
    console.log(`  withTimeout: ${val === 42 ? 'OK' : 'FAIL'}`);

    // CONFIG 확인
    console.log(`  CONFIG.serverUrl:       ${CONFIG.serverUrl}`);
    console.log(`  CONFIG.firebaseAuthUrl: ${CONFIG.firebaseAuthUrl}`);
    console.log(`  CONFIG.firebaseRTDBUrl: ${CONFIG.firebaseRTDBUrl}`);
    console.log(`  CONFIG.firebaseProject: ${CONFIG.firebaseProject}`);
    console.log(`  CONFIG.db.host:         ${CONFIG.db.host}`);
    console.log(`  CONFIG.db.database:     ${CONFIG.db.database}`);

    // TEST_PHONES 확인
    console.log(`  TEST_PHONES.captain:    ${TEST_PHONES.captain}`);

    // printResults 타입 체크 (실제 출력은 건너뜀)
    const dummy: PhaseResult[] = [
      { phase: 'dummy', passed: true, checks: [{ label: 'ok', passed: true }] },
    ];
    console.log(`  PhaseResult 타입 구성:  OK (${dummy.length}개)`);

    // Pool 생성 확인 (연결 시도 없이 인스턴스만)
    const pool = createPool();
    console.log(`  createPool():           OK`);
    await pool.end();

    console.log('[test-client.ts] 셀프 체크 완료 — 모든 export 정상');
  })().catch((e) => {
    console.error('[test-client.ts] 셀프 체크 실패:', e.message);
    process.exit(1);
  });
}
