import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// D-day 배지 (§03.2)
/// planning: D-15~D-1, active: "여행 중", completed: "완료"
class DDayBadge extends StatelessWidget {
  const DDayBadge({super.key, required this.status, this.dDay, this.currentDay});

  final String status;
  final int? dDay;
  final int? currentDay;

  @override
  Widget build(BuildContext context) {
    final display = _getDisplay();
    if (display.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        display,
        style: AppTypography.labelSmall.copyWith(
          color: _getColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getDisplay() {
    switch (status) {
      case 'active':
        return '여행 중';
      case 'completed':
        return '완료';
      case 'planning':
        if (dDay == null) return '';
        if (dDay! > 15) return ''; // §03.2: D-16 이상 비표시
        if (dDay! == 0) return '여행 중';
        return 'D-$dDay';
      default:
        return '';
    }
  }

  Color _getColor() {
    switch (status) {
      case 'active':
        return AppColors.tripActive;
      case 'completed':
        return AppColors.tripCompleted;
      case 'planning':
      default:
        return AppColors.tripPlanning;
    }
  }
}
