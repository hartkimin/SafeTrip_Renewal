import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';

/// 투표 옵션 데이터 모델
class VoteOption {
  const VoteOption({
    required this.optionId,
    required this.label,
    this.voteCount = 0,
  });

  final String optionId;
  final String label;
  final int voteCount;

  factory VoteOption.fromJson(Map<String, dynamic> json) {
    return VoteOption(
      optionId: json['id']?.toString() ??
          json['option_id']?.toString() ??
          json['vote_option_id']?.toString() ??
          '',
      label: json['label'] as String? ??
          json['option_text'] as String? ??
          '',
      voteCount: (json['responseCount'] as num?)?.toInt() ??
          (json['vote_count'] as num?)?.toInt() ??
          0,
    );
  }
}

/// 일정 투표 카드 위젯.
/// 투표 제목, 옵션별 진행률 바, 투표/마감 기능을 제공한다.
class VoteCard extends ConsumerStatefulWidget {
  const VoteCard({
    super.key,
    required this.tripId,
    required this.voteId,
    required this.title,
    required this.options,
    required this.status,
    this.deadline,
    this.userVotedOptionId,
    this.isCaptain = false,
    this.onVoteChanged,
  });

  final String tripId;
  final String voteId;
  final String title;
  final List<VoteOption> options;

  /// 'open' | 'closed'
  final String status;
  final DateTime? deadline;
  final String? userVotedOptionId;
  final bool isCaptain;
  final VoidCallback? onVoteChanged;

  @override
  ConsumerState<VoteCard> createState() => _VoteCardState();
}

class _VoteCardState extends ConsumerState<VoteCard> {
  final ApiService _apiService = ApiService();

  late List<VoteOption> _options;
  String? _selectedOptionId;
  bool _isVoting = false;
  bool _isClosing = false;
  late String _status;
  Timer? _countdownTimer;
  String _countdownText = '';

  @override
  void initState() {
    super.initState();
    _options = widget.options;
    _selectedOptionId = widget.userVotedOptionId;
    _status = widget.status;
    _startCountdownTimer();
  }

