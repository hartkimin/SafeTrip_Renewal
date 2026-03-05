import 'dart:math' as math;
import 'package:intl/intl.dart';

/// 좌표 값을 double로 변환
double parseCoordinate(dynamic value, {double defaultValue = 0.0}) {
  if (value is num) {
    return value.toDouble();
  } else if (value is String) {
    return double.tryParse(value) ?? defaultValue;
  } else {
    return double.tryParse(value.toString()) ?? defaultValue;
  }
}

/// 좌표 값을 nullable double로 변환
double? parseCoordinateNullable(dynamic value) {
  if (value is num) {
    return value.toDouble();
  } else if (value is String) {
    return double.tryParse(value);
  } else {
    return double.tryParse(value.toString());
  }
}

/// UTC 시간을 현지 시간으로 변환하여 포맷팅
String? formatLocalTime(DateTime? dateTime, {String format = 'MM/dd HH:mm'}) {
  if (dateTime == null) return null;
  try {
    // UTC 시간을 현지 시간으로 변환
    final localTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return DateFormat(format).format(localTime);
  } catch (e) {
    return null;
  }
}

/// 문자열 시간을 파싱하여 현지 시간으로 포맷팅
String? formatLocalTimeFromString(
  String? timeString, {
  String format = 'MM/dd HH:mm',
}) {
  if (timeString == null || timeString.isEmpty) return null;
  try {
    final parsed = DateTime.parse(timeString);
    // UTC 시간을 현지 시간으로 변환
    final localTime = parsed.isUtc ? parsed.toLocal() : parsed;
    return DateFormat(format).format(localTime);
  } catch (e) {
    return null;
  }
}

/// 시간 문자열에서 날짜(DateTime) 추출
/// 다양한 형식 지원: 'Z'로 끝나는 UTC, 타임존 포함, 또는 일반 형식
DateTime? parseDateTimeFromString(String? timeString) {
  if (timeString == null || timeString.isEmpty) return null;
  try {
    if (timeString.endsWith('Z')) {
      return DateTime.parse(timeString);
    } else if (timeString.contains('+') || timeString.contains('-')) {
      return DateTime.parse(timeString);
    } else {
      return DateTime.parse('${timeString}Z');
    }
  } catch (e) {
    return null;
  }
}

/// 시간 문자열에서 날짜 문자열(YYYY-MM-DD) 추출
String? extractDateStringFromTime(String? timeString) {
  final dateTime = parseDateTimeFromString(timeString);
  if (dateTime == null) return null;
  return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
}

/// 두 좌표 간 거리 계산 (Haversine formula, 미터 단위)
/// 헤드리스 모드에서도 사용 가능 (dart:math만 사용, Flutter 위젯 의존성 없음)
double calculateDistanceInMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const R = 6371000; // 지구 반지름 (미터)
  final dLat = (lat2 - lat1) * (math.pi / 180);
  final dLon = (lon2 - lon1) * (math.pi / 180);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}
