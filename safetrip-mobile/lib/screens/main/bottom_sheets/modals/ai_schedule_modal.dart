import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../models/schedule.dart';
import '../../../../services/api_service.dart';

/// AI 일정 추천 모달
/// POST /api/v1/trips/:tripId/schedules/ai-suggest 를 호출하여
/// AI가 추천한 일정 목록을 표시한다.
/// 개별 추가 또는 일괄 추가를 지원한다.
class AiScheduleModal extends StatefulWidget {
  const AiScheduleModal({
    super.key,
    required this.tripId,
  });

  final String tripId;

  @override
  State<AiScheduleModal> createState() => _AiScheduleModalState();
}

class _AiScheduleModalState extends State<AiScheduleModal> {
  final TextEditingController _promptController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String? _error;
  List<Schedule> _suggestions = [];
  final Set<int> _addedIndices = {};

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// AI 추천 요청
  Future<void> _requestSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _suggestions = [];
      _addedIndices.clear();
    });

    try {
      final body = <String, dynamic>{};
      if (_promptController.text.trim().isNotEmpty) {
        body['prompt'] = _promptController.text.trim();
      }

      final result = await _apiService.dio.post(
        '/api/v1/trips/${widget.tripId}/schedules/ai-suggest',
        data: body,
      );

      if (result.data?['success'] == true) {
        final data = result.data['data'];
        final schedulesList =
            data is Map ? (data['schedules'] ?? data['suggestions'] ?? []) : (data ?? []);
        final list = (schedulesList as List)
            .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _suggestions = list;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result.data?['error'] ?? 'AI 추천을 가져올 수 없습니다';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'AI 추천 요청에 실패했습니다. 다시 시도해 주세요.';
        _isLoading = false;
      });
    }
  }

  /// 개별 일정 추가
  Future<void> _addSingle(int index) async {
    final schedule = _suggestions[index];
    try {
      final result = await _apiService.dio.post(
        '/api/v1/trips/${widget.tripId}/schedules',
        data: schedule.toJson(),
      );
      if (result.data?['success'] == true) {
        setState(() => _addedIndices.add(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${schedule.title}" 일정이 추가되었습니다'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일정 추가에 실패했습니다'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 일괄 추가
  Future<void> _addAll() async {
    int addedCount = 0;
    for (int i = 0; i < _suggestions.length; i++) {
      if (_addedIndices.contains(i)) continue;
      try {
        final result = await _apiService.dio.post(
          '/api/v1/trips/${widget.tripId}/schedules',
          data: _suggestions[i].toJson(),
        );
        if (result.data?['success'] == true) {
          _addedIndices.add(i);
          addedCount++;
        }
      } catch (_) {
        // 개별 실패 시 계속 진행
      }
    }

    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$addedCount개 일정이 추가되었습니다'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (addedCount > 0) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.bottomSheetRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: AppSpacing.bottomSheetHandleWidth,
              height: AppSpacing.bottomSheetHandleHeight,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius:
                    BorderRadius.circular(AppSpacing.bottomSheetHandleHeight / 2),
              ),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.wandMagicSparkles,
                  size: 20,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'AI 일정 추천',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textTertiary,
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTarget,
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 프롬프트 입력 영역
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '어떤 일정을 추천받고 싶나요? (선택)',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _promptController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '예: 도쿄 3일차 추천, 오사카 맛집 위주',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textDisabled,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radius12),
                      borderSide: const BorderSide(
                        color: AppColors.outlineVariant,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radius12),
                      borderSide: const BorderSide(
                        color: AppColors.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radius12),
                      borderSide: const BorderSide(
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.inputPaddingH,
                      vertical: AppSpacing.inputPaddingV,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _requestSuggestions,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const FaIcon(
                            FontAwesomeIcons.wandMagicSparkles,
                            size: 16,
                          ),
                    label: Text(_isLoading ? '추천 생성 중...' : 'AI 추천받기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radius12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 결과 영역
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.semanticError.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                ),
                child: Text(
                  _error!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textError,
                  ),
                ),
              ),
            ),
          if (_suggestions.isNotEmpty) ...[
            const Divider(height: 1),
            // 일괄 추가 헤더
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    '추천 일정 ${_suggestions.length}건',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (_addedIndices.length < _suggestions.length)
                    TextButton.icon(
                      onPressed: _addAll,
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('일괄 추가'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryTeal,
                      ),
                    ),
                ],
              ),
            ),
            // 추천 일정 목록
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.lg,
                ),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return _buildSuggestionCard(index);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 추천 일정 카드 위젯
  Widget _buildSuggestionCard(int index) {
    final schedule = _suggestions[index];
    final isAdded = _addedIndices.contains(index);

    final startStr =
        '${schedule.startTime.hour.toString().padLeft(2, '0')}:${schedule.startTime.minute.toString().padLeft(2, '0')}';
    final endStr = schedule.endTime != null
        ? '${schedule.endTime!.hour.toString().padLeft(2, '0')}:${schedule.endTime!.minute.toString().padLeft(2, '0')}'
        : '';

    return Opacity(
      opacity: isAdded ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: isAdded
              ? AppColors.surfaceVariant
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          border: Border.all(
            color: isAdded
                ? AppColors.outlineVariant
                : AppColors.primaryTeal.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // 시간 정보
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Text(
                    startStr,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  if (endStr.isNotEmpty)
                    Text(
                      endStr,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // 일정 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.title,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (schedule.locationName != null &&
                      schedule.locationName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        schedule.locationName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (schedule.description != null &&
                      schedule.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        schedule.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // 추가 버튼
            SizedBox(
              width: 56,
              height: 32,
              child: isAdded
                  ? const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: AppColors.semanticSuccess,
                        size: 24,
                      ),
                    )
                  : TextButton(
                      onPressed: () => _addSingle(index),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryTeal,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(56, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radius8),
                          side: const BorderSide(
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ),
                      child: Text(
                        '추가',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