  @override
  void didUpdateWidget(covariant VoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      _options = widget.options;
    }
    if (oldWidget.userVotedOptionId != widget.userVotedOptionId) {
      _selectedOptionId = widget.userVotedOptionId;
    }
    if (oldWidget.status != widget.status) {
      _status = widget.status;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    if (widget.deadline == null || _status == 'closed') return;

    _updateCountdownText();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _updateCountdownText(),
    );
  }

  void _updateCountdownText() {
    if (widget.deadline == null || !mounted) return;

    final now = DateTime.now();
    final diff = widget.deadline!.difference(now);

    if (diff.isNegative) {
      setState(() => _countdownText = '\uB9C8\uAC10\uB428'); // 마감됨
      _countdownTimer?.cancel();
      return;
    }

    if (diff.inDays > 0) {
      setState(() =>
          _countdownText = '${diff.inDays}\uC77C \uB0A8\uC74C'); // N일 남음
    } else if (diff.inHours > 0) {
      setState(() => _countdownText =
          '${diff.inHours}\uC2DC\uAC04 \uB0A8\uC74C'); // N시간 남음
    } else {
      setState(() => _countdownText =
          '${diff.inMinutes}\uBD84 \uB0A8\uC74C'); // N분 남음
    }
  }

  int get _totalVotes {
    int total = 0;
    for (final opt in _options) {
      total += opt.voteCount;
    }
    return total;
  }

  /// 가장 많은 표를 받은 옵션 ID
  String? get _winnerOptionId {
    if (_options.isEmpty || _status != 'closed') return null;
    VoteOption winner = _options.first;
    for (final opt in _options) {
      if (opt.voteCount > winner.voteCount) {
        winner = opt;
      }
    }
    return winner.voteCount > 0 ? winner.optionId : null;
  }

  Future<void> _castVote(String optionId) async {
    if (_isVoting || _status == 'closed') return;
    setState(() => _isVoting = true);

    try {
      final result = await _apiService.dio.post(
        '/api/v1/trips/${widget.tripId}/votes/${widget.voteId}/respond',
        data: {'optionId': optionId},
      );
      if (result.data?['success'] == true && mounted) {
        setState(() {
          _selectedOptionId = optionId;
        });
        widget.onVoteChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('\uD22C\uD45C\uC5D0 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4'), // 투표에 실패했습니다
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _closeVote() async {
    if (_isClosing || _status == 'closed') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\uD22C\uD45C \uB9C8\uAC10'), // 투표 마감
        content: const Text(
          '\uC774 \uD22C\uD45C\uB97C \uB9C8\uAC10\uD558\uC2DC\uACA0\uC2B5\uB2C8\uAE4C? \uB9C8\uAC10 \uD6C4\uC5D0\uB294 \uBCC0\uACBD\uD560 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4.', // 이 투표를 마감하시겠습니까? 마감 후에는 변경할 수 없습니다.
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\uCDE8\uC18C'), // 취소
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.semanticError,
            ),
            child: const Text('\uB9C8\uAC10'), // 마감
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isClosing = true);

    try {
      final result = await _apiService.dio.patch(
        '/api/v1/trips/${widget.tripId}/votes/${widget.voteId}/close',
      );
      if (result.data?['success'] == true && mounted) {
        setState(() {
          _status = 'closed';
          _countdownTimer?.cancel();
        });
        widget.onVoteChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('\uD22C\uD45C \uB9C8\uAC10\uC5D0 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4'), // 투표 마감에 실패했습니다
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = _status == 'closed';
    final winnerId = _winnerOptionId;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius12),
        border: Border.all(
          color: isClosed
              ? AppColors.outlineVariant
              : AppColors.primaryTeal.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 아이콘 + 제목 + 상태/마감
            _buildHeader(isClosed),
            const SizedBox(height: AppSpacing.md),
            // 옵션 목록
            ..._options.map((opt) => _buildOptionItem(
                  opt,
                  isClosed: isClosed,
                  isWinner: winnerId == opt.optionId,
                )),
            // 하단: 투표하기 / 마감 버튼
            const SizedBox(height: AppSpacing.sm),
            _buildFooter(isClosed),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isClosed) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isClosed
                ? AppColors.surfaceVariant
                : AppColors.primaryTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radius8),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.how_to_vote_outlined,
            size: 18,
            color: isClosed
                ? AppColors.textTertiary
                : AppColors.primaryTeal,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            widget.title,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 상태 배지
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isClosed
                ? AppColors.textTertiary.withValues(alpha: 0.1)
                : AppColors.primaryTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            isClosed
                ? '\uB9C8\uAC10\uB428' // 마감됨
                : '\uD22C\uD45C \uC911', // 투표 중
            style: AppTypography.labelSmall.copyWith(
              color: isClosed
                  ? AppColors.textTertiary
                  : AppColors.primaryTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionItem(
    VoteOption option, {
    required bool isClosed,
    required bool isWinner,
  }) {
    final total = _totalVotes;
    final percentage = total > 0 ? (option.voteCount / total) : 0.0;
    final percentText = total > 0
        ? '${(percentage * 100).round()}%'
        : '0%';
    final isSelected = _selectedOptionId == option.optionId;

    Color barColor;
    if (isWinner && isClosed) {
      barColor = AppColors.semanticSuccess;
    } else if (isSelected) {
      barColor = AppColors.primaryTeal;
    } else {
      barColor = AppColors.surfaceVariant;
    }

    return GestureDetector(
      onTap: (!isClosed && _selectedOptionId == null)
          ? () => _castVote(option.optionId)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 라디오 인디케이터
                if (!isClosed)
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryTeal
                            : AppColors.outlineVariant,
                        width: 1.5,
                      ),
                      color: isSelected
                          ? AppColors.primaryTeal
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                // 우승 아이콘
                if (isWinner && isClosed)
                  const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.xs),
                    child: Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: AppColors.secondaryAmber,
                    ),
                  ),
                // 옵션 라벨
                Expanded(
                  child: Text(
                    option.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isWinner && isClosed
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          isWinner && isClosed ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                // 퍼센트 + 투표수
                Text(
                  '$percentText (${option.voteCount})',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // 진행률 바
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radius4),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                backgroundColor:
                    AppColors.surfaceVariant.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isClosed) {
    return Row(
      children: [
        // 마감 카운트다운
        if (!isClosed && _countdownText.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _countdownText,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        // 총 투표수
        if (isClosed)
          Text(
            '\uCD1D $_totalVotes\uD45C', // 총 N표
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        const Spacer(),
        // 캡틴 마감 버튼
        if (widget.isCaptain && !isClosed)
          TextButton(
            onPressed: _isClosing ? null : _closeVote,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.semanticError,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _isClosing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '\uD22C\uD45C \uB9C8\uAC10', // 투표 마감
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.semanticError,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        // 투표하기 버튼 (아직 투표하지 않은 경우)
        if (!isClosed && _selectedOptionId == null)
          Text(
            '\uC635\uC158\uC744 \uC120\uD0DD\uD558\uC138\uC694', // 옵션을 선택하세요
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}
