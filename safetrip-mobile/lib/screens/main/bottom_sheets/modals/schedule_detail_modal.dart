import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../constants/app_tokens.dart';
import '../../../../models/schedule.dart';
import '../../../../services/api_service.dart';
import '../../../../services/offline_sync_service.dart';
import '../../../../utils/app_cache.dart';
import 'add_schedule_direct_modal.dart';

/// D-05 일정 상세 (Schedule Detail)
///
/// 와이어프레임: D_Trip_Management.md - D-05
/// 일정 카드 탭 시 일정 상세 정보를 표시한다.
/// 캡틴/크루장은 편집·삭제 가능, 크루는 열람만 가능.
class ScheduleDetailModal extends StatefulWidget {

  const ScheduleDetailModal({
    super.key,
    required this.schedule,
    this.userRole = 'crew',
    this.onScheduleUpdated,
  });
  final Schedule schedule;
  final String userRole; // 'captain' | 'crew_leader' | 'crew' | 'guardian'
  final VoidCallback? onScheduleUpdated;

  @override
  State<ScheduleDetailModal> createState() => _ScheduleDetailModalState();
}

class _ScheduleDetailModalState extends State<ScheduleDetailModal> {
  late Schedule _schedule;
  bool _isDeleting = false;
  final ApiService _apiService = ApiService();

