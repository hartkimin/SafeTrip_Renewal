import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/offline_sync_service.dart';

/// §6 충돌 해결 다이얼로그 — 오프라인 일정 드래프트가 서버와 충돌할 때 표시.
///
/// 사용자에게 "내 변경 유지" 또는 "서버 버전 사용" 선택지를 제공한다.
class ScheduleConflictDialog extends StatelessWidget {
  const ScheduleConflictDialog({
    super.key,
    required this.conflictedDrafts,
    required this.onResolved,
  });

  final List<Map<String, dynamic>> conflictedDrafts;
  final VoidCallback onResolved;

  static Future<void> showIfNeeded(BuildContext context) async {
    final drafts = await OfflineSyncService().getConflictedDrafts();
    if (drafts.isEmpty || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ScheduleConflictDialog(
        conflictedDrafts: drafts,
        onResolved: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '일정 동기화 충돌',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '오프라인에서 변경한 일정이 서버 버전과 충돌합니다.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: conflictedDrafts.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (_, index) =>
                    _buildConflictItem(context, conflictedDrafts[index]),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _resolveAll(context, 'use_server'),
          child: const Text('서버 버전 사용'),
        ),
        FilledButton(
          onPressed: () => _resolveAll(context, 'use_local'),
          child: const Text('내 변경 유지'),
        ),
      ],
    );
  }

  Widget _buildConflictItem(
    BuildContext context,
    Map<String, dynamic> draft,
  ) {
    final action = draft['action'] as String? ?? 'unknown';
    final payloadStr = draft['payload'] as String? ?? '{}';
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(payloadStr) as Map<String, dynamic>;
    } catch (_) {}

    final title = payload['title'] as String? ?? '(제목 없음)';
    final createdAt = draft['created_at'] as String?;
    final actionLabel = switch (action) {
      'create' => '추가',
      'update' => '수정',
      'delete' => '삭제',
      _ => action,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _actionIcon(action),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '작업: $actionLabel • ${_formatTime(createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionIcon(String action) {
    switch (action) {
      case 'create':
        return const Icon(Icons.add_circle_outline, color: Colors.green, size: 20);
      case 'update':
        return const Icon(Icons.edit_outlined, color: Colors.blue, size: 20);
      case 'delete':
        return const Icon(Icons.delete_outline, color: Colors.red, size: 20);
      default:
        return const Icon(Icons.help_outline, size: 20);
    }
  }

  String _formatTime(String? isoStr) {
    if (isoStr == null) return '';
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    return DateFormat('MM/dd HH:mm').format(dt);
  }

  Future<void> _resolveAll(BuildContext context, String resolution) async {
    final syncService = OfflineSyncService();
    for (final draft in conflictedDrafts) {
      final id = draft['id'] as int;
      if (resolution == 'use_server') {
        // 서버 버전 채택: 로컬 드래프트 삭제 (동기화 완료로 마킹)
        await syncService.markScheduleSynced(id, 'server_adopted');
      } else {
        // 내 변경 유지: 충돌 상태를 pending으로 되돌려 재동기화 시도
        await syncService.resolveConflict(id, 'pending');
      }
    }
    onResolved();
  }
}
