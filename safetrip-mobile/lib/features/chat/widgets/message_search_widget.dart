import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/api_service.dart';

/// 채팅 메시지 검색 위젯.
///
/// 검색 바 + 결과 오버레이를 제공한다.
/// 최소 2글자 입력 시 서버에 검색 요청을 보내고,
/// 결과 목록에서 탭하면 해당 메시지로 이동한다.
class MessageSearchWidget extends StatefulWidget {
  const MessageSearchWidget({
    super.key,
    required this.roomId,
    required this.onResultTap,
    required this.onClose,
  });

  /// 검색 대상 채팅방 ID.
  final String roomId;

  /// 검색 결과 항목 탭 콜백 -- 해당 메시지로 스크롤 등 처리.
  final void Function(Map<String, dynamic> message) onResultTap;

  /// 검색 닫기 콜백.
  final VoidCallback onClose;

  @override
  State<MessageSearchWidget> createState() => _MessageSearchWidgetState();
}

class _MessageSearchWidgetState extends State<MessageSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty || query.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    if (query == _lastQuery) return;
    _lastQuery = query;
    setState(() => _isSearching = true);
    try {
      final result = await _api.dio.get(
        '/api/v1/chats/rooms/${widget.roomId}/messages/search',
        queryParameters: {'q': query.trim(), 'limit': 20},
      );
      final data = result.data;
      setState(() {
        _results = (data is List ? data : (data['data'] ?? []))
            .cast<Map<String, dynamic>>();
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _performSearch,
                    decoration: InputDecoration(
                      hintText: '메시지 검색...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceVariant),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    style: AppTypography.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: widget.onClose,
                  child: const Text('취소'),
                ),
              ],
            ),
          ),

          // 검색 결과
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final msg = _results[index];
                  final content = msg['content'] as String? ?? '';
                  final senderName = msg['sender_name'] as String? ??
                      msg['sender_id'] as String? ??
                      '';
                  final sentAt = msg['sent_at'] as String? ??
                      msg['created_at'] as String? ??
                      '';

                  return ListTile(
                    dense: true,
                    title: Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                    subtitle: Text(
                      '$senderName · ${_formatTime(sentAt)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    onTap: () => widget.onResultTap(msg),
                  );
                },
              ),
            )
          else if (_lastQuery.isNotEmpty && !_isSearching)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '검색 결과가 없습니다',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.month}/${local.day} '
        '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}
