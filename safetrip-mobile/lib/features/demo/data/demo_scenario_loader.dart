import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/demo_scenario.dart';

class DemoScenarioLoader {
  static final Map<DemoScenarioId, DemoScenario> _cache = {};

  static Future<DemoScenario> load(DemoScenarioId id) async {
    if (_cache.containsKey(id)) return _cache[id]!;

    final path = 'assets/demo/scenario_${id.name}.json';
    try {
      final jsonStr = await rootBundle.loadString(path);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final scenario = DemoScenario.fromJson(json);
      _cache[id] = scenario;
      return scenario;
    } catch (e) {
      // §6: JSON 로딩 실패 → 기본 S1로 대체
      if (id != DemoScenarioId.s1) {
        return load(DemoScenarioId.s1);
      }
      rethrow;
    }
  }

  static void clearCache() => _cache.clear();
}
