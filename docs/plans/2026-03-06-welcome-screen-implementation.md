# Welcome Screen Full-Spec Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring the existing welcome and purpose-select screens into full compliance with DOC-T3-WLC-029 v1.2, covering all P0–P3 features including auto-advance timer, parallax, time-of-day color overlay, accessibility, i18n, A/B testing, and analytics.

**Architecture:** Incremental enhancement of existing `screen_welcome.dart` and `screen_purpose_select.dart` within `features/onboarding/`. New extracted widgets for slide pages and dot indicators. New utility files for i18n strings, A/B test assignment, and analytics events. Router redirect fix for deep link → Phase 3 direct routing.

**Tech Stack:** Flutter 3.10+, GoRouter 14.x, Riverpod 2.x, SharedPreferences, AppLinks, existing AppColors/AppTypography/AppSpacing design system.

---

## Task 1: Create i18n Strings Map (§3.7)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/l10n/welcome_strings.dart`

**Step 1: Create the localized strings file**

```dart
import 'dart:ui';

/// DOC-T3-WLC-029 §3.7 — 3-language welcome screen copy
/// Locale detection: device locale → fallback to Korean
class WelcomeStrings {
  WelcomeStrings._();

  static const _ko = 'ko';
  static const _en = 'en';
  static const _ja = 'ja';

  /// Get current language key from device locale
  static String _langKey() {
    final locale = PlatformDispatcher.instance.locale;
    final lang = locale.languageCode;
    if (lang == _en) return _en;
    if (lang == _ja) return _ja;
    return _ko; // fallback
  }

  // ─ Slide titles (§3.2 Phase 2) ─────────────────────────────────
  static const _slideTitles = {
    _ko: ['여행, 더 안전하게', '일정부터 위치까지, 함께', '누군가 지켜보고 있어요', '지금 시작하세요'],
    _en: ['Travel, Safer Together', 'Plans to Location, All in One', "Someone's Got Your Back", 'Get Started Now'],
    _ja: ['旅行を、もっと安全に', 'スケジュールから位置情報まで、一緒に', '誰かが見守っています', '今すぐ始めましょう'],
  };

  static const _slideSubtitles = {
    _ko: [
      'SafeTrip과 함께라면\n어디든 안심하고 떠날 수 있어요',
      '멤버들의 실시간 위치와\n여행 일정을 한눈에 확인하세요',
      '가디언 기능을 통해\n소중한 사람의 안전을 지켜주세요',
      'SafeTrip으로 더 즐겁고\n안전한 여행을 시작해볼까요?',
    ],
    _en: [
      'With SafeTrip, travel anywhere\nwith peace of mind',
      'Check real-time locations\nand trip schedules at a glance',
      'Keep your loved ones safe\nwith the Guardian feature',
      'Ready to start a safer\nand more enjoyable trip?',
    ],
    _ja: [
      'SafeTripと一緒なら\nどこでも安心して出発できます',
      'メンバーのリアルタイム位置と\n旅行スケジュールを一目で確認',
      'ガーディアン機能で\n大切な人の安全を守りましょう',
      'SafeTripでもっと楽しく\n安全な旅を始めませんか？',
    ],
  };

  // ─ Slide accessibility labels (§3.5) ───────────────────────────
  static const _slideSemantics = {
    _ko: [
      '슬라이드 1: 여행 안전을 상징하는 방패 일러스트',
      '슬라이드 2: 함께하는 여행을 상징하는 그룹 일러스트',
      '슬라이드 3: 보호를 상징하는 가디언 일러스트',
      '슬라이드 4: SafeTrip 시작하기',
    ],
    _en: [
      'Slide 1: Shield illustration symbolizing travel safety',
      'Slide 2: Group illustration symbolizing traveling together',
      'Slide 3: Guardian illustration symbolizing protection',
      'Slide 4: Get started with SafeTrip',
    ],
    _ja: [
      'スライド1：旅行の安全を象徴する盾のイラスト',
      'スライド2：一緒に旅行することを象徴するグループイラスト',
      'スライド3：保護を象徴するガーディアンイラスト',
      'スライド4：SafeTripを始めましょう',
    ],
  };

  // ─ Button / UI strings ──────────────────────────────────────────
  static const _skip = {_ko: '건너뛰기', _en: 'Skip', _ja: 'スキップ'};
  static const _next = {_ko: '다음', _en: 'Next', _ja: '次へ'};
  static const _getStarted = {_ko: '시작하기', _en: 'Get Started', _ja: '始める'};

  // Purpose select (§3.2 Phase 3)
  static const _purposeTitle = {
    _ko: '어떤 목적으로 SafeTrip을\n사용하시나요?',
    _en: 'How would you like to\nuse SafeTrip?',
    _ja: 'SafeTripをどのように\nお使いになりますか？',
  };
  static const _createTrip = {_ko: '여행 만들기', _en: 'Create a Trip', _ja: '旅行を作成'};
  static const _enterCode = {_ko: '초대코드 입력', _en: 'Enter Invite Code', _ja: '招待コードを入力'};
  static const _demoTour = {_ko: '먼저 둘러보기', _en: 'Explore First', _ja: 'まず見てみる'};
  static const _guardianJoin = {_ko: '가디언으로 참여', _en: 'Join as Guardian', _ja: 'ガーディアンとして参加'};
  static const _demoTourLink = {_ko: '로그인 없이 먼저 둘러보기', _en: 'Explore without signing in', _ja: 'ログインなしで見てみる'};
  static const _inviteCodeManualHint = {
    _ko: '초대코드를 직접 입력해 주세요.',
    _en: 'Please enter the invite code manually.',
    _ja: '招待コードを直接入力してください。',
  };

  // ─ Public getters ──────────────────────────────────────────────
  static List<String> get slideTitles => _slideTitles[_langKey()]!;
  static List<String> get slideSubtitles => _slideSubtitles[_langKey()]!;
  static List<String> get slideSemantics => _slideSemantics[_langKey()]!;
  static String get skip => _skip[_langKey()]!;
  static String get next => _next[_langKey()]!;
  static String get getStarted => _getStarted[_langKey()]!;
  static String get purposeTitle => _purposeTitle[_langKey()]!;
  static String get createTrip => _createTrip[_langKey()]!;
  static String get enterCode => _enterCode[_langKey()]!;
  static String get demoTour => _demoTour[_langKey()]!;
  static String get guardianJoin => _guardianJoin[_langKey()]!;
  static String get demoTourLink => _demoTourLink[_langKey()]!;
  static String get inviteCodeManualHint => _inviteCodeManualHint[_langKey()]!;
}
```

