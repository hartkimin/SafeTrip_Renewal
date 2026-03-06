import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_sync_service.dart';

/// 긴급 연락처 및 안전가이드 로컬 캐싱 서비스 (오프라인 원칙 §3.1)
///
/// 여행 활성화 시 긴급 연락처와 국가별 안전가이드를 서버에서 받아
/// SQLite(local_cache_meta)에 캐싱하고, 오프라인 상태에서도 즉시 조회 가능하게 합니다.
class EmergencyCacheService {
  EmergencyCacheService({
    required this.apiService,
    required this.offlineSyncService,
  });

  final ApiService apiService;
  final OfflineSyncService offlineSyncService;

  /// 여행 활성화 시 긴급 데이터 캐싱
  ///
  /// [tripId] 여행 ID, [countryCode] 국가 코드 (ISO 3166-1 alpha-2)
  /// 긴급 연락처와 안전가이드를 병렬로 캐싱합니다.
  Future<void> cacheForTrip(String tripId, String countryCode) async {
    await Future.wait([
      _cacheEmergencyContacts(tripId),
      _cacheSafetyGuide(countryCode),
    ]);
  }

  Future<void> _cacheEmergencyContacts(String tripId) async {
    try {
      final contacts = await apiService.getEmergencyContacts(tripId);
      if (contacts != null) {
        await offlineSyncService.setCacheMeta(
          cacheKey: 'emergency_contacts_$tripId',
          data: jsonEncode(contacts),
        );
        debugPrint('[EmergencyCache] 긴급 연락처 캐싱 완료 ($tripId)');
      }
    } catch (e) {
      debugPrint('[EmergencyCache] 긴급 연락처 캐싱 실패: $e');
    }
  }

  Future<void> _cacheSafetyGuide(String countryCode) async {
    try {
      final guide = await apiService.getSafetyGuide(countryCode);
      if (guide != null) {
        await offlineSyncService.setCacheMeta(
          cacheKey: 'safety_guide_$countryCode',
          data: jsonEncode(guide),
        );
        debugPrint('[EmergencyCache] 안전가이드 캐싱 완료 ($countryCode)');
      }
    } catch (e) {
      debugPrint('[EmergencyCache] 안전가이드 캐싱 실패: $e');
    }
  }

  /// 캐시된 긴급 연락처 읽기
  ///
  /// 오프라인 상태에서도 호출 가능. 캐시가 없으면 null 반환.
  Future<Map<String, dynamic>?> getCachedEmergencyContacts(
    String tripId,
  ) async {
    final meta = await offlineSyncService.getCacheMeta(
      'emergency_contacts_$tripId',
    );
    if (meta == null) return null;
    return jsonDecode(meta['data'] as String) as Map<String, dynamic>;
  }

  /// 캐시된 안전가이드 읽기
  ///
  /// 오프라인 상태에서도 호출 가능. 캐시가 없으면 null 반환.
  Future<Map<String, dynamic>?> getCachedSafetyGuide(
    String countryCode,
  ) async {
    final meta = await offlineSyncService.getCacheMeta(
      'safety_guide_$countryCode',
    );
    if (meta == null) return null;
    return jsonDecode(meta['data'] as String) as Map<String, dynamic>;
  }
}
