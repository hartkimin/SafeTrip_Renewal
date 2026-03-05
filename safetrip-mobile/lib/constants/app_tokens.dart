import 'package:flutter/material.dart';

/// SafeTrip 디자인 토큰
/// JSON 토큰 파일을 기반으로 생성된 Dart 상수
class AppTokens {
  AppTokens._();

  // ============================================================================
  // 색상 (Color)
  // ============================================================================

  /// 텍스트 색상
  static const Color text01 = Color(0xFFFFFFFF); // white
  static const Color text02 = Color(0xFFC2C2C2);
  static const Color text03 = Color(0xFF8E8E93);
  static const Color text04 = Color(0xFF4E4E4F);
  static const Color text05 = Color(0xFF1A1A1A); // black
  static const Color text06 = Color(0xFF008298); // primary teal
  static const Color text07 = Color(0xFFD6403A); // error red
  static const Color text08 = Color(0xFFB16D00); // warning orange
  static const Color textInactive = Color(0xFF767676); // inactive icon/text

  /// Primary 색상
  static const Color primaryCoral = Color(0xFFFF807B);
  static const Color primaryTeal = Color(0xFF00A2BD);

  /// Secondary 색상
  static const Color secondaryAmber = Color(0xFFFFC363);
  static const Color secondaryBaige = Color(0xFFF2EDE4);
  static const Color secondaryTeal = Color(0xFFF1F7F9);

  /// Semantic 색상
  static const Color semanticWarning = Color(0xFFFFAC11);
  static const Color semanticError = Color(0xFFDA4C51);
  static const Color semanticSuccess = Color(0xFF15A1A5);
  static const Color sosDanger = Color(0xFFD32F2F);

  /// 배경 색상 - Teal
  static const Color bgTeal01 = Color(0xFFFAFEFF);
  static const Color bgTeal02 = Color(0xFFF5FBFC);
  static const Color bgTeal03 = Color(0xFFEDFAFC);
  static const Color bgTeal04 = Color(0xFFDAEFF3);

  /// 배경 색상 - Basic
  static const Color bgBasic01 = Color(0xFFFFFFFF);
  static const Color bgBasic02 = Color(0xFFFCFCFC);
  static const Color bgBasic03 = Color(0xFFF9F9F9);
  static const Color bgBasic04 = Color(0xFFF5F5F5);
  static const Color bgBasic05 = Color(0xFFE6E6E6);

  /// Teal 색상 팔레트
  static const Color teal01 = Color(0xFFFAFEFF);
  static const Color teal02 = Color(0xFFEFF9FC);
  static const Color teal03 = Color(0xFFE1F5FA);
  static const Color teal04 = Color(0xFFD3ECF2);
  static const Color teal05 = Color(0xFFADE4F0);
  static const Color teal06 = Color(0xFF83D6E5);
  static const Color teal07 = Color(0xFF6ABECE);
  static const Color teal08 = Color(0xFF0095B3);
  static const Color teal09 = Color(0xFF008399);
  static const Color teal10 = Color(0xFF015572);

  /// Coral 색상 팔레트
  static const Color coral01 = Color(0xFFFFF7F7);
  static const Color coral02 = Color(0xFFFFECEC);
  static const Color coral03 = Color(0xFFFFDCDC);
  static const Color coral04 = Color(0xFFFFC9C8);
  static const Color coral05 = Color(0xFFFFB7B4);
  static const Color coral06 = Color(0xFFFFA5A2);
  static const Color coral07 = Color(0xFFFF938F);
  static const Color coral08 = Color(0xFFF27974);
  static const Color coral09 = Color(0xFFF76863);
  static const Color coral10 = Color(0xFFE8554F);

  /// Basic 색상 팔레트
  static const Color basic01 = Color(0xFFFFFFFF);
  static const Color basic02 = Color(0xFFF9F9F9);
  static const Color basic03 = Color(0xFFF5F5F5);
  static const Color basic04 = Color(0xFFE0E0E0);
  static const Color basic05 = Color(0xFFD4D4D4);
  static const Color basic06 = Color(0xFFC1C1C1);
  static const Color basic07 = Color(0xFFA7A7A7);
  static const Color basic08 = Color(0xFF898989);
  static const Color basic09 = Color(0xFF5A5A5A);
  static const Color basic10 = Color(0xFF343434);

  /// 라인 색상
  static const Color line01 = Color(0xFFFFFFFF);
  static const Color line02 = Color(0xFFF5F5F5);
  static const Color line03 = Color(0xFFEDEDED);
  static const Color line04 = Color(0xFFD2D3D4);
  static const Color line05 = Color(0xFFE0F3F7);
  static const Color line06 = Color(0xFF64C0D0);
  static const Color line07 = Color(0xFF00A2BD);
  static const Color line08 = Color(0xFFF7E0E0);
  static const Color line09 = Color(0xFFFFB4B8);

  /// Soft 색상
  static const Color softYellowLight = Color(0xFFFFFBEB);
  static const Color softYellowWeak = Color(0xFFFFF4CE);
  static const Color softGreenLight = Color(0xFFF2FDFA);
  static const Color softGreenWeak = Color(0xFFDFFBF4);
  static const Color softBlueLight = Color(0xFFF5F8FF);
  static const Color softBlueWeak = Color(0xFFE6EDFF);
  static const Color softPurpleLight = Color(0xFFF6F4FD);
  static const Color softPurpleWeak = Color(0xFFE9E3FA);

