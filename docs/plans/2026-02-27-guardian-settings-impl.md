# Guardian Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 설정 화면에 가디언 연결 섹션 추가 (guardian 역할 인라인 pending/linked 관리) + captain의 가디언 메시지 수신 토글 초기값 API 로드 버그 수정.

**Architecture:** 백엔드에 GET `/trips/:tripId/settings` 엔드포인트 추가 → Flutter `ApiService.getTripSettings()` 추가 → `screen_settings.dart` 안에 `_GuardianSection` StatefulWidget 추가. 별도 파일 생성 없음.

**Tech Stack:** Node.js/TypeScript (백엔드), Flutter/Dart (모바일), PostgreSQL (`tb_trip_settings`), `AppTokens` 디자인 시스템

---

### Task 1: 백엔드 — GET /api/v1/trips/:tripId/settings 엔드포인트 추가

**Files:**
- Modify: `safetrip-server-api/src/controllers/trips.controller.ts` (updateTripSettings 위에 getTripSettings 추가)
- Modify: `safetrip-server-api/src/routes/trips.routes.ts` (GET 라우트 추가)

**Background:**
- `trip-settings.service.ts`에 `getSettings(tripId)` 메서드가 이미 존재함 (DB 조회 또는 기본값 반환)
- PATCH `/trips/:tripId/settings`는 이미 있음. GET은 없음.
- 컨트롤러 패턴: `async (req, res): Promise<void>` → `sendSuccess(res, data)` 또는 `sendError(res, msg, code)`

**Step 1: trips.controller.ts에 getTripSettings 컨트롤러 메서드 추가**

`updateTripSettings` 바로 위에 삽입:

```typescript
/**
 * GET /api/v1/trips/:tripId/settings
 * 여행 설정 조회 (인증 필요)
 */
getTripSettings: async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { tripId } = req.params;
    const settings = await tripSettingsService.getSettings(tripId);
    sendSuccess(res, settings);
  } catch (error) {
    logger.error('Failed to get trip settings', { error, tripId: req.params.tripId });
    sendError(res, 'Failed to get trip settings', 500);
  }
},
```

`tripSettingsService`가 이미 import되어 있는지 확인 후 없으면 추가:
```typescript
import { tripSettingsService } from '../services/trip-settings.service';
```

**Step 2: trips.routes.ts에 GET 라우트 추가**

PATCH `/:tripId/settings` 바로 위에 삽입:

```typescript
// GET /api/v1/trips/:tripId/settings
// 여행 설정 조회 (인증 필요)
router.get('/:tripId/settings', authenticate, tripsController.getTripSettings);
```

> ⚠️ `/:tripId/settings`는 `/:tripId` 뒤에 와야 함. 현재 라우트 파일에서 `GET /:tripId`가 line 46에 있는데, Express는 먼저 등록된 라우트 우선 매칭 → `/:tripId/settings`를 `/:tripId` 위에 두면 안 됨. `/:tripId` 아래에 둠.

**Step 3: 서버 재시작 후 수동 테스트**

```bash
# 서버 실행 (이미 실행 중이면 재시작)
cd safetrip-server-api && npm run dev > /tmp/safetrip-backend.log 2>&1 &

# GET 요청 테스트 (tripId는 실제 값으로 교체)
curl -s -H "Authorization: Bearer <firebase-id-token>" \
  http://localhost:3001/api/v1/trips/<tripId>/settings | jq .
```

예상 응답:
```json
{
  "success": true,
  "data": {
    "trip_id": "...",
    "captain_receive_guardian_msg": true
  }
}
```

인증 없이 호출 시 401 반환 확인.

**Step 4: 커밋**

```bash
cd safetrip-server-api
git add src/controllers/trips.controller.ts src/routes/trips.routes.ts
git commit -m "feat: add GET /trips/:tripId/settings endpoint"
```

---

### Task 2: Flutter — ApiService.getTripSettings() 추가

**Files:**
- Modify: `safetrip-mobile/lib/services/api_service.dart` (Guardian Management 섹션 근처에 추가)

**Background:**
- `updateCaptainReceiveGuardianMsg()` 메서드가 line ~2486에 있음
- 동일 파일에 `getTripSettings()`를 바로 위에 추가

