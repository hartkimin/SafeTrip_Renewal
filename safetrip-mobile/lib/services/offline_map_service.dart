import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오프라인 지도 타일 캐시 서비스 (지도 원칙 §9.1)
///
/// 여행 목적지 중심 반경 50km, 줌 10~16 타일 사전 다운로드.
/// 최대 500MB/국가 제한.
/// planning→active 전환 시 Wi-Fi에서 자동 시작.
/// 종료 후 30일 만료.
class OfflineMapService {
  static const int _minZoom = 10;
  static const int _maxZoom = 16;
  static const double _radiusKm = 50.0;
  static const int _expirationDays = 30;
  static const _prefsKeyPrefix = 'offline_map_';

  /// 타일 URL 생성 (CartoDB Light @2x)
  static String tileUrl(int z, int x, int y) {
    final subdomains = ['a', 'b', 'c', 'd'];
    final s = subdomains[(x + y) % subdomains.length];
    return 'https://$s.basemaps.cartocdn.com/light_all/$z/$x/$y@2x.png';
  }

  /// 캐시 디렉토리 경로
  Future<Directory> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/offline_tiles');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 현재 캐시 크기 (MB)
  Future<double> getCacheSizeMb() async {
    final dir = await _cacheDir;
    if (!await dir.exists()) return 0;

    int totalBytes = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes / (1024 * 1024);
  }

  /// 캐시 만료 여부 확인 (30일)
  Future<bool> isCacheExpired(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final completedAt = prefs.getString('${_prefsKeyPrefix}completed_$tripId');
    if (completedAt == null) return false;

    final completedDate = DateTime.parse(completedAt);
    return DateTime.now().difference(completedDate).inDays > _expirationDays;
  }

  /// 만료된 캐시 정리
  Future<void> cleanExpiredCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('${_prefsKeyPrefix}completed_'));

    for (final key in keys) {
      final tripId = key.replaceFirst('${_prefsKeyPrefix}completed_', '');
      if (await isCacheExpired(tripId)) {
        await deleteCacheForTrip(tripId);
        await prefs.remove(key);
        debugPrint('[OfflineMap] 만료된 캐시 삭제: $tripId');
      }
    }
  }

  /// 여행별 캐시 삭제
  Future<void> deleteCacheForTrip(String tripId) async {
    final dir = await _cacheDir;
    final tripDir = Directory('${dir.path}/$tripId');
    if (await tripDir.exists()) {
      await tripDir.delete(recursive: true);
    }
  }

  /// 다운로드할 타일 수 추정 (줌 10~16, 반경 50km)
  static int estimateTileCount(double lat, double lng) {
    int count = 0;
    for (int z = _minZoom; z <= _maxZoom; z++) {
      // 간략 계산: 반경에 해당하는 타일 수
      final metersPerTile = 40075016.686 * cos(lat * pi / 180) / (1 << z);
      final tilesPerSide = (_radiusKm * 1000 * 2 / metersPerTile).ceil();
      count += tilesPerSide * tilesPerSide;
    }
    return count;
  }

  /// 여행 종료 기록 (만료 타이머 시작)
  Future<void> markTripCompleted(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_prefsKeyPrefix}completed_$tripId',
      DateTime.now().toIso8601String(),
    );
  }
}
