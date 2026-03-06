import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/schedule/providers/schedule_provider.dart';
import '../../../features/trip/providers/trip_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/schedule/date_timeline_bar.dart';
import '../../../widgets/schedule/schedule_card.dart';
import '../../../widgets/schedule/share_timeline_bar.dart';
import '../../../models/schedule.dart';
import 'modals/add_schedule_modal.dart';
import 'modals/ai_schedule_modal.dart';

/// 일정 탭 바텀시트 콘텐츠 (화면구성원칙 $4 탭 1)
///
/// 부모 [SnappingBottomSheet]로부터 [ScrollController]를 수신하여
/// 스크롤과 드래그 제스처가 연동된다.
///
/// 5 Regions:
///   A: Privacy banner (privacy_first only)
///   B: Date timeline bar
///   C: Share timeline placeholder (Phase 2)
///   D: Schedule card list
///   E: Add schedule button (captain/crew_chief only)
class BottomSheetTrip extends ConsumerStatefulWidget {
  const BottomSheetTrip({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  ConsumerState<BottomSheetTrip> createState() => _BottomSheetTripState();
}

class _BottomSheetTripState extends ConsumerState<BottomSheetTrip> {
  int _selectedTab = 0; // 0: 일정, 1: 장소
  bool _tripContextInitialized = false;

  @override
  void initState() {
    super.initState();
    // 초기 tripProvider 상태가 이미 로드되어 있으면 바로 setTripContext 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScheduleFromTrip();
    });
  }

