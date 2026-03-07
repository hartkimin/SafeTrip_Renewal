import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/movement_history_provider.dart';
import '../widgets/timeline_view.dart';
import '../widgets/map_route_view.dart';
import '../widgets/date_navigator.dart';
import '../widgets/session_stats_card.dart';
import '../widgets/guardian_upgrade_modal.dart';

class MovementHistoryScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String targetUserId;
  final String memberName;

  const MovementHistoryScreen({
    super.key,
    required this.tripId,
    required this.targetUserId,
    required this.memberName,
  });

  @override
  ConsumerState<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends ConsumerState<MovementHistoryScreen> {
  late DateTime _selectedDate;
  final ScrollController _timelineScrollController = ScrollController();
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _loadData() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    ref
        .read(movementHistoryProvider((
          tripId: widget.tripId,
          targetUserId: widget.targetUserId,
        )).notifier)
        .loadHistory(dateStr);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movementHistoryProvider((
      tripId: widget.tripId,
      targetUserId: widget.targetUserId,
    )));

    // §9.3 가디언 업그레이드 모달 자동 표시
    if (state.upgradeRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GuardianUpgradeModal.show(
          context,
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.memberName} 이동기록'),
      ),
      body: Column(
        children: [
          // 날짜 선택기
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DateNavigator(
              selectedDate: _selectedDate,
              maxDate: DateTime.now(),
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
                _loadData();
              },
            ),
          ),

          // 뷰 모드 탭 (M2 이중 뷰)
          _buildViewModeTab(state),

          // 통계 카드
          if (state.sessionStats != null)
            SessionStatsCard(stats: state.sessionStats!),

          // 메인 콘텐츠
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text(state.error!, style: const TextStyle(color: Colors.red)))
                    : _buildMainContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeTab(MovementHistoryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'timeline', icon: Icon(Icons.timeline), label: Text('타임라인')),
          ButtonSegment(value: 'map', icon: Icon(Icons.map), label: Text('지도')),
        ],
        selected: {state.viewMode},
        onSelectionChanged: (selected) {
          ref
              .read(movementHistoryProvider((
                tripId: widget.tripId,
                targetUserId: widget.targetUserId,
              )).notifier)
              .toggleViewMode();
        },
      ),
    );
  }

  Widget _buildMainContent(MovementHistoryState state) {
    if (state.viewMode == 'timeline') {
      return TimelineView(
        events: state.timelineEvents,
        selectedIndex: state.selectedEventIndex,
        scrollController: _timelineScrollController,
        onEventSelected: (index) {
          _onEventSelected(index, state);
        },
      );
    } else {
      return MapRouteView(
        events: state.timelineEvents,
        selectedIndex: state.selectedEventIndex,
        mapController: _mapController,
        onEventSelected: (index) {
          _onEventSelected(index, state);
        },
      );
    }
  }

  /// M2 양방향 연동: 이벤트 선택 시 타임라인↔지도 동기화
  void _onEventSelected(int index, MovementHistoryState state) {
    final notifier = ref.read(movementHistoryProvider((
      tripId: widget.tripId,
      targetUserId: widget.targetUserId,
    )).notifier);
    notifier.selectEvent(index);

    // 지도 모드에서 선택 시 → 타임라인 스크롤
    // 타임라인에서 선택 시 → 지도 카메라 이동
    if (state.viewMode == 'map' && index < state.timelineEvents.length) {
      // 타임라인 스크롤 (대략적 위치 계산)
      _timelineScrollController.animateTo(
        index * 56.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}
