import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';
import '../models/guide_data.dart';
import 'safety_guide_cache_service.dart';

/// 안전가이드 Repository — API + SQLite 레이어드 캐시 (설계 §3)
/// 1. API 호출 시도
/// 2. 성공 -> 로컬 캐시 갱신 -> 반환
/// 3. 실패 -> SQLite 캐시 폴백 (stale=true)
/// 4. 캐시도 없음 -> 하드코딩 폴백 (영사콜센터)
class SafetyGuideRepository {
  final ApiService _api;
  final SafetyGuideCacheService _cache;

  SafetyGuideRepository({
    required ApiService api,
    required SafetyGuideCacheService cache,
  })  : _api = api,
        _cache = cache;

  /// 전체 6탭 데이터 로드
  Future<SafetyGuideData> loadAll(String countryCode) async {
    try {
      // 1. API 호출 시도
      final response = await _api.getSafetyGuideAll(countryCode);
      if (response != null) {
        // 캐시 저장
        _cacheResponse(countryCode, response);
        return SafetyGuideData.fromJson(response);
      }
    } catch (e) {
      debugPrint('[SafetyGuideRepository] API loadAll failed: $e');
    }

    // 2. API 실패 -> 로컬 캐시 폴백
    return _loadFromCache(countryCode);
  }

  /// 긴급연락처만 로드 (S6: 빠른 접근)
  Future<GuideEmergency> loadEmergency(String countryCode) async {
    try {
      final response = await _api.getSafetyGuideEmergency(countryCode);
      if (response != null) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data != null) {
          final emergency = GuideEmergency.fromJson(data);
          // 영구 캐시 저장
          await _cache.saveEmergencyContacts(
            countryCode,
            emergency.contacts
                .map((c) => {
                      'contact_type': c.contactType,
                      'phone_number': c.phoneNumber,
                      'description_ko': c.descriptionKo,
                      'is_24h': c.is24h,
                    })
                .toList(),
          );
          return emergency;
        }
      }
    } catch (e) {
      debugPrint(
          '[SafetyGuideRepository] API loadEmergency failed: $e');
    }

    // 폴백: SQLite 캐시
    return _loadEmergencyFromCache(countryCode);
  }

  Future<void> _cacheResponse(
      String countryCode, Map<String, dynamic> response) async {
    try {
      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      for (final entry in data.entries) {
        if (entry.value is Map<String, dynamic>) {
          await _cache.cacheGuide(
              countryCode, entry.key, entry.value, expiresAt);
        }
      }

      // 긴급연락처 영구 저장
      if (data['emergency'] is Map<String, dynamic>) {
        final emergency = GuideEmergency.fromJson(data['emergency']);
        await _cache.saveEmergencyContacts(
          countryCode,
          emergency.contacts
              .map((c) => {
                    'contact_type': c.contactType,
                    'phone_number': c.phoneNumber,
                    'description_ko': c.descriptionKo,
                    'is_24h': c.is24h,
                  })
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('[SafetyGuideRepository] _cacheResponse Error: $e');
    }
  }

  Future<SafetyGuideData> _loadFromCache(String countryCode) async {
    try {
      final overviewCache =
          await _cache.getCachedGuide(countryCode, 'overview');
      final safetyCache =
          await _cache.getCachedGuide(countryCode, 'safety');
      final medicalCache =
          await _cache.getCachedGuide(countryCode, 'medical');
      final entryCache =
          await _cache.getCachedGuide(countryCode, 'entry');
      final localLifeCache =
          await _cache.getCachedGuide(countryCode, 'local_life');
      final emergency = await _loadEmergencyFromCache(countryCode);

      final hasAnyCachedData = overviewCache != null ||
          safetyCache != null ||
          medicalCache != null ||
          entryCache != null ||
          localLifeCache != null ||
          emergency.contacts.isNotEmpty;

      if (!hasAnyCachedData) {
        // 캐시도 없음 -> 하드코딩 폴백
        return SafetyGuideData(
          emergency: GuideEmergency.fallback(),
          meta: GuideMeta(
              countryCode: countryCode, cached: true, stale: true),
        );
      }

      return SafetyGuideData(
        overview: overviewCache != null
            ? GuideOverview.fromJson(overviewCache['content'])
            : null,
        safety: safetyCache != null
            ? GuideSafety.fromJson(safetyCache['content'])
            : null,
        medical: medicalCache != null
            ? GuideMedical.fromJson(medicalCache['content'])
            : null,
        entry: entryCache != null
            ? GuideEntry.fromJson(entryCache['content'])
            : null,
        emergency: emergency,
        localLife: localLifeCache != null
            ? GuideLocalLife.fromJson(localLifeCache['content'])
            : null,
        meta: GuideMeta(
          countryCode: countryCode,
          cached: true,
          stale: true,
          fetchedAt: overviewCache?['fetched_at'] != null
              ? DateTime.tryParse(overviewCache!['fetched_at'])
              : null,
        ),
      );
    } catch (e) {
      debugPrint('[SafetyGuideRepository] _loadFromCache Error: $e');
      return SafetyGuideData(
        emergency: GuideEmergency.fallback(),
        meta: GuideMeta(
            countryCode: countryCode, cached: true, stale: true),
      );
    }
  }

  Future<GuideEmergency> _loadEmergencyFromCache(
      String countryCode) async {
    try {
      final cached = await _cache.getEmergencyContacts(countryCode);
      if (cached.isNotEmpty) {
        return GuideEmergency(
          contacts: cached
              .map((c) => EmergencyContactItem(
                    contactType: c['contact_type'] as String? ?? '',
                    phoneNumber: c['phone_number'] as String? ?? '',
                    descriptionKo: c['description_ko'] as String?,
                    is24h: (c['is_24h'] as int?) == 1,
                  ))
              .toList(),
        );
      }
    } catch (e) {
      debugPrint(
          '[SafetyGuideRepository] _loadEmergencyFromCache Error: $e');
    }
    return GuideEmergency.fallback();
  }
}
