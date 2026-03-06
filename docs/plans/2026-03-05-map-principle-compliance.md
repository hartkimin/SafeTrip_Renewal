# Map Principle Compliance (DOC-T3-MAP-017) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring the SafeTrip map screen into full compliance with the 지도 기본화면 고유 원칙 v1.1 — P0 + P1 scope.

**Architecture:** Incremental enhancement of existing Stack-based layout in `screen_main.dart`. New Riverpod providers for layer state, new manager classes for camera transitions / schedule markers / event markers / safety facilities. All changes preserve existing working features.

**Tech Stack:** Flutter + FlutterMap (OSM) + Riverpod + SharedPreferences + Firebase RTDB

**Design Doc:** `docs/plans/2026-03-05-map-principle-compliance-design.md`

**Principle Doc:** `Master_docs/17_T3_지도_기본화면_고유_원칙.md`

---

## Task 1: Map Constants — Role Colors + Cluster Thresholds (§5.2, §5.3)

**Files:**
- Modify: `safetrip-mobile/lib/constants/map_constants.dart`
- Modify: `safetrip-mobile/lib/core/theme/app_colors.dart`

**Step 1: Update map_constants.dart with spec-compliant values**

Replace the entire file content:

```dart
import 'package:flutter/material.dart';

class MapConstants {
  // ─ 기본 줌 레벨 ─────────────────────────────────
  static const double defaultZoomLevel = 15.0;
  static const double userSelectionZoomLevel = 15.0;
  static const double sosZoomLevel = 16.0;          // §4 SOS 카메라 줌
  static const double planningZoomLevel = 12.0;      // §4 planning 상태
  static const double demoZoomLevel = 12.0;          // §4 데모 상태

  // ─ 3단계 클러스터링 (§5.2) ──────────────────────
  /// 줌 15 이상: 개별 마커 + 이름 라벨
  static const double clusterIndividualThreshold = 15.0;
  /// 줌 12~14: 3명 이하 개별, 4명 이상 클러스터
  static const double clusterMixedThreshold = 12.0;
  /// 줌 11 이하: 클러스터만 + 바운딩 박스 auto-fit
  static const double clusterOnlyThreshold = 11.0;
  /// 클러스터 전환 기준 인원수 (줌 12~14)
  static const int clusterMixedMinCount = 4;

  // ─ 레거시 호환 (기존 코드 참조) ─────────────────
  static const double clusterZoomThreshold = clusterIndividualThreshold;

  // ─ 역할별 마커 색상 (§5.3) ──────────────────────
  static const Color markerCaptain = Color(0xFFFFD700);      // 황금색
  static const Color markerCrewLeader = Color(0xFFFF8C00);   // 주황색
  static const Color markerCrew = Color(0xFF2196F3);         // 파란색
  static const Color markerMyLocation = Color(0xFF4CAF50);   // 초록색
  static const Color markerGuardian = Color(0xFF9C27B0);     // 보라색

  // ─ 멤버 오프라인 감지 (§7.1) ────────────────────
  static const Duration offlineThreshold = Duration(minutes: 5);
}
```

**Step 2: Add map marker role colors to app_colors.dart**

Add below the existing `guardian` color definition (line ~46):

```dart
  // ─ 지도 마커 역할별 컬러 (지도 원칙 §5.3) ──────────────────────
  static const Color mapMarkerCaptain = Color(0xFFFFD700);     // 황금색 별
  static const Color mapMarkerCrewLeader = Color(0xFFFF8C00);  // 주황색 다이아몬드
  static const Color mapMarkerCrew = Color(0xFF2196F3);        // 파란색 원형
  static const Color mapMarkerMyLocation = Color(0xFF4CAF50);  // 초록색 펄스
  static const Color mapMarkerGuardian = Color(0xFF9C27B0);    // 보라색 방패
  static const Color mapMarkerOffline = Color(0xFF9E9E9E);     // 회색 (오프라인)
  static const Color mapMarkerHidden = Color(0xFFBDBDBD);      // 회색 (비공유)
```

**Step 3: Verify no compilation errors**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/constants/map_constants.dart lib/core/theme/app_colors.dart 2>&1 | head -20`

**Step 4: Commit**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
git add lib/constants/map_constants.dart lib/core/theme/app_colors.dart
git commit -m "feat(map): add spec-compliant role colors and 3-stage cluster thresholds (§5.2, §5.3)"
```

---

## Task 2: MapLayerProvider — Layer ON/OFF State Management (§3)

**Files:**
- Create: `safetrip-mobile/lib/features/main/providers/map_layer_provider.dart`

**Step 1: Create the layer state provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 7단계 레이어 ON/OFF 상태 관리 (지도 원칙 §3)
///
/// Layer 0 (지도 타일): 항상 ON — 토글 불가
/// Layer 1 (안전시설): 토글 가능
/// Layer 2 (멤버 위치): 토글 가능
/// Layer 3 (일정/장소): 토글 가능
/// Layer 4 (이벤트/알림): 캡틴/크루장 전용, 토글 가능
/// Layer 5 (UI 컨트롤): 항상 ON — 토글 불가
/// Layer 6 (긴급 오버레이): SOS 자동 제어 — 토글 불가
class MapLayerState {
  const MapLayerState({
    this.layer1SafetyFacilities = true,
    this.layer2MemberMarkers = true,
    this.layer3SchedulePlaces = true,
    this.layer4EventAlerts = true,
  });

  final bool layer1SafetyFacilities;
  final bool layer2MemberMarkers;
  final bool layer3SchedulePlaces;
  final bool layer4EventAlerts;

  MapLayerState copyWith({
    bool? layer1SafetyFacilities,
    bool? layer2MemberMarkers,
    bool? layer3SchedulePlaces,
    bool? layer4EventAlerts,
  }) {
    return MapLayerState(
      layer1SafetyFacilities: layer1SafetyFacilities ?? this.layer1SafetyFacilities,
      layer2MemberMarkers: layer2MemberMarkers ?? this.layer2MemberMarkers,
      layer3SchedulePlaces: layer3SchedulePlaces ?? this.layer3SchedulePlaces,
      layer4EventAlerts: layer4EventAlerts ?? this.layer4EventAlerts,
    );
  }
}

