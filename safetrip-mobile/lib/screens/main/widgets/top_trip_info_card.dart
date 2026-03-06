import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/main/providers/main_screen_provider.dart';
import '../../../features/trip/providers/trip_provider.dart';
import '../../../router/route_paths.dart';

/// 상단 여행 정보 카드 (화면구성원칙 §3)
///
/// tripProvider에서 여행명·국가·D+N/D-N·멤버수·프라이버시 등급을 읽어 표시한다.
class TopTripInfoCard extends ConsumerWidget {
  const TopTripInfoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripState = ref.watch(tripProvider);
    final mainState = ref.watch(mainScreenProvider);

    final tripName = tripState.currentTripName.isNotEmpty
        ? tripState.currentTripName
        : '여행 정보를 불러오는 중...';
    final status = tripState.currentTripStatus;
    final role = tripState.currentUserRole;
    final isAdmin = role == 'captain' || role == 'crew_chief';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          // 프라이버시 등급 아이콘 (캡틴/크루장에게만)
          if (isAdmin) ...[
            _buildPrivacyIcon(tripState.currentTrip?.privacyLevel),
            const SizedBox(width: AppSpacing.sm),
          ],

          // 여행 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 상태 + D+N/D-N + 국가 + 멤버수
                Row(
                  children: [
                    _buildStatusBadge(status),
                    const SizedBox(width: 6),
                    Text(
                      _buildDayString(
                        status,
                        tripState.tripStartDate,
                        tripState.tripEndDate,
                      ),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tripState.countryName != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${tripState.countryName}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    if (tripState.totalMemberCount > 0) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.people_outline,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${tripState.totalMemberCount}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // 여행명
                Text(
                  tripName,
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 알림 아이콘 + 미읽음 뱃지
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: '알림',
                onPressed: () => context.push(RoutePaths.notifications),
              ),
              if (mainState.unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.sosDanger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      mainState.unreadCount > 99
                          ? '99+'
                          : '${mainState.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // AI 브리핑
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF7C4DFF)),
            tooltip: 'AI 브리핑',
            onPressed: () => context.push(RoutePaths.aiBriefing),
          ),

          // 설정
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: () => context.push(RoutePaths.settingsMain),
          ),
        ],
      ),
    );
  }

  /// D+N (active) / D-N (planning) / 완료 계산
  String _buildDayString(
    String status,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final now = DateTime.now();

    if (status == 'active' && startDate != null) {
      final days = now.difference(startDate).inDays;
      return 'D+$days';
    } else if (status == 'planning' && startDate != null) {
      final days = startDate.difference(now).inDays;
      return days >= 0 ? 'D-$days' : 'D+${days.abs()}';
    } else if (status == 'completed') {
      return '종료됨';
    }
    return '';
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = AppColors.tripActive;
        label = '여행 중';
        break;
      case 'planning':
        bgColor = AppColors.tripPlanning;
        label = '준비 중';
        break;
      case 'completed':
        bgColor = AppColors.tripCompleted;
        label = '완료';
        break;
      default:
        bgColor = AppColors.textTertiary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bgColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPrivacyIcon(String? privacyLevel) {
    IconData icon;
    Color color;

    switch (privacyLevel) {
      case 'safety_first':
        icon = Icons.shield;
        color = AppColors.privacySafetyFirst;
        break;
      case 'standard':
        icon = Icons.location_on;
        color = AppColors.privacyStandard;
        break;
      case 'privacy_first':
        icon = Icons.lock;
        color = AppColors.privacyFirst;
        break;
      default:
        icon = Icons.location_on;
        color = AppColors.privacyStandard;
    }

    return Tooltip(
      message: _privacyLabel(privacyLevel),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _privacyLabel(String? level) {
    switch (level) {
      case 'safety_first':
        return '안전최우선 — 위치가 항상 공유됩니다';
      case 'standard':
        return '표준 — 스케줄 외 저빈도 공유';
      case 'privacy_first':
        return '프라이버시우선 — 비공유 시간';
      default:
        return '표준';
    }
  }
}
