/// SafeTrip 스페이싱 시스템
/// [AppTokens]의 spacing 값에 시맨틱 이름을 부여한다.
abstract class AppSpacing {
  // ─ 시맨틱 스페이싱 ──────────────────────────────────────────────
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // ─ 화면 레이아웃 ──────────────────────────────────────────────
  static const double screenPaddingH = 20.0; // 화면 좌우 패딩
  static const double screenPaddingTop = 32.0; // 화면 상단 여백
  static const double sectionGap = 24.0; // 섹션 간격
  static const double cardGap = 12.0; // 카드 간 간격

  // ─ 레이아웃 고정 높이 ──────────────────────
  static const double appBarHeight = 56.0; // AppBar 높이
  static const double navigationBarHeight = 60.0; // BottomNavigationBar 높이

  // ─ 컴포넌트 ──────────────────────────────────────────────────
  static const double cardPadding = 16.0; // 카드 내부 패딩
  static const double inputPaddingH = 16.0; // 입력 필드 좌우 패딩
  static const double inputPaddingV = 12.0; // 입력 필드 상하 패딩
  static const double buttonHeight = 52.0; // 기본 버튼 높이
  static const double sosButtonSize = 56.0; // SOS 버튼 크기 (비즈니스 원칙 §05.1)

  // ─ 터치 영역 최소 크기 (접근성 기준) ──────────────────────────
  static const double minTouchTarget = 44.0;
  static const double tabBarItemSize = 48.0; // 탭바 아이템
  static const double mapMarkerSize = 44.0; // 지도 마커

  // ─ 바텀시트 ──────────────────────────────────────────────────
  static const double bottomSheetHandleWidth = 44.0;
  static const double bottomSheetHandleHeight = 4.0;
  static const double bottomSheetRadius = 20.0;

  // ─ 보더 반경 (Radius) ─────────────────────────────────────────
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radiusFull = 999.0;
}
