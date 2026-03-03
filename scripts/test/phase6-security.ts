// scripts/test/phase6-security.ts
//
// SafeTrip 보안 테스트 (Layer 3 — Security)
//
// 검증 항목 (5 Phase / 18 Check):
//
//   SEC Phase 1: 보안 헤더 & Rate Limit 정책
//     - X-Content-Type-Options: nosniff (Helmet)
//     - X-Frame-Options 헤더 존재 (Helmet)
//     - X-DNS-Prefetch-Control 헤더 존재 (Helmet)
//     - generalLimiter: RateLimit-Policy 헤더 존재 (500/15min)
//     - authLimiter: RateLimit-Policy 헤더 존재 (20/15min)
//     - locationLimiter: RateLimit-Policy 헤더 존재 (120/1min)
//
//   SEC Phase 2: 인증 우회 시도 → 모두 401
//     - 토큰 없음 → 401
//     - 잘못된 문자열 토큰 → 401
//     - 빈 Bearer 값 → 401
//     - 위조 JWT 형식 → 401
//
//   SEC Phase 3: 페이로드 & 입력값 검증
//     - 1MB 초과 페이로드 → 413
//     - SQL Injection (검색 파라미터) → 서버 정상 응답 (500 아님)
//     - SQL Injection (트립 코드) → 서버 정상 응답 (500 아님)
//
//   SEC Phase 4: 크로스 리소스 접근 제어
//     - 없는 trip UUID → 403/404
//     - 없는 group UUID → 403/404
//     - 없는 trip guardian-messages → 403/404
//
//   SEC Phase 5: 에러 응답 정보 누출 검사
//     - 없는 엔드포인트 응답에 stack trace 없음
//     - 잘못된 UUID 응답에 DB 에러 없음
//     - 인증 실패 응답에 Firebase 내부 정보 없음
//
// 실행:
//   cd /mnt/d/Project/15_SafeTrip_New && \
//   NODE_PATH=safetrip-server-api/node_modules npx tsx scripts/test/phase6-security.ts
//
// 사전 조건:
//   - 서버(:3001), Firebase 에뮬레이터(:9099), PostgreSQL 모두 실행 중
//   - /tmp/safetrip-test-state.json 존재 (Phase 1~2 완료 후 생성됨)
//
// 주의:
//   SEC Phase 1의 Rate Limit 헤더 검증은 실제 소진 없이 정책만 확인합니다.
//   Rate Limit 소진 테스트는 15분 창에 영향을 주므로 별도 환경에서만 수행하세요.

import * as fs from 'fs';
import * as http from 'http';
import * as path from 'path';

// NODE_PATH 설정
process.env.NODE_PATH = path.resolve(
  __dirname,
  '../../safetrip-server-api/node_modules',
);
// @ts-ignore
require('module').Module._initPaths();

import {
  CONFIG,
  CheckResult,
  PhaseResult,
  apiGet,
  apiPost,
  printResults,
} from './utils/test-client';

// ─── 헤더 포함 HTTP 헬퍼 ─────────────────────────────────────────────────────

interface FullResponse {
  status:  number;
  data:    any;
  headers: Record<string, string>;
}

function extractHeaders(res: http.IncomingMessage): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(res.headers)) {
    if (typeof v === 'string')      out[k] = v;
    else if (Array.isArray(v))      out[k] = v[0] ?? '';
  }
  return out;
}

function parseBody(raw: string, status: number): any {
  try { return JSON.parse(raw); } catch { return raw; }
}

