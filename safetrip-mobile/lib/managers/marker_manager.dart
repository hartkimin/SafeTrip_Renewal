import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_tokens.dart';
import '../constants/map_constants.dart';
import '../models/location.dart' as location_model;

/// 마커 생성, 클러스터링, 업데이트를 담당하는 Manager 클래스
class MarkerManager {
  MarkerManager({
    required this.onMarkersUpdated,
    this.onAnimatedMarkersUpdated,
    required this.onUserSelected,
    required this.onClusterMarkerTapped,
    required this.onZoomLevelChanged,
    required this.onMarkerUpdateRequested,
    required this.isMounted,
    required this.getMapController,
    required this.getUsers,
    required this.getUserLocations,
    required this.getSelectedUserId,
    required this.calculateDistance,
    this.onMarkerTap,
    Set<String> Function()? getSelectedUserIdsForFilter,
    this.getBounceAnimation,
    this.getBounceJumpAnimation,
    this.getBreathingAnimation,
    this.getIsMoving,
    this.getAnimationController,
    this.getMarkerCurrentPosition,
    this.onMarkerPositionUpdated,
    this.isBeforeTripStart,
    this.currentPrivacyLevel,
    this.getScheduleTimeActive,
  }) : getSelectedUserIdsForFilter =
           getSelectedUserIdsForFilter ?? (() => <String>{});

  // 상태
  final List<Marker> _markers = [];
  double _currentZoomLevel = MapConstants.defaultZoomLevel;
  final Map<String, LatLng> _originalPositions = {};
  Timer? _zoomUpdateTimer;
  // markerWidget 캐시 (재생성 방지)
  final Map<String, Widget> _markerWidgetCache = {};
  // 이미지 캐시 (IPC 호출 최소화)
  final Map<String, ui.Image> _imageCache = {};
  // 마커 크기 캐시 (Union_solo.png 크기)
  double? _cachedMarkerWidth;
  double? _cachedMarkerHeight;

  // 콜백 함수들
  final Function(List<Marker>) onMarkersUpdated;
  final Function(List<Marker>)? onAnimatedMarkersUpdated;
  final Function(String, String, {LatLng? targetPosition}) onUserSelected;
  final Function(List<LatLng>) onClusterMarkerTapped;
  final Function(double) onZoomLevelChanged;
  final Function() onMarkerUpdateRequested;
  final void Function(String)? onMarkerTap;
  final bool Function() isMounted;

  /// 사용자 마커 생성 (개별 사용자 모드용)
  Future<List<Marker>> buildUserMarkers() async {
    return await getFilteredUserMarkers();
  }

  final MapController? Function() getMapController;
  final Animation<double>? Function()? getBounceAnimation; // 사용자 마커 바운스 애니메이션
  final Animation<double>? Function()?
  getBounceJumpAnimation; // 사용자 마커 점프 애니메이션
  final Animation<double>? Function()?
  getBreathingAnimation; // 사용자 마커 숨쉬는 애니메이션 (is_moving = false)
  final bool? Function(String)? getIsMoving; // 사용자별 isMoving 상태 조회
  final AnimationController? Function(String)?
  getAnimationController; // 마커 애니메이션 컨트롤러 (Phase 3)
  final LatLng? Function(String)?
  getMarkerCurrentPosition; // 마커 현재 위치 조회 (Phase 3)
  final void Function(String, LatLng)?
  onMarkerPositionUpdated; // 마커 위치 업데이트 콜백 (Phase 3)
  final bool Function()? isBeforeTripStart; // 여행 시작일 전 여부
  final String Function()? currentPrivacyLevel;
  final bool Function(String userId)? getScheduleTimeActive;

  // 외부 데이터 (읽기 전용)
  final List<Map<String, dynamic>> Function() getUsers;
  final Map<String, location_model.Location> Function() getUserLocations;
  final String? Function() getSelectedUserId;
  final Set<String> Function() getSelectedUserIdsForFilter;

  // 거리 계산 함수
  final double Function(LatLng, LatLng) calculateDistance;

  // 상수
  static const double _locationChangeThreshold = 0.00001;

  /// 마커 List 가져오기
  List<Marker> get markers => List.from(_markers);

  /// 현재 줌 레벨 가져오기
  double get currentZoomLevel => _currentZoomLevel;

  /// 원본 위치 가져오기
  Map<String, LatLng> get originalPositions => Map.from(_originalPositions);

