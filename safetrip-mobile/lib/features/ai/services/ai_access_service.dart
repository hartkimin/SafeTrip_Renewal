import '../../../services/api_service.dart';

class AiAccessResult {
  final bool allowed;
  final String plan;
  final String feature;
  final String category;

  AiAccessResult({
    required this.allowed,
    required this.plan,
    required this.feature,
    required this.category,
  });

  factory AiAccessResult.fromJson(Map<String, dynamic> json) {
    return AiAccessResult(
      allowed: json['allowed'] ?? false,
      plan: json['plan'] ?? 'free',
      feature: json['feature'] ?? '',
      category: json['category'] ?? '',
    );
  }
}

class AiAccessService {
  final ApiService _api;

  AiAccessService(this._api);

  Future<AiAccessResult> checkAccess(String feature, {String? tripId}) async {
    try {
      final params = <String, String>{'feature': feature};
      if (tripId != null) params['trip_id'] = tripId;
      final response = await _api.dio.get(
        '/api/ai/access-check',
        queryParameters: params,
      );
      return AiAccessResult.fromJson(response.data);
    } catch (e) {
      return AiAccessResult(
        allowed: false,
        plan: 'free',
        feature: feature,
        category: '',
      );
    }
  }

  Future<Map<String, dynamic>> submitFeedback(
    String logId,
    int feedback,
  ) async {
    final response = await _api.dio.patch(
      '/api/ai/feedback/$logId',
      data: {'feedback': feedback},
    );
    return response.data;
  }
}
