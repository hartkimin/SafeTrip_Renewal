import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// O-04 AI Briefing
class ScreenAiBriefing extends StatefulWidget {
  const ScreenAiBriefing({super.key});

  @override
  State<ScreenAiBriefing> createState() => _ScreenAiBriefingState();
}

class _ScreenAiBriefingState extends State<ScreenAiBriefing> with TickerProviderStateMixin {
  static const Color aiAccent = Color(0xFF7C4DFF);
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _cardAnimController;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text('AI 브리핑'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Chip(
              label: Text('AI Plus', style: AppTypography.labelSmall.copyWith(color: Colors.white)),
              backgroundColor: const Color(0xFFFFB800),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _cardAnimController,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOut)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('좋은 아침이에요!', style: AppTypography.displayLarge.copyWith(fontSize: 24, color: AppColors.textPrimary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('오늘의 안전 브리핑', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildWeatherCard(),
                    _buildSafetyIndexCard(),
                    _buildNoticeCard(),
                    _buildRecommendationCard(),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.md),
              _buildPageIndicator(),
              const SizedBox(height: AppSpacing.xl),
              
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: aiAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius12)),
                    ),
                    child: Text('좋은 여행 되세요!', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) => Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == index ? aiAccent : AppColors.outline),
      )),
    );
  }

  Widget _buildCardContainer(String title, Widget content) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius20),
        border: Border.all(color: AppColors.outline),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(title, style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return _buildCardContainer('오늘 날씨', Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('18°C', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
        Text('구름 조금', style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildWeatherInfo('최저 12°C', '최고 22°C'),
            _buildWeatherInfo('습도 45%', '강수 10%'),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('자외선 지수 높음 — 자외선 차단제를 챙기세요', textAlign: TextAlign.center, style: AppTypography.labelSmall.copyWith(color: AppColors.semanticWarning)),
      ],
    ));
  }

  Widget _buildWeatherInfo(String top, String bottom) {
    return Column(
      children: [
        Text(top, style: AppTypography.bodyMedium),
        Text(bottom, style: AppTypography.bodyMedium),
      ],
    );
  }

  Widget _buildSafetyIndexCard() {
    return _buildCardContainer('안전지수', Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CircularProgressIndicator(value: 0.78, strokeWidth: 10, backgroundColor: AppColors.outline, color: AppColors.primaryTeal),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('78/100', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                    Text('양호', style: AppTypography.labelSmall.copyWith(color: AppColors.semanticSuccess)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildSafetyRow('지역 범죄율', '낮음'),
        _buildSafetyRow('자연재해 위험', '없음'),
        _buildSafetyRow('교통 혼잡도', '보통'),
      ],
    ));
  }

  Widget _buildSafetyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildNoticeCard() {
    return _buildCardContainer('주의사항', Column(
      children: [
        _buildNoticeItem('소매치기 주의', '관광지 주변 소매치기 빈발'),
        const SizedBox(height: AppSpacing.md),
        _buildNoticeItem('야간 이동 주의', '22시 이후 대중교통 감소'),
      ],
    ));
  }

  Widget _buildNoticeItem(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.secondaryAmber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppSpacing.radius12), border: Border.all(color: AppColors.secondaryAmber.withValues(alpha: 0.3))),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.secondaryAmber),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(desc, style: AppTypography.bodySmall)])),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return _buildCardContainer('추천 활동', Column(
      children: [
        _buildRecItem('아사쿠사 산책', '오전 시간대 방문 추천'),
        const SizedBox(height: AppSpacing.md),
        _buildRecItem('츠키지 시장', '점심 시간 방문 추천'),
        const Spacer(),
        Text('ⓘ AI가 생성한 정보로, 실제와 다를 수 있습니다', textAlign: TextAlign.center, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
      ],
    ));
  }

  Widget _buildRecItem(String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: aiAccent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(AppSpacing.radius12), border: Border.all(color: aiAccent.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(desc, style: AppTypography.bodySmall)]),
    );
  }
}
