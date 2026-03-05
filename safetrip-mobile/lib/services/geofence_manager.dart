import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/geofence.dart';
import '../models/geofence_event.dart';
import 'api_service.dart';
import 'log_service.dart';
import 'location_service.dart';
import 'firebase_geofence_service.dart';
import '../utils/map_utils.dart';

/// 지오펜스 이벤트 검증 결과
class GeofenceValidationResult {

  GeofenceValidationResult({
    required this.isValid,
    this.failureReason,
    this.distance,
  });
  final bool isValid;
  final String? failureReason;
  final double? distance;
}

class GeofenceManager {
  final _eventController = StreamController<GeofenceEvent>.broadcast();
  final _geofencesController = StreamController<List<GeofenceData>>.broadcast();
  final _apiService = ApiService();
  final _firebaseGeofenceService = FirebaseGeofenceService();

  final Map<String, GeofenceData> _registeredGeofences = {};
  bool _isInitialized = false;
  StreamSubscription<GeofenceData>? _firebaseAddedSubscription;
  StreamSubscription<GeofenceData>? _firebaseChangedSubscription;
  StreamSubscription<String>? _firebaseRemovedSubscription;
  StreamSubscription<Map<String, GeofenceData>>? _firebaseAllSubscription;
  // 현재 리스닝 중인 그룹 ID (디버깅용)
  // ignore: unused_field
  String? _currentGroupId;

  Stream<GeofenceEvent> get eventStream => _eventController.stream;

  // 지오펜스 목록 Stream (UI 업데이트용)
  Stream<List<GeofenceData>> get geofencesStream => _geofencesController.stream;

  bool get isInitialized => _isInitialized;

  int get geofenceCount => _registeredGeofences.length;

  // 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 지오펜스 이벤트 리스너 등록
      bg.BackgroundGeolocation.onGeofence((bg.GeofenceEvent event) {
        handleGeofenceEvent(event);
      });

      // 지오펜스 추가/삭제 이벤트 리스너 등록
      bg.BackgroundGeolocation.onGeofencesChange((
        bg.GeofencesChangeEvent event,
      ) {
        _handleGeofencesChange(event);
      });

