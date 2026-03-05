import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 마커 애니메이션 관리 클래스
/// 점프, 숨쉬기, 그리고 좌표 이동(Interpolation) 애니메이션을 통합 관리
class MarkerAnimationManager {
  MarkerAnimationManager({
    required TickerProvider vsync,
    bool Function()? shouldPause,
    bool Function()? shouldPauseJump,
    bool Function()? shouldPauseBreathing,
  }) : jumpController = AnimationController(
         duration: const Duration(milliseconds: 3000),
         vsync: vsync,
       ),
       breathingController = AnimationController(
         duration: const Duration(milliseconds: 3000),
         vsync: vsync,
       ),
       moveController = AnimationController(
         duration: const Duration(milliseconds: 1000), // 위치 업데이트 시 1초간 부드럽게 이동
         vsync: vsync,
       ),
       _shouldPause = shouldPause,
       _shouldPauseJump = shouldPauseJump,
       _shouldPauseBreathing = shouldPauseBreathing {
    // 애니메이션 초기화
    jumpAnimation = Tween<double>(begin: 0.0, end: -12.0).animate(
      CurvedAnimation(
        parent: jumpController,
        curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
      ),
    );
    breathingAnimation = Tween<double>(begin: 1.1, end: 1.0).animate(
      CurvedAnimation(
        parent: breathingController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeInOut),
      ),
    );
    _setupJumpAnimation();
    _setupBreathingAnimation();
  }

  // 점프 애니메이션 (이동 중 마커)
  final AnimationController jumpController;
  late final Animation<double> jumpAnimation;

  // 숨쉬는 애니메이션 (정지 중 마커)
  final AnimationController breathingController;
  late final Animation<double> breathingAnimation;

  // 위치 이동 애니메이션
  final AnimationController moveController;
  Animation<LatLng>? _moveAnimation;
  LatLng? _currentLatLng;

  // 상태 관리
  bool _isPaused = false;
  bool Function()? _shouldPause;
  bool Function()? _shouldPauseJump;
  bool Function()? _shouldPauseBreathing;

  /// 현재 마커의 애니메이션된 좌표 가져오기
  LatLng getPosition(LatLng staticLatLng) {
    if (_moveAnimation != null && moveController.isAnimating) {
      return _moveAnimation!.value;
    }
    return staticLatLng;
  }

  /// 좌표가 변경되었을 때 부드러운 이동 시작
  void animateTo(LatLng newLatLng) {
    if (_currentLatLng == null) {
      _currentLatLng = newLatLng;
      return;
    }

    if (_currentLatLng == newLatLng) return;

    final begin = _currentLatLng!;
    _moveAnimation = Tween<LatLng>(
      begin: begin,
      end: newLatLng,
    ).animate(CurvedAnimation(parent: moveController, curve: Curves.easeInOut));

    _currentLatLng = newLatLng;
    moveController.forward(from: 0.0);
  }

  /// 점프 애니메이션 설정
  void _setupJumpAnimation() {
    if (!_isPaused && (_shouldPause == null || !_shouldPause!())) {
      jumpController.repeat(reverse: true);
    }
  }

  /// 숨쉬는 애니메이션 설정
  void _setupBreathingAnimation() {
    if (!_isPaused && (_shouldPause == null || !_shouldPause!())) {
      breathingController.repeat(reverse: true);
    }
  }

  /// 애니메이션 일시정지
  void pause() {
    if (!_isPaused) {
      _isPaused = true;
      jumpController.stop();
      breathingController.stop();
      moveController.stop();
    }
  }

  /// 애니메이션 재개
  void resume() {
    if (_isPaused) {
      _isPaused = false;
      if (_shouldPause == null || !_shouldPause!()) {
        if (_shouldPauseJump == null || !_shouldPauseJump!()) {
          jumpController.repeat(reverse: true);
        }
        if (_shouldPauseBreathing == null || !_shouldPauseBreathing!()) {
          breathingController.repeat(reverse: true);
        }
      }
    }
  }

  /// 일시정지 조건 업데이트
  void updateShouldPause(bool Function()? shouldPause) {
    _shouldPause = shouldPause;
    if (_shouldPause != null && _shouldPause!()) {
      pause();
    } else if (_isPaused) {
      resume();
    }
  }

  void updateShouldPauseJump(bool Function()? shouldPauseJump) {
    _shouldPauseJump = shouldPauseJump;
  }

  void updateShouldPauseBreathing(bool Function()? shouldPauseBreathing) {
    _shouldPauseBreathing = shouldPauseBreathing;
  }

  /// 리소스 해제
  void dispose() {
    jumpController.dispose();
    breathingController.dispose();
    moveController.dispose();
  }
}
