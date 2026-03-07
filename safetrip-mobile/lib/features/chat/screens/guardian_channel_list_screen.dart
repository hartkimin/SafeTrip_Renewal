import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_cache.dart';
import 'guardian_chat_screen.dart';

/// 보호자 채널 목록 화면 (DOC-T3-CHT-020 SS8).
///
/// 현재 여행에 연결된 가디언 채널 목록을 표시한다.
/// 각 채널을 탭하면 1:1 가디언 메시지 화면([GuardianChatScreen])으로 이동한다.
///
/// 채널이 없을 때는 빈 상태 안내 메시지를 표시한다.
class GuardianChannelListScreen extends ConsumerStatefulWidget {
  const GuardianChannelListScreen({super.key});

  @override
  ConsumerState<GuardianChannelListScreen> createState() =>
      _GuardianChannelListScreenState();
}

class _GuardianChannelListScreenState
    extends ConsumerState<GuardianChannelListScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final tripId = AppCache.tripIdSync;
    if (tripId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final result =
          await _api.dio.get('/api/v1/guardian-chats/trip/$tripId/channels');
      final data = result.data;
      setState(() {
        _channels = (data is List ? data : (data['data'] ?? []))
            .cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[GuardianChannelList] 채널 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '연결된 보호자가 없습니다',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '멤버 탭에서 보호자를 추가해보세요',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChannels,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _channels.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final channel = _channels[index];
          final linkId =
              (channel['link_id'] ?? channel['linkId'] ?? '').toString();
          final isPaid =
              channel['is_paid'] ?? channel['isPaid'] ?? false;
          final guardianName = channel['guardian_name'] as String? ??
              channel['guardianName'] as String?;
          final memberName = channel['member_name'] as String? ??
              channel['memberName'] as String?;
          final displayName = guardianName ?? memberName ?? '보호자';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isPaid == true ? AppColors.primaryTeal : AppColors.surfaceVariant,
              child: Icon(
                isPaid == true ? Icons.verified_user : Icons.shield_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              displayName,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              isPaid == true ? '프리미엄 보호자' : '무료 보호자',
              style: AppTypography.labelSmall.copyWith(
                color: isPaid == true
                    ? AppColors.primaryTeal
                    : AppColors.textTertiary,
              ),
            ),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuardianChatScreen(
                    linkId: linkId,
                    isPaid: isPaid == true,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
