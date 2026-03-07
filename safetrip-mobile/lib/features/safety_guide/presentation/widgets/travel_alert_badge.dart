import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';

/// 여행경보 1~4단계 배지 (DOC-T3-SFG-021 §3.2.2)
class TravelAlertBadge extends StatelessWidget {
  const TravelAlertBadge({super.key, required this.level});

  final int level;

  Color get _color {
    switch (level) {
      case 1:
        return const Color(0xFF4CAF50); // 초록 -- 여행유의
      case 2:
        return const Color(0xFFFFC107); // 노랑 -- 여행자제
      case 3:
        return const Color(0xFFFF9800); // 주황 -- 출국권고
      case 4:
        return const Color(0xFFF44336); // 빨강 -- 여행금지
      default:
        return Colors.grey;
    }
  }

  String get _label {
    switch (level) {
      case 1:
        return '여행유의';
      case 2:
        return '여행자제';
      case 3:
        return '출국권고';
      case 4:
        return '여행금지';
      default:
        return '정보없음';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            '$level단계 $_label',
            style: AppTypography.labelSmall.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
