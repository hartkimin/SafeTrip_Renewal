import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 프라이버시 등급 상단 배너 (화면구성원칙 §7)
///
/// 현재 여행의 프라이버시 등급에 따라 색상과 메시지를 다르게 표시한다.
class PrivacyBanner extends StatelessWidget {
  const PrivacyBanner({
    super.key,
    required this.privacyLevel,
  });

  final String privacyLevel;

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(privacyLevel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: config.color.withValues(alpha: 0.12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(config.icon, size: 16, color: config.color),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              config.message,
              style: AppTypography.labelSmall.copyWith(
                color: config.color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  _PrivacyConfig _getConfig(String level) {
    switch (level) {
      case 'safety_first':
        return const _PrivacyConfig(
          icon: Icons.shield,
          color: AppColors.privacySafetyFirst,
          message: '위치가 항상 공유됩니다',
        );
      case 'standard':
        return const _PrivacyConfig(
          icon: Icons.location_on,
          color: AppColors.privacyStandard,
          message: '스케줄 외 저빈도 위치 공유 중',
        );
      case 'privacy_first':
        return const _PrivacyConfig(
          icon: Icons.lock,
          color: AppColors.privacyFirst,
          message: '비공유 시간 — 위치가 공유되지 않습니다',
        );
      default:
        return const _PrivacyConfig(
          icon: Icons.location_on,
          color: AppColors.privacyStandard,
          message: '표준 위치 공유 모드',
        );
    }
  }
}

class _PrivacyConfig {
  const _PrivacyConfig({
    required this.icon,
    required this.color,
    required this.message,
  });
  final IconData icon;
  final Color color;
  final String message;
}
