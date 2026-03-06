import 'package:flutter/material.dart';

/// DOC-T3-WLC-029 §3.4 — Slide indicator dots
/// Current slide: 1.5x scale + color accent
class WelcomeDotIndicator extends StatelessWidget {
  const WelcomeDotIndicator({
    super.key,
    required this.count,
    required this.current,
    this.activeColor = Colors.white,
    this.inactiveColor,
  });

  final int count;
  final int current;
  final Color activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '슬라이드 ${current + 1} / $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            // §3.4: active dot 1.5x scale (8→12), width elongated
            width: isActive ? 24 : 8,
            height: isActive ? 12 : 8,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor
                  : (inactiveColor ?? Colors.white.withValues(alpha: 0.38)),
              borderRadius: BorderRadius.circular(isActive ? 6 : 4),
            ),
          );
        }),
      ),
    );
  }
}
