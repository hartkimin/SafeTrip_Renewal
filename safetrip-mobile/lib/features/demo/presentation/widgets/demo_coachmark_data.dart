/// §3.7: Coachmark definitions — text from DOC-T3-DMO-030 table
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

/// §3.7 texts: Korean P0, English/Japanese P3
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
    id: 'guardian_compare',
    text: '무료·유료 가디언의 차이를 직접 비교해 보세요.\n실제 앱에서는 1,900원/여행으로 추가 연결 가능합니다.',
    arrowDirection: ArrowDirection.left,
  ),
  CoachmarkDef(
    id: 'time_slider',
    text: '슬라이더를 움직여 여행 전·중·후 시점을 체험해 보세요.\n여행은 최대 15일까지 설정 가능합니다.',
    arrowDirection: ArrowDirection.down,
  ),
  CoachmarkDef(
    id: 'sos_button',
    text: 'SOS 버튼은 긴급 상황 시 전체 멤버와 가디언에게 즉시 알림을 보냅니다.',
    arrowDirection: ArrowDirection.down,
  ),
  CoachmarkDef(
    id: 'grade_compare',
    text: '프라이버시 등급을 바꾸면 위치 공유 범위와 가디언 공유 방식이 달라집니다.',
    arrowDirection: ArrowDirection.left,
  ),
];
