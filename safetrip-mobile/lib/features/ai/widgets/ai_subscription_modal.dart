import 'package:flutter/material.dart';

class AiSubscriptionModal extends StatelessWidget {
  final VoidCallback? onSubscribe;
  final VoidCallback? onDismiss;

  const AiSubscriptionModal({super.key, this.onSubscribe, this.onDismiss});

  static bool _shownThisSession = false;

  static Future<void> showIfNeeded(
    BuildContext context, {
    VoidCallback? onSubscribe,
  }) async {
    if (_shownThisSession) return;
    _shownThisSession = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AiSubscriptionModal(onSubscribe: onSubscribe),
    );
  }

  static void resetSession() => _shownThisSession = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'AI 기능 업그레이드',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildPlanCard(
            'AI Plus',
            '4,900원/월 또는 2,900원/여행',
            ['장소 추천', 'AI 챗봇', '실시간 번역', '채팅 요약', '여행 인사이트'],
            const Color(0xFFFFB800),
          ),
          const SizedBox(height: 12),
          _buildPlanCard(
            'AI Pro',
            '9,900원/월 또는 5,900원/여행',
            ['AI Plus 전체 기능', '맞춤 안전 브리핑', '일정 최적화'],
            const Color(0xFF7C4DFF),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubscribe ?? () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('구독하기'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    String name,
    String price,
    List<String> features,
    Color accentColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                price,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text(f, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
