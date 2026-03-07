import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/api_service.dart';

/// 채팅방 미디어 갤러리 화면.
///
/// 채팅방에서 공유된 모든 이미지/동영상을 그리드 형태로 표시한다.
/// 커서 기반 페이징으로 무한 스크롤을 지원한다.
class MediaGalleryScreen extends StatefulWidget {
  const MediaGalleryScreen({super.key, required this.roomId});

  /// 미디어를 조회할 채팅방 ID.
  final String roomId;

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  final ApiService _api = ApiService();
  final List<Map<String, dynamic>> _media = [];
  bool _isLoading = true;
  String? _cursor;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    if (!_hasMore) return;
    try {
      final result = await _api.dio.get(
        '/api/v1/chats/rooms/${widget.roomId}/media',
        queryParameters: {
          'limit': 30,
          if (_cursor != null) 'cursor': _cursor,
        },
      );
      final data = result.data;
      final items = (data is List ? data : (data['data'] ?? []))
          .cast<Map<String, dynamic>>();
      setState(() {
        _media.addAll(items);
        _isLoading = false;
        _hasMore = items.length >= 30;
        if (items.isNotEmpty) {
          _cursor = items.last['sent_at'] as String? ??
              items.last['created_at'] as String?;
        }
      });
    } catch (e) {
      debugPrint('Media gallery error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('미디어 모아보기')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _media.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 48,
                        color: AppColors.textTertiary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '공유된 미디어가 없습니다',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollEndNotification &&
                        notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 200) {
                      _loadMedia();
                    }
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: _media.length,
                    itemBuilder: (context, index) {
                      final item = _media[index];
                      final mediaUrls =
                          item['media_urls'] ?? item['mediaUrls'];
                      String? imageUrl;
                      if (mediaUrls is List && mediaUrls.isNotEmpty) {
                        final first = mediaUrls.first;
                        imageUrl = first is Map
                            ? (first['thumbnail'] ?? first['url']) as String?
                            : first as String?;
                      }

                      return GestureDetector(
                        onTap: () => _showFullImage(context, imageUrl),
                        child: Container(
                          color: Colors.grey.shade200,
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Icon(Icons.image, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showFullImage(BuildContext context, String? url) {
    if (url == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
