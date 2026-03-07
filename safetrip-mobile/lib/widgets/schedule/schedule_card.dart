import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/schedule.dart';
import 'schedule_reactions.dart';
import 'schedule_comments.dart';

/// 날씨 정보 데이터 모델
class WeatherInfo {
  const WeatherInfo({
    required this.temp,
    required this.description,
    required this.icon,
    required this.humidity,
  });

  final double temp;
  final String description;
  final String icon;
  final int humidity;

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      temp: (json['temp'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      humidity: (json['humidity'] as num?)?.toInt() ?? 0,
    );
  }

  /// 날씨 아이콘 코드를 이모지로 변환한다.
  /// 서버가 이미 이모지를 반환하는 경우 그대로 사용한다.
  String get emoji {
    // 서버가 이미 이모지를 반환하면 그대로 사용
    if (icon.length > 3 || icon.contains('\u{FE0F}') || icon.codeUnits.any((c) => c > 127)) {
      return icon;
    }
    // OpenWeatherMap icon code -> emoji
    switch (icon) {
      case '01d':
        return '\u2600\uFE0F'; // sunny
      case '01n':
        return '\u{1F319}'; // crescent moon
      case '02d':
      case '02n':
        return '\u26C5'; // partly cloudy
      case '03d':
      case '03n':
      case '04d':
      case '04n':
        return '\u2601\uFE0F'; // cloudy
      case '09d':
      case '09n':
        return '\u{1F327}\uFE0F'; // rain
      case '10d':
      case '10n':
        return '\u{1F326}\uFE0F'; // rain with sun
      case '11d':
      case '11n':
        return '\u26C8\uFE0F'; // thunderstorm
      case '13d':
      case '13n':
        return '\u{1F328}\uFE0F'; // snow
      case '50d':
      case '50n':
        return '\u{1F32B}\uFE0F'; // fog
      default:
        return '\u{1F324}\uFE0F'; // default
    }
  }
}

