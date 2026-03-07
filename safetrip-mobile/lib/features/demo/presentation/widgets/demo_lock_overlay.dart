import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/demo_state_provider.dart';

/// §3.4: 역할별 접근 불가 기능에 자물쇠 아이콘 + 그레이아웃 오버레이
class DemoLockOverlay extends ConsumerWidget {
  const DemoLockOverlay({
    super.key,
    required this.feature,
    required this.child,
    this.message,
  });

  final String feature;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoState = ref.watch(demoStateProvider);
    if (!demoState.isActive || demoState.canAccess(feature)) {
      return child;
    }
    return Stack(
      children: [
        Opacity(opacity: 0.3, child: IgnorePointer(child: child)),
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (message != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message!),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 32, color: AppColors.textTertiary),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
