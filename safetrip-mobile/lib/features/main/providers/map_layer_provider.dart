import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 7단계 레이어 ON/OFF 상태 관리 (지도 원칙 §3)
///
/// Layer 0 (지도 타일): 항상 ON — 토글 불가
/// Layer 1 (안전시설): 토글 가능
/// Layer 2 (멤버 위치): 토글 가능
/// Layer 3 (일정/장소): 토글 가능
/// Layer 4 (이벤트/알림): 캡틴/크루장 전용, 토글 가능
/// Layer 5 (UI 컨트롤): 항상 ON — 토글 불가
/// Layer 6 (긴급 오버레이): SOS 자동 제어 — 토글 불가
class MapLayerState {
  const MapLayerState({
    this.layer1SafetyFacilities = true,
    this.layer2MemberMarkers = true,
    this.layer3SchedulePlaces = true,
    this.layer4EventAlerts = true,
  });

  final bool layer1SafetyFacilities;
  final bool layer2MemberMarkers;
  final bool layer3SchedulePlaces;
  final bool layer4EventAlerts;

  MapLayerState copyWith({
    bool? layer1SafetyFacilities,
    bool? layer2MemberMarkers,
    bool? layer3SchedulePlaces,
    bool? layer4EventAlerts,
  }) {
    return MapLayerState(
      layer1SafetyFacilities: layer1SafetyFacilities ?? this.layer1SafetyFacilities,
      layer2MemberMarkers: layer2MemberMarkers ?? this.layer2MemberMarkers,
      layer3SchedulePlaces: layer3SchedulePlaces ?? this.layer3SchedulePlaces,
      layer4EventAlerts: layer4EventAlerts ?? this.layer4EventAlerts,
    );
  }
}

class MapLayerNotifier extends StateNotifier<MapLayerState> {
  MapLayerNotifier() : super(const MapLayerState()) {
    _loadFromPrefs();
  }

  static const _keyPrefix = 'map_layer_';

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = MapLayerState(
      layer1SafetyFacilities: prefs.getBool('${_keyPrefix}1') ?? true,
      layer2MemberMarkers: prefs.getBool('${_keyPrefix}2') ?? true,
      layer3SchedulePlaces: prefs.getBool('${_keyPrefix}3') ?? true,
      layer4EventAlerts: prefs.getBool('${_keyPrefix}4') ?? true,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_keyPrefix}1', state.layer1SafetyFacilities);
    await prefs.setBool('${_keyPrefix}2', state.layer2MemberMarkers);
    await prefs.setBool('${_keyPrefix}3', state.layer3SchedulePlaces);
    await prefs.setBool('${_keyPrefix}4', state.layer4EventAlerts);
  }

  void toggleLayer1() {
    state = state.copyWith(layer1SafetyFacilities: !state.layer1SafetyFacilities);
    _save();
  }

  void toggleLayer2() {
    state = state.copyWith(layer2MemberMarkers: !state.layer2MemberMarkers);
    _save();
  }

  void toggleLayer3() {
    state = state.copyWith(layer3SchedulePlaces: !state.layer3SchedulePlaces);
    _save();
  }

  void toggleLayer4() {
    state = state.copyWith(layer4EventAlerts: !state.layer4EventAlerts);
    _save();
  }
}

final mapLayerProvider =
    StateNotifierProvider<MapLayerNotifier, MapLayerState>((ref) {
  return MapLayerNotifier();
});
