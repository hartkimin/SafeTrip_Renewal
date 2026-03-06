import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

enum UpdateType { none, optional, critical }

class VersionCheckResult {
  final UpdateType updateType;
  final String minVersion;
  final String recommendedVersion;
  final String storeUrl;

  const VersionCheckResult({
    required this.updateType,
    required this.minVersion,
    required this.recommendedVersion,
    required this.storeUrl,
  });

  static const VersionCheckResult none = VersionCheckResult(
    updateType: UpdateType.none,
    minVersion: '0.0.0',
    recommendedVersion: '0.0.0',
    storeUrl: '',
  );
}

class VersionCheckService {
  final ApiService _apiService;

  VersionCheckService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<VersionCheckResult> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final version = packageInfo.version;

      final response = await _apiService.dio.get(
        '/api/v1/version/check',
        queryParameters: {'platform': platform, 'version': version},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final result = VersionCheckResult(
          updateType: _parseUpdateType(data['update_type'] as String?),
          minVersion: data['min_version'] as String? ?? '0.0.0',
          recommendedVersion: data['recommended_version'] as String? ?? '0.0.0',
          storeUrl: data['store_url'] as String? ?? '',
        );
        await _cacheResult(result);
        return result;
      }
    } catch (e) {
      debugPrint('[VersionCheckService] check failed: $e');
    }
    return _loadCachedResult();
  }

  UpdateType _parseUpdateType(String? type) {
    switch (type) {
      case 'critical': return UpdateType.critical;
      case 'optional': return UpdateType.optional;
      default: return UpdateType.none;
    }
  }

  Future<void> _cacheResult(VersionCheckResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('version_check_update_type', result.updateType.name);
      await prefs.setString('version_check_store_url', result.storeUrl);
    } catch (_) {}
  }

  Future<VersionCheckResult> _loadCachedResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString('version_check_update_type');
      final url = prefs.getString('version_check_store_url') ?? '';
      if (type != null) {
        return VersionCheckResult(
          updateType: _parseUpdateType(type),
          minVersion: '',
          recommendedVersion: '',
          storeUrl: url,
        );
      }
    } catch (_) {}
    return VersionCheckResult.none;
  }
}
