import 'package:flutter/material.dart';

class AiDisclaimerBadge extends StatelessWidget {
  final String type; // 'convenience' | 'intelligence'

  const AiDisclaimerBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final text = type == 'intelligence'
        ? 'AI 분석 결과입니다. 데이터 범위에 따라 정확도가 달라질 수 있습니다.'
        : 'AI가 생성한 정보로, 실제와 다를 수 있습니다.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
