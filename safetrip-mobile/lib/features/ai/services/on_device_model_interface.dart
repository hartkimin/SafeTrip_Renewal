/// SS6.1 2차 폴백 -- 온디바이스 모델 인터페이스
/// Phase 3에서 TFLite/ONNX Runtime으로 실제 구현 예정
abstract class OnDeviceModel {
  /// 모델 로드 여부
  bool get isLoaded;

  /// 모델 초기화 (기기 저장공간 확인 포함)
  Future<bool> initialize();

  /// 추론 실행
  Future<Map<String, dynamic>> predict(Map<String, dynamic> input);

  /// 모델 해제
  Future<void> dispose();
}

/// Phase 3 전까지 사용하는 Stub 구현
class OnDeviceModelStub implements OnDeviceModel {
  @override
  bool get isLoaded => false;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<Map<String, dynamic>> predict(Map<String, dynamic> input) async {
    throw UnsupportedError(
      'On-device model not available. Use rule-based fallback.',
    );
  }

  @override
  Future<void> dispose() async {}
}