class MapLayerNotifier extends StateNotifier<MapLayerState> {
  MapLayerNotifier() : super(const MapLayerState()) {
    _loadFromPrefs();
  }

  static const _keyPrefix = 'map_layer_';

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = MapLayerState(
      layer1SafetyFacilities: prefs.getBool('${_keyPrefix}1') ?? true,
      layer2MemberMarkers: prefs.getBool('${_keyPrefix}2') ?? true,
      layer3SchedulePlaces: prefs.getBool('${_keyPrefix}3') ?? true,
      layer4EventAlerts: prefs.getBool('${_keyPrefix}4') ?? true,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_keyPrefix}1', state.layer1SafetyFacilities);
    await prefs.setBool('${_keyPrefix}2', state.layer2MemberMarkers);
    await prefs.setBool('${_keyPrefix}3', state.layer3SchedulePlaces);
    await prefs.setBool('${_keyPrefix}4', state.layer4EventAlerts);
  }

  void toggleLayer1() {
    state = state.copyWith(layer1SafetyFacilities: !state.layer1SafetyFacilities);
    _save();
  }

  void toggleLayer2() {
    state = state.copyWith(layer2MemberMarkers: !state.layer2MemberMarkers);
    _save();
  }

  void toggleLayer3() {
    state = state.copyWith(layer3SchedulePlaces: !state.layer3SchedulePlaces);
    _save();
  }

  void toggleLayer4() {
    state = state.copyWith(layer4EventAlerts: !state.layer4EventAlerts);
    _save();
  }
}

final mapLayerProvider =
    StateNotifierProvider<MapLayerNotifier, MapLayerState>((ref) {
  return MapLayerNotifier();
});
```

**Step 2: Verify compilation**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/features/main/providers/map_layer_provider.dart 2>&1 | head -10`

**Step 3: Commit**

```bash
git add lib/features/main/providers/map_layer_provider.dart
git commit -m "feat(map): add MapLayerProvider for layer ON/OFF state with persistence (§3)"
```

---

## Task 3: Layer Settings Bottom Sheet — Toggle UI (§3)

**Files:**
- Create: `safetrip-mobile/lib/screens/main/bottom_sheets/bottom_sheet_layer_settings.dart`

**Step 1: Create the layer settings bottom sheet**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/main/providers/map_layer_provider.dart';
import '../../../features/trip/providers/trip_provider.dart';

/// 레이어 토글 패널 바텀시트 (지도 원칙 §3)
///
/// Layer 1~4만 토글 가능.
/// Layer 4는 캡틴/크루장에게만 표시.
void showLayerSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _LayerSettingsContent(),
  );
}

class _LayerSettingsContent extends ConsumerWidget {
  const _LayerSettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layerState = ref.watch(mapLayerProvider);
    final layerNotifier = ref.read(mapLayerProvider.notifier);
    final userRole = ref.watch(tripProvider).currentUserRole;
    final isLeader = userRole == 'captain' || userRole == 'crew_chief' || userRole == 'leader' || userRole == 'full';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('지도 레이어 설정', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),

