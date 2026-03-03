// scripts/test/phase1-captain-onboarding.ts
//
// SafeTrip UAT Phase 1: Captain 온보딩
//
// 검증 항목 9개:
//   1. Captain Firebase 인증 (TEST_PHONES.captain)
//   2. firebase-verify 서버 API 호출 → 200/201 확인
//   3. DB tb_user 레코드 생성 확인 (phone_number 기준)
//   4. 여행 생성 (POST /api/v1/trips) → 200/201 확인
//   5. DB tb_trip 레코드 존재 확인
//   6. DB tb_group_member.member_role = 'captain' 확인
//   7. DB tb_group_member.trip_id NOT NULL 확인
//   8. Traveler 초대 코드 생성 (target_role='crew')
//   9. Guardian 초대 코드 생성 (target_role='guardian')
//
// 실행: npx tsx scripts/test/phase1-captain-onboarding.ts
//   (프로젝트 루트에서 실행)
//
// 사전 조건:
//   - 서버(:3001), Firebase 에뮬레이터(:9099, :9000), PostgreSQL 모두 실행 중
//   - Firebase Auth 에뮬레이터 계정 초기화 완료

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
} from './utils/test-client';

// ─── 날짜 헬퍼 ────────────────────────────────────────────────────────────────

function dateAfterDays(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().split('T')[0];
}

// ─── 상태 저장 경로 ───────────────────────────────────────────────────────────

const STATE_PATH = '/tmp/safetrip-test-state.json';

// ─── Phase 1 메인 ─────────────────────────────────────────────────────────────

