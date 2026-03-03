// scripts/test/phase5-edge-cases.ts
//
// SafeTrip UAT Phase 5: 엣지 케이스 검증
//
// 검증 항목 5개:
//   EC-001: Crew #2 Firebase 인증 및 초대코드 재가입
//   EC-001: 중복 가입 방지 확인
//   EC-003: 초대코드로 역할 자동 할당 확인 (member_role='crew')
//   EC-004: Captain 리더십 이전 (Captain → Crew Chief)
//   EC-002: getUserTrips — 기존 여행 유지 확인
//
// 실행:
//   cd /mnt/d/Project/15_SafeTrip_New && NODE_PATH=safetrip-server-api/node_modules npx tsx scripts/test/phase5-edge-cases.ts
//
// 사전 조건:
//   - Phase 1, 2 완료 후 /tmp/safetrip-test-state.json 존재
//     (captainIdToken, captainUserId, groupId, tripId, travelerCode, crew1IdToken, crew1UserId, ccIdToken, ccUserId)
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

// ─── Phase state 인터페이스 ───────────────────────────────────────────────────

interface PhaseState {
  captainIdToken: string;
  captainUserId:  string;
  groupId:        string;
  tripId:         string;
  travelerCode:   string;
  guardianCode:   string;
  crew1IdToken:   string;
  crew1UserId:    string;
  ccIdToken:      string;
  ccUserId:       string;
}

function loadPhaseState(): PhaseState {
  if (!fs.existsSync(STATE_PATH)) {
    throw new Error(
      `State 파일 없음: ${STATE_PATH}\nPhase 1, 2 먼저 실행하세요.`,
    );
  }
  const raw   = fs.readFileSync(STATE_PATH, 'utf-8');
  const state = JSON.parse(raw) as PhaseState;

  const required: (keyof PhaseState)[] = [
    'captainIdToken', 'captainUserId',
    'groupId', 'tripId',
    'travelerCode',
    'ccIdToken', 'ccUserId',
  ];
  const missing = required.filter((k) => !state[k]);
  if (missing.length > 0) {
    throw new Error(
      `State 필드 누락: ${missing.join(', ')}\nPhase 1, 2를 재실행하세요.`,
    );
  }
  return state;
}

// ─── Phase 5 메인 ─────────────────────────────────────────────────────────────

