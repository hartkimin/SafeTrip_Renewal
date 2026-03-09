import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// 프라이버시 등급 배지 (§03.3, §07)
/// 3행 레이아웃의 3행에 표시된다.
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(config.icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: AppTypography.labelSmall.copyWith(
              color: config.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static _PrivacyConfig _getConfig(String level) {
    switch (level) {
      case 'safety_first':
        return const _PrivacyConfig(
          icon: '\u{1F6E1}\u{FE0F}',
          label: '안전 최우선 \u{00B7} 강제 공유 \u{00B7} 24시간',
          color: AppColors.privacySafetyFirst,
        );
      case 'privacy_first':
        return const _PrivacyConfig(
          icon: '\u{1F512}',
          label: '프라이버시 우선 \u{00B7} 일정 연동',
          color: AppColors.privacyFirst,
        );
      case 'standard':
      default:
        return const _PrivacyConfig(
          icon: '\u{1F4CD}',
          label: '표준 \u{00B7} 24시간 공유',
          color: AppColors.privacyStandard,
        );
    }
  }
}

class _PrivacyConfig {
  const _PrivacyConfig({
    required this.icon,
    required this.label,
    required this.color,
  });
  final String icon;
  final String label;
  final Color color;
}
