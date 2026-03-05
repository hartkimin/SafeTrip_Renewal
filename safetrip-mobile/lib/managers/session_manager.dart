import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location.dart' as location_model;
import '../services/session_service.dart';
import '../services/session_path_manager.dart';
import '../utils/map_utils.dart' as map_utils;

/// 세션 데이터 관리 및 경로 렌더링을 담당하는 Manager 클래스
class SessionManager {

  SessionManager({
    required SessionService sessionService,
    required this.onSessionsLoaded,
    required this.onSessionSelected,
    required this.onPathRendered,
    required this.onSessionLabelChanged,
    required this.onUserMarkerUpdateRequested,
    required this.onCameraFitRequested,
    required this.onStartEndMarkersFitRequested,
    required this.isMounted,
    required this.getSelectedUserId,
    required this.getSelectedUserName,
    required this.getSelectedUserLocation,
    required this.getUsers,
    required this.createUserCustomMarker,
    required this.addUserMarker,
    required this.removeUserMarkers,
  }) : _sessionService = sessionService;
  // 상태
  List<Map<String, dynamic>> _userSessions = [];
  Map<String, dynamic>? _userOngoingSession;
  String? _selectedSessionId;
  String? _currentOngoingSessionId;
  final SessionPathManager _sessionPathManager = SessionPathManager();
  LatLng? _lastOngoingPathLocation;
  Timer? _sessionUpdateTimer;
  bool _isFirstLocationUpdate = true;

  // 서비스
  final SessionService _sessionService;

  // 콜백 함수들
  final Function(List<Map<String, dynamic>>, Map<String, dynamic>?) onSessionsLoaded;
  final Function(String?) onSessionSelected;
  final Function(List<Marker>, List<Polyline>) onPathRendered;
  final Function(String) onSessionLabelChanged;
  final Function(String, String, LatLng?) onUserMarkerUpdateRequested;
  final Function(List<LatLng>, {bool force, BuildContext? context}) onCameraFitRequested;
  final Function(LatLng, LatLng, {bool force, BuildContext? context}) onStartEndMarkersFitRequested;
  final bool Function() isMounted;
  final String? Function() getSelectedUserId;
  final String? Function() getSelectedUserName;
  final location_model.Location? Function() getSelectedUserLocation;
  final List<Map<String, dynamic>> Function() getUsers;
  final Future<Widget> Function({String? profileImageUrl, double scale}) createUserCustomMarker;
  final void Function(String, String, LatLng, Widget) addUserMarker;
  final void Function({String? exceptUserId, bool includeSelectedUser, bool includeCurrentUser}) removeUserMarkers;

  // Getters
  List<Map<String, dynamic>> get userSessions => List.from(_userSessions);
  Map<String, dynamic>? get userOngoingSession => _userOngoingSession;
  String? get selectedSessionId => _selectedSessionId;
  String? get currentOngoingSessionId => _currentOngoingSessionId;
  SessionPathManager get sessionPathManager => _sessionPathManager;
  LatLng? get lastOngoingPathLocation => _lastOngoingPathLocation;
  bool get isFirstLocationUpdate => _isFirstLocationUpdate;