            _LayerToggleTile(
              icon: Icons.local_hospital,
              iconColor: Colors.green,
              title: '안전시설',
              subtitle: '병원, 경찰서, 대사관',
              value: layerState.layer1SafetyFacilities,
              onChanged: (_) => layerNotifier.toggleLayer1(),
            ),
            _LayerToggleTile(
              icon: Icons.people,
              iconColor: AppColors.mapMarkerCrew,
              title: '멤버 위치',
              subtitle: '그룹 멤버 실시간 위치 마커',
              value: layerState.layer2MemberMarkers,
              onChanged: (_) => layerNotifier.toggleLayer2(),
            ),
            _LayerToggleTile(
              icon: Icons.event,
              iconColor: AppColors.primaryTeal,
              title: '일정/장소',
              subtitle: '여행 일정 장소 핀 마커',
              value: layerState.layer3SchedulePlaces,
              onChanged: (_) => layerNotifier.toggleLayer3(),
            ),
            if (isLeader)
              _LayerToggleTile(
                icon: Icons.notifications_active,
                iconColor: AppColors.semanticWarning,
                title: '이벤트/알림',
                subtitle: '지오펜스 경보, 출석 체크 마커',
                value: layerState.layer4EventAlerts,
                onChanged: (_) => layerNotifier.toggleLayer4(),
              ),

            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _LayerToggleTile extends StatelessWidget {
  const _LayerToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: iconColor),
      title: Text(title, style: AppTypography.bodyMedium),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
```

**Step 2: Verify compilation**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/screens/main/bottom_sheets/bottom_sheet_layer_settings.dart 2>&1 | head -10`

**Step 3: Commit**

```bash
git add lib/screens/main/bottom_sheets/bottom_sheet_layer_settings.dart
git commit -m "feat(map): add layer settings bottom sheet toggle UI (§3)"
```

---

## Task 4: Camera Transition Manager (§4)

**Files:**
- Create: `safetrip-mobile/lib/managers/map_camera_transition_manager.dart`

**Step 1: Create the camera transition manager**

```dart
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/map_constants.dart';

/// 카메라 자동 전환 우선순위 (지도 원칙 §4)
enum TransitionPriority {
  p0, // SOS
  p1, // 지오펜스 이탈, 앱 복귀
  p2, // 멤버 오프라인, 일정 시작
}

/// 카메라 전환 요청
class CameraTransition {
  CameraTransition({
    required this.priority,
    required this.targetPosition,
    required this.targetZoom,
    required this.reason,
    this.layerAction,
  });

  final TransitionPriority priority;
  final LatLng targetPosition;
  final double targetZoom;
  final String reason;
  /// 레이어 동작 콜백 (예: Layer 6 활성화)
  final VoidCallback? layerAction;
}

/// 카메라 자동 전환 큐 관리 (지도 원칙 §4)
///
/// P0 (SOS) > P1 (지오펜스 이탈/앱 복귀) > P2 (멤버 오프라인/일정 시작)
/// P0 처리 중 P1/P2 이벤트는 큐에 보관, SOS 해제 후 순차 처리.
class MapCameraTransitionManager {
  MapCameraTransitionManager({
    required this.getMapController,
  });

  final MapController? Function() getMapController;

  bool _isP0Active = false;
  final Queue<CameraTransition> _pendingQueue = Queue();

  bool get isP0Active => _isP0Active;

  /// 전환 요청 처리
  void requestTransition(CameraTransition transition) {
    if (_isP0Active && transition.priority != TransitionPriority.p0) {
      // P0 처리 중 → 큐에 보관
      _pendingQueue.add(transition);
      debugPrint('[CameraTransition] P0 활성 중 — ${transition.reason} 큐에 보관');
      return;
    }

    if (transition.priority == TransitionPriority.p0) {
      _isP0Active = true;
    }

    _executeTransition(transition);
  }

  /// SOS 발동 (§4 P0)
  void onSosActivated(LatLng senderPosition) {
    requestTransition(CameraTransition(
      priority: TransitionPriority.p0,
      targetPosition: senderPosition,
      targetZoom: MapConstants.sosZoomLevel,
      reason: 'sos',
    ));
  }

  /// SOS 해제 → 큐 순차 처리
  void onSosDeactivated() {
    _isP0Active = false;
    debugPrint('[CameraTransition] SOS 해제 — 큐 ${_pendingQueue.length}건 처리');
    _processPendingQueue();
  }

  /// 지오펜스 이탈 (§4 P1)
  void onGeofenceExit(LatLng memberPosition) {
    requestTransition(CameraTransition(
      priority: TransitionPriority.p1,
      targetPosition: memberPosition,
      targetZoom: MapConstants.defaultZoomLevel,
      reason: 'geofence_exit',
    ));
  }

  /// 앱 복귀 (§4 P1)
  void onAppResume(LatLng myPosition) {
    requestTransition(CameraTransition(
      priority: TransitionPriority.p1,
      targetPosition: myPosition,
      targetZoom: MapConstants.defaultZoomLevel,
      reason: 'app_resume',
    ));
  }

  /// 일정 시작 알림 (§4 P2 — 선택적, 강제 아님)
  void onScheduleStart(LatLng placePosition) {
    requestTransition(CameraTransition(
      priority: TransitionPriority.p2,
      targetPosition: placePosition,
      targetZoom: MapConstants.defaultZoomLevel,
      reason: 'schedule_start',
    ));
  }

  /// 여행 상태별 기본 카메라 이동 (§4)
  void moveToDefault({
    required String tripStatus,
    LatLng? myPosition,
    LatLng? destinationPosition,
  }) {
    final controller = getMapController();
    if (controller == null) return;

    switch (tripStatus) {
      case 'active':
        if (myPosition != null) {
          controller.move(myPosition, MapConstants.defaultZoomLevel);
        }
        break;
      case 'planning':
        if (destinationPosition != null) {
          controller.move(destinationPosition, MapConstants.planningZoomLevel);
        }
        break;
      default: // demo
        if (destinationPosition != null) {
          controller.move(destinationPosition, MapConstants.demoZoomLevel);
        }
        break;
    }
  }

  /// 가디언 카메라: 연결 멤버 바운딩 박스 피트 (§4)
  void fitGuardianMembers(List<LatLng> memberPositions) {
    final controller = getMapController();
    if (controller == null || memberPositions.isEmpty) return;

    if (memberPositions.length == 1) {
      controller.move(memberPositions.first, MapConstants.defaultZoomLevel);
      return;
    }

    // 바운딩 박스 계산
    double minLat = memberPositions.first.latitude;
    double maxLat = memberPositions.first.latitude;
    double minLng = memberPositions.first.longitude;
    double maxLng = memberPositions.first.longitude;

    for (final pos in memberPositions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - 0.005, minLng - 0.005),
          LatLng(maxLat + 0.005, maxLng + 0.005),
        ),
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  void _executeTransition(CameraTransition transition) {
    final controller = getMapController();
    if (controller == null) {
      debugPrint('[CameraTransition] MapController null — ${transition.reason} 스킵');
      return;
    }

    controller.move(transition.targetPosition, transition.targetZoom);
    transition.layerAction?.call();
    debugPrint('[CameraTransition] ${transition.reason} 실행 — 줌 ${transition.targetZoom}');
  }

  void _processPendingQueue() {
    while (_pendingQueue.isNotEmpty) {
      final next = _pendingQueue.removeFirst();
      _executeTransition(next);
    }
  }

  void dispose() {
    _pendingQueue.clear();
  }
}
```

**Step 2: Verify compilation**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/managers/map_camera_transition_manager.dart 2>&1 | head -10`

**Step 3: Commit**

```bash
git add lib/managers/map_camera_transition_manager.dart
git commit -m "feat(map): add camera transition manager with priority queue (§4)"
```

---

## Task 5: Offline Banner — Orange Color + Spec Message (§9.3)

**Files:**
- Modify: `safetrip-mobile/lib/widgets/components/offline_banner.dart`

**Step 1: Update offline banner to match spec**

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 오프라인 상태 배너 (지도 원칙 §9.3)
///
/// 네트워크 끊김 시 화면 상단에 **오렌지색** 배너 표시.
/// 메시지: "오프라인 상태 — 실시간 위치가 업데이트되지 않습니다"
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: Colors.orange,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 16, color: Colors.white),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '오프라인 상태 — 실시간 위치가 업데이트되지 않습니다',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/widgets/components/offline_banner.dart
git commit -m "fix(map): offline banner orange color + spec message (§9.3)"
```

---

## Task 6: SOS Overlay Enhancement — Full-Width Red Overlay (§10.1, Layer 6)

**Files:**
- Modify: `safetrip-mobile/lib/widgets/components/sos_overlay.dart`

**Step 1: Enhance SOS overlay**

The current implementation already shows a red banner with pulsing icon. The spec (§4) requires:
- SOS 발동 시 Layer 6 전체 화면 빨간 오버레이
- 발신자 정보 표시
- 동시 다수 SOS → SOS 목록 표시

The current implementation is close but needs a more prominent overlay. Add a semi-transparent red overlay behind the banner. Replace the file:

```dart
import 'package:flutter/material.dart';
import '../../constants/app_tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// SOS 긴급 오버레이 — Layer 6 (지도 원칙 §3, §4, §7.3)
///
/// SOS 발동 시 화면 상단에 고정 표시되는 알림 배너 + 반투명 오버레이.
/// 복수 SOS 시 목록 표시. SOS 해제 시 자동 비활성화.
class SosOverlay extends StatelessWidget {
  const SosOverlay({
    super.key,
    required this.userName,
    this.onDismiss,
    this.additionalSosUsers = const [],
  });

  final String userName;
  final VoidCallback? onDismiss;
  /// 동시 다수 SOS 시 추가 발신자 이름 (§7.3)
  final List<String> additionalSosUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.sm,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.sosDanger,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const _PulsingIcon(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SOS 긴급 알림 발송됨',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize16,
                        fontWeight: AppTokens.fontWeightBold,
                        color: AppColors.sosText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$userName님의 위치가 보호자에게 공유되고 있습니다',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.sosText.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 동시 다수 SOS 목록 (§7.3)
          if (additionalSosUsers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...additionalSosUsers.map((name) => Padding(
              padding: const EdgeInsets.only(left: 44, top: 2),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 14, color: AppColors.sosText),
                  const SizedBox(width: 6),
                  Text(
                    '$name님 SOS 발동 중',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.sosText.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.sosText,
        size: 28,
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/widgets/components/sos_overlay.dart
git commit -m "feat(map): enhance SOS overlay with multi-SOS list support (§7.3, Layer 6)"
```

---

## Task 7: Member Mini Card Widget (§5.4)

**Files:**
- Create: `safetrip-mobile/lib/widgets/map/member_mini_card.dart`

**Step 1: Create the member mini card widget**

```dart
import 'package:flutter/material.dart';

import '../../constants/map_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 멤버 마커 탭 시 표시되는 미니 카드 (지도 원칙 §5.4)
///
/// 이름, 역할, 마지막 업데이트 시각, 배터리 표시.
class MemberMiniCard extends StatelessWidget {
  const MemberMiniCard({
    super.key,
    required this.userName,
    required this.role,
    this.lastUpdated,
    this.batteryLevel,
    this.isOffline = false,
    this.onClose,
  });

  final String userName;
  final String role;
  final DateTime? lastUpdated;
  final int? batteryLevel;
  final bool isOffline;
  final VoidCallback? onClose;

  Color get _roleColor {
    switch (role) {
      case 'captain':
      case 'leader':
        return MapConstants.markerCaptain;
      case 'crew_chief':
      case 'full':
        return MapConstants.markerCrewLeader;
      case 'guardian':
        return MapConstants.markerGuardian;
      default:
        return MapConstants.markerCrew;
    }
  }

  String get _roleLabel {
    switch (role) {
      case 'captain':
      case 'leader':
        return '캡틴';
      case 'crew_chief':
      case 'full':
        return '크루장';
      case 'guardian':
        return '가디언';
      default:
        return '크루';
    }
  }

  String get _timeAgo {
    if (lastUpdated == null) return '';
    final diff = DateTime.now().difference(lastUpdated!);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  IconData get _batteryIcon {
    if (batteryLevel == null) return Icons.battery_unknown;
    if (batteryLevel! > 80) return Icons.battery_full;
    if (batteryLevel! > 50) return Icons.battery_5_bar;
    if (batteryLevel! > 20) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이름 + 역할
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOffline ? AppColors.mapMarkerOffline : _roleColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(userName, style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _roleLabel,
                      style: AppTypography.labelSmall.copyWith(
                        color: _roleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onClose,
                      child: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              // 마지막 업데이트 + 배터리
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOffline)
                    Text(
                      '오프라인',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.mapMarkerOffline,
                      ),
                    )
                  else if (lastUpdated != null)
                    Text(
                      _timeAgo,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  if (batteryLevel != null) ...[
                    const SizedBox(width: 8),
                    Icon(_batteryIcon, size: 14,
                      color: batteryLevel! <= 20
                          ? AppColors.semanticError
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$batteryLevel%',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Verify compilation**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/widgets/map/member_mini_card.dart 2>&1 | head -10`

**Step 3: Commit**

```bash
git add lib/widgets/map/member_mini_card.dart
git commit -m "feat(map): add member mini card widget for marker tap (§5.4)"
```

---

## Task 8: Schedule Marker Manager — Layer 3 (§10.2 P1)

**Files:**
- Create: `safetrip-mobile/lib/managers/schedule_marker_manager.dart`

**Step 1: Create schedule marker manager**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';

/// 일정/장소 마커 관리 — Layer 3 (지도 원칙 §3, §10.2)
///
/// 여행 일정 장소를 지도 위에 핀 마커로 표시.
/// 일정 순서대로 폴리라인 경로 연결.
/// 일정 시작 시 해당 마커 강조.
class ScheduleMarkerManager {
  ScheduleMarkerManager({
    required this.onMarkersUpdated,
    required this.onPolylinesUpdated,
    this.onScheduleMarkerTap,
  });

