import '../../../services/api_service.dart';
import '../models/movement_history_data.dart';
import '../models/timeline_event.dart';
import '../models/session_stats.dart';

class MovementHistoryService {
  final ApiService _apiService;

  MovementHistoryService([ApiService? apiService])
      : _apiService = apiService ?? ApiService();

  /// 멤버 이동기록 조회 (역할 검증 + 마스킹 서버 적용)
  Future<MovementHistoryData> getMemberMovementHistory({
    required String tripId,
    required String targetUserId,
    required String date,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/movement-history',
        queryParameters: {'date': date},
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return MovementHistoryData.fromJson(response.data['data']);
      }
      return MovementHistoryData(sessions: [], date: date, total: 0);
    } catch (e) {
      rethrow;
    }
  }

  /// 타임라인 데이터 조회
  Future<List<TimelineEvent>> getMemberTimeline({
    required String tripId,
    required String targetUserId,
    required String date,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/movement-history/timeline',
        queryParameters: {'date': date},
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        final events = response.data['data']['events'] as List? ?? [];
        return events.map((e) => TimelineEvent.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// 세션 통계 조회
  Future<SessionStats?> getSessionStats({
    required String tripId,
    required String targetUserId,
    required String sessionId,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/movement-sessions/$sessionId/stats',
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return SessionStats.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// 체류 지점 조회
  Future<List<Map<String, dynamic>>> getMemberStayPoints({
    required String tripId,
    required String targetUserId,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/stay-points',
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// 개인 인사이트 조회 (Phase 2)
  Future<Map<String, dynamic>?> getMemberInsights({
    required String tripId,
    required String targetUserId,
    required String date,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/trips/$tripId/members/$targetUserId/insights',
        queryParameters: {'date': date},
      );
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
