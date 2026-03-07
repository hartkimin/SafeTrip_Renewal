import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

enum BottomTab { trip, member, chat, guide }

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    this.isGuardian = false,
    this.isDisabled = false,
  });

  final BottomTab currentTab;
  final Function(BottomTab) onTabChanged;
  final bool isGuardian;

  /// SOS 발동 시 탭 전환 비활성화 (§10.2)
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final systemBottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      width: double.infinity,
      height: AppSpacing.navigationBarHeight + 20 + systemBottomPadding,
      padding: EdgeInsets.only(top: 8, bottom: 12 + systemBottomPadding),
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
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: IgnorePointer(
          ignoring: isDisabled,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabItem(BottomTab.trip, '일정', Icons.calendar_today),
              _buildTabItem(
                BottomTab.member,
                isGuardian ? '내 담당 멤버' : '멤버',
                Icons.people,
              ),
              if (!isGuardian)
                _buildTabItem(BottomTab.chat, '채팅', Icons.chat_bubble),
              _buildTabItem(
                BottomTab.guide,
                '안전가이드',
                Icons.shield_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(BottomTab tab, String label, IconData icon) {
    final isActive = currentTab == tab;
    final color = isActive ? AppColors.primaryTeal : AppColors.textTertiary;

    return Expanded(
      child: Semantics(
        label: '$label 탭${isActive ? ", 선택됨" : ""}',
        button: true,
        child: GestureDetector(
          onTap: () => onTabChanged(tab),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: AppSpacing.tabBarItemSize,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ),
    );
  }
}
