import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 일정 탭 바텀시트 콘텐츠 (화면구성원칙 §4 탭 1)
///
/// 부모 [SnappingBottomSheet]로부터 [ScrollController]를 수신하여
/// 스크롤과 드래그 제스처가 연동된다.
class BottomSheetTrip extends StatefulWidget {
  const BottomSheetTrip({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  State<BottomSheetTrip> createState() => _BottomSheetTripState();
}

class _BottomSheetTripState extends State<BottomSheetTrip> {
  int _selectedTab = 0; // 0: 일정, 1: 장소

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        Expanded(
          child: _selectedTab == 0
              ? _buildScheduleList()
              : _buildPlaceList(),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
        ),
        child: Row(
          children: [
            _buildTabItem(0, '일정', Icons.calendar_today),
            _buildTabItem(1, '장소', Icons.location_on),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radius8),
            boxShadow: isSelected
                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.primaryTeal
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 3,
      itemBuilder: (context, index) => _buildScheduleItem(index),
    );
  }

  Widget _buildScheduleItem(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const Text('10:00', style: AppTypography.labelSmall),
              Container(width: 2, height: 40, color: AppColors.outline),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('일정 제목 ${index + 1}',
                        style: AppTypography.titleMedium),
                    const Text('장소 정보가 표시됩니다',
                        style: AppTypography.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceList() {
    return ListView(
      controller: widget.scrollController,
      children: const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('등록된 장소가 없습니다.'),
          ),
        ),
      ],
    );
  }
}