async function runPhase5(): Promise<PhaseResult> {
  const phaseName = 'Phase 5: 엣지 케이스';
  const checks: CheckResult[] = [];

  // Phase 1+2 state 로드
  const state = loadPhaseState();
  const {
    captainIdToken,
    captainUserId,
    groupId,
    tripId,
    travelerCode,
    ccIdToken,
    ccUserId,
  } = state;

  console.log('\n[Phase State 로드]');
  console.log(`  captainUserId : ${captainUserId}`);
  console.log(`  groupId       : ${groupId}`);
  console.log(`  tripId        : ${tripId}`);
  console.log(`  travelerCode  : ${travelerCode}`);
  console.log(`  ccUserId      : ${ccUserId}`);

  // Crew #2 런타임 변수
  let crew2IdToken = '';
  let crew2LocalId = '';
  let crew2UserId  = '';

  const pool = createPool();

  try {
    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 1: EC-001 Crew #2 Firebase 인증 및 초대코드 재가입
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[1/5] EC-001 Crew #2 Firebase 인증 및 초대코드 가입...');
    let check1Passed = false;
    try {
      // (a) Firebase 인증
      const { idToken, localId } = await Firebase.getIdToken(TEST_PHONES.crew2);
      crew2IdToken = idToken;
      crew2LocalId = localId;
      console.log(`  -> Firebase 인증 성공 localId=${localId}`);

      // (b) firebase-verify로 DB user_id 확보
      const verifyRes = await apiPost(
        '/api/v1/auth/firebase-verify',
        { id_token: crew2IdToken },
      );
      if (verifyRes.data?.data?.user_id) {
        crew2UserId = verifyRes.data.data.user_id;
        console.log(`  -> firebase-verify crew2UserId=${crew2UserId}`);
      } else {
        // fallback: Firebase localId 사용
        crew2UserId = localId;
        console.log(`  -> firebase-verify 실패, fallback crew2UserId=${crew2UserId}`);
      }

      // (c) travelerCode로 그룹 가입
      const joinRes = await apiPost(
        `/api/v1/groups/join-by-code/${travelerCode}`,
        {},
        crew2IdToken,
      );

      const joinOk = joinRes.status === 200 || joinRes.status === 201;
      console.log(
        `  -> join-by-code status=${joinRes.status}, ` +
        `already_member=${joinRes.data?.data?.already_member ?? false}, ` +
        `member_role=${joinRes.data?.data?.member?.member_role ?? 'N/A'}`,
      );

      if (!joinOk) {
        console.error('  join-by-code 응답 전체:', JSON.stringify(joinRes.data, null, 2));
      }

      // (d) DB 확인: member_role='crew', trip_id NOT NULL
      const rows = await dbQuery(
        pool,
        `SELECT member_role, trip_id
         FROM tb_group_member
         WHERE group_id = $1
           AND user_id  = $2`,
        [groupId, crew2UserId],
      );

      const hasRow       = rows.length > 0;
      const roleIsCrew   = hasRow && rows[0].member_role === 'crew';
      const tripIdNotNull = hasRow && rows[0].trip_id !== null && rows[0].trip_id !== undefined;

      check1Passed = joinOk && hasRow && roleIsCrew && tripIdNotNull;

      checks.push({
        label:  'EC-001 Crew #2 초대코드 가입 (member_role=crew, trip_id NOT NULL)',
        passed: check1Passed,
        detail: hasRow
          ? `status=${joinRes.status}, member_role=${rows[0].member_role}, trip_id=${rows[0].trip_id}`
          : `status=${joinRes.status}, DB 레코드 없음 (groupId=${groupId}, userId=${crew2UserId})`,
      });
      console.log(
        `  -> ${check1Passed ? 'PASS' : 'FAIL'} ` +
        `member_role=${rows[0]?.member_role ?? 'N/A'}, trip_id=${rows[0]?.trip_id ?? 'NULL'}`,
      );
    } catch (e: any) {
      checks.push({
        label:  'EC-001 Crew #2 초대코드 가입 (member_role=crew, trip_id NOT NULL)',
        passed: false,
        detail: e.message,
      });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 2: EC-001 중복 가입 방지 확인
    //   - 동일 travelerCode로 재가입 시도
    //   - 기대: 200 (already_member=true) 또는 200/201 (서버 중복 허용 처리)
    //   - DB: COUNT = 1 (중복 레코드 없음)
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[2/5] EC-001 중복 가입 방지 확인...');
    try {
      if (!crew2IdToken) {
        checks.push({
          label:  'EC-001 중복 가입 방지 (DB count=1)',
          passed: false,
          detail: 'crew2IdToken 없음 — CHECK 1 실패로 스킵',
        });
        console.log('  -> SKIP (crew2IdToken 없음)');
      } else {
        // 동일 코드로 재가입 시도
        const reJoinRes = await apiPost(
          `/api/v1/groups/join-by-code/${travelerCode}`,
          {},
          crew2IdToken,
        );

        const reJoinOk =
          reJoinRes.status === 200 ||
          reJoinRes.status === 201;

        console.log(
          `  -> 재가입 status=${reJoinRes.status}, ` +
          `already_member=${reJoinRes.data?.data?.already_member ?? false}`,
        );

        // DB: 중복 레코드 없음 확인
        const countRows = await dbQuery(
          pool,
          `SELECT COUNT(*) AS cnt
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, crew2UserId],
        );

        const count      = parseInt(countRows[0]?.cnt ?? '0', 10);
        const noDuplicate = count === 1;
        const passed      = reJoinOk && noDuplicate;

        checks.push({
          label:  'EC-001 중복 가입 방지 (DB count=1)',
          passed,
          detail: `재가입 status=${reJoinRes.status}, DB count=${count} (기대: 1)`,
        });
        console.log(
          `  -> ${passed ? 'PASS' : 'FAIL'} status=${reJoinRes.status}, DB count=${count}`,
        );

        if (!passed && !reJoinOk) {
          console.error('  재가입 응답 전체:', JSON.stringify(reJoinRes.data, null, 2));
        }
      }
    } catch (e: any) {
      checks.push({
        label:  'EC-001 중복 가입 방지 (DB count=1)',
        passed: false,
        detail: e.message,
      });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 3: EC-003 초대코드로 역할 자동 할당 확인
    //   - 서버가 코드 타입에 따라 member_role을 자동 할당하는지 검증
    //   - traveler 코드 사용 → member_role='crew' 기대
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[3/5] EC-003 초대코드 역할 자동 할당 확인...');
    try {
      if (!crew2UserId) {
        checks.push({
          label:  'EC-003 역할 자동 할당 (member_role=crew)',
          passed: false,
          detail: 'crew2UserId 없음 — CHECK 1 실패로 스킵',
        });
        console.log('  -> SKIP (crew2UserId 없음)');
      } else {
        const rows = await dbQuery(
          pool,
          `SELECT member_role
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, crew2UserId],
        );

        const hasRow     = rows.length > 0;
        const roleIsCrew = hasRow && rows[0].member_role === 'crew';
        const passed     = roleIsCrew;

        checks.push({
          label:  'EC-003 역할 자동 할당 (member_role=crew)',
          passed,
          detail: hasRow
            ? `member_role=${rows[0].member_role} (기대: crew)`
            : `DB 레코드 없음 (groupId=${groupId}, userId=${crew2UserId})`,
        });
        console.log(
          `  -> ${passed ? 'PASS' : 'FAIL'} member_role=${rows[0]?.member_role ?? 'N/A'}`,
        );
      }
    } catch (e: any) {
      checks.push({
        label:  'EC-003 역할 자동 할당 (member_role=crew)',
        passed: false,
        detail: e.message,
      });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 4: EC-004 Captain 리더십 이전 (Captain → Crew Chief)
    //   POST /api/v1/groups/:groupId/transfer-leadership
    //   body: { to_user_id: ccUserId }   ← 컨트롤러 파라미터명 확인됨
    //   token: captainIdToken
    //
    //   DB 검증:
    //   - ccUserId: member_role='captain', is_admin=true
    //   - captainUserId: is_admin=false
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[4/5] EC-004 Captain 리더십 이전 (Captain → Crew Chief)...');
    try {
      if (!groupId || !captainIdToken || !ccUserId) {
        checks.push({
          label:  'EC-004 리더십 이전 (ccUserId=captain, 원 captain is_admin=false)',
          passed: false,
          detail: 'groupId, captainIdToken 또는 ccUserId 없음',
        });
        console.log('  -> SKIP (필요 값 없음)');
      } else {
        // API 호출
        const transferRes = await apiPost(
          `/api/v1/groups/${groupId}/transfer-leadership`,
          { to_user_id: ccUserId },
          captainIdToken,
        );

        const transferOk = transferRes.status === 200;
        console.log(
          `  -> transfer-leadership status=${transferRes.status}`,
        );
        if (!transferOk) {
          console.error('  응답 전체:', JSON.stringify(transferRes.data, null, 2));
        }

        // DB: Crew Chief가 captain 역할 + is_admin=true 인지 확인
        const ccRows = await dbQuery(
          pool,
          `SELECT member_role, is_admin
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, ccUserId],
        );

        const ccHasRow         = ccRows.length > 0;
        const ccIsCaptain      = ccHasRow && ccRows[0].member_role === 'captain';
        const ccIsAdmin        = ccHasRow && ccRows[0].is_admin === true;

        console.log(
          `  -> CC DB: member_role=${ccRows[0]?.member_role ?? 'N/A'}, ` +
          `is_admin=${ccRows[0]?.is_admin ?? 'N/A'}`,
        );

        // DB: 원 Captain의 is_admin=false 확인
        const capRows = await dbQuery(
          pool,
          `SELECT is_admin, member_role
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, captainUserId],
        );

        const capHasRow      = capRows.length > 0;
        const capNotAdmin    = capHasRow && capRows[0].is_admin === false;

        console.log(
          `  -> 원 Captain DB: member_role=${capRows[0]?.member_role ?? 'N/A'}, ` +
          `is_admin=${capRows[0]?.is_admin ?? 'N/A'}`,
        );

        const passed = transferOk && ccIsCaptain && ccIsAdmin && capNotAdmin;

        checks.push({
          label:  'EC-004 리더십 이전 (ccUserId=captain, 원 captain is_admin=false)',
          passed,
          detail: [
            `transfer status=${transferRes.status}`,
            `CC: member_role=${ccRows[0]?.member_role ?? 'N/A'}, is_admin=${ccRows[0]?.is_admin ?? 'N/A'}`,
            `원 Captain: is_admin=${capRows[0]?.is_admin ?? 'N/A'}`,
          ].join('; '),
        });
        console.log(`  -> ${passed ? 'PASS' : 'FAIL'}`);
      }
    } catch (e: any) {
      checks.push({
        label:  'EC-004 리더십 이전 (ccUserId=captain, 원 captain is_admin=false)',
        passed: false,
        detail: e.message,
      });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 5: EC-002 getUserTrips — 기존 여행 유지 확인
    //   GET /api/v1/trips/users/:user_id/trips (token: crew2IdToken)
    //   검증: 응답에 tripId 포함
    //   주의: /api/v1/trips/my-trips 라우트 없음 → /users/:user_id/trips 사용
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[5/5] EC-002 getUserTrips — Crew #2 여행 목록 확인...');
    try {
      if (!crew2IdToken || !crew2UserId) {
        checks.push({
          label:  'EC-002 Crew #2 my-trips에 tripId 포함',
          passed: false,
          detail: 'crew2IdToken 또는 crew2UserId 없음 — CHECK 1 실패로 스킵',
        });
        console.log('  -> SKIP (crew2IdToken/crew2UserId 없음)');
      } else {
        const tripsRes = await apiGet(`/api/v1/trips/users/${crew2UserId}/trips`, crew2IdToken);

        const tripsOk = tripsRes.status === 200;
        console.log(`  -> my-trips status=${tripsRes.status}`);

        if (!tripsOk) {
          console.error('  응답 전체:', JSON.stringify(tripsRes.data, null, 2));
        }

        // 응답 구조: { data: { trips: [...] } } 또는 { data: [...] }
        const trips: any[] = Array.isArray(tripsRes.data?.data)
          ? tripsRes.data.data
          : (Array.isArray(tripsRes.data?.data?.trips)
              ? tripsRes.data.data.trips
              : []);

        const hasTripId = trips.some(
          (t: any) => t.trip_id === tripId || t.tripId === tripId,
        );

        const passed = tripsOk && hasTripId;

        checks.push({
          label:  'EC-002 Crew #2 my-trips에 tripId 포함',
          passed,
          detail: [
            `status=${tripsRes.status}`,
            `여행 수=${trips.length}`,
            `tripId(${tripId}) 포함=${hasTripId}`,
          ].join(', '),
        });
        console.log(
          `  -> ${passed ? 'PASS' : 'FAIL'} ` +
          `여행 수=${trips.length}, tripId 포함=${hasTripId}`,
        );

        if (!passed && tripsOk) {
          console.error(
            '  여행 목록:',
            JSON.stringify(
              trips.map((t: any) => ({ trip_id: t.trip_id ?? t.tripId })),
              null,
              2,
            ),
          );
        }
      }
    } catch (e: any) {
      checks.push({
        label:  'EC-002 Crew #2 my-trips에 tripId 포함',
        passed: false,
        detail: e.message,
      });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ─── State 파일 업데이트 ──────────────────────────────────────────────────
    const updatedState = {
      ...state,
      crew2IdToken,
      crew2LocalId,
      crew2UserId,
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
  console.log('SafeTrip UAT Phase 5: 엣지 케이스 검증 시작');
  console.log(`서버: ${CONFIG.serverUrl}`);
  console.log(`Firebase Auth 에뮬레이터: ${CONFIG.firebaseAuthUrl}`);
  console.log(`Crew #2 전화번호: ${TEST_PHONES.crew2}`);

  let result: PhaseResult;
  try {
    result = await runPhase5();
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
