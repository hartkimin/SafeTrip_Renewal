import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';
import '../../services/location_service.dart';
import '../../services/sos_service.dart';
import '../../services/api_service.dart';
import '../../managers/firebase_location_manager.dart';
import '../../managers/marker_manager.dart';
import '../../models/location.dart' as location_model;
import 'navigation/bottom_navigation_bar.dart';
import 'bottom_sheets/bottom_sheet_1_trip.dart';
import 'bottom_sheets/bottom_sheet_2_member.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key, required this.authNotifier});
  final AuthNotifier authNotifier;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  late final FirebaseLocationManager _firebaseLocationManager;
  late final MarkerManager _markerManager;
  SOSService? _sosService;

  BottomTab _currentTab = BottomTab.trip;
  final ValueNotifier<List<Marker>> _userMarkersNotifier = ValueNotifier([]);

  bool _isInitialLoading = true;
  String _currentTripName = '여행 정보를 불러오는 중...';
  double _panelHeight = 0.4;

  @override
  void initState() {
    super.initState();

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
        debugPrint('[MainScreen] Marker tapped: $userId');
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final groupId = prefs.getString('group_id');

      if (userId != null && groupId != null) {
        await _locationService.initialize(userId: userId);
        if (prefs.getString('user_role') != 'guardian') {
          await _locationService.startTracking();
        }

        await _firebaseLocationManager.subscribeStreams();

        _sosService = SOSService(
          locationService: _locationService,
          apiService: ApiService(),
          tripId: groupId,
        );
      }

      // 여행 정보 로드 (간소화)
      setState(() {
        _currentTripName = '도쿄 가족 여행';
        _isInitialLoading = false;
      });
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

    // 첫 로드 시 마커 위치로 카메라 이동
    if (markers.isNotEmpty && _isInitialLoading) {
      _mapController.move(markers.first.point, 15.0);
    }
  }

  @override
  void dispose() {
    _firebaseLocationManager.dispose();
    _userMarkersNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Base Map Layer
          ValueListenableBuilder<List<Marker>>(
            valueListenable: _userMarkersNotifier,
            builder: (context, markers, _) {
              return FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(37.5665, 126.9780),
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.urock.safe.trip',
                  ),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          if (_isInitialLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Top Bar Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: _buildTopBar(),
          ),

          // Bottom Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.navigationBarHeight + 20,
            child: SizedBox(
              height: screenHeight * _panelHeight,
              child: _buildBottomSheet(),
            ),
          ),

          // Bottom Navigation Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNavigationBar(
              currentTab: _currentTab,
              onTabChanged: (tab) {
                setState(() => _currentTab = tab);
              },
              onSOSPressed: () {
                _handleSOS();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    switch (_currentTab) {
      case BottomTab.trip:
        return BottomSheetTrip(
          initialHeight: _panelHeight,
          onHeightChanged: (h) => setState(() => _panelHeight = h),
        );
      case BottomTab.member:
        return BottomSheetMember(
          initialHeight: _panelHeight,
          onHeightChanged: (h) => setState(() => _panelHeight = h),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Icon(Icons.flight_takeoff, color: AppColors.primaryTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '여행 진행 중',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  _currentTripName,
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF7C4DFF)),
            onPressed: () => context.push(RoutePaths.aiBriefing),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(RoutePaths.settingsMain),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSOS() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userName = prefs.getString('user_name');

    if (_sosService != null && userId != null && userName != null) {
      final success = await _sosService!.sendSOS(
        userId: userId,
        userName: userName,
        message: '긴급 상황 발생!',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'SOS 알림을 보냈습니다.' : 'SOS 전송 실패'),
            backgroundColor: success
                ? AppColors.primaryTeal
                : AppColors.sosDanger,
          ),
        );
      }
    }
  }
}
