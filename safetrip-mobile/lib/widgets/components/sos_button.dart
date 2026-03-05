import 'package:flutter/material.dart';
import '../../constants/app_tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// SOS 버튼 위젯
/// 56x56dp FloatingActionButton 스타일, 3초 롱프레스로 활성화.
/// 오발송 방지를 위해 3초 프로그레스 링을 표시하며,
/// 손가락을 떼면 취소된다.
///
/// 참조: 스타일 가이드 §2.2 Button_SOS, 비즈니스 원칙 §05.1
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onSosActivated,
  });

  /// SOS 3초 롱프레스 완료 시 호출되는 콜백
  final VoidCallback onSosActivated;

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
            // SOS 버튼 본체
            FloatingActionButton(
              onPressed: null, // 롱프레스로만 동작
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

            // 프로그레스 링 오버레이 (롱프레스 진행 중)
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
}
