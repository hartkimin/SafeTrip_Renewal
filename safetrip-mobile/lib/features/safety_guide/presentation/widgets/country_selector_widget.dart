import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/country_context_provider.dart';

/// 국가 변경 바텀시트 (DOC-T3-SFG-021 §3.3 수동 변경)
class CountrySelectorWidget extends ConsumerWidget {
  const CountrySelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(countryContextProvider);

    return InkWell(
      onTap: () => _showCountryPicker(context, ref),
      borderRadius: BorderRadius.circular(AppSpacing.radius8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctx.flagEmoji ?? '',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              ctx.countryNameKo ?? '국가 선택',
              style: AppTypography.labelLarge,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _CountryPickerContent(
          scrollController: scrollController,
          onSelect: (code, name, emoji) {
            ref.read(countryContextProvider.notifier).setManual(
                  code,
                  countryNameKo: name,
                  flagEmoji: emoji,
                );
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CountryPickerContent
// ---------------------------------------------------------------------------

class _CountryPickerContent extends StatelessWidget {
  const _CountryPickerContent({
    required this.scrollController,
    required this.onSelect,
  });

  final ScrollController scrollController;
  final void Function(String code, String name, String emoji) onSelect;

  // 주요 국가 목록 (Phase 1 기본)
  static const _countries = [
    ('JP', '일본', '\u{1F1EF}\u{1F1F5}'),
    ('US', '미국', '\u{1F1FA}\u{1F1F8}'),
    ('CN', '중국', '\u{1F1E8}\u{1F1F3}'),
    ('TH', '태국', '\u{1F1F9}\u{1F1ED}'),
    ('VN', '베트남', '\u{1F1FB}\u{1F1F3}'),
    ('PH', '필리핀', '\u{1F1F5}\u{1F1ED}'),
    ('SG', '싱가포르', '\u{1F1F8}\u{1F1EC}'),
    ('GB', '영국', '\u{1F1EC}\u{1F1E7}'),
    ('FR', '프랑스', '\u{1F1EB}\u{1F1F7}'),
    ('DE', '독일', '\u{1F1E9}\u{1F1EA}'),
    ('IT', '이탈리아', '\u{1F1EE}\u{1F1F9}'),
    ('ES', '스페인', '\u{1F1EA}\u{1F1F8}'),
    ('AU', '호주', '\u{1F1E6}\u{1F1FA}'),
    ('CA', '캐나다', '\u{1F1E8}\u{1F1E6}'),
    ('MY', '말레이시아', '\u{1F1F2}\u{1F1FE}'),
    ('ID', '인도네시아', '\u{1F1EE}\u{1F1E9}'),
    ('TW', '대만', '\u{1F1F9}\u{1F1FC}'),
    ('TR', '튀르키예', '\u{1F1F9}\u{1F1F7}'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('국가 선택', style: AppTypography.titleMedium),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: _countries.length,
            itemBuilder: (context, index) {
              final (code, name, emoji) = _countries[index];
              return ListTile(
                leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                title: Text(name, style: AppTypography.bodyMedium),
                trailing: Text(
                  code,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                onTap: () => onSelect(code, name, emoji),
              );
            },
          ),
        ),
      ],
    );
  }
}
