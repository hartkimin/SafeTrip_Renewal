import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// 공유 기능 헬퍼
class ShareHelper {
  /// 텍스트를 클립보드에 복사
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// 텍스트를 클립보드에 복사하고 토스트 메시지 표시
  static Future<void> copyToClipboardWithToast(
    BuildContext context,
    String text,
  ) async {
    await copyToClipboard(text);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('복사되었습니다: $text'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 시스템 공유 시트 호출
  ///
  /// [text]: 공유할 텍스트
  /// [context]: SnackBar 표시를 위한 BuildContext
  /// [subject]: 공유 제목 (선택적)
  static Future<void> share({
    required String text,
    required BuildContext context,
    String? subject,
  }) async {
    await Share.share(text, subject: subject);
  }

  /// 파일 공유 (이미지 등)
  ///
  /// [filePath]: 공유할 파일 경로
  /// [text]: 공유할 텍스트 (선택적)
  static Future<void> shareFile({
    required String filePath,
    String? text,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      text: text,
    );
  }
}

