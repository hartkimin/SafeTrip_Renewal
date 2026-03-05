import 'package:flutter/foundation.dart';

/// 여행 안전 가이드 검색 결과 모델
class GuideSearchResult {
  final String countryCode;
  final String? countryNameKo;
  final String snippet;
  final List<String> matchedSections;

  GuideSearchResult({
    required this.countryCode,
    this.countryNameKo,
    this.snippet = '',
    this.matchedSections = const [],
  });

  factory GuideSearchResult.fromJson(Map<String, dynamic> json) {
    return GuideSearchResult(
      countryCode: json['country_code'] as String? ?? '',
      countryNameKo: json['country_name_ko'] as String?,
      snippet: json['snippet'] as String? ?? '',
      matchedSections:
          (json['matched_sections'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// 여행 안전 가이드 서비스
/// 국가별 안전 정보 검색 기능을 제공합니다.
class TravelGuideService {
  /// 안전 가이드 검색
  Future<List<GuideSearchResult>> searchGuides({
    required String query,
    required String countryCode,
  }) async {
    try {
      // TODO: 백엔드 API 연동 후 실제 검색 구현
      // 현재는 로컬 데이터 기반 검색 stub
      debugPrint('[TravelGuideService] 검색: query=$query, country=$countryCode');
      return [];
    } catch (e) {
      debugPrint('[TravelGuideService] 검색 실패: $e');
      return [];
    }
  }
}
