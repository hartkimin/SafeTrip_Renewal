import 'package:flutter/material.dart';
import '../../l10n/welcome_strings.dart';

/// DOC-T3-WLC-029 §3.4 — Slide indicator dots
/// Current slide: 1.5x scale + color accent
/// §3.2: Dots are tappable for manual slide navigation
class WelcomeDotIndicator extends StatelessWidget {
  const WelcomeDotIndicator({
    super.key,
    required this.count,
    required this.current,
    this.onDotTap,
    this.activeColor = Colors.white,
    this.inactiveColor,
  });

  final int count;
  final int current;
  /// §3.2: "수동 전환: 좌우 스와이프 또는 인디케이터 도트 탭"
  final ValueChanged<int>? onDotTap;
  final Color activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: WelcomeStrings.dotSemantics(current + 1, count),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return GestureDetector(
            onTap: onDotTap != null ? () => onDotTap!(i) : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // §3.5: Ensure minimum 44dp tap area
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                // §3.4: active dot 1.5x scale (8→12), width elongated
                width: isActive ? 24 : 8,
                height: isActive ? 12 : 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor
                      : (inactiveColor ?? Colors.white.withValues(alpha: 0.38)),
                  borderRadius: BorderRadius.circular(isActive ? 6 : 4),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
