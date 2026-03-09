import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 첨부 메뉴 바텀시트 위젯 (DOC-T3-CHT-020 SS7.1).
///
/// [+] 버튼 탭 시 나타나는 바텀시트로, 다음 항목을 제공한다:
///   - 사진/동영상 (갤러리 또는 카메라)
///   - 현재 위치 공유
///   - 일정 공유
///   - 파일 첨부
///
/// 미구현 항목은 "준비 중입니다" SnackBar를 표시한다.
class AttachmentMenuWidget extends StatelessWidget {
  const AttachmentMenuWidget({
    super.key,
    this.onPickPhoto,
    this.onShareLocation,
    this.onShareSchedule,
    this.onPickFile,
  });

  /// 사진/동영상 선택 콜백.
  final VoidCallback? onPickPhoto;

  /// 현재 위치 공유 콜백.
  final VoidCallback? onShareLocation;

  /// 일정 공유 콜백.
  final VoidCallback? onShareSchedule;

  /// 파일 첨부 콜백.
  final VoidCallback? onPickFile;

  /// 바텀시트를 표시하는 정적 헬퍼 메서드.
  static void show(
    BuildContext context, {
    VoidCallback? onPickPhoto,
    VoidCallback? onShareLocation,
    VoidCallback? onShareSchedule,
    VoidCallback? onPickFile,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttachmentMenuWidget(
        onPickPhoto: onPickPhoto,
        onShareLocation: onShareLocation,
        onShareSchedule: onShareSchedule,
        onPickFile: onPickFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.bottomSheetRadius),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들 바
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: AppSpacing.bottomSheetHandleWidth,
              height: AppSpacing.bottomSheetHandleHeight,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius:
                    BorderRadius.circular(AppSpacing.bottomSheetHandleHeight / 2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 타이틀
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '첨부',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 메뉴 항목
            _buildMenuItem(
              context,
              icon: Icons.photo_camera_outlined,
              iconColor: const Color(0xFF2196F3),
              label: '사진/동영상',
              description: '갤러리에서 선택 또는 카메라 촬영',
              onTap: onPickPhoto,
            ),
            _buildMenuItem(
              context,
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFF4CAF50),
              label: '현재 위치 공유',
              description: '위치 카드 생성',
              onTap: onShareLocation,
            ),
            _buildMenuItem(
              context,
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFFFF9800),
              label: '일정 공유',
              description: '이 여행의 일정 목록에서 선택',
              onTap: onShareSchedule,
            ),
            _buildMenuItem(
              context,
              icon: Icons.attach_file_outlined,
              iconColor: const Color(0xFF9C27B0),
              label: '파일 첨부',
              description: '파일 선택 (최대 50MB)',
              onTap: onPickFile,
            ),

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String description,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        if (onTap != null) {
          onTap();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('준비 중입니다'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radius12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
