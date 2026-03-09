/// §3.7: Coachmark definitions — 핵심 3개만 표시 (지도, 역할, 슬라이더)
class CoachmarkDef {
  const CoachmarkDef({
    required this.id,
    required this.text,
    this.arrowDirection = ArrowDirection.up,
  });

  final String id;
  final String text;
  final ArrowDirection arrowDirection;
}

enum ArrowDirection { up, down, left, right }

/// 핵심 코치마크 3개 — 나머지는 도구 메뉴에서 자연스럽게 발견
const kDemoCoachmarks = [
  CoachmarkDef(
    id: 'map_tab',
    text: '멤버들의 실시간 위치가 지도에 표시됩니다.\n마커를 탭하면 멤버 정보를 확인할 수 있어요.',
    arrowDirection: ArrowDirection.down,
  ),
  CoachmarkDef(
    id: 'role_panel',
    text: '역할을 바꿔가며 각 역할의 기능 차이를 체험해 보세요.',
    arrowDirection: ArrowDirection.right,
  ),
  CoachmarkDef(
    id: 'time_slider',
    text: '슬라이더를 움직여 여행 전·중·후 시점을 체험해 보세요.',
    arrowDirection: ArrowDirection.down,
  ),
];
