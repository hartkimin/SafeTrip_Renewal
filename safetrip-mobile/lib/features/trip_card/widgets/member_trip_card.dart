import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/trip_card_data.dart';
import 'planning_card_content.dart';
import 'active_card_content.dart';
import 'completed_card_content.dart';

/// 멤버 여행 카드 — 상태별 strategy 분기 (§04, C3)
class MemberTripCardWidget extends StatelessWidget {
  const MemberTripCardWidget({
    super.key,
    required this.data,
    this.onTap,
    this.onReactivate,
    this.showSwitchButton = false,
    this.onSwitch,
  });

  final MemberTripCard data;
  final VoidCallback? onTap;
  final VoidCallback? onReactivate;
  final bool showSwitchButton;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4),
          ],
        ),
        child: Stack(
          children: [
            _buildContent(),
            // [전환▼] 버튼 (§09.1, P0-6)
            if (showSwitchButton)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onSwitch,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.status == 'completed' ? '열람' : '전환',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textTertiary),
                        ),
                        const Icon(Icons.arrow_drop_down,
                            size: 14, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (data.status) {
      case 'active':
        return ActiveCardContent(card: data);
      case 'completed':
        return CompletedCardContent(card: data, onReactivate: onReactivate);
      case 'planning':
      default:
        return PlanningCardContent(card: data);
    }
  }
}
