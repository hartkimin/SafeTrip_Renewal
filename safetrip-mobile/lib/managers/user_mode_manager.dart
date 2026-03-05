import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/location.dart' as location_model;
import '../services/user_service.dart';
import '../services/session_service.dart';
import '../services/geocoding_service.dart';

/// 개별 사용자 모드 관리를 담당하는 Manager 클래스
class UserModeManager {

  UserModeManager({
    required this.onUserModeChanged,
    required this.onUserSelected,
    required this.onUserModeExited,
    required this.onUserSessionsLoadRequested,
    required this.onAppStatusCheckRequested,
    required this.isMounted,
  });
  // 상태
  String? _selectedUserId;
  String? _selectedUserName;
  location_model.Location? _selectedUserLocation;
  bool _isFirstLocationUpdate = true;

  // 서비스
  SessionService? _sessionService;
  GeocodingService? _geocodingService;
  UserService? _userService;

  // 콜백 함수들
  final Function(String?, String?, location_model.Location?, bool) onUserModeChanged;
  final Function(String, String) onUserSelected;
  final Function() onUserModeExited;
  final Future<void> Function(String, {LatLng? targetPosition}) onUserSessionsLoadRequested;
  final Future<void> Function(String, String) onAppStatusCheckRequested;
  final bool Function() isMounted;

  // Getters
  String? get selectedUserId => _selectedUserId;
  String? get selectedUserName => _selectedUserName;
  location_model.Location? get selectedUserLocation => _selectedUserLocation;
  bool get isFirstLocationUpdate => _isFirstLocationUpdate;

  /// 사용자 선택
  Future<void> selectUser(
    String userId,
    String userName, {
    LatLng? targetPosition,
  }) async {
    debugPrint('[UserModeManager] 사용자 선택: $userName (ID: $userId)');
    onUserSelected(userId, userName);
  }

  /// 개별 사용자 모드 진입
  Future<void> enterUserMode(
    String userId,
    String userName,
    location_model.Location? initialLocation, {
    LatLng? targetPosition,
  }) async {
    // 서비스 초기화
    _sessionService ??= SessionService();
    _geocodingService ??= GeocodingService();
    _userService ??= UserService();

    // 상태 업데이트
    _selectedUserId = userId;
    _selectedUserName = userName;
    _selectedUserLocation = initialLocation;
    _isFirstLocationUpdate = true;

    // 콜백 호출
    onUserModeChanged(_selectedUserId, _selectedUserName, _selectedUserLocation, true);

    // 앱 상태 확인
    await onAppStatusCheckRequested(userId, userName);

    // 세션 로드
    await onUserSessionsLoadRequested(userId, targetPosition: targetPosition);
  }

  /// 메인 모드로 복귀
  void exitUserMode() {
    _selectedUserId = null;
    _selectedUserName = null;
    _selectedUserLocation = null;
    _isFirstLocationUpdate = true;

    // 콜백 호출
    onUserModeChanged(null, null, null, false);
    onUserModeExited();
  }

  /// 선택된 사용자 위치 업데이트
  void updateSelectedUserLocation(location_model.Location? location) {
    _selectedUserLocation = location;
  }

  /// 첫 위치 업데이트 플래그 리셋
  void resetFirstLocationUpdate() {
    _isFirstLocationUpdate = false;
  }

  /// 앱 상태 확인
  Future<void> checkAppStatus(String userId, String userName) async {
    await onAppStatusCheckRequested(userId, userName);
  }

  /// 리소스 정리
  void dispose() {
    _sessionService = null;
    _geocodingService = null;
    _userService = null;
  }
}