**Step 2: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/features/onboarding/l10n/welcome_strings.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/onboarding/l10n/welcome_strings.dart
git commit -m "feat(welcome): add i18n strings for KO/EN/JP (DOC-T3-WLC-029 §3.7)"
```

---

## Task 2: Create A/B Test Service (§3.6)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/data/ab_test_service.dart`

**Step 1: Create the A/B test service**

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// DOC-T3-WLC-029 §3.6 — Device ID hash-based A/B test variant assignment
/// Same device always gets same variant (deterministic).
enum WelcomeAbVariant { a, b }

class WelcomeAbTestService {
  WelcomeAbTestService._();

  static WelcomeAbVariant? _cached;

  /// Get the A/B variant for this device.
  /// Uses stored device_id hash for deterministic assignment.
  static Future<WelcomeAbVariant> getVariant() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('user_id') ??
        prefs.getString('device_id') ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Deterministic hash → variant
    final hash = deviceId.hashCode.abs();
    _cached = hash % 2 == 0 ? WelcomeAbVariant.a : WelcomeAbVariant.b;
    return _cached!;
  }

  /// A/B test variables (§3.6 table)
  static int slideCount(WelcomeAbVariant v) => v == WelcomeAbVariant.a ? 4 : 3;
  static String ctaText(WelcomeAbVariant v) => v == WelcomeAbVariant.a ? 'default' : 'safety';
}
```

**Step 2: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/features/onboarding/data/ab_test_service.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/onboarding/data/ab_test_service.dart
git commit -m "feat(welcome): add A/B test service with device-hash variant (DOC-T3-WLC-029 §3.6)"
```

---

## Task 3: Create Analytics Event Service (§7.3)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/data/welcome_analytics.dart`

**Step 1: Create analytics event service**