**Step 1: api_service.dart에서 Guardian Management 섹션 찾기**

`// ─── Guardian Management` 주석 근처 (line ~2325)에 위치.

**Step 2: getTripSettings 메서드 추가**

`updateCaptainReceiveGuardianMsg` 바로 위에 삽입:

```dart
/// GET /api/v1/trips/:tripId/settings — 여행 설정 조회
Future<Map<String, dynamic>?> getTripSettings(String tripId) async {
  try {
    final response = await _dio.get('/api/v1/trips/$tripId/settings');
    if (response.data['success'] == true && response.data['data'] != null) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    return null;
  } catch (e) {
    debugPrint('[ApiService] getTripSettings error: $e');
    return null;
  }
}
```

**Step 3: 빌드 확인**

```bash
cd safetrip-mobile && flutter analyze lib/services/api_service.dart
```

에러 없음 확인.

**Step 4: 커밋**

```bash
git add lib/services/api_service.dart
git commit -m "feat: add ApiService.getTripSettings()"
```

---

### Task 3: Flutter — _GuardianSection 위젯 작성 (captain 역할)

**Files:**
- Modify: `safetrip-mobile/lib/screens/settings/screen_settings.dart`

**Background:**
- `SettingsScreen`은 StatefulWidget, 현재 762줄
- captain의 가디언 메시지 수신 토글(`_buildGuardianMsgToggle`)이 `_captainReceiveGuardianMsg = true`로 하드코딩됨 (line 49)
- 목표: `_GuardianSection`이라는 독립 StatefulWidget을 파일 끝에 추가하고, captain 역할일 때 settings 값을 API에서 로드

**Step 1: screen_settings.dart 맨 끝(line 762 이후)에 _GuardianSection 클래스 추가**

