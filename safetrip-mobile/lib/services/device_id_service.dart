import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 기기 고유 식별자 관리 서비스
class DeviceIdService {
  static const String _prefKey = 'install_id';
  static String? _cached;

  /// 앱 설치 ID 반환 (없으면 신규 생성)
  static Future<String> getInstallId() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_prefKey);

    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_prefKey, id);
      debugPrint('[DeviceId] New install_id generated: $id');
    }

    _cached = id;
    return id;
  }

  static void clearCache() => _cached = null;
}