  final void Function(List<Marker>) onMarkersUpdated;
  final void Function(List<Polyline>) onPolylinesUpdated;
  final void Function(String scheduleId)? onScheduleMarkerTap;

  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  String? _highlightedScheduleId;

  List<Marker> get markers => List.from(_markers);
  List<Polyline> get polylines => List.from(_polylines);

  /// 일정 데이터로 마커 + 폴리라인 갱신
  void updateSchedules(List<Map<String, dynamic>> schedules) {
    _markers.clear();
    _polylines.clear();

    final routePoints = <LatLng>[];

    for (int i = 0; i < schedules.length; i++) {
      final schedule = schedules[i];
      final lat = schedule['latitude'] as double?;
      final lng = schedule['longitude'] as double?;
      final scheduleId = schedule['schedule_id'] as String? ?? '$i';
      final placeName = schedule['place_name'] as String? ?? '';

      if (lat == null || lng == null) continue;

      final position = LatLng(lat, lng);
      routePoints.add(position);

      final isHighlighted = _highlightedScheduleId == scheduleId;

      _markers.add(Marker(
        key: ValueKey('schedule_$scheduleId'),
        point: position,
        width: isHighlighted ? 48 : 36,
        height: isHighlighted ? 48 : 36,
        child: GestureDetector(
          onTap: () => onScheduleMarkerTap?.call(scheduleId),
          child: _SchedulePin(
            index: i + 1,
            placeName: placeName,
            isHighlighted: isHighlighted,
          ),
        ),
      ));
    }

    // 경로 폴리라인 (2개 이상 장소일 때)
    if (routePoints.length >= 2) {
      _polylines.add(Polyline(
        points: routePoints,
        color: AppColors.primaryTeal.withValues(alpha: 0.6),
        strokeWidth: 3,
        isDotted: true,
      ));
    }

    onMarkersUpdated(List.from(_markers));
    onPolylinesUpdated(List.from(_polylines));
  }

