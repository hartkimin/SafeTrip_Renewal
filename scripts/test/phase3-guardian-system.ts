// scripts/test/phase3-guardian-system.ts
//
// SafeTrip UAT Phase 3: 가디언 시스템
//
// 검증 항목 6개:
//   1. Guardian Firebase 인증 (TEST_PHONES.guardian = +821099901004)
//   2. Guardian 그룹 가입 (guardianCode 사용) → DB user_id 획득
//   3. DB tb_group_member.member_role = 'guardian' 확인
//   4. 가디언 링크 생성 (Crew #1이 Guardian 초대) → link_id 추출
//   5. 가디언 링크 수락 (Guardian이 accepted) → DB status='accepted' 확인
//   6. Member→Guardian 메시지 전송 → RTDB 저장 확인
//
// 실행: cd /mnt/d/Project/15_SafeTrip_New && NODE_PATH=safetrip-server-api/node_modules npx tsx scripts/test/phase3-guardian-system.ts
//
// 사전 조건:
//   - Phase 1, 2 state: /tmp/safetrip-test-state.json 존재
//     (captainIdToken, groupId, tripId, guardianCode, crew1IdToken, crew1UserId 포함)
//   - 서버(:3001), Firebase 에뮬레이터(:9099, :9000), PostgreSQL 모두 실행 중

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
  httpGet,
} from './utils/test-client';

// ─── 상태 파일 경로 ───────────────────────────────────────────────────────────

const STATE_PATH = '/tmp/safetrip-test-state.json';

// ─── Phase 1+2 state 구조 ────────────────────────────────────────────────────

interface PhaseState {
  captainIdToken: string;
  captainUserId: string;
  groupId: string;
  tripId: string;
  travelerCode: string;
  guardianCode: string;
  crew1IdToken: string;
  crew1UserId: string;
  ccIdToken: string;
  ccUserId: string;
}

function loadState(): PhaseState {
  if (!fs.existsSync(STATE_PATH)) {
    throw new Error(
      `State 파일 없음: ${STATE_PATH}\nPhase 1, 2를 먼저 실행하세요.`,
    );
  }
  const raw = fs.readFileSync(STATE_PATH, 'utf-8');
  const state = JSON.parse(raw) as PhaseState;

  const required: (keyof PhaseState)[] = [
    'captainIdToken', 'groupId', 'tripId', 'guardianCode',
    'crew1IdToken', 'crew1UserId',
  ];
  const missing = required.filter((k) => !state[k]);
  if (missing.length > 0) {
    throw new Error(
      `State 필드 누락: ${missing.join(', ')}\nPhase 1, 2를 다시 실행하세요.`,
    );
  }
  return state;
}

// ─── Phase 3 메인 ─────────────────────────────────────────────────────────────

