import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';

/// DOC-T3-WLC-029 §3.4 — Individual slide page with parallax effect
/// Image loading failure → color background fallback (§6.1)
class WelcomeSlidePage extends StatelessWidget {
  const WelcomeSlidePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.semanticLabel,
    this.imagePath,
    this.pageOffset = 0.0,
    this.timeOverlayColor,
    this.reducedMotion = false,
  });

  final String title;
  final String subtitle;
  final Color bgColor;
  final String semanticLabel;
  final String? imagePath;
  /// Current page offset from PageController for parallax calculation
  final double pageOffset;
  final Color? timeOverlayColor;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    // §3.4 Parallax: background moves at 0.5x speed, foreground at 1.0x
    final parallaxOffset = reducedMotion ? 0.0 : pageOffset * 100;

    return Semantics(
      label: semanticLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Background color
          Container(color: bgColor),

          // Layer 2: Time-of-day overlay (§3.2.1) — tinted, not replacing brand color
          if (timeOverlayColor != null)
            Container(
              color: timeOverlayColor!.withValues(alpha: 0.15),
            ),

          // Layer 3: Image (parallax at 0.5x) with fallback (§6.1)
          if (imagePath != null)
            Transform.translate(
              offset: Offset(parallaxOffset * 0.5, 0),
              child: Opacity(
                opacity: 0.3,
                child: Image.asset(
                  imagePath!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

          // Layer 4: Dark scrim for WCAG AA contrast (§3.5)
          // Ensures white text meets 4.5:1 ratio even on bright backgrounds
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.15),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Layer 5: Content (parallax at 1.0x for depth effect)
          Transform.translate(
            offset: Offset(parallaxOffset, 0),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title (H1 level — §3.4 Typography)
                    Text(
                      title,
                      style: AppTypography.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Subtitle (H2 level)
                    Text(
                      subtitle,
                      style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
