import 'package:flutter/foundation.dart';
import '../models/mofa_country_info.dart';
import 'api_service.dart';

/// 외교부(MOFA) 안전 정보 서비스
/// 재외공관 연락처, 여행경보, 안전공지 등을 제공합니다.
class MofaService {
  final ApiService _apiService = ApiService();

  /// 특정 국가의 재외공관 연락처 정보 가져오기
  Future<MofaContactInfo> getContactInfo(String countryCode) async {
    try {
      final response = await _apiService.getCountries();
      // 국가 코드에 해당하는 재외공관 정보 필터링
      final embassies = <EmbassyInfo>[];
      final localContacts = <LocalContactInfo>[];

      for (final item in response) {
        final code = item['country_iso_alp2'] ?? item['countryCode'];
        if (code == countryCode) {
          embassies.add(EmbassyInfo.fromJson(item));
        }
      }

      return MofaContactInfo(
        embassies: embassies,
        localContacts: localContacts,
        countryCode: countryCode,
      );
    } catch (e) {
      debugPrint('[MofaService] getContactInfo 실패: $e');
      return MofaContactInfo(countryCode: countryCode);
    }
  }

  /// 여행경보 정보 가져오기
  Future<List<TravelWarningInfo>> getTravelWarnings(String countryCode) async {
    try {
      // TODO: 백엔드 API 연동 후 실제 데이터로 교체
      return [];
    } catch (e) {
      debugPrint('[MofaService] getTravelWarnings 실패: $e');
      return [];
    }
  }

  /// 안전공지 가져오기
  Future<List<SafetyNoticeInfo>> getSafetyNotices(String countryCode) async {
    try {
      // TODO: 백엔드 API 연동 후 실제 데이터로 교체
      return [];
    } catch (e) {
      debugPrint('[MofaService] getSafetyNotices 실패: $e');
      return [];
    }
  }
}