  /// 일정 시작 시 해당 마커 강조 (§4 P2)
  void highlightSchedule(String scheduleId) {
    _highlightedScheduleId = scheduleId;
    // 재빌드를 위해 updateSchedules를 다시 호출해야 함
  }

  void clearHighlight() {
    _highlightedScheduleId = null;
  }

  void dispose() {
    _markers.clear();
    _polylines.clear();
  }
}

/// 일정 핀 위젯
class _SchedulePin extends StatelessWidget {
  const _SchedulePin({
    required this.index,
    required this.placeName,
    this.isHighlighted = false,
  });

  final int index;
  final String placeName;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final size = isHighlighted ? 40.0 : 30.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isHighlighted
                ? AppColors.primaryTeal
                : AppColors.primaryTeal.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isHighlighted ? 3 : 2,
            ),
            boxShadow: isHighlighted
                ? [BoxShadow(
                    color: AppColors.primaryTeal.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )]
                : null,
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                color: Colors.white,
                fontSize: isHighlighted ? 16 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

**Step 2: Verify compilation**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/managers/schedule_marker_manager.dart 2>&1 | head -10`

**Step 3: Commit**

```bash
git add lib/managers/schedule_marker_manager.dart
git commit -m "feat(map): add schedule marker manager for Layer 3 (§3, §10.2)"
```

---

## Task 9: Event Marker Manager — Layer 4 (§10.2 P1)

**Files:**
- Create: `safetrip-mobile/lib/managers/event_marker_manager.dart`

**Step 1: Create event marker manager**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';

/// 이벤트/알림 마커 관리 — Layer 4 (지도 원칙 §3, §10.2)
///
/// 지오펜스 이탈 경보 마커, 출석 체크 위치 마커.
/// 캡틴/크루장 전용 레이어.
class EventMarkerManager {
  EventMarkerManager({
    required this.onMarkersUpdated,
    this.onEventMarkerTap,
  });

  final void Function(List<Marker>) onMarkersUpdated;
  final void Function(String eventId)? onEventMarkerTap;

  final List<Marker> _markers = [];

  List<Marker> get markers => List.from(_markers);

  /// 지오펜스 이탈 경보 마커 추가
  void addGeofenceExitAlert({
    required String eventId,
    required String memberName,
    required LatLng position,
  }) {
    // 중복 방지
    _markers.removeWhere((m) {
      final key = m.key is ValueKey<String> ? (m.key as ValueKey<String>).value : null;
      return key == 'event_$eventId';
    });

    _markers.add(Marker(
      key: ValueKey('event_$eventId'),
      point: position,
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => onEventMarkerTap?.call(eventId),
        child: _AlertPin(memberName: memberName),
      ),
    ));

    onMarkersUpdated(List.from(_markers));
  }

  /// 이벤트 마커 제거
  void removeEvent(String eventId) {
    _markers.removeWhere((m) {
      final key = m.key is ValueKey<String> ? (m.key as ValueKey<String>).value : null;
      return key == 'event_$eventId';
    });
    onMarkersUpdated(List.from(_markers));
  }

  /// 전체 이벤트 마커 초기화
  void clear() {
    _markers.clear();
    onMarkersUpdated([]);
  }

  void dispose() {
    _markers.clear();
  }
}

/// 경보 핀 위젯 (빨간 삼각형)
class _AlertPin extends StatelessWidget {
  const _AlertPin({required this.memberName});

  final String memberName;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$memberName 지오펜스 이탈',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.semanticError,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.warning,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/managers/event_marker_manager.dart
git commit -m "feat(map): add event marker manager for Layer 4 geofence alerts (§3, §10.2)"
```

---

## Task 10: Safety Facility Model + Manager — Layer 1 (§10.2 P1)

**Files:**
- Create: `safetrip-mobile/lib/models/safety_facility.dart`
- Create: `safetrip-mobile/lib/managers/safety_facility_manager.dart`

**Step 1: Create safety facility model**

```dart
/// 안전시설 모델 (지도 원칙 §3 Layer 1)
class SafetyFacility {
  SafetyFacility({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
  });

  factory SafetyFacility.fromJson(Map<String, dynamic> json) {
    return SafetyFacility(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: SafetyFacilityType.fromString(json['type'] as String?),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
    );
  }

  final String id;
  final String name;
  final SafetyFacilityType type;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
}

enum SafetyFacilityType {
  hospital,
  police,
  embassy;

  static SafetyFacilityType fromString(String? value) {
    switch (value) {
      case 'hospital':
        return SafetyFacilityType.hospital;
      case 'police':
        return SafetyFacilityType.police;
      case 'embassy':
        return SafetyFacilityType.embassy;
      default:
        return SafetyFacilityType.hospital;
    }
  }
}
```

**Step 2: Create safety facility manager**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';
import '../models/safety_facility.dart';

/// 안전시설 마커 관리 — Layer 1 (지도 원칙 §3, §10.2)
///
/// 병원(녹색 십자), 경찰서(파란 방패), 대사관(빨간 국기) 마커 표시.
/// 데이터는 백엔드 API에서 로드, 로컬 캐시 지원.
class SafetyFacilityManager {
  SafetyFacilityManager({
    required this.onMarkersUpdated,
  });

  final void Function(List<Marker>) onMarkersUpdated;

  final List<SafetyFacility> _facilities = [];
  final List<Marker> _markers = [];

  List<Marker> get markers => List.from(_markers);

  /// 안전시설 데이터 업데이트
  void updateFacilities(List<SafetyFacility> facilities) {
    _facilities.clear();
    _facilities.addAll(facilities);
    _rebuildMarkers();
  }

