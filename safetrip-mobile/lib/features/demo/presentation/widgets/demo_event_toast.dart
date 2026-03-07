import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// §3.6 step 4: Event-specific toast notification
/// Shows icon + color based on event type, auto-dismisses after 3 seconds.
class DemoEventToast {
  DemoEventToast._();

  static void show(BuildContext context, {
    required String type,
    required String message,
  }) {
    final config = _configFor(type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(config.icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: AppTypography.bodySmall.copyWith(
                color: Colors.white,
              )),
            ),
          ],
        ),
        backgroundColor: config.color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: config.isAlert ? 4 : 3),
        margin: const EdgeInsets.only(
          bottom: 120,
          left: AppSpacing.md,
          right: AppSpacing.md,
        ),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static _ToastConfig _configFor(String type) {
    switch (type) {
      case 'sos_drill':
      case 'sos_resolved':
        return const _ToastConfig(Icons.sos, AppColors.semanticError, true);
      case 'geofence_out':
      case 'geofence_violation':
        return const _ToastConfig(Icons.warning_amber, AppColors.semanticWarning, true);
      case 'member_left':
        return const _ToastConfig(Icons.person_off, AppColors.secondaryAmber, true);
      case 'schedule_changed':
        return const _ToastConfig(Icons.event_note, AppColors.semanticInfo, false);
      case 'geofence_in':
      case 'all_arrived':
        return const _ToastConfig(Icons.location_on, AppColors.semanticSuccess, false);
      case 'chat_message':
        return const _ToastConfig(Icons.chat_bubble, AppColors.primaryTeal, false);
      case 'trip_start':
      case 'trip_end':
        return const _ToastConfig(Icons.flight, AppColors.primaryTeal, false);
      case 'notification':
        return const _ToastConfig(Icons.notifications, AppColors.secondaryAmber, false);
      case 'daily_summary':
        return const _ToastConfig(Icons.summarize, AppColors.primaryTeal, false);
      default:
        return const _ToastConfig(Icons.info, AppColors.primaryTeal, false);
    }
  }
}

class _ToastConfig {
  const _ToastConfig(this.icon, this.color, this.isAlert);
  final IconData icon;
  final Color color;
  final bool isAlert;
}
