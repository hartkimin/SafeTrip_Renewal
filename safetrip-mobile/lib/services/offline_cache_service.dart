import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_member.dart';

/// 멤버 목록 오프라인 캐시 서비스 (DOC-T3-MBR-019 SS14)
///
/// SharedPreferences를 사용하여 멤버 데이터를 캐시하고,
/// API 실패 시 캐시된 데이터로 폴백할 수 있도록 지원한다.
class OfflineCacheService {
  static const _membersCacheKey = 'offline_members_cache';
  static const _lastSyncKey = 'offline_last_sync';

  /// 멤버 목록 캐시 저장
  Future<void> cacheMembers(List<TripMember> members) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = members.map((m) => m.toJson()).toList();
      await prefs.setString(_membersCacheKey, jsonEncode(json));
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      debugPrint(
        '[OfflineCacheService] 멤버 ${members.length}명 캐시 저장 완료',
      );
    } catch (e) {
      debugPrint('[OfflineCacheService] 캐시 저장 실패: $e');
    }
  }

  /// 캐시된 멤버 목록 로드
  Future<List<TripMember>?> loadCachedMembers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_membersCacheKey);
      if (cached == null) return null;
      final list = (jsonDecode(cached) as List)
          .map((e) => TripMember.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint(
        '[OfflineCacheService] 캐시에서 멤버 ${list.length}명 로드 완료',
      );
      return list;
    } catch (e) {
      debugPrint('[OfflineCacheService] 캐시 로드 실패: $e');
      return null;
    }
  }

  /// 마지막 동기화 시각
  Future<DateTime?> getLastSyncAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_lastSyncKey);
      return str != null ? DateTime.tryParse(str) : null;
    } catch (e) {
      debugPrint('[OfflineCacheService] 마지막 동기화 시각 조회 실패: $e');
      return null;
    }
  }

  /// 캐시 초기화
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_membersCacheKey);
      await prefs.remove(_lastSyncKey);
      debugPrint('[OfflineCacheService] 캐시 초기화 완료');
    } catch (e) {
      debugPrint('[OfflineCacheService] 캐시 초기화 실패: $e');
    }
  }
}
