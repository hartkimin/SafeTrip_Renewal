import 'package:flutter/material.dart';

/// 가디언 배지 위젯 (DOC-T3-PRF-027 §4)
///
/// 무료 가디언: "가디언" (기본 브랜드 컬러, 회색 계열)
/// 유료 가디언: "가디언+" (골드 프리미엄)
///
/// 두 가지 형태:
/// - [GuardianBadge] — 텍스트 태그 형태 (닉네임 옆 인라인)
/// - [GuardianBadge.icon] — 원형 아이콘 (프로필 사진 우하단, 20dp)
class GuardianBadge extends StatelessWidget {
  final bool isPaid;

  const GuardianBadge({super.key, required this.isPaid});

  /// 프로필 사진 우하단 원형 배지 아이콘 (§4.2, 20dp)
  const factory GuardianBadge.icon({Key? key, required bool isPaid}) =
      _GuardianBadgeIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFFFF3E0) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaid ? const Color(0xFFFFB300) : Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: Text(
        isPaid ? '가디언+' : '가디언',
        style: TextStyle(
          fontSize: 11,
          color: isPaid ? const Color(0xFFE65100) : Colors.grey[700],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GuardianBadgeIcon extends GuardianBadge {
  const _GuardianBadgeIcon({super.key, required super.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFFFB300) : Colors.grey[400],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Icon(
          Icons.shield,
          size: 12,
          color: isPaid ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }
}
