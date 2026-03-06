import 'package:flutter/material.dart';

import '../../constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 멤버 마커 탭 시 표시되는 미니 카드 (지도 원칙 §5.4)
///
/// 이름, 역할, 마지막 업데이트 시각, 배터리 표시.
class MemberMiniCard extends StatelessWidget {
  const MemberMiniCard({
    super.key,
    required this.userName,
    required this.role,
    this.lastUpdated,
    this.batteryLevel,
    this.isOffline = false,
    this.onClose,
  });

  final String userName;
  final String role;
  final DateTime? lastUpdated;
  final int? batteryLevel;
  final bool isOffline;
  final VoidCallback? onClose;

  Color get _roleColor {
    switch (role) {
      case 'captain':
      case 'leader':
        return MapConstants.markerCaptain;
      case 'crew_chief':
      case 'full':
        return MapConstants.markerCrewLeader;
      case 'guardian':
        return MapConstants.markerGuardian;
      default:
        return MapConstants.markerCrew;
    }
  }

  String get _roleLabel {
    switch (role) {
      case 'captain':
      case 'leader':
        return '캡틴';
      case 'crew_chief':
      case 'full':
        return '크루장';
      case 'guardian':
        return '가디언';
      default:
        return '크루';
    }
  }

  String get _timeAgo {
    if (lastUpdated == null) return '';
    final diff = DateTime.now().difference(lastUpdated!);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  IconData get _batteryIcon {
    if (batteryLevel == null) return Icons.battery_unknown;
    if (batteryLevel! > 80) return Icons.battery_full;
    if (batteryLevel! > 50) return Icons.battery_5_bar;
    if (batteryLevel! > 20) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이름 + 역할
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOffline ? AppColors.mapMarkerOffline : _roleColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(userName, style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _roleLabel,
                      style: AppTypography.labelSmall.copyWith(
                        color: _roleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onClose,
                      child: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // 마지막 업데이트 + 배터리
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOffline)
                    Text(
                      '오프라인',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.mapMarkerOffline,
                      ),
                    )
                  else if (lastUpdated != null)
                    Text(
                      _timeAgo,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  if (batteryLevel != null) ...[
                    const SizedBox(width: 8),
                    Icon(_batteryIcon, size: 14,
                      color: batteryLevel! <= 20
                          ? AppColors.semanticError
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$batteryLevel%',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
