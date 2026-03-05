import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
  final String id;
  final String type; // sos, geofence, attendance, chat, etc.
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
}

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      type: 'sos',
      title: '긴급 SOS 상황 발생',
      body: '멤버 "홍길동"님이 SOS를 요청했습니다. 현재 위치를 확인하세요.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    NotificationItem(
      id: '2',
      type: 'geofence',
      title: '안전 구역 이탈',
      body: '멤버 "이순신"님이 설정된 안전 구역을 벗어났습니다.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    NotificationItem(
      id: '3',
      type: 'attendance',
      title: '출석 체크 완료',
      body: '모든 멤버가 목적지에 도착하여 출석 체크를 완료했습니다.',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('알림'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () {},
              child: const Text('모두 읽음'),
            ),
        ],
      ),
      body: _buildNotificationList(),
    );
  }

  Widget _buildNotificationList() {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.outline),
            const SizedBox(height: AppSpacing.md),
            Text('새로운 알림이 없습니다', style: AppTypography.bodyLarge.copyWith(color: AppColors.textTertiary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final item = _notifications[index];
        return _buildNotificationTile(item);
      },
    );
  }

  Widget _buildNotificationTile(NotificationItem item) {
    final isSos = item.type == 'sos' || item.type == 'danger';

    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.transparent : AppColors.primaryTeal.withValues(alpha: 0.03),
          border: isSos ? const Border(left: BorderSide(color: AppColors.sosDanger, width: 4)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_emojiForType(item.type), style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.title,
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTimestamp(item.timestamp),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emojiForType(String type) {
    switch (type) {
      case 'geofence': return '📍';
      case 'sos': return '🆘';
      case 'attendance': return '✅';
      case 'message': return '💬';
      case 'device': return '🔋';
      case 'danger': return '⚠️';
      case 'guardian': return '🛡️';
      default: return '🔔';
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return DateFormat('MM.dd HH:mm').format(dt);
  }
}