```dart
import 'package:flutter/foundation.dart';

/// DOC-T3-WLC-029 §7.3 — Welcome screen analytics events
/// Currently logs to debug console. Swap with Firebase Analytics when ready.
class WelcomeAnalytics {
  WelcomeAnalytics._();

  static void welcomeView({
    required String abVariant,
    required String timeOfDay,
    required bool deeplinkPresent,
  }) {
    _log('welcome_view', {
      'ab_variant': abVariant,
      'time_of_day': timeOfDay,
      'deeplink_present': deeplinkPresent.toString(),
    });
  }

  static void slideViewed({
    required int slideIndex,
    required bool autoAdvance,
  }) {
    _log('slide_viewed', {
      'slide_index': slideIndex.toString(),
      'auto_or_manual': autoAdvance ? 'auto' : 'manual',
    });
  }

  static void slideSkipped({required int skippedAtSlide}) {
    _log('slide_skipped', {
      'skipped_at_slide': skippedAtSlide.toString(),
    });
  }

  static void purposeSelected({required String purpose}) {
    _log('purpose_selected', {
      'purpose': purpose,
    });
  }

  static void _log(String eventName, Map<String, String> params) {
    debugPrint('[WelcomeAnalytics] $eventName: $params');
    // TODO: Replace with FirebaseAnalytics.instance.logEvent() when integrated
  }
}
```

**Step 2: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/features/onboarding/data/welcome_analytics.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/onboarding/data/welcome_analytics.dart
git commit -m "feat(welcome): add analytics event service (DOC-T3-WLC-029 §7.3)"
```

---

## Task 4: Add Time-of-Day Color Constants (§3.2.1)

**Files:**
- Modify: `safetrip-mobile/lib/core/theme/app_colors.dart`

**Step 1: Add time-of-day colors to AppColors**

Add the following block after the existing `sosText` line (around line 83):

```dart
  // ─ 시간대별 감성 색상 (DOC-T3-WLC-029 §3.2.1) ────────────────
  /// Morning (07:00~12:00): 밝은 하늘색, 상쾌함·설렘
  static const Color timeOfDayMorning = Color(0xFF87CEEB);
  /// Afternoon (12:00~18:00): 따뜻한 노랑, 활기·에너지
  static const Color timeOfDayAfternoon = Color(0xFFFFC947);
  /// Night (18:00~07:00): 딥 네이비, 안정감·신뢰
  static const Color timeOfDayNight = Color(0xFF0D1B2A);

  /// Get time-of-day overlay color based on local device time
  static Color timeOfDayOverlay() {
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 12) return timeOfDayMorning;
    if (hour >= 12 && hour < 18) return timeOfDayAfternoon;
    return timeOfDayNight;
  }

  /// Get time-of-day name for analytics
  static String timeOfDayName() {
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 18) return 'afternoon';
    return 'night';
  }
```

**Step 2: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/core/theme/app_colors.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/core/theme/app_colors.dart
git commit -m "feat(theme): add time-of-day color constants (DOC-T3-WLC-029 §3.2.1)"
```

---

## Task 5: Extract Dot Indicator Widget (§3.4)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/presentation/widgets/welcome_dot_indicator.dart`

**Step 1: Create extracted dot indicator with 1.5x scale spec**

```dart
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
```

**Step 2: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/features/onboarding/presentation/widgets/welcome_dot_indicator.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/onboarding/presentation/widgets/welcome_dot_indicator.dart
git commit -m "feat(welcome): extract dot indicator widget with 1.5x scale (DOC-T3-WLC-029 §3.4)"
```

---

## Task 6: Extract Slide Page Widget with Parallax (§3.4)

**Files:**
- Create: `safetrip-mobile/lib/features/onboarding/presentation/widgets/welcome_slide_page.dart`

**Step 1: Create slide page widget with parallax and image support**

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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

          // Layer 4: Content (parallax at 1.0x for depth effect)
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
                        color: Colors.white.withValues(alpha: 0.85),
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
```

**Step 2: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/features/onboarding/presentation/widgets/welcome_slide_page.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/onboarding/presentation/widgets/welcome_slide_page.dart
git commit -m "feat(welcome): add slide page widget with parallax and image fallback (DOC-T3-WLC-029 §3.4)"
```

---

## Task 7: Rewrite ScreenWelcome — Full Spec (§3.2, §3.4, §3.5, §3.6, §3.7, §3.8, §7.3)

This is the main task. The existing `screen_welcome.dart` gets fully rewritten.

**Files:**
- Modify: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_welcome.dart`

**Step 1: Rewrite the complete welcome screen**

Replace the entire contents of `screen_welcome.dart` with:

```dart
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
        setState(() {
          _pageOffset = (_pageController.page ?? 0) - _currentPage;
        });
      });

    _initAbVariant();
    _startAutoAdvance();

    // Analytics: welcome_view (§7.3)
    WelcomeAnalytics.welcomeView(
      abVariant: _abVariant.name,
      timeOfDay: AppColors.timeOfDayName(),
      deeplinkPresent: false, // deep link users skip welcome entirely
    );
  }

  Future<void> _initAbVariant() async {
    final variant = await WelcomeAbTestService.getVariant();
    if (mounted) setState(() => _abVariant = variant);
  }

  /// §3.2: Auto-advance every 5 seconds when no user interaction
  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isLastPage && mounted) {
        _pageController.nextPage(
          duration: _reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        // Analytics: auto-advance
        WelcomeAnalytics.slideViewed(
          slideIndex: _currentPage + 1,
          autoAdvance: true,
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
                setState(() => _currentPage = i);
                WelcomeAnalytics.slideViewed(
                  slideIndex: i,
                  autoAdvance: false,
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
                // Dot indicator (§3.4)
                WelcomeDotIndicator(
                  count: _slideCount,
                  current: _currentPage,
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
```

**Step 2: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/features/onboarding/presentation/screens/screen_welcome.dart`
Expected: No errors (or only warnings about unused imports from other files)

**Step 3: Commit**

```bash
git add lib/features/onboarding/presentation/screens/screen_welcome.dart
git commit -m "feat(welcome): rewrite with auto-timer, parallax, time-color, a11y, i18n (DOC-T3-WLC-029)"
```

---

## Task 8: Rewrite ScreenPurposeSelect — Full Spec (§3.2 Phase 3)

**Files:**
- Modify: `safetrip-mobile/lib/features/onboarding/presentation/screens/screen_purpose_select.dart`

**Step 1: Rewrite with i18n, analytics, accessibility**

Replace the entire contents of `screen_purpose_select.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../router/route_paths.dart';
import '../../data/welcome_analytics.dart';
import '../../l10n/welcome_strings.dart';

/// DOC-T3-WLC-029 §3.2 Phase 3 — Purpose Selection Screen
/// W4: Role-based purpose selection without exposing internal role terms
/// W5: Zero frustration — every choice leads to a valid path
class ScreenPurposeSelect extends StatelessWidget {
  const ScreenPurposeSelect({super.key});

  void _onRoleSelected(BuildContext context, String role) {
    WelcomeAnalytics.purposeSelected(purpose: role);
    context.push(RoutePaths.authPhone, extra: {'role': role});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),

              // Logo
              Semantics(
                label: 'SafeTrip 로고',
                child: Image.asset(
                  'assets/images/logo-L.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Question (§3.2 Phase 3)
              Text(
                WelcomeStrings.purposeTitle,
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 1. 여행 만들기 (Captain) — Primary CTA
              _PurposeButton(
                icon: '✈️',
                label: WelcomeStrings.createTrip,
                semanticLabel: '${WelcomeStrings.createTrip} 버튼',
                onTap: () => _onRoleSelected(context, 'captain'),
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. 초대코드 입력 (Crew)
              _PurposeButton(
                icon: '🔑',
                label: WelcomeStrings.enterCode,
                semanticLabel: '${WelcomeStrings.enterCode} 버튼',
                isSecondary: true,
                onTap: () {
                  WelcomeAnalytics.purposeSelected(purpose: 'join_trip');
                  context.push(RoutePaths.tripJoin);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. 먼저 둘러보기 (Demo)
              _PurposeButton(
                icon: '👀',
                label: WelcomeStrings.demoTour,
                semanticLabel: '${WelcomeStrings.demoTour} 버튼',
                isOutlined: true,
                onTap: () {
                  WelcomeAnalytics.purposeSelected(purpose: 'demo');
                  context.go(RoutePaths.tripDemo);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. 가디언으로 참여 (§3.2, §03.1 free guardian direct entry)
              Semantics(
                button: true,
                label: '${WelcomeStrings.guardianJoin} 링크',
                child: TextButton(
                  onPressed: () => _onRoleSelected(context, 'guardian'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      AppSpacing.minTouchTarget,
                      AppSpacing.minTouchTarget,
                    ),
                  ),
                  child: Text(
                    '${WelcomeStrings.guardianJoin} →',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable purpose button with consistent styling
class _PurposeButton extends StatelessWidget {
  const _PurposeButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.isSecondary = false,
    this.isOutlined = false,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String semanticLabel;
  final bool isSecondary;
  final bool isOutlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: double.infinity,
        height: AppSpacing.buttonHeight + 4,
        child: isOutlined
            ? OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radius16),
                  ),
                ),
                child: _content(AppColors.textPrimary),
              )
            : ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSecondary
                      ? AppColors.textPrimary
                      : AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radius16),
                  ),
                ),
                child: _content(Colors.white),
              ),
      ),
    );
  }

