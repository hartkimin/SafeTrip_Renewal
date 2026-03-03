// scripts/test/phase2-member-roles.ts
//
// SafeTrip UAT Phase 2: 멤버 역할 검증
//
// 검증 항목 8개:
//   1. Crew #1 Firebase 인증 (TEST_PHONES.crew1 = +821099901002)
//   2. Crew #1 초대코드로 그룹 가입 (POST /api/v1/groups/join-by-code/:code) → 200/201
//   3. DB: Crew #1 tb_group_member.member_role = 'crew'
//   4. DB: Crew #1 tb_group_member.trip_id NOT NULL
//
//   5. Crew Chief 인증 (+821099901003), Crew로 가입 후 Captain이 Crew Chief 승격
//      - Captain이 PATCH /api/v1/groups/:groupId/members/:ccUserId {member_role:'crew_chief'} → 200
//   6. DB: Crew Chief is_admin = true
//
//   7. 권한 분리: Crew #1이 초대코드 생성 시도 → 403
//   8. Captain이 유저 검색 → 200 (GET /api/v1/users/search?q=테스트)
//
// 실행: cd /mnt/d/Project/15_SafeTrip_New && NODE_PATH=safetrip-server-api/node_modules npx tsx scripts/test/phase2-member-roles.ts
//
// 사전 조건:
//   - Phase 1 state: /tmp/safetrip-test-state.json 존재 (captainIdToken, captainUserId, groupId, tripId, travelerCode)
//   - 서버(:3001), Firebase 에뮬레이터(:9099), PostgreSQL 모두 실행 중

import * as fs from 'fs';
import * as path from 'path';

// NODE_PATH 설정: safetrip-server-api/node_modules에서 pg 모듈 해소
process.env.NODE_PATH = path.resolve(
  __dirname,
  '../../safetrip-server-api/node_modules',
);
// @ts-ignore
require('module').Module._initPaths();

import {
  CONFIG,
  TEST_PHONES,
  CheckResult,
  PhaseResult,
  Firebase,
  createPool,
  dbQuery,
  apiPost,
  apiGet,
  apiPatch,
} from './utils/test-client';

// ─── 상태 파일 경로 ───────────────────────────────────────────────────────────

const STATE_PATH = '/tmp/safetrip-test-state.json';

// ─── Phase 1 state 로드 ───────────────────────────────────────────────────────

interface Phase1State {
  captainIdToken: string;
  captainUserId: string;
  groupId: string;
  tripId: string;
  travelerCode: string;
  guardianCode: string;
}

function loadPhase1State(): Phase1State {
  if (!fs.existsSync(STATE_PATH)) {
    throw new Error(`Phase 1 state 파일 없음: ${STATE_PATH}\nPhase 1 먼저 실행하세요.`);
  }
  const raw = fs.readFileSync(STATE_PATH, 'utf-8');
  const state = JSON.parse(raw) as Phase1State;
  if (!state.captainIdToken || !state.groupId || !state.travelerCode) {
    throw new Error(
      `Phase 1 state 필드 누락: captainIdToken=${!!state.captainIdToken}, groupId=${!!state.groupId}, travelerCode=${!!state.travelerCode}`,
    );
  }
  return state;
}

// ─── Phase 2 메인 ─────────────────────────────────────────────────────────────

