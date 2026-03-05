import 'package:flutter/material.dart';

/// 사용자 위치 상태 정보 모델
class UserLocationStatus {

  UserLocationStatus({
    required this.userId,
    this.latitude,
    this.longitude,
    required this.statusText,
    required this.movementStatus,
    required this.displayText,
    this.statusIcon,
    this.distance,
    required this.isInsideGeofence,
    required this.isMoving,
    this.thoroughfare,
    this.subLocality,
    this.geofenceName,
    this.countryCode,
    this.countryName,
    this.address,
    this.activityType,
    this.movementSessionId,
    this.movementSessionCreatedAt,
    this.currentGeofenceId,
    this.geofenceEnteredAt,
    this.lastLocationTimestamp,
  });
  final String userId;
  final double? latitude;
  final double? longitude;
  final String statusText; // "도착", "100m", "1.2km" 등
  final String movementStatus; // "이동중", "목현동에서 1시간째 머무름" 등
  final String
  displayText; // 일정에 표시되는 텍스트 (아이콘 제외, 예: "목현동에서 이동중", "목현동에서 1시간째 머무름")
  final IconData?
  statusIcon; // fa-circle-dot, fa-location-dot, fa-person-walking 등
  final double? distance; // 지오펜스까지 거리 (미터)
  final bool isInsideGeofence;
  final bool isMoving;
  final String? thoroughfare;
  final String? subLocality;
  final String? geofenceName;
  final String? countryCode; // ISO 3166-1 alpha-2 국가 코드 (예: "KR", "US")
  final String? countryName; // 국가명 (예: "한국", "United States")
  final String? address; // 주소 (국가명 제외, 예: "경기도 광주시")
  final String? activityType;
  final String? movementSessionId;
  final dynamic movementSessionCreatedAt;
  final String? currentGeofenceId;
  final int? geofenceEnteredAt;
  final int? lastLocationTimestamp;
}