/// 일정 카드 위젯
/// 시간, 아이콘, 제목, 위치, 상태 배지, 날씨, 소셜 바를 표시한다.
/// status: 'current' | 'upcoming' | 'past' | 'future'
class ScheduleCard extends ConsumerStatefulWidget {
  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.status,
    this.canEdit = false,
    this.onTap,
    this.onMapTap,
    this.weatherInfo,
    this.showSocialBar = true,
    this.tripId,
  });

  final Schedule schedule;
  final String status;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;
  final WeatherInfo? weatherInfo;
  final bool showSocialBar;
  final String? tripId;

  @override
  ConsumerState<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends ConsumerState<ScheduleCard> {
  bool _isSocialExpanded = false;

  /// schedule_type -> FontAwesome 아이콘 매핑 (7 types)
  static IconData _iconForType(String type) {
    switch (type) {
      case 'move':
        return FontAwesomeIcons.plane;
      case 'stay':
        return FontAwesomeIcons.hotel;
      case 'meal':
        return FontAwesomeIcons.utensils;
      case 'sightseeing':
        return FontAwesomeIcons.locationDot;
      case 'shopping':
        return FontAwesomeIcons.bagShopping;
      case 'meeting':
        return FontAwesomeIcons.userGroup;
      case 'other':
      default:
        return FontAwesomeIcons.thumbtack;
    }
  }

  /// schedule_type -> 아이콘 배경색
  static Color _iconBgForType(String type) {
    switch (type) {
      case 'move':
        return AppColors.scheduleMoveBg;
      case 'stay':
        return AppColors.scheduleStayBg;
      case 'meal':
        return AppColors.scheduleMealBg;
      case 'sightseeing':
        return AppColors.scheduleSightseeingBg;
      case 'shopping':
        return AppColors.scheduleShoppingBg;
      case 'meeting':
        return AppColors.scheduleMeetingBg;
      case 'other':
      default:
        return AppColors.scheduleOtherBg;
    }
  }

  /// schedule_type -> 아이콘 색상
  static Color _iconColorForType(String type) {
    switch (type) {
      case 'move':
        return AppColors.scheduleMoveIcon;
      case 'stay':
        return AppColors.scheduleStayIcon;
      case 'meal':
        return AppColors.scheduleMealIcon;
      case 'sightseeing':
        return AppColors.scheduleSightseeingIcon;
      case 'shopping':
        return AppColors.scheduleShoppingIcon;
      case 'meeting':
        return AppColors.primaryTeal;
      case 'other':
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPast = widget.status == 'past';
    final isCurrent = widget.status == 'current';
    final isUpcoming = widget.status == 'upcoming';

    final timeFormat = DateFormat('HH:mm');
    final startStr = timeFormat.format(widget.schedule.startTime);
    final endStr = widget.schedule.endTime != null
        ? timeFormat.format(widget.schedule.endTime!)
        : '';

    // 테두리 설정
    Border cardBorder;
    if (isCurrent) {
      cardBorder = Border.all(color: AppColors.primaryTeal, width: 2);
    } else if (isUpcoming) {
      cardBorder = Border.all(color: AppColors.secondaryAmber, width: 1.5);
    } else {
      cardBorder = Border.all(color: Colors.transparent, width: 0.5);
    }

    final effectiveTripId = widget.tripId ?? widget.schedule.tripId;

    return Opacity(
      opacity: isPast ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius12),
            border: cardBorder,
            boxShadow: [
              if (!isPast)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 기존 카드 콘텐츠 (시간 + 내용)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 좌측: 시간 컬럼 + 수직선
                    _buildTimeColumn(startStr, endStr, isCurrent),
                    // 우측: 콘텐츠
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppSpacing.cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상단: 아이콘 + 제목 + 날씨 + 상태배지 + 지도 버튼
                            Row(
                              children: [
                                _buildTypeIcon(),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.schedule.title,
                                        style: AppTypography.labelLarge
                                            .copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (widget.schedule.locationName !=
                                              null &&
                                          widget.schedule.locationName!
                                              .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 2),
                                          child: Text(
                                            widget
                                                .schedule.locationName!,
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              color:
                                                  AppColors.textTertiary,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // 날씨 표시
                                if (widget.weatherInfo != null) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  _buildWeatherIndicator(
                                      widget.weatherInfo!),
                                ],
                                // 상태 배지
                                if (isCurrent || isUpcoming) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  _buildStatusBadge(),
                                ],
                                // 지도 버튼
                                if (widget.schedule.locationCoords !=
                                        null &&
                                    widget.onMapTap != null) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  _buildMapButton(),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 소셜 바 (리액션 + 댓글 토글)
              if (widget.showSocialBar && effectiveTripId != null)
                _buildSocialBar(effectiveTripId),
            ],
          ),
        ),
      ),
    );
  }

  /// 소셜 바: 리액션 아이콘 + 댓글 아이콘, 탭 시 확장
  Widget _buildSocialBar(String tripId) {
    return Column(
      children: [
        // 구분선
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
          indent: AppSpacing.md,
          endIndent: AppSpacing.md,
        ),
        // 소셜 토글 버튼
        GestureDetector(
          onTap: () => setState(() => _isSocialExpanded = !_isSocialExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.thumb_up_alt_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '\uBC18\uC751', // 반응
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '\uB313\uAE00', // 댓글
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isSocialExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        // 확장 시 리액션 + 댓글 표시
        if (_isSocialExpanded)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.cardPadding,
              right: AppSpacing.cardPadding,
              bottom: AppSpacing.cardPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScheduleReactions(
                  tripId: tripId,
                  scheduleId: widget.schedule.scheduleId,
                ),
                const SizedBox(height: AppSpacing.sm),
                ScheduleComments(
                  tripId: tripId,
                  scheduleId: widget.schedule.scheduleId,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 날씨 인디케이터 (우측 상단)
  Widget _buildWeatherIndicator(WeatherInfo weather) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(weather.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 2),
          Text(
            '${weather.temp.round()}\u00B0',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 좌측 시간 컬럼 (시작~종료 + 수직 라인)
  Widget _buildTimeColumn(
      String startStr, String endStr, bool isCurrent) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.cardPadding,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Text(
            startStr,
            style: AppTypography.labelMedium.copyWith(
              color: isCurrent
                  ? AppColors.primaryTeal
                  : AppColors.textSecondary,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (endStr.isNotEmpty) ...[
            Expanded(
              child: Center(
                child: Container(
                  width: 1.5,
                  constraints: const BoxConstraints(minHeight: 8),
                  color: isCurrent
                      ? AppColors.primaryTeal.withValues(alpha: 0.4)
                      : AppColors.outlineVariant,
                ),
              ),
            ),
            Text(
              endStr,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  /// 일정 타입 아이콘
  Widget _buildTypeIcon() {
    final icon = _iconForType(widget.schedule.scheduleType);
    final bgColor = _iconBgForType(widget.schedule.scheduleType);
    final iconColor = _iconColorForType(widget.schedule.scheduleType);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
      ),
      alignment: Alignment.center,
      child: FaIcon(icon, size: 16, color: iconColor),
    );
  }

  /// 상태 배지 ('진행 중' / '곧 시작')
  Widget _buildStatusBadge() {
    final isCurrent = widget.status == 'current';
    final label = isCurrent ? '\uC9C4\uD589 \uC911' : '\uACE7 \uC2DC\uC791'; // 진행 중 / 곧 시작
    final color =
        isCurrent ? AppColors.primaryTeal : AppColors.secondaryAmber;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 지도 보기 버튼
  Widget _buildMapButton() {
    return GestureDetector(
      onTap: widget.onMapTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.map_outlined,
          size: 18,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