  /// tripProvider에서 여행 정보를 읽어 scheduleProvider에 컨텍스트를 설정한다.
  void _initScheduleFromTrip() {
    final tripState = ref.read(tripProvider);
    final trip = tripState.currentTrip;
    if (trip == null || _tripContextInitialized) return;

    final startDate = tripState.tripStartDate ?? trip.startDate;
    final endDate = tripState.tripEndDate ?? trip.endDate;
    final userRole = tripState.currentUserRole;
    final tripStatus = tripState.currentTripStatus;

    ref.read(scheduleProvider.notifier).setTripContext(
          tripId: trip.tripId,
          startDate: startDate,
          endDate: endDate,
          privacyLevel: trip.privacyLevel,
          userRole: userRole,
          tripStatus: tripStatus,
        );
    _tripContextInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final scheduleState = ref.watch(scheduleProvider);
    final tripState = ref.watch(tripProvider);

    // tripProvider가 변경되면 scheduleProvider에 컨텍스트 재설정
    ref.listen<TripState>(tripProvider, (prev, next) {
      final trip = next.currentTrip;
      if (trip != null &&
          (prev?.currentTrip?.tripId != trip.tripId || !_tripContextInitialized)) {
        final startDate = next.tripStartDate ?? trip.startDate;
        final endDate = next.tripEndDate ?? trip.endDate;

        ref.read(scheduleProvider.notifier).setTripContext(
              tripId: trip.tripId,
              startDate: startDate,
              endDate: endDate,
              privacyLevel: trip.privacyLevel,
              userRole: next.currentUserRole,
              tripStatus: next.currentTripStatus,
            );
        _tripContextInitialized = true;
      }
    });

    return Column(
      children: [
        _buildTabs(),
        if (_selectedTab == 0) ...[
          // Region A: Privacy banner (only for privacy_first)
          if (scheduleState.showPrivacyBanner) _buildPrivacyBanner(),
          // Region B: Date timeline bar
          if (scheduleState.tripDates.isNotEmpty)
            DateTimelineBar(
              dates: scheduleState.tripDates,
              selectedDate: scheduleState.selectedDate ?? DateTime.now(),
              scheduleDates: scheduleState.scheduleDates,
              onDateSelected: (date) =>
                  ref.read(scheduleProvider.notifier).selectDate(date),
            ),
          // Region C: Share timeline (privacy_first only)
          if (scheduleState.showShareTimeline)
            ShareTimelineBar(
              segments: scheduleState.shareTimelineSegments,
            ),
          // Region D: Schedule card list
          Expanded(child: _buildScheduleCardList(scheduleState)),
          // Region E: Add schedule button (captain/crew_chief only)
          if (scheduleState.canEdit) _buildAddButton(),
        ] else
          Expanded(child: _buildPlaceList()),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Sub-tabs (일정 | 장소) — 기존 스타일 유지
  // ──────────────────────────────────────────────

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radius12),
              ),
              child: Row(
                children: [
                  _buildTabItem(0, '일정', Icons.calendar_today),
                  _buildTabItem(1, '장소', Icons.location_on),
                ],
              ),
            ),
          ),
          // 더보기 메뉴 (AI 추천, 내보내기)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textTertiary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            onSelected: (value) {
              switch (value) {
                case 'ai':
                  _showAIModal();
                  break;
                case 'ics':
                  _exportICS();
                  break;
                case 'text':
                  _exportText();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'ai', child: Text('AI 일정 추천')),
              PopupMenuItem(value: 'ics', child: Text('iCal 내보내기')),
              PopupMenuItem(value: 'text', child: Text('텍스트 내보내기')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radius8),
            boxShadow: isSelected
                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.primaryTeal
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Region A: Privacy Banner
  // ──────────────────────────────────────────────

  Widget _buildPrivacyBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.semanticInfo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radius8),
        border: Border.all(color: AppColors.semanticInfo.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 16, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '일정 연동 공유 모드 활성 \u2014 일정 시간대에만 위치가 공유됩니다',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Region D: Schedule Card List
  // ──────────────────────────────────────────────

  Widget _buildScheduleCardList(ScheduleState scheduleState) {
    // Loading
    if (scheduleState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (scheduleState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scheduleState.error!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: () =>
                    ref.read(scheduleProvider.notifier).fetchSchedules(),
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty
    if (scheduleState.schedules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 48,
                color: AppColors.textTertiary.withOpacity(0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '이 날짜에 등록된 일정이 없습니다',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              if (scheduleState.canEdit) ...[
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: _showAddScheduleModal,
                  icon: const Icon(Icons.add),
                  label: const Text('일정 추가하기'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTeal,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Sort: current first, then upcoming/future, then past
    final sorted = _sortSchedules(scheduleState.schedules);

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        return ScheduleCard(
          schedule: entry.schedule,
          status: entry.status,
          canEdit: scheduleState.canEdit,
          onTap: () {
            // TODO: 일정 상세 보기 / 수정 모달
          },
          onMapTap: entry.schedule.locationCoords != null
              ? () {
                  // TODO: 지도에서 위치 보기
                }
              : null,
        );
      },
    );
  }

  /// 일정 상태 판별 및 정렬
  /// - current: startTime <= now <= endTime
  /// - upcoming: now < startTime && startTime - now < 15min
  /// - past: endTime < now
  /// - future: else
  /// 정렬 순서: current -> upcoming -> future -> past
  List<_ScheduleEntry> _sortSchedules(List<Schedule> schedules) {
    final now = DateTime.now();
    final entries = <_ScheduleEntry>[];
    // §3: 진행 중 강조는 active 상태에서만 (planning/completed 제외)
    final scheduleState = ref.read(scheduleProvider);
    final isActive = scheduleState.tripStatus == 'active';

    for (final s in schedules) {
      final start = s.startTime;
      final end = s.endTime ?? s.startTime.add(const Duration(hours: 1));

      String status;
      if (isActive &&
          (start.isBefore(now) && end.isAfter(now) ||
              start.isAtSameMomentAs(now) ||
              end.isAtSameMomentAs(now))) {
        status = 'current';
      } else if (isActive &&
          now.isBefore(start) &&
          start.difference(now) < const Duration(minutes: 15)) {
        status = 'upcoming';
      } else if (end.isBefore(now)) {
        status = 'past';
      } else {
        status = 'future';
      }

      entries.add(_ScheduleEntry(schedule: s, status: status));
    }

    // Sort priority: current(0) > upcoming(1) > future(2) > past(3)
    int priority(String s) {
      switch (s) {
        case 'current':
          return 0;
        case 'upcoming':
          return 1;
        case 'future':
          return 2;
        case 'past':
          return 3;
        default:
          return 4;
      }
    }

    entries.sort((a, b) {
      final cmp = priority(a.status).compareTo(priority(b.status));
      if (cmp != 0) return cmp;
      return a.schedule.startTime.compareTo(b.schedule.startTime);
    });

    return entries;
  }

  // ──────────────────────────────────────────────
  // Region E: Add Schedule Button
  // ──────────────────────────────────────────────

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showAddScheduleModal,
          icon: const Icon(Icons.add),
          label: const Text('일정 추가'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryTeal,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  /// 일정 추가 모달 (AddScheduleModal)을 표시한다.
  void _showAddScheduleModal() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddScheduleModal(),
    );
    if (result == true) {
      ref.read(scheduleProvider.notifier).fetchSchedules();
      ref.read(scheduleProvider.notifier).fetchScheduleDates();
    }
  }

  // ──────────────────────────────────────────────
  // AI 추천 & 내보내기
  // ──────────────────────────────────────────────

  /// AI 일정 추천 모달을 표시한다.
  void _showAIModal() async {
    final scheduleState = ref.read(scheduleProvider);
    final tripId = scheduleState.tripId;
    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('여행이 선택되지 않았습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiScheduleModal(tripId: tripId),
    );
    if (result == true) {
      ref.read(scheduleProvider.notifier).fetchSchedules();
      ref.read(scheduleProvider.notifier).fetchScheduleDates();
    }
  }

  /// iCal(.ics) 형식으로 일정을 내보낸다.
  Future<void> _exportICS() async {
    final scheduleState = ref.read(scheduleProvider);
    final tripId = scheduleState.tripId;
    if (tripId == null) return;

    try {
      final apiService = ApiService();
      final result = await apiService.dio.get(
        '/api/v1/trips/$tripId/schedules/export/ics',
      );

      if (result.data != null) {
        // ICS 파일 내용을 임시 파일로 저장 후 공유
        final icsContent = result.data is String
            ? result.data as String
            : (result.data['data'] ?? '').toString();

        if (icsContent.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('내보낼 일정이 없습니다'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/safetrip_schedule.ics');
        await file.writeAsString(icsContent);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'SafeTrip 일정',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('iCal 내보내기에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 텍스트 형식으로 일정을 내보낸다.
  Future<void> _exportText() async {
    final scheduleState = ref.read(scheduleProvider);
    final tripId = scheduleState.tripId;
    if (tripId == null) return;

    try {
      final apiService = ApiService();
      final result = await apiService.dio.get(
        '/api/v1/trips/$tripId/schedules/export/pdf',
      );

      if (result.data != null) {
        final textContent = result.data is String
            ? result.data as String
            : (result.data['data'] ?? '').toString();

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.description_outlined,
                    size: 20, color: AppColors.primaryTeal),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '일정 텍스트',
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(
                  textContent.isEmpty ? '내보낼 일정이 없습니다' : textContent,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('텍스트 내보내기에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────
  // 장소 탭 (기존 유지)
  // ──────────────────────────────────────────────

  Widget _buildPlaceList() {
    return ListView(
      controller: widget.scrollController,
      children: const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('등록된 장소가 없습니다.'),
          ),
        ),
      ],
    );
  }
}

/// 일정 + 상태를 함께 보관하는 내부 헬퍼 클래스
class _ScheduleEntry {
  const _ScheduleEntry({
    required this.schedule,
    required this.status,
  });

  final Schedule schedule;
  final String status;
}
