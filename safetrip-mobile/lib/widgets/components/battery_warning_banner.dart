import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 배터리 경고 배너 (오프라인 원칙 §7.3)
///
/// 배터리 잔량 임계값에 따라 3단계 경고를 표시:
/// - <20%: GPS 수집 주기 감소 안내 (orange)
/// - <10%: 긴급 기능만 유지 안내 (deep orange)
/// - < 5%: SOS 대기 모드 전환 안내 (red)
///
/// [batteryLevel]이 20% 이상이면 배너를 숨긴다 (`SizedBox.shrink()`).
class BatteryWarningBanner extends StatelessWidget {
  const BatteryWarningBanner({super.key, required this.batteryLevel});

  final int batteryLevel;

  @override
  Widget build(BuildContext context) {
    final warningLevel = _getWarningLevel();
    if (warningLevel == null) return const SizedBox.shrink();

    final config = _getConfig(warningLevel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: config.color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(config.icon, size: 16, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              config.message,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  int? _getWarningLevel() {
    if (batteryLevel < 5) return 5;
    if (batteryLevel < 10) return 10;
    if (batteryLevel < 20) return 20;
    return null;
  }

  _BannerConfig _getConfig(int level) {
    switch (level) {
      case 5:
        return _BannerConfig(
          color: Colors.red,
          icon: Icons.battery_alert,
          message: '배터리 위험 ($batteryLevel%) — SOS 대기 모드',
        );
      case 10:
        return _BannerConfig(
          color: Colors.deepOrange,
          icon: Icons.battery_2_bar,
          message: '배터리 매우 부족 ($batteryLevel%) — 긴급 기능만 유지',
        );
      case 20:
      default:
        return _BannerConfig(
          color: Colors.orange.shade700,
          icon: Icons.battery_3_bar,
          message: '배터리 부족 ($batteryLevel%) — GPS 주기 감소',
        );
    }
  }
}

class _BannerConfig {
  const _BannerConfig({
    required this.color,
    required this.icon,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String message;
}
