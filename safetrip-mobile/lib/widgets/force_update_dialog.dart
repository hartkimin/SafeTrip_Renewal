import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_spacing.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String storeUrl;

  const ForceUpdateDialog({super.key, required this.storeUrl});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('업데이트가 필요합니다', style: AppTypography.titleLarge),
        content: Text(
          '안전한 여행을 위해 최신 버전으로 업데이트해 주세요.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: storeUrl.isEmpty ? null : () => _openStore(),
              child: const Text('지금 업데이트'),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius16),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> show(BuildContext context, String storeUrl) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForceUpdateDialog(storeUrl: storeUrl),
    );
  }
}
