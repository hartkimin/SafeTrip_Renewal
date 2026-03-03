# SafeTrip 온보딩 전면 고도화 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 현재 11단계 온보딩을 5~6단계로 줄이고, 서사형 역할 선택 + Progressive 프로파일 방식으로 전환하여 UX/전환율을 개선한다.

**Architecture:** 백엔드 DB에 약관 동의 이력 및 온보딩 단계 컬럼을 추가하고, Flutter에서 기존 인트로·시작·전화·OTP·약관 화면 5개를 역할선택·전화인증 2개로 통합하며, 역할(captain/crew/guardian) 기반 새 진입 모델(`OnboardingRole`)을 도입한다.

**Tech Stack:** Flutter (go_router, firebase_auth, shared_preferences), Node.js/TypeScript (Express, PostgreSQL), Firebase Phone Auth

---

## Task 1: DB 마이그레이션 — tb_user에 약관·온보딩 컬럼 추가

**Files:**
- Create: `safetrip-server-api/migrations/20260227_add_onboarding_columns.sql`

**Step 1: 마이그레이션 SQL 파일 생성**

```sql
-- safetrip-server-api/migrations/20260227_add_onboarding_columns.sql
ALTER TABLE tb_user
  ADD COLUMN IF NOT EXISTS terms_agreed_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS terms_version VARCHAR(10) DEFAULT '1.0',
  ADD COLUMN IF NOT EXISTS onboarding_step VARCHAR(20) DEFAULT 'complete';

COMMENT ON COLUMN tb_user.terms_agreed_at IS '약관 동의 시각';
COMMENT ON COLUMN tb_user.terms_version IS '동의한 약관 버전 (예: 1.0)';
COMMENT ON COLUMN tb_user.onboarding_step IS '온보딩 완료 상태: complete | profile_pending | trip_pending';
```

**Step 2: 마이그레이션 적용**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
psql -U postgres -d safetrip -f migrations/20260227_add_onboarding_columns.sql
```

Expected output:
```
ALTER TABLE
COMMENT
COMMENT
COMMENT
```

**Step 3: 기존 유저 데이터 기본값 확인**

```bash
psql -U postgres -d safetrip -c "SELECT COUNT(*) FROM tb_user WHERE onboarding_step IS NOT NULL;"
```

Expected: 기존 레코드 모두 `complete` 기본값 적용됨 확인.

**Step 4: 커밋**

```bash
cd /mnt/d/Project/15_SafeTrip_New
git add safetrip-server-api/migrations/20260227_add_onboarding_columns.sql
git commit -m "feat(db): add terms_agreed_at, terms_version, onboarding_step to tb_user"
```

---

## Task 2: 백엔드 — 여행 미리보기 API (인증 불필요)

**Files:**
- Modify: `safetrip-server-api/src/routes/trips.routes.ts` — 신규 라우트 추가
- Modify: `safetrip-server-api/src/controllers/trips.controller.ts` — handler 추가
- Modify: `safetrip-server-api/src/services/trips.service.ts` — service 메서드 추가

**Step 1: trips.service.ts에 `getTripPreviewByCode` 메서드 추가**

`safetrip-server-api/src/services/trips.service.ts` 의 기존 메서드 목록 맨 끝에 추가:

```typescript
// 인증 없이 초대 코드로 여행 미리보기 반환
async getTripPreviewByCode(inviteCode: string): Promise<{
  trip_id: string;
  trip_name: string;
  country_name: string;
  start_date: string;
  end_date: string;
  captain_name: string;
  member_count: number;
  role: 'crew_chief' | 'crew' | 'guardian';
} | null> {
  // 코드 prefix로 역할 결정: A→crew_chief, V→guardian, M→crew
  let role: 'crew_chief' | 'crew' | 'guardian';
  const prefix = inviteCode.charAt(0).toUpperCase();
  if (prefix === 'A') role = 'crew_chief';
  else if (prefix === 'V') role = 'guardian';
  else role = 'crew';

  const result = await this.db.query<any>(`
    SELECT
      t.trip_id,
      t.trip_name,
      t.country_name,
      t.start_date::date::text  AS start_date,
      t.end_date::date::text    AS end_date,
      u.display_name            AS captain_name,
      COUNT(gm.user_id)         AS member_count
    FROM tb_trip t
    JOIN tb_group g   ON g.trip_id = t.trip_id
    JOIN tb_group_member gm_cap ON gm_cap.group_id = g.group_id
                                AND gm_cap.member_role = 'captain'
    JOIN tb_user u    ON u.user_id = gm_cap.user_id
    LEFT JOIN tb_group_member gm ON gm.group_id = g.group_id
    WHERE (t.invite_code_crew_chief = $1
        OR t.invite_code_crew      = $1
        OR t.invite_code_guardian  = $1)
      AND t.status = 'active'
    GROUP BY t.trip_id, t.trip_name, t.country_name,
             t.start_date, t.end_date, u.display_name
    LIMIT 1
  `, [inviteCode]);

  if (result.rows.length === 0) return null;
  const row = result.rows[0];
  return {
    trip_id:      row.trip_id,
    trip_name:    row.trip_name,
    country_name: row.country_name ?? '',
    start_date:   row.start_date,
    end_date:     row.end_date,
    captain_name: row.captain_name ?? '',
    member_count: parseInt(row.member_count, 10),
    role,
  };
}
```

> **주의**: 실제 컬럼명(invite_code_crew_chief 등)은 현재 DB 스키마와 맞춰야 합니다. 다를 경우 `\d tb_trip;` 으로 확인 후 수정.

**Step 2: trips.controller.ts에 `getTripPreview` handler 추가**

```typescript
async getTripPreview(req: Request, res: Response): Promise<void> {
  const { code } = req.params;
  if (!code || code.length < 6) {
    res.status(400).json({ error: 'Invalid invite code' });
    return;
  }
  const preview = await this.tripsService.getTripPreviewByCode(code);
  if (!preview) {
    res.status(404).json({ error: 'Trip not found or invalid code' });
    return;
  }
  res.json(preview);
}
```

**Step 3: trips.routes.ts에 라우트 추가 (인증 미들웨어 제외)**

```typescript
// 인증 없이 접근 가능한 미리보기 라우트 — authenticate 미들웨어 없음
router.get('/preview/:code', (req, res) => controller.getTripPreview(req, res));
```

기존 라우트들보다 위에 배치해야 `:tripId` 패턴과 충돌하지 않음.

**Step 4: 수동 테스트**

```bash
# 서버 실행 중인 경우
curl http://localhost:3001/api/v1/trips/preview/MXXXXXXX
# 예상: 404 (코드 없을 때) 또는 여행 정보 JSON
```

**Step 5: 커밋**

```bash
git add safetrip-server-api/src/services/trips.service.ts \
        safetrip-server-api/src/controllers/trips.controller.ts \
        safetrip-server-api/src/routes/trips.routes.ts