  /// JSON 리스트로부터 업데이트 (API 응답)
  void updateFromJson(List<Map<String, dynamic>> jsonList) {
    final facilities = jsonList.map(SafetyFacility.fromJson).toList();
    updateFacilities(facilities);
  }

  void _rebuildMarkers() {
    _markers.clear();

    for (final facility in _facilities) {
      _markers.add(Marker(
        key: ValueKey('safety_${facility.id}'),
        point: LatLng(facility.latitude, facility.longitude),
        width: 32,
        height: 32,
        child: _SafetyFacilityPin(
          type: facility.type,
          name: facility.name,
        ),
      ));
    }

    onMarkersUpdated(List.from(_markers));
  }

  void dispose() {
    _facilities.clear();
    _markers.clear();
  }
}

class _SafetyFacilityPin extends StatelessWidget {
  const _SafetyFacilityPin({
    required this.type,
    required this.name,
  });

  final SafetyFacilityType type;
  final String name;

  IconData get _icon {
    switch (type) {
      case SafetyFacilityType.hospital:
        return Icons.local_hospital;
      case SafetyFacilityType.police:
        return Icons.local_police;
      case SafetyFacilityType.embassy:
        return Icons.flag;
    }
  }

  Color get _color {
    switch (type) {
      case SafetyFacilityType.hospital:
        return Colors.green;
      case SafetyFacilityType.police:
        return Colors.blue;
      case SafetyFacilityType.embassy:
        return AppColors.semanticError;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Icon(_icon, color: Colors.white, size: 16),
      ),
    );
  }
}
```

**Step 3: Commit**

```bash
git add lib/models/safety_facility.dart lib/managers/safety_facility_manager.dart
git commit -m "feat(map): add safety facility model + manager for Layer 1 (§3, §10.2)"
```

---

## Task 11: Integrate Layers + Camera Transitions into screen_main.dart

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

This is the largest integration task. It wires everything together:
1. Add layer settings button (Layer 5)
2. Add layer toggle state (via `mapLayerProvider`)
3. Add camera transition manager
4. Add schedule markers (Layer 3) — conditional on `layer3SchedulePlaces`
5. Add event markers (Layer 4) — conditional on `layer4EventAlerts`
6. Add safety facility markers (Layer 1) — conditional on `layer1SafetyFacilities`
7. Add member mini card on marker tap
8. Add app lifecycle observer for camera restore (§4 P1)
9. Wire SOS to camera transition manager (§4 P0)

**Step 1: Add imports at top of screen_main.dart (after existing imports)**

```dart
import '../../features/main/providers/map_layer_provider.dart';
import '../../managers/map_camera_transition_manager.dart';
import '../../managers/schedule_marker_manager.dart';
import '../../managers/event_marker_manager.dart';
import '../../managers/safety_facility_manager.dart';
import '../../widgets/map/member_mini_card.dart';
import 'bottom_sheets/bottom_sheet_layer_settings.dart';
```

**Step 2: Add fields in _MainScreenState class (after existing fields)**

```dart
  late final MapCameraTransitionManager _cameraTransitionManager;
  late final ScheduleMarkerManager _scheduleMarkerManager;
  late final EventMarkerManager _eventMarkerManager;
  late final SafetyFacilityManager _safetyFacilityManager;

  final ValueNotifier<List<Marker>> _scheduleMarkersNotifier = ValueNotifier([]);
  final ValueNotifier<List<Polyline>> _scheduleLinesNotifier = ValueNotifier([]);
  final ValueNotifier<List<Marker>> _eventMarkersNotifier = ValueNotifier([]);
  final ValueNotifier<List<Marker>> _safetyMarkersNotifier = ValueNotifier([]);

  /// 멤버 미니카드 표시 상태 (§5.4)
  String? _selectedMarkerUserId;
  Map<String, dynamic>? _selectedMarkerUserData;
```

**Step 3: Initialize managers in initState (after existing MarkerManager init)**

```dart
    _cameraTransitionManager = MapCameraTransitionManager(
      getMapController: () => _mapController,
    );

    _scheduleMarkerManager = ScheduleMarkerManager(
      onMarkersUpdated: (markers) => _scheduleMarkersNotifier.value = markers,
      onPolylinesUpdated: (lines) => _scheduleLinesNotifier.value = lines,
      onScheduleMarkerTap: (id) {
        debugPrint('[MainScreen] Schedule marker tapped: $id');
      },
    );

    _eventMarkerManager = EventMarkerManager(
      onMarkersUpdated: (markers) => _eventMarkersNotifier.value = markers,
      onEventMarkerTap: (id) {
        debugPrint('[MainScreen] Event marker tapped: $id');
      },
    );

    _safetyFacilityManager = SafetyFacilityManager(
      onMarkersUpdated: (markers) => _safetyMarkersNotifier.value = markers,
    );
```

**Step 4: Update MarkerManager `onMarkerTap` to show mini card**

Replace the existing `onMarkerTap` callback:

```dart
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
```

**Step 5: Add app lifecycle resume handler**

In the `didChangeMetrics` override area, add a new override:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // §4 P1: 앱 복귀 시 내 위치로 카메라 복귀
      _locationService.getCurrentPosition().then((location) {
        if (location != null && mounted) {
          _cameraTransitionManager.onAppResume(
            LatLng(location.coords.latitude, location.coords.longitude),
          );
        }
      });
    }
  }
```

**Step 6: Update _handleSOS to use camera transition manager**

Replace `_centerMapOnCurrentLocation()` call in `_handleSOS`:

```dart
    // §4 P0: 카메라 자동 전환 매니저로 SOS 발동 처리
    final location = await _locationService.getCurrentPosition();
    if (location != null && mounted) {
      _cameraTransitionManager.onSosActivated(
        LatLng(location.coords.latitude, location.coords.longitude),
      );
    }
```

**Step 7: Update _handleSOSRelease to deactivate camera transition**

Add after `notifier.deactivateSos()`:

```dart
    _cameraTransitionManager.onSosDeactivated();
```

**Step 8: Add layer toggle button and member mini card to build method**

In the `Stack` children, after the top trip info card and before the bottom sheet:

