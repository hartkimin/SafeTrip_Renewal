import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_cache.dart';

/// 출석체크 서비스
/// Firebase Realtime Database를 사용한 출석체크 기능
class AttendanceService {
  factory AttendanceService() => _instance;
  AttendanceService._internal();
  static final AttendanceService _instance = AttendanceService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  /// 출석 기록 작성
  ///
  /// [groupId] 그룹 ID
  /// [status] 출석 상태 ('attended' | 'going' | 'unavailable')
  /// [latitude] 위도
  /// [longitude] 경도
  /// [message] 사용자가 작성한 문구 (선택사항)
  Future<void> markAttendance({
    required String groupId,
    required String status,
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    try {
      final userId = await AppCache.userId;
      final userName = await AppCache.userName;

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // 만료 체크
      final isExpired = await this.isExpired(groupId);
      if (isExpired) {
        throw Exception('Attendance check session has expired');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final attendanceData = {
        'user_id': userId,
        'user_name': userName ?? 'Unknown',
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'checked_at': now,
        'created_at': now,
        if (message != null && message.isNotEmpty) 'message': message,
      };

      await _database
          .child('realtime_attendance')
          .child(groupId)
          .child(userId)
          .set(attendanceData);

      debugPrint('[AttendanceService] 출석 기록 성공: $status');
    } catch (e) {
      debugPrint('[AttendanceService] 출석 기록 실패: $e');
      rethrow;
    }
  }

  /// 출석 현황 실시간 리스닝
  ///
  /// [groupId] 그룹 ID
  /// 만료 체크 포함
  Stream<Map<String, dynamic>?> listenAttendanceStatus(String groupId) {
    final ref = _database.child('realtime_attendance').child(groupId);
    ref.keepSynced(true); // 로컬 캐싱 및 오프라인-온라인 큐 자동 동기화 유지

    return ref.onValue.asyncMap((event) async {
      if (event.snapshot.value == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

          // 만료 체크
          final expiresAt = data['_expires_at'] as int?;
          if (expiresAt != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now > expiresAt) {
              debugPrint('[AttendanceService] 출석체크 세션 만료됨');
              return null;
            }
          }

          return data;
        });
  }

  /// 출석체크 세션 만료 여부 확인
  Future<bool> isExpired(String groupId) async {
    try {
      final snapshot = await _database
          .child('realtime_attendance')
          .child(groupId)
          .child('_expires_at')
          .once();

      if (!snapshot.snapshot.exists) {
        return true;
      }

      final expiresAt = snapshot.snapshot.value as int?;
      if (expiresAt == null) {
        return true;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      return now > expiresAt;
    } catch (e) {
      debugPrint('[AttendanceService] 만료 체크 실패: $e');
      return true;
    }
  }

  /// 활성 출석체크 요청 존재 여부 확인
  Future<bool> hasActiveAttendanceCheck(String groupId) async {
    try {
      final snapshot = await _database
          .child('realtime_attendance')
          .child(groupId)
          .once();

      if (!snapshot.snapshot.exists) {
        return false;
      }

      final data = snapshot.snapshot.value as Map?;
      if (data == null) {
        return false;
      }

      // 만료 체크
      final expiresAt = data['_expires_at'] as int?;
      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now > expiresAt) {
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('[AttendanceService] 활성 출석체크 확인 실패: $e');
      return false;
    }
  }

  /// _expires_at 조회 (타이머용)
  Future<int?> getExpiresAt(String groupId) async {
    try {
      final snapshot = await _database
          .child('realtime_attendance')
          .child(groupId)
          .child('_expires_at')
          .once();

      if (!snapshot.snapshot.exists) {
        return null;
      }

      return snapshot.snapshot.value as int?;
    } catch (e) {
      debugPrint('[AttendanceService] _expires_at 조회 실패: $e');
      return null;
    }
  }

  /// 관리자 문구 조회
  Future<String?> getMessage(String groupId) async {
    try {
      final snapshot = await _database
          .child('realtime_attendance')
          .child(groupId)
          .child('_message')
          .once();

      if (!snapshot.snapshot.exists) {
        return null;
      }

      return snapshot.snapshot.value as String?;
    } catch (e) {
      debugPrint('[AttendanceService] _message 조회 실패: $e');
      return null;
    }
  }

  /// 본인 출석 기록 조회
  Future<Map<String, dynamic>?> getMyAttendance(String groupId) async {
    try {
      final userId = await AppCache.userId;
      if (userId == null) {
        return null;
      }

      final snapshot = await _database
          .child('realtime_attendance')
          .child(groupId)
          .child(userId)
          .once();

      if (!snapshot.snapshot.exists) {
        return null;
      }

      return Map<String, dynamic>.from(snapshot.snapshot.value as Map);
    } catch (e) {
      debugPrint('[AttendanceService] 본인 출석 기록 조회 실패: $e');
      return null;
    }
  }

  /// 출석 데이터 초기화 (선택)
  Future<void> clearAttendance(String groupId) async {
    try {
      await _database.child('realtime_attendance').child(groupId).remove();
      debugPrint('[AttendanceService] 출석 데이터 초기화 완료');
    } catch (e) {
      debugPrint('[AttendanceService] 출석 데이터 초기화 실패: $e');
      rethrow;
    }
  }
}
