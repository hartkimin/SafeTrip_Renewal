import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/demo_state_provider.dart';
import 'demo_coachmark_data.dart';

/// §3.7: Coachmark overlay with tooltip, arrow triangle, and semi-transparent backdrop.
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

    // Position tooltip relative to target based on arrow direction
    final bool tooltipAbove = coachmark.arrowDirection == ArrowDirection.down;
    final tooltipTop = tooltipAbove
        ? targetRect.top - 120
        : targetRect.bottom + 20; // space for arrow

    final tooltipLeft =
        (targetRect.center.dx - 140).clamp(16.0, screenSize.width - 296);

    // Arrow position
    final arrowCenterX = targetRect.center.dx.clamp(32.0, screenSize.width - 32.0);

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

            // Arrow triangle (§3.7: 포인팅 화살표 포함)
            if (coachmark.arrowDirection == ArrowDirection.down)
              Positioned(
                top: targetRect.top - 12,
                left: arrowCenterX - 8,
                child: CustomPaint(
                  size: const Size(16, 10),
                  painter: _ArrowPainter(
                    direction: ArrowDirection.down,
                    color: Colors.white,
                  ),
                ),
              )
            else if (coachmark.arrowDirection == ArrowDirection.up)
              Positioned(
                top: targetRect.bottom + 2,
                left: arrowCenterX - 8,
                child: CustomPaint(
                  size: const Size(16, 10),
                  painter: _ArrowPainter(
                    direction: ArrowDirection.up,
                    color: Colors.white,
                  ),
                ),
              )
            else if (coachmark.arrowDirection == ArrowDirection.left)
              Positioned(
                top: targetRect.center.dy - 5,
                left: targetRect.right + 2,
                child: CustomPaint(
                  size: const Size(10, 16),
                  painter: _ArrowPainter(
                    direction: ArrowDirection.left,
                    color: Colors.white,
                  ),
                ),
              )
            else if (coachmark.arrowDirection == ArrowDirection.right)
              Positioned(
                top: targetRect.center.dy - 5,
                left: targetRect.left - 12,
                child: CustomPaint(
                  size: const Size(10, 16),
                  painter: _ArrowPainter(
                    direction: ArrowDirection.right,
                    color: Colors.white,
                  ),
                ),
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

/// §3.7: 포인팅 화살표 삼각형
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.direction, required this.color});
  final ArrowDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();

    switch (direction) {
      case ArrowDirection.up:
        path.moveTo(0, size.height);
        path.lineTo(size.width / 2, 0);
        path.lineTo(size.width, size.height);
      case ArrowDirection.down:
        path.moveTo(0, 0);
        path.lineTo(size.width / 2, size.height);
        path.lineTo(size.width, 0);
      case ArrowDirection.left:
        // Arrow points left (from right to left)
        path.moveTo(size.width, 0);
        path.lineTo(0, size.height / 2);
        path.lineTo(size.width, size.height);
      case ArrowDirection.right:
        // Arrow points right (from left to right)
        path.moveTo(0, 0);
        path.lineTo(size.width, size.height / 2);
        path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) =>
      old.direction != direction || old.color != color;
}
