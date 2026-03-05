import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'firebase_location_service.dart';
import '../utils/app_cache.dart';

/// 세션 관리 서비스
class SessionService {

  SessionService({
    ApiService? apiService,
    FirebaseLocationService? firebaseLocationService,
  }) : _apiService = apiService ?? ApiService(),
       _firebaseLocationService =
           firebaseLocationService ?? FirebaseLocationService();
  final ApiService _apiService;
  final FirebaseLocationService _firebaseLocationService;

  /// 세션 날짜 범위 조회
  Future<Map<String, dynamic>?> getSessionDateRange(String userId) async {
    try {
      debugPrint('[SessionService] 세션 날짜 범위 조회 시작: userId=$userId');
      final dateRange = await _apiService.getSessionDateRange(userId: userId);
      debugPrint('[SessionService] 세션 날짜 범위 조회 완료: $dateRange');
      return dateRange;
    } catch (e) {
      debugPrint('[SessionService] 세션 날짜 범위 조회 실패: $e');
      return null;
    }
  }

  /// 세션 리스트를 완료된 세션과 이동 중인 세션으로 분리
  Map<String, dynamic> separateSessions(List<Map<String, dynamic>> sessions) {
    final completedSessions = <Map<String, dynamic>>[];
    Map<String, dynamic>? ongoingSession;

    for (final session in sessions) {
      final isCompleted = session['is_completed'] as bool? ?? false;

      if (isCompleted) {
        completedSessions.add(session);
      } else {
        // 이동 중인 세션은 하나만 유지 (가장 최신 것)
        final startTime = session['start_time'] as String?;
        if (ongoingSession == null ||
            (startTime != null &&
                ongoingSession['start_time'] != null &&
                startTime.compareTo(ongoingSession['start_time'] as String) >
                    0)) {
          ongoingSession = session;
        }
      }
    }

    // 완료된 세션을 시작 시간 기준 내림차순 정렬
    completedSessions.sort(
      (a, b) =>
          (b['start_time'] as String).compareTo(a['start_time'] as String),
    );

    return {
      'completedSessions': completedSessions,
      'ongoingSession': ongoingSession,
    };
  }

  /// 날짜별 세션 리스트 조회
  Future<List<Map<String, dynamic>>> getSessionsByDate(
    String userId,
    String date, { // YYYY-MM-DD 형식
    List<String>? needImages,
  }) async {
    try {
      debugPrint('[SessionService] 날짜별 세션 조회 시작: userId=$userId, date=$date');
      final sessions = await _apiService.getMovementSessionsByDate(
        userId: userId,
        date: date,
        needImages: needImages,
      );
      debugPrint('[SessionService] 날짜별 세션 조회 완료: ${sessions.length}개');

      // 오늘 날짜인지 확인 (UTC 기준)
      final now = DateTime.now().toUtc();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final isToday = date == todayStr;

      // 오늘 날짜일 때만 Firebase 조회 및 비교 (과거 날짜는 모두 완료된 것이 확실)
      bool? firstSessionIsOngoing;
      if (isToday && sessions.isNotEmpty) {
        // Firebase에서 사용자의 movement_session_id 조회 (오늘 날짜일 때만)
        final groupId =
            await AppCache.groupId ?? '00000000-0000-0000-0000-000000000002';
        final firebaseSessionId = await _firebaseLocationService
            .getUserMovementSessionId(groupId, userId);
        debugPrint(
          '[SessionService] Firebase movement_session_id: $firebaseSessionId',
        );

        // 가장 최근 세션만 Firebase와 비교 (세션은 start_time DESC로 정렬됨)
        final firstSessionId = sessions[0]['session_id'] as String?;
        if (firstSessionId != null) {
          if (firebaseSessionId == null) {
            // Firebase 읽기 실패 또는 값 없음 → 완료
            firstSessionIsOngoing = false;
          } else {
            // Firebase 값과 세션 ID 일치 여부 확인
            firstSessionIsOngoing = (firebaseSessionId == firstSessionId);
          }
        }
      } else {
        // 과거 날짜는 Firebase 조회 생략
        debugPrint('[SessionService] 과거 날짜이므로 Firebase 조회 생략: $date');
        firstSessionIsOngoing = false; // 모든 세션 완료 처리
      }

      // 세션 데이터 변환
      final transformedSessions = <Map<String, dynamic>>[];

      for (int i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        final sessionId = session['session_id'] as String?;
        if (sessionId == null) continue;

        final startTime = session['start_time'] as String?;
        final endTime = session['end_time'] as String?;
        final locationCount = session['location_count'] as int? ?? 0;

        // 가장 최근 세션만 Firebase와 비교, 나머지는 모두 완료
        bool isCompleted;
        if (i == 0 && firstSessionIsOngoing == true) {
          // 첫 번째 세션(가장 최근)이 진행 중
          isCompleted = false;
        } else {
          // 첫 번째 세션이 완료되었거나, 나머지 세션들은 모두 완료
          isCompleted = true;
        }

        // 주소 구성
        final startLocation =
            session['start_location'] as Map<String, dynamic>?;
        String startAddress = _extractAddress(startLocation);

        final endLocation = session['end_location'] as Map<String, dynamic>?;
        String endAddress = _extractAddress(endLocation);

        final sessionData = {
          'session_id': sessionId,
          'start_time': startTime,
          'end_time': endTime,
          'last_recorded_at': endTime ?? startTime,
          'is_completed': isCompleted,
          'location_count': locationCount,
          'locations': null, // 위치 데이터는 나중에 로드
          'start_location': startLocation,
          'end_location': endLocation,
          'start_address': startAddress,
          'end_address': endAddress,
          'total_distance_km': session['total_distance_km'],
          'map_image_url': session['map_image_url'], // Firebase Storage URL
          'map_image_base64': session['map_image_base64'], // Base64 (하위 호환성)
          'vehicle_type': session['vehicle_type'], // 차량 타입 추가
          'event_count': session['event_count'], // 이벤트 카운트 추가
          'max_speed_kmh': session['max_speed_kmh'], // 최고 속도 추가
        };

        transformedSessions.add(sessionData);
      }

      // 시작 시간 기준 내림차순 정렬
      transformedSessions.sort(
        (a, b) =>
            (b['start_time'] as String).compareTo(a['start_time'] as String),
      );

      return transformedSessions;
    } catch (e) {
      debugPrint('[SessionService] 날짜별 세션 조회 실패: $e');
      return [];
    }
  }

