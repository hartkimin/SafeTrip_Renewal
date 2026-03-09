// scripts/test/phase7-onboarding-ux.ts
//
// SafeTrip UAT Phase 7: 온보딩 UX 시나리오 검증 (DOC-T3-ONB-014 v3.1)
//
// 검증 항목 14개:
//   1. 시나리오 A: Captain Firebase 인증 → 사용자 생성
//   2. 시나리오 A: 약관 동의 기록 (4종 필수 + 1종 선택)
//   3. 시나리오 A: 약관 동의 DB 저장 확인
//   4. 시나리오 A: 온보딩 완료 (displayName + dateOfBirth)
//   5. 시나리오 A: 성인 minorStatus = 'adult' 확인
//   6. 시나리오 A: 여행 생성 + 15일 제한 검증
//   7. 시나리오 A: 15일 초과 여행 생성 차단
//   8. 시나리오 B: Crew 초대코드 참여 → 역할 배정
//   9. 시나리오 B: 초대코드 미리보기 (validate)
//  10. 시나리오 C: 가디언 초대 생성 + 수락
//  11. 시나리오 D: 복귀 사용자 토큰 재인증
//  12. 미성년자(14~17세) 온보딩 → minor_over14
//  13. 미성년자(14세 미만) → 법정대리인 동의 필수
//  14. 약관 동의 철회 기능
//
// 실행: npx tsx scripts/test/phase7-onboarding-ux.ts
//   (프로젝트 루트에서 실행)
//
// 사전 조건:
//   - 서버(:3001), Firebase 에뮬레이터(:9099, :9000), PostgreSQL 모두 실행 중

import * as fs from 'fs';
import * as path from 'path';

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
  httpRequest,
} from './utils/test-client';

// ─── 날짜 헬퍼 ────────────────────────────────────────────────────────────────

function dateAfterDays(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().split('T')[0];
}

function birthDateForAge(age: number): string {
  const d = new Date();
  d.setFullYear(d.getFullYear() - age);
  d.setMonth(d.getMonth() - 1); // 안전 마진: 1달 전 생일
  return d.toISOString().split('T')[0];
}

// ─── Phase 7 메인 ─────────────────────────────────────────────────────────────