  Widget _content(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
```

**Step 2: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/features/onboarding/presentation/screens/screen_purpose_select.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/features/onboarding/presentation/screens/screen_purpose_select.dart
git commit -m "feat(welcome): rewrite purpose select with i18n, analytics, a11y (DOC-T3-WLC-029 §3.2 Phase 3)"
```

---

## Task 9: Fix Deep Link Routing — Phase 3 Direct (§3.2 Phase 1)

**Files:**
- Modify: `safetrip-mobile/lib/router/app_router.dart` (lines 233-244)

**Context:** Currently, deep link invite code routes unauthenticated users directly to `authPhone`. The spec (§3.2 Phase 1) says invite code users should go to Phase 3 (purpose select / trip join) with auto-fill. However, since the user must authenticate before joining a trip, the correct flow per spec is: deep link → skip slides → Phase 3 purpose select (with `tripJoin` auto-navigated for invite codes). The key change: `pendingInviteCode` should route to `onboardingPurpose` for first-launch users (not authPhone), and the purpose-select screen should detect the pending code and auto-navigate to trip join.

**Step 1: Modify the redirect logic in app_router.dart**

Find the block in `_redirect` method (around line 233-244):

```dart
      if (!isAuth) {
        // Check for deep link scenarios (§4.3)
        if (authNotifier.pendingInviteCode != null) {
          return RoutePaths.authPhone; // invite code → auth first
        }
        if (authNotifier.pendingGuardianCode != null) {
          return RoutePaths.authPhone; // guardian → auth first
        }
        // Route A: new user / Route B: returning unauthenticated (§4.1)
        return authNotifier.isFirstLaunch
            ? RoutePaths.onboardingWelcome
            : RoutePaths.onboardingPurpose;
      }
```

Replace with:

```dart
      if (!isAuth) {
        // DOC-T3-WLC-029 §3.2 Phase 1: Deep link context detection
        if (authNotifier.pendingInviteCode != null) {
          // Invite code → skip slides, go to Phase 3 (purpose/trip-join)
          // tripJoin screen handles auto-fill from pendingInviteCode
          return RoutePaths.tripJoin;
        }
        if (authNotifier.pendingGuardianCode != null) {
          // Guardian code → skip slides, go to auth (guardian needs account)
          return RoutePaths.authPhone;
        }
        // Route A: new user → welcome slides / Route B: returning → purpose
        return authNotifier.isFirstLaunch
            ? RoutePaths.onboardingWelcome
            : RoutePaths.onboardingPurpose;
      }
```

**Step 2: Update tripJoin route to handle unauthenticated invite code users**

In the `_redirect` method, ensure tripJoin is NOT blocked for unauthenticated users with a pending invite code. The existing `onboardingPaths` guard only blocks onboarding routes for fully-onboarded auth users, so `tripJoin` (which is `/trip/join`) should pass through. Verify this by reading the existing redirect logic — no additional change needed since `tripJoin` is not in `onboardingPaths`.

**Step 3: Verify file compiles**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze lib/router/app_router.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/router/app_router.dart
git commit -m "fix(router): deep link invite → Phase 3 direct, not authPhone (DOC-T3-WLC-029 §3.2)"
```

---

## Task 10: Update TripJoin Screen for Deep Link Auto-Fill (§3.2 Phase 3)

**Files:**
- Modify: `safetrip-mobile/lib/screens/trip/screen_trip_join_code.dart`

**Step 1: Read the current trip join screen**

Read `screen_trip_join_code.dart` to understand how invite codes are currently entered.

**Step 2: Add pendingInviteCode auto-fill**

The trip join screen needs to:
1. Check `AuthNotifier.pendingInviteCode` on init
2. If present, auto-fill the text field and show a toast: "초대코드를 직접 입력해 주세요." (if code parsing failed) or auto-submit
3. Clear the pending code after use

The exact code depends on the current screen implementation. The key pattern:

```dart
@override
void initState() {
  super.initState();
  // DOC-T3-WLC-029 §3.2: Deep link auto-fill
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final authNotifier = /* get from context or provider */;
    final pendingCode = authNotifier.pendingInviteCode;
    if (pendingCode != null && pendingCode.isNotEmpty) {
      _codeController.text = pendingCode;
      authNotifier.clearPendingInviteCode();
    }
  });
}
```

**Step 3: Verify file compiles and commit**

```bash
git add lib/screens/trip/screen_trip_join_code.dart
git commit -m "feat(trip-join): auto-fill invite code from deep link (DOC-T3-WLC-029 §3.2)"
```

---

## Task 11: Write Widget Tests

**Files:**
- Create: `safetrip-mobile/test/widgets/welcome_screen_test.dart`
- Create: `safetrip-mobile/test/widgets/purpose_select_test.dart`

**Step 1: Write welcome screen widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/onboarding/presentation/widgets/welcome_dot_indicator.dart';

void main() {
  group('WelcomeDotIndicator', () {
    testWidgets('renders correct number of dots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WelcomeDotIndicator(count: 4, current: 0),
          ),
        ),
      );

      // 4 AnimatedContainers for 4 dots
      final containers = find.byType(AnimatedContainer);
      expect(containers, findsNWidgets(4));
    });

    testWidgets('active dot has larger width', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WelcomeDotIndicator(count: 4, current: 1),
          ),
        ),
      );

      // Verify semantics label
      expect(find.bySemanticsLabel('슬라이드 2 / 4'), findsOneWidget);
    });
  });
}
```

