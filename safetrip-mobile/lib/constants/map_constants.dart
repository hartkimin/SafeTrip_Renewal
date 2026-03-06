import 'package:flutter/material.dart';

class MapConstants {
  // ─ 기본 줌 레벨 ─────────────────────────────────
  static const double defaultZoomLevel = 15.0;
  static const double userSelectionZoomLevel = 15.0;
  static const double sosZoomLevel = 16.0;
  static const double planningZoomLevel = 12.0;
  static const double demoZoomLevel = 12.0;

  // ─ 3단계 클러스터링 (§5.2) ──────────────────────
  static const double clusterIndividualThreshold = 15.0;
  static const double clusterMixedThreshold = 12.0;
  static const double clusterOnlyThreshold = 11.0;
  static const int clusterMixedMinCount = 4;

  // ─ 레거시 호환 ─────────────────────────────────
  static const double clusterZoomThreshold = clusterIndividualThreshold;

  // ─ 역할별 마커 색상 (§5.3) ──────────────────────
  static const Color markerCaptain = Color(0xFFFFD700);
  static const Color markerCrewLeader = Color(0xFFFF8C00);
  static const Color markerCrew = Color(0xFF2196F3);
  static const Color markerMyLocation = Color(0xFF4CAF50);
  static const Color markerGuardian = Color(0xFF9C27B0);

  // ─ 멤버 오프라인 감지 (§7.1) ────────────────────
  static const Duration offlineThreshold = Duration(minutes: 5);
}
