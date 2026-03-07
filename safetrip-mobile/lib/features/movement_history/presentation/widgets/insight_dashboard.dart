import 'package:flutter/material.dart';

class InsightDashboard extends StatelessWidget {
  final Map<String, dynamic> insights;

  const InsightDashboard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('오늘의 인사이트', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildDistanceRow(context),
            const Divider(),
            _buildTopStayPoints(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceRow(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.directions_walk, color: Colors.teal),
        const SizedBox(width: 8),
        Text(
          '총 이동 거리: ${insights['daily_distance_km'] ?? 0} km',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildTopStayPoints(BuildContext context) {
    final topStayPoints = insights['top_stay_points'] as List? ?? [];
    if (topStayPoints.isEmpty) {
      return const Text('체류 지점 데이터가 없습니다.', style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('체류 핫스팟 TOP 3', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...topStayPoints.take(3).map((sp) => ListTile(
          dense: true,
          leading: const Icon(Icons.place, color: Colors.blue),
          title: Text(sp['place_name'] ?? '알 수 없는 장소'),
          trailing: Text('${sp['duration_minutes']}분'),
        )),
      ],
    );
  }
}