**Step 2: Run tests**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter test test/widgets/welcome_screen_test.dart`
Expected: All tests pass

**Step 3: Write purpose select test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/features/onboarding/l10n/welcome_strings.dart';

void main() {
  group('WelcomeStrings', () {
    test('Korean strings have 4 slide titles', () {
      // Default locale in test is usually 'en', but fallback is Korean
      final titles = WelcomeStrings.slideTitles;
      expect(titles.length, 4);
    });

    test('all string lists have matching lengths', () {
      final titles = WelcomeStrings.slideTitles;
      final subtitles = WelcomeStrings.slideSubtitles;
      final semantics = WelcomeStrings.slideSemantics;
      expect(titles.length, subtitles.length);
      expect(titles.length, semantics.length);
    });
  });
}
```

**Step 4: Run all tests**

Run: `cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter test test/widgets/`
Expected: All tests pass

**Step 5: Commit**

```bash
git add test/widgets/welcome_screen_test.dart test/widgets/purpose_select_test.dart
git commit -m "test(welcome): add widget tests for dot indicator and i18n strings"
```

---

## Task 12: Verification Round (5 Iterations per User Request)

After all implementation tasks are complete, run through the DOC-T3-WLC-029 §10 verification checklist 5 times.

**Checklist items (12 total from §10):**

| # | Item | How to verify |
|---|------|---------------|
| 1 | New user → welcome screen displays | `flutter run` → fresh install → splash → welcome slides appear |
| 2 | Returning user → main screen direct | Set `auth_verified_at` in SharedPreferences → restart → no welcome |
| 3 | Deep link invite → code auto-filled | `adb shell am start -a android.intent.action.VIEW -d "safetrip://invite?code=TEST123"` |
| 4 | "여행 만들기" → captain onboarding | Tap button → verify authPhone screen with role=captain |
| 5 | "초대코드 입력" → invite code screen | Tap button → verify tripJoin screen |
| 6 | "먼저 둘러보기" → demo tour | Tap button → verify demo screen |
| 7 | "가디언으로 참여" → guardian onboarding | Tap link → verify authPhone with role=guardian |
| 8 | Slides auto-advance every 5s | Wait and observe timer-driven transitions |
| 9 | Skip → purpose select immediately | Tap "건너뛰기" → verify purpose select screen |
| 10 | Image load failure → color fallback | Temporarily rename image file → verify color background |
| 11 | WCAG AA color contrast | Check white text on Navy(#1A3A5C), Mint(#00BFA5), Coral(#FF6B6B) |
| 12 | Offline → slides + purpose render | Enable airplane mode → verify screens render |

**Each round:**
1. Run `flutter analyze` — zero errors
2. Run `flutter test` — all pass
3. Walk through the 12 checklist items
4. Log any issues found → fix → re-verify
5. Mark round as complete

**Step 1: Run static analysis**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter analyze
```

**Step 2: Run all tests**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile && flutter test
```

**Step 3: Walk through checklist items 1-12**

For each item, verify on emulator or device. Fix any failures before proceeding.

**Step 4: Repeat steps 1-3 for rounds 2-5**

**Step 5: Final commit after all rounds pass**

```bash
git add -A
git commit -m "verify(welcome): all 12 DOC-T3-WLC-029 §10 checklist items passed (5 rounds)"
```
