import 'package:flutter/material.dart';
import '../../../constants/app_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../features/main/providers/main_screen_provider.dart';

/// 5단계 스냅 바텀시트 래퍼 (바텀시트 동작 규칙 §2)
///
/// [DraggableScrollableSheet]를 래핑하여 AppTokens.bottomSheetSnapPoints에
/// 정의된 5단계(collapsed/peek/half/expanded/full)로 스냅한다.
///
/// [controller]를 외부에서 주입하면 [DraggableScrollableController.animateTo]로
/// 프로그래밍적 높이 제어가 가능하다 (탭 전환, SOS, 키보드 이벤트).
class SnappingBottomSheet extends StatefulWidget {
  const SnappingBottomSheet({
    super.key,
    required this.builder,
    this.controller,
    this.initialLevel = BottomSheetLevel.half,
    this.onLevelChanged,
    this.isDragEnabled = true,
    this.onCreated,
  });

  /// 시트 내부 콘텐츠 빌더. [ScrollController]를 반드시 ListView 등에 연결해야 한다.
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  /// 외부에서 주입 가능한 DraggableScrollableController (§3, §10 제어용)
  final DraggableScrollableController? controller;

  /// 초기 시트 레벨
  final BottomSheetLevel initialLevel;

  /// 레벨 변경 콜백
  final ValueChanged<BottomSheetLevel>? onLevelChanged;

  /// 드래그 활성화 여부 (SOS 발동 시 false — §10.2)
  final bool isDragEnabled;

  /// §3.3: 시트 상태 생성 후 콜백 — 프로그래밍적 이동 표시 기능 접근용
  final void Function(void Function([Duration]) markProgrammatic)? onCreated;

  @override
  State<SnappingBottomSheet> createState() => _SnappingBottomSheetState();
}

class _SnappingBottomSheetState extends State<SnappingBottomSheet> {
  late final DraggableScrollableController _controller;
  bool _ownsController = false;

  // DraggableScrollableSheet의 snapSizes는 minChildSize/maxChildSize를 제외한 중간값만 받음
  static const _minSize = AppTokens.bottomSheetHeightCollapsed; // 0.10
  static const _maxSize = AppTokens.bottomSheetHeightExpanded; // 1.00
  static const _snapSizes = [
    AppTokens.bottomSheetHeightPeek, // 0.25
    AppTokens.bottomSheetHeightHalf, // 0.50
    AppTokens.bottomSheetHeightTall, // 0.75
  ];

  /// §3.3: 직전 안정 레벨 (전환 제약 검증용)
  BottomSheetLevel _previousStableLevel = BottomSheetLevel.half;

  /// 프로그래밍적 애니메이션 중인지 여부
  bool _isProgrammaticMove = false;

  /// §3.3: 마지막 수직 드래그 velocity (dp/s)
  double _lastDragVelocity = 0;
  double _previousSize = 0.5;
  DateTime _previousSizeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = DraggableScrollableController();
      _ownsController = true;
    }
    _controller.addListener(_onSizeChanged);
    _previousStableLevel = widget.initialLevel;
    _previousSize = widget.initialLevel.fraction;
    widget.onCreated?.call(_markProgrammaticMove);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSizeChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _markProgrammaticMove([Duration duration = const Duration(milliseconds: 300)]) {
    _isProgrammaticMove = true;
    Future.delayed(duration + const Duration(milliseconds: 50), () {
      _isProgrammaticMove = false;
    });
  }

  void _onSizeChanged() {
    if (!_controller.isAttached) return;
    final size = _controller.size;
    final now = DateTime.now();
    final level = BottomSheetLevelExt.fromFraction(size);

    // §3.3: 속도 추정 (dp/s 환산)
    final dt = now.difference(_previousSizeTime).inMilliseconds;
    if (dt > 0) {
      final screenHeight = MediaQuery.of(context).size.height;
      final deltaDp = (size - _previousSize).abs() * screenHeight;
      _lastDragVelocity = deltaDp / (dt / 1000); // dp/s
    }
    _previousSize = size;
    _previousSizeTime = now;

    // §3.3: 프로그래밍적 이동이 아닌 사용자 제스처에 의한 직접 점프 검증
    if (!_isProgrammaticMove && widget.isDragEnabled) {
      final distance = (level.index - _previousStableLevel.index).abs();
      if (distance >= 3 && _lastDragVelocity < 2000) {
        // 느린 점프 → 리다이렉트
        final redirectLevel = level.index > _previousStableLevel.index
            ? BottomSheetLevel.peek
            : BottomSheetLevel.expanded;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.isAttached) {
            const redirectDuration = Duration(milliseconds: 300);
            _isProgrammaticMove = true;
            _controller.animateTo(
              redirectLevel.fraction,
              duration: redirectDuration,
              curve: Curves.easeInOut,
            );
            Future.delayed(redirectDuration + const Duration(milliseconds: 50), () {
              _isProgrammaticMove = false;
            });
          }
        });

        widget.onLevelChanged?.call(redirectLevel);
        _previousStableLevel = redirectLevel;
        return;
      }
      // distance >= 3 && velocity >= 2000 → 직접 전환 허용 (스펙 §3.3)
    }

    _previousStableLevel = level;
    widget.onLevelChanged?.call(level);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.initialLevel.fraction,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: _snapSizes,
      snapAnimationDuration: const Duration(milliseconds: 300),
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radius24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 드래그 핸들 — isDragEnabled=false일 때도 시각적 핸들은 유지 (§10.2)
              GestureDetector(
                // SOS 잠금 시 드래그를 흡수하여 무효화
                onVerticalDragUpdate:
                    widget.isDragEnabled ? null : (_) {},
                child: Container(
                  height: 32,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // 콘텐츠
              Expanded(
                child: widget.isDragEnabled
                    ? widget.builder(context, scrollController)
                    : IgnorePointer(
                        ignoring: true,
                        child: widget.builder(context, scrollController),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