```dart
/// 가디언 관련 설정 섹션 — 역할에 따라 다른 UI 렌더링
/// - captain: 가디언 메시지 수신 ON/OFF (API에서 초기값 로드)
/// - guardian: pending 초대 + 연결 멤버 인라인 목록
class _GuardianSection extends StatefulWidget {
  final String tripId;
  final String userRole;

  const _GuardianSection({
    required this.tripId,
    required this.userRole,
  });

  @override
  State<_GuardianSection> createState() => _GuardianSectionState();
}

class _GuardianSectionState extends State<_GuardianSection> {
  final _api = ApiService();

  // captain 역할 상태
  bool _captainReceiveGuardianMsg = true;

  // guardian 역할 상태
  List<GuardianInvitation> _pending = [];
  List<LinkedMember> _linked = [];

  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      if (widget.userRole == 'captain') {
        final settings = await _api.getTripSettings(widget.tripId);
        if (mounted) {
          setState(() {
            _captainReceiveGuardianMsg =
                settings?['captain_receive_guardian_msg'] as bool? ?? true;
          });
        }
      } else if (widget.userRole == 'guardian') {
        final results = await Future.wait([
          _api.getPendingGuardianInvitations(widget.tripId),
          _api.getLinkedMembers(widget.tripId),
        ]);
        if (mounted) {
          setState(() {
            _pending = results[0] as List<GuardianInvitation>;
            _linked = results[1] as List<LinkedMember>;
          });
        }
      }
    } catch (e) {
      debugPrint('[_GuardianSection] load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole == 'captain') return _buildCaptainSection();
    if (widget.userRole == 'guardian') return _buildGuardianSection();
    return const SizedBox.shrink();
  }

  // ── Captain: 가디언 메시지 수신 토글 ──────────────────────────────
  Widget _buildCaptainSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('가디언 설정'),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(),
          )
        else
          _buildMsgToggle(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMsgToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
      child: InkWell(
        onTap: () => _onToggleMsg(!_captainReceiveGuardianMsg),
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTokens.secondaryAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppTokens.secondaryAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '가디언 메시지 수신',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.text05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _captainReceiveGuardianMsg
                          ? '가디언에게서 메시지를 받습니다'
                          : 'OFF: 모든 가디언 메시지가 차단됩니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: _captainReceiveGuardianMsg
                            ? AppTokens.text03
                            : AppTokens.semanticError,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _captainReceiveGuardianMsg,
                onChanged: _onToggleMsg,
                activeThumbColor: AppTokens.primaryTeal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onToggleMsg(bool value) async {
    final prev = _captainReceiveGuardianMsg;
    setState(() => _captainReceiveGuardianMsg = value);
    try {
      await _api.updateCaptainReceiveGuardianMsg(widget.tripId, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '가디언 메시지 수신이 켜졌습니다' : '가디언 메시지 수신이 꺼졌습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _captainReceiveGuardianMsg = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정 변경에 실패했습니다')),
        );
      }
    }
  }

  // ── Guardian: pending 초대 + 연결 멤버 ───────────────────────────
  Widget _buildGuardianSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('가디언 연결'),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: LinearProgressIndicator(),
          )
        else if (_hasError)
          _buildErrorTile()
        else ...[
          ..._pending.map(_buildPendingCard),
          ..._linked.map(_buildLinkedMemberTile),
          if (_pending.isEmpty && _linked.isEmpty) _buildEmptyTile(),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildErrorTile() {
    return GestureDetector(
      onTap: _load,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTokens.bgBasic01,
          borderRadius: BorderRadius.circular(AppTokens.radius12),
        ),
        child: Row(
          children: [
            const Icon(Icons.refresh, color: AppTokens.semanticError, size: 18),
            const SizedBox(width: 12),
            Text(
              '불러오기 실패 — 탭하여 재시도',
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize13,
                color: AppTokens.semanticError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTokens.secondaryAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined,
                color: AppTokens.secondaryAmber, size: 20),
          ),
          const SizedBox(width: 14),
          Text(
            '연결된 멤버가 없습니다',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              color: AppTokens.text03,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(GuardianInvitation inv) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(
          color: AppTokens.secondaryAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, size: 16, color: AppTokens.secondaryAmber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${inv.memberDisplayName}님의 가디언 초대',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize14,
                    fontWeight: AppTokens.fontWeightSemibold,
                    color: AppTokens.text05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${inv.tripCountryName}  ${inv.tripStartDate} ~ ${inv.tripEndDate}',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize12,
              color: AppTokens.text03,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respond(inv, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTokens.semanticError,
                    side: const BorderSide(color: AppTokens.semanticError),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _respond(inv, 'accepted'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('수락'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedMemberTile(LinkedMember member) {
    final name = member.displayName.isNotEmpty
        ? member.displayName
        : member.phoneNumber;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AvatarWidget(
              userId: member.memberId,
              userName: name,
              profileImageUrl: member.profileImageUrl,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize14,
                      fontWeight: AppTokens.fontWeightMedium,
                      color: AppTokens.text05,
                    ),
                  ),
                  Text(
                    member.phoneNumber,
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize12,
                      color: AppTokens.text03,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.link_off, size: 20),
              color: AppTokens.semanticError,
              tooltip: '연결 해제',
              onPressed: () => _disconnect(member),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(GuardianInvitation inv, String action) async {
    try {
      await _api.respondToGuardianInvitation(inv.tripId, inv.linkId, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'accepted' ? '초대를 수락했습니다' : '초대를 거절했습니다'),
        ),
      );
      _load(); // 목록 갱신
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리 중 오류가 발생했습니다')),
      );
    }
  }

  Future<void> _disconnect(LinkedMember member) async {
    final name = member.displayName.isNotEmpty
        ? member.displayName
        : member.phoneNumber;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('연결 해제'),
        content: Text('$name 멤버와의 가디언 연결을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTokens.semanticError),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.removeGuardianLink(widget.tripId, member.linkId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결이 해제되었습니다')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해제 중 오류가 발생했습니다')),
      );
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title,
        style: AppTokens.textStyle(
          fontSize: AppTokens.fontSize12,
          fontWeight: AppTokens.fontWeightSemibold,
          color: AppTokens.text03,
        ),
      ),
    );
  }
}
```

**Step 2: flutter analyze 실행**

```bash
cd safetrip-mobile && flutter analyze lib/screens/settings/screen_settings.dart
```

에러 없음 확인. `AvatarWidget` import 이미 있음 (line 14).

