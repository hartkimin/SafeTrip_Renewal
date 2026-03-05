import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../router/route_paths.dart';

/// B-01 No Trip Home Screen
class ScreenNoTripHome extends StatelessWidget {
  const ScreenNoTripHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Stack(
                children: [
                  // Map Placeholder
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: AppColors.surfaceVariant,
                    child: const Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 80,
                        color: AppColors.outline,
                      ),
                    ),
                  ),

                  // CTA Overlay Card
                  Positioned(
                    left: AppSpacing.screenPaddingH,
                    right: AppSpacing.screenPaddingH,
                    bottom: AppSpacing.lg,
                    child: _buildCtaCard(context),
                  ),
                ],
              ),
            ),
            _buildBottomNavBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: AppSpacing.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            'SafeTrip',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primaryTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(RoutePaths.notificationList),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RoutePaths.settingsMain),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radius16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.luggage_outlined, size: 48, color: AppColors.primaryTeal),
          const SizedBox(height: AppSpacing.md),
          const Text('여행을 시작해보세요', style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '새 여행을 만들거나\n초대코드로 참여하세요',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push(RoutePaths.tripCreate),
                  child: const Text('여행 만들기'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(RoutePaths.tripJoin),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                    side: const BorderSide(color: AppColors.primaryTeal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radius12),
                    ),
                  ),
                  child: const Text('코드 입력', style: TextStyle(color: AppColors.primaryTeal)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      height: AppSpacing.navigationBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.calendar_today_outlined, '일정', true, () => _showLockedToast(context)),
          _buildNavItem(Icons.people_outline, '멤버', true, () => _showLockedToast(context)),
          _buildNavItem(Icons.chat_bubble_outline, '채팅', true, () => _showLockedToast(context)),
          _buildNavItem(Icons.menu_book_outlined, '안전가이드', false, () {
            // TODO: Open safety guide
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isLocked, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isLocked ? AppColors.textTertiary : AppColors.primaryTeal),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: isLocked ? AppColors.textTertiary : AppColors.primaryTeal,
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('여행에 참여한 후 이용할 수 있습니다')),
    );
  }
}