git commit -m "feat(api): GET /trips/preview/:code — unauthenticated trip preview"
```

---

## Task 3: 백엔드 — 약관 동의 저장 API

**Files:**
- Modify: `safetrip-server-api/src/services/users.service.ts`
- Modify: `safetrip-server-api/src/controllers/users.controller.ts`
- Modify: `safetrip-server-api/src/routes/users.routes.ts`

**Step 1: users.service.ts에 `saveTermsAgreement` 추가**

```typescript
async saveTermsAgreement(userId: string, termsVersion: string): Promise<{ terms_agreed_at: string }> {
  const now = new Date().toISOString();
  await this.db.query(
    `UPDATE tb_user
     SET terms_agreed_at = $1, terms_version = $2
     WHERE user_id = $3`,
    [now, termsVersion, userId]
  );
  return { terms_agreed_at: now };
}
```

**Step 2: users.controller.ts에 `patchTerms` handler 추가**

```typescript
async patchTerms(req: Request, res: Response): Promise<void> {
  const { id } = req.params;
  const { terms_version } = req.body;
  if (!terms_version) {
    res.status(400).json({ error: 'terms_version is required' });
    return;
  }
  const result = await this.usersService.saveTermsAgreement(id, terms_version);
  res.json(result);
}
```

**Step 3: users.routes.ts에 라우트 추가 (authenticate 포함)**

```typescript
router.patch('/:id/terms', authenticate, (req, res) => controller.patchTerms(req, res));
```

**Step 4: 수동 테스트**

```bash
curl -X PATCH http://localhost:3001/api/v1/users/TEST_USER_ID/terms \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"terms_version":"1.0"}'
# 예상: {"terms_agreed_at": "2026-02-27T..."}
```

**Step 5: 커밋**

```bash
git add safetrip-server-api/src/services/users.service.ts \
        safetrip-server-api/src/controllers/users.controller.ts \
        safetrip-server-api/src/routes/users.routes.ts
git commit -m "feat(api): PATCH /users/:id/terms — save terms agreement"
```

---

## Task 4: Flutter — OnboardingRole 모델 + RoutePaths 업데이트

**Files:**
- Create: `safetrip-mobile/lib/models/onboarding/onboarding_role.dart`
- Modify: `safetrip-mobile/lib/router/route_paths.dart`

**Step 1: OnboardingRole enum 생성**

```dart
// safetrip-mobile/lib/models/onboarding/onboarding_role.dart
enum OnboardingRole {
  captain,   // 캡틴 — 여행 생성자
  crew,      // 크루 — 일반 멤버
  guardian,  // 가디언 — 안전 모니터
}
```

> 기존 `OnboardingEntry` enum은 **유지**한다. 일부 기존 화면(screen_trip_confirm 등)이 아직 사용 중.

**Step 2: RoutePaths 업데이트**

기존 `route_paths.dart`를 아래로 교체:

```dart
class RoutePaths {
  // --- 유지 (splash, main, permission, trip*) ---
  static const splash       = '/';
  static const main         = '/main';
  static const permission   = '/permission';
  static const tripCreate   = '/trip/create';
  static const tripJoin     = '/trip/join';
  static const tripConfirm  = '/trip/confirm';

  // --- 신규 온보딩 경로 ---
  static const roleSelect   = '/onboarding/role';    // 역할 선택 (신규)
  static const authPhone    = '/auth/phone-auth';    // 전화+OTP 통합 (신규)
  static const captainSetup = '/auth/captain-setup'; // 캡틴 셋업 (신규)
  static const crewSetup    = '/auth/crew-setup';    // 크루/가디언 셋업 (신규)
  static const tripPreview  = '/trip/preview';       // 여행 미리보기 (딥링크용)

  // --- Deprecated (레거시 코드 참조용 — 삭제 전까지 유지) ---
  static const onboarding     = '/onboarding';       // 삭제 예정
  static const onboardingMain = '/onboarding/main';  // 삭제 예정
  static const authVerify     = '/auth/verify';      // 삭제 예정
  static const authTerms      = '/auth/terms';       // 삭제 예정
  static const authProfile    = '/auth/profile';     // 삭제 예정
}
```

**Step 3: 빌드 확인 (컴파일 에러 없는지)**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/models/onboarding/onboarding_role.dart lib/router/route_paths.dart
```

Expected: `No issues found!`

**Step 4: 커밋**

