import 'package:flutter/material.dart';
import '../../constants/app_tokens.dart';

/// SafeTrip 시맨틱 색상 시스템
/// 역할별, 프라이버시 등급별, 상태별 색상을 정의한다.
/// 기본 색상 팔레트는 [AppTokens]에 정의되어 있으며,
/// 이 클래스는 의미 기반(semantic) 색상만 제공한다.
abstract class AppColors {
  // ─ 브랜드 컬러 (AppTokens 시맨틱 재-export) ────────────────────────
  static const Color primaryCoral = AppTokens.primaryCoral;
  static const Color primaryTeal = AppTokens.primaryTeal;
  static const Color secondaryAmber = AppTokens.secondaryAmber;
  static const Color secondaryBeige = AppTokens.secondaryBaige;

  // ─ 표면/배경 컬러 ────────────────────────────
  static const Color surface = AppTokens.bgBasic01;
  static const Color surfaceVariant = AppTokens.bgBasic03;
  static const Color onSurface = AppTokens.text05;
  static const Color onSurfaceVariant = AppTokens.text03;

  // ─ 경계선 컬러 ────────────────────────────────
  static const Color outline = AppTokens.line03;
  static const Color outlineVariant = AppTokens.line02;

  // ─ 텍스트 컬러 ──────────────────────────────────────────────────
  static const Color textPrimary = AppTokens.text05;
  static const Color textSecondary = AppTokens.text04;
  static const Color textTertiary = AppTokens.text03;
  static const Color textDisabled = AppTokens.textInactive;
  static const Color textOnPrimary = AppTokens.text01;
  static const Color textTeal = AppTokens.text06;
  static const Color textError = AppTokens.text07;
  static const Color textWarning = AppTokens.text08;

  // ─ 시맨틱 상태 컬러 ──────────────────────────────────────────────
  static const Color semanticSuccess = AppTokens.semanticSuccess;
  static const Color semanticWarning = AppTokens.semanticWarning;
  static const Color semanticError = AppTokens.semanticError;
  static const Color semanticInfo = AppTokens.primaryTeal;

  // ─ 역할별 컬러 (비즈니스 원칙 §03.1) ─────────────────────────────
  static const Color captain = AppTokens.primaryTeal; // 캡틴
  static const Color crewChief = AppTokens.teal10; // 크루장 — Teal Dark
  static const Color crew = AppTokens.basic08; // 크루 — Basic Gray
  static const Color guardian = AppTokens.semanticSuccess; // 가디언

  // ─ 지도 마커 역할별 컬러 (지도 원칙 §5.3) ──────────────────────
  static const Color mapMarkerCaptain = Color(0xFFFFD700);
  static const Color mapMarkerCrewLeader = Color(0xFFFF8C00);
  static const Color mapMarkerCrew = Color(0xFF2196F3);
  static const Color mapMarkerMyLocation = Color(0xFF4CAF50);
  static const Color mapMarkerGuardian = Color(0xFF9C27B0);
  static const Color mapMarkerOffline = Color(0xFF9E9E9E);
  static const Color mapMarkerHidden = Color(0xFFBDBDBD);

  /// 역할 enum -> 색상 매핑
  static Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'leader':
      case 'captain':
        return captain;
      case 'full':
      case 'crew_chief':
        return crewChief;
      case 'view_only':
      case 'guardian':
        return guardian;
      case 'normal':
      case 'crew':
      default:
        return crew;
    }
  }

  // ─ 프라이버시 등급별 컬러 (비즈니스 원칙 §04) ────────────────────
  static const Color privacySafetyFirst = AppTokens.semanticError; // 안전최우선
  static const Color privacyStandard = AppTokens.primaryTeal; // 표준
  static const Color privacyFirst = AppTokens.basic07; // 프라이버시우선

  // ─ SOS 전용 (비즈니스 원칙 §05.1) ────────────────────────────────
  static const Color sosDanger = AppTokens.sosDanger; // SOS 버튼
  static const Color sosBackground = AppTokens.sosDanger; // SOS 오버레이 배경
  static const Color sosText = AppTokens.text01; // SOS 텍스트

  // ─ 시간대별 감성 색상 (DOC-T3-WLC-029 §3.2.1) ────────────────
  /// Morning (07:00~12:00): 밝은 하늘색, 상쾌함·설렘
  static const Color timeOfDayMorning = Color(0xFF87CEEB);
  /// Afternoon (12:00~18:00): 따뜻한 노랑, 활기·에너지
  static const Color timeOfDayAfternoon = Color(0xFFFFC947);
  /// Night (18:00~07:00): 딥 네이비, 안정감·신뢰
  static const Color timeOfDayNight = Color(0xFF0D1B2A);

  /// Get time-of-day overlay color based on local device time
  static Color timeOfDayOverlay() {
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 12) return timeOfDayMorning;
    if (hour >= 12 && hour < 18) return timeOfDayAfternoon;
    return timeOfDayNight;
  }

  /// Get time-of-day name for analytics
  static String timeOfDayName() {
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 18) return 'afternoon';
    return 'night';
  }

  // ─ 여행 상태별 컬러 ──────────────────────────────────────────────
  static const Color tripPlanning = AppTokens.secondaryAmber; // planning
  static const Color tripActive = AppTokens.semanticSuccess; // active
  static const Color tripCompleted = AppTokens.basic08; // completed

  // ─ 일정 타입별 컬러 (schedule_type) ─────────────────────────────
  static const Color scheduleMoveBg = AppTokens.softBlueWeak;
  static const Color scheduleMoveIcon = Color(0xFF1565C0);
  static const Color scheduleStayBg = AppTokens.softPurpleLight;
  static const Color scheduleStayIcon = Color(0xFF7B1FA2);
  static const Color scheduleMealBg = AppTokens.softYellowLight;
  static const Color scheduleMealIcon = Color(0xFFE65100);
  static const Color scheduleSightseeingBg = AppTokens.softGreenLight;
  static const Color scheduleSightseeingIcon = Color(0xFF2E7D32);
  static const Color scheduleShoppingBg = AppTokens.coral01;
  static const Color scheduleShoppingIcon = Color(0xFFC62828);
  static const Color scheduleMeetingBg = AppTokens.teal03;
  static const Color scheduleOtherBg = AppTokens.bgBasic04;
}