  /// 줌 레벨 업데이트
  void updateZoomLevel(double zoomLevel) {
    if ((_currentZoomLevel - zoomLevel).abs() > 0.5) {
      _currentZoomLevel = zoomLevel;
      onZoomLevelChanged(_currentZoomLevel);
    }
  }

  /// 원본 위치 업데이트
  void updateOriginalPositions(Map<String, LatLng> positions) {
    _originalPositions.clear();
    _originalPositions.addAll(positions);
  }

  /// 네트워크 이미지 로드
  Future<ui.Image?> _loadImageFromUrl(String url) async {
    try {
      final completer = Completer<ui.Image?>();
      final imageProvider = NetworkImage(url);
      final imageStream = imageProvider.resolve(const ImageConfiguration());

      imageStream.addListener(
        ImageStreamListener(
          (ImageInfo info, bool _) {
            completer.complete(info.image);
          },
          onError: (exception, stackTrace) {
            completer.complete(null);
          },
        ),
      );

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Assets 이미지 로드
  Future<ui.Image?> loadImageFromAssets(String assetPath) async {
    // 캐시 확인
    if (_imageCache.containsKey(assetPath)) {
      return _imageCache[assetPath];
    }

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      // 캐시에 저장
      _imageCache[assetPath] = frameInfo.image;
      return frameInfo.image;
    } catch (e) {
      return null;
    }
  }

  /// 마커 크기 가져오기 (캐시된 값 사용)
  Future<void> _ensureMarkerSize() async {
    if (_cachedMarkerWidth != null && _cachedMarkerHeight != null) {
      return;
    }

    final markerBg = await loadImageFromAssets('assets/images/Union_solo.png');
    if (markerBg != null) {
      _cachedMarkerWidth = markerBg.width.toDouble() / 3.0;
      _cachedMarkerHeight = markerBg.height.toDouble() / 3.0;
    }
  }

  /// 뱃지 타입 결정 (개별 마커용)
  String _getMovementBadgeType({
    required bool? isMoving,
    String? activityType,
  }) {
    // 우선순위 1: isMoving == false → 정지 뱃지
    if (isMoving == false) {
      return 'img-movement-still.png';
    }

    // 우선순위 2: isMoving == true && activityType in [walking, on_foot, running] → 도보 뱃지
    if (isMoving == true) {
      if (activityType == 'walking' ||
          activityType == 'on_foot' ||
          activityType == 'running') {
        return 'img-movement-walk.png';
      }

      // 우선순위 3: isMoving == true && activityType in [in_vehicle, on_bicycle] → 차량 뱃지
      if (activityType == 'in_vehicle' || activityType == 'on_bicycle') {
        return 'img-movement-car.png';
      }

      // 우선순위 4: isMoving == true && activityType == 'still' → 정지 뱃지
      if (activityType == 'still') {
        return 'img-movement-still.png';
      }
    }

    // 기본값: 정지 뱃지
    return 'img-movement-still.png';
  }

  /// 뱃지 타입 결정 (클러스터 마커용)
  String _getClusterBadgeType(Set<String> clusterUserIds) {
    final locations = getUserLocations();
    bool hasVehicle = false;
    bool hasWalking = false;

    for (final userId in clusterUserIds) {
      final location = locations[userId];
      if (location == null) continue;

      final isMoving = location.isMoving ?? false;
      final activityType = location.activityType;

      // activityType == 'still'이면 정지로 카운트
      if (activityType == 'still' || !isMoving) {
        continue; // 정지는 카운트하지 않음 (기본값)
      }

      if (isMoving) {
        if (activityType == 'in_vehicle' || activityType == 'on_bicycle') {
          hasVehicle = true;
        } else if (activityType == 'walking' ||
            activityType == 'on_foot' ||
            activityType == 'running') {
          hasWalking = true;
        }
      }
    }

    // 우선순위: 차량 > 도보 > 정지
    if (hasVehicle) {
      return 'img-movement-car.png';
    }
    if (hasWalking) {
      return 'img-movement-walk.png';
    }
    return 'img-movement-still.png';
  }

  /// 개별 마커 생성 (Union_solo.png 사용) - Widget 반환
  Future<Widget> createCustomMarker({
    String? profileImageUrl,
    String? userId,
    double scale = 1.0,
    String? activityType,
    bool? isMoving,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 마커 배경 이미지 로드 (Union_solo.png)
    final markerBg = await loadImageFromAssets('assets/images/Union_solo.png');
    if (markerBg == null) {
      throw Exception('Union_solo.png를 로드할 수 없습니다');
    }

    final width = markerBg.width * scale;
    final height = markerBg.height * scale;

    // 마커 배경 그리기
    canvas.scale(scale);
    canvas.drawImage(markerBg, Offset.zero, Paint());

    // 프로필 이미지 로드 (profileImageUrl이 있을 때만)
    ui.Image? profileImage;

    // profileImageUrl이 없으면 기본 이미지만 사용
    if (profileImageUrl == null || profileImageUrl.isEmpty) {
      profileImage = await loadImageFromAssets('assets/images/avata_df.png');
    } else {
      // 1. 네트워크 URL에서 직접 로드 시도
      profileImage = await _loadImageFromUrl(profileImageUrl);

      // 2. 실패하면 기본 이미지
      profileImage ??= await loadImageFromAssets('assets/images/avata_df.png');
    }

    if (profileImage != null) {
      // 프로필 이미지를 원형으로 클리핑하여 배치
      final profileSize = markerBg.width * 0.75;
      final profileX = (markerBg.width - profileSize) / 2;
      final profileY = profileX;

      final profileRect = Rect.fromLTWH(
        profileX,
        profileY,
        profileSize,
        profileSize,
      );
      final path = ui.Path()..addOval(profileRect);

      canvas.save();
      canvas.clipPath(path);
      canvas.drawImageRect(
        profileImage,
        Rect.fromLTWH(
          0,
          0,
          profileImage.width.toDouble(),
          profileImage.height.toDouble(),
        ),
        profileRect,
        Paint(),
      );
      canvas.restore();
    }

    // 뱃지 그리기 (오른쪽 아래)
    final badgeType = _getMovementBadgeType(
      isMoving: isMoving,
      activityType: activityType,
    );
    final badgeImage = await loadImageFromAssets('assets/images/$badgeType');

    if (badgeImage != null) {
      // 뱃지 크기 (마커 크기의 25%)
      final badgeSize = markerBg.width * 0.3;
      // 오른쪽 아래 위치 (5% 여백)
      final badgeX = markerBg.width - badgeSize - (markerBg.width * 0.05);
      final badgeY = markerBg.height - badgeSize - (markerBg.height * 0.05);

      canvas.drawImageRect(
        badgeImage,
        Rect.fromLTWH(
          0,
          0,
          badgeImage.width.toDouble(),
          badgeImage.height.toDouble(),
        ),
        Rect.fromLTWH(badgeX, badgeY, badgeSize, badgeSize),
        Paint(),
      );
    }

    // 이미지로 변환
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();

    return Image.memory(
      uint8List,
      width: width,
      height: height,
      fit: BoxFit.fill,
    );
  }

  /// 클러스터 마커 생성 (Union.png 사용) - Widget 반환
  Future<Widget> createClusterMarker({
    required int count,
    double scale = 1.0,
    Set<String>? clusterUserIds,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 마커 배경 이미지 로드 (Union.png)
    final markerBg = await loadImageFromAssets('assets/images/Union.png');
    if (markerBg == null) {
      throw Exception('Union.png를 로드할 수 없습니다');
    }

    // 항상 원본 크기로 이미지 생성 (고해상도 유지)
    final width = markerBg.width.toDouble();
    final height = markerBg.height.toDouble();

    // 마커 배경 그리기 (scale 제거)
    canvas.drawImage(markerBg, Offset.zero, Paint());

    // 클러스터용 프로필 이미지 로드 (default_profile_dimmed.png)
    final profileImage = await loadImageFromAssets(
      'assets/images/default_profile_dimmed.png',
    );

    if (profileImage != null) {
      final profileSize = markerBg.width * 0.75;
      final profileX = (markerBg.width - profileSize) / 2;
      final profileY = profileX;

      final profileRect = Rect.fromLTWH(
        profileX,
        profileY,
        profileSize,
        profileSize,
      );
      final path = ui.Path()..addOval(profileRect);

      canvas.save();
      canvas.clipPath(path);
      canvas.drawImageRect(
        profileImage,
        Rect.fromLTWH(
          0,
          0,
          profileImage.width.toDouble(),
          profileImage.height.toDouble(),
        ),
        profileRect,
        Paint(),
      );
      canvas.restore();
    }

    // 숫자 텍스트 그리기 ("+4" 형식)
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 50,
      fontWeight: FontWeight.bold,
    );

    final displayText = count > 1 ? '+$count' : count.toString();
    final textPainter = TextPainter(
      text: TextSpan(text: displayText, style: textStyle),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    // 숫자를 프로필 이미지 중앙에 배치
    final centerX = markerBg.width / 2;
    final profileSize = markerBg.width * 0.75;
    final profileX = (markerBg.width - profileSize) / 2;
    final profileY = profileX;
    final profileCenterY = profileY + profileSize / 2;

    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        profileCenterY - textPainter.height / 2,
      ),
    );

    // 뱃지 그리기 (오른쪽 아래) - 클러스터 마커용
    if (clusterUserIds != null && clusterUserIds.isNotEmpty) {
      final badgeType = _getClusterBadgeType(clusterUserIds);
      final badgeImage = await loadImageFromAssets('assets/images/$badgeType');

      if (badgeImage != null) {
        // 뱃지 크기 (마커 크기의 25%)
        final badgeSize = markerBg.width * 0.3;
        // 오른쪽 아래 위치 (5% 여백)
        final badgeX = markerBg.width - badgeSize - (markerBg.width * 0.05);
        final badgeY = markerBg.height - badgeSize - (markerBg.height * 0.05);

        canvas.drawImageRect(
          badgeImage,
          Rect.fromLTWH(
            0,
            0,
            badgeImage.width.toDouble(),
            badgeImage.height.toDouble(),
          ),
          Rect.fromLTWH(badgeX, badgeY, badgeSize, badgeSize),
          Paint(),
        );
      }
    }

    // 이미지로 변환
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();

    return Image.memory(
      uint8List,
      width: width,
      height: height,
      fit: BoxFit.fill, // 위젯 크기를 정확히 채우도록 변경
    );
  }

  /// 사용자 커스텀 마커 생성 (개별 사용자 모드용)
  Future<Widget> createUserCustomMarker({
    String? profileImageUrl,
    String? userId,
    double scale = 1.0,
    String? activityType,
    bool? isMoving,
  }) async {
    return await createCustomMarker(
      profileImageUrl: profileImageUrl,
      userId: userId,
      scale: scale,
      activityType: activityType,
      isMoving: isMoving,
    );
  }

  /// 필터링된 사용자 마커 리스트 반환
  /// location_sharing_enabled, can_view_all_locations, 선택된 사용자 필터링 적용
  /// 여행 시작일 전이면 현재 사용자만 표시
  Future<List<Marker>> getFilteredUserMarkers() async {
    // 개별 사용자 모드일 때는 다른 사용자 마커를 추가하지 않음
    if (getSelectedUserId() != null) {
      return [];
    }

    // 현재 사용자의 can_view_all_locations 권한 확인
    final users = getUsers();
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id');
    bool canViewAllLocations = false;

    if (currentUserId != null) {
      final currentUser = users.firstWhere(
        (u) => (u['user_id'] as String?) == currentUserId,
        orElse: () => <String, dynamic>{},
      );
      canViewAllLocations =
          currentUser['can_view_all_locations'] as bool? ?? false;
    }

    // 여행 시작일 전이면 현재 사용자만 표시 (단, 보호자인 경우 보호대상도 표시)
    final beforeTripStart = isBeforeTripStart?.call() ?? false;
    if (beforeTripStart && currentUserId != null) {
      final filteredPositions = <String, LatLng>{};

      // getUsers()는 이미 필터링된 리스트를 반환
      // users가 비어있지 않으면 보호자 모드 (보호대상이 있음)
      // users가 비어있으면 일반 여행자 모드
      if (users.isNotEmpty) {
        // 보호자 모드: 보호대상만 표시 (users에 보호자 자신은 이미 제외됨)
        for (final user in users) {
          final userId = user['user_id'] as String?;
          if (userId != null) {
            final position = _originalPositions[userId];
            if (position != null) {
              filteredPositions[userId] = position;
            }
          }
        }
        debugPrint(
          '[MarkerManager] 여행 시작일 전 - 보호자 모드: 보호대상 ${filteredPositions.length}명 표시',
        );
      } else {
        // 일반 여행자 모드: 현재 사용자만 표시
        final currentUserPosition = _originalPositions[currentUserId];
        if (currentUserPosition != null) {
          filteredPositions[currentUserId] = currentUserPosition;
        }
        debugPrint('[MarkerManager] 여행 시작일 전 - 일반 여행자 모드: 현재 사용자만 표시');
      }

      // 필터링된 위치로 개별 마커 생성
      final userLocations = getUserLocations();
      final markers = <Marker>[];

      for (final entry in filteredPositions.entries) {
        final userId = entry.key;
        final position = entry.value;
        final location = userLocations[userId];

        if (location != null) {
          final marker = await buildSingleMarker(userId, position, location);
          if (marker != null) {
            markers.add(marker);
          }
        }
      }

      return markers;
    }

    // 선택된 사용자 ID Set 가져오기
    final selectedUserIdsForFilter = getSelectedUserIdsForFilter();

    // _originalPositions 필터링 (위치 공유 중단된 사용자 제외 및 선택된 사용자 필터링)
    // getUsers()에 포함된 사용자만 처리 (보호자 필터링 등이 이미 적용된 상태)
    debugPrint(
      '[MarkerManager] getFilteredUserMarkers: _originalPositions=${_originalPositions.length}개, users=${users.length}명',
    );

    final filteredPositions = <String, LatLng>{};
    for (final entry in _originalPositions.entries) {
      final userId = entry.key;

      // 필터링된 users 리스트에 포함된 사용자인지 확인
      final user = users.firstWhere(
        (u) => (u['user_id'] as String?) == userId,
        orElse: () => <String, dynamic>{},
      );

      // users 리스트에 없는 사용자는 스킵 (보호자 필터링 등으로 제외된 사용자)
      if (user.isEmpty) {
        continue;
      }

      final locationSharingEnabled =
          user['location_sharing_enabled'] as bool? ?? true;

      // 권한이 있거나 위치 공유가 활성화된 경우만 포함
      if (locationSharingEnabled || canViewAllLocations) {
        // 선택된 사용자 필터링: 선택된 사용자가 있으면 선택된 사용자만 표시, 없으면 모두 표시
        if (selectedUserIdsForFilter.isEmpty ||
            selectedUserIdsForFilter.contains(userId)) {
          filteredPositions[userId] = entry.value;
        }
      }
    }

    // §6: 프라이버시 등급별 마커 필터링
    final privacyLevel = currentPrivacyLevel?.call() ?? 'standard';
    if (privacyLevel == 'privacy_first' && getScheduleTimeActive != null) {
      // privacy_first: 일정 활성 시간대의 멤버만 표시 (본인은 항상 표시)
      filteredPositions.removeWhere((userId, _) {
        if (userId == currentUserId) return false;
        return !getScheduleTimeActive!(userId);
      });
      debugPrint(
        '[MarkerManager] §6 privacy_first 필터 적용: ${filteredPositions.length}명 표시',
      );
    }
    // safety_first: 모든 멤버 항상 표시 (추가 필터링 없음)
    // standard: 위치 공유 ON인 멤버만 표시 (위의 locationSharingEnabled 필터가 이미 적용됨)

    // 필터링된 위치로 개별 마커 생성
    final userLocations = getUserLocations();
    final markers = <Marker>[];

    for (final entry in filteredPositions.entries) {
      final userId = entry.key;
      final position = entry.value;
      final location = userLocations[userId];

      if (location != null) {
        final marker = await buildSingleMarker(userId, position, location);
        if (marker != null) {
          markers.add(marker);
        }
      }
    }

    return markers;
  }

  /// 단일 마커 생성 (Marker + TweenAnimationBuilder 사용)
  Future<Marker?> buildSingleMarker(
    String userId,
    LatLng position,
    location_model.Location location,
  ) async {
    // 프로필 이미지 URL 가져오기
    final users = getUsers();
    final user = users.firstWhere(
      (u) => (u['user_id'] as String?) == userId,
      orElse: () => <String, dynamic>{},
    );

    // 사용자 정보가 없으면 null 반환 (필터링된 사용자가 아님)
    if (user.isEmpty) {
      return null;
    }

    final profileImageUrl = user['profile_image_url'] as String?;
    final isMoving = location.isMoving ?? false;
    final speed = location.speed; // m/s

    // markerWidget 캐시 키 생성 (프로필 이미지, 활동 타입, isMoving 상태만 포함)
    final cacheKey =
        '$userId-${profileImageUrl ?? 'null'}-${location.activityType}-$isMoving';

    // 캐시된 markerWidget이 있으면 재사용, 없으면 생성
    Widget baseMarkerWidget;
    if (_markerWidgetCache.containsKey(cacheKey)) {
      baseMarkerWidget = _markerWidgetCache[cacheKey]!;
    } else {
      baseMarkerWidget = await createCustomMarker(
        profileImageUrl: profileImageUrl,
        userId: userId,
        activityType: location.activityType,
        isMoving: isMoving,
      );
      _markerWidgetCache[cacheKey] = baseMarkerWidget;
      // 오래된 캐시 정리 (최대 50개 유지)
      if (_markerWidgetCache.length > 50) {
        final keysToRemove = _markerWidgetCache.keys
            .take(_markerWidgetCache.length - 50)
            .toList();
        for (final key in keysToRemove) {
          _markerWidgetCache.remove(key);
        }
      }
    }

    // 속도 표시 추가 (이동 중일 때만, 속도가 0이어도 표시)
    Widget markerWidget;
    if (isMoving && speed != null) {
      final speedKmh = (speed * 3.6).round();
      markerWidget = Stack(
        clipBehavior: Clip.none, // 마커 영역을 벗어나도 표시
        children: [
          baseMarkerWidget,
          Positioned(
            left: 58, // 왼쪽 정렬 (뱃지 오른쪽부터 시작)
            bottom: 4.5, // 뱃지와 같은 높이
            child: Text(
              '${speedKmh}km/h',
              style: TextStyle(
                color: AppTokens.primaryTeal, // Teal 색상
                fontSize: AppTokens.fontSize11,
                fontWeight: AppTokens.fontWeightBold,
                shadows: [
                  // 가독성을 위한 흰색 그림자
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 3,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      markerWidget = baseMarkerWidget;
    }

    // 마커 크기 계산 (원본 크기의 1/3: 173×188 -> 약 57.67×62.67)
    // 캐시된 크기 사용 (이미지 로드 최소화)
    await _ensureMarkerSize();
    if (_cachedMarkerWidth == null || _cachedMarkerHeight == null) {
      return null;
    }
    final markerWidth = _cachedMarkerWidth!;
    final markerHeight = _cachedMarkerHeight!;

    // ⭐ 단순 Marker 생성 (애니메이션 없이 새 위치에 바로 업데이트)
    return Marker(
      key: ValueKey<String>(userId),
      point: position,
      width: markerWidth,
      height: markerHeight,
      alignment: const Alignment(0.0, -0.6),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            if (onMarkerTap != null) {
              onMarkerTap!(userId);
            }
          },
          child: _AnimatedUserMarker(
            userId: userId,
            userName: location.userName,
            markerWidget: markerWidget,
            isMoving: isMoving,
            targetPosition: position,
            getBounceAnimation: getBounceAnimation,
            getBounceJumpAnimation: getBounceJumpAnimation,
            getBreathingAnimation: getBreathingAnimation,
          ),
        ),
      ),
    );
  }

  /// 마커 변경 감지
  bool detectMarkerChanges(List<Marker> newMarkers) {
    // 기존 사용자 마커 추출 (지오펜스, 세션 마커 제외)
    final existingUserMarkers = _markers.where((marker) {
      final markerKey = marker.key is ValueKey<String>
          ? (marker.key as ValueKey<String>).value
          : null;
      if (markerKey == null) return false;
      return !markerKey.startsWith('geofence_') &&
          markerKey != 'session_start' &&
          markerKey != 'session_end';
    }).toList();

    // 마커 개수 확인
    if (existingUserMarkers.length != newMarkers.length) {
      return true;
    }

    // 마커 ID 확인
    final existingMarkerIds = existingUserMarkers
        .map(
          (m) => m.key is ValueKey<String>
              ? (m.key as ValueKey<String>).value
              : null,
        )
        .where((id) => id != null)
        .toSet();
    final newMarkerIds = newMarkers
        .map(
          (m) => m.key is ValueKey<String>
              ? (m.key as ValueKey<String>).value
              : null,
        )
        .where((id) => id != null)
        .toSet();

    if (!existingMarkerIds.containsAll(newMarkerIds) ||
        !newMarkerIds.containsAll(existingMarkerIds)) {
      return true;
    }

    // 위치 변경 확인
    for (final newMarker in newMarkers) {
      final newMarkerKey = newMarker.key is ValueKey<String>
          ? (newMarker.key as ValueKey<String>).value
          : null;
      if (newMarkerKey == null) continue;

      final existingMarker = existingUserMarkers.firstWhere((m) {
        final mKey = m.key is ValueKey<String>
            ? (m.key as ValueKey<String>).value
            : null;
        return mKey == newMarkerKey;
      }, orElse: () => newMarker);

      final latDiff = (existingMarker.point.latitude - newMarker.point.latitude)
          .abs();
      final lngDiff =
          (existingMarker.point.longitude - newMarker.point.longitude).abs();

      if (latDiff > _locationChangeThreshold ||
          lngDiff > _locationChangeThreshold) {
        return true;
      }
    }

    return false;
  }

  /// 사용자 마커 제거
  void removeUserMarkers({
    String? exceptUserId,
    bool includeSelectedUser = false,
    bool includeCurrentUser = false,
  }) {
    final currentUserId =
        getUsers().firstWhere(
              (u) => (u['user_id'] as String?) != null,
              orElse: () => {},
            )['user_id']
            as String?;

    _markers.removeWhere((marker) {
      final markerKey = marker.key is ValueKey<String>
          ? (marker.key as ValueKey<String>).value
          : null;
      if (markerKey == null) return false;
      // 지오펜스 마커는 항상 유지
      if (markerKey.startsWith('geofence_')) {
        return false;
      }
      // 세션 관련 마커는 항상 유지
      if (markerKey == 'session_start' || markerKey == 'session_end') {
        return false;
      }
      // 제외할 사용자 마커는 유지
      if (exceptUserId != null && markerKey == exceptUserId) {
        return false;
      }
      // 선택된 사용자 마커도 제거할지 여부
      if (includeSelectedUser && markerKey == getSelectedUserId()) {
        return true;
      }
      // 내 마커도 제거할지 여부
      if (includeCurrentUser &&
          currentUserId != null &&
          markerKey == currentUserId) {
        return true;
      }
      // 나머지 모든 사용자 마커는 제거
      return true;
    });
    onMarkersUpdated(List.from(_markers));
  }

  /// 사용자 마커 추가
  void addUserMarker(
    String userId,
    String userName,
    LatLng position,
    Widget icon,
  ) async {
    // 마커 크기 계산 (기본 크기의 1/3)
    final markerBg = await loadImageFromAssets('assets/images/Union_solo.png');
    if (markerBg == null) return;
    final markerWidth = markerBg.width.toDouble() / 3.0;
    final markerHeight = markerBg.height.toDouble() / 3.0;

    // 사용자 마커에 애니메이션 적용 (isMoving 상태에 따라)
    Widget animatedIcon = icon;
    final isMoving = getIsMoving?.call(userId) ?? false;

    if (isMoving) {
      // isMoving == true: 바운스 애니메이션
      final bounceAnimation = getBounceAnimation?.call();
      final jumpAnimation = getBounceJumpAnimation?.call();
      if (bounceAnimation != null || jumpAnimation != null) {
        Widget child = icon;
        if (bounceAnimation != null) {
          child = ScaleTransition(scale: bounceAnimation, child: child);
        }
        if (jumpAnimation != null) {
          child = AnimatedBuilder(
            animation: jumpAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, jumpAnimation.value),
                child: child,
              );
            },
            child: child,
          );
        }
        animatedIcon = child;
      }
    } else {
      // isMoving == false: 숨쉬는 애니메이션
      final breathingAnimation = getBreathingAnimation?.call();
      if (breathingAnimation != null) {
        animatedIcon = ScaleTransition(scale: breathingAnimation, child: icon);
      }
    }

    _markers.add(
      Marker(
        key: ValueKey<String>(userId),
        point: position,
        width: markerWidth,
        height: markerHeight,
        alignment: const Alignment(0.0, -0.6), // 이미지 하단 꼭지점을 포인트로
        child: animatedIcon,
      ),
    );
    onMarkersUpdated(List.from(_markers));
  }

  /// 마커 추가 (세션 마커 등)
  void addMarker(Marker marker) {
    _markers.add(marker);
    onMarkersUpdated(List.from(_markers));
  }

  /// 마커 제거
  void removeMarker(String markerId) {
    _markers.removeWhere((m) {
      final mKey = m.key is ValueKey<String>
          ? (m.key as ValueKey<String>).value
          : null;
      return mKey == markerId;
    });
    onMarkersUpdated(List.from(_markers));
  }

  /// 마커 제거 (조건부)
  void removeMarkersWhere(bool Function(Marker) test) {
    _markers.removeWhere(test);
    onMarkersUpdated(List.from(_markers));
  }

  /// 리소스 정리
  void dispose() {
    _zoomUpdateTimer?.cancel();
    _zoomUpdateTimer = null;
  }
}

/// AnimatedMarker의 builder를 별도 위젯으로 분리
/// 이렇게 하면 Flutter가 같은 위젯으로 인식하여 AnimatedMarker의 애니메이션이 작동함
class _AnimatedUserMarker extends StatelessWidget {
  const _AnimatedUserMarker({
    required this.userId,
    required this.userName,
    required this.markerWidget,
    required this.isMoving,
    required this.targetPosition,
    this.getBounceAnimation,
    this.getBounceJumpAnimation,
    this.getBreathingAnimation,
  });
  final String userId;
  final String userName;
  final Widget markerWidget;
  final bool isMoving;
  final LatLng targetPosition;
  final Animation<double>? Function()? getBounceAnimation;
  final Animation<double>? Function()? getBounceJumpAnimation;
  final Animation<double>? Function()? getBreathingAnimation;

