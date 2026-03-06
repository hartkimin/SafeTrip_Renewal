/// 프로필 아바타 테마 상수 (DOC-T3-PRF-027 §7.3)
///
/// 10종 여행 테마 아바타. 사용자가 프로필 사진 대신 선택 가능.
/// 서버에는 avatar_id만 저장된다.
class AvatarConstants {
  AvatarConstants._();

  static const List<AvatarTheme> themes = [
    AvatarTheme(id: 'avatar_airplane', name: '비행기', icon: '✈️', color: 0xFF4FC3F7),
    AvatarTheme(id: 'avatar_camping', name: '캠핑', icon: '⛺', color: 0xFF81C784),
    AvatarTheme(id: 'avatar_mountain', name: '산', icon: '🏔️', color: 0xFF7986CB),
    AvatarTheme(id: 'avatar_city', name: '도시', icon: '🏙️', color: 0xFFFFB74D),
    AvatarTheme(id: 'avatar_beach', name: '해변', icon: '🏖️', color: 0xFF4DD0E1),
    AvatarTheme(id: 'avatar_train', name: '기차', icon: '🚂', color: 0xFFE57373),
    AvatarTheme(id: 'avatar_ship', name: '크루즈', icon: '🚢', color: 0xFF90A4AE),
    AvatarTheme(id: 'avatar_backpack', name: '배낭여행', icon: '🎒', color: 0xFFA1887F),
    AvatarTheme(id: 'avatar_camera', name: '사진여행', icon: '📷', color: 0xFFBA68C8),
    AvatarTheme(id: 'avatar_compass', name: '탐험', icon: '🧭', color: 0xFFFF8A65),
  ];

  static AvatarTheme? getById(String? id) {
    if (id == null) return null;
    try {
      return themes.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

class AvatarTheme {
  final String id;
  final String name;
  final String icon;
  final int color;

  const AvatarTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}
