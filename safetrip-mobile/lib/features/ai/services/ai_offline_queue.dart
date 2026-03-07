import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// SS13 오프라인 Safety AI -- 로컬 이벤트 큐잉
class AiOfflineQueue {
  static const _queueKey = 'ai_safety_offline_queue';

  /// 오프라인 이벤트를 큐에 추가
  Future<void> enqueue(Map<String, dynamic> event) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    event['queued_at'] = DateTime.now().toIso8601String();
    queue.add(jsonEncode(event));
    await prefs.setStringList(_queueKey, queue);
  }

  /// 큐잉된 이벤트 목록 조회
  Future<List<Map<String, dynamic>>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    return queue.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// 온라인 복귀 시 큐 비우기
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  /// SS13.2 규칙 기반 이탈 감지 (오프라인)
  Map<String, dynamic> evaluateDepartureOffline({
    required double distanceM,
    required int durationMin,
  }) {
    final isDeparted = distanceM > 300 && durationMin >= 10;
    return {
      'type': 'departure_detect',
      'is_departed': isDeparted,
      'distance_m': distanceM,
      'duration_min': durationMin,
      'model': 'rule_based_offline',
    };
  }
}
