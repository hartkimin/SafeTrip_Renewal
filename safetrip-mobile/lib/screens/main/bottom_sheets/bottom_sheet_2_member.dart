import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/avatar_widget.dart';

/// 멤버 탭 바텀시트 콘텐츠 (화면구성원칙 §4 탭 2)
///
/// 부모 [SnappingBottomSheet]로부터 [ScrollController]를 수신.
class BottomSheetMember extends StatefulWidget {
  const BottomSheetMember({
    super.key,
    required this.scrollController,
    this.onEnterDetail,
    this.onExitDetail,
  });

  final ScrollController scrollController;

  /// §7.4: 세부 화면 진입 시 호출 (바텀시트 → full)
  final VoidCallback? onEnterDetail;

  /// §7.4: 세부 화면 종료 시 호출 (바텀시트 → 이전 레벨 복원)
  final VoidCallback? onExitDetail;

  @override
  State<BottomSheetMember> createState() => _BottomSheetMemberState();
}

class _BottomSheetMemberState extends State<BottomSheetMember> {
  String? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    return _selectedUserId == null
        ? _buildMemberList()
        : _buildUserTimeline(_selectedUserId!);
  }

  Widget _buildMemberList() {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 5,
      itemBuilder: (context, index) {
        return ListTile(
          leading: AvatarWidget(
            userId: 'user_$index',
            userName: '멤버 $index',
            radius: 20,
          ),
          title: Text('멤버 $index', style: AppTypography.titleMedium),
          subtitle: Text(
            index == 0 ? '이동 중' : '정지',
            style: AppTypography.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() => _selectedUserId = 'user_$index');
            widget.onEnterDetail?.call(); // §7.4
          },
        );
      },
    );
  }

  Widget _buildUserTimeline(String userId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _selectedUserId = null);
                  widget.onExitDetail?.call(); // §7.4
                },
              ),
              Text('$userId의 이동기록', style: AppTypography.titleLarge),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: 10,
            itemBuilder: (context, index) {
              return Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 50,
                        color: AppColors.outline,
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '14:${index.toString().padLeft(2, '0')}',
                          style: AppTypography.labelSmall,
                        ),
                        Text(
                          '위치 정보 업데이트 $index',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
