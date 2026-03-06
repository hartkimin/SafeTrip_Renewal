import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/location_service.dart';

// ---------------------------------------------------------------------------
// DOC-T2-OFL-016 §7.3 -- Battery Level Provider
// ---------------------------------------------------------------------------

/// 배터리 잔량 스트림 프로바이더.
///
/// [LocationService]의 `batteryLevelStream`을 구독하여
/// 위치 업데이트마다 갱신되는 배터리 잔량(0-100)을 제공한다.
/// 초기 값이 아직 없으면 `AsyncLoading` 상태이다.
final batteryLevelProvider = StreamProvider<int>((ref) {
  return LocationService().batteryLevelStream;
});
