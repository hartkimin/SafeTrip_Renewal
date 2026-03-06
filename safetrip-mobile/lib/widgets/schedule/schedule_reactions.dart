import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';

/// 일정 카드 하단에 표시되는 이모지 리액션 위젯.
/// 각 이모지는 카운트를 표시하며, 탭하면 자신의 리액션을 토글한다.
class ScheduleReactions extends ConsumerStatefulWidget {
  const ScheduleReactions({
    super.key,
    required this.tripId,
    required this.scheduleId,
  });

  final String tripId;
  final String scheduleId;

  @override
  ConsumerState<ScheduleReactions> createState() => _ScheduleReactionsState();
}

class _ScheduleReactionsState extends ConsumerState<ScheduleReactions> {
  static const List<String> _availableEmojis = [
    '\u{1F44D}', // thumbs up
    '\u{2764}\u{FE0F}', // red heart
    '\u{1F60A}', // smiling face
    '\u{1F389}', // party popper
    '\u{1F44F}', // clapping hands
  ];

  final ApiService _apiService = ApiService();

  /// emoji -> count
  Map<String, int> _reactionCounts = {};

  /// 현재 사용자가 누른 리액션 emoji 목록
  Set<String> _myReactions = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchReactions();
  }

  Future<void> _fetchReactions() async {
    try {
      final result = await _apiService.dio.get(
        '/api/v1/trips/${widget.tripId}/schedules/${widget.scheduleId}/reactions',
      );
      if (result.data?['success'] == true && mounted) {
        final data = result.data['data'];
        final reactionsData = data is Map ? data : {};

        final counts = <String, int>{};
        final mine = <String>{};

        // 서버 응답 형식: { reactions: [ { emoji, count, users: [...] } ] }
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final reactionsList = reactionsData['reactions'] as List? ?? [];
        for (final r in reactionsList) {
          final emoji = r['emoji'] as String? ?? '';
          final count = (r['count'] as num?)?.toInt() ?? 0;
          // Check is_mine/isMine field or users array
          bool isMine = r['is_mine'] as bool? ??
              r['isMine'] as bool? ??
              false;
          if (!isMine && currentUserId != null && r['users'] is List) {
            isMine = (r['users'] as List).contains(currentUserId);
          }
          if (emoji.isNotEmpty) {
            counts[emoji] = count;
            if (isMine) mine.add(emoji);
          }
        }

        setState(() {
          _reactionCounts = counts;
          _myReactions = mine;
        });
      }
    } catch (_) {
      // 리액션 로드 실패 시 빈 상태 유지
    }
  }

  Future<void> _toggleReaction(String emoji) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final wasSelected = _myReactions.contains(emoji);

    // 낙관적 UI 업데이트
    setState(() {
      if (wasSelected) {
        _myReactions.remove(emoji);
        _reactionCounts[emoji] = (_reactionCounts[emoji] ?? 1) - 1;
        if ((_reactionCounts[emoji] ?? 0) <= 0) {
          _reactionCounts.remove(emoji);
        }
      } else {
        _myReactions.add(emoji);
        _reactionCounts[emoji] = (_reactionCounts[emoji] ?? 0) + 1;
      }
    });

    try {
      await _apiService.dio.post(
        '/api/v1/trips/${widget.tripId}/schedules/${widget.scheduleId}/reactions',
        data: {'emoji': emoji},
      );
    } catch (_) {
      // 실패 시 원래 상태로 복원
      if (mounted) {
        setState(() {
          if (wasSelected) {
            _myReactions.add(emoji);
            _reactionCounts[emoji] = (_reactionCounts[emoji] ?? 0) + 1;
          } else {
            _myReactions.remove(emoji);
            _reactionCounts[emoji] = (_reactionCounts[emoji] ?? 1) - 1;
            if ((_reactionCounts[emoji] ?? 0) <= 0) {
              _reactionCounts.remove(emoji);
            }
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: _availableEmojis.map((emoji) {
        final count = _reactionCounts[emoji] ?? 0;
        final isSelected = _myReactions.contains(emoji);

        return _ReactionChip(
          emoji: emoji,
          count: count,
          isSelected: isSelected,
          onTap: () => _toggleReaction(emoji),
        );
      }).toList(),
    );
  }
}

/// 개별 리액션 이모지 칩
class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryTeal.withValues(alpha: 0.12)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryTeal.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            if (count > 0) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected
                      ? AppColors.primaryTeal
                      : AppColors.textTertiary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
