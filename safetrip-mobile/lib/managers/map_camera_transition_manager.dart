import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/map_constants.dart';

enum TransitionPriority { p0, p1, p2 }

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
  final VoidCallback? layerAction;
}

/// 카메라 자동 전환 큐 관리 (지도 원칙 §4)
class MapCameraTransitionManager {
  MapCameraTransitionManager({
    required this.getMapController,
  });

  final MapController? Function() getMapController;

  bool _isP0Active = false;
  final Queue<CameraTransition> _pendingQueue = Queue();

  bool get isP0Active => _isP0Active;

  void requestTransition(CameraTransition transition) {
    if (_isP0Active && transition.priority != TransitionPriority.p0) {
      _pendingQueue.add(transition);
      debugPrint('[CameraTransition] P0 활성 중 — ${transition.reason} 큐에 보관');
      return;
    }

    if (transition.priority == TransitionPriority.p0) {
      _isP0Active = true;
    }

    _executeTransition(transition);
  }

  void onSosActivated(LatLng senderPosition) {
    requestTransition(CameraTransition(
      priority: TransitionPriority.p0,
      targetPosition: senderPosition,
      targetZoom: MapConstants.sosZoomLevel,
      reason: 'sos',
    ));
  }

  void onSosDeactivated() {
    _isP0Active = false;
    debugPrint('[CameraTransition] SOS 해제 — 큐 ${_pendingQueue.length}건 처리');
    _processPendingQueue();
  }

  void onGeofenceExit(LatLng memberPosition) {
    requestTransition(CameraTransition(
      priority: TransitionPriority.p1,
      targetPosition: memberPosition,
      targetZoom: MapConstants.defaultZoomLevel,
      reason: 'geofence_exit',
    ));
  }

  void onAppResume(LatLng myPosition) {
    requestTransition(CameraTransition(
      priority: TransitionPriority.p1,
      targetPosition: myPosition,
      targetZoom: MapConstants.defaultZoomLevel,
      reason: 'app_resume',
    ));
  }

  void onScheduleStart(LatLng placePosition) {
    requestTransition(CameraTransition(
      priority: TransitionPriority.p2,
      targetPosition: placePosition,
      targetZoom: MapConstants.defaultZoomLevel,
      reason: 'schedule_start',
    ));
  }

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
      default:
        if (destinationPosition != null) {
          controller.move(destinationPosition, MapConstants.demoZoomLevel);
        }
        break;
    }
  }

  void fitGuardianMembers(List<LatLng> memberPositions) {
    final controller = getMapController();
    if (controller == null || memberPositions.isEmpty) return;

    if (memberPositions.length == 1) {
      controller.move(memberPositions.first, MapConstants.defaultZoomLevel);
      return;
    }

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
