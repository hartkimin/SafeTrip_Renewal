import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/location_config.dart';
import '../utils/map_utils.dart' as map_utils;
import '../utils/map_utils.dart';
import 'api_service.dart';

/// 개별 사용자 모드에서 세션 경로(폴리라인) 관리 및 렌더링 데이터 생성
class SessionPathManager {
  // 세션 위치 데이터 관리
  List<Map<String, dynamic>> _locations = [];
  String? _sessionId;
  DateTime? _lastLoadedTime;

  // Getters
  List<Map<String, dynamic>> get locations => _locations;
  String? get sessionId => _sessionId;
  DateTime? get lastLoadedTime => _lastLoadedTime;
  bool get hasData => _locations.isNotEmpty && _sessionId != null;

  /// 전체 세션 데이터 로드
  Future<void> loadFullSessionData(String userId, String sessionId) async {
    try {
      debugPrint(
        '[SessionPathManager] 전체 세션 데이터 로드 시작 - sessionId: $sessionId',
      );
      final apiService = ApiService();

      // 세션의 전체 위치 데이터 가져오기
      final allLocations = await apiService.getLocationHistory(
        userId,
        limit: 1000,
      );

      debugPrint(
        '[SessionPathManager] 전체 위치 데이터 가져옴 - 총 ${allLocations.length}개',
      );

      // 해당 세션 ID의 위치만 필터링
      final sessionLocations = allLocations
          .where((loc) => loc['movement_session_id'] == sessionId)
          .toList();

      debugPrint(
        '[SessionPathManager] 세션 필터링 완료 - 세션 위치 ${sessionLocations.length}개',
      );

      if (sessionLocations.isEmpty) {
        debugPrint('[SessionPathManager] 세션 위치 데이터 없음');
        return;
      }

      // 시간순 정렬 (null-safe)
      sessionLocations.removeWhere((loc) => loc['recorded_at'] == null);
      sessionLocations.sort((a, b) {
        final aTime = a['recorded_at'] as String? ?? '';
        final bTime = b['recorded_at'] as String? ?? '';
        return aTime.compareTo(bTime);
      });

      // 메모리에 저장
      _locations = sessionLocations;
      _sessionId = sessionId;

      // 가장 최신 위치의 시간 저장
      final newestTimeStr = sessionLocations.last['recorded_at'] as String?;
      if (newestTimeStr != null) {
        try {
          _lastLoadedTime = DateTime.parse(newestTimeStr);
          debugPrint(
            '[SessionPathManager] 전체 세션 데이터 로드 완료 - 위치 ${sessionLocations.length}개, 마지막 시간: $newestTimeStr',
          );
        } catch (e) {
          debugPrint('[SessionPathManager] 시간 파싱 실패: $e');
        }
      }
    } catch (e) {
      debugPrint('[SessionPathManager] 전체 세션 데이터 로드 실패: $e');
    }
  }

