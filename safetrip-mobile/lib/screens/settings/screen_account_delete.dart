import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../router/route_paths.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_cache.dart';

class ScreenAccountDelete extends StatefulWidget {
  const ScreenAccountDelete({super.key});

  @override
  State<ScreenAccountDelete> createState() => _ScreenAccountDeleteState();
}

class _ScreenAccountDeleteState extends State<ScreenAccountDelete> {
  bool _isLoading = false;
  String? _activeTripId;
  String? _activeTripTitle;

  @override
  void initState() {
    super.initState();
    _loadActiveTripInfo();
  }

  Future<void> _loadActiveTripInfo() async {
    final tripId = await AppCache.tripId;
    if (tripId != null && tripId.isNotEmpty) {
      try {
        final tripData = await ApiService().getTripById(tripId);
        if (tripData != null && mounted) {
          setState(() {
            _activeTripId = tripId;
            _activeTripTitle = tripData['title'] as String?;
          });
        }
      } catch (e) {
        debugPrint('[ScreenAccountDelete] _loadActiveTripInfo Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('계정 삭제'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.xl),

                            // ── Warning Icon ───────────────────────────
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 48,
                              color: AppColors.sosDanger,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // ── Title ───────────────────────────────────
                            Text(
                              '계정을 삭제하면',
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // ── Info Card 1: 즉시 삭제 ──────────────────
                            _buildInfoCard(
                              icon: Icons.delete_forever,
                              iconColor: AppColors.sosDanger,
                              title: '즉시 삭제',
                              description: '프로필 정보, 이미지, 긴급 연락처',
                            ),
                            const SizedBox(height: AppSpacing.cardGap),

                            // ── Info Card 2: 익명화 보관 ─────────────────
                            _buildInfoCard(
                              icon: Icons.visibility_off,
                              iconColor: AppColors.secondaryAmber,
                              title: '익명화 보관',
                              description: '위치 데이터, 이벤트 로그 (통계용)',
                            ),
                            const SizedBox(height: AppSpacing.cardGap),

                            // ── Info Card 3: 영구 보관 ───────────────────
                            _buildInfoCard(
                              icon: Icons.gavel,
                              iconColor: AppColors.textSecondary,
                              title: '영구 보관',
                              description: 'SOS 기록 (법적 의무 보관)',
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // ── 7-Day Info Box ──────────────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal
                                    .withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radius12,
                                ),
                                border: Border.all(
                                  color: AppColors.primaryTeal
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: AppColors.primaryTeal,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      '삭제 요청 후 7일 이내에 로그인하면 삭제를 철회할 수 있습니다.',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.primaryTeal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
                    ),

                    // ── Bottom Button ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.lg,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: AppSpacing.buttonHeight,
                        child: ElevatedButton(
                          onPressed: _requestDeletion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sosDanger,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radius12,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            '계정 삭제 요청',
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Info Card Widget
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Deletion Flow
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _requestDeletion() async {
    final confirmed = await _showConfirmationDialog();
    if (confirmed != true) return;

    final reconfirmed = await _showTypeToConfirmDialog();
    if (!reconfirmed) return;

    setState(() => _isLoading = true);

    try {
      final success = await ApiService().requestAccountDeletion();

      if (!mounted) return;

      if (success) {
        await _showCompletionDialog();
        await _performSignOut();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('계정 삭제 요청에 실패했습니다. 다시 시도해 주세요.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ScreenAccountDelete] _requestDeletion Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오류가 발생했습니다. 다시 시도해 주세요.'),
          ),
        );
      }
    }
  }

  Future<bool> _showTypeToConfirmDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('최종 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('계정을 삭제하려면 아래에 "삭제"를 입력해주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '삭제',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim() == '삭제') {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sosDanger,
            ),
            child: const Text('확인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result ?? false;
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 계정을 삭제하시겠습니까?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Active trip warning
              if (_activeTripId != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color:
                        AppColors.semanticWarning.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radius8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.semanticWarning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          "참여 중인 여행 '${_activeTripTitle ?? '여행'}'에서 탈퇴됩니다.",
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Deletion categories
              Text(
                '삭제되는 데이터:',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildDeletionCategory(
                '즉시삭제',
                '프로필, 이미지, 긴급 연락처',
              ),
              _buildDeletionCategory(
                '익명화',
                '위치 데이터, 이벤트 로그',
              ),
              _buildDeletionCategory(
                '영구보관',
                'SOS 기록 (법적 의무)',
              ),
              const SizedBox(height: AppSpacing.md),

              // Grace period info
              Text(
                '7일 유예 기간 내에 로그인하면 삭제를 철회할 수 있습니다.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.sosDanger,
            ),
            child: const Text('계정 삭제 요청'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletionCategory(String label, String detail) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u2022 ',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: detail,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompletionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('삭제 요청 완료'),
        content: const Text(
          '7일 후 계정이 삭제됩니다.\n로그인 시 삭제를 철회할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSignOut() async {
    try {
      // 1. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Clear AppCache
      await AppCache.clear();

      // 3. Stop LocationService
      await LocationService().stopTracking();

      // 4. Sign out FirebaseAuth
      await FirebaseAuth.instance.signOut();

      // 5. Navigate to splash
      if (mounted) {
        context.go(RoutePaths.splash);
      }
    } catch (e) {
      debugPrint('[ScreenAccountDelete] _performSignOut Error: $e');
      if (mounted) {
        context.go(RoutePaths.splash);
      }
    }
  }
}
