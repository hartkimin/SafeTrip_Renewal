import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../router/route_paths.dart';

/// A-02 Onboarding Intro Screen
class ScreenWelcome extends StatefulWidget {
  const ScreenWelcome({super.key});

  @override
  State<ScreenWelcome> createState() => _ScreenWelcomeState();
}

class _ScreenWelcomeState extends State<ScreenWelcome> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _IntroPageData(
      emoji: '🛡️',
      title: '여행, 더 안전하게',
      subtitle: 'SafeTrip과 함께라면\n어디든 안심하고 떠날 수 있어요',
      bgColor: Color(0xFF1A3A5C),
    ),
    _IntroPageData(
      emoji: '👥',
      title: '일정부터 위치까지, 함께',
      subtitle: '멤버들의 실시간 위치와\n여행 일정을 한눈에 확인하세요',
      bgColor: Color(0xFF00BFA5),
    ),
    _IntroPageData(
      emoji: '👩‍👧‍👦',
      title: '누군가 지켜보고 있어요',
      subtitle: '가디언 기능을 통해\n소중한 사람의 안전을 지켜주세요',
      bgColor: Color(0xFFFF6B6B),
    ),
    _IntroPageData(
      emoji: '🚀',
      title: '지금 시작하세요',
      subtitle: 'SafeTrip으로 더 즐겁고\n안전한 여행을 시작해볼까요?',
      bgColor: AppColors.primaryTeal,
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _goNext() {
    if (!_isLastPage) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(RoutePaths.roleSelect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 색상 애니메이션 (선택 사항, 현재는 페이지 내 컨테이너로 처리)
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (_, index) => _IntroPageWidget(page: _pages[index]),
          ),

          // 건너뛰기 버튼
          if (!_isLastPage)
            Positioned(
              top: MediaQuery.of(context).padding.top + AppSpacing.sm,
              right: AppSpacing.md,
              child: TextButton(
                onPressed: () => context.go(RoutePaths.roleSelect),
                child: Text(
                  '건너뛰기',
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                ),
              ),
            ),

          // 하단 컨트롤
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // 인디케이터
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 액션 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _pages[_currentPage].bgColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radius16),
                        ),
                      ),
                      child: Text(
                        _isLastPage ? '시작하기' : '다음',
                        style: AppTypography.labelLarge.copyWith(
                          color: _pages[_currentPage].bgColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                if (_isLastPage) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.tripDemo),
                    child: Text(
                      '로그인 없이 먼저 둘러보기',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
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
    _pageController.dispose();
    super.dispose();
  }
}

class _IntroPageData {
  const _IntroPageData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bgColor,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final Color bgColor;
}

class _IntroPageWidget extends StatelessWidget {
  const _IntroPageWidget({required this.page});
  final _IntroPageData page;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: page.bgColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(page.emoji, style: const TextStyle(fontSize: 80)),
              const SizedBox(height: AppSpacing.xl),
              Text(
                page.title,
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                page.subtitle,
                style: AppTypography.bodyLarge.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
