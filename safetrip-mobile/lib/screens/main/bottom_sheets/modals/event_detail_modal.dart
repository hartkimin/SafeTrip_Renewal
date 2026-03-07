import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../constants/app_tokens.dart';

/// 이벤트 상세 모달 (§5.4 이벤트 마커 탭)
class EventDetailModal extends StatelessWidget {
  const EventDetailModal({
    super.key,
    required this.eventType,
    required this.memberName,
    required this.description,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.geofenceName,
  });

  final String eventType;
  final String memberName;
  final String description;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? geofenceName;

  IconData get _icon {
    switch (eventType) {
      case 'geofence_exit':
        return Icons.warning_amber_rounded;
      case 'attendance_check':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color get _iconColor {
    switch (eventType) {
      case 'geofence_exit':
        return AppTokens.semanticError;
      case 'attendance_check':
        return AppTokens.primaryTeal;
      default:
        return AppTokens.text03;
    }
  }

  String get _title {
    switch (eventType) {
      case 'geofence_exit':
        return '지오펜스 이탈 경보';
      case 'attendance_check':
        return '출석 체크 확인';
      default:
        return '이벤트 알림';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(timestamp);
    final dateStr = DateFormat('yyyy.MM.dd').format(timestamp);

    return Container(
      padding: const EdgeInsets.all(AppTokens.spacing16),
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTokens.radius20),
          topRight: Radius.circular(AppTokens.radius20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: _iconColor, size: 24),
              const SizedBox(width: AppTokens.spacing8),
              Expanded(
                child: Text(
                  _title,
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize18,
                    fontWeight: AppTokens.fontWeightBold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spacing12),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTokens.bgTeal03,
                child: Text(
                  memberName.characters.first,
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    fontWeight: AppTokens.fontWeightBold,
                    color: AppTokens.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spacing8),
              Text(
                memberName,
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize14,
                  fontWeight: AppTokens.fontWeightSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spacing8),
          Text(
            description,
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize13,
              color: AppTokens.text04,
            ),
          ),
          const SizedBox(height: AppTokens.spacing8),
          Text(
            '$dateStr $timeStr',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize12,
              color: AppTokens.text03,
            ),
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: AppTokens.spacing4),
            Text(
              '위치: ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}',
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize11,
                color: AppTokens.text03,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