async function runPhase1(): Promise<PhaseResult> {
  const phaseName = 'Phase 1: Captain 온보딩';
  const checks: CheckResult[] = [];

  const pool = createPool();

  // 결과 상태 (state 파일에 저장)
  let captainIdToken = '';
  let captainUserId  = '';
  let groupId        = '';
  let tripId         = '';
  let travelerCode   = '';
  let guardianCode   = '';

  try {
    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 1: Captain Firebase 인증
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[1/9] Captain Firebase 인증 중...');
    let authPassed = false;
    try {
      const { idToken, localId } = await Firebase.getIdToken(TEST_PHONES.captain);
      captainIdToken = idToken;
      captainUserId  = localId; // 임시; 나중에 firebase-verify 응답으로 덮어씀

      authPassed = !!(idToken && localId);
      checks.push({
        label:  'Captain Firebase 인증 성공',
        passed: authPassed,
        detail: authPassed ? `localId=${localId}` : 'idToken 또는 localId 없음',
      });
      console.log(`  -> ${authPassed ? 'PASS' : 'FAIL'} localId=${localId}`);
    } catch (e: any) {
      checks.push({ label: 'Captain Firebase 인증 성공', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    if (!captainIdToken) {
      // 인증 실패 시 후속 체크 불가
      checks.push({ label: 'firebase-verify 200/201',      passed: false, detail: '선행 Firebase 인증 실패' });
      checks.push({ label: 'tb_user INSERT 확인',          passed: false, detail: '선행 단계 실패' });
      checks.push({ label: '여행 생성 200/201',             passed: false, detail: '선행 단계 실패' });
      checks.push({ label: 'tb_trip 레코드 존재',           passed: false, detail: '선행 단계 실패' });
      checks.push({ label: 'Captain member_role = captain', passed: false, detail: '선행 단계 실패' });
      checks.push({ label: 'tb_group_member.trip_id NOT NULL', passed: false, detail: '선행 단계 실패' });
      checks.push({ label: 'Traveler 초대 코드 생성',       passed: false, detail: '선행 단계 실패' });
      checks.push({ label: 'Guardian 초대 코드 생성',       passed: false, detail: '선행 단계 실패' });
      return { phase: phaseName, passed: false, checks };
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 2: firebase-verify 서버 API 호출 → 200/201
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[2/9] firebase-verify API 호출 중...');
    let verifyPassed = false;
    try {
      const res = await apiPost('/api/v1/auth/firebase-verify', {
        id_token: captainIdToken,
      });

      const okStatus = res.status === 200 || res.status === 201;
      const hasUserId = !!(res.data?.data?.user_id);

      verifyPassed = okStatus && hasUserId;

      if (hasUserId) {
        // firebase-verify 응답의 user_id(=firebase UID)로 갱신
        captainUserId = res.data.data.user_id;
      }

      checks.push({
        label:  'firebase-verify 200/201',
        passed: verifyPassed,
        detail: `status=${res.status}, user_id=${res.data?.data?.user_id ?? 'N/A'}`,
      });
      console.log(`  -> ${verifyPassed ? 'PASS' : 'FAIL'} status=${res.status} user_id=${captainUserId}`);

      if (!verifyPassed) {
        console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
      }
    } catch (e: any) {
      checks.push({ label: 'firebase-verify 200/201', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 3: DB tb_user 레코드 생성 확인 (phone_number 기준)
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[3/9] DB tb_user 레코드 확인 중...');
    let dbUserPassed = false;
    try {
      const rows = await dbQuery(
        pool,
        `SELECT user_id, phone_number, created_at
         FROM tb_user
         WHERE phone_number = $1
           AND deleted_at IS NULL`,
        [TEST_PHONES.captain],
      );

      dbUserPassed = rows.length > 0;

      // DB의 user_id로 갱신 (firebase-verify가 실패한 경우 대비)
      if (dbUserPassed && !captainUserId) {
        captainUserId = rows[0].user_id;
      }

      checks.push({
        label:  'tb_user INSERT 확인',
        passed: dbUserPassed,
        detail: dbUserPassed
          ? `user_id=${rows[0].user_id}, phone=${rows[0].phone_number}`
          : `phone=${TEST_PHONES.captain} 미존재`,
      });
      console.log(`  -> ${dbUserPassed ? 'PASS' : 'FAIL'} rows=${rows.length}`);
    } catch (e: any) {
      checks.push({ label: 'tb_user INSERT 확인', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 4: 여행 생성 (POST /api/v1/trips) → 200/201
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[4/9] 여행 생성 중...');
    let tripCreatePassed = false;
    try {
      const startDate = dateAfterDays(1);
      const endDate   = dateAfterDays(7);

      // controllers/trips.controller.ts createTrip 읽음:
      //   const { title, country_code, country_name, trip_type, start_date, end_date } = req.body;
      //   'title' 필드 (trip_name 아님)
      const res = await apiPost(
        '/api/v1/trips',
        {
          title:            'UAT 테스트 여행',
          country_code:     'JP',
          country_name:     '일본',
          destination_city: '도쿄',
          trip_type:        'leisure',
          start_date:       startDate,
          end_date:         endDate,
        },
        captainIdToken,
      );

      const okStatus = res.status === 200 || res.status === 201;
      const hasTripId  = !!(res.data?.data?.trip_id);
      const hasGroupId = !!(res.data?.data?.group_id);

      tripCreatePassed = okStatus && hasTripId && hasGroupId;

      if (hasTripId)  tripId  = res.data.data.trip_id;
      if (hasGroupId) groupId = res.data.data.group_id;

      checks.push({
        label:  '여행 생성 200/201',
        passed: tripCreatePassed,
        detail: `status=${res.status}, trip_id=${tripId || 'N/A'}, group_id=${groupId || 'N/A'}`,
      });
      console.log(`  -> ${tripCreatePassed ? 'PASS' : 'FAIL'} status=${res.status} trip_id=${tripId} group_id=${groupId}`);

      if (!tripCreatePassed) {
        console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
      }
    } catch (e: any) {
      checks.push({ label: '여행 생성 200/201', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 5: DB tb_trip 레코드 존재 확인
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[5/9] DB tb_trip 레코드 확인 중...');
    let dbTripPassed = false;
    try {
      if (!tripId) {
        checks.push({ label: 'tb_trip 레코드 존재', passed: false, detail: '여행 생성 실패로 tripId 없음' });
        console.log('  -> SKIP (tripId 없음)');
      } else {
        const rows = await dbQuery(
          pool,
          `SELECT trip_id, group_id, country_code, start_date, end_date, status
           FROM tb_trip
           WHERE trip_id = $1`,
          [tripId],
        );

        dbTripPassed = rows.length > 0;

        checks.push({
          label:  'tb_trip 레코드 존재',
          passed: dbTripPassed,
          detail: dbTripPassed
            ? `trip_id=${rows[0].trip_id}, country=${rows[0].country_code}, status=${rows[0].status}`
            : `trip_id=${tripId} 미존재`,
        });
        console.log(`  -> ${dbTripPassed ? 'PASS' : 'FAIL'} rows=${rows.length}`);
      }
    } catch (e: any) {
      checks.push({ label: 'tb_trip 레코드 존재', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 6: DB tb_group_member.member_role = 'captain' 확인
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[6/9] Captain member_role 확인 중...');
    let memberRolePassed = false;
    try {
      if (!groupId || !captainUserId) {
        checks.push({ label: 'Captain member_role = captain', passed: false, detail: 'groupId 또는 captainUserId 없음' });
        console.log('  -> SKIP (groupId/captainUserId 없음)');
      } else {
        const rows = await dbQuery(
          pool,
          `SELECT member_id, user_id, member_role, is_admin, trip_id
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, captainUserId],
        );

        const hasCaptainRole = rows.length > 0 && rows[0].member_role === 'captain';
        memberRolePassed = hasCaptainRole;

        checks.push({
          label:  'Captain member_role = captain',
          passed: memberRolePassed,
          detail: rows.length > 0
            ? `member_role=${rows[0].member_role}, is_admin=${rows[0].is_admin}`
            : '레코드 없음',
        });
        console.log(`  -> ${memberRolePassed ? 'PASS' : 'FAIL'} member_role=${rows[0]?.member_role ?? 'N/A'}`);
      }
    } catch (e: any) {
      checks.push({ label: 'Captain member_role = captain', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 7: DB tb_group_member.trip_id NOT NULL 확인
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[7/9] tb_group_member.trip_id NOT NULL 확인 중...');
    let tripIdNotNullPassed = false;
    try {
      if (!groupId || !captainUserId) {
        checks.push({ label: 'tb_group_member.trip_id NOT NULL', passed: false, detail: 'groupId 또는 captainUserId 없음' });
        console.log('  -> SKIP (groupId/captainUserId 없음)');
      } else {
        const rows = await dbQuery(
          pool,
          `SELECT trip_id
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, captainUserId],
        );

        const hasTripId = rows.length > 0 && rows[0].trip_id !== null && rows[0].trip_id !== undefined;
        tripIdNotNullPassed = hasTripId;

        checks.push({
          label:  'tb_group_member.trip_id NOT NULL',
          passed: tripIdNotNullPassed,
          detail: rows.length > 0
            ? `trip_id=${rows[0].trip_id}`
            : '레코드 없음',
        });
        console.log(`  -> ${tripIdNotNullPassed ? 'PASS' : 'FAIL'} trip_id=${rows[0]?.trip_id ?? 'NULL'}`);
      }
    } catch (e: any) {
      checks.push({ label: 'tb_group_member.trip_id NOT NULL', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 8: Traveler 초대 코드 생성
    //   POST /api/v1/groups/:groupId/invite-codes
    //   body: { target_role: 'crew' }
    //   (crew = 여행자/traveler 역할)
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[8/9] Traveler 초대 코드 생성 중...');
    let travelerCodePassed = false;
    try {
      if (!groupId) {
        checks.push({ label: 'Traveler 초대 코드 생성', passed: false, detail: 'groupId 없음' });
        console.log('  -> SKIP (groupId 없음)');
      } else {
        const res = await apiPost(
          `/api/v1/groups/${groupId}/invite-codes`,
          {
            target_role:     'crew',
            max_uses:        50,
            expires_in_days: 7,
          },
          captainIdToken,
        );

        const okStatus = res.status === 200 || res.status === 201;
        const hasCode  = !!(res.data?.data?.code);

        travelerCodePassed = okStatus && hasCode;
        if (hasCode) travelerCode = res.data.data.code;

        checks.push({
          label:  'Traveler 초대 코드 생성',
          passed: travelerCodePassed,
          detail: `status=${res.status}, code=${travelerCode || 'N/A'}`,
        });
        console.log(`  -> ${travelerCodePassed ? 'PASS' : 'FAIL'} status=${res.status} code=${travelerCode}`);

        if (!travelerCodePassed) {
          console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
        }
      }
    } catch (e: any) {
      checks.push({ label: 'Traveler 초대 코드 생성', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 9: Guardian 초대 코드 생성
    //   POST /api/v1/groups/:groupId/invite-codes
    //   body: { target_role: 'guardian' }
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[9/9] Guardian 초대 코드 생성 중...');
    let guardianCodePassed = false;
    try {
      if (!groupId) {
        checks.push({ label: 'Guardian 초대 코드 생성', passed: false, detail: 'groupId 없음' });
        console.log('  -> SKIP (groupId 없음)');
      } else {
        const res = await apiPost(
          `/api/v1/groups/${groupId}/invite-codes`,
          {
            target_role:     'guardian',
            max_uses:        10,
            expires_in_days: 7,
          },
          captainIdToken,
        );

        const okStatus = res.status === 200 || res.status === 201;
        const hasCode  = !!(res.data?.data?.code);

        guardianCodePassed = okStatus && hasCode;
        if (hasCode) guardianCode = res.data.data.code;

        checks.push({
          label:  'Guardian 초대 코드 생성',
          passed: guardianCodePassed,
          detail: `status=${res.status}, code=${guardianCode || 'N/A'}`,
        });
        console.log(`  -> ${guardianCodePassed ? 'PASS' : 'FAIL'} status=${res.status} code=${guardianCode}`);

        if (!guardianCodePassed) {
          console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
        }
      }
    } catch (e: any) {
      checks.push({ label: 'Guardian 초대 코드 생성', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ─── State 파일 저장 ──────────────────────────────────────────────────────
    const state = {
      captainIdToken,
      captainUserId,
      groupId,
      tripId,
      travelerCode,
      guardianCode,
    };

    try {
      fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2), 'utf-8');
      console.log(`\n[State] ${STATE_PATH} 저장 완료`);
      console.log(JSON.stringify(state, null, 2));
    } catch (e: any) {
      console.error(`[State] 저장 실패: ${e.message}`);
    }

    return { phase: phaseName, passed: checks.every((c) => c.passed), checks };
  } catch (error: any) {
    return { phase: phaseName, passed: false, checks, error: error.message };
  } finally {
    await pool.end();
  }
}

// ─── 결과 출력 (test-client.ts printResults 확장 버전) ───────────────────────

function printPhaseResult(result: PhaseResult): void {
  const SEP = '='.repeat(60);
  console.log('\n' + SEP);
  console.log(`  SafeTrip UAT — ${result.phase}`);
  console.log(SEP);

  let passCount = 0;
  let failCount = 0;

  for (const c of result.checks) {
    if (c.passed) {
      console.log(`  ✓ ${c.label}`);
      if (c.detail) console.log(`      ${c.detail}`);
      passCount++;
    } else {
      console.log(`  ✗ ${c.label}`);
      if (c.detail) console.log(`      [FAIL] ${c.detail}`);
      failCount++;
    }
  }

  console.log(SEP);
  const total = passCount + failCount;
  const allOk = failCount === 0;
  console.log(
    `  합계: ${total}/1 ${allOk ? '통과' : '실패'} (체크 ${passCount}/${total} 통과)`,
  );
  console.log(SEP + '\n');
}

// ─── 진입점 ────────────────────────────────────────────────────────────────────

(async () => {
  console.log('SafeTrip UAT Phase 1: Captain 온보딩 시작');
  console.log(`서버: ${CONFIG.serverUrl}`);
  console.log(`Firebase Auth 에뮬레이터: ${CONFIG.firebaseAuthUrl}`);
  console.log(`Captain 전화번호: ${TEST_PHONES.captain}`);

  // Firebase Auth 에뮬레이터 계정 초기화
  console.log('\n[사전 준비] Firebase Auth 에뮬레이터 계정 초기화...');
  try {
    const { httpRequest } = await import('./utils/test-client');
    const delRes = await httpRequest(
      'DELETE',
      `${CONFIG.firebaseAuthUrl}/emulator/v1/projects/${CONFIG.firebaseProject}/accounts`,
      undefined,
      { Authorization: 'Bearer owner' },
    );
    if (delRes.status === 200) {
      console.log('  -> 에뮬레이터 계정 초기화 완료');
    } else {
      console.warn(`  -> 초기화 응답 status=${delRes.status} (계속 진행)`);
    }
  } catch (e: any) {
    console.warn(`  -> 초기화 실패 (계속 진행): ${e.message}`);
  }

  const result = await runPhase1();
  printPhaseResult(result);

  if (!result.passed) {
    console.error('일부 체크 실패 — 서버 로그 확인:');
    console.error('  tail -20 /tmp/safetrip-backend.log');
    process.exit(1);
  }
})();
