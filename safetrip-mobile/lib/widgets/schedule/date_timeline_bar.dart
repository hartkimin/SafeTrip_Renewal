import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 여행 일정 날짜 타임라인 바
/// 여행 기간(최대 15일) 내 날짜를 가로 스크롤로 표시한다.
/// - 오늘: 틸 테두리 + 볼드
/// - 선택됨: 틸 배경 틴트
/// - 일정 있음: 날짜 아래 작은 파란 점
class DateTimelineBar extends StatefulWidget {
  const DateTimelineBar({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.scheduleDates,
    required this.onDateSelected,
  });

  /// 여행 날짜 목록 (최대 15개)
  final List<DateTime> dates;

  /// 현재 선택된 날짜
  final DateTime selectedDate;

  /// 일정이 있는 날짜 ('YYYY-MM-DD' 형식)
  final List<String> scheduleDates;

  /// 날짜 탭 콜백
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<DateTimelineBar> createState() => _DateTimelineBarState();
}

class _DateTimelineBarState extends State<DateTimelineBar> {
  late ScrollController _scrollController;
  static const double _itemWidth = 56.0;
  static const double _itemSpacing = 8.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(covariant DateTimelineBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final index = widget.dates.indexWhere((d) =>
        d.year == widget.selectedDate.year &&
        d.month == widget.selectedDate.month &&
        d.day == widget.selectedDate.day);
    if (index < 0 || !_scrollController.hasClients) return;

    final targetOffset =
        index * (_itemWidth + _itemSpacing) - (_itemWidth * 2);
    final maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dates.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateFormatter = DateFormat('yyyy-MM-dd');

    return Container(
      height: 80,
      color: AppColors.surface,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.sm,
        ),
        itemCount: widget.dates.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: _itemSpacing),
        itemBuilder: (context, index) {
          final date = widget.dates[index];
          final dateOnly = DateTime(date.year, date.month, date.day);
          final isToday = dateOnly == today;
          final isSelected =
              dateOnly.year == widget.selectedDate.year &&
                  dateOnly.month == widget.selectedDate.month &&
                  dateOnly.day == widget.selectedDate.day;
          final hasSchedule = widget.scheduleDates
              .contains(dateFormatter.format(dateOnly));

          return _DateItem(
            date: dateOnly,
            isToday: isToday,
            isSelected: isSelected,
            hasSchedule: hasSchedule,
            onTap: () => widget.onDateSelected(dateOnly),
          );
        },
      ),
    );
  }
}

class _DateItem extends StatelessWidget {
  const _DateItem({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.hasSchedule,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool hasSchedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat.E('ko').format(date);
    final dayNumber = date.day.toString();

    Color bgColor;
    Color textColor;
    Border? border;

    if (isSelected) {
      bgColor = AppColors.primaryTeal.withValues(alpha: 0.12);
      textColor = AppColors.textPrimary;
      border = Border.all(color: AppColors.primaryTeal, width: 2);
    } else if (isToday) {
      bgColor = Colors.transparent;
      textColor = AppColors.primaryTeal;
      border = Border.all(color: AppColors.primaryTeal, width: 1.5);
    } else {
      bgColor = Colors.transparent;
      textColor = AppColors.textTertiary;
      border = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 요일
            Text(
              dayName,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected || isToday
                    ? AppColors.primaryTeal
                    : AppColors.textTertiary,
                fontWeight:
                    isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            // 날짜 원형
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: border,
              ),
              alignment: Alignment.center,
              child: Text(
                dayNumber,
                style: AppTypography.labelLarge.copyWith(
                  color: textColor,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // 일정 있음 표시 (작은 점)
            if (hasSchedule)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTeal,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 4, height: 4),
          ],
        ),
      ),
    );
  }
}
