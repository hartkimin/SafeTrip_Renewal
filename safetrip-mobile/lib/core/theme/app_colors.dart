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

  // ─ 여행 상태별 컬러 ──────────────────────────────────────────────
  static const Color tripPlanning = AppTokens.secondaryAmber; // planning
  static const Color tripActive = AppTokens.semanticSuccess; // active
  static const Color tripCompleted = AppTokens.basic08; // completed
}