      _isInitialized = true;
      debugPrint('[GeofenceManager] 초기화 완료');
    } catch (e) {
      debugPrint('[GeofenceManager] 초기화 실패: $e');
      rethrow;
    }
  }

  // 지오펜스 변경 여부 확인
  bool _hasGeofenceChanged(GeofenceData old, GeofenceData newG) {
    return old.centerLatitude != newG.centerLatitude ||
        old.centerLongitude != newG.centerLongitude ||
        old.radiusMeters != newG.radiusMeters ||
        old.triggerOnEnter != newG.triggerOnEnter ||
        old.triggerOnExit != newG.triggerOnExit ||
        old.isActive != newG.isActive;
  }

  // 보호자용 지오펜스 모두 제거
  Future<void> removeAllGuardianGeofences() async {
    try {
      final guardianGeofenceIds = _registeredGeofences.entries
          .where((entry) => entry.value.type != 'stationary')
          .map((entry) => entry.key)
          .toList();

      for (final geofenceId in guardianGeofenceIds) {
        try {
          await bg.BackgroundGeolocation.removeGeofence(geofenceId);
          _registeredGeofences.remove(geofenceId);
        } catch (e) {
          debugPrint('[GeofenceManager] 지오펜스 제거 실패 ($geofenceId): $e');
        }
      }

      debugPrint('[GeofenceManager] 보호자용 지오펜스 모두 제거 완료');
    } catch (e) {
      debugPrint('[GeofenceManager] removeAllGuardianGeofences 실패: $e');
    }
  }

  // 플러그인에 지오펜스 추가
  Future<void> _addGeofenceToPlugin(GeofenceData geofence) async {
    try {
      if (geofence.shapeType != 'circle' ||
          geofence.centerLatitude == null ||
          geofence.centerLongitude == null ||
          geofence.radiusMeters == null) {
        throw Exception('원형 지오펜스만 지원합니다');
      }

      final bgGeofence = bg.Geofence(
        identifier: geofence.geofenceId,
        radius: geofence.radiusMeters!.toDouble(),
        latitude: geofence.centerLatitude!,
        longitude: geofence.centerLongitude!,
        notifyOnEntry: geofence.triggerOnEnter, // ENTER 이벤트 활성화
        notifyOnExit: geofence.triggerOnExit,
        notifyOnDwell: false, // DWELL 비활성화
        extras: {'name': geofence.name, 'type': geofence.type},
      );

      await bg.BackgroundGeolocation.addGeofence(bgGeofence);
      _registeredGeofences[geofence.geofenceId] = geofence;

      // debugPrint('[GeofenceManager] 지오펜스 플러그인 등록 완료: ${geofence.geofenceId}');
    } catch (e) {
      debugPrint('[GeofenceManager] _addGeofenceToPlugin 실패: $e');
      rethrow;
    }
  }

  // 지오펜스 추가/삭제 이벤트 처리
  // 라이브러리 자동 생성 정지 지오펜스는 더 이상 처리하지 않음
  void _handleGeofencesChange(bg.GeofencesChangeEvent event) async {
    // 라이브러리 자동 생성 정지 지오펜스 처리 로직 제거됨
    // 보호자 지오펜스는 Firebase 리스너를 통해 처리됨
  }

  // 지오펜스 이벤트 검증
  Future<GeofenceValidationResult> _validateGeofenceEvent({
    required GeofenceData geofence,
    required bg.GeofenceEvent event,
    required String eventType,
  }) async {
    // 0. GPS 정확도 검증 (정확도가 너무 낮으면 이벤트 보류)
    final accuracy = event.location.coords.accuracy;
    if (accuracy > 100) {
      return GeofenceValidationResult(
        isValid: false,
        failureReason: 'GPS 정확도 낮음 검증 실패 (${accuracy}m > 100m)',
      );
    }

    // 1. 거리 기반 검증 및 히스테리시스 보정
    final currentLat = event.location.coords.latitude;
    final currentLon = event.location.coords.longitude;
    final geofenceLat = geofence.centerLatitude!;
    final geofenceLon = geofence.centerLongitude!;
    final radius = geofence.radiusMeters!;

    final distance = calculateDistanceInMeters(
      currentLat,
      currentLon,
      geofenceLat,
      geofenceLon,
    );
    
    // 이탈 시 히스테리시스 버퍼 적용 (경계선 부근 GPS 튕김에 의한 반복 이탈 방지)
    const double hysteresisBuffer = 20.0;

    if (eventType == 'enter') {
      // ENTER: distance <= radius + slight buffer considering accuracy (max 10m)
      final effectiveRadius = radius + (accuracy < 10 ? accuracy : 10);
      if (distance > effectiveRadius) {
        return GeofenceValidationResult(
          isValid: false,
          failureReason:
              '거리 기반 검증 실패: 현재 위치(${distance.toStringAsFixed(1)}m)가 지오펜스 보정반경(${effectiveRadius.toStringAsFixed(1)}m) 밖에 있음',
          distance: distance,
        );
      }
    } else {
      // EXIT: distance > radius + hysteresisBuffer
      final effectiveRadius = radius + hysteresisBuffer;
      if (distance <= effectiveRadius) {
        return GeofenceValidationResult(
          isValid: false,
          failureReason:
              '거리 기반 검증 실패: 이탈 보정 반경(${effectiveRadius.toStringAsFixed(1)}m) 안에 위치함 (${distance.toStringAsFixed(1)}m)',
          distance: distance,
        );
      }

      // 2. 실제 진입 기록 확인 (EXIT만)
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentGeofenceId = prefs.getString('last_guardian_geofence_id');

        // 실제로 진입했던 지오펜스가 아니면 exit 무시
        if (currentGeofenceId == null || currentGeofenceId != geofence.geofenceId) {
          return GeofenceValidationResult(
            isValid: false,
            failureReason:
                '실제 진입 기록 없음: 현재 진입한 지오펜스($currentGeofenceId)와 다름',
            distance: distance,
          );
        }

        // 3. 시간 기반 검증 (EXIT만)
        final geofenceEnteredAtStr = prefs.getString(
          'last_guardian_geofence_entered_at',
        );

        if (geofenceEnteredAtStr != null) {
          final geofenceEnteredAt = int.tryParse(geofenceEnteredAtStr);
          if (geofenceEnteredAt != null) {
            final enteredAt = DateTime.fromMillisecondsSinceEpoch(
              geofenceEnteredAt,
            );
            final now = DateTime.now();
            final duration = now.difference(enteredAt);

            // 진입 후 1분 이내 EXIT는 실패 (즉시 진입/이탈 방지)
            if (duration.inSeconds < 60) {
              return GeofenceValidationResult(
                isValid: false,
                failureReason:
                    '시간 기반 검증 실패: 진입 후 ${duration.inSeconds}초 만에 이탈 (최소 1분 필요)',
                distance: distance,
              );
            }

            // 진입 후 24시간 이상 지난 경우는 허용 (오래된 상태 정리)
            // 이 경우는 검증 통과
          }
        }
      } catch (e) {
        debugPrint('[GeofenceManager] 진입 기록 확인 중 오류: $e');
        // 오류 발생 시 검증 통과 (안전한 선택)
      }
    }

    // 모든 검증 통과
    return GeofenceValidationResult(isValid: true, distance: distance);
  }

  // 지오펜스 이벤트 처리 (포어그라운드/헤드리스 공통)
  Future<void> handleGeofenceEvent(bg.GeofenceEvent event) async {
    // 백그라운드 작업 시작 (API 호출이 있으므로 필요)
    int? taskId;
    try {
      taskId = await bg.BackgroundGeolocation.startBackgroundTask();
    } catch (e) {
      debugPrint('[GeofenceManager] startBackgroundTask 실패: $e');
    }

    try {
      // 먼저 _registeredGeofences에서 조회
      var geofence = _registeredGeofences[event.identifier];

      if (geofence == null) {
        debugPrint('[GeofenceManager] 알 수 없는 지오펜스 이벤트: ${event.identifier}');
        return;
      }

      // DWELL 이벤트는 무시 (notifyOnDwell: false로 설정되어 있음)
      if (event.action == 'DWELL') {
        debugPrint('[GeofenceManager] DWELL 이벤트 무시: ${event.identifier}');
        return;
      }

      // 이벤트 타입 파싱 (ENTER, EXIT만)
      String originalEventType = event.action == 'ENTER' ? 'enter' : 'exit';

      // 검증 로직 실행
      final validationResult = await _validateGeofenceEvent(
        geofence: geofence,
        event: event,
        eventType: originalEventType,
      );

      if (!validationResult.isValid) {
        // 검증 실패: 서버 저장만 건너뛰고 return
        debugPrint(
          '[GeofenceManager] 검증 실패 - 서버 저장 안 함: ${validationResult.failureReason}',
        );
        return;
      }

      // timestamp 파싱 (공통)
      DateTime timestamp;
      try {
        final timestampStr = event.location.timestamp.toString();
        timestamp = timestampStr.contains('T') || timestampStr.contains('Z')
            ? DateTime.parse(timestampStr)
            : DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
      } catch (e) {
        timestamp = DateTime.now().toUtc();
      }

      // 로컬 로그 저장 헬퍼 함수
      Future<void> saveLocalLog(
        GeofenceData geofenceData,
        String eventTypeForLog,
      ) async {
        try {
          final logService = LogService();
          await logService.addLog('geofence', {
            'geofenceId': geofenceData.geofenceId,
            'geofenceName': geofenceData.name,
            'geofenceType': geofenceData.type,
            'eventType': eventTypeForLog,
            'latitude': event.location.coords.latitude,
            'longitude': event.location.coords.longitude,
            'timestamp': timestamp.toIso8601String(),
          });
        } catch (e) {
          debugPrint('[GeofenceManager] 로그 저장 실패: $e');
        }
      }

      // 서버 기록 여부 플래그 (ENTER 이벤트 중복 방지용)
      bool shouldRecordToServer = true;

      // ENTER 이벤트 처리
      if (originalEventType == 'enter') {
        debugPrint('[GeofenceManager] ENTER 이벤트');

        // 로컬 로그 저장
        await saveLocalLog(geofence, 'enter');

        // 보호자 지오펜스인 경우 프리퍼런스에 저장 및 즉시 realtime_locations 업데이트
        if (geofence.type != 'stationary') {
          try {
            final prefs = await SharedPreferences.getInstance();
            final currentGeofenceId = prefs.getString(
              'last_guardian_geofence_id',
            );

            // 같은 지오펜스가 아니거나 없을 때만 저장 (중복 방지)
            if (currentGeofenceId != geofence.geofenceId) {
              await prefs.setString(
                'last_guardian_geofence_id',
                geofence.geofenceId,
              );
              await prefs.setString(
                'last_guardian_geofence_entered_at',
                timestamp.millisecondsSinceEpoch.toString(),
              );
              debugPrint(
                '[GeofenceManager] 보호자 지오펜스 진입 정보 저장: ${geofence.geofenceId}',
              );

              // 즉시 realtime_locations 업데이트
              try {
                await LocationService.updateUserLocationRealtime(
                  event.location,
                );
                debugPrint(
                  '[GeofenceManager] realtime_locations 즉시 업데이트 완료 (ENTER)',
                );
              } catch (e) {
                debugPrint('[GeofenceManager] realtime_locations 업데이트 실패: $e');
              }
            } else {
              // 이미 같은 지오펜스에 있으면 서버 기록 건너뛰기
              shouldRecordToServer = false;
              debugPrint(
                '[GeofenceManager] 이미 같은 지오펜스에 있음 - 서버 기록 건너뛰기: ${geofence.geofenceId}',
              );
            }
          } catch (e) {
            debugPrint('[GeofenceManager] 프리퍼런스 저장 실패: $e');
          }
        }
      } else {
        // EXIT 이벤트: 로컬 로그 저장
        await saveLocalLog(geofence, 'exit');

        // 보호자 지오펜스인 경우 프리퍼런스에서 삭제 및 즉시 realtime_locations 업데이트
        if (geofence.type != 'stationary') {
          try {
            final prefs = await SharedPreferences.getInstance();
            final currentGeofenceId = prefs.getString(
              'last_guardian_geofence_id',
            );
            if (currentGeofenceId == geofence.geofenceId) {
              await prefs.remove('last_guardian_geofence_id');
              await prefs.remove('last_guardian_geofence_entered_at');
              debugPrint(
                '[GeofenceManager] 보호자 지오펜스 이탈 정보 삭제: ${geofence.geofenceId}',
              );

              // 즉시 realtime_locations 업데이트 (지오펜스 정보는 null로)
              try {
                await LocationService.updateUserLocationRealtime(
                  event.location,
                );
                debugPrint('[GeofenceManager] realtime_locations 즉시 업데이트 완료 (EXIT)');
              } catch (e) {
                debugPrint('[GeofenceManager] realtime_locations 업데이트 실패: $e');
              }
            } else {
              // currentGeofenceId가 없거나 다른 지오펜스인 경우 서버 기록 건너뛰기
              shouldRecordToServer = false;
              debugPrint(
                '[GeofenceManager] 진입 기록 없음 - 서버 기록 건너뛰기 (EXIT): currentGeofenceId=$currentGeofenceId, geofenceId=${geofence.geofenceId}',
              );
            }
          } catch (e) {
            debugPrint('[GeofenceManager] 프리퍼런스 삭제 실패: $e');
          }
        }
      }

      // ENTER와 EXIT 모두 동일한 서버 저장 로직 사용
      final geofenceEvent = GeofenceEvent(
        geofenceId: geofence.geofenceId,
        geofenceName: geofence.name,
        geofenceType: geofence.type,
        eventType: originalEventType, // 'enter' 또는 'exit'
        latitude: event.location.coords.latitude,
        longitude: event.location.coords.longitude,
        timestamp: timestamp.toUtc(),
      );

      // 간소화된 로그
      debugPrint(
        '[GeofenceManager] 지오펜스 이벤트: ${geofence.name} - $originalEventType',
      );

      // 서버 기록이 필요한 경우에만 저장 (중복 방지)
      if (!shouldRecordToServer) {
        debugPrint(
          '[GeofenceManager] 서버 기록 건너뛰기: ${geofence.name} - $originalEventType',
        );
        return;
      }

      // 서버에 직접 저장 (tb_event_log에 통합)
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        final recorded = await _apiService.recordEvent(
          eventType: 'geofence',
          eventSubtype: geofenceEvent.eventType, // 'enter' 또는 'exit'
          geofenceId: geofenceEvent.geofenceId,
          latitude: geofenceEvent.latitude,
          longitude: geofenceEvent.longitude,
          eventData: {
            'geofence_name': geofence.name,
            'geofence_type': geofence.type,
          },
          occurredAt: geofenceEvent.timestamp,
        );

        if (recorded) {
          // 서버 저장 성공 후에만 eventStream에 발행
          _eventController.add(geofenceEvent);
          debugPrint(
            '[GeofenceManager] 서버 저장 성공: ${geofence.name} - $originalEventType',
          );
        } else {
          debugPrint('[GeofenceManager] 서버 저장 실패, 이벤트 무시');
        }
      } else {
        // 사용자 정보가 없어도 이벤트는 발행 (UI 업데이트용)
        _eventController.add(geofenceEvent);
      }
    } catch (e) {
      debugPrint('[GeofenceManager] _handleGeofenceEvent 실패: $e');
    } finally {
      // 백그라운드 작업 종료
      if (taskId != null) {
        bg.BackgroundGeolocation.stopBackgroundTask(taskId);
      }
    }
  }

  // 지오펜스 초기화 (Firebase Realtime Database 리스너 시작)
  Future<void> initializeGeofences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupId =
          prefs.getString('group_id') ?? '00000000-0000-0000-0000-000000000002';

      // GeofenceManager 초기화 (이미 초기화되어 있으면 스킵)
      if (!_isInitialized) {
        await initialize();
      }

      // Firebase에서 현재 등록된 지오펜스를 먼저 로드하여 _registeredGeofences에 채우기
      // (리스너 시작 전에 로드하여 중복 등록 방지)
      await _loadCurrentGeofencesFromFirebase(groupId);

      // Firebase Realtime Database 리스너 시작
      // onChildAdded가 기존 데이터도 자동으로 처리하지만, 이미 _registeredGeofences에 있으면 스킵됨
      await _startFirebaseListeners(groupId);

      debugPrint('[GeofenceManager] 지오펜스 초기화 완료 (Firebase 리스너 시작)');
    } catch (e) {
      debugPrint('[GeofenceManager] 지오펜스 초기화 실패: $e');
      rethrow;
    }
  }

  // Firebase Realtime Database 리스너 시작
  Future<void> _startFirebaseListeners(String groupId) async {
    try {
      // 기존 리스너 해제
      await _stopFirebaseListeners();

      _currentGroupId = groupId;

      // 지오펜스 추가 감지 (기존 데이터와 새 데이터 모두 처리)
      _firebaseAddedSubscription = _firebaseGeofenceService
          .listenGeofenceAdded(groupId)
          .listen(
            (geofence) async {
              // 이미 등록된 지오펜스는 스킵 (중복 방지)
              if (_registeredGeofences.containsKey(geofence.geofenceId)) {
                debugPrint('[GeofenceManager] 이미 등록된 지오펜스 - 스킵: ${geofence.name}');
                return;
              }

              await _addGeofenceToPlugin(geofence);
              _emitGeofencesUpdate();
              debugPrint('[GeofenceManager] Firebase에서 지오펜스 추가: ${geofence.name}');
            },
            onError: (e) {
              debugPrint('[GeofenceManager] Firebase 지오펜스 추가 리스너 에러: $e');
            },
          );

      // 지오펜스 변경 감지
      _firebaseChangedSubscription = _firebaseGeofenceService
          .listenGeofenceChanged(groupId)
          .listen(
            (geofence) async {
              final existing = _registeredGeofences[geofence.geofenceId];
              if (existing != null) {
                // 변경 여부 확인
                if (_hasGeofenceChanged(existing, geofence)) {
                  // 변경된 경우에만 업데이트
                  await bg.BackgroundGeolocation.removeGeofence(
                    geofence.geofenceId,
                  );
                  _registeredGeofences.remove(geofence.geofenceId);
                  await _addGeofenceToPlugin(geofence);
                  _emitGeofencesUpdate();
                  debugPrint(
                    '[GeofenceManager] Firebase에서 지오펜스 업데이트: ${geofence.name}',
                  );
                } else {
                  // 값은 같지만 UI 업데이트는 필요할 수 있음 (isActive 등)
                  _emitGeofencesUpdate();
                  debugPrint(
                    '[GeofenceManager] 지오펜스 변경 없음 (UI만 업데이트): ${geofence.name}',
                  );
                }
              } else {
                // 등록되지 않은 경우 추가
                await _addGeofenceToPlugin(geofence);
                _emitGeofencesUpdate();
                debugPrint(
                  '[GeofenceManager] Firebase에서 지오펜스 추가 (변경 이벤트): ${geofence.name}',
                );
              }
            },
            onError: (e) {
              debugPrint('[GeofenceManager] Firebase 지오펜스 변경 리스너 에러: $e');
            },
          );

      // 지오펜스 삭제 감지
      _firebaseRemovedSubscription = _firebaseGeofenceService
          .listenGeofenceRemoved(groupId)
          .listen(
            (geofenceId) async {
              try {
                await bg.BackgroundGeolocation.removeGeofence(geofenceId);
                _registeredGeofences.remove(geofenceId);

                // 프리퍼런스에서 지오펜스 정보 삭제 (보호자 지오펜스인 경우)
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final currentGeofenceId = prefs.getString(
                    'last_guardian_geofence_id',
                  );
                  if (currentGeofenceId == geofenceId) {
                    await prefs.remove('last_guardian_geofence_id');
                    await prefs.remove('last_guardian_geofence_entered_at');
                    debugPrint('[GeofenceManager] 프리퍼런스에서 지오펜스 정보 삭제: $geofenceId');
                  }
                } catch (e) {
                  debugPrint('[GeofenceManager] 프리퍼런스 삭제 실패: $e');
                }

                _emitGeofencesUpdate();
                debugPrint('[GeofenceManager] Firebase에서 지오펜스 삭제: $geofenceId');
              } catch (e) {
                debugPrint('[GeofenceManager] 지오펜스 삭제 실패 ($geofenceId): $e');
              }
            },
            onError: (e) {
              debugPrint('[GeofenceManager] Firebase 지오펜스 삭제 리스너 에러: $e');
            },
          );

      debugPrint('[GeofenceManager] Firebase 리스너 시작 완료: $groupId');
    } catch (e) {
      debugPrint('[GeofenceManager] Firebase 리스너 시작 실패: $e');
    }
  }

  // Firebase 리스너 중지
  Future<void> _stopFirebaseListeners() async {
    // Stream 구독 정리 (MissingPluginException 방지)
    try {
      await _firebaseAddedSubscription?.cancel();
    } catch (e) {
      // MissingPluginException 등 네이티브 플러그인 관련 오류는 무시
      debugPrint('[GeofenceManager] Firebase Added Stream 정리 중 오류 (무시): $e');
    }
    
    try {
      await _firebaseChangedSubscription?.cancel();
    } catch (e) {
      debugPrint('[GeofenceManager] Firebase Changed Stream 정리 중 오류 (무시): $e');
    }
    
    try {
      await _firebaseRemovedSubscription?.cancel();
    } catch (e) {
      debugPrint('[GeofenceManager] Firebase Removed Stream 정리 중 오류 (무시): $e');
    }
    
    try {
      await _firebaseAllSubscription?.cancel();
    } catch (e) {
      debugPrint('[GeofenceManager] Firebase All Stream 정리 중 오류 (무시): $e');
    }
    
    _firebaseAddedSubscription = null;
    _firebaseChangedSubscription = null;
    _firebaseRemovedSubscription = null;
    _firebaseAllSubscription = null;
    _currentGroupId = null;
  }

  // 지오펜스 목록 업데이트를 Stream에 발행
  void _emitGeofencesUpdate() {
    final allGeofences = _registeredGeofences.values.toList();
    debugPrint('[GeofenceManager] Stream 발행: ${allGeofences.length}개 지오펜스');
    for (final geofence in allGeofences) {
      debugPrint('[GeofenceManager]   - ${geofence.name} (${geofence.geofenceId}): type=${geofence.type}, active=${geofence.isActive}, shape=${geofence.shapeType}, center=(${geofence.centerLatitude}, ${geofence.centerLongitude}), radius=${geofence.radiusMeters}');
    }
    if (!_geofencesController.isClosed) {
      _geofencesController.add(allGeofences);
      debugPrint('[GeofenceManager] Stream 발행 완료');
    } else {
      debugPrint('[GeofenceManager] Stream이 닫혀있어 발행 실패');
    }
  }

  // Firebase에서 현재 등록된 지오펜스를 로드하여 _registeredGeofences에 채우기
  // 플러그인에도 등록하여 이벤트가 발생하도록 함
  Future<void> _loadCurrentGeofencesFromFirebase(String groupId) async {
    try {
      debugPrint('[GeofenceManager] Firebase에서 현재 지오펜스 로드 시작: $groupId');

      // listenAllGeofences를 사용하여 한 번만 값을 가져오기
      final geofencesMap = await _firebaseGeofenceService
          .listenAllGeofences(groupId)
          .first
          .timeout(const Duration(seconds: 10));

      int loadedCount = 0;
      for (final geofence in geofencesMap.values) {
        // _registeredGeofences에 추가하고 플러그인에도 등록
        // 이미 플러그인에 등록되어 있을 수 있으므로 try-catch로 처리
        try {
          await _addGeofenceToPlugin(geofence);
          loadedCount++;
          debugPrint(
            '[GeofenceManager] 현재 지오펜스 로드 및 플러그인 등록: ${geofence.name} (${geofence.geofenceId})',
          );
        } catch (e) {
          // 이미 등록되어 있거나 다른 오류인 경우에도 _registeredGeofences에는 추가
          _registeredGeofences[geofence.geofenceId] = geofence;
          debugPrint(
            '[GeofenceManager] 현재 지오펜스 로드 (플러그인 등록 실패, 이미 등록되었을 수 있음): ${geofence.name} (${geofence.geofenceId}) - $e',
          );
        }
      }

      debugPrint('[GeofenceManager] Firebase에서 현재 지오펜스 로드 완료: $loadedCount개');
      
      // 초기 로드 완료 후 Stream에 발행 (UI 업데이트)
      _emitGeofencesUpdate();
      debugPrint('[GeofenceManager] 초기 로드된 지오펜스 Stream 발행 완료');
    } catch (e) {
      debugPrint('[GeofenceManager] Firebase에서 현재 지오펜스 로드 실패: $e');
      // 실패해도 계속 진행 (리스너가 처리할 것)
    }
  }

  // 지오펜스 새로고침 (리스너가 자동으로 처리하므로 별도 작업 불필요)
  Future<void> refreshGeofences() async {
    try {
      debugPrint('[GeofenceManager] 지오펜스 새로고침 - Firebase 리스너가 자동으로 처리합니다');
      // 리스너가 이미 켜져 있으면 자동으로 동기화됨
      // 필요시 UI 업데이트만 발행
      _emitGeofencesUpdate();
    } catch (e) {
      debugPrint('[GeofenceManager] 지오펜스 새로고침 실패: $e');
      rethrow;
    }
  }

  // 지오펜스 데이터 조회 (UI 표시용) - 현재 등록된 지오펜스 반환
  Future<List<GeofenceData>> getGeofencesForDisplay() async {
    try {
      // 현재 등록된 모든 지오펜스 반환
      final allGeofences = _registeredGeofences.values.toList();
      return allGeofences;
    } catch (e) {
      debugPrint('[GeofenceManager] getGeofencesForDisplay 실패: $e');
      return [];
    }
  }

  // 정리
  void dispose() {
    _stopFirebaseListeners();
    _eventController.close();
    _geofencesController.close();
  }
}
