import 'package:flutter/material.dart';

enum ExportFormat { pdf, csv }

class ExportDialog extends StatelessWidget {
  final String memberName;
  final String date;
  final ValueChanged<ExportFormat>? onExport;

  const ExportDialog({
    super.key,
    required this.memberName,
    required this.date,
    this.onExport,
  });

  static Future<ExportFormat?> show(BuildContext context, {
    required String memberName,
    required String date,
  }) {
    return showDialog<ExportFormat>(
      context: context,
      builder: (_) => ExportDialog(memberName: memberName, date: date),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이동기록 내보내기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$memberName님의 $date 이동기록'),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('PDF'),
            subtitle: const Text('지도 이미지 + 타임라인 요약'),
            onTap: () => Navigator.pop(context, ExportFormat.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.green),
            title: const Text('CSV'),
            subtitle: const Text('위치 포인트 원시 데이터'),
            onTap: () => Navigator.pop(context, ExportFormat.csv),
          ),
        ],
      ),
    );
  }
}
