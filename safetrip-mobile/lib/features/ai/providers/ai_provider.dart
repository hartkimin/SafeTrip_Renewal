import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../services/ai_access_service.dart';

final aiAccessServiceProvider = Provider<AiAccessService>((ref) {
  return AiAccessService(ApiService());
});

class AiState {
  final bool isLoading;
  final String? error;
  final Map<String, bool> featureAccess;

  const AiState({
    this.isLoading = false,
    this.error,
    this.featureAccess = const {},
  });

  AiState copyWith({
    bool? isLoading,
    String? error,
    Map<String, bool>? featureAccess,
  }) {
    return AiState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      featureAccess: featureAccess ?? this.featureAccess,
    );
  }
}

class AiNotifier extends StateNotifier<AiState> {
  final AiAccessService _accessService;
  AiNotifier(this._accessService) : super(const AiState());

  Future<bool> checkFeatureAccess(String feature, {String? tripId}) async {
    state = state.copyWith(isLoading: true);
    final result = await _accessService.checkAccess(feature, tripId: tripId);
    final updated = Map<String, bool>.from(state.featureAccess);
    updated[feature] = result.allowed;
    state = state.copyWith(isLoading: false, featureAccess: updated);
    return result.allowed;
  }
}

final aiProvider = StateNotifierProvider<AiNotifier, AiState>((ref) {
  return AiNotifier(ref.read(aiAccessServiceProvider));
});
