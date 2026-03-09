import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/demo_state_provider.dart';

/// §3.2: 데모 타임 슬라이더 — D-7 ~ D+N+3 (최대 D+15)
class DemoTimeSlider extends ConsumerStatefulWidget {
  const DemoTimeSlider({super.key});

  @override
  ConsumerState<DemoTimeSlider> createState() => _DemoTimeSliderState();
}

class _DemoTimeSliderState extends ConsumerState<DemoTimeSlider> {
  bool _showMaxTooltip = false;

  @override
  Widget build(BuildContext context) {
    final demoState = ref.watch(demoStateProvider);
    final scenario = demoState.currentScenario;
    if (scenario == null) return const SizedBox.shrink();

    final durationDays = scenario.durationDays;
    // Range: -7 to durationDays + 3, clamped at 15 total days from trip start
    final maxDay = (durationDays + 3).clamp(0, 15);
    const minDay = -7;
    final totalRange = maxDay - minDay; // total slider range in days

    // Calculate current position from simStartTime / currentSimTime
    final simStart = demoState.simStartTime ?? DateTime.now();
    final simCurrent = demoState.currentSimTime ?? simStart;
    final diffMinutes = simCurrent.difference(simStart).inMinutes;
    final currentDayValue =
        (diffMinutes / (24 * 60)).clamp(minDay.toDouble(), maxDay.toDouble());

    // Segment boundaries (normalized 0-1)
    final preEnd = 7.0 / totalRange; // D-7 to D+0
    final tripEnd = (7 + durationDays) / totalRange; // D+0 to D+N

    return Material(
      type: MaterialType.transparency,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Labels row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('D-7', style: _labelStyle(AppColors.semanticInfo)),
              Text('여행 중',
                  style: _labelStyle(AppColors.primaryCoral)),
              Text('D+${maxDay - 7}',
                  style: _labelStyle(AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 4),

          // Current position label
          Text(
            _formatDayLabel(currentDayValue),
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),

          // Slider with color segments
          Stack(
            children: [
              // Background segments
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: CustomPaint(
                    size: const Size(double.infinity, 6),
                    painter: _SegmentPainter(
                      preEnd: preEnd,
                      tripEnd: tripEnd,
                    ),
                  ),
                ),
              ),

              // Slider
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: AppColors.primaryTeal,
                  overlayColor:
                      AppColors.primaryTeal.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: currentDayValue,
                  min: minDay.toDouble(),
                  max: maxDay.toDouble(),
                  onChanged: (value) {
                    // D+16 clamp check
                    if (value >= maxDay.toDouble() && maxDay >= 15) {
                      if (!_showMaxTooltip) {
                        HapticFeedback.heavyImpact();
                        setState(() => _showMaxTooltip = true);
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            setState(() => _showMaxTooltip = false);
                          }
                        });
                      }
                      return;
                    }
                    final newTime = simStart.add(
                      Duration(minutes: (value * 24 * 60).round()),
                    );
                    ref.read(demoStateProvider.notifier).setSimTime(newTime);
                  },
                ),
              ),
            ],
          ),

          // Max day tooltip
          if (_showMaxTooltip)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '여행은 최대 15일까지 설정 가능합니다. 분할 생성해 주세요',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textWarning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  String _formatDayLabel(double dayValue) {
    final day = dayValue.floor();
    final hourFraction = (dayValue - day) * 24;
    final hour = hourFraction.round().clamp(0, 23);

    if (day < 0) {
      return 'D$day ${hour.toString().padLeft(2, '0')}:00';
    } else if (day == 0) {
      return 'D-Day ${hour.toString().padLeft(2, '0')}:00';
    } else {
      return 'D+$day ${hour.toString().padLeft(2, '0')}:00';
    }
  }

  TextStyle _labelStyle(Color color) {
    return AppTypography.labelSmall.copyWith(
      color: color,
      fontWeight: FontWeight.w500,
    );
  }
}

class _SegmentPainter extends CustomPainter {
  _SegmentPainter({required this.preEnd, required this.tripEnd});
  final double preEnd;
  final double tripEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final prePaint = Paint()
      ..color = AppColors.semanticInfo.withValues(alpha: 0.3);
    final tripPaint = Paint()
      ..color = AppColors.primaryCoral.withValues(alpha: 0.4);
    final postPaint = Paint()
      ..color = AppColors.textTertiary.withValues(alpha: 0.2);

    // Pre-trip segment (D-7 to D+0)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * preEnd, size.height),
      prePaint,
    );
    // Trip segment (D+0 to D+N)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * preEnd,
        0,
        size.width * (tripEnd - preEnd),
        size.height,
      ),
      tripPaint,
    );
    // Post-trip segment (D+N to end)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * tripEnd,
        0,
        size.width * (1 - tripEnd),
        size.height,
      ),
      postPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SegmentPainter old) =>
      old.preEnd != preEnd || old.tripEnd != tripEnd;
}