async function runPhase3(): Promise<PhaseResult> {
  const phaseName = 'Phase 3: 가디언 시스템';
  const checks: CheckResult[] = [];

  // 이전 Phase state 로드
  const prev = loadState();
  const { groupId, tripId, guardianCode, crew1IdToken, crew1UserId } = prev;

  console.log('\n[Phase 1+2 State 로드]');
  console.log(`  groupId       : ${groupId}`);
  console.log(`  tripId        : ${tripId}`);
  console.log(`  guardianCode  : ${guardianCode}`);
  console.log(`  crew1UserId   : ${crew1UserId}`);

  // Phase 3에서 수집할 값들
  let guardianIdToken = '';
  let guardianUserId  = '';
  let linkId          = '';
  let channelId       = '';
  let memberMessageKey = '';

  const pool = createPool();

  try {
    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 1: Guardian Firebase 인증
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[1/6] Guardian Firebase 인증 중...');
    try {
      const { idToken, localId } = await Firebase.getIdToken(TEST_PHONES.guardian);
      guardianIdToken = idToken;
      guardianUserId  = localId; // 임시; firebase-verify 응답으로 덮어씀

      const passed = !!(idToken && localId);
      checks.push({
        label:  'Guardian Firebase 인증 성공',
        passed,
        detail: passed ? `localId=${localId}` : 'idToken 또는 localId 없음',
      });
      console.log(`  -> ${passed ? 'PASS' : 'FAIL'} localId=${localId}`);
    } catch (e: any) {
      checks.push({ label: 'Guardian Firebase 인증 성공', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    if (!guardianIdToken) {
      const skipDetail = 'Guardian Firebase 인증 실패로 스킵';
      checks.push({ label: 'Guardian 그룹 가입 200/201',       passed: false, detail: skipDetail });
      checks.push({ label: 'Guardian member_role = guardian',   passed: false, detail: skipDetail });
      checks.push({ label: '가디언 링크 생성 201',             passed: false, detail: skipDetail });
      checks.push({ label: '가디언 링크 수락 → status=accepted', passed: false, detail: skipDetail });
      checks.push({ label: '멤버→가디언 메시지 RTDB 저장',     passed: false, detail: skipDetail });
      return { phase: phaseName, passed: false, checks };
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 2: Guardian 그룹 가입 (guardianCode 사용)
    //   - firebase-verify로 tb_user에 upsert & DB user_id 획득
    //   - POST /api/v1/groups/join-by-code/:guardianCode (token: guardianIdToken)
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[2/6] Guardian 그룹 가입 중...');
    let guardianJoinPassed = false;
    try {
      // tb_user 자동 upsert + DB user_id 획득
      const verifyRes = await apiPost(
        '/api/v1/auth/firebase-verify',
        { id_token: guardianIdToken },
      );
      if (verifyRes.data?.data?.user_id) {
        guardianUserId = verifyRes.data.data.user_id;
        console.log(`  -> firebase-verify guardianUserId=${guardianUserId}`);
      } else {
        console.warn(`  -> firebase-verify 응답에 user_id 없음 (status=${verifyRes.status})`);
        console.warn('  응답 전체:', JSON.stringify(verifyRes.data, null, 2));
      }

      // guardianCode로 그룹 가입
      const joinRes = await apiPost(
        `/api/v1/groups/join-by-code/${guardianCode}`,
        {},
        guardianIdToken,
      );

      guardianJoinPassed = joinRes.status === 200 || joinRes.status === 201;

      checks.push({
        label:  'Guardian 그룹 가입 200/201',
        passed: guardianJoinPassed,
        detail: `status=${joinRes.status}, already_member=${joinRes.data?.data?.already_member ?? false}, member_role=${joinRes.data?.data?.member?.member_role ?? 'N/A'}`,
      });
      console.log(`  -> ${guardianJoinPassed ? 'PASS' : 'FAIL'} status=${joinRes.status}`);

      if (!guardianJoinPassed) {
        console.error('  응답 전체:', JSON.stringify(joinRes.data, null, 2));
      }
    } catch (e: any) {
      checks.push({ label: 'Guardian 그룹 가입 200/201', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 3: DB tb_group_member.member_role = 'guardian' 확인
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[3/6] DB Guardian member_role 확인 중...');
    try {
      if (!guardianUserId) {
        checks.push({
          label:  'Guardian member_role = guardian',
          passed: false,
          detail: 'guardianUserId 없음 (firebase-verify 실패)',
        });
        console.log('  -> SKIP (guardianUserId 없음)');
      } else {
        const rows = await dbQuery(
          pool,
          `SELECT member_role, is_guardian
           FROM tb_group_member
           WHERE group_id = $1
             AND user_id  = $2`,
          [groupId, guardianUserId],
        );

        const hasGuardianRole = rows.length > 0 && rows[0].member_role === 'guardian';
        checks.push({
          label:  'Guardian member_role = guardian',
          passed: hasGuardianRole,
          detail: rows.length > 0
            ? `member_role=${rows[0].member_role}, is_guardian=${rows[0].is_guardian}`
            : `group_id=${groupId}, user_id=${guardianUserId} 레코드 없음`,
        });
        console.log(`  -> ${hasGuardianRole ? 'PASS' : 'FAIL'} member_role=${rows[0]?.member_role ?? 'N/A'}, is_guardian=${rows[0]?.is_guardian ?? 'N/A'}`);
      }
    } catch (e: any) {
      checks.push({ label: 'Guardian member_role = guardian', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 4: 가디언 링크 생성 (Crew #1이 Guardian 초대)
    //   POST /api/v1/trips/:tripId/guardians
    //   body: { guardian_phone: '+821099901004' }
    //   token: crew1IdToken
    //   → 201, 응답에서 link_id 추출
    //   → DB: status='pending' or 'accepted' (이미 수락된 경우도 허용)
    //
    //   멱등성: 409 (GUARDIAN_LINK_ALREADY_EXISTS) 발생 시 DB에서 기존 link_id 조회
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[4/6] 가디언 링크 생성 (Crew #1 → Guardian 초대) 중...');
    let linkCreatePassed = false;
    try {
      // 먼저 기존 링크 삭제 후 신규 생성 (멱등성 보장)
      // DB에서 기존 링크 삭제
      const existingRows = await dbQuery(
        pool,
        `SELECT link_id, status FROM tb_guardian_link
         WHERE trip_id = $1 AND member_id = $2 AND guardian_id = $3`,
        [tripId, crew1UserId, guardianUserId],
      );
      if (existingRows.length > 0) {
        console.log(`  -> 기존 링크 발견 (link_id=${existingRows[0].link_id}, status=${existingRows[0].status}), 삭제 후 재생성...`);
        await dbQuery(
          pool,
          `DELETE FROM tb_guardian_link WHERE link_id = $1`,
          [existingRows[0].link_id],
        );
        console.log(`  -> 기존 링크 삭제 완료`);
      }

      const res = await apiPost(
        `/api/v1/trips/${tripId}/guardians`,
        { guardian_phone: TEST_PHONES.guardian },
        crew1IdToken,
      );

      const okStatus = res.status === 201;
      const hasLinkId = !!(res.data?.data?.link_id);

      if (hasLinkId) {
        linkId = res.data.data.link_id;
      }

      // DB에서 pending 상태 확인
      let dbStatus = '';
      if (hasLinkId) {
        try {
          const rows = await dbQuery(
            pool,
            `SELECT status FROM tb_guardian_link WHERE link_id = $1`,
            [linkId],
          );
          dbStatus = rows[0]?.status ?? '';
          console.log(`  -> DB status=${dbStatus}`);
        } catch (dbErr: any) {
          console.warn(`  -> DB 확인 실패: ${dbErr.message}`);
        }
      }

      const dbPending = dbStatus === 'pending';
      linkCreatePassed = okStatus && hasLinkId && dbPending;

      checks.push({
        label:  '가디언 링크 생성 201',
        passed: linkCreatePassed,
        detail: `status=${res.status}, link_id=${linkId || 'N/A'}, db_status=${dbStatus || 'N/A'}`,
      });
      console.log(`  -> ${linkCreatePassed ? 'PASS' : 'FAIL'} status=${res.status} link_id=${linkId}`);

      if (!linkCreatePassed) {
        console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
      }
    } catch (e: any) {
      checks.push({ label: '가디언 링크 생성 201', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 5: 가디언 링크 수락 (Guardian이 accepted)
    //   PATCH /api/v1/trips/:tripId/guardians/:linkId/respond
    //   body: { action: 'accepted' }
    //   token: guardianIdToken
    //   → 200
    //   → DB: status='accepted' 확인
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[5/6] 가디언 링크 수락 (Guardian → accepted) 중...');
    let linkAcceptPassed = false;
    try {
      if (!linkId) {
        checks.push({
          label:  '가디언 링크 수락 → status=accepted',
          passed: false,
          detail: 'linkId 없음 (링크 생성 실패)',
        });
        console.log('  -> SKIP (linkId 없음)');
      } else if (!guardianIdToken) {
        checks.push({
          label:  '가디언 링크 수락 → status=accepted',
          passed: false,
          detail: 'guardianIdToken 없음',
        });
        console.log('  -> SKIP (guardianIdToken 없음)');
      } else {
        const res = await apiPatch(
          `/api/v1/trips/${tripId}/guardians/${linkId}/respond`,
          { action: 'accepted' },
          guardianIdToken,
        );

        const okStatus = res.status === 200;

        // DB에서 accepted 상태 확인
        let dbAccepted = false;
        try {
          const rows = await dbQuery(
            pool,
            `SELECT status FROM tb_guardian_link WHERE link_id = $1`,
            [linkId],
          );
          dbAccepted = rows.length > 0 && rows[0].status === 'accepted';
          console.log(`  -> DB status=${rows[0]?.status ?? 'N/A'}`);
        } catch (dbErr: any) {
          console.warn(`  -> DB 확인 실패: ${dbErr.message}`);
        }

        linkAcceptPassed = okStatus && dbAccepted;

        checks.push({
          label:  '가디언 링크 수락 → status=accepted',
          passed: linkAcceptPassed,
          detail: `status=${res.status}, db_status=${dbAccepted ? 'accepted' : 'N/A'}`,
        });
        console.log(`  -> ${linkAcceptPassed ? 'PASS' : 'FAIL'} status=${res.status}`);

        if (!linkAcceptPassed) {
          console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
        }
      }
    } catch (e: any) {
      checks.push({ label: '가디언 링크 수락 → status=accepted', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CHECK 6: Member→Guardian 메시지 전송
    //   POST /api/v1/trips/:tripId/guardian-messages/member
    //   body: { link_id: linkId, message: 'UAT 테스트 메시지입니다' }
    //   token: crew1IdToken
    //   → 200 or 201
    //   → 응답에서 message_key, channel_id 추출
    //   → RTDB 검증: guardian_messages/{tripId}/{linkId}/messages/{messageKey}
    // ──────────────────────────────────────────────────────────────────────────
    console.log('\n[6/6] Member→Guardian 메시지 전송 중...');
    let messagePassed = false;
    try {
      if (!linkId) {
        checks.push({
          label:  '멤버→가디언 메시지 RTDB 저장',
          passed: false,
          detail: 'linkId 없음 (링크 생성/수락 실패)',
        });
        console.log('  -> SKIP (linkId 없음)');
      } else {
        const res = await apiPost(
          `/api/v1/trips/${tripId}/guardian-messages/member`,
          {
            link_id: linkId,
            message: 'UAT 테스트 메시지입니다',
          },
          crew1IdToken,
        );

        const okStatus = res.status === 200 || res.status === 201;
        const hasMessageKey = !!(res.data?.data?.message_key);

        if (hasMessageKey) {
          memberMessageKey = res.data.data.message_key;
        }
        if (res.data?.data?.channel_id) {
          channelId = res.data.data.channel_id;
        }

        console.log(`  -> API status=${res.status}, message_key=${memberMessageKey}, channel_id=${channelId}`);

        // RTDB 검증: guardian_messages/{tripId}/{linkId}/messages/{messageKey}
        // channel_id = 'link_{linkId}' → RTDB 경로는 linkId 직접 사용
        // 서버 FIREBASE_DATABASE_URL: http://127.0.0.1:9000/?ns=safetrip-urock-default-rtdb
        // → RTDB 네임스페이스는 'safetrip-urock-default-rtdb' (프로젝트 ID와 다름)
        let inRtdb = false;
        if (okStatus && memberMessageKey) {
          try {
            // sendToLinkChannel은 guardian_messages/{tripId}/{linkId}/messages 에 push
            const rtdbNs = `${CONFIG.firebaseProject}-default-rtdb`;
            const rtdbUrl = `${CONFIG.firebaseRTDBUrl}/guardian_messages/${tripId}/${linkId}/messages/${memberMessageKey}.json?ns=${rtdbNs}`;
            console.log(`  -> RTDB URL: ${rtdbUrl}`);
            const rtdbRes = await httpGet(rtdbUrl);
            inRtdb = rtdbRes.status === 200 && rtdbRes.data !== null;
            console.log(`  -> RTDB status=${rtdbRes.status}, data=${JSON.stringify(rtdbRes.data)?.substring(0, 120)}`);
          } catch (rtdbErr: any) {
            console.warn(`  -> RTDB 조회 실패: ${rtdbErr.message}`);
          }
        }

        messagePassed = okStatus && hasMessageKey && inRtdb;

        checks.push({
          label:  '멤버→가디언 메시지 RTDB 저장',
          passed: messagePassed,
          detail: `status=${res.status}, message_key=${memberMessageKey || 'N/A'}, channel_id=${channelId || 'N/A'}, rtdb=${inRtdb ? 'PASS' : 'FAIL'}`,
        });
        console.log(`  -> ${messagePassed ? 'PASS' : 'FAIL'} status=${res.status} rtdb=${inRtdb}`);

        if (!messagePassed) {
          console.error('  응답 전체:', JSON.stringify(res.data, null, 2));
        }
      }
    } catch (e: any) {
      checks.push({ label: '멤버→가디언 메시지 RTDB 저장', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ─── State 파일 업데이트 ──────────────────────────────────────────────────
    const updatedState = {
      ...prev,
      guardianIdToken,
      guardianUserId,
      linkId,
      channelId,
      memberMessageId: memberMessageKey,
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
  console.log('SafeTrip UAT Phase 3: 가디언 시스템 시작');
  console.log(`서버: ${CONFIG.serverUrl}`);
  console.log(`Firebase Auth 에뮬레이터: ${CONFIG.firebaseAuthUrl}`);
  console.log(`Firebase RTDB 에뮬레이터: ${CONFIG.firebaseRTDBUrl}`);
  console.log(`Guardian 전화번호: ${TEST_PHONES.guardian}`);

  let result: PhaseResult;
  try {
    result = await runPhase3();
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
