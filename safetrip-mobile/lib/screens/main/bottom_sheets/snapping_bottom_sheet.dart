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
/// 콘텐츠 빌더가 반환하는 위젯은 반드시 전달받은 [ScrollController]를
/// 스크롤 가능 위젯(ListView, CustomScrollView 등)에 연결해야 한다.
/// 연결하지 않으면 DraggableScrollableSheet의 드래그가 동작하지 않는다.
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

  static const _minSize = AppTokens.bottomSheetHeightCollapsed; // 0.10
  static const _maxSize = AppTokens.bottomSheetHeightExpanded; // 1.00
  static const _snapSizes = [
    AppTokens.bottomSheetHeightPeek, // 0.25
    AppTokens.bottomSheetHeightHalf, // 0.50
    AppTokens.bottomSheetHeightTall, // 0.75
  ];
  static const _allSnaps = [_minSize, ..._snapSizes, _maxSize];

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

  void _markProgrammaticMove([
    Duration duration = const Duration(milliseconds: 300),
  ]) {
    // 외부에서 animateTo 호출 시 레벨 콜백 안정화를 위한 마커
    Future.delayed(duration + const Duration(milliseconds: 50), () {
      // intentionally empty — 프로그래밍적 이동 후 안정화 대기
    });
  }

  void _onSizeChanged() {
    if (!_controller.isAttached) return;
    final level = BottomSheetLevelExt.fromFraction(_controller.size);
    widget.onLevelChanged?.call(level);
  }

  /// 핸들 드래그 종료 시 velocity 기반 스냅
  void _snapToNearest(double velocity) {
    if (!_controller.isAttached) return;
    final cur = _controller.size;
    double target;

    if (velocity.abs() > 500) {
      if (velocity < 0) {
        // 위로 플릭 → 다음 큰 스냅 포인트
        target = _allSnaps.firstWhere(
          (s) => s > cur + 0.02,
          orElse: () => _maxSize,
        );
      } else {
        // 아래로 플릭 → 다음 작은 스냅 포인트
        target = _allSnaps.reversed.firstWhere(
          (s) => s < cur - 0.02,
          orElse: () => _minSize,
        );
      }
    } else {
      // 느린 드래그: 가장 가까운 스냅 포인트
      target = _allSnaps.reduce(
        (a, b) => (cur - a).abs() < (cur - b).abs() ? a : b,
      );
    }

    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
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
      snapAnimationDuration: const Duration(milliseconds: 250),
      builder: (context, scrollController) {
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radius24),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          child: Column(
            children: [
              // ── 드래그 핸들 ────────────────────────────────
              // 핸들은 DraggableScrollableSheet의 scrollController 밖이므로
              // GestureDetector로 controller.jumpTo()에 직접 연결한다.
              // isDragEnabled=false일 때는 콜백을 null로 설정하여
              // 제스처 경쟁에 참여하지 않도록 한다.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: widget.isDragEnabled
                    ? (details) {
                        if (!_controller.isAttached) return;
                        final screenH = MediaQuery.of(context).size.height;
                        final delta =
                            -(details.primaryDelta ?? 0) / screenH;
                        final next =
                            (_controller.size + delta).clamp(_minSize, _maxSize);
                        _controller.jumpTo(next);
                      }
                    : null,
                onVerticalDragEnd: widget.isDragEnabled
                    ? (details) =>
                        _snapToNearest(details.primaryVelocity ?? 0)
                    : null,
                child: SizedBox(
                  height: 28,
                  width: double.infinity,
                  child: Center(
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
              ),
              // ── 콘텐츠 ────────────────────────────────────
              Expanded(
                child: widget.isDragEnabled
                    ? widget.builder(context, scrollController)
                    : IgnorePointer(
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
