import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../models/geofence.dart';

/// 지오펜스 정보 모달 (§5.4 지오펜스 영역 탭)
class GeofenceInfoModal extends StatelessWidget {
  const GeofenceInfoModal({
    super.key,
    required this.geofence,
    required this.userRole,
    this.onEdit,
  });

  final GeofenceData geofence;
  final String userRole;
  final VoidCallback? onEdit;

  bool get _canEdit => userRole == 'captain' || userRole == 'crew_leader';

  String get _typeName {
    switch (geofence.type) {
      case 'safe':
        return '안전 구역';
      case 'watch':
        return '주의 구역';
      case 'caution':
        return '경계 구역';
      case 'danger':
        return '위험 구역';
      default:
        return geofence.type;
    }
  }

  Color get _typeColor {
    switch (geofence.type) {
      case 'safe':
        return AppTokens.primaryTeal;
      case 'watch':
      case 'caution':
        return Colors.orange;
      case 'danger':
        return AppTokens.semanticError;
      default:
        return AppTokens.primaryTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _typeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTokens.spacing8),
              Expanded(
                child: Text(
                  geofence.name,
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
          _InfoRow(label: '유형', value: _typeName),
          if (geofence.radiusMeters != null)
            _InfoRow(label: '반경', value: '${geofence.radiusMeters}m'),
          _InfoRow(label: '상태', value: geofence.isActive ? '활성' : '비활성'),
          if (_canEdit) ...[
            const SizedBox(height: AppTokens.spacing16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('편집'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTokens.primaryTeal,
                  side: const BorderSide(color: AppTokens.primaryTeal),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spacing4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize13,
                color: AppTokens.text03,
              ),
            ),
          ),
          Text(
            value,
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              fontWeight: AppTokens.fontWeightMedium,
            ),
          ),
        ],
      ),
    );
  }
}