  @override
  Widget build(BuildContext context) {
    // 이름 태그 위젯 생성
    final nameTagWidget = _buildNameTag(userName);

    // 마커와 이름 태그를 함께 Stack으로 구성
    final markerWithName = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 마커 위젯
        markerWidget,
        // 이름 태그 (마커 위에 배치, 5px 띄움)
        Positioned(
          bottom: null,
          top: -22, // 마커 높이의 절반(약 31px) + 5px 띄움 + 2px 추가
          child: nameTagWidget,
        ),
      ],
    );

    Widget animatedWidget = markerWithName;

    if (isMoving) {
      // 이동 중: 점프 애니메이션
      final jumpAnimation = getBounceJumpAnimation?.call();
      if (jumpAnimation != null) {
        animatedWidget = AnimatedBuilder(
          animation: jumpAnimation,
          builder: (context, _) => Transform.translate(
            offset: Offset(0, jumpAnimation.value),
            child: markerWithName,
          ),
        );
      }
    } else {
      // 정지 중: 숨쉬는 애니메이션
      final breathingAnimation = getBreathingAnimation?.call();
      if (breathingAnimation != null) {
        animatedWidget = ScaleTransition(
          scale: breathingAnimation,
          child: markerWithName,
        );
      }
    }

    return animatedWidget;
  }

  /// 이름 태그 위젯 생성
  Widget _buildNameTag(String name) {
    // Future를 한 번만 생성하고 재사용 (캐싱)
    _cachedNameTagImageFuture ??= _loadNameTagImage().then((image) {
      // 이미지 로드 완료 시 결과를 캐싱
      _cachedNameTagImage = image;
      return image;
    });

    return FutureBuilder<ui.Image?>(
      future: _cachedNameTagImageFuture,
      initialData: _cachedNameTagImage, // 캐시된 이미지가 있으면 즉시 사용
      builder: (context, snapshot) {
        // 로딩 중이거나 데이터가 없을 때 fallback UI 표시
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            snapshot.data == null) {
          // 이미지 로드 실패 또는 로딩 중일 때 텍스트만 표시
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF008080), // AppTokens.primaryTeal fallback
              ),
            ),
          );
        }

        final nameTagImage = snapshot.data!;
        // 마커와 동일하게 1/3 크기로 축소
        final imageWidth = nameTagImage.width.toDouble() / 3.0;
        final imageHeight = nameTagImage.height.toDouble() / 3.0;

        // 이미지 크기가 유효한지 확인
        if (imageWidth <= 0 || imageHeight <= 0) {
          // 이미지 크기가 유효하지 않으면 fallback UI 표시
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF008080),
              ),
            ),
          );
        }

        return SizedBox(
          width: imageWidth,
          height: imageHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 배경 이미지
              Image.asset(
                'assets/images/name_tag.png',
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.contain,
              ),
              // 이름 텍스트 (틸 색상, 크기도 비례적으로 축소)
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12, // 약 8px (12px의 2/3)
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF008080),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // 이름 태그 이미지 Future 캐시 (static 변수로 클래스 레벨에서 공유)
  static Future<ui.Image?>? _cachedNameTagImageFuture;
  // 이름 태그 이미지 결과 캐시 (재빌드 시 즉시 사용)
  static ui.Image? _cachedNameTagImage;

  /// 이름 태그 이미지 로드 (static 메서드로 변경)
  static Future<ui.Image?> _loadNameTagImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/name_tag.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      return frameInfo.image;
    } catch (e) {
      return null;
    }
  }
}