**Step 3: 커밋 (아직 settings.dart에서 아무것도 제거하지 않음)**

```bash
git add lib/screens/settings/screen_settings.dart
git commit -m "feat: add _GuardianSection widget (captain + guardian roles)"
```

---

### Task 4: Flutter — SettingsScreen에서 기존 가디언 코드 제거 후 _GuardianSection 연결

**Files:**
- Modify: `safetrip-mobile/lib/screens/settings/screen_settings.dart`

**Background:**
- 현재 `SettingsScreen`에 있는 captain용 가디언 설정 코드 (`_captainReceiveGuardianMsg`, `_buildGuardianMsgToggle`, `_onGuardianMsgChanged`)는 `_GuardianSection`으로 이전되었으므로 삭제
- `build()` 메서드에서 가디언 설정 섹션을 `_GuardianSection` 위젯으로 교체

**Step 1: SettingsScreen에서 guardian 관련 상태 및 메서드 제거**

다음을 `_SettingsScreenState`에서 삭제:
- `bool _captainReceiveGuardianMsg = true;` (line 49)
- `_buildGuardianMsgToggle()` 메서드 (line 601-666)
- `_onGuardianMsgChanged()` 메서드 (line 668-697)

**Step 2: build() 메서드에서 captain 가디언 설정 섹션 교체**

현재 코드 (line 371-375):
```dart
// 가디언 설정 섹션 (captain만)
if (_isLeader && AppCache.tripIdSync != null) ...[
  _buildSectionHeader('가디언 설정'),
  _buildGuardianMsgToggle(),
  const SizedBox(height: 8),
],
```

교체 후:
```dart
// 가디언 설정/연결 섹션 (_GuardianSection이 역할에 따라 렌더링)
if (AppCache.tripIdSync != null &&
    (widget.userRole == 'captain' || widget.userRole == 'guardian')) ...[
  _GuardianSection(
    tripId: AppCache.tripIdSync!,
    userRole: widget.userRole,
  ),
],
```

> 설명: captain이면 가디언 메시지 수신 토글, guardian이면 pending 초대 + 연결 멤버 목록을 각자 렌더링.

**Step 3: flutter analyze 실행**

```bash
cd safetrip-mobile && flutter analyze lib/screens/settings/screen_settings.dart
```

에러 없음 확인.

**Step 4: 커밋**

```bash
git add lib/screens/settings/screen_settings.dart
git commit -m "feat: integrate _GuardianSection into SettingsScreen, remove legacy guardian state"
```

---

### Task 5: 수동 검증

**Step 1: 서버 시작 확인**

```bash
tail -20 /tmp/safetrip-backend.log
# "Server running on port 3001" 확인
```

**Step 2: Flutter 앱 빌드 및 실행**

```bash
cd safetrip-mobile && flutter run
```

**Step 3: captain 역할로 설정 화면 오픈 → 가디언 설정 섹션 확인**

- "가디언 설정" 섹션이 보임
- 앱 열 때 LinearProgressIndicator가 잠깐 보인 후 실제 서버 값으로 토글 초기화
- 토글 변경 시 snackbar 표시

**Step 4: guardian 역할로 설정 화면 오픈 → 가디언 연결 섹션 확인**

- "가디언 연결" 섹션이 보임
- pending 초대가 있으면 amber 카드 + 수락/거절 버튼
- linked member가 있으면 타일 + 연결 해제 버튼
- 둘 다 없으면 "연결된 멤버가 없습니다" 타일

**Step 5: crew/crew_chief 역할 확인**

- 가디언 설정 섹션 없음 (기존 "내 가디언 관리" 타일만 유지)

---

### Task 6: Obsidian 개발사항 기록

설계/구현 완료 후 `SafeTrip/개발일지/2026-02-27_개발사항.md`에 기록.

항목:
- 수정 파일: `trips.controller.ts`, `trips.routes.ts`, `api_service.dart`, `screen_settings.dart`
- 버그 수정: `_captainReceiveGuardianMsg` 초기값 API 로드
- 신규 기능: guardian 역할 설정 화면 가디언 연결 섹션 (pending 초대 + linked members)
- 신규 API: `GET /api/v1/trips/:tripId/settings`
