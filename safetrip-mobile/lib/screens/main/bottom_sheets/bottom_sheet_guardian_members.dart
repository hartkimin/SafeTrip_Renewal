import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/avatar_widget.dart';

/// 가디언 전용 — 내 담당 멤버 탭 (화면구성원칙 §6.3)
///
/// 가디언이 연결된 멤버만 표시한다.
class BottomSheetGuardianMembers extends StatelessWidget {
  const BottomSheetGuardianMembers({
    super.key,
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // TODO: 실제 가디언 연결 멤버 데이터 바인딩
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '내 담당 멤버',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildMemberCard(
          userId: 'member_1',
          name: '멤버 정보 로딩 중...',
          status: '연결됨',
        ),
      ],
    );
  }

  Widget _buildMemberCard({
    required String userId,
    required String name,
    required String status,
  }) {
    return Card(
      child: ListTile(
        leading: AvatarWidget(
          userId: userId,
          userName: name,
          radius: 20,
        ),
        title: Text(name, style: AppTypography.titleMedium),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.semanticSuccess,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(status, style: AppTypography.bodySmall),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
