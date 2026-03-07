import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../router/route_paths.dart';
import '../../features/main/providers/connectivity_provider.dart';
import '../../features/main/providers/main_screen_provider.dart';
import '../../features/trip/providers/trip_provider.dart';
import '../../managers/firebase_location_manager.dart';
import '../../managers/marker_manager.dart';
import '../../models/location.dart' as location_model;
import '../../router/auth_notifier.dart';
import '../../services/api_service.dart';
import '../../services/device_status_service.dart';
import '../../services/location_service.dart';
import '../../services/emergency_cache_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/sos_service.dart';
import '../../widgets/components/battery_warning_banner.dart';
import '../../widgets/components/offline_banner.dart';
import '../../widgets/components/privacy_banner.dart';
import '../../widgets/components/schedule_conflict_dialog.dart';
import '../../widgets/components/sos_button.dart';
import '../../widgets/components/sos_overlay.dart';
import '../../features/main/providers/battery_provider.dart';
import '../../features/main/providers/map_layer_provider.dart';
import '../../managers/map_camera_transition_manager.dart';
import '../../managers/schedule_marker_manager.dart';
import '../../managers/event_marker_manager.dart';
import '../../managers/geofence_map_renderer.dart';
import '../../managers/safety_facility_manager.dart';
import '../../widgets/map/member_mini_card.dart';
import 'bottom_sheets/modals/event_detail_modal.dart';
import 'bottom_sheets/modals/geofence_info_modal.dart';
import 'bottom_sheets/modals/schedule_detail_modal.dart';
import 'bottom_sheets/bottom_sheet_1_trip.dart';
import 'bottom_sheets/bottom_sheet_2_member.dart';
import 'bottom_sheets/bottom_sheet_3_chat.dart';
import '../../features/schedule/providers/schedule_provider.dart';
import '../../features/safety_guide/presentation/safety_guide_bottom_sheet.dart';
import 'bottom_sheets/bottom_sheet_layer_settings.dart';
import 'bottom_sheets/snapping_bottom_sheet.dart';
import 'navigation/bottom_navigation_bar.dart';
import '../../features/trip_card/widgets/trip_info_card_section.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key, required this.authNotifier});
  final AuthNotifier authNotifier;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  late final FirebaseLocationManager _firebaseLocationManager;
  late final MarkerManager _markerManager;
  SOSService? _sosService;

  /// 외부 제어용 DraggableScrollableController (§3 상태 전환 제어)
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  BottomTab _currentTab = BottomTab.trip;
  final ValueNotifier<List<Marker>> _userMarkersNotifier = ValueNotifier([]);

  late final MapCameraTransitionManager _cameraTransitionManager;
  late final ScheduleMarkerManager _scheduleMarkerManager;
  late final EventMarkerManager _eventMarkerManager;
  late final SafetyFacilityManager _safetyFacilityManager;
  late final GeofenceMapRenderer _geofenceMapRenderer;

  final ValueNotifier<List<Marker>> _scheduleMarkersNotifier = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Polyline>> _scheduleLinesNotifier = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Marker>> _eventMarkersNotifier = ValueNotifier([]);
  final ValueNotifier<List<Marker>> _safetyMarkersNotifier = ValueNotifier([]);
  final ValueNotifier<List<CircleMarker>> _geofenceCirclesNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<Marker>> _geofenceTapMarkersNotifier = ValueNotifier(
    [],
  );

  /// 멤버 미니카드 표시 상태 (§5.4)
  String? _selectedMarkerUserId;
  Map<String, dynamic>? _selectedMarkerUserData;

  bool _isInitialLoading = true;

  /// §3.1: 긴급 데이터 캐싱 완료 플래그 (세션 1회)
  bool _emergencyCached = false;

  /// 키보드 감지용 (§6)
  bool _isKeyboardVisible = false;

  /// SOS 발신자 이름 (§10.1 오버레이 표시용)
  String? _sosUserName;

  /// §4.2, §8.3: 동기화 완료 알림 구독
  late final StreamSubscription<SyncResult> _syncSubscription;

  /// §3.3: 프로그래밍적 시트 이동 시 점프 가드 우회 콜백
  void Function([Duration])? _markSheetProgrammatic;

  /// §3.3: 두 손가락 제스처 감지용
  int _pointerCount = 0;
  double? _twoFingerStartY;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // §9.3: 유예 기간 내 재로그인 시 삭제 취소 팝업
    _checkDeletionPending();

    // §4.2, §8.3: 동기화 완료 토스트 알림
    _syncSubscription = DeviceStatusService().syncResultStream.listen((result) {
      if (!mounted) return;
      if (result.synced > 0 && !result.hasFailures) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오프라인 중 ${result.synced}건의 데이터가 동기화되었습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result.hasFailures) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일부 데이터 동기화 실패. 재시도 중...'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // §6 충돌 감지: 동기화 후 충돌 드래프트 확인
      if (mounted) {
        ScheduleConflictDialog.showIfNeeded(context);
      }
    });

    _firebaseLocationManager = FirebaseLocationManager(
      onUsersUpdated: (users) {
        debugPrint('[MainScreen] Users updated: ${users.length}');
      },
      onUserLocationsUpdated: (locations) {
        _updateMarkers(locations);
      },
      onOriginalPositionsUpdated: (_) {},
      onSelectedUserLocationUpdated: (_, __) {},
      onPathUpdateDataReady: (_) {},
      onMarkerUpdateRequested: () {},
      onUserMarkerUpdateRequested: (_) {},
      onLocationTextRequested: (_, __, ___) {},
      isMounted: () => mounted,
      calculateDistance: (p1, p2) =>
          const Distance().as(LengthUnit.Meter, p1, p2),
    );

    _markerManager = MarkerManager(
      onMarkersUpdated: (markers) {
        _userMarkersNotifier.value = markers;
      },
      onUserSelected: (userId, userName, {targetPosition}) {
        debugPrint('[MainScreen] User selected: $userId');
      },
      onClusterMarkerTapped: (positions) {
        debugPrint('[MainScreen] Cluster tapped: ${positions.length} markers');
      },
      onZoomLevelChanged: (zoom) {
        debugPrint('[MainScreen] Zoom changed: $zoom');
      },
      onMarkerUpdateRequested: () {
        _updateMarkers(_firebaseLocationManager.userLocations);
      },
      isMounted: () => mounted,
      getMapController: () => _mapController,
      getUsers: () => _firebaseLocationManager.users,
      getUserLocations: () => _firebaseLocationManager.userLocations,
      getSelectedUserId: () => null,
      calculateDistance: (p1, p2) =>
          const Distance().as(LengthUnit.Meter, p1, p2),
      onMarkerTap: (userId) {
        final users = _firebaseLocationManager.users;
        final user = users.firstWhere(
          (u) => (u['user_id'] as String?) == userId,
          orElse: () => <String, dynamic>{},
        );
        if (user.isNotEmpty) {
          setState(() {
            _selectedMarkerUserId = userId;
            _selectedMarkerUserData = user;
          });
        }
      },
    );

    _cameraTransitionManager = MapCameraTransitionManager(
      getMapController: () => _mapController,
    );

    _scheduleMarkerManager = ScheduleMarkerManager(
      onMarkersUpdated: (markers) => _scheduleMarkersNotifier.value = markers,
      onPolylinesUpdated: (lines) => _scheduleLinesNotifier.value = lines,
      onScheduleMarkerTap: (id) {
        final scheduleState = ref.read(scheduleProvider);
        final schedule = scheduleState.schedules
            .where((s) => s.scheduleId == id)
            .firstOrNull;
        if (schedule != null && mounted) {
          final userRole = ref.read(tripProvider).currentUserRole;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ScheduleDetailModal(
              schedule: schedule,
              userRole: userRole,
              onScheduleUpdated: () {
                ref.read(scheduleProvider.notifier).fetchSchedules();
              },
            ),
          );
        }
      },
    );

    _eventMarkerManager = EventMarkerManager(
      onMarkersUpdated: (markers) => _eventMarkersNotifier.value = markers,
      onEventMarkerTap: (eventId) {
        final data = _eventMarkerManager.getEventData(eventId);
        if (data != null && mounted) {
          showModalBottomSheet(
            context: context,
            builder: (_) => EventDetailModal(
              eventType: data['eventType'] as String,
              memberName: data['memberName'] as String,
              description:
                  '${data['memberName']} ${data['geofenceName'] ?? '지오펜스'} 이탈',
              timestamp: data['timestamp'] as DateTime,
              latitude: (data['position'] as LatLng?)?.latitude,
              longitude: (data['position'] as LatLng?)?.longitude,
              geofenceName: data['geofenceName'] as String?,
            ),
          );
        }
      },
    );

    _safetyFacilityManager = SafetyFacilityManager(
      onMarkersUpdated: (markers) => _safetyMarkersNotifier.value = markers,
    );

    _geofenceMapRenderer = GeofenceMapRenderer(
      onGeofencesUpdated: (circles) => _geofenceCirclesNotifier.value = circles,
      onMarkersUpdated: (markers) =>
          _geofenceTapMarkersNotifier.value = markers,
      isMounted: () => mounted,
      onGeofenceTap: (geofence) async {
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        final userRole = prefs.getString('user_role') ?? 'crew';
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          builder: (_) =>
              GeofenceInfoModal(geofence: geofence, userRole: userRole),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDemoMode = prefs.getBool('is_demo_mode') ?? false;
      final userId = prefs.getString('user_id');
      final groupId = prefs.getString('group_id');
      final userRole = prefs.getString('user_role') ?? 'crew';

      // Demo mode: skip Firebase/location services, use pre-seeded tripProvider
      if (isDemoMode) {
        if (mounted) {
          final notifier = ref.read(mainScreenProvider.notifier);
          notifier.setSheetLevel(BottomSheetLevel.half);
          notifier.setNoTrip(false);
          _animateSheetTo(BottomSheetLevel.half);
          setState(() => _isInitialLoading = false);
        }
        return;
      }

      if (userId != null && groupId != null) {
        await _locationService.initialize(userId: userId);
        if (userRole != 'guardian') {
          await _locationService.startTracking();
        }

        await _firebaseLocationManager.subscribeStreams();

        _sosService = SOSService(
          locationService: _locationService,
          apiService: ApiService(),
          tripId: groupId,
        );

        // §7.3: SOS 앱 재시작 시 활성 SOS 상태 복원
        _checkAndRestoreSos();
      }

      // 가디언이면 가디언 전용 화면으로 리다이렉트
      if (userRole == 'guardian' && mounted) {
        context.go('/main/guardian');
        return;
      }

      if (mounted) {
        // 여행 상태별 초기 높이 적용 (§5.2)
        final tripStatus = ref.read(tripProvider).currentTripStatus;
        final initialLevel = initialHeightForTripStatus(tripStatus);
        final notifier = ref.read(mainScreenProvider.notifier);
        notifier.setSheetLevel(initialLevel);

        // §8.2: 여행 없음 상태 설정
        notifier.setNoTrip(tripStatus == 'none');

        _animateSheetTo(initialLevel);

        setState(() => _isInitialLoading = false);

        // §3.1: 여행 활성 + 온라인 시 긴급 데이터 캐싱 (세션 1회, fire-and-forget)
        if (!_emergencyCached && tripStatus == 'active' && groupId != null) {
          final networkStatus = ref.read(networkStateProvider);
          if (networkStatus.isOnline) {
            _emergencyCached = true;
            final countryCode = ref.read(tripProvider).countryCode ?? 'KR';
            final emergencyCache = EmergencyCacheService(
              apiService: ApiService(),
              offlineSyncService: OfflineSyncService(),
            );
            emergencyCache.cacheForTrip(groupId, countryCode);
          }
        }
      }
    } catch (e) {
      debugPrint('[MainScreen] Initialization failed: $e');
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  void _updateMarkers(Map<String, location_model.Location> locations) async {
    final markers = await _markerManager.buildUserMarkers();
    _userMarkersNotifier.value = markers;

    if (markers.isNotEmpty && _isInitialLoading) {
      _mapController.move(markers.first.point, 15.0);
    }
  }

  /// 키보드 출현/닫힘 감지 (§6)
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // ignore_for_file: use_build_context_synchronously
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      final keyboardNow = bottomInset > 0;

      if (keyboardNow && !_isKeyboardVisible) {
        // 키보드 출현 (§6.1)
        _isKeyboardVisible = true;
        final notifier = ref.read(mainScreenProvider.notifier);
        final target = notifier.onKeyboardShow();
        _animateSheetTo(target, curve: Curves.easeInOut);
      } else if (!keyboardNow && _isKeyboardVisible) {
        // 키보드 닫힘 (§6.1)
        _isKeyboardVisible = false;
        final notifier = ref.read(mainScreenProvider.notifier);
        final target = notifier.onKeyboardHide();
        _animateSheetTo(target, duration: const Duration(milliseconds: 250));
      }
    });
  }

  /// §9.3: 유예 기간 내 재로그인 → 삭제 취소 팝업
  Future<void> _checkDeletionPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final profile = await ApiService().getUserById(userId);
      if (profile == null) return;

      final deletionAt = profile['deletion_requested_at'];
      if (deletionAt == null) return;

      if (!mounted) return;
      final shouldCancel = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('계정 삭제 예약됨'),
          content: const Text('계정 삭제가 요청된 상태입니다.\n삭제를 취소하고 계정을 유지하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('삭제 유지'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제 취소'),
            ),
          ],
        ),
      );

      if (shouldCancel == true) {
        final success = await ApiService().cancelAccountDeletion();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '계정 삭제가 취소되었습니다.' : '삭제 취소에 실패했습니다.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[MainScreen] _checkDeletionPending Error: $e');
    }
  }

  @override
  void dispose() {
    _syncSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _firebaseLocationManager.dispose();
    _userMarkersNotifier.dispose();
    _cameraTransitionManager.dispose();
    _scheduleMarkerManager.dispose();
    _eventMarkerManager.dispose();
    _safetyFacilityManager.dispose();
    _geofenceMapRenderer.dispose();
    _scheduleMarkersNotifier.dispose();
    _scheduleLinesNotifier.dispose();
    _eventMarkersNotifier.dispose();
    _safetyMarkersNotifier.dispose();
    _geofenceCirclesNotifier.dispose();
    _geofenceTapMarkersNotifier.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  /// 시트를 특정 레벨로 애니메이션 이동
  void _animateSheetTo(
    BottomSheetLevel level, {
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
  }) {
    if (!_sheetController.isAttached) return;
    _markSheetProgrammatic?.call(duration); // §3.3: 점프 가드 우회
    _sheetController.animateTo(
      level.fraction,
      duration: duration,
      curve: curve,
    );
  }

  /// §3.3: 포인터 다운 — 동시 터치 수 추적
  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount == 2) {
      _twoFingerStartY = event.position.dy;
    }
  }

  /// §3.3: 포인터 업 — 두 손가락 위 스와이프 판정
  void _onPointerUp(PointerUpEvent event) {
    if (_pointerCount == 2 && _twoFingerStartY != null) {
      final deltaY = event.position.dy - _twoFingerStartY!;
      final mainState = ref.read(mainScreenProvider);

      // 위로 스와이프 (deltaY < -100) + collapsed 상태 → full로 직접 전환
      if (deltaY < -100 &&
          mainState.sheetLevel == BottomSheetLevel.collapsed &&
          !mainState.isSosActive &&
          !mainState.isNoTrip) {
        final notifier = ref.read(mainScreenProvider.notifier);
        notifier.setSheetLevel(BottomSheetLevel.full);
        _animateSheetTo(
          BottomSheetLevel.full,
          duration: const Duration(milliseconds: 300),
        );
      }
    }
    _pointerCount--;
    if (_pointerCount <= 0) {
      _pointerCount = 0;
      _twoFingerStartY = null;
    }
  }

  /// 탭 전환 처리 (§4.4, §5.1, §7.2)
  void _handleTabChanged(BottomTab tab) {
    final mainState = ref.read(mainScreenProvider);
    final notifier = ref.read(mainScreenProvider.notifier);

    // SOS 활성 시 탭 전환 비활성화 (§10.2)
    if (mainState.isSosActive) return;

    // 여행 없음 상태에서 탭 전환 비활성화 (§8.2)
    final tripStatus = ref.read(tripProvider).currentTripStatus;
    if (tripStatus == 'none') return;

    if (tab == _currentTab) {
      // 동일 탭 재탭 (§4.4)
      final previousLevel = mainState.sheetLevel;
      final targetLevel = notifier.resolveHeightForSameTabTap();
      notifier.setSheetLevel(targetLevel);

      // §3.1: collapsed → half 전환은 250ms easeInOut
      final duration =
          (previousLevel == BottomSheetLevel.collapsed &&
              targetLevel == BottomSheetLevel.half)
          ? const Duration(milliseconds: 250)
          : const Duration(milliseconds: 200);
      _animateSheetTo(targetLevel, duration: duration);
    } else {
      // 다른 탭 전환 (§7.2)
      final targetLevel = notifier.resolveHeightForTab(tab);
      notifier.setCurrentTab(tab);
      notifier.setSheetLevel(targetLevel);
      setState(() => _currentTab = tab);
      _animateSheetTo(targetLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);
    final networkStatus = ref.watch(networkStateProvider);
    final mainState = ref.watch(mainScreenProvider);
    final layerState = ref.watch(mapLayerProvider);

    final tripStatus = tripState.currentTripStatus;
    final isCompleted = tripStatus == 'completed';
    final isActive = tripStatus == 'active';
    final privacyLevel = tripState.currentTrip?.privacyLevel ?? 'standard';

    // SOS는 active 상태 + 비가디언일 때만 표시
    final showSos = isActive && tripState.currentUserRole != 'guardian';
    final isNoTrip = tripStatus == 'none';
    // 안드로이드 시스템 네비게이션 바 높이 (소프트키/제스처 영역)
    final systemBottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // §7.3: 배터리 레벨 (위치 업데이트에서 수신)
    final batteryAsync = ref.watch(batteryLevelProvider);
    final batteryLevel = batteryAsync.valueOrNull;
    final showBatteryWarning = batteryLevel != null && batteryLevel < 20;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final sheetLevel = mainState.sheetLevel;
        if (sheetLevel == BottomSheetLevel.full ||
            sheetLevel == BottomSheetLevel.expanded) {
          // full/expanded → half로 축소
          ref
              .read(mainScreenProvider.notifier)
              .setSheetLevel(BottomSheetLevel.half);
          _animateSheetTo(BottomSheetLevel.half);
        } else {
          // half 이하 → 앱 종료 다이얼로그
          _showExitDialog();
        }
      },
      child: Scaffold(
        body: Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          child: Stack(
            children: [
              // ── Layer 1: Base Map ──────────────────────────────
              ValueListenableBuilder<List<Marker>>(
                valueListenable: _userMarkersNotifier,
                builder: (context, userMarkers, _) {
                  return FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(37.5665, 126.9780),
                      initialZoom: 13.0,
                      onTap: (_, __) {
                        // §5.4: 빈 영역 탭 → 미니카드 닫기
                        setState(() {
                          _selectedMarkerUserId = null;
                          _selectedMarkerUserData = null;
                        });
                      },
                    ),
                    children: [
                      // Layer 0: 지도 타일
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.urock.safe.trip',
                        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                      ),
                      // Layer 1: 안전시설 마커
                      if (layerState.layer1SafetyFacilities)
                        ValueListenableBuilder<List<Marker>>(
                          valueListenable: _safetyMarkersNotifier,
                          builder: (_, markers, __) =>
                              MarkerLayer(markers: markers),
                        ),
                      // Layer 2: 멤버 위치 마커
                      if (layerState.layer2MemberMarkers)
                        MarkerLayer(markers: userMarkers),
                      // Layer 3: 일정 폴리라인
                      if (layerState.layer3SchedulePlaces)
                        ValueListenableBuilder<List<Polyline>>(
                          valueListenable: _scheduleLinesNotifier,
                          builder: (_, lines, __) =>
                              PolylineLayer(polylines: lines),
                        ),
                      // Layer 3: 일정 장소 마커
                      if (layerState.layer3SchedulePlaces)
                        ValueListenableBuilder<List<Marker>>(
                          valueListenable: _scheduleMarkersNotifier,
                          builder: (_, markers, __) =>
                              MarkerLayer(markers: markers),
                        ),
                      // Layer 4: 지오펜스 영역 (CircleLayer)
                      if (layerState.layer4EventAlerts)
                        ValueListenableBuilder<List<CircleMarker>>(
                          valueListenable: _geofenceCirclesNotifier,
                          builder: (_, circles, __) =>
                              CircleLayer(circles: circles),
                        ),
                      // Layer 4: 지오펜스 탭 감지 마커
                      if (layerState.layer4EventAlerts)
                        ValueListenableBuilder<List<Marker>>(
                          valueListenable: _geofenceTapMarkersNotifier,
                          builder: (_, markers, __) =>
                              MarkerLayer(markers: markers),
                        ),
                      // Layer 4: 이벤트/알림 마커
                      if (layerState.layer4EventAlerts)
                        ValueListenableBuilder<List<Marker>>(
                          valueListenable: _eventMarkersNotifier,
                          builder: (_, markers, __) =>
                              MarkerLayer(markers: markers),
                        ),
                    ],
                  );
                },
              ),

              if (_isInitialLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),

              // ── Layer 2: Top Bar ──────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: const TripInfoCardSection(),
              ),

              // ── Layer Settings Button (우측 상단) ─────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                right: AppSpacing.md,
                child: FloatingActionButton.small(
                  heroTag: 'layer_settings',
                  onPressed: () => showLayerSettingsSheet(context),
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.layers,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              // ── Layer 3: Snapping Bottom Sheet ────────────────
              SnappingBottomSheet(
                controller: _sheetController,
                initialLevel: BottomSheetLevel.half,
                isDragEnabled:
                    !mainState.isSosActive &&
                    !isNoTrip, // SOS/NoTrip 잠금 (§10.2, §8.2)
                onCreated: (markFn) => _markSheetProgrammatic = markFn,
                onLevelChanged: (level) {
                  final applied = ref
                      .read(mainScreenProvider.notifier)
                      .setSheetLevel(level);
                  // SOS 잠금 시 collapsed로 되돌리기
                  if (applied != level) {
                    _animateSheetTo(
                      applied,
                      duration: const Duration(milliseconds: 150),
                    );
                  }
                },
                builder: (context, scrollController) {
                  // §8.2: 여행 없음 → CTA만 표시
                  if (isNoTrip) {
                    return _buildNoTripContent();
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _buildTabContent(scrollController),
                  );
                },
              ),

              // ── Layer 4: Bottom Navigation ────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNavigationBar(
                  currentTab: _currentTab,
                  onTabChanged: _handleTabChanged,
                  isGuardian: false,
                  isDisabled:
                      mainState.isSosActive ||
                      isNoTrip, // SOS/NoTrip 시 탭 전환 비활성화 (§10.2, §8.2)
                ),
              ),

              // ── Layer 5: SOS Button (독립 Positioned) ─────────
              // SOS 버튼은 active 상태에서 항상 표시 (§2.2)
              // SOS 활성 시 해제 버튼으로 전환 (§10.2)
              if (showSos)
                Positioned(
                  right: 16,
                  bottom:
                      AppSpacing.navigationBarHeight + 28 + systemBottomPadding,
                  child: Semantics(
                    label: mainState.isSosActive
                        ? 'SOS 해제 버튼'
                        : '긴급 SOS 발송 버튼, 3초간 누르세요',
                    child: SosButton(
                      onSosActivated: _handleSOS,
                      onSosDeactivated: _handleSOSRelease,
                      isSosActive: mainState.isSosActive,
                    ),
                  ),
                ),

              // ── Layer 6: SOS Overlay (§10.1 — 전체 화면 최상단) ──
              if (mainState.isSosActive)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SosOverlay(userName: _sosUserName ?? ''),
                ),

              // ── Member Mini Card (§5.4) ───────────────────
              if (_selectedMarkerUserId != null &&
                  _selectedMarkerUserData != null)
                Positioned(
                  bottom:
                      AppSpacing.navigationBarHeight + 80 + systemBottomPadding,
                  left: AppSpacing.md,
                  right: AppSpacing.md + 72,
                  child: MemberMiniCard(
                    userName:
                        _selectedMarkerUserData!['user_name'] as String? ?? '',
                    role: _selectedMarkerUserData!['role'] as String? ?? 'crew',
                    batteryLevel: _selectedMarkerUserData!['battery'] as int?,
                    onClose: () => setState(() {
                      _selectedMarkerUserId = null;
                      _selectedMarkerUserData = null;
                    }),
                  ),
                ),

              // ── Layer 7: Offline / Degraded Banner (§8.1) ─────
              if (!networkStatus.isOnline)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: OfflineBanner(status: networkStatus),
                ),

              // ── Layer 7b: Battery Warning Banner (§7.3) ──────
              if (showBatteryWarning)
                Positioned(
                  top:
                      MediaQuery.of(context).padding.top +
                      (!networkStatus.isOnline ? 32 : 0),
                  left: 0,
                  right: 0,
                  child: BatteryWarningBanner(batteryLevel: batteryLevel),
                ),

              // ── Privacy Banner (active 상태에서만) ────────────
              if (isActive)
                Positioned(
                  top:
                      MediaQuery.of(context).padding.top +
                      (!networkStatus.isOnline ? 32 : 0) +
                      (showBatteryWarning ? 32 : 0),
                  left: 0,
                  right: 0,
                  child: PrivacyBanner(privacyLevel: privacyLevel),
                ),

              // ── Completed 상태 읽기 전용 뱃지 ─────────────────
              if (isCompleted)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tripCompleted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radius8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.tripCompleted,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '종료된 여행 — 읽기 전용 모드',
                          style: TextStyle(
                            color: AppColors.tripCompleted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 탭 전환 시 바텀시트 콘텐츠 빌드
  Widget _buildTabContent(ScrollController scrollController) {
    switch (_currentTab) {
      case BottomTab.trip:
        return BottomSheetTrip(
          key: const ValueKey('tab_trip'),
          scrollController: scrollController,
        );
      case BottomTab.member:
        return BottomSheetMember(
          key: const ValueKey('tab_member'),
          scrollController: scrollController,
          onEnterDetail: () {
            // §7.4: 세부 화면 진입 → full
            final target = ref
                .read(mainScreenProvider.notifier)
                .enterDetailView();
            _animateSheetTo(
              target,
              duration: const Duration(milliseconds: 250),
            );
          },
          onExitDetail: () {
            // §7.4: 세부 화면 종료 → 이전 레벨 복원
            final target = ref
                .read(mainScreenProvider.notifier)
                .exitDetailView();
            _animateSheetTo(
              target,
              duration: const Duration(milliseconds: 250),
            );
          },
        );
      case BottomTab.chat:
        return BottomSheetChat(
          key: const ValueKey('tab_chat'),
          scrollController: scrollController,
        );
      case BottomTab.guide:
        return SafetyGuideBottomSheet(
          key: const ValueKey('tab_guide'),
          scrollController: scrollController,
        );
    }
  }

  /// §8.2: 여행 없는 상태에서 표시할 CTA
  Widget _buildNoTripContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.luggage_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '아직 여행이 없습니다',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.tripCreate),
              icon: const Icon(Icons.add),
              label: const Text('새 여행 만들기'),
            ),
          ],
        ),
      ),
    );
  }

  /// SOS 발동 (§10.1)
  Future<void> _handleSOS() async {
    final notifier = ref.read(mainScreenProvider.notifier);

    // §10.1: 바텀시트 → collapsed 강제 전환 + 잠금
    notifier.activateSos();
    _animateSheetTo(
      BottomSheetLevel.collapsed,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userName = prefs.getString('user_name') ?? '';

    // §10.1: SOS 오버레이에 표시할 발신자 이름 저장
    setState(() => _sosUserName = userName);

    // §4 P0: 카메라 자동 전환 매니저로 SOS 발동 처리
    _locationService.getCurrentPosition().then((location) {
      if (location != null && mounted) {
        _cameraTransitionManager.onSosActivated(
          LatLng(location.coords.latitude, location.coords.longitude),
        );
      }
    });

    if (_sosService != null && userId != null) {
      final success = await _sosService!.sendSOS(
        userId: userId,
        userName: userName,
        message: '긴급 상황 발생!',
      );

      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS 전송에 실패했습니다. 재시도해주세요.'),
            backgroundColor: AppColors.sosDanger,
          ),
        );
      }
    }
  }

  /// §7.3: 앱 재시작 시 활성 SOS 상태 복원
  Future<void> _checkAndRestoreSos() async {
    if (_sosService == null) return;
    try {
      final activeSos = await _sosService!.checkActiveSos();
      if (activeSos != null && mounted) {
        final userName = activeSos['user_name'] as String? ?? 'SOS';
        setState(() => _sosUserName = userName);
        ref.read(mainScreenProvider.notifier).activateSos();
        _animateSheetTo(BottomSheetLevel.collapsed);
        debugPrint('[SOS] 활성 SOS 상태 복원: $userName');
      }
    } catch (e) {
      debugPrint('[SOS] 활성 SOS 복원 실패: $e');
    }
  }

  /// SOS 해제 (§10.3) — 해제 버튼 탭 시 호출
  void _handleSOSRelease() {
    final notifier = ref.read(mainScreenProvider.notifier);

    // §10.3: 잠금 해제 + peek 복원
    notifier.deactivateSos();
    _cameraTransitionManager.onSosDeactivated();
    _animateSheetTo(
      BottomSheetLevel.peek,
      duration: const Duration(milliseconds: 250),
      curve: Curves.elasticOut,
    );

    setState(() => _sosUserName = null);
  }

  Future<void> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱 종료'),
        content: const Text('SafeTrip을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      SystemNavigator.pop();
    }
  }
}