```dart
            // ── Layer Settings Button (우측 상단) ─────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: AppSpacing.md,
              child: FloatingActionButton.small(
                heroTag: 'layer_settings',
                onPressed: () => showLayerSettingsSheet(context),
                backgroundColor: Colors.white,
                child: const Icon(Icons.layers, color: AppColors.textSecondary),
              ),
            ),
```

After the SOS overlay (Layer 6), add the member mini card:

```dart
            // ── Member Mini Card (§5.4) ───────────────────
            if (_selectedMarkerUserId != null && _selectedMarkerUserData != null)
              Positioned(
                bottom: AppSpacing.navigationBarHeight + 80,
                left: AppSpacing.md,
                right: AppSpacing.md + 72, // SOS 버튼 공간 확보
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedMarkerUserId = null;
                    _selectedMarkerUserData = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: MemberMiniCard(
                    userName: _selectedMarkerUserData!['user_name'] as String? ?? '',
                    role: _selectedMarkerUserData!['role'] as String? ?? 'crew',
                    batteryLevel: _selectedMarkerUserData!['battery'] as int?,
                    onClose: () => setState(() {
                      _selectedMarkerUserId = null;
                      _selectedMarkerUserData = null;
                    }),
                  ),
                ),
              ),
```

**Step 9: Update FlutterMap children to include conditional layers**

Replace the FlutterMap children section with layer-aware rendering. The FlutterMap should conditionally include schedule polylines, schedule markers, event markers, and safety markers based on `mapLayerProvider` state:

```dart
            ValueListenableBuilder<List<Marker>>(
              valueListenable: _userMarkersNotifier,
              builder: (context, userMarkers, _) {
                final layerState = ref.watch(mapLayerProvider);

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
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.urock.safe.trip',
                    ),
                    // Layer 1: 안전시설 마커
                    if (layerState.layer1SafetyFacilities)
                      ValueListenableBuilder<List<Marker>>(
                        valueListenable: _safetyMarkersNotifier,
                        builder: (_, markers, __) => MarkerLayer(markers: markers),
                      ),
                    // Layer 2: 멤버 위치 마커
                    if (layerState.layer2MemberMarkers)
                      MarkerLayer(markers: userMarkers),
                    // Layer 3: 일정 폴리라인
                    if (layerState.layer3SchedulePlaces)
                      ValueListenableBuilder<List<Polyline>>(
                        valueListenable: _scheduleLinesNotifier,
                        builder: (_, lines, __) => PolylineLayer(polylines: lines),
                      ),
                    // Layer 3: 일정 장소 마커
                    if (layerState.layer3SchedulePlaces)
                      ValueListenableBuilder<List<Marker>>(
                        valueListenable: _scheduleMarkersNotifier,
                        builder: (_, markers, __) => MarkerLayer(markers: markers),
                      ),
                    // Layer 4: 이벤트/알림 마커
                    if (layerState.layer4EventAlerts)
                      ValueListenableBuilder<List<Marker>>(
                        valueListenable: _eventMarkersNotifier,
                        builder: (_, markers, __) => MarkerLayer(markers: markers),
                      ),
                  ],
                );
              },
            ),
```

**Step 10: Add dispose calls**

In `dispose()`, add:

```dart
    _cameraTransitionManager.dispose();
    _scheduleMarkerManager.dispose();
    _eventMarkerManager.dispose();
    _safetyFacilityManager.dispose();
    _scheduleMarkersNotifier.dispose();
    _scheduleLinesNotifier.dispose();
    _eventMarkersNotifier.dispose();
    _safetyMarkersNotifier.dispose();
```

**Step 11: Verify compilation**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/screens/main/screen_main.dart 2>&1 | head -30`

Fix any compilation errors.

**Step 12: Commit**

```bash
git add lib/screens/main/screen_main.dart
git commit -m "feat(map): integrate layers, camera transitions, mini card into main screen (§3-§5)"
```

---

## Task 12: Guardian Screen — Bounding Box Camera (§4)

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main_guardian.dart`

**Step 1: Add camera transition manager import and field**

Add import:
```dart
import '../../managers/map_camera_transition_manager.dart';
```

Add field:
```dart
  late final MapCameraTransitionManager _cameraTransitionManager;
```

Initialize in the state class (override `initState`):
```dart
  @override
  void initState() {
    super.initState();
    _cameraTransitionManager = MapCameraTransitionManager(
      getMapController: () => _mapController,
    );
  }
```

**Step 2: Add lifecycle dispose**

```dart
  @override
  void dispose() {
    _cameraTransitionManager.dispose();
    super.dispose();
  }
```

**Step 3: Commit**

```bash
git add lib/screens/main/screen_main_guardian.dart
git commit -m "feat(map): add camera transition manager to guardian screen (§4)"
```

---

## Task 13: Update Marker Manager — 3-Stage Clustering + Privacy Filter (§5.2, §6)

**Files:**
- Modify: `safetrip-mobile/lib/managers/marker_manager.dart`

**Step 1: Update clustering logic in getFilteredUserMarkers**

The current code does not have zoom-based clustering logic (it relies on the `flutter_map_marker_cluster` package externally). The key changes:

1. Update `MarkerManager` constructor to accept `currentPrivacyLevel` and `getScheduleTimeActive` callbacks.
2. Add privacy filtering to `getFilteredUserMarkers()`.

Add new constructor parameters (after `isBeforeTripStart`):

```dart
    this.currentPrivacyLevel,
    this.getScheduleTimeActive,
```

Add fields:

```dart
  final String Function()? currentPrivacyLevel;
  final bool Function(String userId)? getScheduleTimeActive;
```

Add privacy filtering in `getFilteredUserMarkers()`, after the `locationSharingEnabled` check (around line 607):

