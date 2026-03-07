import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../data/safety_guide_cache_service.dart';
import '../data/safety_guide_repository.dart';
import '../models/guide_data.dart';

// ---------------------------------------------------------------------------
// Service instance providers
// ---------------------------------------------------------------------------

final safetyGuideCacheServiceProvider = Provider<SafetyGuideCacheService>((ref) {
  return SafetyGuideCacheService();
});

final safetyGuideRepositoryProvider = Provider<SafetyGuideRepository>((ref) {
  return SafetyGuideRepository(
    api: ApiService(),
    cache: ref.read(safetyGuideCacheServiceProvider),
  );
});

/// 선택된 국가 코드 (null = 자유 탐색 모드)
final selectedCountryCodeProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// SafetyGuideState
// ---------------------------------------------------------------------------

class SafetyGuideState {
  final SafetyGuideData? data;
  final bool isLoading;
  final String? error;

  const SafetyGuideState({this.data, this.isLoading = false, this.error});

  SafetyGuideState copyWith({
    SafetyGuideData? data,
    bool? isLoading,
    String? error,
  }) {
    return SafetyGuideState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// SafetyGuideNotifier — StateNotifier
// ---------------------------------------------------------------------------

class SafetyGuideNotifier extends StateNotifier<SafetyGuideState> {
  final SafetyGuideRepository _repository;

  SafetyGuideNotifier(this._repository) : super(const SafetyGuideState());

  /// 전체 가이드 데이터 로드
  Future<void> loadGuide(String countryCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repository.loadAll(countryCode);
      if (mounted) {
        state = SafetyGuideState(data: data, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  /// 새로고침 (pull-to-refresh)
  Future<void> refresh(String countryCode) async {
    await loadGuide(countryCode);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final safetyGuideProvider =
    StateNotifierProvider.autoDispose<SafetyGuideNotifier, SafetyGuideState>(
  (ref) {
    return SafetyGuideNotifier(ref.read(safetyGuideRepositoryProvider));
  },
);
