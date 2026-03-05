import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/avatar_widget.dart';

class BottomSheetMember extends StatefulWidget {
  const BottomSheetMember({
    super.key,
    required this.initialHeight,
    this.onHeightChanged,
  });
  final double initialHeight;
  final Function(double)? onHeightChanged;

  @override
  State<BottomSheetMember> createState() => _BottomSheetMemberState();
}

class _BottomSheetMemberState extends State<BottomSheetMember> {
  String? _selectedUserId;
  late double _currentHeight;

  @override
  void initState() {
    super.initState();
    _currentHeight = widget.initialHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radius24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          _buildHandle(),
          Expanded(
            child: _selectedUserId == null ? _buildMemberList() : _buildUserTimeline(_selectedUserId!),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        final screenHeight = MediaQuery.of(context).size.height;
        setState(() {
          _currentHeight -= details.delta.dy / screenHeight;
          _currentHeight = _currentHeight.clamp(0.1, 1.0);
          widget.onHeightChanged?.call(_currentHeight);
        });
      },
      child: Container(
        height: 32,
        width: double.infinity,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberList() {
    return ListView.builder(
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
          subtitle: Text(index == 0 ? '이동 중' : '정지', style: AppTypography.bodySmall),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => _selectedUserId = 'user_$index'),
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
                onPressed: () => setState(() => _selectedUserId = null),
              ),
              Text('$userId의 이동기록', style: AppTypography.titleLarge),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: 10,
            itemBuilder: (context, index) {
              return Row(
                children: [
                  Column(
                    children: [
                      Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.primaryTeal, shape: BoxShape.circle)),
                      Container(width: 2, height: 50, color: AppColors.outline),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('14:${index.toString().padLeft(2, '0')}', style: AppTypography.labelSmall),
                        Text('위치 정보 업데이트 $index', style: AppTypography.bodyMedium),
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
