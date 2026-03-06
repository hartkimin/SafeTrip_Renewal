import 'package:flutter/material.dart';
import '../../constants/app_tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// SOS 버튼 위젯 (바텀시트 동작 규칙 §10)
///
/// - 비활성 모드: 56x56dp, 3초 롱프레스로 SOS 발동
/// - 활성 모드(`isSosActive=true`): "해제" 버튼으로 전환, 탭으로 SOS 해제 (§10.2)
///
/// 참조: 스타일 가이드 §2.2 Button_SOS, 비즈니스 원칙 §05.1
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onSosActivated,
    this.onSosDeactivated,
    this.isSosActive = false,
  });

  /// SOS 3초 롱프레스 완료 시 호출되는 콜백
  final VoidCallback onSosActivated;

  /// SOS 해제 버튼 탭 시 호출되는 콜백 (§10.3)
  final VoidCallback? onSosDeactivated;

  /// SOS 활성 상태 — true이면 "해제" 버튼으로 전환 (§10.2)
  final bool isSosActive;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isPressing = false;

  static const Duration _longPressDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _longPressDuration,
    );
    _controller.addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _isPressing = false);
      widget.onSosActivated();
    }
  }

  void _onPressStart() {
    setState(() => _isPressing = true);
    _controller.forward(from: 0.0);
  }

  void _onPressCancel() {
    if (_isPressing) {
      setState(() => _isPressing = false);
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    // §10.2: SOS 활성 시 해제 버튼으로 전환
    if (widget.isSosActive) {
      return _buildDeactivateButton();
    }
    return _buildActivateButton();
  }

  /// SOS 발동 버튼 (3초 롱프레스)
  Widget _buildActivateButton() {
    return GestureDetector(
      onLongPressStart: (_) => _onPressStart(),
      onLongPressEnd: (_) => _onPressCancel(),
      onLongPressCancel: _onPressCancel,
      child: SizedBox(
        width: AppSpacing.sosButtonSize,
        height: AppSpacing.sosButtonSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FloatingActionButton(
              onPressed: null,
              elevation: 4,
              backgroundColor: AppColors.sosDanger,
              shape: const CircleBorder(),
              child: Text(
                'SOS',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize16,
                  fontWeight: AppTokens.fontWeightBold,
                  color: AppColors.sosText,
                ),
              ),
            ),
            if (_isPressing)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return SizedBox(
                    width: AppSpacing.sosButtonSize,
                    height: AppSpacing.sosButtonSize,
                    child: CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 3.0,
                      color: AppColors.sosText,
                      backgroundColor:
                          AppColors.sosText.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// SOS 해제 버튼 (§10.2 — 탭으로 해제)
  Widget _buildDeactivateButton() {
    return SizedBox(
      width: AppSpacing.sosButtonSize,
      height: AppSpacing.sosButtonSize,
      child: FloatingActionButton(
        onPressed: widget.onSosDeactivated,
        elevation: 4,
        backgroundColor: AppColors.surface,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.sosDanger, width: 2),
        ),
        child: Text(
          '해제',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            fontWeight: AppTokens.fontWeightBold,
            color: AppColors.sosDanger,
          ),
        ),
      ),
    );
  }
}
