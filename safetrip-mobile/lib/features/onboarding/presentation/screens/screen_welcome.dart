import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../router/route_paths.dart';
import '../../data/ab_test_service.dart';
import '../../data/welcome_analytics.dart';
import '../../l10n/welcome_strings.dart';
import '../widgets/welcome_dot_indicator.dart';
import '../widgets/welcome_slide_page.dart';

/// DOC-T3-WLC-029 — Welcome Screen (Phase 2: Value Proposition Slides)
/// W1: 3-second value delivery
/// W2: Emotion first — Safety → Connection → Protection → CTA
/// W5: Zero frustration — skip always available
class ScreenWelcome extends StatefulWidget {
  const ScreenWelcome({super.key});

  @override
  State<ScreenWelcome> createState() => _ScreenWelcomeState();
}

class _ScreenWelcomeState extends State<ScreenWelcome> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;
  double _pageOffset = 0.0;
  bool _reducedMotion = false;
  WelcomeAbVariant _abVariant = WelcomeAbVariant.a;
  bool _isAutoAdvancing = false;

  // §3.2 Phase 2 slide data — colors fixed per spec
  static const _slideColors = [
    Color(0xFF1A3A5C), // Navy — 안전
    Color(0xFF00BFA5), // Mint — 연결
    Color(0xFFFF6B6B), // Coral — 보호
    AppColors.primaryTeal, // Brand — CTA
  ];

  static const _slideImages = [
    'assets/images/image-onboarding_01.png',
    'assets/images/image-onboarding_02.png',
    'assets/images/image-onboarding_03.png',
    'assets/images/image-onboarding_04.png',
  ];

  int get _slideCount => WelcomeAbTestService.slideCount(_abVariant);
  bool get _isLastPage => _currentPage == _slideCount - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController()
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          _pageOffset = (_pageController.page ?? 0) - _currentPage;
        });
      });

    _initAbVariant();
    _startAutoAdvance();
  }

  Future<void> _initAbVariant() async {
    final variant = await WelcomeAbTestService.getVariant();
    if (!mounted) return;
    setState(() => _abVariant = variant);

    // Analytics: welcome_view (§7.3) — fires after A/B variant is resolved
    WelcomeAnalytics.welcomeView(
      abVariant: variant.name,
      timeOfDay: AppColors.timeOfDayName(),
      deeplinkPresent: false,
    );
  }

  /// §3.2: Auto-advance every 5 seconds when no user interaction
  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isLastPage && mounted) {
        _isAutoAdvancing = true;
        _pageController.nextPage(
          duration: _reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _autoAdvanceTimer?.cancel();
      }
    });
  }

  /// Reset timer on manual interaction
  void _resetAutoAdvance() {
    _startAutoAdvance();
  }

  void _goNext() {
    if (!_isLastPage) {
      _pageController.nextPage(
        duration: _reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(RoutePaths.onboardingPurpose);
    }
  }

  /// §3.2: Navigate to specific slide via dot indicator tap
  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: _reducedMotion ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _resetAutoAdvance();
  }

  void _skip() {
    WelcomeAnalytics.slideSkipped(skippedAtSlide: _currentPage);
    context.go(RoutePaths.onboardingPurpose);
  }

  @override
  Widget build(BuildContext context) {
    // §3.5: Detect reduced motion preference
    _reducedMotion = MediaQuery.of(context).disableAnimations;

    final timeOverlay = AppColors.timeOfDayOverlay();
    final titles = WelcomeStrings.slideTitles;
    final subtitles = WelcomeStrings.slideSubtitles;
    final semantics = WelcomeStrings.slideSemantics;

    return Scaffold(
      body: Stack(
        children: [
          // ── Slides (PageView) ──────────────────────────────────
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _resetAutoAdvance();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) {
                final wasAutoAdvance = _isAutoAdvancing;
                _isAutoAdvancing = false;
                setState(() => _currentPage = i);
                WelcomeAnalytics.slideViewed(
                  slideIndex: i,
                  autoAdvance: wasAutoAdvance,
                );
              },
              itemCount: _slideCount,
              itemBuilder: (_, index) => WelcomeSlidePage(
                title: titles[index],
                subtitle: subtitles[index],
                bgColor: _slideColors[index],
                semanticLabel: semantics[index],
                imagePath: _slideImages[index],
                pageOffset: index == _currentPage ? _pageOffset : 0.0,
                timeOverlayColor: timeOverlay,
                reducedMotion: _reducedMotion,
              ),
            ),
          ),

          // ── Skip button (top-right, not on last page) ──────────
          if (!_isLastPage)
            Positioned(
              top: MediaQuery.of(context).padding.top + AppSpacing.sm,
              right: AppSpacing.md,
              child: Semantics(
                button: true,
                label: WelcomeStrings.skip,
                child: TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppSpacing.minTouchTarget,
                      AppSpacing.minTouchTarget,
                    ),
                  ),
                  child: Text(
                    WelcomeStrings.skip,
                    style: AppTypography.bodyMedium
                        .copyWith(color: Colors.white70),
                  ),
                ),
              ),
            ),

          // ── Bottom controls ────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Dot indicator (§3.4) — tappable per §3.2
                WelcomeDotIndicator(
                  count: _slideCount,
                  current: _currentPage,
                  onDotTap: _goToPage,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Main action button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _slideColors[_currentPage],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radius16,
                          ),
                        ),
                      ),
                      child: Text(
                        _isLastPage
                            ? WelcomeStrings.getStarted
                            : WelcomeStrings.next,
                        style: AppTypography.labelLarge.copyWith(
                          color: _slideColors[_currentPage],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // Demo tour link (last page only, same as Phase 3's demo button)
                if (_isLastPage) ...[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    button: true,
                    label: WelcomeStrings.demoTourLink,
                    child: TextButton(
                      onPressed: () {
                        WelcomeAnalytics.purposeSelected(purpose: 'demo');
                        context.go(RoutePaths.tripDemo);
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          AppSpacing.minTouchTarget,
                          AppSpacing.minTouchTarget,
                        ),
                      ),
                      child: Text(
                        WelcomeStrings.demoTourLink,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}
