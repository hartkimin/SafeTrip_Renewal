import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../screens/main/navigation/bottom_navigation_bar.dart';

/// 바텀시트 5단계 스냅 레벨 (바텀시트 동작 규칙 §2)
enum BottomSheetLevel {
  collapsed, // 0.10
  peek, // 0.25
  half, // 0.50
  expanded, // 0.75
  full, // 1.00
}

extension BottomSheetLevelExt on BottomSheetLevel {
  double get fraction {
    switch (this) {
      case BottomSheetLevel.collapsed:
        return 0.10;
      case BottomSheetLevel.peek:
        return 0.25;
      case BottomSheetLevel.half:
        return 0.50;
      case BottomSheetLevel.expanded:
        return 0.75;
      case BottomSheetLevel.full:
        return 1.00;
    }
  }

  /// 현재 fraction 값에 가장 가까운 레벨 반환
  static BottomSheetLevel fromFraction(double fraction) {
    BottomSheetLevel nearest = BottomSheetLevel.collapsed;
    double minDist = (fraction - nearest.fraction).abs();
    for (final level in BottomSheetLevel.values) {
      final dist = (fraction - level.fraction).abs();
      if (dist < minDist) {
        minDist = dist;
        nearest = level;
      }
    }
    return nearest;
  }

  /// 비교: 이 레벨이 [other]보다 높거나 같은지 (§7.2 높이 비교용)
  bool operator >=(BottomSheetLevel other) => index >= other.index;
}

/// 탭별 기본 높이 (§5.1)
const Map<BottomTab, BottomSheetLevel> tabDefaultHeight = {
  BottomTab.trip: BottomSheetLevel.half, // 일정탭: half
  BottomTab.member: BottomSheetLevel.peek, // 멤버탭: peek
  BottomTab.chat: BottomSheetLevel.expanded, // 채팅탭: expanded
  BottomTab.guide: BottomSheetLevel.half, // 안전가이드탭: half
};

/// 탭별 최소 요구 높이 (§7.3)
const Map<BottomTab, BottomSheetLevel> tabMinRequiredHeight = {
  BottomTab.trip: BottomSheetLevel.peek, // 일정 항목 최소 1개
  BottomTab.member: BottomSheetLevel.peek, // 멤버 카드 최소 1개
  BottomTab.chat: BottomSheetLevel.expanded, // 입력창 + 메시지 영역
  BottomTab.guide: BottomSheetLevel.peek, // 서브탭 선택 영역
};

/// 여행 상태별 초기 높이 (§5.2)
BottomSheetLevel initialHeightForTripStatus(String? tripStatus) {
  switch (tripStatus) {
    case 'completed':
      return BottomSheetLevel.half;
    case 'none':
    case 'planning':
    case 'active':
    default:
      return BottomSheetLevel.collapsed;
  }
}

class MainScreenState {
  const MainScreenState({
    this.sheetLevel = BottomSheetLevel.half,
    this.currentTab = BottomTab.trip,
    this.isOnline = true,
    this.unreadCount = 0,
    this.isSosActive = false,
    this.isNoTrip = false,
    this.preKeyboardLevel,
    this.preDetailLevel,
  });

  final BottomSheetLevel sheetLevel;
  final BottomTab currentTab;
  final bool isOnline;
  final int unreadCount;

  /// SOS 발동 상태 (§10 — true이면 collapsed 잠금)
  final bool isSosActive;

  /// 여행 없음 상태 (§8.2 — true이면 collapsed 잠금 + 탭 비활성화)
  final bool isNoTrip;

  /// 키보드 출현 직전 상태 저장 (§6.1 — 키보드 닫힘 시 복원용)
  final BottomSheetLevel? preKeyboardLevel;

  /// 세부 화면 진입 직전 상태 저장 (§7.4 — 뒤로가기 시 복원용)
  final BottomSheetLevel? preDetailLevel;

  MainScreenState copyWith({
    BottomSheetLevel? sheetLevel,
    BottomTab? currentTab,
    bool? isOnline,
    int? unreadCount,
    bool? isSosActive,
    bool? isNoTrip,
    BottomSheetLevel? Function()? preKeyboardLevel,
    BottomSheetLevel? Function()? preDetailLevel,
  }) {
    return MainScreenState(
      sheetLevel: sheetLevel ?? this.sheetLevel,
      currentTab: currentTab ?? this.currentTab,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      isSosActive: isSosActive ?? this.isSosActive,
      isNoTrip: isNoTrip ?? this.isNoTrip,
      preKeyboardLevel: preKeyboardLevel != null
          ? preKeyboardLevel()
          : this.preKeyboardLevel,
      preDetailLevel: preDetailLevel != null
          ? preDetailLevel()
          : this.preDetailLevel,
    );
  }
}

class MainScreenNotifier extends StateNotifier<MainScreenState> {
  MainScreenNotifier() : super(const MainScreenState());

