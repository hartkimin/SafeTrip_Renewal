import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';

/// 일정 카드 하단에 표시되는 확장/축소 가능한 댓글 섹션.
/// 댓글 목록, 새 댓글 입력, 자기 댓글 스와이프 삭제를 지원한다.
class ScheduleComments extends ConsumerStatefulWidget {
  const ScheduleComments({
    super.key,
    required this.tripId,
    required this.scheduleId,
    this.initialCommentCount = 0,
  });

  final String tripId;
  final String scheduleId;
  final int initialCommentCount;

  @override
  ConsumerState<ScheduleComments> createState() => _ScheduleCommentsState();
}

class _ScheduleCommentsState extends ConsumerState<ScheduleComments> {
  final ApiService _apiService = ApiService();
  final TextEditingController _commentController = TextEditingController();

  List<_CommentData> _comments = [];
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _isSending = false;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _commentCount = widget.initialCommentCount;
    _fetchCommentCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _fetchCommentCount() async {
    try {
      final result = await _apiService.dio.get(
        '/api/v1/trips/${widget.tripId}/schedules/${widget.scheduleId}/comments',
        queryParameters: {'limit': 0},
      );
      if (result.data?['success'] == true && mounted) {
        final data = result.data['data'];
        final total = data is Map
            ? (data['total'] as num?)?.toInt() ?? 0
            : 0;
        setState(() => _commentCount = total);
      }
    } catch (_) {
      // 카운트 로드 실패 시 기존 값 유지
    }
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.dio.get(
        '/api/v1/trips/${widget.tripId}/schedules/${widget.scheduleId}/comments',
      );
      if (result.data?['success'] == true && mounted) {
        final data = result.data['data'];
        final commentsList = data is Map
            ? (data['comments'] ?? []) as List
            : (data is List ? data : []);
        final comments = commentsList.map((c) {
          final map = c as Map<String, dynamic>;
          return _CommentData(
            commentId: map['comment_id']?.toString() ??
                map['schedule_comment_id']?.toString() ??
                '',
            userId: map['user_id']?.toString() ?? '',
            userName: map['user_name'] as String? ??
                map['display_name'] as String? ??
                '알 수 없는 사용자',
            content: map['content'] as String? ?? '',
            createdAt: map['created_at'] != null
                ? DateTime.tryParse(map['created_at'].toString()) ??
                    DateTime.now()
                : DateTime.now(),
          );
        }).toList();

        setState(() {
          _comments = comments;
          _commentCount = comments.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final result = await _apiService.dio.post(
        '/api/v1/trips/${widget.tripId}/schedules/${widget.scheduleId}/comments',
        data: {'content': text},
      );
      if (result.data?['success'] == true && mounted) {
        _commentController.clear();
        await _fetchComments();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('댓글 작성에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final result = await _apiService.dio.delete(
        '/api/v1/trips/${widget.tripId}/schedules/${widget.scheduleId}/comments/$commentId',
      );
      if (result.data?['success'] == true && mounted) {
        setState(() {
          _comments.removeWhere((c) => c.commentId == commentId);
          _commentCount = _comments.length;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('댓글 삭제에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded && _comments.isEmpty) {
      _fetchComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 댓글 헤더: "댓글 N개" + 확장/축소 토글
        _buildHeader(),
        // 확장 시 댓글 목록 + 입력 필드
        if (_isExpanded) ...[
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            _buildCommentList(),
            _buildCommentInput(),
          ],
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: _toggleExpand,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              _isExpanded
                  ? Icons.chat_bubble
                  : Icons.chat_bubble_outline,
              size: 14,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '\uB313\uAE00 $_commentCount\uAC1C', // 댓글 N개
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const Spacer(),
            Icon(
              _isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentList() {
    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          '\uC544\uC9C1 \uB313\uAE00\uC774 \uC5C6\uC2B5\uB2C8\uB2E4', // 아직 댓글이 없습니다
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: _comments.length,
        itemBuilder: (context, index) {
          final comment = _comments[index];
          final isOwnComment = comment.userId == _currentUserId;

          if (isOwnComment) {
            return Dismissible(
              key: Key(comment.commentId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.md),
                color: AppColors.semanticError.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.semanticError,
                  size: 20,
                ),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('\uB313\uAE00 \uC0AD\uC81C'), // 댓글 삭제
                    content: const Text(
                      '\uC774 \uB313\uAE00\uC744 \uC0AD\uC81C\uD558\uC2DC\uACA0\uC2B5\uB2C8\uAE4C?', // 이 댓글을 삭제하시겠습니까?
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
                        child: const Text('\uC0AD\uC81C'), // 삭제
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) => _deleteComment(comment.commentId),
              child: _buildCommentItem(comment),
            );
          }

          return _buildCommentItem(comment);
        },
      ),
    );
  }

  Widget _buildCommentItem(_CommentData comment) {
    final timeStr = _formatCommentTime(comment.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.surfaceVariant,
            child: Text(
              comment.userName.isNotEmpty
                  ? comment.userName.substring(0, 1)
                  : '?',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 콘텐츠
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      timeStr,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: AppTypography.bodySmall,
              decoration: InputDecoration(
                hintText: '\uB313\uAE00\uC744 \uC785\uB825\uD558\uC138\uC694...', // 댓글을 입력하세요...
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendComment(),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              onPressed: _isSending ? null : _sendComment,
              padding: EdgeInsets.zero,
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.send,
                      size: 18,
                      color: AppColors.primaryTeal,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 댓글 시간을 상대 형식으로 포맷한다.
  String _formatCommentTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '\uBC29\uAE08'; // 방금
    if (diff.inMinutes < 60) return '${diff.inMinutes}\uBD84 \uC804'; // N분 전
    if (diff.inHours < 24) return '${diff.inHours}\uC2DC\uAC04 \uC804'; // N시간 전
    if (diff.inDays < 7) return '${diff.inDays}\uC77C \uC804'; // N일 전

    return DateFormat('MM/dd HH:mm').format(dt);
  }
}

/// 댓글 데이터 모델
class _CommentData {
  const _CommentData({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  final String commentId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
}