  /// 최신 로그 추가 및 필터링
  /// 반환값: 새 위치가 추가되었는지 여부
  Future<bool> updateWithLatestLogs(
    List<Map<String, dynamic>> latestLogs,
  ) async {
    if (_sessionId == null) return false;

    try {
      final beforeCount = _locations.length;

      if (latestLogs.isEmpty) {
        return false;
      }

      // 같은 세션 ID이고, 마지막 로드 시간 이후의 로그만 필터링
      final newLocations = <Map<String, dynamic>>[];
      int skippedSessionMismatch = 0;
      int skippedTimeBefore = 0;

      for (final log in latestLogs) {
        final sessionId = log['movement_session_id'] as String?;
        final recordedAtStr = log['recorded_at'] as String?;

        if (sessionId != _sessionId) {
          skippedSessionMismatch++;
          continue;
        }

        if (recordedAtStr != null && _lastLoadedTime != null) {
          try {
            final recordedAt = DateTime.parse(recordedAtStr);
            // 마지막 로드 시간 이후의 로그만 추가
            if (!recordedAt.isBefore(_lastLoadedTime!)) {
              newLocations.add(log);
            } else {
              skippedTimeBefore++;
            }
          } catch (e) {
            // 시간 파싱 실패는 조용히 스킵
          }
        } else if (_lastLoadedTime == null) {
          // 처음 로드하는 경우
          newLocations.add(log);
        }
      }

      // 필터링 결과 로그
      if (newLocations.isEmpty &&
          (skippedSessionMismatch > 0 || skippedTimeBefore > 0)) {
        debugPrint(
          '[SessionPathManager] 필터링 결과 - 세션 불일치: $skippedSessionMismatch개, 시간 이전: $skippedTimeBefore개, 마지막 로드 시간: $_lastLoadedTime',
        );
      }

      final afterCount = _locations.length;

      if (newLocations.isNotEmpty) {
        // 시간순 정렬 (null-safe)
        newLocations.removeWhere((loc) => loc['recorded_at'] == null);
        newLocations.sort((a, b) {
          final aTime = a['recorded_at'] as String? ?? '';
          final bTime = b['recorded_at'] as String? ?? '';
          return aTime.compareTo(bTime);
        });

        // 메모리에 추가
        _locations.addAll(newLocations);

        // 다시 시간순 정렬 (전체, null-safe)
        _locations.removeWhere((loc) => loc['recorded_at'] == null);
        _locations.sort((a, b) {
          final aTime = a['recorded_at'] as String? ?? '';
          final bTime = b['recorded_at'] as String? ?? '';
          return aTime.compareTo(bTime);
        });

        // 실제로 추가된 로그의 최신 시간으로 _lastLoadedTime 업데이트
        DateTime? latestAddedTime;
        for (final log in newLocations) {
          final recordedAtStr = log['recorded_at'] as String?;
          if (recordedAtStr != null) {
            try {
              final recordedAt = DateTime.parse(recordedAtStr);
              if (latestAddedTime == null ||
                  recordedAt.isAfter(latestAddedTime)) {
                latestAddedTime = recordedAt;
              }
            } catch (e) {
              // 시간 파싱 실패는 조용히 스킵
            }
          }
        }
        if (latestAddedTime != null) {
          _lastLoadedTime = latestAddedTime;
        }

        final finalCount = _locations.length;
        debugPrint(
          '[SessionPathManager] DB: ${latestLogs.length}개 → 추가: ${newLocations.length}개 ($beforeCount개 → $finalCount개)',
        );
        return true; // 새 위치 추가됨
      } else {
        debugPrint(
          '[SessionPathManager] DB: ${latestLogs.length}개 → 추가: 0개 ($beforeCount개 → $afterCount개)',
        );
        return false; // 새 위치 없음
      }
    } catch (e) {
      debugPrint('[SessionPathManager] 최신 로그 업데이트 실패: $e');
      return false;
    }
  }

