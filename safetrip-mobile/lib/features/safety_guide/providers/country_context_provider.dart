import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// CountryContextSource — 국가 컨텍스트 출처 (DOC-T3-SFG-021 §3.3)
// ---------------------------------------------------------------------------

enum CountryContextSource {
  /// 활성 여행에서 자동 감지
  activeTrip,

  /// 가디언 연결 멤버의 여행 목적지
  guardian,

  /// 사용자 수동 선택
  manual,

  /// 미설정
  none,
}

// ---------------------------------------------------------------------------
// CountryContextState
// ---------------------------------------------------------------------------

/// 컨텍스트 기반 국가 자동 선택 상태 (§3.3)
/// 우선순위: 1. Active 여행 -> 2. 가디언 -> 3. 수동 선택 -> 4. null (자유 탐색)
class CountryContextState {
  final String? countryCode;
  final String? countryNameKo;
  final String? flagEmoji;
  final bool isManualOverride;
  final CountryContextSource source;

  const CountryContextState({
    this.countryCode,
    this.countryNameKo,
    this.flagEmoji,
    this.isManualOverride = false,
    this.source = CountryContextSource.none,
  });

  CountryContextState copyWith({
    String? countryCode,
    String? countryNameKo,
    String? flagEmoji,
    bool? isManualOverride,
    CountryContextSource? source,
  }) {
    return CountryContextState(
      countryCode: countryCode ?? this.countryCode,
      countryNameKo: countryNameKo ?? this.countryNameKo,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      source: source ?? this.source,
    );
  }
}

// ---------------------------------------------------------------------------
// CountryContextNotifier — StateNotifier
// ---------------------------------------------------------------------------

class CountryContextNotifier extends StateNotifier<CountryContextState> {
  CountryContextNotifier() : super(const CountryContextState());

  /// 여행 컨텍스트에서 자동 설정
  void setFromTrip(
    String countryCode, {
    String? countryNameKo,
    String? flagEmoji,
  }) {
    if (state.isManualOverride) return; // 수동 변경 중에는 자동 변경 무시
    state = CountryContextState(
      countryCode: countryCode,
      countryNameKo: countryNameKo,
      flagEmoji: flagEmoji,
      source: CountryContextSource.activeTrip,
    );
  }

  /// 가디언 컨텍스트에서 자동 설정
  void setFromGuardian(
    String countryCode, {
    String? countryNameKo,
    String? flagEmoji,
  }) {
    if (state.isManualOverride) return;
    state = CountryContextState(
      countryCode: countryCode,
      countryNameKo: countryNameKo,
      flagEmoji: flagEmoji,
      source: CountryContextSource.guardian,
    );
  }

  /// 수동 국가 변경 (§3.3 수동 변경)
  void setManual(
    String countryCode, {
    String? countryNameKo,
    String? flagEmoji,
  }) {
    state = CountryContextState(
      countryCode: countryCode,
      countryNameKo: countryNameKo,
      flagEmoji: flagEmoji,
      isManualOverride: true,
      source: CountryContextSource.manual,
    );
  }

  /// 수동 변경 해제 -> 컨텍스트 복원
  void clearManualOverride() {
    if (!state.isManualOverride) return;
    state = const CountryContextState(); // 리셋 -> 재초기화 필요
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final countryContextProvider =
    StateNotifierProvider<CountryContextNotifier, CountryContextState>(
  (ref) => CountryContextNotifier(),
);
