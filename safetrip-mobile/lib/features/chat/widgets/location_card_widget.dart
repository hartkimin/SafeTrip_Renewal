import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 위치 공유 카드 위젯 (DOC-T3-CHT-020 SS7.3).
///
/// 위치 데이터를 카드 형태로 표시한다:
///   - 미니 맵 영역 (100dp 높이, 현재는 placeholder)
///   - 주소 텍스트
///   - 공유 시각
///   - [지도에서 보기] 버튼
class LocationCardWidget extends StatelessWidget {
  const LocationCardWidget({
    super.key,
    required this.message,
    this.onViewMap,
  });

  /// 위치 메시지 맵. 필요한 키:
  ///   - `location_data` (Map): { address, place_name, lat, lng }
  ///   - `created_at` (String?): 공유 시각
  ///   - `sender_name` (String?): 공유자 이름
  final Map<String, dynamic> message;

  /// [지도에서 보기] 버튼 콜백. null이면 SnackBar 표시.
  final VoidCallback? onViewMap;

  @override
  Widget build(BuildContext context) {
    final locationData = message['location_data'] as Map<String, dynamic>? ?? {};
    final address = locationData['address'] as String? ??
        locationData['place_name'] as String? ??
        '위치 정보 없음';
    final senderName = message['sender_name'] as String? ?? '';
    final createdAt = message['created_at'] as String?;
    final timeStr = _formatTime(createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 미니 맵 placeholder (100dp 높이)
            Container(
              height: 100,
              width: double.infinity,
              color: AppColors.surfaceVariant,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 32,
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '지도 미리보기',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 위치 정보
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 공유자 이름
                  if (senderName.isNotEmpty) ...[
                    Text(
                      '$senderName님의 위치',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // 주소
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '\u{1F4CD} ',
                        style: TextStyle(fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          address,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // 시각
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],

                  // 지도에서 보기 버튼
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onViewMap ??
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('지도 탭에서 확인할 수 있습니다'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('지도에서 보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryTeal,
                        side: BorderSide(
                          color: AppColors.primaryTeal.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radius8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