  // ============================================================================
  // 타이포그래피 (Typography)
  // ============================================================================

  /// 폰트 패밀리
  static const String fontFamily = 'Plus Jakarta Sans';

  /// 폰트 크기
  static const double fontSize11 = 11.0;
  static const double fontSize12 = 12.0;
  static const double fontSize13 = 13.0;
  static const double fontSize14 = 14.0;
  static const double fontSize15 = 15.0;
  static const double fontSize16 = 16.0;
  static const double fontSize18 = 18.0;
  static const double fontSize20 = 20.0;
  static const double fontSize24 = 24.0;
  static const double fontSize28 = 28.0;
  static const double fontSize36 = 36.0;
  static const double fontSize40 = 40.0;
  static const double fontSize48 = 48.0;

  /// 폰트 굵기
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemibold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  /// 자간 (Letter Spacing)
  static const double letterSpacing0 = 0.0;
  static const double letterSpacingNeg05 = -0.5;
  static const double letterSpacingNeg03 = -0.3;
  static const double letterSpacingNeg15 = -1.5;
  static const double letterSpacingNeg1 = -1.0;
  static const double letterSpacingNeg2 = -2.0;
  static const double letterSpacingNeg3 = -3.0;
  static const double letterSpacingNeg5 = -5.0;

  // ============================================================================
  // 간격 (Spacing)
  // ============================================================================

  static const double spacing1 = 1.0;
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacing16 = 16.0;
  static const double spacing18 = 18.0;
  static const double spacing20 = 20.0;
  static const double spacing22 = 22.0;
  static const double spacing24 = 24.0;
  static const double spacing28 = 28.0;
  static const double spacing32 = 32.0;
  static const double spacing34 = 34.0;
  static const double spacing40 = 40.0;
  static const double spacing44 = 44.0;
  static const double spacing48 = 48.0;
  static const double spacing52 = 52.0;
  static const double spacing56 = 56.0;
  static const double spacing60 = 60.0;
  static const double spacing64 = 64.0;
  static const double spacing68 = 68.0;

  // ============================================================================
  // Border Radius
  // ============================================================================

  static const double radius4 = 4.0;
  static const double radius6 = 6.0;
  static const double radius8 = 8.0;
  static const double radius10 = 10.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius48 = 48.0;
  static const double radius60 = 60.0;

  // ============================================================================
  // Bottom Sheet
  // ============================================================================

  /// 바텀시트 높이 스냅 포인트 (화면 높이 대비 비율) — 5단계 (v2.0 규칙)
  static const double bottomSheetHeightCollapsed = 0.10; // 1단계: collapsed
  static const double bottomSheetHeightPeek = 0.25;      // 2단계: peek
  static const double bottomSheetHeightHalf = 0.50;      // 3단계: half
  static const double bottomSheetHeightTall = 0.75;      // 4단계: expanded
  static const double bottomSheetHeightExpanded = 1.00;  // 5단계: full (전체 화면)

  /// 바텀시트 스냅 포인트 목록 (오름차순)
  static const List<double> bottomSheetSnapPoints = [
    bottomSheetHeightCollapsed,
    bottomSheetHeightPeek,
    bottomSheetHeightHalf,
    bottomSheetHeightTall,
    bottomSheetHeightExpanded,
  ];

  /// 가장 가까운 스냅 포인트 반환
  static double nearestSnapPoint(double height) {
    double nearest = bottomSheetSnapPoints[0];
    double minDist = (height - nearest).abs();
    for (final snap in bottomSheetSnapPoints) {
      final dist = (height - snap).abs();
      if (dist < minDist) {
        minDist = dist;
        nearest = snap;
      }
    }
    return nearest;
  }

  // 하위 호환 별칭 (v2.0 기준)
  static const double bottomSheetHeightMin = bottomSheetHeightCollapsed;
  static const double bottomSheetHeightMid = bottomSheetHeightHalf;
  static const double bottomSheetHeightMax = bottomSheetHeightExpanded;

  // ============================================================================
  // 그림자 (Shadow)
  // ============================================================================

  /// 기본 그림자
  static List<BoxShadow> get shadow01 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      offset: const Offset(0, 1),
      blurRadius: 1,
      spreadRadius: 1,
    ),
  ];

  /// 중간 그림자
  static List<BoxShadow> get shadow02 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.01),
      offset: const Offset(0, 4),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.01),
      offset: const Offset(0, 2),
      blurRadius: 2,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      offset: const Offset(0, 0),
      blurRadius: 1,
      spreadRadius: 0,
    ),
  ];

  // ============================================================================
  // 편의 메서드 (Helper Methods)
  // ============================================================================

  /// 텍스트 스타일 생성
  static TextStyle textStyle({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize ?? fontSize14,
      fontWeight: fontWeight ?? fontWeightRegular,
      fontStyle: fontStyle,
      color: color ?? text05,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
    );
  }

  /// 색상 헬퍼 - hex 문자열을 Color로 변환
  static Color colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