async function runPhase2(): Promise<PhaseResult> {
  const phaseName = 'Phase 2: 멤버 역할 검증';
  const checks: CheckResult[] = [];

  // Phase 1 state 로드
  const p1 = loadPhase1State();
  const { captainIdToken, captainUserId, groupId, travelerCode } = p1;

  console.log(`\n[Phase 1 State 로드]`);
  console.log(`  captainUserId  : ${captainUserId}`);
  console.log(`  groupId        : ${groupId}`);
  console.log(`  travelerCode   : ${travelerCode}`);

  // Phase 2에서 수집할 값들
  let crew1IdToken  = '';
  let crew1UserId   = '';
  let ccIdToken     = '';
  let ccUserId      = '';

  const pool = createPool();

  try {
    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 1: Crew #1 Firebase 인증
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[1/8] Crew #1 Firebase 인증 중...');
    try {
      const { idToken, localId } = await Firebase.getIdToken(TEST_PHONES.crew1);
      crew1IdToken = idToken;
      crew1UserId  = localId;

      const passed = !!(idToken && localId);
      checks.push({
        label:  'Crew #1 Firebase 인증 성공',
        passed,
        detail: passed ? `localId=${localId}` : 'idToken 또는 localId 없음',
      });
      console.log(`  -> ${passed ? 'PASS' : 'FAIL'} localId=${localId}`);
    } catch (e: any) {
      checks.push({ label: 'Crew #1 Firebase 인증 성공', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // 인증 실패 시 후속 crew1 체크 스킵 처리
    if (!crew1IdToken) {
      const skipDetail = 'Crew #1 Firebase 인증 실패로 스킵';
      checks.push({ label: 'Crew #1 그룹 가입 200/201',          passed: false, detail: skipDetail });
      checks.push({ label: 'Crew #1 member_role = crew',         passed: false, detail: skipDetail });
      checks.push({ label: 'Crew #1 trip_id NOT NULL',           passed: false, detail: skipDetail });
      // Crew Chief 체크도 스킵
      checks.push({ label: 'Crew Chief 승격 200',                passed: false, detail: skipDetail });
      checks.push({ label: 'Crew Chief is_admin = true',         passed: false, detail: skipDetail });
      // 권한 분리 + 검색은 별도 실행 가능하지만 일관성을 위해 스킵
      checks.push({ label: 'Crew #1 초대코드 생성 → 403',        passed: false, detail: skipDetail });
      checks.push({ label: 'Captain 유저 검색 → 200',            passed: false, detail: skipDetail });
      return { phase: phaseName, passed: false, checks };
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 2: Crew #1 초대코드로 그룹 가입
    //   POST /api/v1/groups/join-by-code/:code
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[2/8] Crew #1 그룹 가입 중...');
    let crew1JoinPassed = false;
    try {
      const res = await apiPost(
        `/api/v1/groups/join-by-code/${travelerCode}`,
        {},
        crew1IdToken,
      );

      const okStatus = res.status === 200 || res.status === 201;
      // 이미 멤버인 경우도 200으로 처리됨 (already_member=true)
      const hasGroupData = !!(res.data?.data?.group || res.data?.data?.member || res.data?.data?.already_member !== undefined);
      crew1JoinPassed = okStatus;

      checks.push({
        label:  'Crew #1 그룹 가입 200/201',
        passed: crew1JoinPassed,
        detail: `status=${res.status}, already_member=${res.data?.data?.already_member ?? false}, member_role=${res.data?.data?.member?.member_role ?? 'N/A'}`,
      });
      console.log(`  -> ${crew1JoinPassed ? 'PASS' : 'FAIL'} status=${res.status}`);

      if (!crew1JoinPassed) {
        console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
      }
    } catch (e: any) {
      checks.push({ label: 'Crew #1 그룹 가입 200/201', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 3: DB Crew #1 member_role = 'crew'
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[3/8] DB Crew #1 member_role 확인 중...');
    try {
      // firebase-verify를 통해 DB user_id 확보 (crew1UserId는 Firebase localId)
      // auth.middleware의 auto-upsert로 tb_user에 INSERT됨
      const verifyRes = await apiPost(
        '/api/v1/auth/firebase-verify',
        { id_token: crew1IdToken },
      );
      if (verifyRes.data?.data?.user_id) {
        crew1UserId = verifyRes.data.data.user_id;
        console.log(`  -> firebase-verify crew1UserId=${crew1UserId}`);
      }

      const rows = await dbQuery(
        pool,
        `SELECT member_id, user_id, member_role, is_admin, trip_id
         FROM tb_group_member
         WHERE group_id = $1
           AND user_id  = $2`,
        [groupId, crew1UserId],
      );

      const hasCrewRole = rows.length > 0 && rows[0].member_role === 'crew';
      checks.push({
        label:  'Crew #1 member_role = crew',
        passed: hasCrewRole,
        detail: rows.length > 0
          ? `member_role=${rows[0].member_role}, is_admin=${rows[0].is_admin}`
          : `group_id=${groupId}, user_id=${crew1UserId} 레코드 없음`,
      });
      console.log(`  -> ${hasCrewRole ? 'PASS' : 'FAIL'} member_role=${rows[0]?.member_role ?? 'N/A'}`);
    } catch (e: any) {
      checks.push({ label: 'Crew #1 member_role = crew', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 4: DB Crew #1 trip_id NOT NULL
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[4/8] DB Crew #1 trip_id NOT NULL 확인 중...');
    try {
      if (!crew1UserId) {
        checks.push({ label: 'Crew #1 trip_id NOT NULL', passed: false, detail: 'crew1UserId 없음' });
        console.log('  -> SKIP (crew1UserId 없음)');
      } else {
        const rows = await dbQuery(
          pool,
          `SELECT trip_id
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, crew1UserId],
        );

        const hasTripId = rows.length > 0 && rows[0].trip_id !== null && rows[0].trip_id !== undefined;
        checks.push({
          label:  'Crew #1 trip_id NOT NULL',
          passed: hasTripId,
          detail: rows.length > 0
            ? `trip_id=${rows[0].trip_id}`
            : '레코드 없음',
        });
        console.log(`  -> ${hasTripId ? 'PASS' : 'FAIL'} trip_id=${rows[0]?.trip_id ?? 'NULL'}`);
      }
    } catch (e: any) {
      checks.push({ label: 'Crew #1 trip_id NOT NULL', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 5: Crew Chief 인증 → Crew로 가입 → Captain이 Crew Chief 승격
    //   1) Firebase 인증 (crewChief = +821099901003)
    //   2) travelerCode로 그룹 가입 (crew 역할)
    //   3) Captain이 PATCH /api/v1/groups/:groupId/members/:ccUserId {member_role:'crew_chief'} → 200
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[5/8] Crew Chief 인증 + 가입 + 승격 중...');
    let ccPromotePassed = false;
    try {
      // (a) Firebase 인증
      const { idToken: ccToken, localId: ccLocalId } = await Firebase.getIdToken(TEST_PHONES.crewChief);
      ccIdToken = ccToken;
      ccUserId  = ccLocalId;
      console.log(`  -> Crew Chief Firebase 인증 성공 localId=${ccLocalId}`);

      // (b) firebase-verify로 DB user_id 확보
      const verifyRes = await apiPost(
        '/api/v1/auth/firebase-verify',
        { id_token: ccIdToken },
      );
      if (verifyRes.data?.data?.user_id) {
        ccUserId = verifyRes.data.data.user_id;
        console.log(`  -> firebase-verify ccUserId=${ccUserId}`);
      }

      // (c) travelerCode로 그룹 가입 (crew 역할)
      const joinRes = await apiPost(
        `/api/v1/groups/join-by-code/${travelerCode}`,
        {},
        ccIdToken,
      );
      console.log(`  -> 그룹 가입 status=${joinRes.status}, member_role=${joinRes.data?.data?.member?.member_role ?? 'N/A'}`);

      // (d) Captain이 Crew Chief로 승격
      const promoteRes = await apiPatch(
        `/api/v1/groups/${groupId}/members/${ccUserId}`,
        { member_role: 'crew_chief' },
        captainIdToken,
      );

      ccPromotePassed = promoteRes.status === 200;
      checks.push({
        label:  'Crew Chief 승격 200',
        passed: ccPromotePassed,
        detail: `status=${promoteRes.status}, member_role=${promoteRes.data?.data?.member_role ?? 'N/A'}, is_admin=${promoteRes.data?.data?.is_admin ?? 'N/A'}`,
      });
      console.log(`  -> ${ccPromotePassed ? 'PASS' : 'FAIL'} status=${promoteRes.status}`);

      if (!ccPromotePassed) {
        console.error('  응답 전체:', JSON.stringify(promoteRes.data, null, 2));
      }
    } catch (e: any) {
      checks.push({ label: 'Crew Chief 승격 200', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 6: DB Crew Chief is_admin = true
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[6/8] DB Crew Chief is_admin 확인 중...');
    try {
      if (!ccUserId) {
        checks.push({ label: 'Crew Chief is_admin = true', passed: false, detail: 'ccUserId 없음' });
        console.log('  -> SKIP (ccUserId 없음)');
      } else {
        const rows = await dbQuery(
          pool,
          `SELECT member_role, is_admin
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, ccUserId],
        );

        const hasAdminTrue = rows.length > 0 && rows[0].is_admin === true;
        const hasCrewChiefRole = rows.length > 0 && rows[0].member_role === 'crew_chief';
        const passed = hasAdminTrue && hasCrewChiefRole;

        checks.push({
          label:  'Crew Chief is_admin = true',
          passed,
          detail: rows.length > 0
            ? `member_role=${rows[0].member_role}, is_admin=${rows[0].is_admin}`
            : `group_id=${groupId}, user_id=${ccUserId} 레코드 없음`,
        });
        console.log(`  -> ${passed ? 'PASS' : 'FAIL'} member_role=${rows[0]?.member_role ?? 'N/A'}, is_admin=${rows[0]?.is_admin ?? 'N/A'}`);
      }
    } catch (e: any) {
      checks.push({ label: 'Crew Chief is_admin = true', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 7: 권한 분리 — Crew #1이 초대코드 생성 시도 → 403
    //   POST /api/v1/groups/:groupId/invite-codes (crew 권한 → 403 기대)
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[7/8] 권한 분리: Crew #1이 초대코드 생성 시도 중...');
    try {
      if (!crew1IdToken || !groupId) {
        checks.push({
          label:  'Crew #1 초대코드 생성 → 403',
          passed: false,
          detail: 'crew1IdToken 또는 groupId 없음',
        });
        console.log('  -> SKIP');
      } else {
        const res = await apiPost(
          `/api/v1/groups/${groupId}/invite-codes`,
          {
            target_role:     'crew',
            max_uses:        10,
            expires_in_days: 7,
          },
          crew1IdToken,
        );

        const passed = res.status === 403;
        checks.push({
          label:  'Crew #1 초대코드 생성 → 403',
          passed,
          detail: `status=${res.status} (기대: 403), message=${res.data?.message ?? 'N/A'}`,
        });
        console.log(`  -> ${passed ? 'PASS' : 'FAIL'} status=${res.status} (기대: 403)`);

        if (!passed) {
          console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
        }
      }
    } catch (e: any) {
      checks.push({ label: 'Crew #1 초대코드 생성 → 403', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 8: Captain이 유저 검색 → 200
    //   GET /api/v1/users/search?q=테스트
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[8/8] Captain 유저 검색 중...');
    try {
      const res = await apiGet(
        `/api/v1/users/search?q=${encodeURIComponent('테스트')}`,
        captainIdToken,
      );

      const passed = res.status === 200;
      const resultCount = Array.isArray(res.data?.data)
        ? res.data.data.length
        : (Array.isArray(res.data?.data?.users) ? res.data.data.users.length : 'N/A');

      checks.push({
        label:  'Captain 유저 검색 → 200',
        passed,
        detail: `status=${res.status}, 결과 수=${resultCount}`,
      });
      console.log(`  -> ${passed ? 'PASS' : 'FAIL'} status=${res.status}, 결과 수=${resultCount}`);

      if (!passed) {
        console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
      }
    } catch (e: any) {
      checks.push({ label: 'Captain 유저 검색 → 200', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ─── State 파일 업데이트 ──────────────────────────────────────────────────
    const updatedState = {
      ...p1,
      crew1IdToken,
      crew1UserId,
      ccIdToken,
      ccUserId,
    };

    try {
      fs.writeFileSync(STATE_PATH, JSON.stringify(updatedState, null, 2), 'utf-8');
      console.log(`\n[State] ${STATE_PATH} 업데이트 완료`);
      console.log(JSON.stringify(updatedState, null, 2));
    } catch (e: any) {
      console.error(`[State] 저장 실패: ${e.message}`);
    }

    const allPassed = checks.every((c) => c.passed);
    return { phase: phaseName, passed: allPassed, checks };

  } catch (error: any) {
    return { phase: phaseName, passed: false, checks, error: error.message };
  } finally {
    await pool.end();
  }
}

// ─── 결과 출력 ────────────────────────────────────────────────────────────────

function printPhaseResult(result: PhaseResult): void {
  const SEP = '='.repeat(60);
  console.log('\n' + SEP);
  console.log(`  SafeTrip UAT --- ${result.phase}`);
  console.log(SEP);

  if (result.error) {
    console.log(`  [ERROR] ${result.error}`);
  }

  let passCount = 0;
  let failCount = 0;

  for (const c of result.checks) {
    if (c.passed) {
      console.log(`  [PASS] ${c.label}`);
      if (c.detail) console.log(`         ${c.detail}`);
      passCount++;
    } else {
      console.log(`  [FAIL] ${c.label}`);
      if (c.detail) console.log(`         ${c.detail}`);
      failCount++;
    }
  }

  console.log(SEP);
  const total = passCount + failCount;
  console.log(
    `  합계: ${passCount}/${total} 통과 (${failCount > 0 ? failCount + '개 실패' : '전체 통과'})`,
  );
  console.log(SEP + '\n');
}

// ─── 진입점 ────────────────────────────────────────────────────────────────────

(async () => {
  console.log('SafeTrip UAT Phase 2: 멤버 역할 검증 시작');
  console.log(`서버: ${CONFIG.serverUrl}`);
  console.log(`Firebase Auth 에뮬레이터: ${CONFIG.firebaseAuthUrl}`);
  console.log(`Crew #1 전화번호: ${TEST_PHONES.crew1}`);
  console.log(`Crew Chief 전화번호: ${TEST_PHONES.crewChief}`);

  let result: PhaseResult;
  try {
    result = await runPhase2();
  } catch (e: any) {
    console.error(`\n[FATAL] ${e.message}`);
    process.exit(1);
  }

  printPhaseResult(result);

  if (!result.passed) {
    console.error('일부 체크 실패 --- 서버 로그 확인:');
    console.error('  tail -20 /tmp/safetrip-backend.log');
    process.exit(1);
  }
})();
