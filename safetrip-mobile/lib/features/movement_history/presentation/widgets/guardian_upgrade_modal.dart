import 'package:flutter/material.dart';

class GuardianUpgradeModal extends StatelessWidget {
  final String date;
  final VoidCallback? onUpgrade;
  final VoidCallback? onDismiss;

  const GuardianUpgradeModal({
    super.key,
    required this.date,
    this.onUpgrade,
    this.onDismiss,
  });

  static Future<void> show(BuildContext context, {required String date, VoidCallback? onUpgrade}) {
    return showDialog(
      context: context,
      builder: (_) => GuardianUpgradeModal(
        date: date,
        onUpgrade: onUpgrade,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이동기록 열람 제한'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            '$date 이동기록을 보려면\n유료 가디언으로 전환하세요',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '무료 가디언은 당일(24시간 이내)\n이동기록만 조회할 수 있습니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: onUpgrade,
          child: const Text('1,900원으로 전체 기간 조회하기'),
        ),
      ],
    );
  }
}
