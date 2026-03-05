import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/components/sos_button.dart';

enum BottomTab { trip, member, chat, guide }

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    this.onSOSPressed,
    this.isGuardian = false,
  });

  final BottomTab currentTab;
  final Function(BottomTab) onTabChanged;
  final VoidCallback? onSOSPressed;
  final bool isGuardian;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: AppSpacing.navigationBarHeight + 20,
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radius12),
          topRight: Radius.circular(AppSpacing.radius12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabItem(BottomTab.trip, '일정', Icons.calendar_today),
              _buildTabItem(
                BottomTab.member,
                isGuardian ? '내 담당 멤버' : '멤버',
                Icons.people,
              ),
              if (!isGuardian)
                _buildTabItem(BottomTab.chat, '메시지', Icons.chat_bubble),
              _buildTabItem(BottomTab.guide, '안전가이드', Icons.menu_book),
              if (!isGuardian) const SizedBox(width: 70),
            ],
          ),
          if (!isGuardian)
            Positioned(
              right: 12,
              bottom: 4,
              child: SosButton(onSosActivated: onSOSPressed ?? () {}),
            ),
        ],
      ),
    );
  }

  Widget _buildTabItem(BottomTab tab, String label, IconData icon) {
    final isActive = currentTab == tab;
    final color = isActive ? AppColors.primaryTeal : AppColors.textTertiary;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(tab),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
