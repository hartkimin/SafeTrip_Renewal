# SafeTrip 개선 설계 문서

날짜: 2026-02-26
범위: 8개 이슈 (장소 직접 추가 제외)

---

## 도메인 1: 멤버 (최우선)

### 1-A. 멤버탭 "멤버 추가" 버튼
- 파일: `bottom_sheet_2_member.dart`
- 헤더 영역에 `+` 아이콘 버튼 추가
- 탭 → `AddMemberBottomSheet` 모달 표시

### 1-B. AddMemberBottomSheet (신규 파일)
- 파일: `modals/add_member_modal.dart`
- 두 탭 구조:
  - **초대코드 탭**: 코드 목록 + "새 코드 생성" 버튼 (역할/maxUses/유효기간 선택) → createInviteCode API → 복사/공유
  - **직접 검색 탭**: 전화번호/이름 검색 → `/api/v1/users/search` → 결과 선택 → 역할 지정 → 초대

### 1-C. 초대코드 관리 모달 개선
- 파일: `invite_code_management_modal.dart`
- "새 코드 생성" FAB 추가 (leader/full 권한만 노출)
- 생성 폼: 역할(full/normal/view_only), 최대사용횟수(1/5/10/무제한), 유효기간(1일/3일/7일/무기한)

### 1-D. 배터리 색상 단계별
- 파일: `bottom_sheet_2_member.dart` `_getBatteryIcon` 인근
- 아이콘 색상 단계:
  - >60%: `Colors.green`
  - 20~60%: `Colors.orange`
  - ≤20%: `Colors.red`
  - 충전 중: `Colors.blue`

---

## 도메인 2: 여행정보

### 2-A. 역할 표시 버그 (리더→여행자)
- 파일: `screen_main.dart` `_loadTripInfo()`
- `creator_id == userId` 또는 `member_role == 'leader'`이면 `userRole = 'leader'` 강제 설정

### 2-B. 권한별 역할 칩 확장
- 파일: `trip_info_card.dart` `_resolveRoleLabel()`
- `full` → '공동관리자', `normal` → '일반 멤버', `view_only` → '모니터링' 칩 추가

### 2-C. 날짜 하루 차이 버그
- 파일: `screen_trip_create.dart` `_onNextPressed()`
- `DateFormat('yyyy-MM-dd').format(_startDate!)` 사용 (intl 이미 import됨)

### 2-D. 국가명 / 여행명 분리
- 파일: `trip_info_card.dart`
- `countryName` 파라미터 추가
- 국기 + 국가명을 여행명 위 별도 라인에 표시

### 2-E. 여행전환 목록 미표시
- 파일: `screen_main.dart` `_showTripSwitchModal()`
- 모달 열기 전 `await _loadUserTripList()` 호출

---

## 도메인 3: UI 흐름

### 3-A. 여행전환화면 "참여코드로 참여" 버튼
- 파일: `trip_switch_modal.dart` `_buildBottomSection()`
- "코드로 참여" 버튼 추가 → `ScreenTripJoinCode(joinType: JoinType.traveler)` 이동
