import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 투표 생성 바텀시트 다이얼로그 (DOC-T3-CHT-020 SS7.4).
///
/// 사용자가 투표를 생성할 때 표시되는 바텀시트로, 다음을 입력받는다:
///   - 질문 텍스트 (필수)
///   - 선택지 2~5개 (최소 2개 필수)
///   - 마감 시한 (선택사항)
class PollCreateDialog extends StatefulWidget {
  const PollCreateDialog({super.key, required this.onSubmit});

  /// 투표 생성 완료 콜백.
  final void Function(
      String title, List<String> options, DateTime? deadline) onSubmit;

  /// 바텀시트를 표시하는 정적 헬퍼 메서드.
  static Future<void> show(
    BuildContext context, {
    required void Function(
            String title, List<String> options, DateTime? deadline)
        onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.bottomSheetRadius),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PollCreateDialog(onSubmit: onSubmit),
      ),
    );
  }

  @override
  State<PollCreateDialog> createState() => _PollCreateDialogState();
}

class _PollCreateDialogState extends State<PollCreateDialog> {
  final _titleController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  DateTime? _deadline;

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 헤더 ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '투표 만들기',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- 질문 입력 ----
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: '질문',
              hintText: '투표 질문을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius8),
              ),
            ),
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- 선택지 목록 ----
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ..._optionControllers.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: '선택지 ${entry.key + 1}',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radius8),
                              ),
                              isDense: true,
                            ),
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                        if (_optionControllers.length > 2)
                          IconButton(
                            onPressed: () => setState(() {
                              _optionControllers[entry.key].dispose();
                              _optionControllers.removeAt(entry.key);
                            }),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.semanticError),
                          ),
                      ],
                    ),
                  );
                }),
                if (_optionControllers.length < 5)
                  TextButton.icon(
                    onPressed: () => setState(
                        () => _optionControllers.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('선택지 추가'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- 마감 시한 선택 ----
          Row(
            children: [
              const Text('마감 시간: ', style: AppTypography.bodyMedium),
              TextButton(
                onPressed: _pickDeadline,
                child: Text(
                  _deadline != null
                      ? '${_deadline!.month}/${_deadline!.day} '
                          '${_deadline!.hour}:${_deadline!.minute.toString().padLeft(2, '0')}'
                      : '설정 (선택사항)',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- 생성 버튼 ----
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius12),
                ),
              ),
              child: const Text('투표 생성'),
            ),
          ),
        ],
      ),
    );
  }

  /// 날짜 + 시간 선택기를 순차적으로 표시한다.
  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _deadline = DateTime(
              date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  /// 입력 검증 후 콜백 호출.
  void _submit() {
    final title = _titleController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (title.isEmpty || options.length < 2) return;
    widget.onSubmit(title, options, _deadline);
    Navigator.pop(context);
  }
}