  /// 세션 리스트 조회 및 데이터 변환 (모든 날짜의 세션 조회)
  /// @deprecated 이 메서드는 모든 날짜를 순회하므로 사용하지 마세요.
  /// 대신 getSessionsByDate를 사용하세요.
  @Deprecated(
    'Use getSessionsByDate instead. This method queries all dates which is inefficient.',
  )
  Future<SessionListData> getSessions(String userId) async {
    try {
      debugPrint('[SessionService] 세션 리스트 조회 시작: userId=$userId');

      // 1. 날짜 범위 조회
      final dateRange = await getSessionDateRange(userId);
      if (dateRange == null ||
          dateRange['start_date'] == null ||
          dateRange['end_date'] == null) {
        debugPrint('[SessionService] 날짜 범위가 없습니다. 빈 리스트 반환');
        return SessionListData(completedSessions: [], ongoingSession: null);
      }

      final startDateStr = dateRange['start_date'] as String;
      final endDateStr = dateRange['end_date'] as String;
      debugPrint('[SessionService] 날짜 범위: $startDateStr ~ $endDateStr');

      // 2. 날짜 범위 내의 모든 날짜에 대해 세션 조회
      final allSessions = <Map<String, dynamic>>[];
      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);
      var currentDate = startDate;

      while (currentDate.isBefore(endDate) ||
          currentDate.isAtSameMomentAs(endDate)) {
        final dateStr =
            '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
        debugPrint('[SessionService] 날짜별 세션 조회: $dateStr');

        final sessions = await getSessionsByDate(userId, dateStr);
        allSessions.addAll(sessions);

        currentDate = currentDate.add(const Duration(days: 1));
      }

      debugPrint('[SessionService] 전체 세션 조회 완료: ${allSessions.length}개');

      // 3. 완료된 세션과 이동 중인 세션 분리
      final separated = separateSessions(allSessions);
      final completedSessions =
          separated['completedSessions'] as List<Map<String, dynamic>>;
      final ongoingSession =
          separated['ongoingSession'] as Map<String, dynamic>?;

      debugPrint(
        '[SessionService] 세션 리스트 조회 완료: 완료된 세션 ${completedSessions.length}개, 이동 중인 세션 ${ongoingSession != null ? 1 : 0}개',
      );

      return SessionListData(
        completedSessions: completedSessions,
        ongoingSession: ongoingSession,
      );
    } catch (e) {
      debugPrint('[SessionService] 세션 리스트 조회 실패: $e');
      rethrow;
    }
  }

  /// 세션 상세 조회
  Future<Map<String, dynamic>?> getSessionDetail(
    String userId,
    String sessionId,
  ) async {
    try {
      debugPrint(
        '[SessionService] 세션 상세 조회 시작: userId=$userId, sessionId=$sessionId',
      );
      final detail = await _apiService.getMovementSessionDetail(
        userId: userId,
        sessionId: sessionId,
      );

      if (detail == null) {
        return null;
      }

      // Firebase에서 사용자의 movement_session_id 조회
      final groupId =
          await AppCache.groupId ?? '00000000-0000-0000-0000-000000000002';
      final firebaseSessionId = await _firebaseLocationService
          .getUserMovementSessionId(groupId, userId);
      debugPrint(
        '[SessionService] Firebase movement_session_id: $firebaseSessionId',
      );

      // Firebase 비교 로직으로 is_completed 결정
      bool isCompleted;
      if (firebaseSessionId == null) {
        // Firebase 읽기 실패 또는 값 없음 → 완료
        isCompleted = true;
      } else if (firebaseSessionId == sessionId) {
        // Firebase 값과 세션 ID 일치 → 이동중
        isCompleted = false;
      } else {
        // Firebase 값과 세션 ID 불일치 → 완료
        isCompleted = true;
      }

      // is_completed 업데이트
      detail['is_completed'] = isCompleted;
      debugPrint(
        '[SessionService] 세션 상세 조회 완료: is_completed=$isCompleted (Firebase 비교)',
      );

      return detail;
    } catch (e) {
      debugPrint('[SessionService] 세션 상세 조회 실패: $e');
      return null;
    }
  }

  /// 주소 추출 (세션의 start_location/end_location에서)
  String _extractAddress(Map<String, dynamic>? location) {
    if (location == null) return '위치 없음';

    if (location['address'] != null &&
        location['address'].toString().isNotEmpty) {
      return location['address'].toString();
    } else if (location['city'] != null &&
        location['city'].toString().isNotEmpty) {
      return location['city'].toString();
    } else if (location['country'] != null &&
        location['country'].toString().isNotEmpty) {
      return location['country'].toString();
    }

    return '위치 없음';
  }
}

/// 세션 리스트 데이터 모델
class SessionListData {

  SessionListData({required this.completedSessions, this.ongoingSession});
  final List<Map<String, dynamic>> completedSessions;
  final Map<String, dynamic>? ongoingSession;
}
