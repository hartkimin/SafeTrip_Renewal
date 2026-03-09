import '../../../services/api_service.dart';
import '../models/trip_card_data.dart';

/// 여행정보카드 API 서비스 (DOC-T3-TIC-024)
class TripCardService {
  TripCardService(this._apiService);

  final ApiService _apiService;

  /// GET /trips/card-view
  Future<TripCardViewData> fetchCardView() async {
    final response = await _apiService.dio.get('/api/v1/trips/card-view');
    if (response.data is Map<String, dynamic>) {
      final body = response.data as Map<String, dynamic>;
      // 서버 TransformInterceptor가 { success, data } 로 래핑하므로 unwrap
      final payload = (body['success'] == true && body['data'] is Map<String, dynamic>)
          ? body['data'] as Map<String, dynamic>
          : body;
      return TripCardViewData.fromJson(payload);
    }
    return const TripCardViewData();
  }

  /// PATCH /trips/:tripId/reactivate (§04.5)
  Future<void> reactivateTrip(String tripId) async {
    await _apiService.dio.patch('/api/v1/trips/$tripId/reactivate');
  }
}
