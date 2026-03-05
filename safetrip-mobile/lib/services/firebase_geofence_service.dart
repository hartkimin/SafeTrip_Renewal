import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/geofence.dart';

/// Firebase Realtime Database를 사용한 실시간 지오펜스 서비스
/// 지오펜스 변경사항을 실시간으로 감지하여 플러그인에 동기화
class FirebaseGeofenceService {
  factory FirebaseGeofenceService() => _instance;
  FirebaseGeofenceService._internal();
  static final FirebaseGeofenceService _instance =
      FirebaseGeofenceService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// 그룹의 실시간 지오펜스 변경 감지 (추가)
  Stream<GeofenceData> listenGeofenceAdded(String groupId) {
    return _database
        .child('realtime_geofences')
        .child(groupId)
        .onChildAdded
        .map((event) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          return GeofenceData.fromJson(data);
        });
  }

  /// 그룹의 실시간 지오펜스 변경 감지 (수정)
  Stream<GeofenceData> listenGeofenceChanged(String groupId) {
    return _database
        .child('realtime_geofences')
        .child(groupId)
        .onChildChanged
        .map((event) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          return GeofenceData.fromJson(data);
        });
  }

  /// 그룹의 실시간 지오펜스 변경 감지 (삭제)
  Stream<String> listenGeofenceRemoved(String groupId) {
    return _database
        .child('realtime_geofences')
        .child(groupId)
        .onChildRemoved
        .map((event) => event.snapshot.key!);
  }

  /// 그룹의 모든 실시간 지오펜스 조회 (초기 로드용)
  Stream<Map<String, GeofenceData>> listenAllGeofences(String groupId) {
    return _database.child('realtime_geofences').child(groupId).onValue.map((
      event,
    ) {
      if (event.snapshot.value == null) return <String, GeofenceData>{};

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );
      final Map<String, GeofenceData> geofences = {};

      data.forEach((key, value) {
        try {
          final geofenceData = Map<String, dynamic>.from(value as Map);
          geofences[key] = GeofenceData.fromJson(geofenceData);
        } catch (e) {
          debugPrint('[FirebaseGeofence] 지오펜스 파싱 실패 ($key): $e');
        }
      });

      return geofences;
    });
  }

  /// 특정 지오펜스 ID로 지오펜스 정보 조회
  Future<GeofenceData?> getGeofenceById(
    String groupId,
    String geofenceId,
  ) async {
    try {
      final snapshot = await _database
          .child('realtime_geofences')
          .child(groupId)
          .child(geofenceId)
          .get();

      if (snapshot.value == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      
      final geofence = GeofenceData.fromJson(data);
      
      return geofence;
    } catch (e) {
      debugPrint('[FirebaseGeofence] 지오펜스 조회 실패 ($geofenceId): $e');
      return null;
    }
  }
}
