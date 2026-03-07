import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/demo_state_provider.dart';
import 'demo_coachmark_data.dart';

/// §3.7: Coachmark overlay with tooltip, arrow, and semi-transparent backdrop.
/// Shows once per coachmark per demo session. "Skip All" dismisses all.
class DemoCoachmarkOverlay extends ConsumerWidget {
  const DemoCoachmarkOverlay({
    super.key,
    required this.coachmark,
    required this.targetRect,
    required this.onDismiss,
    required this.onSkipAll,
  });

  final CoachmarkDef coachmark;
  final Rect targetRect;
  final VoidCallback onDismiss;
  final VoidCallback onSkipAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;

    // Position tooltip relative to target
    final tooltipTop = coachmark.arrowDirection == ArrowDirection.down
        ? targetRect.top - 100
        : targetRect.bottom + 12;

    final tooltipLeft =
        (targetRect.center.dx - 140).clamp(16.0, screenSize.width - 296);

    return GestureDetector(
      onTap: () {
        ref.read(demoStateProvider.notifier).markCoachmarkViewed(coachmark.id);
        onDismiss();
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Semi-transparent backdrop with cutout
            CustomPaint(
              size: screenSize,
              painter: _BackdropPainter(targetRect: targetRect),
            ),

            // Tooltip bubble
            Positioned(
              top: tooltipTop,
              left: tooltipLeft,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radius12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      coachmark.text,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            final notifier =
                                ref.read(demoStateProvider.notifier);
                            for (final cm in kDemoCoachmarks) {
                              notifier.markCoachmarkViewed(cm.id);
                            }
                            onSkipAll();
                          },
                          child: Text(
                            '모두 건너뛰기',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            '확인',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a semi-transparent overlay with a rounded-rect cutout around the target
class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.targetRect});
  final Rect targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw full overlay then cut out target area
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, paint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(
      targetRect.inflate(4),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, clearPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.targetRect != targetRect;
}
