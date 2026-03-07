import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 파일 첨부 표시 위젯.
///
/// 채팅 메시지에 첨부된 파일을 표시한다.
/// 업로드 중일 때 프로그레스를 보여주고,
/// 완료 후에는 다운로드 아이콘을 표시한다.
class FileAttachmentWidget extends StatelessWidget {
  const FileAttachmentWidget({
    super.key,
    required this.fileName,
    required this.fileSize,
    this.uploadProgress,
    this.onTap,
    this.isUploading = false,
  });

  /// 파일 이름.
  final String fileName;

  /// 파일 크기 (바이트 단위).
  final int fileSize;

  /// 업로드 진행률 (0.0 ~ 1.0).
  final double? uploadProgress;

  /// 파일 탭 콜백 (다운로드 등).
  final VoidCallback? onTap;

  /// 업로드 중 여부.
  final bool isUploading;

  /// 최대 허용 파일 크기: 50 MB.
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.insert_drive_file,
                color: AppColors.primaryTeal,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(fileSize),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (isUploading && uploadProgress != null) ...[
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: uploadProgress,
                  strokeWidth: 2,
                  color: AppColors.primaryTeal,
                ),
              ),
            ] else
              const Icon(
                Icons.download,
                color: AppColors.textTertiary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// 바이트를 사람이 읽을 수 있는 파일 크기 문자열로 변환한다.
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 파일 크기가 허용 범위 내인지 검증한다.
  static bool validateFileSize(int bytes) {
    return bytes <= maxFileSizeBytes;
  }
}
