import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// 원터치 긴급전화 버튼 (S6: 즉시 행동, DOC-T3-SFG-021 §3.2.5)
/// - 최소 높이 56dp
/// - 빨간 배경 (#E53935) + 흰 전화기 아이콘
/// - 탭 -> 즉시 네이티브 전화 앱 연결
class EmergencyCallButton extends StatelessWidget {
  const EmergencyCallButton({
    super.key,
    required this.phoneNumber,
    required this.label,
    this.sublabel,
    this.is24h = true,
  });

  final String phoneNumber;
  final String label;
  final String? sublabel;
  final bool is24h;

  Future<void> _makeCall() async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56, // §3.2.5 최소 높이 56dp
      child: Material(
        color: const Color(0xFFE53935), // 빨간 배경
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
        child: InkWell(
          onTap: _makeCall,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.phone, color: Colors.white, size: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sublabel != null)
                        Text(
                          sublabel!,
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  phoneNumber,
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (is24h) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '24h',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
