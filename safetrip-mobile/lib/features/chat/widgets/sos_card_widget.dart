import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// SOS CRITICAL 카드 위젯 (DOC-T3-CHT-020 SS5.1).
///
/// 빨간/코랄 배경 카드로 SOS 발신 정보를 표시한다.
///   - 발신자 이름
///   - 위치 주소 (location_data.address)
///   - 배터리 잔량 (location_data.battery_level)
///   - 액션 버튼: [지도에서 확인] [메시지] [119 안내]
///
/// SOS가 해제된 경우 회색 배경 + "해제됨" 텍스트로 전환된다.
class SosCardWidget extends StatelessWidget {
  const SosCardWidget({
    super.key,
    required this.message,
    this.onViewMap,
    this.onSendMessage,
    this.onCall119,
  });

  /// 시스템 메시지 맵. 필요한 키:
  ///   - `content` (String): 메시지 본문
  ///   - `sender_name` (String?): 발신자 이름
  ///   - `location_data` (Map?): { address, battery_level, lat, lng }
  ///   - `system_event_type` (String?): 'sos_resolved'이면 해제 상태
  final Map<String, dynamic> message;

  /// [지도에서 확인] 버튼 콜백. null이면 SnackBar 표시.
  final VoidCallback? onViewMap;

  /// [메시지] 버튼 콜백. null이면 SnackBar 표시.
  final VoidCallback? onSendMessage;

  /// [119 안내] 버튼 콜백. null이면 SnackBar 표시.
  final VoidCallback? onCall119;

  @override
  Widget build(BuildContext context) {
    final isResolved = _isResolved;
    final locationData = message['location_data'] as Map<String, dynamic>?;
    final senderName = message['sender_name'] as String? ?? '멤버';
    final address = locationData?['address'] as String? ??
        locationData?['place_name'] as String?;
    final batteryLevel = locationData?['battery_level'];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isResolved ? AppColors.surfaceVariant : const Color(0xFFFFF0EF),
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          border: Border.all(
            color: isResolved
                ? AppColors.outlineVariant
                : AppColors.sosDanger.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS 헤더
            Row(
              children: [
                if (isResolved)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.textTertiary,
                    size: 20,
                  )
                else
                  const Text(
                    '\u{1F6A8}',
                    style: TextStyle(fontSize: 18),
                  ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    isResolved
                        ? '$senderName님의 SOS가 해제되었습니다.'
                        : '$senderName님이 SOS를 발신했습니다.',
                    style: AppTypography.labelMedium.copyWith(
                      color: isResolved
                          ? AppColors.textTertiary
                          : AppColors.semanticError,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // 위치 정보
            if (address != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u{1F4CD} ',
                    style: TextStyle(
                      fontSize: 14,
                      color: isResolved
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '위치: $address',
                      style: AppTypography.bodySmall.copyWith(
                        color: isResolved
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 배터리 정보
            if (batteryLevel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '\u{1F50B} ',
                    style: TextStyle(
                      fontSize: 14,
                      color: isResolved
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '배터리: $batteryLevel%',
                    style: AppTypography.bodySmall.copyWith(
                      color: isResolved
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],

            // 해제됨 배지
            if (isResolved) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '해제됨',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],

            // 액션 버튼 (해제되지 않은 경우만)
            if (!isResolved) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _buildActionButton(
                    context,
                    label: '지도에서 확인',
                    icon: Icons.map_outlined,
                    onTap: onViewMap,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildActionButton(
                    context,
                    label: '메시지',
                    icon: Icons.chat_bubble_outline,
                    onTap: onSendMessage,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _buildActionButton(
                    context,
                    label: '119 안내',
                    icon: Icons.phone_outlined,
                    onTap: onCall119,
                    isEmergency: true,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _isResolved {
    final eventType = message['system_event_type'] as String?;
    return eventType == 'sos_resolved';
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    bool isEmergency = false,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('준비 중입니다'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isEmergency ? AppColors.semanticError : AppColors.primaryTeal,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isEmergency ? AppColors.semanticError : AppColors.primaryTeal,
          side: BorderSide(
            color: isEmergency
                ? AppColors.semanticError.withValues(alpha: 0.4)
                : AppColors.primaryTeal.withValues(alpha: 0.4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius8),
          ),
        ),
      ),
    );
  }
}