async function runPhase7(): Promise<PhaseResult> {
  const phaseName = 'Phase 7: 온보딩 UX 시나리오 (DOC-T3-ONB-014)';
  const checks: CheckResult[] = [];
  const pool = createPool();

  let captainIdToken = '';
  let captainUserId = '';
  let crew1IdToken = '';
  let crew1UserId = '';
  let tripId = '';
  let groupId = '';
  let travelerCode = '';

  try {
    // ── Firebase 에뮬레이터 초기화 ──────────────────────────────────────────
    console.log('\n[사전 준비] Firebase Auth 에뮬레이터 계정 초기화...');
    try {
      await httpRequest(
        'DELETE',
        `${CONFIG.firebaseAuthUrl}/emulator/v1/projects/${CONFIG.firebaseProject}/accounts`,
        undefined,
        { Authorization: 'Bearer owner' },
      );
      console.log('  -> 에뮬레이터 계정 초기화 완료');
    } catch (e: any) {
      console.warn(`  -> 초기화 실패 (계속 진행): ${e.message}`);
    }

    // DB cleanup: 테스트 전화번호 관련 데이터 정리
    console.log('[사전 준비] DB 테스트 데이터 정리...');
    const testPhones = Object.values(TEST_PHONES);
    for (const phone of testPhones) {
      await dbQuery(pool, `DELETE FROM tb_user_consent WHERE user_id IN (SELECT user_id FROM tb_user WHERE phone_number = $1)`, [phone]);
      await dbQuery(pool, `DELETE FROM tb_parental_consent WHERE user_id IN (SELECT user_id FROM tb_user WHERE phone_number = $1)`, [phone]);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 1: 시나리오 A — Captain Firebase 인증
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[1/14] 시나리오 A: Captain Firebase 인증...');
    try {
      const { idToken, localId } = await Firebase.getIdToken(TEST_PHONES.captain);
      captainIdToken = idToken;

      const res = await apiPost('/api/v1/auth/firebase-verify', {
        id_token: captainIdToken,
        phone_country_code: '+82',
        is_test_device: true,
        test_phone_number: TEST_PHONES.captain,
      });

      const ok = (res.status === 200 || res.status === 201) && !!res.data?.data?.user_id;
      captainUserId = res.data?.data?.user_id || '';

      checks.push({
        label: '시나리오 A: Captain 인증 + 사용자 생성',
        passed: ok,
        detail: `status=${res.status}, user_id=${captainUserId}, is_new=${res.data?.data?.is_new_user}`,
      });
      console.log(`  -> ${ok ? 'PASS' : 'FAIL'} user_id=${captainUserId}`);
    } catch (e: any) {
      checks.push({ label: '시나리오 A: Captain 인증 + 사용자 생성', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 2: 시나리오 A — 약관 동의 기록 (§8)
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[2/14] 시나리오 A: 약관 동의 기록 (4종 필수 + 1종 선택)...');
    let consentPassed = false;
    try {
      const consentItems = [
        { consentType: 'terms_of_service', consentVersion: '2026-03-01', isGranted: true },
        { consentType: 'privacy_policy', consentVersion: '2026-03-01', isGranted: true },
        { consentType: 'lbs_terms', consentVersion: '2026-03-01', isGranted: true },
        { consentType: 'marketing', consentVersion: '2026-03-01', isGranted: false },
      ];

      let allOk = true;
      for (const item of consentItems) {
        const res = await apiPost('/api/v1/auth/consent', item, captainIdToken);
        if (res.status !== 200 && res.status !== 201) {
          allOk = false;
          console.error(`  -> FAIL consent ${item.consentType}: status=${res.status}`);
        }
      }

      consentPassed = allOk;
      checks.push({
        label: '시나리오 A: 약관 동의 기록 (4종)',
        passed: consentPassed,
        detail: consentPassed ? '4종 모두 200/201' : '일부 실패',
      });
      console.log(`  -> ${consentPassed ? 'PASS' : 'FAIL'}`);
    } catch (e: any) {
      checks.push({ label: '시나리오 A: 약관 동의 기록 (4종)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 3: 약관 동의 DB 저장 확인
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[3/14] 약관 동의 DB 저장 확인...');
    try {
      const rows = await dbQuery(
        pool,
        `SELECT consent_type, is_agreed, agreed_at, consent_version
         FROM tb_user_consent
         WHERE user_id = $1
         ORDER BY consent_type`,
        [captainUserId],
      );

      const hasRequired = rows.filter(
        (r: any) => r.is_agreed === true && ['terms_of_service', 'privacy_policy', 'lbs_terms'].includes(r.consent_type)
      ).length === 3;

      const hasMarketing = rows.some(
        (r: any) => r.consent_type === 'marketing' && r.is_agreed === false
      );

      const passed = hasRequired && hasMarketing;
      checks.push({
        label: '약관 동의 DB 저장 확인 (§8.2)',
        passed,
        detail: `총 ${rows.length}건, 필수3=${hasRequired}, 마케팅거부=${hasMarketing}`,
      });
      console.log(`  -> ${passed ? 'PASS' : 'FAIL'} rows=${rows.length}`);
    } catch (e: any) {
      checks.push({ label: '약관 동의 DB 저장 확인 (§8.2)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 4: 온보딩 완료 (displayName + dateOfBirth)
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[4/14] 시나리오 A: 온보딩 완료...');
    try {
      const res = await apiPost('/api/v1/auth/register', {
        displayName: 'UAT캡틴',
        dateOfBirth: birthDateForAge(30),
      }, captainIdToken);

      const ok = res.status === 200 || res.status === 201;
      checks.push({
        label: '시나리오 A: 온보딩 완료 (register)',
        passed: ok,
        detail: `status=${res.status}`,
      });
      console.log(`  -> ${ok ? 'PASS' : 'FAIL'} status=${res.status}`);
    } catch (e: any) {
      checks.push({ label: '시나리오 A: 온보딩 완료 (register)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 5: 성인 minorStatus = 'adult'
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[5/14] minorStatus = adult 확인...');
    try {
      const rows = await dbQuery(
        pool,
        `SELECT minor_status, is_onboarding_complete, onboarding_step, minor_status_updated_at
         FROM tb_user WHERE user_id = $1`,
        [captainUserId],
      );

      const isAdult = rows.length > 0 && rows[0].minor_status === 'adult';
      const isComplete = rows.length > 0 && rows[0].is_onboarding_complete === true;
      const passed = isAdult && isComplete;

      checks.push({
        label: '성인 minorStatus = adult, 온보딩 완료',
        passed,
        detail: `minor_status=${rows[0]?.minor_status}, onboarding_complete=${rows[0]?.is_onboarding_complete}, step=${rows[0]?.onboarding_step}`,
      });
      console.log(`  -> ${passed ? 'PASS' : 'FAIL'} minor_status=${rows[0]?.minor_status}`);
    } catch (e: any) {
      checks.push({ label: '성인 minorStatus = adult, 온보딩 완료', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 6: 여행 생성 (15일 이내)
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[6/14] 여행 생성 (15일 이내, §11)...');
    try {
      const res = await apiPost('/api/v1/trips', {
        title: 'UAT 온보딩 여행',
        country_code: 'JP',
        country_name: '일본',
        destination_city: '도쿄',
        trip_type: 'leisure',
        start_date: dateAfterDays(1),
        end_date: dateAfterDays(10),
      }, captainIdToken);

      const ok = (res.status === 200 || res.status === 201) && !!res.data?.data?.trip_id;
      tripId = res.data?.data?.trip_id || '';
      groupId = res.data?.data?.group_id || '';

      checks.push({
        label: '여행 생성 (10일, 15일 이내)',
        passed: ok,
        detail: `status=${res.status}, trip_id=${tripId}`,
      });
      console.log(`  -> ${ok ? 'PASS' : 'FAIL'} trip_id=${tripId}`);
    } catch (e: any) {
      checks.push({ label: '여행 생성 (10일, 15일 이내)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 7: 15일 초과 여행 생성 차단 (§11)
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[7/14] 15일 초과 여행 생성 차단...');
    try {
      const res = await apiPost('/api/v1/trips', {
        title: '초과 여행',
        country_code: 'JP',
        country_name: '일본',
        destination_city: '오사카',
        trip_type: 'leisure',
        start_date: dateAfterDays(20),
        end_date: dateAfterDays(40), // 20일
      }, captainIdToken);

      const blocked = res.status === 400;
      checks.push({
        label: '15일 초과 여행 생성 차단 (§11)',
        passed: blocked,
        detail: `status=${res.status} (기대: 400)`,
      });
      console.log(`  -> ${blocked ? 'PASS' : 'FAIL'} status=${res.status}`);
    } catch (e: any) {
      checks.push({ label: '15일 초과 여행 생성 차단 (§11)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 8: 시나리오 B — 초대코드 생성 + Crew 참여
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[8/14] 시나리오 B: 초대코드 Crew 참여...');
    try {
      // 8a. 초대코드 생성
      if (!groupId) throw new Error('여행 미생성으로 건너뜀');

      const codeRes = await apiPost(`/api/v1/groups/${groupId}/invite-codes`, {
        target_role: 'crew',
        max_uses: 10,
        expires_in_days: 7,
      }, captainIdToken);

      travelerCode = codeRes.data?.data?.code || '';
      if (!travelerCode) throw new Error('초대코드 생성 실패');

      // 8b. Crew 인증
      const { idToken: c1Token } = await Firebase.getIdToken(TEST_PHONES.crew1);
      crew1IdToken = c1Token;

      const verifyRes = await apiPost('/api/v1/auth/firebase-verify', {
        id_token: crew1IdToken,
        phone_country_code: '+82',
        is_test_device: true,
        test_phone_number: TEST_PHONES.crew1,
      });
      crew1UserId = verifyRes.data?.data?.user_id || '';

      // 8c. 초대코드 사용
      const joinRes = await apiPost(`/api/v1/groups/join-by-code/${travelerCode}`, {}, crew1IdToken);
      const joinOk = joinRes.status === 200 || joinRes.status === 201;

      // 8d. DB 확인: member_role = 'crew'
      const memberRows = await dbQuery(
        pool,
        `SELECT member_role, trip_id FROM tb_group_member
         WHERE group_id = $1 AND user_id = $2`,
        [groupId, crew1UserId],
      );

      const isCrew = memberRows.length > 0 && memberRows[0].member_role === 'crew';
      const passed = joinOk && isCrew;

      checks.push({
        label: '시나리오 B: 초대코드 Crew 참여 (§4)',
        passed,
        detail: `join_status=${joinRes.status}, member_role=${memberRows[0]?.member_role}, code=${travelerCode}`,
      });
      console.log(`  -> ${passed ? 'PASS' : 'FAIL'} role=${memberRows[0]?.member_role}`);
    } catch (e: any) {
      checks.push({ label: '시나리오 B: 초대코드 Crew 참여 (§4)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 9: 시나리오 B — 초대코드 미리보기 (validate)
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[9/14] 시나리오 B: 초대코드 미리보기...');
    try {
      if (!travelerCode) throw new Error('초대코드 없음');

      // 새 초대코드 생성 (기존 코드는 이미 사용됨)
      const newCodeRes = await apiPost(`/api/v1/groups/${groupId}/invite-codes`, {
        target_role: 'crew',
        max_uses: 10,
        expires_in_days: 7,
      }, captainIdToken);
      const previewCode = newCodeRes.data?.data?.code || '';

      const previewRes = await apiGet(`/api/v1/groups/preview-by-code/${previewCode}`, captainIdToken);
      const hasInfo = previewRes.status === 200 && !!previewRes.data?.data;

      checks.push({
        label: '시나리오 B: 초대코드 미리보기 (B-8)',
        passed: hasInfo,
        detail: `status=${previewRes.status}, has_data=${!!previewRes.data?.data}`,
      });
      console.log(`  -> ${hasInfo ? 'PASS' : 'FAIL'} status=${previewRes.status}`);
    } catch (e: any) {
      checks.push({ label: '시나리오 B: 초대코드 미리보기 (B-8)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 10: 시나리오 C — 가디언 초대 + 수락
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[10/14] 시나리오 C: 가디언 초대 + 수락...');
    try {
      if (!tripId) throw new Error('여행 미생성으로 건너뜀');

      // 10a. 가디언 인증
      const { idToken: gToken } = await Firebase.getIdToken(TEST_PHONES.guardian);

      const gVerifyRes = await apiPost('/api/v1/auth/firebase-verify', {
        id_token: gToken,
        phone_country_code: '+82',
        is_test_device: true,
        test_phone_number: TEST_PHONES.guardian,
      });
      const guardianUserId = gVerifyRes.data?.data?.user_id || '';

      // 10b. 가디언 링크 생성 (캡틴이 초대)
      const linkRes = await apiPost(`/api/v1/trips/${tripId}/guardians`, {
        guardian_phone: TEST_PHONES.guardian,
      }, captainIdToken);
      const linkId = linkRes.data?.data?.link_id;

      if (!linkId) throw new Error(`가디언 링크 생성 실패: ${JSON.stringify(linkRes.data)}`);

      // 10c. 가디언이 수락
      const acceptRes = await apiPatch(
        `/api/v1/trips/${tripId}/guardians/${linkId}/respond`,
        { action: 'accepted' },
        gToken,
      );

      const acceptOk = acceptRes.status === 200 || acceptRes.status === 201;

      checks.push({
        label: '시나리오 C: 가디언 초대 + 수락 (§5)',
        passed: acceptOk,
        detail: `link_id=${linkId}, accept_status=${acceptRes.status}`,
      });
      console.log(`  -> ${acceptOk ? 'PASS' : 'FAIL'} link_id=${linkId}`);
    } catch (e: any) {
      checks.push({ label: '시나리오 C: 가디언 초대 + 수락 (§5)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 11: 시나리오 D — 복귀 사용자 재인증
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[11/14] 시나리오 D: 복귀 사용자 재인증...');
    try {
      // Captain을 다시 인증 (이미 온보딩 완료된 사용자)
      const { idToken: reToken } = await Firebase.getIdToken(TEST_PHONES.captain);

      const reRes = await apiPost('/api/v1/auth/firebase-verify', {
        id_token: reToken,
        phone_country_code: '+82',
        is_test_device: true,
        test_phone_number: TEST_PHONES.captain,
      });

      const ok = reRes.status === 200 && reRes.data?.data?.is_new_user === false;
      const sameUser = reRes.data?.data?.user_id === captainUserId;

      checks.push({
        label: '시나리오 D: 복귀 사용자 재인증 (§6)',
        passed: ok && sameUser,
        detail: `is_new_user=${reRes.data?.data?.is_new_user}, same_user=${sameUser}`,
      });
      console.log(`  -> ${ok && sameUser ? 'PASS' : 'FAIL'} is_new_user=${reRes.data?.data?.is_new_user}`);

      captainIdToken = reToken; // 토큰 갱신
    } catch (e: any) {
      checks.push({ label: '시나리오 D: 복귀 사용자 재인증 (§6)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 12: 미성년자(14~17세) 온보딩 → minor_over14
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[12/14] 미성년자(16세) 온보딩 → minor_over14...');
    try {
      // crew2를 미성년자로 등록
      const { idToken: minorToken } = await Firebase.getIdToken(TEST_PHONES.crew2);

      const verifyRes = await apiPost('/api/v1/auth/firebase-verify', {
        id_token: minorToken,
        phone_country_code: '+82',
        is_test_device: true,
        test_phone_number: TEST_PHONES.crew2,
      });
      const minorUserId = verifyRes.data?.data?.user_id || '';

      // 16세 생년월일로 온보딩 완료
      const regRes = await apiPost('/api/v1/auth/register', {
        displayName: 'UAT미성년자',
        dateOfBirth: birthDateForAge(16),
      }, minorToken);

      const regOk = regRes.status === 200 || regRes.status === 201;

      // DB 확인
      const rows = await dbQuery(
        pool,
        `SELECT minor_status, minor_status_updated_at FROM tb_user WHERE user_id = $1`,
        [minorUserId],
      );

      const isMinorOver14 = rows.length > 0 && rows[0].minor_status === 'minor_over14';
      const hasUpdatedAt = rows.length > 0 && rows[0].minor_status_updated_at !== null;

      checks.push({
        label: '미성년자(16세) → minor_over14 (§12)',
        passed: regOk && isMinorOver14 && hasUpdatedAt,
        detail: `register=${regRes.status}, minor_status=${rows[0]?.minor_status}, updated_at=${rows[0]?.minor_status_updated_at ? 'SET' : 'NULL'}`,
      });
      console.log(`  -> ${isMinorOver14 ? 'PASS' : 'FAIL'} minor_status=${rows[0]?.minor_status}`);
    } catch (e: any) {
      checks.push({ label: '미성년자(16세) → minor_over14 (§12)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 13: 미성년자(14세 미만) → 법정대리인 동의 필수
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[13/14] 미성년자(12세) → 법정대리인 동의 필수 (§12)...');
    try {
      // crewChief를 14세 미만으로 등록 시도
      const { idToken: childToken } = await Firebase.getIdToken(TEST_PHONES.crewChief);

      const verifyRes = await apiPost('/api/v1/auth/firebase-verify', {
        id_token: childToken,
        phone_country_code: '+82',
        is_test_device: true,
        test_phone_number: TEST_PHONES.crewChief,
      });
      const childUserId = verifyRes.data?.data?.user_id || '';

      // 12세 생년월일로 온보딩 시도 → 법정대리인 동의 없이 거부되어야 함
      const regRes = await apiPost('/api/v1/auth/register', {
        displayName: 'UAT아동',
        dateOfBirth: birthDateForAge(12),
      }, childToken);

      const blocked = regRes.status === 400;

      checks.push({
        label: '미성년자(12세) 법정대리인 동의 없이 차단 (§12)',
        passed: blocked,
        detail: `status=${regRes.status} (기대: 400)`,
      });
      console.log(`  -> ${blocked ? 'PASS' : 'FAIL'} status=${regRes.status}`);
    } catch (e: any) {
      checks.push({ label: '미성년자(12세) 법정대리인 동의 없이 차단 (§12)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    // ════════════════════════════════════════════════════════════════════════
    // CHECK 14: 약관 동의 철회 기능
    // ════════════════════════════════════════════════════════════════════════
    console.log('\n[14/14] 약관 동의 철회 (marketing → false)...');
    try {
      // 마케팅 동의를 true로 변경
      await apiPost('/api/v1/auth/consent', {
        consentType: 'marketing',
        consentVersion: '2026-03-01',
        isGranted: true,
      }, captainIdToken);

      // 마케팅 동의 철회
      const withdrawRes = await apiPost('/api/v1/auth/consent', {
        consentType: 'marketing',
        consentVersion: '2026-03-01',
        isGranted: false,
      }, captainIdToken);

      const withdrawOk = withdrawRes.status === 200 || withdrawRes.status === 201;

      // DB 확인: withdrawn_at NOT NULL
      const rows = await dbQuery(
        pool,
        `SELECT is_agreed, withdrawn_at FROM tb_user_consent
         WHERE user_id = $1 AND consent_type = 'marketing'`,
        [captainUserId],
      );

      const hasWithdrawn = rows.length > 0 && rows[0].is_agreed === false && rows[0].withdrawn_at !== null;

      checks.push({
        label: '약관 동의 철회 (withdrawn_at 기록)',
        passed: withdrawOk && hasWithdrawn,
        detail: `api=${withdrawRes.status}, is_agreed=${rows[0]?.is_agreed}, withdrawn_at=${rows[0]?.withdrawn_at ? 'SET' : 'NULL'}`,
      });
      console.log(`  -> ${hasWithdrawn ? 'PASS' : 'FAIL'} withdrawn_at=${rows[0]?.withdrawn_at ? 'SET' : 'NULL'}`);
    } catch (e: any) {
      checks.push({ label: '약관 동의 철회 (withdrawn_at 기록)', passed: false, detail: e.message });
      console.error(`  -> FAIL ${e.message}`);
    }

    return { phase: phaseName, passed: checks.every((c) => c.passed), checks };
  } catch (error: any) {
    return { phase: phaseName, passed: false, checks, error: error.message };
  } finally {
    await pool.end();
  }
}

// ─── 결과 출력 ────────────────────────────────────────────────────────────────

function printPhaseResult(result: PhaseResult): void {
  const SEP = '='.repeat(70);
  console.log('\n' + SEP);
  console.log(`  SafeTrip UAT — ${result.phase}`);
  console.log(SEP);

  let passCount = 0;
  let failCount = 0;

  for (const c of result.checks) {
    const icon = c.passed ? '✓' : '✗';
    console.log(`  ${icon} ${c.label}`);
    if (c.detail) console.log(`      ${c.detail}`);
    c.passed ? passCount++ : failCount++;
  }

  console.log(SEP);
  const allOk = failCount === 0;
  console.log(`  결과: ${passCount}/${passCount + failCount} 통과 — ${allOk ? 'ALL PASS' : `${failCount}건 FAIL`}`);
  if (result.error) console.log(`  ERROR: ${result.error}`);
  console.log(SEP + '\n');
}

// ─── 진입점 ────────────────────────────────────────────────────────────────────

(async () => {
  console.log('SafeTrip UAT Phase 7: 온보딩 UX 시나리오 검증 시작');
  console.log(`DOC-T3-ONB-014 v3.1 기준`);
  console.log(`서버: ${CONFIG.serverUrl}`);
  console.log(`Firebase Auth: ${CONFIG.firebaseAuthUrl}`);

  const result = await runPhase7();
  printPhaseResult(result);

  if (!result.passed) {
    console.error('일부 체크 실패 — 서버 로그 확인:');
    console.error('  tail -20 /tmp/safetrip-backend.log');
    process.exit(1);
  }
})();