```bash
git add safetrip-mobile/lib/models/onboarding/onboarding_role.dart \
        safetrip-mobile/lib/router/route_paths.dart
git commit -m "feat(flutter): add OnboardingRole enum and update RoutePaths"
```

---

## Task 5: Flutter — screen_role_select.dart (서사형 역할 선택)

**Files:**
- Create: `safetrip-mobile/lib/screens/onboarding/screen_role_select.dart`

**Step 1: 화면 구현**

```dart
// safetrip-mobile/lib/screens/onboarding/screen_role_select.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../models/onboarding/onboarding_role.dart';
import '../../router/route_paths.dart';
import '../../constants/app_tokens.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  VideoPlayerController? _videoController;
  OnboardingRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.asset('assets/video/bg.mp4')
      ..initialize().then((_) {
        _videoController!.setLooping(true);
        _videoController!.setVolume(0);
        _videoController!.setPlaybackSpeed(1.2);
        _videoController!.play();
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _onRoleSelected(OnboardingRole role) {
    setState(() => _selectedRole = role);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      context.push(RoutePaths.authPhone, extra: {'role': role.name});
    });
  }

  void _showInviteCodeSheet() {
    final codeController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('초대 코드 입력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: codeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: '코드 7자리 입력 (예: AXXXXXXX)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final code = codeController.text.trim().toUpperCase();
                    if (code.length < 6) return;
                    Navigator.pop(context);
                    // 코드 미리보기 화면으로 이동
                    context.push(RoutePaths.tripPreview, extra: {'code': code});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('확인', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 비디오
          if (_videoController != null && _videoController!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          // 어두운 오버레이
          Container(color: Colors.black.withOpacity(0.55)),
          // 콘텐츠
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  const Text(
                    '이번 여행에서\n나는?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SafeTrip에서의 역할을 선택하세요',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  // 역할 카드 3개
                  _RoleCard(
                    icon: '🏔',
                    title: '캡틴',
                    subtitle: '여행을 만들고 팀을 이끄는 사람',
                    details: '일정 생성 · 멤버 초대 · SOS 수신',
                    selected: _selectedRole == OnboardingRole.captain,
                    onTap: () => _onRoleSelected(OnboardingRole.captain),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    icon: '🎒',
                    title: '크루',
                    subtitle: '여행에 함께하는 사람',
                    details: '위치 공유 · SOS 발신 · 일정 확인',
                    selected: _selectedRole == OnboardingRole.crew,
                    onTap: () => _onRoleSelected(OnboardingRole.crew),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    icon: '🛡',
                    title: '가디언',
                    subtitle: '집에서 안전을 지켜보는 사람',
                    details: '위치 모니터링 · 알림 수신',
                    selected: _selectedRole == OnboardingRole.guardian,
                    onTap: () => _onRoleSelected(OnboardingRole.guardian),
                  ),
                  const Spacer(flex: 1),
                  // 초대 코드 링크
                  Center(
                    child: GestureDetector(
                      onTap: _showInviteCodeSheet,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '초대 코드가 있어요 →',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String details;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withOpacity(0.95)
            : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTokens.primaryColor : Colors.white.withOpacity(0.2),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? Colors.black87 : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: selected ? Colors.black54 : Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(
                        color: selected ? AppTokens.primaryColor : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppTokens.primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
```

> **주의**: `AppTokens.primaryColor`가 실제 앱 컬러 상수인지 확인. 다르면 실제 클래스명으로 교체.

**Step 2: 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/screens/onboarding/screen_role_select.dart
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/screens/onboarding/screen_role_select.dart
git commit -m "feat(flutter): add RoleSelectScreen — narrative role selection"
```

---

## Task 6: Flutter — screen_phone_auth.dart (전화+OTP 통합)

**Files:**
- Create: `safetrip-mobile/lib/screens/auth/screen_phone_auth.dart`

**Step 1: 화면 구현**

이 화면은 기존 `screen_6_phone.dart`의 전화번호 입력 로직과 `screen_7_verify.dart`의 OTP 인증 로직을 하나의 화면에서 처리한다. 두 단계는 `_PhoneAuthStep` enum으로 구분한다.

```dart
// safetrip-mobile/lib/screens/auth/screen_phone_auth.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../constants/app_tokens.dart';
import '../../constants/test_auth_config.dart';
import '../../models/onboarding/onboarding_role.dart';
import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';
import '../../services/api_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../utils/phone_parser.dart';
import '../../utils/phone_util.dart';

enum _PhoneAuthStep { enterPhone, enterOtp }

class PhoneAuthScreen extends StatefulWidget {
  final OnboardingRole role;
  final AuthNotifier authNotifier;

