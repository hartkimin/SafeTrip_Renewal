import 'package:flutter/material.dart';
import '../core/constants/avatar_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// 아바타 선택 그리드 (DOC-T3-PRF-027 §7.3)
///
/// 10종 여행 테마 아바타를 5열 그리드로 표시.
/// 선택된 아바타는 테두리 강조 표시.
class AvatarSelector extends StatelessWidget {
  final String? selectedAvatarId;
  final ValueChanged<String> onSelected;

  const AvatarSelector({
    super.key,
    this.selectedAvatarId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: AvatarConstants.themes.length,
      itemBuilder: (context, index) {
        final avatar = AvatarConstants.themes[index];
        final isSelected = avatar.id == selectedAvatarId;

        return GestureDetector(
          onTap: () => onSelected(avatar.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Color(avatar.color).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryCoral
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Text(avatar.icon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                avatar.name,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 11,
                  color: isSelected
                      ? AppColors.primaryCoral
                      : AppColors.textTertiary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
