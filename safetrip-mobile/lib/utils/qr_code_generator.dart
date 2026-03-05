import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR 코드 생성 유틸리티
class QrCodeGenerator {
  /// QR 코드 위젯 생성
  ///
  /// [data]: QR 코드에 인코딩할 데이터 (초대 코드 또는 딥링크 URL)
  /// [size]: QR 코드 크기 (픽셀)
  static Widget generateQrCode({
    required String data,
    double size = 200,
  }) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
    );
  }

  /// QR 코드를 이미지로 변환 (공유용)
  ///
  /// [data]: QR 코드에 인코딩할 데이터
  /// [size]: QR 코드 크기 (픽셀)
  static Future<dynamic> generateQrCodeImage({
    required String data,
    double size = 200,
  }) async {
    // TODO: 향후 QR 코드 이미지 렌더링 구현
    return null;
  }
}