  const PhoneAuthScreen({
    super.key,
    required this.role,
    required this.authNotifier,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  _PhoneAuthStep _step = _PhoneAuthStep.enterPhone;

  // 전화번호 단계
  final _phoneController = TextEditingController();
  final _phoneHasText = ValueNotifier<bool>(false);
  final String _countryCode = '+82';
  bool _isSending = false;

  // OTP 단계
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  final _otpHasText = ValueNotifier<bool>(false);
  bool _isVerifying = false;
  int _remainingSeconds = 180;
  Timer? _timer;
  bool _canResend = false;
  String? _verificationId;
  int? _resendToken;

  final _authService = FirebaseAuthService();
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
    _phoneController.addListener(() {
      _phoneHasText.value = _phoneController.text.isNotEmpty;
    });
    _otpController.addListener(() {
      _otpHasText.value = _otpController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneHasText.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _otpHasText.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('phone_number');
      if (stored != null && stored.startsWith('+82')) {
        final local = '0${stored.substring(3)}';
        if (PhoneParser.isValidKoreanPhoneNumber(local)) {
          _phoneController.text = local;
          return;
        }
      }
      final sim = await PhoneUtil.getPhoneNumber();
      if (sim != null && sim.isNotEmpty) {
        final parsed = PhoneParser.parsePhoneNumber(sim);
        final num = parsed['number'] ?? '';
        if (PhoneParser.isValidKoreanPhoneNumber(num)) {
          _phoneController.text = num;
        }
      }
    } catch (_) {}
  }

  // ── 전화번호 인증 요청 ──────────────────────────────────────
  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!PhoneParser.isValidKoreanPhoneNumber(phone)) {
      _showSnack('올바른 전화번호를 입력해주세요');
      return;
    }

    final e164 = '$_countryCode${phone.substring(1)}';
    setState(() => _isSending = true);

    // 테스트 전화번호 처리
    if (TestAuthConfig.isTestPhoneNumber(e164)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone_number', e164);
      setState(() {
        _isSending = false;
        _step = _PhoneAuthStep.enterOtp;
        _verificationId = 'TEST_VERIFICATION';
      });
      _startTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) => _otpFocusNode.requestFocus());
      return;
    }

    await _authService.verifyPhoneNumber(
      phoneNumber: e164,
      verificationCompleted: (credential) async {
        setState(() => _isSending = false);
        await _signInWithCredential(credential);
      },
      verificationFailed: (e) {
        setState(() => _isSending = false);
        _showSnack('인증 실패: ${e.message ?? '알 수 없는 오류'}');
      },
      codeSent: (verificationId, resendToken) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone_number', e164);
        setState(() {
          _isSending = false;
          _step = _PhoneAuthStep.enterOtp;
          _verificationId = verificationId;
          _resendToken = resendToken;
        });
        _startTimer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _otpFocusNode.requestFocus();
          if (_authService.isEmulatorMode) _autoFillEmulatorCode(verificationId);
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ── 에뮬레이터 자동 입력 ──────────────────────────────────
  Future<void> _autoFillEmulatorCode(String verificationId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      final code = await _authService.getEmulatorVerificationCode(verificationId);
      if (code != null && mounted) {
        _otpController.text = code;
        await _verifyCode(code);
      }
    } catch (_) {}
  }

  // ── OTP 인증 ──────────────────────────────────────────────
  Future<void> _verifyCode(String code) async {
    if (code.length != 6 || _verificationId == null) return;
    setState(() => _isVerifying = true);

    try {
      // 테스트 인증
      if (_verificationId == 'TEST_VERIFICATION') {
        final testCode = TestAuthConfig.getTestOtp(_phoneController.text.trim().replaceFirst('0', '+820'));
        if (code != testCode) {
          _showSnack('인증번호가 올바르지 않습니다');
          setState(() => _isVerifying = false);
          return;
        }
        final user = await FirebaseAuth.instance.signInAnonymously();
        await _onAuthSuccess(user.user!, isTestAuth: true);
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      if (mounted) {
        _showSnack('인증 실패: 코드를 확인해주세요');
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    await _onAuthSuccess(userCredential.user!);
  }

  Future<void> _onAuthSuccess(User firebaseUser, {bool isTestAuth = false}) async {
    final idToken = await firebaseUser.getIdToken();
    final phone = _phoneController.text.trim();
    final e164 = '$_countryCode${phone.substring(1)}';

    final syncResult = await _apiService.syncUserWithFirebase(
      idToken!,
      _countryCode,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', syncResult['user_id'] ?? '');
    await prefs.setString('user_name', syncResult['display_name'] ?? '');
    await prefs.setString('auth_verified_at', DateTime.now().toUtc().toIso8601String());
    if (isTestAuth) await prefs.setBool('is_test_device', true);

    final userId = syncResult['user_id'] as String? ?? '';
    final isNewUser = syncResult['is_new_user'] as bool? ?? true;

    // 약관 동의 저장 (인증 성공 시 자동 처리)
    if (userId.isNotEmpty) {
      try {
        await _apiService.saveTermsAgreement(userId, '1.0');
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isVerifying = false);

    // 역할별 다음 화면 결정
    _navigateNext(userId: userId, isNewUser: isNewUser);
  }

  void _navigateNext({required String userId, required bool isNewUser}) {
    final groupId = SharedPreferences.getInstance().then((p) => p.getString('group_id'));

    // 기존 유저이고 여행이 있으면 바로 메인
    groupId.then((gid) {
      if (!mounted) return;
      if (!isNewUser && gid != null && gid.isNotEmpty) {
        widget.authNotifier.setAuthenticated(hasTrip: true);
        context.go(RoutePaths.main);
        return;
      }

      switch (widget.role) {
        case OnboardingRole.captain:
          context.push(RoutePaths.captainSetup, extra: {'userId': userId});
        case OnboardingRole.crew:
        case OnboardingRole.guardian:
          context.push(RoutePaths.crewSetup, extra: {
            'userId': userId,
            'role': widget.role.name,
          });
      }
    });
  }

  // ── 타이머 ────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 180;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_remainingSeconds <= 0) {
        t.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String get _timerText {
    final m = _remainingSeconds ~/ 60;
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showTermsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            const Text('이용약관 상세', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...[
              '만 14세 이상 이용자만 가입할 수 있습니다.',
              '서비스 이용약관에 동의합니다.',
              '위치기반서비스 이용약관에 동의합니다.',
              '개인정보 수집·이용에 동의합니다.',
            ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _step == _PhoneAuthStep.enterOtp
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => setState(() {
                  _step = _PhoneAuthStep.enterPhone;
                  _timer?.cancel();
                }),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => context.pop(),
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _step == _PhoneAuthStep.enterPhone
              ? _buildPhoneStep()
              : _buildOtpStep(),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('전화번호로\n시작하기', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.3)),
        const SizedBox(height: 8),
        Text('인증 후 30일간 로그인 유지됩니다', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 32),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('+82', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '010-0000-0000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: ValueListenableBuilder(
                    valueListenable: _phoneHasText,
                    builder: (_, v, __) => v
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _phoneController.clear(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        // 인라인 약관 동의 텍스트
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text('계속하면 ', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              GestureDetector(
                onTap: _showTermsSheet,
                child: const Text(
                  '이용약관 및 개인정보처리방침',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text('에 동의하는 것입니다', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ValueListenableBuilder(
            valueListenable: _phoneHasText,
            builder: (_, hasText, __) => ElevatedButton(
              onPressed: (hasText && !_isSending) ? _sendCode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.primaryColor,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('인증 코드 받기', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('인증 코드\n입력', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.3)),
        const SizedBox(height: 8),
        Text('${_countryCode} ${_phoneController.text}로 전송된 6자리 코드를 입력하세요',
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 32),
        TextField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 12),
          decoration: InputDecoration(
            hintText: '• • • • • •',
            hintStyle: TextStyle(fontSize: 24, color: Colors.grey[300], letterSpacing: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (v) {
            if (v.length == 6) _verifyCode(v);
          },
        ),
        const SizedBox(height: 16),
        Center(
          child: _canResend
              ? TextButton(
                  onPressed: () {
                    setState(() => _step = _PhoneAuthStep.enterPhone);
                    Future.delayed(const Duration(milliseconds: 100), _sendCode);
                  },
                  child: const Text('인증번호 재발송'),
                )
              : Text(
                  '$_timerText 후 재발송 가능',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ValueListenableBuilder(
            valueListenable: _otpHasText,
            builder: (_, hasText, __) => ElevatedButton(
              onPressed: (hasText && !_isVerifying)
                  ? () => _verifyCode(_otpController.text)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.primaryColor,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isVerifying
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('확인', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
```

**Step 2: ApiService에 `saveTermsAgreement` 메서드 추가**

`safetrip-mobile/lib/services/api_service.dart`에 추가:

```dart
Future<Map<String, dynamic>> saveTermsAgreement(String userId, String termsVersion) async {
  final response = await _dio.patch(
    '/api/v1/users/$userId/terms',
    data: {'terms_version': termsVersion},
  );
  return response.data as Map<String, dynamic>;
}
```

**Step 3: 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/screens/auth/screen_phone_auth.dart
```

**Step 4: 커밋**

```bash
git add safetrip-mobile/lib/screens/auth/screen_phone_auth.dart \
        safetrip-mobile/lib/services/api_service.dart
git commit -m "feat(flutter): add PhoneAuthScreen — unified phone+OTP+terms"
```

---

## Task 7: Flutter — screen_captain_setup.dart

**Files:**
- Create: `safetrip-mobile/lib/screens/auth/screen_captain_setup.dart`

**Step 1: 화면 구현**

```dart
// safetrip-mobile/lib/screens/auth/screen_captain_setup.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_tokens.dart';
import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';
import '../../services/api_service.dart';

class CaptainSetupScreen extends StatefulWidget {
  final String userId;
  final AuthNotifier authNotifier;

  const CaptainSetupScreen({
    super.key,
    required this.userId,
    required this.authNotifier,
  });

  @override
  State<CaptainSetupScreen> createState() => _CaptainSetupScreenState();
}

class _CaptainSetupScreenState extends State<CaptainSetupScreen> {
  final _nameController = TextEditingController();
  final _tripNameController = TextEditingController();
  String? _selectedCountryCode;
  String? _selectedCountryName;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  final _apiService = ApiService();

  bool get _canProceed =>
      _nameController.text.trim().isNotEmpty &&
      _tripNameController.text.trim().isNotEmpty &&
      _selectedCountryCode != null &&
      _startDate != null &&
      _endDate != null;

  @override
  void dispose() {
    _nameController.dispose();
    _tripNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _selectCountry() async {
    // 국가 목록은 기존 ApiService.getCountries() 재사용
    // 여기서는 간단히 아시아 국가 상수 사용
    final countries = await _apiService.getCountries().catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scrollCtrl) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('여행지 국가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: countries.length,
                itemBuilder: (_, i) {
                  final c = countries[i];
                  return ListTile(
                    title: Text(c['country_name'] as String? ?? ''),
                    onTap: () {
                      setState(() {
                        _selectedCountryCode = c['country_code'] as String?;
                        _selectedCountryName = c['country_name'] as String?;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canProceed || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 1. 이름 저장
      await _apiService.updateUser(widget.userId, {
        'display_name': _nameController.text.trim(),
        'onboarding_step': 'complete',
      });

      // 2. 여행 생성
      final result = await _apiService.createTrip({
        'trip_name': _tripNameController.text.trim(),
        'country_code': _selectedCountryCode,
        'country_name': _selectedCountryName,
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'trip_type': 'personal',
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('group_id', result['group_id'] ?? '');
      await prefs.setString('user_role', 'captain');
      await prefs.setString('user_name', _nameController.text.trim());

      if (!mounted) return;
      widget.authNotifier.setHasActiveTrip(true);
      widget.authNotifier.setAuthenticated(hasTrip: true);

      // Android: 권한 요청, iOS: 바로 메인
      final isAndroid = Theme.of(context).platform == TargetPlatform.android;
      if (isAndroid) {
        context.push(RoutePaths.permission);
      } else {
        context.go(RoutePaths.main);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('캡틴으로\n시작하기', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.3)),
              const SizedBox(height: 32),
              // 이름
              _buildLabel('내 이름'),
              _buildTextField(_nameController, '이름을 입력하세요'),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text('첫 여행 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const SizedBox(height: 16),
              // 여행 이름
              _buildLabel('여행 이름'),
              _buildTextField(_tripNameController, '예: 일본 벚꽃 여행'),
              const SizedBox(height: 16),
              // 국가 선택
              _buildLabel('어디로?'),
              _buildTapField(
                hint: '나라 검색...',
                value: _selectedCountryName,
                onTap: _selectCountry,
                icon: Icons.place_outlined,
              ),
              const SizedBox(height: 16),
              // 날짜 선택
              _buildLabel('언제?'),
              _buildTapField(
                hint: '출발일 ~ 도착일',
                value: _startDate != null && _endDate != null
                    ? '${_startDate!.month}/${_startDate!.day} ~ ${_endDate!.month}/${_endDate!.day}'
                    : null,
                onTap: _selectDateRange,
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ListenableBuilder(
                  listenable: Listenable.merge([_nameController, _tripNameController]),
                  builder: (_, __) => ElevatedButton(
                    onPressed: _canProceed ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTokens.primaryColor,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('여행 시작하기', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
  );

  Widget _buildTextField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  Widget _buildTapField({
    required String hint,
    required String? value,
    required VoidCallback onTap,
    required IconData icon,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[500], size: 18),
              const SizedBox(width: 8),
              Text(
                value ?? hint,
                style: TextStyle(color: value != null ? Colors.black87 : Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
        ),
      );
}
```

**Step 2: 컴파일 확인**

```bash
flutter analyze lib/screens/auth/screen_captain_setup.dart
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/screens/auth/screen_captain_setup.dart
git commit -m "feat(flutter): add CaptainSetupScreen — name + trip setup in one screen"
```

---

## Task 8: Flutter — screen_crew_setup.dart

**Files:**
- Create: `safetrip-mobile/lib/screens/auth/screen_crew_setup.dart`

**Step 1: 화면 구현**

```dart
// safetrip-mobile/lib/screens/auth/screen_crew_setup.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_tokens.dart';
import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';
import '../../services/api_service.dart';

class CrewSetupScreen extends StatefulWidget {
  final String userId;
  final String role; // 'crew' | 'guardian'
  final AuthNotifier authNotifier;

  const CrewSetupScreen({
    super.key,
    required this.userId,
    required this.role,
    required this.authNotifier,
  });

  @override
  State<CrewSetupScreen> createState() => _CrewSetupScreenState();
}

class _CrewSetupScreenState extends State<CrewSetupScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  final _apiService = ApiService();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _apiService.updateUser(widget.userId, {
        'display_name': name,
        'onboarding_step': 'complete',
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_role', widget.role);

      if (!mounted) return;

      // 대기 중인 초대 코드가 있으면 trip join으로, 없으면 메인으로
      final groupId = prefs.getString('group_id');
      widget.authNotifier.setAuthenticated(hasTrip: groupId != null && groupId.isNotEmpty);

      context.go(RoutePaths.main);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuardian = widget.role == 'guardian';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                '반가워요!\n${isGuardian ? '가디언' : '크루'}으로\n등록합니다',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                isGuardian
                    ? '가족에게 어떻게 불릴까요?'
                    : '팀에서 어떻게 불릴까요?',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '이름 또는 닉네임',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nameController.text.trim().isNotEmpty ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primaryColor,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('시작하기', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: 컴파일 확인**

```bash
flutter analyze lib/screens/auth/screen_crew_setup.dart
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/screens/auth/screen_crew_setup.dart
git commit -m "feat(flutter): add CrewSetupScreen — minimal name-only setup for crew/guardian"
```

---

## Task 9: Flutter — auth_notifier.dart 업데이트

**Files:**
- Modify: `safetrip-mobile/lib/router/auth_notifier.dart`

**Step 1: `onboarding_step` 상태 추가**

기존 `auth_notifier.dart`의 변수 선언부에 추가:

```dart
String _onboardingStep = 'complete'; // 'complete' | 'profile_pending' | 'trip_pending'
String get onboardingStep => _onboardingStep;
```

`_loadState()` 내에 SharedPreferences 로드 코드 추가:

```dart
_onboardingStep = prefs.getString('onboarding_step') ?? 'complete';
```

새 메서드 추가:

```dart
Future<void> setOnboardingStep(String step) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('onboarding_step', step);
  _onboardingStep = step;
  notifyListeners();
}
```

**Step 2: 컴파일 확인**

```bash
flutter analyze lib/router/auth_notifier.dart
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/router/auth_notifier.dart
git commit -m "feat(flutter): add onboarding_step tracking to AuthNotifier"
```

---

## Task 10: Flutter — app_router.dart 재편성

**Files:**
- Modify: `safetrip-mobile/lib/router/app_router.dart`

**Step 1: 전체 라우터 재편성**

기존 `app_router.dart`를 아래로 교체. 핵심 변경:
- 기존 `onboarding`, `onboardingMain`, `authPhone`, `authVerify`, `authTerms`, `authProfile` 라우트 → 신규 라우트로 교체
- 삭제 예정 화면들은 import에서도 제거

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/onboarding/onboarding_role.dart';
import '../screens/auth/screen_captain_setup.dart';
import '../screens/auth/screen_crew_setup.dart';
import '../screens/auth/screen_phone_auth.dart';
import '../screens/main/screen_main.dart';
import '../screens/onboarding/screen_role_select.dart';
import '../screens/screen_permission.dart';
import '../screens/screen_splash.dart';
import '../screens/trip/screen_trip_confirm.dart';
import '../screens/trip/screen_trip_create.dart';
import '../screens/trip/screen_trip_join_code.dart';
import 'auth_notifier.dart';
import 'route_paths.dart';

class AppRouter {
  final AuthNotifier authNotifier;

  AppRouter(this.authNotifier);

  late final GoRouter router = GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: authNotifier,
    redirect: _redirect,
    routes: _routes,
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final isLoading = authNotifier.isLoading;
    final isAuth = authNotifier.isAuthenticated;
    final hasTrip = authNotifier.hasActiveTrip;

    if (isLoading) return path == RoutePaths.splash ? null : RoutePaths.splash;

    if (path == RoutePaths.splash) {
      if (!isAuth) return RoutePaths.roleSelect;
      return hasTrip ? RoutePaths.main : RoutePaths.tripCreate;
    }

    // 인증된 사용자가 온보딩 화면 접근 시 메인으로
    if (isAuth && (path == RoutePaths.roleSelect)) return RoutePaths.main;

    // 미인증 사용자가 보호된 경로 접근 시 역할 선택으로
    if (!isAuth && (path == RoutePaths.tripCreate || path == RoutePaths.permission || path == RoutePaths.tripConfirm)) {
      return RoutePaths.roleSelect;
    }

    // 딥링크 초대 코드 처리
    if (!isAuth && path == RoutePaths.tripJoin) {
      final code = state.uri.queryParameters['code'];
      if (code != null) authNotifier.setPendingInviteCode(code);
      return RoutePaths.roleSelect;
    }

    return null;
  }

  List<RouteBase> get _routes => [
    GoRoute(
      path: RoutePaths.splash,
      builder: (_, __) => const InitialScreen(),
    ),
    // ── 신규 온보딩 라우트 ──────────────────────────────────
    GoRoute(
      path: RoutePaths.roleSelect,
      builder: (_, __) => const RoleSelectScreen(),
    ),
    GoRoute(
      path: RoutePaths.authPhone,
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        final roleName = extra['role'] as String? ?? OnboardingRole.crew.name;
        final role = OnboardingRole.values.firstWhere(
          (r) => r.name == roleName,
          orElse: () => OnboardingRole.crew,
        );
        return PhoneAuthScreen(role: role, authNotifier: authNotifier);
      },
    ),
    GoRoute(
      path: RoutePaths.captainSetup,
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return CaptainSetupScreen(
          userId: extra['userId'] as String? ?? '',
          authNotifier: authNotifier,
        );
      },
    ),
    GoRoute(
      path: RoutePaths.crewSetup,
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return CrewSetupScreen(
          userId: extra['userId'] as String? ?? '',
          role: extra['role'] as String? ?? 'crew',
          authNotifier: authNotifier,
        );
      },
    ),
    GoRoute(
      path: RoutePaths.tripPreview,
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        final code = extra['code'] as String? ??
            state.uri.queryParameters['code'] ?? '';
        return ScreenTripJoinCode(
          joinType: JoinType.autoDetect,
          fromOnboarding: true,
          prefilledCode: code,
        );
      },
    ),
    // ── 기존 라우트 유지 ─────────────────────────────────────
    GoRoute(
      path: RoutePaths.main,
      builder: (_, __) => MainScreen(authNotifier: authNotifier),
    ),
    GoRoute(
      path: RoutePaths.tripCreate,
      builder: (_, __) => const ScreenTripCreate(),
    ),
    GoRoute(
      path: RoutePaths.tripJoin,
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return ScreenTripJoinCode(
          joinType: JoinType.autoDetect,
          fromOnboarding: false,
          prefilledCode: code,
        );
      },
    ),
    GoRoute(
      path: RoutePaths.permission,
      builder: (_, __) => const PermissionScreen(),
    ),
    GoRoute(
      path: RoutePaths.tripConfirm,
      builder: (context, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        final typeName = extra['confirmType'] as String? ?? 'crew';
        final confirmType = ConfirmType.values.firstWhere(
          (e) => e.name == typeName,
          orElse: () => ConfirmType.crew,
        );
        return ScreenTripConfirm(
          confirmType: confirmType,
          inviteCode: extra['inviteCode'] as String?,
          previewData: extra['previewData'] as Map<String, dynamic>?,
        );
      },
    ),
  ];
}
```

**Step 2: 컴파일 확인 (전체 앱)**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/
```

Expected: `No issues found!` 또는 삭제 예정 파일 관련 경고만.

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/router/app_router.dart
git commit -m "feat(flutter): rewrite AppRouter — new 5-step onboarding routes"
```

---

## Task 11: Flutter — 구 온보딩 화면 삭제

**Files:**
- Delete: `safetrip-mobile/lib/screens/onboarding/screen_1_onboarding.dart`
- Delete: `safetrip-mobile/lib/screens/auth/screen_3_start.dart`
- Delete: `safetrip-mobile/lib/screens/auth/screen_5_terms.dart`

**Step 1: 파일 삭제 전 참조 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
grep -r "screen_1_onboarding\|screen_3_start\|screen_5_terms\|OnboardingScreen\|StartScreen\|TermsScreen" lib/ --include="*.dart" -l
```

Expected: 파일이 없어야 함 (app_router.dart에서 이미 제거됨).

**Step 2: 파일 삭제**

```bash
rm lib/screens/onboarding/screen_1_onboarding.dart
rm lib/screens/auth/screen_3_start.dart
rm lib/screens/auth/screen_5_terms.dart
```

**Step 3: 빌드 확인**

```bash
flutter analyze lib/
flutter build apk --debug --no-pub 2>&1 | head -30
```

**Step 4: 커밋**

```bash
git add -A
git commit -m "chore(flutter): delete deprecated onboarding/start/terms screens"
```

---

## Task 12: Flutter — 메인 앱 웰컴 배너

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

**Step 1: 온보딩 배너 위젯 추가**

`screen_main.dart`의 홈 탭 상단에 조건부 배너 추가. 아래 위젯을 스크린 파일에 추가:

```dart
Widget _buildOnboardingBanner(BuildContext context, AuthNotifier authNotifier) {
  final step = authNotifier.onboardingStep;
  if (step == 'complete') return const SizedBox.shrink();

  final (String message, String buttonText, VoidCallback onTap) = switch (step) {
    'profile_pending' => (
        '프로필을 완성하면 멤버들이 나를 알아볼 수 있어요',
        '완성하기',
        () => context.push('/profile/edit'),
      ),
    'trip_pending' => (
        '첫 여행을 만들어 멤버들을 초대해보세요',
        '여행 만들기',
        () => context.push(RoutePaths.tripCreate),
      ),
    _ => ('', '', () {}),
  };

  if (message.isEmpty) return const SizedBox.shrink();

  return Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppTokens.primaryColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTokens.primaryColor.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onTap,
          child: Text(buttonText, style: TextStyle(color: AppTokens.primaryColor, fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: () => authNotifier.setOnboardingStep('complete'),
          child: const Icon(Icons.close, size: 16, color: Colors.grey),
        ),
      ],
    ),
  );
}
```

`screen_main.dart`의 홈 탭 최상단에 `_buildOnboardingBanner(context, widget.authNotifier)` 호출 추가.

**Step 2: 컴파일 확인**

```bash
flutter analyze lib/screens/main/screen_main.dart
```

**Step 3: 커밋**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "feat(flutter): add smart welcome banner for deferred profile completion"
```

---

## Task 13: 통합 테스트 — 전체 플로우 검증

**수동 테스트 체크리스트**

아래 모든 경로를 에뮬레이터 또는 실기기에서 테스트:

```
□ 캡틴 플로우:
  1. 앱 실행 → 역할 선택 화면 표시 확인
  2. 캡틴 카드 탭 → PhoneAuthScreen 이동 확인
  3. 테스트 번호 입력 → 코드 자동 입력 확인
  4. OTP 인증 → CaptainSetupScreen 이동 확인
  5. 이름 + 여행정보 입력 → 권한 요청(Android) → 메인 진입 확인
  6. 메인 앱 정상 진입 확인

□ 크루 플로우:
  1. 역할 선택 → 크루 탭
  2. 전화 인증
  3. CrewSetupScreen → 이름 입력 → 메인 진입 확인

□ 초대 코드 플로우:
  1. 역할 선택 화면 하단 "초대 코드가 있어요" 탭
  2. 코드 입력 → 여행 미리보기 화면 확인
  3. 전화 인증 → 이름 입력 → 합류 확인

□ 재진입 플로우:
  1. 앱 재시작 → 인증 유지 확인 (30일 이내)
  2. 인증 만료 후 재시작 → 역할 선택 화면으로 이동 확인
```

**서버 테스트**

```bash
# 여행 미리보기 API (코드는 실제 생성된 코드 사용)
curl http://localhost:3001/api/v1/trips/preview/MXXXXXX

# 약관 저장 API (idToken은 Firebase 인증 후 토큰)
curl -X PATCH http://localhost:3001/api/v1/users/USER_ID/terms \
  -H "Authorization: Bearer ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"terms_version":"1.0"}'
```

---

## 구현 순서 요약

| 순서 | Task | 예상 소요 | 의존성 |
|------|------|----------|-------|
| 1 | DB 마이그레이션 | 5분 | 없음 |
| 2 | 백엔드 여행 미리보기 API | 20분 | Task 1 |
| 3 | 백엔드 약관 API | 15분 | Task 1 |
| 4 | OnboardingRole + RoutePaths | 10분 | 없음 |
| 5 | RoleSelectScreen | 30분 | Task 4 |
| 6 | PhoneAuthScreen | 40분 | Task 4, 3 |
| 7 | CaptainSetupScreen | 30분 | Task 4 |
| 8 | CrewSetupScreen | 15분 | Task 4 |
| 9 | AuthNotifier 업데이트 | 10분 | 없음 |
| 10 | AppRouter 재편성 | 20분 | Task 5-9 |
| 11 | 구 화면 삭제 | 5분 | Task 10 |
| 12 | 웰컴 배너 | 20분 | Task 9 |
| 13 | 통합 테스트 | 30분 | 전체 |

---

## 알려진 주의사항

1. **AppTokens.primaryColor**: 실제 클래스명/경로 확인 필요. `app_tokens.dart`에서 색상 상수 이름 확인 후 사용.
2. **ApiService.updateUser()**: 기존 `PUT /users/:id` API를 호출하는 메서드가 있어야 함. 없으면 추가.
3. **ApiService.getCountries()**: 국가 목록 API. 기존에 있으면 재사용, 없으면 `kAsianCountries` 상수로 대체.
4. **tb_trip 인바이트 코드 컬럼명**: `invite_code_crew_chief`, `invite_code_crew`, `invite_code_guardian` — 실제 스키마와 다를 경우 `\d tb_trip` 으로 확인 후 수정.
5. **screen_7_verify.dart의 에뮬레이터 코드 조회 메서드**: `_authService.getEmulatorVerificationCode(verificationId)` 메서드가 `FirebaseAuthService`에 있어야 함. 없으면 추가.
