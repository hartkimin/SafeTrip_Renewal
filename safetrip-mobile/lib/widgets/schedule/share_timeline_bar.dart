import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 24시간 타임라인 세그먼트 데이터 모델
/// privacy_first 모드에서 공유/버퍼/비공유 구간을 표현한다.
class TimelineSegment {
  const TimelineSegment({
    required this.start,
    required this.end,
    required this.type,
  });

  /// HH:mm 형식의 시작 시각
  final String start;

  /// HH:mm 형식의 종료 시각
  final String end;

  /// 세그먼트 유형: 'shared' | 'buffer' | 'off'
  final String type;

  factory TimelineSegment.fromJson(Map<String, dynamic> json) {
    return TimelineSegment(
      start: _extractHHmm(json['start'] as String),
      end: _extractHHmm(json['end'] as String),
      type: json['type'] as String,
    );
  }

  /// ISO datetime 또는 HH:mm 문자열에서 HH:mm 부분을 추출한다.
  static String _extractHHmm(String value) {
    if (value.contains('T')) {
      final dt = DateTime.parse(value);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return value;
  }

  /// HH:mm 문자열을 분(minutes) 단위로 변환한다.
  static int _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  /// 시작 시각을 분 단위로 반환한다.
  int get startMinutes => _parseMinutes(start);

  /// 종료 시각을 분 단위로 반환한다.
  int get endMinutes => _parseMinutes(end);

  /// 세그먼트의 지속 시간(분)을 반환한다.
  int get durationMinutes {
    final dur = endMinutes - startMinutes;
    return dur > 0 ? dur : 0;
  }
}

/// 영역 C: 공유 타임라인 바 (일정탭 원칙 S4)
/// privacy_first 모드에서만 표시한다.
/// 24시간 바에 공유/버퍼/비공유 구간을 시각화하며,
/// 현재 시각을 빨간 수직선으로 표시한다.
class ShareTimelineBar extends StatelessWidget {
  const ShareTimelineBar({
    super.key,
    required this.segments,
    this.onSegmentTap,
  });

  final List<TimelineSegment> segments;
  final ValueChanged<TimelineSegment>? onSegmentTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 타임라인 바 (CustomPaint)
          SizedBox(
            height: 32,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: onSegmentTap != null
                      ? (details) =>
                          _handleTap(details.localPosition.dx, constraints.maxWidth)
                      : null,
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 32),
                    painter: _TimelineBarPainter(
                      segments: segments,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // 시간 마커 (00, 06, 12, 18, 24)
          _buildHourMarkers(),
        ],
      ),
    );
  }

  /// 탭 위치에 해당하는 세그먼트를 찾아 콜백을 호출한다.
  void _handleTap(double tapX, double totalWidth) {
    if (onSegmentTap == null || segments.isEmpty) return;
    const totalMinutes = 24 * 60;
    final tappedMinute = (tapX / totalWidth * totalMinutes).round();

    for (final seg in segments) {
      if (tappedMinute >= seg.startMinutes && tappedMinute < seg.endMinutes) {
        onSegmentTap!(seg);
        return;
      }
    }
  }

  /// 00, 06, 12, 18, 24 시간 마커를 표시한다.
  Widget _buildHourMarkers() {
    const markers = ['00', '06', '12', '18', '24'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: markers
          .map(
            (label) => Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                fontSize: 10,
              ),
            ),
          )
          .toList(),
    );
  }
}

/// 24시간 타임라인 바를 그리는 CustomPainter.
/// 세그먼트별 색상을 비례 너비로 렌더링하고,
/// 현재 시각 위치에 빨간 수직선을 그린다.
class _TimelineBarPainter extends CustomPainter {
  _TimelineBarPainter({
    required this.segments,
  });

  final List<TimelineSegment> segments;

  static const int _totalMinutes = 24 * 60; // 1440

  @override
  void paint(Canvas canvas, Size size) {
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );

    // 전체 바를 surfaceVariant(off 색상)로 먼저 채운다.
    final bgPaint = Paint()..color = AppColors.surfaceVariant;
    canvas.drawRRect(barRect, bgPaint);

    // 클리핑: 둥근 모서리 안에서만 세그먼트를 그린다.
    canvas.save();
    canvas.clipRRect(barRect);

    // 각 세그먼트를 비례 너비로 그린다.
    for (final seg in segments) {
      final color = _colorForType(seg.type);
      final startX = (seg.startMinutes / _totalMinutes) * size.width;
      final endX = (seg.endMinutes / _totalMinutes) * size.width;
      final segWidth = endX - startX;

      if (segWidth <= 0) continue;

      final segPaint = Paint()..color = color;
      canvas.drawRect(
        Rect.fromLTWH(startX, 0, segWidth, size.height),
        segPaint,
      );
    }

    // 현재 시각 빨간 수직선
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final currentX = (currentMinutes / _totalMinutes) * size.width;

    final linePaint = Paint()
      ..color = const Color(0xFFEF4444) // red-500
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(currentX, 0),
      Offset(currentX, size.height),
      linePaint,
    );

    // 현재 시각 표시 작은 원 (상단)
    final dotPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, 0), 3, dotPaint);

    canvas.restore();
  }

  /// 세그먼트 유형에 따른 색상을 반환한다.
  Color _colorForType(String type) {
    switch (type) {
      case 'shared':
        return AppColors.primaryTeal;
      case 'buffer':
        return AppColors.primaryTeal.withOpacity(0.3);
      case 'off':
      default:
        return AppColors.surfaceVariant;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineBarPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}