  bool get _canEdit =>
      widget.userRole == 'captain' || widget.userRole == 'crew_leader';

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildAppBar(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                  if (_schedule.locationName != null &&
                      _schedule.locationName!.isNotEmpty)
                    _buildLocationSection(),
                  if (_schedule.description != null &&
                      _schedule.description!.isNotEmpty)
                    _buildMemoSection(),
                  if (_canEdit) ...[
                    const SizedBox(height: 24),
                    _buildActions(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: AppTokens.line04,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text(
            '일정 상세',
            style: TextStyle(
              fontSize: AppTokens.fontSize18,
              fontFamily: AppTokens.fontFamily,
              fontWeight: AppTokens.fontWeightSemibold,
              color: AppTokens.text05,
              letterSpacing: AppTokens.letterSpacingNeg05,
            ),
          ),
          const Spacer(),
          if (_canEdit)
            GestureDetector(
              onTap: _onEdit,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  FontAwesomeIcons.penToSquare,
                  color: AppTokens.primaryTeal,
                  size: 18,
                ),
              ),
            ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                FontAwesomeIcons.xmark,
                color: AppTokens.text03,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final typeIcon = _getScheduleTypeIcon(_schedule.scheduleType);
    final dateStr = _formatDate(_schedule.startTime);
    final timeStr = _formatTimeRange(_schedule.startTime, _schedule.endTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(color: AppTokens.line03),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 유형 아이콘 + 일정명
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(typeIcon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _schedule.title,
                  style: const TextStyle(
                    fontSize: AppTokens.fontSize20,
                    fontFamily: AppTokens.fontFamily,
                    fontWeight: AppTokens.fontWeightSemibold,
                    color: AppTokens.text05,
                    letterSpacing: AppTokens.letterSpacingNeg05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 날짜
          _buildDetailRow('📅', dateStr),
          const SizedBox(height: 12),

          // 시간
          _buildDetailRow('⏰', timeStr),

          // 장소
          if (_schedule.locationName != null &&
              _schedule.locationName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              '📍',
              _schedule.locationName!,
              valueColor: AppTokens.primaryTeal,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String emoji, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: AppTokens.fontSize14,
              fontFamily: AppTokens.fontFamily,
              fontWeight: AppTokens.fontWeightRegular,
              color: valueColor ?? AppTokens.text04,
              letterSpacing: AppTokens.letterSpacingNeg03,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          '장소',
          style: TextStyle(
            fontSize: AppTokens.fontSize16,
            fontFamily: AppTokens.fontFamily,
            fontWeight: AppTokens.fontWeightSemibold,
            color: AppTokens.text05,
            letterSpacing: AppTokens.letterSpacingNeg03,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTokens.bgBasic02,
            borderRadius: BorderRadius.circular(AppTokens.radius12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.locationDot,
                    color: AppTokens.primaryTeal,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _schedule.locationName ?? '',
                      style: const TextStyle(
                        fontSize: AppTokens.fontSize14,
                        fontFamily: AppTokens.fontFamily,
                        fontWeight: AppTokens.fontWeightMedium,
                        color: AppTokens.text05,
                      ),
                    ),
                  ),
                ],
              ),
              if (_schedule.locationAddress != null &&
                  _schedule.locationAddress!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    _schedule.locationAddress!,
                    style: const TextStyle(
                      fontSize: AppTokens.fontSize12,
                      fontFamily: AppTokens.fontFamily,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: AppTokens.text03,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          '메모',
          style: TextStyle(
            fontSize: AppTokens.fontSize16,
            fontFamily: AppTokens.fontFamily,
            fontWeight: AppTokens.fontWeightSemibold,
            color: AppTokens.text05,
            letterSpacing: AppTokens.letterSpacingNeg03,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTokens.bgBasic02,
            borderRadius: BorderRadius.circular(AppTokens.radius12),
          ),
          child: Text(
            _schedule.description!,
            style: const TextStyle(
              fontSize: AppTokens.fontSize14,
              fontFamily: AppTokens.fontFamily,
              fontWeight: AppTokens.fontWeightRegular,
              color: AppTokens.text04,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // 편집 버튼
        GestureDetector(
          onTap: _onEdit,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: AppTokens.primaryTeal,
              borderRadius: BorderRadius.circular(AppTokens.radius12),
            ),
            child: const Center(
              child: Text(
                '편집하기',
                style: TextStyle(
                  color: AppTokens.bgBasic01,
                  fontSize: AppTokens.fontSize16,
                  fontFamily: AppTokens.fontFamily,
                  fontWeight: AppTokens.fontWeightSemibold,
                  letterSpacing: AppTokens.letterSpacingNeg15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 삭제 버튼
        GestureDetector(
          onTap: _isDeleting ? null : _onDelete,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppTokens.radius12),
              border: Border.all(color: AppTokens.semanticError),
            ),
            child: Center(
              child: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTokens.semanticError,
                        ),
                      ),
                    )
                  : const Text(
                      '삭제하기',
                      style: TextStyle(
                        color: AppTokens.semanticError,
                        fontSize: AppTokens.fontSize16,
                        fontFamily: AppTokens.fontFamily,
                        fontWeight: AppTokens.fontWeightSemibold,
                        letterSpacing: AppTokens.letterSpacingNeg15,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _onEdit() async {
    Navigator.of(context).pop();
    final groupId = AppCache.groupIdSync;
    if (groupId == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AddScheduleDirectModal(schedule: _schedule),
      ),
    );
    widget.onScheduleUpdated?.call();
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('"${_schedule.title}" 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제', style: TextStyle(color: AppTokens.semanticError)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final groupId = AppCache.groupIdSync;
      if (groupId == null) throw Exception('group_id not found');

      // §5.4 오프라인 감지
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity == ConnectivityResult.none;

      if (isOffline) {
        // 오프라인: 삭제 요청을 로컬 드래프트에 큐잉
        await OfflineSyncService().pushScheduleDraft(
          scheduleId: _schedule.scheduleId,
          tripId: groupId,
          action: 'delete',
          payload: jsonEncode({
            'schedule_id': _schedule.scheduleId,
            'title': _schedule.title,
          }),
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('오프라인 — 연결 복구 시 삭제가 동기화됩니다'),
              duration: Duration(seconds: 3),
            ),
          );
          widget.onScheduleUpdated?.call();
        }
        return;
      }

      await _apiService.deleteSchedule(
        groupId: groupId,
        scheduleId: _schedule.scheduleId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일정이 삭제되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
        widget.onScheduleUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getScheduleTypeIcon(String type) {
    switch (type) {
      case 'transport':
        return '✈️';
      case 'accommodation':
        return '🏨';
      case 'food':
        return '🍽️';
      case 'sightseeing':
        return '📍';
      case 'shopping':
        return '🛍️';
      case 'meeting':
        return '👥';
      default:
        return '📌';
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('yyyy년 M월 d일 (E)', 'ko').format(dt);
  }

  String _formatTimeRange(DateTime? start, DateTime? end) {
    if (start == null) return '-';
    final startStr = DateFormat('HH:mm').format(start);
    if (end == null) return startStr;
    final endStr = DateFormat('HH:mm').format(end);
    final diff = end.difference(start);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    String durStr = '';
    if (hours > 0) durStr += '$hours시간';
    if (mins > 0) durStr += ' $mins분';
    return '$startStr ~ $endStr ($durStr)';
  }
}