  /// 사용자 세션 로드
  Future<void> loadUserSessions(
    String userId, {
    LatLng? targetPosition,
    DateTime? selectedDate, // 선택한 날짜 (없으면 가장 최근 날짜 사용)
  }) async {
    if (getSelectedUserId() == null) {
      return;
    }

    try {
      // 날짜 범위 조회
      final dateRange = await _sessionService.getSessionDateRange(userId);
      
      if (dateRange == null) {
        onSessionsLoaded([], null);
        return;
      }

      // 선택한 날짜 결정
      DateTime targetDate;
      if (selectedDate != null) {
        targetDate = selectedDate;
      } else if (dateRange['end_date'] != null) {
        // 가장 최근 날짜 사용
        final endDateStr = dateRange['end_date'] as String;
        final parts = endDateStr.split('-');
        if (parts.length == 3) {
          targetDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } else {
          targetDate = DateTime.now();
        }
      } else {
        targetDate = DateTime.now();
      }

      // UTC 날짜로 변환 (서버는 UTC 기준으로 비교)
      final utcDate = DateTime.utc(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final dateStr =
          '${utcDate.year}-${utcDate.month.toString().padLeft(2, '0')}-${utcDate.day.toString().padLeft(2, '0')}';

      // 선택한 날짜의 세션만 조회 (getSessions 대신 getSessionsByDate 사용)
      final sessions = await _sessionService.getSessionsByDate(userId, dateStr);

      // 완료된 세션과 이동 중인 세션 분리
      final separated = _sessionService.separateSessions(sessions);
      final completedSessions =
          separated['completedSessions'] as List<Map<String, dynamic>>;
      final ongoingSession =
          separated['ongoingSession'] as Map<String, dynamic>?;

      _userSessions = completedSessions;
      _userOngoingSession = ongoingSession;

      // 콜백 호출
      onSessionsLoaded(_userSessions, _userOngoingSession);

      // 처음 진입 시에는 실시간 모드로 시작 (selectedSessionId = null)
      if (_userOngoingSession != null) {
        final sessionId = _userOngoingSession!['session_id'] as String;
        final isOngoing = _userOngoingSession!['is_completed'] == false;

        // 이동 중인 세션 ID만 저장 (선택은 하지 않음)
        if (isOngoing) {
          _currentOngoingSessionId = sessionId;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[SessionManager] 세션 리스트 로드 실패: $e');
      debugPrint('[SessionManager] 스택 트레이스: $stackTrace');
    }
  }

  /// 세션 상세 데이터 로드
  Future<void> loadUserSessionDetail(String userId, String sessionId) async {
    try {
      final detail = await _sessionService.getSessionDetail(userId, sessionId);

      if (detail != null && detail['locations'] != null) {
        final locations = List<Map<String, dynamic>>.from(
          detail['locations'].map((loc) => Map<String, dynamic>.from(loc)),
        );

        // 서버에서 받은 is_completed 사용
        final isCompleted = detail['is_completed'] as bool? ?? false;
        final isOngoing = !isCompleted;

        final sessionIndex = _userSessions.indexWhere(
          (s) => s['session_id'] == sessionId,
        );
        if (sessionIndex >= 0) {
          _userSessions[sessionIndex]['locations'] = locations;
          _userSessions[sessionIndex]['is_completed'] = isCompleted;
        } else if (_userOngoingSession != null &&
            _userOngoingSession!['session_id'] == sessionId) {
          _userOngoingSession!['locations'] = locations;
          _userOngoingSession!['is_completed'] = isCompleted;
        }

        if (locations.isNotEmpty) {
          // 이동중 세션이면 SessionPathManager에 데이터 로드
          if (isOngoing) {
            await _sessionPathManager.loadFullSessionData(userId, sessionId);
          }

          // 렌더링 데이터 생성
          await renderSessionPath(sessionId, locations, isOngoing);
        }
      }
    } catch (e) {
      debugPrint('[SessionManager] 세션 상세 로드 실패: $e');
    }
  }

  /// 세션 찾기
  Map<String, dynamic>? findSessionById(String sessionId) {
    if (_userOngoingSession != null &&
        _userOngoingSession!['session_id'] == sessionId) {
      return _userOngoingSession;
    }
    try {
      return _userSessions.firstWhere((s) => s['session_id'] == sessionId);
    } catch (e) {
      return null;
    }
  }

  /// 세션 데이터 로드 (필요한 경우)
  Future<Map<String, dynamic>?> loadSessionIfNeeded(
    String sessionId,
    Map<String, dynamic>? session,
  ) async {
    if (session == null) return null;

    final locations = session['locations'] as List<Map<String, dynamic>>?;
    if (locations != null && locations.isNotEmpty) {
      return session;
    }

    // 세션 상세 데이터 로드
    await loadUserSessionDetail(getSelectedUserId()!, sessionId);

    // 다시 세션 찾기
    final reloadedSession = findSessionById(sessionId);
    if (reloadedSession == null) return null;

    final reloadedLocations =
        reloadedSession['locations'] as List<Map<String, dynamic>>?;
    if (reloadedLocations == null || reloadedLocations.isEmpty) {
      return null;
    }

    return reloadedSession;
  }

  /// 세션 위치 데이터 준비
  List<Map<String, dynamic>> prepareSessionLocations(
    Map<String, dynamic> session,
  ) {
    final locationsList = (session['locations'] as List<Map<String, dynamic>>)
        .toList();
    // null인 recorded_at 필터링
    locationsList.removeWhere((loc) => loc['recorded_at'] == null);
    locationsList.sort((a, b) {
      final aTime = a['recorded_at'] as String? ?? '';
      final bTime = b['recorded_at'] as String? ?? '';
      return aTime.compareTo(bTime);
    });
    return locationsList;
  }

  /// 세션 경로 렌더링
  Future<void> renderSessionPath(
    String sessionId,
    List<Map<String, dynamic>> locationsList,
    bool isOngoing,
  ) async {
    if (isOngoing) {
      // SessionPathManager에 데이터 로드
      await _sessionPathManager.loadFullSessionData(
        getSelectedUserId()!,
        sessionId,
      );

      // 메모리 데이터로 경로 그리기
      await updateOngoingPathFromMemory();

      // 마지막 위치를 현재 위치로 초기화
      final selectedUserLocation = getSelectedUserLocation();
      if (selectedUserLocation != null) {
        _lastOngoingPathLocation = LatLng(
          selectedUserLocation.latitude,
          selectedUserLocation.longitude,
        );
      }
      return;
    }

    // 종료된 세션: 렌더링 데이터 생성
    final renderData = await _sessionPathManager.createPathRenderData(
      userId: getSelectedUserId()!,
      sessionId: sessionId,
      isOngoing: false,
      locations: locationsList,
      onMarkerTap: (locationData, {bool isStart = false}) {
        // 카드 표시 제거
      },
    );

    if (!isMounted()) return;

    // 콜백을 통해 마커와 폴리라인 업데이트
    onPathRendered(renderData.markers, renderData.polylines);
  }

  /// 세션 선택 시 경로 표시
  Future<void> selectSession(String sessionId) async {
    if (getSelectedUserId() == null) return;

    try {
      debugPrint('[SessionManager] 세션 선택 시작 - sessionId: $sessionId');

      // 세션 선택 시 메모리 초기화
      _sessionPathManager.clear();

      // 세션 선택 상태 업데이트
      _selectedSessionId = sessionId;
      onSessionSelected(sessionId);

      // 세션 찾기
      var session = findSessionById(sessionId);
      if (session == null) {
        debugPrint('[SessionManager] 세션을 찾을 수 없습니다: $sessionId');
        return;
      }

      // 세션 데이터 로드 (필요한 경우)
      session = await loadSessionIfNeeded(sessionId, session);
      if (session == null) return;

      // 세션 위치 데이터 준비
      final locationsList = prepareSessionLocations(session);

      // 세션 상태 확인
      final isCompleted = session['is_completed'] as bool? ?? false;
      final isOngoing = !isCompleted;

      // 세션 경로 렌더링
      await renderSessionPath(sessionId, locationsList, isOngoing);
    } catch (e) {
      debugPrint('[SessionManager] 세션 선택 실패: $e');
    }
  }

  /// 메모리 데이터로 경로 그리기
  Future<void> updateOngoingPathFromMemory() async {
    if (!_sessionPathManager.hasData) {
      return;
    }

    final sessionId = _sessionPathManager.sessionId!;

    // session['is_completed']를 사용해서 isOngoing 판단
    bool isOngoing = false;
    if (_userOngoingSession != null &&
        _userOngoingSession!['session_id'] == sessionId) {
      final isCompleted =
          _userOngoingSession!['is_completed'] as bool? ?? false;
      isOngoing = !isCompleted;
    } else {
      try {
        final session = _userSessions.firstWhere(
          (s) => s['session_id'] == sessionId,
        );
        final isCompleted = session['is_completed'] as bool? ?? false;
        isOngoing = !isCompleted;
      } catch (e) {
        isOngoing = false;
      }
    }

    final renderData = await _sessionPathManager.createPathRenderData(
      userId: getSelectedUserId()!,
      sessionId: sessionId,
      isOngoing: isOngoing,
      onMarkerTap: (locationData, {bool isStart = false}) {
        // 카드 표시 제거
      },
    );

    if (!isMounted()) return;

    // 콜백을 통해 마커와 폴리라인 업데이트
    onPathRendered(renderData.markers, renderData.polylines);

    // 이동중일 때 프로필 사진이 있는 사용자 마커 추가 (현재 위치에)
    if (isOngoing && getSelectedUserId() != null && getSelectedUserName() != null) {
      final selectedUserLocation = getSelectedUserLocation();
      if (selectedUserLocation != null) {
        final currentPosition = LatLng(
          selectedUserLocation.latitude,
          selectedUserLocation.longitude,
        );

        // 프로필 이미지 URL 가져오기
        String? profileImageUrl;
        try {
          final users = getUsers();
          final user = users.firstWhere(
            (u) => (u['user_id'] as String?) == getSelectedUserId(),
          );
          profileImageUrl = user['profile_image_url'] as String?;
        } catch (e) {
          // 사용자를 찾을 수 없으면 null
        }

        final customIcon = await createUserCustomMarker(
          profileImageUrl: profileImageUrl,
        );

        if (isMounted()) {
          // 기존 사용자 마커 제거
          removeUserMarkers(includeSelectedUser: true, includeCurrentUser: true);
          // 프로필 사진이 있는 사용자 마커 추가 (현재 위치에)
          addUserMarker(
            getSelectedUserId()!,
            getSelectedUserName()!,
            currentPosition,
            customIcon,
          );
        }
      }
    }
  }

  /// 현재 세션 라벨 가져오기
  String getCurrentSessionLabel() {
    if (_selectedSessionId == null) {
      return '실시간 위치 보기';
    }

    Map<String, dynamic>? session = findSessionById(_selectedSessionId!);

    if (session == null) {
      return '이동 세션 보기';
    }

    final startTime = session['start_time'] as String?;
    final endTime = session['end_time'] as String?;

    if (startTime == null) {
      return '이동 세션 보기';
    }

    try {
      final startStr = map_utils.formatLocalTimeFromString(
            startTime,
            format: 'MM-dd HH:mm',
          ) ??
          '알 수 없음';
      if (endTime != null) {
        final endStr = map_utils.formatLocalTimeFromString(
              endTime,
              format: 'MM-dd HH:mm',
            ) ??
            '알 수 없음';
        return '$startStr ~ $endStr';
      } else {
        return '$startStr ~ 진행중';
      }
    } catch (_) {
      return '이동 세션 보기';
    }
  }

  /// 세션 메뉴 선택 처리
  Future<void> handleSessionMenuSelection(String value) async {
    if (value == 'realtime') {
      // 실시간 항목을 클릭했을 때는 항상 실시간 모드로 전환
      _selectedSessionId = null;
      _isFirstLocationUpdate = true;
      onSessionSelected(null);
      onSessionLabelChanged(getCurrentSessionLabel());
    } else {
      _sessionUpdateTimer?.cancel();
      _currentOngoingSessionId = null;
      await selectSession(value);
      onSessionLabelChanged(getCurrentSessionLabel());
    }
  }

  /// 세션 초기화
  void clearSessions() {
    _userSessions.clear();
    _userOngoingSession = null;
    _selectedSessionId = null;
    _currentOngoingSessionId = null;
    _sessionPathManager.clear();
    _lastOngoingPathLocation = null;
    _isFirstLocationUpdate = true;
    _sessionUpdateTimer?.cancel();
    _sessionUpdateTimer = null;
  }

  /// 리소스 정리
  void dispose() {
    _sessionUpdateTimer?.cancel();
    _sessionUpdateTimer = null;
  }
}

