import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../constants/app_tokens.dart';
import '../../../../services/api_service.dart';

/// D-03 빠른 일정 입력 (Quick Schedule Entry)
///
/// 와이어프레임: D_Trip_Management.md - D-03
/// 텍스트 한 줄로 시간+내용을 빠르게 입력하여 일정을 추가한다.
/// 실시간 시간 패턴 파싱(정규식: HH:MM, H시, 오후 N시 등).
class QuickScheduleModal extends StatefulWidget {
  const QuickScheduleModal({
    super.key,
    required this.groupId,
    required this.tripId,
    required this.selectedDate,
    this.onScheduleAdded,
  });

  final String groupId;
  final String tripId;
  final DateTime selectedDate;
  final VoidCallback? onScheduleAdded;

  @override
  State<QuickScheduleModal> createState() => _QuickScheduleModalState();
}

class _QuickScheduleModalState extends State<QuickScheduleModal> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ApiService _apiService = ApiService();

  // 파싱 결과
  TimeOfDay? _parsedStartTime;
  TimeOfDay? _parsedEndTime;
  String? _parsedTitle;
  bool _parseSuccess = false;

  // 추가된 일정 목록
  final List<_AddedItem> _addedItems = [];
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          const SizedBox(height: 16),
          _buildInputRow(),
          const SizedBox(height: 8),
          _buildHint(),
          if (_parseSuccess) ...[
            const SizedBox(height: 16),
            _buildPreviewCard(),
          ],
          if (_addedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAddedList(),
          ],
          const Spacer(),
          _buildDoneButton(),
          const SizedBox(height: 24),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Text(
            '빠른 일정 입력',
            style: TextStyle(
              fontSize: AppTokens.fontSize18,
              fontFamily: AppTokens.fontFamily,
              fontWeight: AppTokens.fontWeightSemibold,
              color: AppTokens.text05,
              letterSpacing: AppTokens.letterSpacingNeg05,
            ),
          ),
          const Spacer(),
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

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTokens.bgBasic02,
                borderRadius: BorderRadius.circular(AppTokens.radius12),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppTokens.primaryTeal
                      : AppTokens.line03,
                ),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                onChanged: _onInputChanged,
                onSubmitted: (_) => _onAdd(),
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontSize: AppTokens.fontSize16,
                  fontFamily: AppTokens.fontFamily,
                  color: AppTokens.text05,
                ),
                decoration: const InputDecoration(
                  hintText: '10:00 시부야 쇼핑',
                  hintStyle: TextStyle(
                    fontSize: AppTokens.fontSize16,
                    fontFamily: AppTokens.fontFamily,
                    color: AppTokens.text02,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isAdding || !_parseSuccess ? null : _onAdd,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _parseSuccess
                    ? AppTokens.primaryTeal
                    : AppTokens.bgBasic04,
                borderRadius: BorderRadius.circular(AppTokens.radius12),
              ),
              child: Center(
                child: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.add,
                        color: _parseSuccess ? Colors.white : AppTokens.text02,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        '시간 + 내용을 입력하세요 (예: 14:00 센소지 관광)',
        style: TextStyle(
          fontSize: AppTokens.fontSize12,
          fontFamily: AppTokens.fontFamily,
          fontWeight: AppTokens.fontWeightRegular,
          color: AppTokens.text02,
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final startStr = _parsedStartTime != null
        ? '${_parsedStartTime!.hour.toString().padLeft(2, '0')}:${_parsedStartTime!.minute.toString().padLeft(2, '0')}'
        : '??:??';
    final endStr = _parsedEndTime != null
        ? '${_parsedEndTime!.hour.toString().padLeft(2, '0')}:${_parsedEndTime!.minute.toString().padLeft(2, '0')}'
        : '${(_parsedStartTime != null ? (_parsedStartTime!.hour + 1) % 24 : 0).toString().padLeft(2, '0')}:${_parsedStartTime?.minute.toString().padLeft(2, '0') ?? '00'}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.bgBasic02,
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          border: Border.all(
            color: AppTokens.primaryTeal.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '파싱 미리보기',
              style: TextStyle(
                fontSize: AppTokens.fontSize12,
                fontFamily: AppTokens.fontFamily,
                fontWeight: AppTokens.fontWeightMedium,
                color: AppTokens.text03,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '⏰  $startStr ~ $endStr',
                  style: const TextStyle(
                    fontSize: AppTokens.fontSize14,
                    fontFamily: AppTokens.fontFamily,
                    fontWeight: AppTokens.fontWeightSemibold,
                    color: AppTokens.primaryTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '📝  ${_parsedTitle ?? ''}',
                  style: const TextStyle(
                    fontSize: AppTokens.fontSize14,
                    fontFamily: AppTokens.fontFamily,
                    fontWeight: AppTokens.fontWeightMedium,
                    color: AppTokens.text05,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddedList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '방금 추가',
              style: TextStyle(
                fontSize: AppTokens.fontSize12,
                fontFamily: AppTokens.fontFamily,
                fontWeight: AppTokens.fontWeightMedium,
                color: AppTokens.text03,
              ),
            ),
          ),
          ..._addedItems.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTokens.semanticSuccess,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.time} ${item.title}',
                    style: const TextStyle(
                      fontSize: AppTokens.fontSize14,
                      fontFamily: AppTokens.fontFamily,
                      fontWeight: AppTokens.fontWeightRegular,
                      color: AppTokens.semanticSuccess,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          if (_addedItems.isNotEmpty) {
            widget.onScheduleAdded?.call();
          }
          Navigator.of(context).pop();
        },
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: AppTokens.primaryTeal,
            borderRadius: BorderRadius.circular(AppTokens.radius12),
          ),
          child: const Center(
            child: Text(
              '완료',
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
    );
  }

  // ── 시간 파싱 로직 ──

  void _onInputChanged(String text) {
    final result = _parseTimeAndTitle(text.trim());
    setState(() {
      _parsedStartTime = result.$1;
      _parsedTitle = result.$2;
      _parsedEndTime = result.$3;
      _parseSuccess =
          _parsedStartTime != null && (_parsedTitle?.isNotEmpty ?? false);
    });
  }

  /// 시간 패턴 파싱: "10:00 시부야 쇼핑" → (10:00, "시부야 쇼핑")
  /// 지원 패턴: HH:MM, H시, 오전/오후 H시, H시M분
  (TimeOfDay?, String?, TimeOfDay?) _parseTimeAndTitle(String input) {
    if (input.isEmpty) return (null, null, null);

    // Pattern 1: HH:MM or H:MM
    final colonPattern = RegExp(r'^(\d{1,2}):(\d{2})\s+(.+)$');
    var match = colonPattern.firstMatch(input);
    if (match != null) {
      final h = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      if (h >= 0 && h < 24 && m >= 0 && m < 60) {
        return (
          TimeOfDay(hour: h, minute: m),
          match.group(3),
          TimeOfDay(hour: (h + 1) % 24, minute: m),
        );
      }
    }

    // Pattern 2: 오전/오후 H시 (M분)
    final koreanAmPmPattern = RegExp(
      r'^(오전|오후|아침|저녁|밤)\s*(\d{1,2})시\s*(\d{1,2}분)?\s*(.+)$',
    );
    match = koreanAmPmPattern.firstMatch(input);
    if (match != null) {
      var h = int.parse(match.group(2)!);
      final minStr = match.group(3);
      final m = minStr != null ? int.parse(minStr.replaceAll('분', '')) : 0;
      final period = match.group(1)!;
      if (period == '오후' || period == '저녁' || period == '밤') {
        if (h < 12) h += 12;
      } else {
        if (h == 12) h = 0;
      }
      if (h >= 0 && h < 24) {
        return (
          TimeOfDay(hour: h, minute: m),
          match.group(4),
          TimeOfDay(hour: (h + 1) % 24, minute: m),
        );
      }
    }

    // Pattern 3: H시 (M분)
    final koreanHourPattern = RegExp(r'^(\d{1,2})시\s*(\d{1,2}분)?\s*(.+)$');
    match = koreanHourPattern.firstMatch(input);
    if (match != null) {
      final h = int.parse(match.group(1)!);
      final minStr = match.group(2);
      final m = minStr != null ? int.parse(minStr.replaceAll('분', '')) : 0;
      if (h >= 0 && h < 24) {
        return (
          TimeOfDay(hour: h, minute: m),
          match.group(3),
          TimeOfDay(hour: (h + 1) % 24, minute: m),
        );
      }
    }

    return (null, input, null);
  }

  Future<void> _onAdd() async {
    if (!_parseSuccess || _parsedStartTime == null || _parsedTitle == null) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      final startDt = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _parsedStartTime!.hour,
        _parsedStartTime!.minute,
      );

      final endH = _parsedEndTime?.hour ?? ((_parsedStartTime!.hour + 1) % 24);
      final endM = _parsedEndTime?.minute ?? _parsedStartTime!.minute;
      final endDt = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        endH,
        endM,
      );

      await _apiService.createSchedule(
        groupId: widget.groupId,
        tripId: widget.tripId,
        title: _parsedTitle!,
        scheduleType: 'other',
        startTime: startDt,
        endTime: endDt,
      );

      final timeStr =
          '${_parsedStartTime!.hour.toString().padLeft(2, '0')}:${_parsedStartTime!.minute.toString().padLeft(2, '0')}';

      setState(() {
        _addedItems.add(_AddedItem(time: timeStr, title: _parsedTitle!));
        _inputController.clear();
        _parsedStartTime = null;
        _parsedEndTime = null;
        _parsedTitle = null;
        _parseSuccess = false;
        _isAdding = false;
      });

      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정 추가 실패: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _AddedItem {
  const _AddedItem({required this.time, required this.title});
  final String time;
  final String title;
}
