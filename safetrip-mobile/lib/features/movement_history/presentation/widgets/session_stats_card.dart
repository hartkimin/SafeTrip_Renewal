import 'package:flutter/material.dart';
import '../../models/session_stats.dart';

class SessionStatsCard extends StatelessWidget {
  final SessionStats stats;

  const SessionStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.straighten,
              value: '${stats.totalDistanceKm} km',
              label: '이동 거리',
            ),
            _StatItem(
              icon: Icons.timer,
              value: '${stats.durationMinutes}분',
              label: '이동 시간',
            ),
            _StatItem(
              icon: Icons.speed,
              value: '${stats.avgSpeed} m/s',
              label: '평균 속도',
            ),
            _StatItem(
              icon: Icons.location_on,
              value: '${stats.locationCount}',
              label: '위치 포인트',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
