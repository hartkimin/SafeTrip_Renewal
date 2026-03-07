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
      return TripCardViewData.fromJson(response.data as Map<String, dynamic>);
    }
    return const TripCardViewData();
  }

  /// PATCH /trips/:tripId/reactivate (§04.5)
  Future<void> reactivateTrip(String tripId) async {
    await _apiService.dio.patch('/api/v1/trips/$tripId/reactivate');
  }
}
