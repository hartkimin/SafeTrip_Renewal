import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.secondaryAmber,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '오프라인 상태입니다. 일부 기능이 제한됩니다.',
              style: AppTypography.bodySmall.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
