import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/main/providers/map_layer_provider.dart';
import '../../../features/trip/providers/trip_provider.dart';

/// 레이어 토글 패널 바텀시트 (지도 원칙 §3)
void showLayerSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _LayerSettingsContent(),
  );
}

class _LayerSettingsContent extends ConsumerWidget {
  const _LayerSettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layerState = ref.watch(mapLayerProvider);
    final layerNotifier = ref.read(mapLayerProvider.notifier);
    final userRole = ref.watch(tripProvider).currentUserRole;
    final isLeader = userRole == 'captain' || userRole == 'crew_chief' || userRole == 'leader' || userRole == 'full';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('지도 레이어 설정', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _LayerToggleTile(
              icon: Icons.local_hospital,
              iconColor: Colors.green,
              title: '안전시설',
              subtitle: '병원, 경찰서, 대사관',
              value: layerState.layer1SafetyFacilities,
              onChanged: (_) => layerNotifier.toggleLayer1(),
            ),
            _LayerToggleTile(
              icon: Icons.people,
              iconColor: AppColors.mapMarkerCrew,
              title: '멤버 위치',
              subtitle: '그룹 멤버 실시간 위치 마커',
              value: layerState.layer2MemberMarkers,
              onChanged: (_) => layerNotifier.toggleLayer2(),
            ),
            _LayerToggleTile(
              icon: Icons.event,
              iconColor: AppColors.primaryTeal,
              title: '일정/장소',
              subtitle: '여행 일정 장소 핀 마커',
              value: layerState.layer3SchedulePlaces,
              onChanged: (_) => layerNotifier.toggleLayer3(),
            ),
            if (isLeader)
              _LayerToggleTile(
                icon: Icons.notifications_active,
                iconColor: AppColors.semanticWarning,
                title: '이벤트/알림',
                subtitle: '지오펜스 경보, 출석 체크 마커',
                value: layerState.layer4EventAlerts,
                onChanged: (_) => layerNotifier.toggleLayer4(),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _LayerToggleTile extends StatelessWidget {
  const _LayerToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: iconColor),
      title: Text(title, style: AppTypography.bodyMedium),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