  /// 경로 렌더링 데이터 생성 (마커 + 폴리라인)
  Future<PathRenderData> createPathRenderData({
    required String userId,
    required String sessionId,
    required bool isOngoing,
    required Function(Map<String, dynamic>, {bool isStart}) onMarkerTap,
    List<Map<String, dynamic>>? locations,
    int? sessionNumber,
    Color? sessionColor,
    double? zoomLevel,
  }) async {
    // locations가 제공되면 사용, 아니면 내부 _locations 사용
    final sourceLocations = locations ?? _locations;

    // recorded_at이 null인 항목 필터링 및 정렬
    final validLocations = sourceLocations
        .where((loc) => loc['recorded_at'] != null)
        .toList();

    if (validLocations.isEmpty) {
      debugPrint('[SessionPathManager] recorded_at이 있는 위치 없음');
      return PathRenderData(markers: [], polylines: [], circles: []);
    }

    validLocations.sort((a, b) {
      final aTime = a['recorded_at'] as String? ?? '';
      final bTime = b['recorded_at'] as String? ?? '';
      return aTime.compareTo(bTime);
    });

    final rawPoints = validLocations.map((loc) {
      final lat = loc['latitude'];
      final lng = loc['longitude'];

      final latValue = map_utils.parseCoordinate(lat);
      final lngValue = map_utils.parseCoordinate(lng);

      return LatLng(latValue, lngValue);
    }).toList();

    final points = rawPoints;
    final startMarker = points.isNotEmpty ? points.first : null;
    final endMarker = points.isNotEmpty ? points.last : null;

    final newMarkers = <Marker>[];
    final newPolylines = <Polyline>[];
    final newCircles = <CircleMarker>[];

    if (points.isNotEmpty) {
      final startLocationData = validLocations.first;
      final endLocationData = validLocations.last;

      // 시작 마커 생성
      if (startMarker != null) {
        Widget startIcon;

        if (sessionNumber != null && sessionColor != null) {
          // 숫자 마커 (전체 보기 모드)
          startIcon = await createNumberMarker(sessionNumber, sessionColor);

          newMarkers.add(
            Marker(
              key: ValueKey<String>('${sessionId}_start'),
              point: startMarker,
              width: 20.0,
              height: 20.0,
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  onMarkerTap(startLocationData, isStart: true);
                },
                child: startIcon,
              ),
            ),
          );
        } else {
          // 텍스트 마커 (일반 세션 선택 시) - 원형
          startIcon = await createTextMarker('시작', null);

          newMarkers.add(
            Marker(
              key: const ValueKey<String>('session_start'),
              point: startMarker,
              width: 20.0,
              height: 20.0,
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  onMarkerTap(startLocationData, isStart: true);
                },
                child: startIcon,
              ),
            ),
          );
        }
      }

      // 종료 마커 생성 (전체 보기 모드가 아니고 완료된 세션일 때만)
      if (sessionNumber == null &&
          sessionColor == null &&
          endMarker != null &&
          endMarker != startMarker &&
          !isOngoing) {
        final endIcon = await createTextMarker('종료', null);
        newMarkers.add(
          Marker(
            key: const ValueKey<String>('session_end'),
            point: endMarker,
            width: 20.0,
            height: 20.0,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                onMarkerTap(endLocationData, isStart: false);
              },
              child: endIcon,
            ),
          ),
        );
      }

      // 폴리라인 생성
      if (points.length > 1) {
        debugPrint(
          '[SessionPathManager] 폴리라인 생성 시작 - points: ${points.length}개, sessionId: $sessionId',
        );
        if (sessionColor != null) {
          // 세션별 색상 폴리라인 (전체 보기 모드) - flutter_polyline_points로 화살표 폴리라인 생성
          final arrowPolyline = _createArrowPolyline(
            points,
            sessionColor,
            sessionId,
            zoomLevel: zoomLevel,
          );
          newPolylines.add(arrowPolyline);

          // 화살표 마커 추가 (5km 간격 고정)
          const double intervalMeters = 5000.0; // 5km 간격
          final arrows = await createArrowMarkers(
            points,
            sessionColor,
            sessionId,
            intervalMeters: intervalMeters,
          );
          newMarkers.addAll(arrows);

          // 완료된 세션의 종료 위치에 원 그리기 (보호자 지오펜스 스타일)
          if (!isOngoing && endMarker != null && endMarker != startMarker) {
            newCircles.add(
              CircleMarker(
                point: endMarker,
                radius: LocationConfig.stationaryRadius,
                color: Colors.blue.withValues(alpha: 0.15), // 보호자 지오펜스 스타일
                useRadiusInMeter: true, // 미터 단위로 반지름 사용
              ),
            );
          }
        } else {
          // 속도 기반 그라데이션 폴리라인 (일반 세션 선택 시)
          final speedPolylines = createSpeedGradientPolylines(
            points,
            validLocations,
            sessionId,
          );
          newPolylines.addAll(speedPolylines);
        }
      }

      // 이동 중일 때는 사용자 마커는 screen_main에서 프로필 사진과 함께 추가됨
      // (이동중 마커 제거)
    }

    return PathRenderData(
      markers: newMarkers,
      polylines: newPolylines,
      circles: newCircles,
    );
  }

  /// 속도에 따른 그라데이션 폴리라인 생성
  List<Polyline> createSpeedGradientPolylines(
    List<LatLng> points,
    List<Map<String, dynamic>> locations,
    String sessionId,
  ) {
    if (points.length < 2 || locations.isEmpty) {
      return [];
    }

    final polylines = <Polyline>[];
    final times = <DateTime?>[];

    for (final loc in locations) {
      try {
        final timeStr = loc['recorded_at'] as String?;
        if (timeStr != null) {
          times.add(DateTime.parse(timeStr));
        } else {
          times.add(null);
        }
      } catch (e) {
        times.add(null);
      }
    }

    final speeds = <double>[];
    for (int i = 0; i < locations.length; i++) {
      double speedKmh = 0.0;

      final speed = locations[i]['speed'];
      if (speed != null) {
        final speedValue = speed is num
            ? speed.toDouble()
            : double.tryParse(speed.toString()) ?? 0.0;
        if (speedValue > 0) {
          speedKmh = speedValue * 3.6;
        }
      }

      if (speedKmh == 0 &&
          i > 0 &&
          i < times.length &&
          times[i] != null &&
          times[i - 1] != null) {
        final timeDiff = times[i]!.difference(times[i - 1]!).inSeconds;
        if (timeDiff > 0) {
          final lat1Value = locations[i - 1]['latitude'];
          final lng1Value = locations[i - 1]['longitude'];
          final lat2Value = locations[i]['latitude'];
          final lng2Value = locations[i]['longitude'];

          final lat1 = lat1Value is num
              ? lat1Value.toDouble()
              : double.tryParse(lat1Value.toString()) ?? 0.0;
          final lng1 = lng1Value is num
              ? lng1Value.toDouble()
              : double.tryParse(lng1Value.toString()) ?? 0.0;
          final lat2 = lat2Value is num
              ? lat2Value.toDouble()
              : double.tryParse(lat2Value.toString()) ?? 0.0;
          final lng2 = lng2Value is num
              ? lng2Value.toDouble()
              : double.tryParse(lng2Value.toString()) ?? 0.0;

          final distanceKm =
              calculateDistanceInMeters(lat1, lng1, lat2, lng2) /
              1000.0; // 미터를 km로 변환
          speedKmh = (distanceKm / timeDiff) * 3600;
        }
      }

      speeds.add(speedKmh);
    }

    List<LatLng> currentSegment = [points[0]];
    Color? currentColor;
    const int averageWindowSize = 5;

    for (int i = 1; i < points.length; i++) {
      final locationIndex = ((i / (points.length - 1)) * (locations.length - 1))
          .round();
      final clampedIndex = math.min(locationIndex, speeds.length - 1);

      double avgSpeedKmh = 0.0;
      int validSpeedCount = 0;
      final startIdx = math.max(0, clampedIndex - averageWindowSize ~/ 2);
      final endIdx = math.min(
        speeds.length - 1,
        clampedIndex + averageWindowSize ~/ 2,
      );

      for (int j = startIdx; j <= endIdx; j++) {
        if (speeds[j] > 0) {
          avgSpeedKmh += speeds[j];
          validSpeedCount++;
        }
      }

      if (validSpeedCount > 0) {
        avgSpeedKmh = avgSpeedKmh / validSpeedCount;
      } else {
        avgSpeedKmh = speeds[clampedIndex];
      }

      final segmentColor = getSpeedColor(avgSpeedKmh);

      if (currentColor != null && currentColor != segmentColor) {
        if (currentSegment.length > 1) {
          polylines.add(
            Polyline(
              points: currentSegment,
              color: currentColor.withValues(alpha: 0.7),
              strokeWidth: 2,
            ),
          );
        }
        currentSegment = [currentSegment.last, points[i]];
      } else {
        currentSegment.add(points[i]);
      }

      currentColor = segmentColor;
    }

    if (currentSegment.length > 1 && currentColor != null) {
      polylines.add(
        Polyline(
          points: currentSegment,
          color: currentColor.withValues(alpha: 0.7),
          strokeWidth: 2,
        ),
      );
    }

    if (polylines.isEmpty && points.length > 1) {
      polylines.add(
        Polyline(
          points: points,
          color: Colors.blue.withValues(alpha: 0.7),
          strokeWidth: 2,
        ),
      );
    }

    return polylines;
  }

  /// 텍스트 마커 생성 (시작/종료 마커용) - 원형
  Future<Widget> createTextMarker(String title, String? time) async {
    // 원형 마커 설정
    const double circleSize = 20.0;
    const tealColor = Color(0xFF00A2BD); // Primary teal
    const strokeWidth = 2.0;
    const double scale = 2.0; // 해상도 개선을 위한 스케일

    // 2배 크기로 Canvas 생성
    const scaledSize = Size(circleSize * scale, circleSize * scale);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 텍스트 스타일 (2배 크기)
    const textStyle = TextStyle(
      color: tealColor,
      fontSize: 12 * scale,
      fontWeight: FontWeight.bold,
    );

    // 시작 → S, 종료 → E
    final displayText = title == '시작'
        ? 'S'
        : title == '종료'
        ? 'E'
        : title;

    final textPainter = TextPainter(
      text: TextSpan(text: displayText, style: textStyle),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    // 2배 크기로 계산
    const scaledRadius = (circleSize * scale / 2) - (strokeWidth * scale / 2);
    const scaledCenter = Offset(circleSize * scale / 2, circleSize * scale / 2);

    // 배경 (흰색)
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(scaledCenter, scaledRadius, bgPaint);

    // 테두리 (Primary teal, 굵기 2)
    final borderPaint = Paint()
      ..color = tealColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale
      ..isAntiAlias = true;

    canvas.drawCircle(scaledCenter, scaledRadius, borderPaint);

    // 텍스트를 중앙에 배치
    textPainter.paint(
      canvas,
      Offset(
        (scaledSize.width - textPainter.width) / 2,
        (scaledSize.height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      scaledSize.width.toInt(),
      scaledSize.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();

    return Image.memory(
      uint8List,
      width: circleSize,
      height: circleSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

  Future<Widget> createNumberMarker(int number, Color color) async {
    // 원형 마커 설정
    const double circleSize = 20.0; // 원 크기
    const strokeWidth = 2.0;
    const double scale = 2.0; // 해상도 개선을 위한 스케일

    // 2배 크기로 Canvas 생성
    const scaledSize = Size(circleSize * scale, circleSize * scale);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 숫자 스타일 (2배 크기) - 세션 색상 사용
    final numberStyle = TextStyle(
      color: color,
      fontSize: 12 * scale,
      fontWeight: FontWeight.bold,
    );

    final numberPainter = TextPainter(
      text: TextSpan(text: number.toString(), style: numberStyle),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    numberPainter.layout();

    // 2배 크기로 계산
    const scaledRadius = (circleSize * scale / 2) - (strokeWidth * scale / 2);
    const scaledCenter = Offset(circleSize * scale / 2, circleSize * scale / 2);

    // 배경 (흰색)
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(scaledCenter, scaledRadius, bgPaint);

    // 테두리 (세션 색상, 굵기 2)
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale
      ..isAntiAlias = true;

    canvas.drawCircle(scaledCenter, scaledRadius, borderPaint);

    // 숫자를 중앙에 배치
    numberPainter.paint(
      canvas,
      Offset(
        (scaledSize.width - numberPainter.width) / 2,
        (scaledSize.height - numberPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      scaledSize.width.toInt(),
      scaledSize.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();

    return Image.memory(
      uint8List,
      width: circleSize,
      height: circleSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

  /// 속도에 따른 색상 반환
  Color getSpeedColor(double speedKmh) {
    if (speedKmh < 10) {
      return Colors.green;
    } else if (speedKmh < 30) {
      return Colors.yellow.shade700;
    } else if (speedKmh < 60) {
      return Colors.orange;
    } else if (speedKmh < 90) {
      return Colors.red;
    } else {
      return Colors.purple;
    }
  }

  /// 화살표 마커 생성 (방향 표시용)
  Future<Widget> createArrowMarker(double rotation, Color color) async {
    const double arrowSize = 16.0;
    const double arrowWidth = 8.0;
    const double arrowHeight = 10.0;
    const double scale = 2.0; // 해상도 개선을 위한 스케일

    // 2배 크기로 Canvas 생성
    const scaledSize = Size(arrowSize * scale, arrowSize * scale);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const scaledCenter = Offset(arrowSize * scale / 2, arrowSize * scale / 2);

    // 회전 적용
    canvas.save();
    canvas.translate(scaledCenter.dx, scaledCenter.dy);
    canvas.rotate(rotation);
    canvas.translate(-scaledCenter.dx, -scaledCenter.dy);

    // 화살표 경로 (삼각형) - 명확한 좌표 (2배 크기)
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 좌표 계산 (2배 크기)
    const scaledTopY = (arrowSize * scale - arrowHeight * scale) / 2;
    const scaledBottomY = (arrowSize * scale + arrowHeight * scale) / 2;
    const scaledLeftX = arrowSize * scale / 2 - arrowWidth * scale / 2;
    const scaledRightX = arrowSize * scale / 2 + arrowWidth * scale / 2;
    const scaledCenterX = arrowSize * scale / 2;

    final path = ui.Path();
    // 위쪽을 가리키는 삼각형
    path.moveTo(scaledCenterX, scaledTopY); // 꼭지점
    path.lineTo(scaledLeftX, scaledBottomY); // 왼쪽 하단
    path.lineTo(scaledRightX, scaledBottomY); // 오른쪽 하단
    path.close();

    canvas.drawPath(path, arrowPaint);
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      scaledSize.width.toInt(),
      scaledSize.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();

    return Image.memory(
      uint8List,
      width: arrowSize,
      height: arrowSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

  /// 폴리라인에 화살표 마커 배치 (일정 간격)
  Future<List<Marker>> createArrowMarkers(
    List<LatLng> points,
    Color color,
    String sessionId, {
    double intervalMeters = 5000.0, // 5km 간격
  }) async {
    if (points.length < 2) return [];

    final arrows = <Marker>[];
    double accumulatedDistance = 0.0;
    int arrowIndex = 0;

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      final segmentDistance = calculateDistanceInMeters(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );

      accumulatedDistance += segmentDistance;

      // 2km마다 화살표 추가
      if (accumulatedDistance >= intervalMeters) {
        // 방향 계산 (라디안)
        final angle = math.atan2(
          curr.longitude - prev.longitude,
          curr.latitude - prev.latitude,
        );

        final arrowIcon = await createArrowMarker(angle, color);

        arrows.add(
          Marker(
            key: ValueKey<String>('${sessionId}_arrow_$arrowIndex'),
            point: curr,
            width: 16.0,
            height: 16.0,
            alignment: Alignment.center,
            child: arrowIcon,
          ),
        );

        arrowIndex++;
        accumulatedDistance = 0.0; // 거리 리셋
      }
    }

    return arrows;
  }

  /// flutter_polyline_points를 사용하여 화살표가 있는 폴리라인 생성
  Polyline _createArrowPolyline(
    List<LatLng> points,
    Color color,
    String sessionId, {
    double? zoomLevel,
  }) {
    // flutter_polyline_points는 주로 Google Directions API를 사용하여 경로를 계산하는 패키지입니다.
    // 하지만 여기서는 기존 points를 사용하여 화살표가 있는 폴리라인을 생성합니다.
    // 화살표는 기존 createArrowMarkers 방식을 사용하되, 폴리라인 자체는 일반 Polyline으로 생성합니다.
    // 실제로는 flutter_polyline_points의 기능을 활용하여 더 부드러운 경로를 생성할 수 있습니다.

    // flutter_polyline_points를 사용하여 경로를 부드럽게 만들 수 있습니다.
    // 하지만 현재는 기존 points를 그대로 사용합니다.
    // 향후 필요시 PolylinePoints를 사용하여 경로를 최적화할 수 있습니다.

    return Polyline(
      points: points,
      color: color.withValues(alpha: 0.7), // 투명도 70%
      strokeWidth: 2,
      // 화살표는 별도 마커로 추가되므로 폴리라인 자체는 일반 선으로 생성
    );
  }

  /// 초기화
  void clear() {
    _locations.clear();
    _sessionId = null;
    _lastLoadedTime = null;
  }
}

/// 경로 렌더링 데이터
class PathRenderData { // 세션 완료 위치 원 (전체 보기 모드)

  PathRenderData({
    required this.markers,
    required this.polylines,
    this.circles = const [],
  });
  final List<Marker> markers;
  final List<Polyline> polylines;
  final List<CircleMarker> circles;
}
