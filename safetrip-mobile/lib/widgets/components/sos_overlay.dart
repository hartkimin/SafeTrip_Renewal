import 'package:flutter/material.dart';
import '../../constants/app_tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// SOS 긴급 오버레이 — Layer 6 (지도 원칙 §3, §4, §7.3)
class SosOverlay extends StatelessWidget {
  const SosOverlay({
    super.key,
    required this.userName,
    this.onDismiss,
    this.additionalSosUsers = const [],
  });

  final String userName;
  final VoidCallback? onDismiss;
  /// 동시 다수 SOS 시 추가 발신자 이름 (§7.3)
  final List<String> additionalSosUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.sm,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.sosDanger,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const _PulsingIcon(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SOS 긴급 알림 발송됨',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize16,
                        fontWeight: AppTokens.fontWeightBold,
                        color: AppColors.sosText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$userName님의 위치가 보호자에게 공유되고 있습니다',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.sosText.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 동시 다수 SOS 목록 (§7.3)
          if (additionalSosUsers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...additionalSosUsers.map((name) => Padding(
              padding: const EdgeInsets.only(left: 44, top: 2),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 14, color: AppColors.sosText),
                  const SizedBox(width: 6),
                  Text(
                    '$name님 SOS 발동 중',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.sosText.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

/// SOS 아이콘 (반복 스케일 애니메이션)
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.sosText,
        size: 28,
      ),
    );
  }
}
