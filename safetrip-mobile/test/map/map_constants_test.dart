import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/constants/map_constants.dart';

/// MapConstants 단위 테스트 (17_T3 지도 기본화면 고유 원칙 §11 검증)
///
/// 검증 항목:
/// - 오프라인 감지 임계값 (§7.1)
/// - 3단계 클러스터링 줌 임계값 (§5.2)
/// - 역할별 마커 색상 (§5.3)
/// - 기본 줌 레벨
void main() {
  group('MapConstants — 오프라인 감지 (§7.1)', () {
    test('offlineThreshold는 5분이어야 한다', () {
      expect(
        MapConstants.offlineThreshold,
        equals(const Duration(minutes: 5)),
      );
    });

    test('offlineThreshold는 20분이 아니어야 한다 (구 규격 금지)', () {
      expect(
        MapConstants.offlineThreshold,
        isNot(equals(const Duration(minutes: 20))),
      );
    });
  });

  group('MapConstants — 3단계 클러스터링 줌 임계값 (§5.2)', () {
    test('clusterIndividualThreshold == 15.0 (개별 마커 표시)', () {
      expect(MapConstants.clusterIndividualThreshold, equals(15.0));
    });

    test('clusterMixedThreshold == 12.0 (혼합 표시)', () {
      expect(MapConstants.clusterMixedThreshold, equals(12.0));
    });

    test('clusterOnlyThreshold == 11.0 (클러스터만 표시)', () {
      expect(MapConstants.clusterOnlyThreshold, equals(11.0));
    });

    test('줌 임계값 순서: individual > mixed > only', () {
      expect(
        MapConstants.clusterIndividualThreshold,
        greaterThan(MapConstants.clusterMixedThreshold),
      );
      expect(
        MapConstants.clusterMixedThreshold,
        greaterThan(MapConstants.clusterOnlyThreshold),
      );
    });

    test('clusterMixedMinCount == 4 (혼합 표시 최소 인원)', () {
      expect(MapConstants.clusterMixedMinCount, equals(4));
    });
  });

  group('MapConstants — 역할별 마커 색상 (§5.3)', () {
    test('캡틴 마커 색상은 금색(#FFD700)이어야 한다', () {
      expect(MapConstants.markerCaptain, equals(const Color(0xFFFFD700)));
    });

    test('크루장 마커 색상은 주황색(#FF8C00)이어야 한다', () {
      expect(MapConstants.markerCrewLeader, equals(const Color(0xFFFF8C00)));
    });

    test('크루 마커 색상은 파란색(#2196F3)이어야 한다', () {
      expect(MapConstants.markerCrew, equals(const Color(0xFF2196F3)));
    });

    test('내 위치 마커 색상은 녹색(#4CAF50)이어야 한다', () {
      expect(MapConstants.markerMyLocation, equals(const Color(0xFF4CAF50)));
    });

    test('가디언 마커 색상은 보라색(#9C27B0)이어야 한다', () {
      expect(MapConstants.markerGuardian, equals(const Color(0xFF9C27B0)));
    });

    test('모든 역할 색상이 서로 달라야 한다', () {
      final colors = [
        MapConstants.markerCaptain,
        MapConstants.markerCrewLeader,
        MapConstants.markerCrew,
        MapConstants.markerMyLocation,
        MapConstants.markerGuardian,
      ];
      // Set으로 변환하여 중복 확인
      expect(colors.toSet().length, equals(colors.length));
    });
  });

  group('MapConstants — 기본 줌 레벨', () {
    test('defaultZoomLevel == 15.0', () {
      expect(MapConstants.defaultZoomLevel, equals(15.0));
    });

    test('sosZoomLevel == 16.0 (SOS 시 더 가까이 확대)', () {
      expect(MapConstants.sosZoomLevel, equals(16.0));
    });

    test('SOS 줌 레벨이 기본 줌 레벨보다 커야 한다', () {
      expect(
        MapConstants.sosZoomLevel,
        greaterThan(MapConstants.defaultZoomLevel),
      );
    });
  });
}
