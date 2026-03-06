import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/main/providers/connectivity_provider.dart';

/// 오프라인/연결 불안정 상태 배너 (지도 원칙 §8.1, §9.3)
///
/// [NetworkStatus]에 따라 3가지 상태를 표시:
/// - **online**: 배너 숨김 (`SizedBox.shrink()`)
/// - **degraded**: 앰버 배너 — "연결 불안정 — 재시도 중..."
/// - **offline**: 오렌지 배너 — "오프라인 모드 — 마지막 동기화: HH:MM"
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.status});

  final NetworkStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.isOnline) return const SizedBox.shrink();

    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerText;

    if (status.isOffline) {
      bannerColor = Colors.orange;
      bannerIcon = Icons.cloud_off;
      bannerText = '오프라인 모드 — 마지막 동기화: ${_formatTime(status.lastSyncTime)}';
    } else {
      // degraded
      bannerColor = Colors.amber;
      bannerIcon = Icons.signal_wifi_statusbar_connected_no_internet_4;
      bannerText = '연결 불안정 — 재시도 중...';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: bannerColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(bannerIcon, size: 16, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              bannerText,
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

  /// Format [DateTime] to 'HH:MM', or '--:--' if null.
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