  /// 시트 레벨 변경 콜백 (컨트롤러 리스너에서 호출)
  /// 반환: 실제 적용된 레벨 (SOS 잠금 시 collapsed 강제)
  BottomSheetLevel setSheetLevel(BottomSheetLevel level) {
    // SOS 활성 시 collapsed 이외 허용 안함 (§10.2)
    if (state.isSosActive && level != BottomSheetLevel.collapsed) {
      return BottomSheetLevel.collapsed;
    }
    // 여행 없음 시 collapsed 이외 허용 안함 (§8.2)
    if (state.isNoTrip && level != BottomSheetLevel.collapsed) {
      return BottomSheetLevel.collapsed;
    }
    state = state.copyWith(sheetLevel: level);
    return level;
  }

  void setCurrentTab(BottomTab tab) {
    state = state.copyWith(currentTab: tab);
  }

  void setOnline(bool online) {
    state = state.copyWith(isOnline: online);
  }

  void setUnreadCount(int count) {
    state = state.copyWith(unreadCount: count);
  }

  /// 탭 전환 시 높이 결정 (§7.2)
  ///
  /// 현재 높이 >= 새 탭의 최소 요구 높이 → 유지
  /// 현재 높이 < 최소 요구 높이 → 탭의 기본 높이로 전환
  BottomSheetLevel resolveHeightForTab(BottomTab newTab) {
    final currentLevel = state.sheetLevel;
    final minRequired =
        tabMinRequiredHeight[newTab] ?? BottomSheetLevel.peek;

    if (currentLevel >= minRequired) {
      return currentLevel; // 현재 높이 유지
    }
    return tabDefaultHeight[newTab] ?? BottomSheetLevel.half;
  }

  /// 동일 탭 재탭 시 높이 결정 (§4.4)
  BottomSheetLevel resolveHeightForSameTabTap() {
    switch (state.sheetLevel) {
      case BottomSheetLevel.collapsed:
        return BottomSheetLevel.half; // collapsed → half
      case BottomSheetLevel.peek:
      case BottomSheetLevel.half:
        return BottomSheetLevel.collapsed; // peek/half → collapsed
      case BottomSheetLevel.expanded:
      case BottomSheetLevel.full:
        return BottomSheetLevel.half; // expanded/full → half
    }
  }

  /// SOS 발동 (§10.1)
  void activateSos() {
    state = state.copyWith(
      isSosActive: true,
      sheetLevel: BottomSheetLevel.collapsed,
    );
  }

  /// SOS 해제 (§10.3) — peek 상태로 복원
  void deactivateSos() {
    state = state.copyWith(
      isSosActive: false,
      sheetLevel: BottomSheetLevel.peek,
    );
  }

  /// 키보드 출현 (§6.1) — 현재 상태 저장 후 full 전환
  /// SOS 활성 시에는 collapsed 유지 (§10.2 불변 조건)
  BottomSheetLevel onKeyboardShow() {
    if (state.isSosActive) return BottomSheetLevel.collapsed;

    state = state.copyWith(
      preKeyboardLevel: () => state.sheetLevel,
      sheetLevel: BottomSheetLevel.full,
    );
    return BottomSheetLevel.full;
  }

  /// 키보드 닫힘 (§6.1, §6.2) — 이전 상태로 복원
  BottomSheetLevel onKeyboardHide() {
    final restored = state.currentTab == BottomTab.chat
        ? BottomSheetLevel.expanded // 채팅탭: expanded로 복원 (§6.2)
        : (state.preKeyboardLevel ?? BottomSheetLevel.half);
    state = state.copyWith(
      sheetLevel: restored,
      preKeyboardLevel: () => null,
    );
    return restored;
  }

  /// 여행 없음 상태 설정 (§8.2)
  void setNoTrip(bool noTrip) {
    state = state.copyWith(
      isNoTrip: noTrip,
      sheetLevel: noTrip ? BottomSheetLevel.collapsed : state.sheetLevel,
    );
  }

  /// 세부 화면 진입 (§7.4) — 현재 레벨 저장 후 full 전환
  BottomSheetLevel enterDetailView() {
    state = state.copyWith(
      preDetailLevel: () => state.sheetLevel,
      sheetLevel: BottomSheetLevel.full,
    );
    return BottomSheetLevel.full;
  }

  /// 세부 화면 종료 (§7.4) — 이전 레벨로 복원
  BottomSheetLevel exitDetailView() {
    final restored = state.preDetailLevel ?? BottomSheetLevel.half;
    state = state.copyWith(
      sheetLevel: restored,
      preDetailLevel: () => null,
    );
    return restored;
  }
}

final mainScreenProvider =
    StateNotifierProvider<MainScreenNotifier, MainScreenState>((ref) {
  return MainScreenNotifier();
});