function httpGetFull(
  url: string,
  headers?: Record<string, string>,
): Promise<FullResponse> {
  return new Promise((resolve, reject) => {
    const parsed  = new URL(url);
    const options = {
      hostname: parsed.hostname,
      port:     parseInt(parsed.port) || 80,
      path:     parsed.pathname + parsed.search,
      method:   'GET',
      headers:  headers ?? {},
    };
    const req = http.request(options, (res) => {
      let raw = '';
      res.on('data', (c) => { raw += c; });
      res.on('end',  () => {
        resolve({
          status:  res.statusCode!,
          data:    parseBody(raw, res.statusCode!),
          headers: extractHeaders(res),
        });
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function httpPostFull(
  url: string,
  body: object,
  headers?: Record<string, string>,
): Promise<FullResponse> {
  return new Promise((resolve, reject) => {
    const bodyStr    = JSON.stringify(body);
    const parsed     = new URL(url);
    const reqHeaders = {
      'Content-Type':   'application/json',
      'Content-Length': String(Buffer.byteLength(bodyStr)),
      ...(headers ?? {}),
    };
    const options = {
      hostname: parsed.hostname,
      port:     parseInt(parsed.port) || 80,
      path:     parsed.pathname + parsed.search,
      method:   'POST',
      headers:  reqHeaders,
    };
    const req = http.request(options, (res) => {
      let raw = '';
      res.on('data', (c) => { raw += c; });
      res.on('end',  () => {
        resolve({
          status:  res.statusCode!,
          data:    parseBody(raw, res.statusCode!),
          headers: extractHeaders(res),
        });
      });
    });
    req.on('error', reject);
    req.write(bodyStr);
    req.end();
  });
}

// ─── 상태 로드 ────────────────────────────────────────────────────────────────

const STATE_PATH = '/tmp/safetrip-test-state.json';

interface PhaseState {
  captainIdToken: string;
  captainUserId:  string;
  groupId:        string;
  tripId:         string;
}

function loadState(): PhaseState | null {
  try {
    return JSON.parse(fs.readFileSync(STATE_PATH, 'utf8')) as PhaseState;
  } catch {
    return null;
  }
}

// ─── 보안 테스트 ──────────────────────────────────────────────────────────────

async function secPhase1_Headers(): Promise<PhaseResult> {
  const checks: CheckResult[] = [];
  let error: string | undefined;

  try {
    // /health — Helmet 헤더 확인 (rate limit skip 대상이므로 순수 Helmet만)
    const healthRes = await httpGetFull(`${CONFIG.serverUrl}/health`);
    const h = healthRes.headers;

    checks.push({
      label:  'X-Content-Type-Options: nosniff',
      passed: h['x-content-type-options'] === 'nosniff',
      detail: h['x-content-type-options'] ?? '없음',
    });

    checks.push({
      label:  'X-Frame-Options 헤더 존재',
      passed: !!h['x-frame-options'],
      detail: h['x-frame-options'] ?? '없음',
    });

    checks.push({
      label:  'X-DNS-Prefetch-Control 헤더 존재',
      passed: !!h['x-dns-prefetch-control'],
      detail: h['x-dns-prefetch-control'] ?? '없음',
    });

    // generalLimiter: /api/v1/users (인증 없이 → 401이지만 헤더는 붙음)
    const generalRes = await httpGetFull(`${CONFIG.serverUrl}/api/v1/users/me`);

    checks.push({
      label:  'generalLimiter: RateLimit-Policy 헤더 존재',
      passed: !!generalRes.headers['ratelimit-policy'],
      detail: generalRes.headers['ratelimit-policy'] ?? '없음',
    });

    checks.push({
      label:  'generalLimiter: 500/900s 정책',
      passed: (generalRes.headers['ratelimit-policy'] ?? '').includes('500'),
      detail: generalRes.headers['ratelimit-policy'] ?? '없음',
    });

    // authLimiter: /api/v1/auth/firebase-verify (빈 body → 400이지만 헤더 붙음)
    const authRes = await httpPostFull(
      `${CONFIG.serverUrl}/api/v1/auth/firebase-verify`,
      { idToken: 'dummy-test-token-for-header-check' },
    );

    checks.push({
      label:  'authLimiter: RateLimit-Policy 헤더 존재',
      passed: !!authRes.headers['ratelimit-policy'],
      detail: authRes.headers['ratelimit-policy'] ?? '없음',
    });

    checks.push({
      label:  'authLimiter: 20/900s 정책',
      passed: (authRes.headers['ratelimit-policy'] ?? '').includes('20'),
      detail: authRes.headers['ratelimit-policy'] ?? '없음',
    });

    // locationLimiter: /api/v1/locations (인증 없이 → 401이지만 헤더 붙음)
    const locRes = await httpPostFull(
      `${CONFIG.serverUrl}/api/v1/locations/update`,
      { latitude: 37.5, longitude: 127.0 },
    );

    checks.push({
      label:  'locationLimiter: RateLimit-Policy 헤더 존재',
      passed: !!locRes.headers['ratelimit-policy'],
      detail: locRes.headers['ratelimit-policy'] ?? '없음',
    });

    checks.push({
      label:  'locationLimiter: 120/60s 정책',
      passed: (locRes.headers['ratelimit-policy'] ?? '').includes('120'),
      detail: locRes.headers['ratelimit-policy'] ?? '없음',
    });

  } catch (e: any) {
    error = e.message;
  }

  return {
    phase:  'SEC Phase 1: 보안 헤더 & Rate Limit 정책',
    passed: !error && checks.every((c) => c.passed),
    checks,
    error,
  };
}

async function secPhase2_AuthBypass(): Promise<PhaseResult> {
  const checks: CheckResult[] = [];
  let error: string | undefined;

  try {
    // 1. 토큰 없음 → 401
    const noTokenRes = await apiGet('/api/v1/users/me');
    checks.push({
      label:  '토큰 없음 → 401',
      passed: noTokenRes.status === 401,
      detail: `HTTP ${noTokenRes.status}`,
    });

    // 2. 완전히 잘못된 문자열 → 401
    const badTokenRes = await apiGet('/api/v1/users/me', 'totally-invalid-token');
    checks.push({
      label:  '잘못된 문자열 토큰 → 401',
      passed: badTokenRes.status === 401,
      detail: `HTTP ${badTokenRes.status}`,
    });

    // 3. 빈 Bearer 값 → 401
    const emptyBearerRes = await httpGetFull(
      `${CONFIG.serverUrl}/api/v1/users/me`,
      { Authorization: 'Bearer ' },
    );
    checks.push({
      label:  '빈 Bearer → 401',
      passed: emptyBearerRes.status === 401,
      detail: `HTTP ${emptyBearerRes.status}`,
    });

    // 4. 유효한 JWT 형식이지만 서명 위조 → 401
    //    (header.payload.invalid-signature)
    const fakeJwt =
      'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9' +
      '.eyJzdWIiOiJmYWtlLXVzZXIiLCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6OTk5OTk5OTk5OX0' +
      '.invalid-signature-tampered';
    const fakeJwtRes = await apiGet('/api/v1/users/me', fakeJwt);
    checks.push({
      label:  'JWT 형식 위조 서명 → 401',
      passed: fakeJwtRes.status === 401,
      detail: `HTTP ${fakeJwtRes.status}`,
    });

  } catch (e: any) {
    error = e.message;
  }

  return {
    phase:  'SEC Phase 2: 인증 우회 시도',
    passed: !error && checks.every((c) => c.passed),
    checks,
    error,
  };
}

async function secPhase3_InputValidation(): Promise<PhaseResult> {
  const checks: CheckResult[] = [];
  let error: string | undefined;

  try {
    // 1. 1.1MB 페이로드 → 413 (express.json({ limit: '1mb' }) 설정)
    const bigBody = { data: 'A'.repeat(1_150_000) };   // ~1.1MB JSON
    const bigRes  = await httpPostFull(
      `${CONFIG.serverUrl}/api/v1/trips`,
      bigBody,
    );
    checks.push({
      label:  '1MB 초과 페이로드 → 413',
      passed: bigRes.status === 413,
      detail: `HTTP ${bigRes.status}`,
    });

    // 2. SQL Injection — 사용자 검색 파라미터 ('; DROP TABLE tb_user; --)
    const sqlSearchRes = await httpGetFull(
      `${CONFIG.serverUrl}/api/v1/users/search?q=${encodeURIComponent("'; DROP TABLE tb_user; --")}`,
    );
    checks.push({
      label:  'SQL Injection (검색 q=) → 서버 크래시 없음',
      passed: sqlSearchRes.status !== 500,
      detail: `HTTP ${sqlSearchRes.status}`,
    });

    // 3. SQL Injection — trip 초대 코드 경로
    const sqlCodeRes = await httpGetFull(
      `${CONFIG.serverUrl}/api/v1/trips/preview/${encodeURIComponent("' OR '1'='1")}`,
    );
    checks.push({
      label:  'SQL Injection (trip 코드 경로) → 서버 크래시 없음',
      passed: sqlCodeRes.status !== 500,
      detail: `HTTP ${sqlCodeRes.status}`,
    });

    // 4. XSS 페이로드 포함 JSON — 서버가 400/401/403 등 정상 에러 반환
    const xssRes = await httpPostFull(
      `${CONFIG.serverUrl}/api/v1/users/profile`,
      { displayName: '<script>alert("xss")</script>', bio: 'test' },
    );
    checks.push({
      label:  'XSS 페이로드 → 서버 크래시 없음 (500 아님)',
      passed: xssRes.status !== 500,
      detail: `HTTP ${xssRes.status}`,
    });

  } catch (e: any) {
    error = e.message;
  }

  return {
    phase:  'SEC Phase 3: 페이로드 & 입력값 검증',
    passed: !error && checks.every((c) => c.passed),
    checks,
    error,
  };
}

async function secPhase4_AccessControl(): Promise<PhaseResult> {
  const checks: CheckResult[] = [];
  let error: string | undefined;

  const state = loadState();

  try {
    if (!state) {
      throw new Error('상태 파일 없음 — Phase 1~2를 먼저 실행하세요');
    }

    const fakeUuid = '00000000-0000-0000-0000-000000000000';

    // 1. 존재하지 않는 trip → 403/404
    const fakeTripRes = await apiGet(`/api/v1/trips/${fakeUuid}`, state.captainIdToken);
    checks.push({
      label:  '없는 trip UUID → 403/404',
      passed: [403, 404].includes(fakeTripRes.status),
      detail: `HTTP ${fakeTripRes.status}`,
    });

    // 2. 존재하지 않는 group → 403/404
    const fakeGroupRes = await apiGet(`/api/v1/groups/${fakeUuid}`, state.captainIdToken);
    checks.push({
      label:  '없는 group UUID → 403/404',
      passed: [403, 404].includes(fakeGroupRes.status),
      detail: `HTTP ${fakeGroupRes.status}`,
    });

    // 3. 존재하지 않는 trip의 guardian-messages → 403/404
    const fakeGuardianRes = await apiGet(
      `/api/v1/trips/${fakeUuid}/guardian-messages`,
      state.captainIdToken,
    );
    checks.push({
      label:  '없는 trip guardian-messages → 403/404',
      passed: [403, 404].includes(fakeGuardianRes.status),
      detail: `HTTP ${fakeGuardianRes.status}`,
    });

    // 4. 존재하지 않는 trip의 geofences → 403/404
    const fakeGeofenceRes = await apiGet(
      `/api/v1/geofences?tripId=${fakeUuid}`,
      state.captainIdToken,
    );
    checks.push({
      label:  '없는 tripId geofences → 정상 응답 (200 빈배열 또는 403/404)',
      // 200(빈 배열 반환) 또는 403/404 모두 허용 — 500이 아니면 됨
      passed: fakeGeofenceRes.status !== 500,
      detail: `HTTP ${fakeGeofenceRes.status}`,
    });

  } catch (e: any) {
    error = e.message;
  }

  return {
    phase:  'SEC Phase 4: 크로스 리소스 접근 제어',
    passed: !error && checks.every((c) => c.passed),
    checks,
    error,
  };
}

async function secPhase5_InfoLeakage(): Promise<PhaseResult> {
  const checks: CheckResult[] = [];
  let error: string | undefined;

  try {
    // 1. 존재하지 않는 엔드포인트 → stack trace 없어야 함
    const notFoundRes = await httpGetFull(
      `${CONFIG.serverUrl}/api/v1/does-not-exist-endpoint`,
    );
    const notFoundStr = JSON.stringify(notFoundRes.data);
    checks.push({
      label:  '없는 엔드포인트 응답에 stack trace 없음',
      passed: !notFoundStr.includes('at Object.')
           && !notFoundStr.includes('node_modules')
           && !notFoundStr.includes('at async'),
      detail: notFoundStr.substring(0, 150),
    });

    // 2. UUID 형식이 아닌 trip ID → DB 에러 없어야 함
    const badUuidRes = await httpGetFull(
      `${CONFIG.serverUrl}/api/v1/trips/not-a-valid-uuid-at-all`,
    );
    const badUuidStr = JSON.stringify(badUuidRes.data);
    checks.push({
      label:  '잘못된 UUID → DB 에러 정보 노출 없음',
      passed: !badUuidStr.toLowerCase().includes('postgresql')
           && !badUuidStr.toLowerCase().includes('syntax error at')
           && !badUuidStr.includes('pg_')
           && !badUuidStr.includes('column "'),
      detail: badUuidStr.substring(0, 150),
    });

    // 3. 인증 실패 응답 → Firebase/서비스계정 정보 없어야 함
    const authFailRes = await apiGet('/api/v1/users/me', 'bad-token');
    const authFailStr = JSON.stringify(authFailRes.data);
    checks.push({
      label:  '인증 실패 응답에 Firebase 내부 정보 없음',
      passed: !authFailStr.includes('FIREBASE_AUTH')
           && !authFailStr.includes('service_account')
           && !authFailStr.includes('private_key')
           && !authFailStr.includes('client_email'),
      detail: authFailStr.substring(0, 150),
    });

    // 4. 잘못된 Content-Type으로 POST → 에러에 파일 경로 없어야 함
    const badContentTypeRes = await new Promise<FullResponse>((resolve, reject) => {
      const rawBody = 'this is plain text, not json';
      const parsed  = new URL(`${CONFIG.serverUrl}/api/v1/auth/firebase-verify`);
      const req = http.request({
        hostname: parsed.hostname,
        port:     parseInt(parsed.port) || 80,
        path:     parsed.pathname,
        method:   'POST',
        headers: {
          'Content-Type':   'text/plain',
          'Content-Length': String(Buffer.byteLength(rawBody)),
        },
      }, (res) => {
        let raw = '';
        res.on('data', (c) => { raw += c; });
        res.on('end',  () => resolve({
          status:  res.statusCode!,
          data:    parseBody(raw, res.statusCode!),
          headers: extractHeaders(res),
        }));
      });
      req.on('error', reject);
      req.write(rawBody);
      req.end();
    });
    const badCtStr = JSON.stringify(badContentTypeRes.data);
    checks.push({
      label:  '잘못된 Content-Type → 파일 경로 노출 없음',
      passed: !badCtStr.includes('/mnt/')
           && !badCtStr.includes('/home/')
           && !badCtStr.includes('src/'),
      detail: badCtStr.substring(0, 150),
    });

  } catch (e: any) {
    error = e.message;
  }

  return {
    phase:  'SEC Phase 5: 에러 응답 정보 누출 검사',
    passed: !error && checks.every((c) => c.passed),
    checks,
    error,
  };
}

// ─── 메인 ─────────────────────────────────────────────────────────────────────

(async () => {
  console.log('\n=== SafeTrip 보안 테스트 (Layer 3) ===');
  console.log(`    서버: ${CONFIG.serverUrl}`);
  console.log(`    시각: ${new Date().toISOString()}\n`);

  const results = await Promise.all([
    secPhase1_Headers(),
    secPhase2_AuthBypass(),
    secPhase3_InputValidation(),
    secPhase4_AccessControl(),
    secPhase5_InfoLeakage(),
  ]);

  printResults(results);
})().catch((e) => {
  console.error('보안 테스트 치명적 오류:', e);
  process.exit(1);
});
