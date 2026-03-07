import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/main/providers/connectivity_provider.dart';
import '../../../features/trip/providers/trip_provider.dart';
import '../providers/country_context_provider.dart';
import '../providers/safety_guide_providers.dart';
import 'tabs/overview_tab.dart';
import 'tabs/safety_tab.dart';
import 'tabs/medical_tab.dart';
import 'tabs/entry_tab.dart';
import 'tabs/emergency_tab.dart';
import 'tabs/local_life_tab.dart';
import 'widgets/country_selector_widget.dart';
import 'widgets/offline_banner.dart';

/// 안전가이드 바텀시트 (DOC-T3-SFG-021 §3.1)
/// S5: 역할 무관 동등 접근 -- 권한 체크 없음
class SafetyGuideBottomSheet extends ConsumerStatefulWidget {
  const SafetyGuideBottomSheet({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  ConsumerState<SafetyGuideBottomSheet> createState() =>
      _SafetyGuideBottomSheetState();
}

class _SafetyGuideBottomSheetState extends ConsumerState<SafetyGuideBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['개요', '안전', '의료', '입국', '긴급연락', '현지생활'];

  /// 현재 로드된 국가 코드를 추적하여 중복 로드 방지
  String? _loadedCountryCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStateProvider);
    final isOffline = !networkStatus.isOnline;
    final countryCtx = ref.watch(countryContextProvider);
    final guideState = ref.watch(safetyGuideProvider);

    // S1: 컨텍스트 기반 국가 자동 선택 (§3.3 — active trip → country context)
    final tripState = ref.watch(tripProvider);
    if (tripState.countryCode != null &&
        !countryCtx.isManualOverride &&
        countryCtx.countryCode != tripState.countryCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(countryContextProvider.notifier).setFromTrip(
                tripState.countryCode!,
                countryNameKo: tripState.countryName,
              );
        }
      });
    }

    // 국가 변경 시 자동 로드
    final countryCode = countryCtx.countryCode;
    if (countryCode != null &&
        countryCode != _loadedCountryCode &&
        !guideState.isLoading) {
      _loadedCountryCode = countryCode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(safetyGuideProvider.notifier).loadGuide(countryCode);
        }
      });
    }

    return Column(
      children: [
        // 헤더: 국가 선택기
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              const Expanded(child: CountrySelectorWidget()),
              if (guideState.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),

        // 오프라인 / stale 데이터 배너
        if (isOffline || (guideState.data?.meta.stale ?? false))
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: OfflineBanner(
              lastSyncTime: guideState.data?.meta.fetchedAt ??
                  networkStatus.lastSyncTime,
              isStale: !isOffline && (guideState.data?.meta.stale ?? false),
            ),
          ),

        // 에러 메시지
        if (guideState.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.semanticError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radius8),
                border: Border.all(
                  color: AppColors.semanticError.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '데이터 로드 실패. 다시 시도해 주세요.',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.semanticError,
                ),
              ),
            ),
          ),

        // 탭 바
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primaryTeal,
          labelStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: AppTypography.labelMedium,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),

        // 탭 콘텐츠
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              OverviewTab(scrollController: widget.scrollController),
              SafetyTab(scrollController: widget.scrollController),
              MedicalTab(scrollController: widget.scrollController),
              EntryTab(scrollController: widget.scrollController),
              EmergencyTab(scrollController: widget.scrollController),
              LocalLifeTab(scrollController: widget.scrollController),
            ],
          ),
        ),
      ],
    );
  }
}