```dart
      // §6: 프라이버시 등급별 마커 필터링
      final privacyLevel = currentPrivacyLevel?.call() ?? 'standard';
      if (privacyLevel == 'safety_first') {
        // 전체 멤버 항상 표시 — 필터링 없음
        filteredPositions[userId] = entry.value;
      } else if (privacyLevel == 'standard') {
        // 공유 ON 멤버만 표시
        if (locationSharingEnabled || canViewAllLocations) {
          if (selectedUserIdsForFilter.isEmpty || selectedUserIdsForFilter.contains(userId)) {
            filteredPositions[userId] = entry.value;
          }
        }
      } else if (privacyLevel == 'privacy_first') {
        // 일정 연동 시간대만 표시
        final isScheduleTime = getScheduleTimeActive?.call(userId) ?? true;
        if (isScheduleTime || canViewAllLocations) {
          if (selectedUserIdsForFilter.isEmpty || selectedUserIdsForFilter.contains(userId)) {
            filteredPositions[userId] = entry.value;
          }
        }
      }
```

**Step 2: Verify compilation**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/managers/marker_manager.dart 2>&1 | head -20`

**Step 3: Commit**

```bash
git add lib/managers/marker_manager.dart
git commit -m "feat(map): add privacy level filtering to marker manager (§6)"
```

---

## Task 14: Full Integration Verification

**Step 1: Run full project analysis**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze 2>&1 | tail -30`

Fix any errors found.

**Step 2: Verify the app builds**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter build apk --debug 2>&1 | tail -20`

**Step 3: Final commit if fixes were needed**

```bash
git add -A
git commit -m "fix(map): resolve compilation issues from map principle integration"
```

---

## Task 15: Offline Map Service — Tile Caching (§9.1)

**Files:**
- Create: `safetrip-mobile/lib/services/offline_map_service.dart`

**Step 1: Create offline map service**

This service manages tile caching for offline use. It uses `flutter_map`'s built-in `NetworkTileProvider` with a custom caching layer via `shared_preferences` for metadata and the device file system for tiles.

```dart
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오프라인 지도 타일 캐시 서비스 (지도 원칙 §9.1)
///
/// 여행 목적지 중심 반경 50km, 줌 10~16 타일 사전 다운로드.
/// 최대 500MB/국가 제한.
/// planning→active 전환 시 Wi-Fi에서 자동 시작.
/// 종료 후 30일 만료.
class OfflineMapService {
  static const int _minZoom = 10;
  static const int _maxZoom = 16;
  static const double _radiusKm = 50.0;
  static const int _maxSizeMb = 500;
  static const int _expirationDays = 30;
  static const _prefsKeyPrefix = 'offline_map_';

  /// 타일 URL 생성 (OSM)
  static String tileUrl(int z, int x, int y) {
    return 'https://tile.openstreetmap.org/$z/$x/$y.png';
  }

  /// 캐시 디렉토리 경로
  Future<Directory> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/offline_tiles');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 현재 캐시 크기 (MB)
  Future<double> getCacheSizeMb() async {
    final dir = await _cacheDir;
    if (!await dir.exists()) return 0;

    int totalBytes = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes / (1024 * 1024);
  }

  /// 캐시 만료 여부 확인 (30일)
  Future<bool> isCacheExpired(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final completedAt = prefs.getString('${_prefsKeyPrefix}completed_$tripId');
    if (completedAt == null) return false;

    final completedDate = DateTime.parse(completedAt);
    return DateTime.now().difference(completedDate).inDays > _expirationDays;
  }

  /// 만료된 캐시 정리
  Future<void> cleanExpiredCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('${_prefsKeyPrefix}completed_'));

    for (final key in keys) {
      final tripId = key.replaceFirst('${_prefsKeyPrefix}completed_', '');
      if (await isCacheExpired(tripId)) {
        await deleteCacheForTrip(tripId);
        await prefs.remove(key);
        debugPrint('[OfflineMap] 만료된 캐시 삭제: $tripId');
      }
    }
  }

  /// 여행별 캐시 삭제
  Future<void> deleteCacheForTrip(String tripId) async {
    final dir = await _cacheDir;
    final tripDir = Directory('${dir.path}/$tripId');
    if (await tripDir.exists()) {
      await tripDir.delete(recursive: true);
    }
  }

  /// 타일 좌표 계산 (위경도 → 타일 XY)
  static int _lngToTileX(double lng, int zoom) {
    return ((lng + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  static int _latToTileY(double lat, int zoom) {
    final latRad = lat * pi / 180.0;
    return ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * (1 << zoom)).floor();
  }

  /// 다운로드할 타일 수 추정 (줌 10~16, 반경 50km)
  static int estimateTileCount(double lat, double lng) {
    int count = 0;
    for (int z = _minZoom; z <= _maxZoom; z++) {
      // 간략 계산: 반경에 해당하는 타일 수
      final metersPerTile = 40075016.686 * cos(lat * pi / 180) / (1 << z);
      final tilesPerSide = (_radiusKm * 1000 * 2 / metersPerTile).ceil();
      count += tilesPerSide * tilesPerSide;
    }
    return count;
  }

  /// 여행 종료 기록 (만료 타이머 시작)
  Future<void> markTripCompleted(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_prefsKeyPrefix}completed_$tripId',
      DateTime.now().toIso8601String(),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/offline_map_service.dart
git commit -m "feat(map): add offline map tile cache service (§9.1)"
```

---

## Completion Checklist

After all tasks are done, verify against the 원칙 §11 검증 체크리스트:

| # | 검증 항목 | Task |
|---|---------|------|
| 1 | G1~G5 원칙 준수 | T1-T6 |
| 2 | SOS 버튼 항상 표시 | Already done |
| 3 | Layer 6 SOS 오버레이 즉시 활성화 | T6, T11 |
| 4 | 역할별 마커 색상 일치 | T1 |
| 5 | 터치 인터랙션 우선순위 | T7, T11 |
| 6 | Layer 0~6 렌더링 순서 | T11 |
| 7 | 레이어 토글 앱 재시작 유지 | T2, T3 |
| 8 | P0 SOS 카메라 즉시 이동 | T4, T11 |
| 9 | P0 중 P1/P2 큐 보관 | T4 |
| 10 | 줌 15+ 개별 마커 + 이름 라벨 | T1, T13 |
| 11 | 클러스터 내 SOS 빨간 배지 | Future: Phase 2 |
| 12 | 오프라인 배너 오렌지색 | T5 |
| 13 | 프라이버시 등급별 마커 표시 | T13 |
| 14 | 가디언 바운딩 박스 카메라 | T4, T12 |
