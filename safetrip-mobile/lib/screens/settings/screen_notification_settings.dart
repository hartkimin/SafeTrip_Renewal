import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 전역 알림 설정 화면 (설정 메뉴 원칙 4.1)
///
/// 5개 알림 토글을 제공하며, SOS 알림은 항상 활성화 상태로 비활성화 불가.
/// 모든 토글 상태는 [SharedPreferences]에 즉시 저장된다.
class ScreenNotificationSettings extends StatefulWidget {
  const ScreenNotificationSettings({super.key});

  @override
  State<ScreenNotificationSettings> createState() =>
      _ScreenNotificationSettingsState();
}

class _ScreenNotificationSettingsState
    extends State<ScreenNotificationSettings> {
  // ── SharedPreferences 키 ──────────────────────────────────────────
  static const _keyGuardian = 'notif_guardian';
  static const _keyChat = 'notif_chat';
  static const _keySchedule = 'notif_schedule';
  static const _keyMarketing = 'notif_marketing';

  // ── 토글 상태 ──────────────────────────────────────────────────────
  bool _guardianEnabled = true;
  bool _chatEnabled = true;
  bool _scheduleEnabled = true;
  bool _marketingEnabled = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _guardianEnabled = prefs.getBool(_keyGuardian) ?? true;
      _chatEnabled = prefs.getBool(_keyChat) ?? true;
      _scheduleEnabled = prefs.getBool(_keySchedule) ?? true;
      _marketingEnabled = prefs.getBool(_keyMarketing) ?? false;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('전역 알림 설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: AppSpacing.sm),

                // 1. SOS 알림 — 항상 ON, 토글 비활성화
                _buildToggleTile(
                  title: 'SOS 알림',
                  subtitle: '긴급 상황 알림은 항상 활성화됩니다',
                  value: true,
                  onChanged: null,
                  isDisabled: true,
                ),

                const Divider(height: 1),

                // 2. 가디언 알림
                _buildToggleTile(
                  title: '가디언 알림',
                  subtitle: '가디언 연결 요청 및 상태 변경',
                  value: _guardianEnabled,
                  onChanged: (value) {
                    setState(() => _guardianEnabled = value);
                    _savePreference(_keyGuardian, value);
                  },
                ),

                const Divider(height: 1),

                // 3. 채팅 알림
                _buildToggleTile(
                  title: '채팅 알림',
                  subtitle: '새 메시지 수신',
                  value: _chatEnabled,
                  onChanged: (value) {
                    setState(() => _chatEnabled = value);
                    _savePreference(_keyChat, value);
                  },
                ),

                const Divider(height: 1),

                // 4. 일정 알림
                _buildToggleTile(
                  title: '일정 알림',
                  subtitle: '일정 시작 전 리마인더',
                  value: _scheduleEnabled,
                  onChanged: (value) {
                    setState(() => _scheduleEnabled = value);
                    _savePreference(_keySchedule, value);
                  },
                ),

                const Divider(height: 1),

                // 5. 마케팅 알림
                _buildToggleTile(
                  title: '마케팅 알림',
                  subtitle: '이벤트 및 혜택 안내',
                  value: _marketingEnabled,
                  onChanged: (value) {
                    setState(() => _marketingEnabled = value);
                    _savePreference(_keyMarketing, value);
                  },
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Toggle Tile
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool isDisabled = false,
  }) {
    return Container(
      color: AppColors.surface,
      child: SwitchListTile(
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(
            color: isDisabled ? AppColors.textTertiary : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primaryTeal,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }
}
