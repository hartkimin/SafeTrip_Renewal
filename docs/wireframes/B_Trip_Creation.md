# B. 여행 생성 & 참여

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 여행 생성 및 참여 플로우 8개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |
| 화면 구성 원칙 | `Master_docs/10_T2_화면구성원칙.md` |

---

## 개요

- **화면 수:** 8개 (B-01 ~ B-08)
- **Phase:** 전체 P0
- **핵심 역할:** 캡틴 (여행 생성), 크루 (여행 참여)
- **연관 문서:** 비즈니스 원칙 &sect;03 여행 생성/참여

---

## User Journey Flow

```
[프로필 설정 완료 / 재로그인 (여행 없음)]
 → B-01 여행없음 홈
    ├─ "여행 만들기" → B-02 → B-03 국가 → B-04 프라이버시 → B-05 공유모드 → B-06 확인 → C-01 메인맵
    └─ "코드 입력" → B-07 초대코드 → B-08 미리보기 → C-01 메인맵
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| A-06 | 프로필 설정 완료 (여행 없음) | B-01 | A |
| B-06 | 여행 생성 완료 | C-01 메인맵 | C |
| B-08 | 여행 참여 완료 | C-01 메인맵 | C |

---

## 화면 상세

---

### B-01 여행 없음 홈 (No Trip Home)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | B-01 |
| 화면명 | 여행 없음 홈 (No Trip Home) |
| Phase | P0 |
| 역할 | 크루 (여행 미참여 상태) |
| 진입 경로 | A-06 프로필 설정 완료 (여행 없음) → B-01 / 재로그인 (여행 없음) → B-01 |
| 이탈 경로 | B-01 → B-02 (여행 만들기) / B-01 → B-07 (코드로 참여) |

**레이아웃**

```
┌─────────────────────────────┐
│ SafeTrip 🔔 ⚙️              │ AppBar_Map (로고 좌 + 알림/설정 우)
├─────────────────────────────┤
│                             │
│    ┌───────────────────┐    │
│    │                   │    │
│    │    (지도 배경)      │    │ GoogleMap (탐색 모드)
│    │   멤버 마커 없음    │    │ 마커 비활성
│    │                   │    │
│    │                   │    │
│    └───────────────────┘    │
│                             │
│  ┌─────────────────────────┐│
│  │                         ││
│  │    🧳 (일러스트)         ││ Card_Standard (반투명)
│  │                         ││ radius16, shadow, center
│  │  여행을 시작해보세요      ││ titleLarge (20sp, SemiBold)
│  │                         ││
│  │  새 여행을 만들거나       ││ bodyMedium (14sp)
│  │  초대코드로 참여하세요    ││ onSurfaceVariant
│  │                         ││
│  │ ┌───────────┐┌─────────┐││
│  │ │ 여행 만들기 ││코드 입력 │││ Button_Primary + Button_Secondary
│  │ └───────────┘└─────────┘││ 가로 배치 (Row, spacing8)
│  │                         ││
│  └─────────────────────────┘│
│                             │
├─────────────────────────────┤
│ [일정🔒][멤버🔒][채팅🔒][안전가이드📖]│ NavBar_Crew
│                             │ 안전가이드만 활성 (primaryTeal)
│                             │ 나머지 3탭 비활성 (회색+잠금아이콘)
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `Stack` + `Positioned` | style: AppBar_Map, leading: SafeTrip 로고 (primaryTeal), actions: 알림 벨 아이콘 + 설정 기어 아이콘 |
| 지도 배경 | `GoogleMap` | 사용자 현재 위치 기준 도시 표시, 마커 없음, 인터랙션 가능 (탐색 모드) |
| 오버레이 카드 | `Card` | style: Card_Standard, radius16, backgroundColor: surface 90% opacity, 중앙 정렬, padding: spacing16 |
| 일러스트 | `Image.asset` | width: 80, height: 80, 여행 가방/지구본 아이콘 |
| 제목 | `Text` | style: titleLarge (20sp, SemiBold), color: onSurface, textAlign: center |
| 부제목 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, textAlign: center |
| 여행 만들기 버튼 | `ElevatedButton` | style: Button_Primary, text: "여행 만들기", flex: 1 |
| 코드 입력 버튼 | `OutlinedButton` | style: Button_Secondary, text: "코드 입력", flex: 1 |
| 하단 탭바 | `BottomNavigationBar` | style: NavBar_Crew, 안전가이드 탭만 활성 (primaryTeal), 나머지 disabled (onSurfaceVariant + lock) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 지도 배경 로드 + 오버레이 카드 중앙 표시, 탭바 3탭 비활성 (잠금 아이콘) |
| 지도 로딩 중 | 지도 영역에 CircularProgressIndicator 표시 |
| 지도 로드 완료 | 지도 배경 표시, 마커 없음 (none 상태) |
| 안전가이드 탭 활성 | 바텀시트로 안전가이드 컨텐츠 표시 (여행 국가 미선택 → 일반 안전 가이드) |
| 비활성 탭 탭 시 | Toast "여행에 참여한 후 이용할 수 있습니다" |
| 네트워크 오류 | 지도 로드 실패 → 기본 배경 이미지 + 오버레이 카드 유지 |

**인터랙션**

- [탭] 여행 만들기 → Navigator.push → B-02 여행 만들기
- [탭] 코드 입력 → Navigator.push → B-07 초대코드 입력
- [탭] 안전가이드 탭 → 바텀시트 열림 (일반 안전 가이드 표시)
- [탭] 비활성 탭 (일정/멤버/채팅) → Toast "여행에 참여한 후 이용할 수 있습니다"
- [탭] 알림 아이콘 → Navigator.push → 알림 목록 화면
- [탭] 설정 아이콘 → Navigator.push → K-01 설정 화면
- [제스처] 지도 핀치/드래그 → 지도 탐색 (마커 없는 탐색 모드)

---

### B-02 여행 만들기 (Trip Create Form)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | B-02 |
| 화면명 | 여행 만들기 (Trip Create Form) |
| Phase | P0 |
| 역할 | 캡틴 (여행 생성자) |
| 진입 경로 | B-01 여행 없음 홈 (여행 만들기 탭) → B-02 |
| 이탈 경로 | B-02 → B-03 (국가 선택 탭) / B-02 → B-04 (다음 버튼, 스텝 1 완료) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 여행 만들기     1/4      │ AppBar_Standard + 스텝 인디케이터
├─────────────────────────────┤
│                             │
│  여행 정보를 입력해주세요     │ headlineMedium (24sp, SemiBold)
│                             │
│  ┌─ 여행 이름 ──────────────┐│
│  │ 예: 도쿄 자유여행          ││ Input_Text
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─ 국가 선택 ──────────────┐│
│  │ 🇰🇷 선택해주세요      ▼   ││ DropdownField → B-03 호출
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─ 도시 ──────────────────┐│
│  │ 예: 도쿄, 오사카          ││ Input_Text
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─ 여행 기간 ──────────────┐│
│  │ 📅 시작일 ~ 종료일        ││ DateRangePicker
│  │    (최대 15일)            ││ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │ spacing16
│  여행 유형                   │ bodyMedium (14sp, SemiBold)
│  ┌──────────┐ ┌──────────┐  │
│  │ ✈️ 개인    │ │ 🎒 투어   │  │ Chip_Tag (2개, 단일 선택)
│  │    여행   │ │   리더   │  │ 선택 시 primaryTeal 배경
│  └──────────┘ └──────────┘  │
│                             │
│                             │
│  ┌─────────────────────────┐│
│  │       다음               ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "여행 만들기", leading: BackButton, actions: Text("1/4", bodySmall, onSurfaceVariant), style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 여행 이름 입력 | `TextFormField` | style: Input_Text, hintText: "예: 도쿄 자유여행", maxLength: 30, validator: 필수 (2~30자) |
| 국가 선택 필드 | `InkWell` + `Container` | style: Input_Text 유사, 우측 chevron_down 아이콘, 탭 시 B-03 모달 호출, 선택 후 국기+국가명 표시 |
| 도시 입력 | `TextFormField` | style: Input_Text, hintText: "예: 도쿄, 오사카", maxLength: 50 |
| 여행 기간 선택 | `InkWell` + `Container` | 좌측 📅 아이콘, 탭 시 DateRangePicker 표시, 최대 15일 제한, 선택 후 "YYYY.MM.DD ~ YYYY.MM.DD (N일)" 표시 |
| 여행 유형 라벨 | `Text` | style: bodyMedium (14sp, SemiBold), color: onSurface |
| 여행 유형 칩 | `ChoiceChip` x 2 | style: Chip_Tag, labels: ["✈️ 개인 여행", "🎒 투어 리더"], selectedColor: primaryTeal, 기본 선택: 개인 여행 |
| 다음 버튼 | `ElevatedButton` | style: Button_Primary, text: "다음", enabled: 필수 입력 완료 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 모든 필드 비어있음, 여행 유형 "개인 여행" 기본 선택, 다음 버튼 비활성 (opacity 0.4) |
| 여행 이름 입력 중 | Input_Text 포커스 보더 primaryTeal, 실시간 글자 수 카운트 (우측 하단) |
| 국가 선택 완료 | 필드에 국기 이모지 + 국가명 표시 (예: "🇯🇵 일본") |
| 도시 입력 완료 | Input_Text filled 상태 |
| 날짜 범위 선택 중 | Modal_Bottom DateRangePicker 표시, primaryTeal 강조 |
| 날짜 범위 15일 초과 | Toast "여행 기간은 최대 15일까지 가능합니다" |
| 필수 입력 완료 | 다음 버튼 활성 (primaryTeal), 여행 이름 + 국가 + 날짜 필수 |
| 다음 탭 | Navigator.push → B-04 프라이버시 등급 선택 |

**인터랙션**

- [탭] 여행 이름 입력 → 키보드 표시
- [탭] 국가 선택 필드 → Modal_Bottom → B-03 국가 선택 화면 (바텀시트)
- [탭] 도시 입력 → 키보드 표시
- [탭] 여행 기간 필드 → Modal_Bottom DateRangePicker 표시
- [탭] 여행 유형 칩 (개인/투어 리더) → 선택 토글 (단일 선택)
- [탭] 다음 → Navigator.push → B-04 프라이버시 등급 선택 (입력 데이터 전달)
- [뒤로가기] → B-01 여행 없음 홈 (입력 데이터 유실 경고 Dialog_Confirm)

---

### B-03 국가 선택 (Country Picker)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | B-03 |
| 화면명 | 국가 선택 (Country Picker) |
| Phase | P0 |
| 역할 | 캡틴 |
| 진입 경로 | B-02 여행 만들기 (국가 선택 필드 탭) → B-03 |
| 이탈 경로 | B-03 → B-02 (국가 선택 완료 / 닫기) |

**레이아웃**

```
┌─────────────────────────────┐
│         ── (드래그 핸들)       │ 바텀시트 핸들 (4px x 44px)
│  국가 선택               ✕   │ titleLarge + 닫기 버튼
├─────────────────────────────┤
│  ┌─────────────────────────┐│
│  │ 🔍 국가명 검색            ││ Input_Search
│  └─────────────────────────┘│
│                             │
│  최근 선택                   │ bodySmall (12sp), onSurfaceVariant
│  ┌──────┐ ┌──────┐ ┌──────┐│
│  │🇯🇵 일본│ │🇹🇭 태국│ │🇻🇳 베트남││ Chip_Tag (horizontal scroll)
│  └──────┘ └──────┘ └──────┘│
│                             │
│  ─────────────────────────── │ Divider
│                             │
│  ㄱ                          │ 초성 섹션 헤더, bodySmall, Bold
│  ┌─────────────────────────┐│
│  │ 🇬🇭 가나          Ghana   ││ ListTile (국기+한글명+영문명)
│  ├─────────────────────────┤│
│  │ 🇬🇾 가이아나      Guyana  ││
│  ├─────────────────────────┤│
│  │ 🇬🇦 가봉          Gabon   ││
│  └─────────────────────────┘│
│                             │
│  ㄴ                          │ 초성 섹션 헤더
│  ┌─────────────────────────┐│
│  │ 🇳🇬 나이지리아    Nigeria ││
│  ├─────────────────────────┤│
│  │ 🇳🇦 나미비아      Namibia ││
│  └─────────────────────────┘│
│                             │
│  ...                        │ (스크롤 가능)
│                             │
│  ┌──────┐  (우측 초성 인덱스)  │ AlphabetScrollbar
│  │ ㄱ   │                   │ ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎ
│  │ ㄴ   │                   │
│  │ ...  │                   │
│  └──────┘                   │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 바텀시트 | `showModalBottomSheet` | style: Modal_Bottom, radius20 top, 높이: 화면 85%, isScrollControlled: true |
| 핸들 바 | `Container` | width: 44, height: 4, color: line04, borderRadius: radius48 |
| 헤더 | `Row` | children: [Text("국가 선택", titleLarge), Spacer, IconButton(close)] |
| 검색 입력 | `TextField` | style: Input_Search, hintText: "국가명 검색", prefixIcon: Icons.search, 초성 검색 지원 |
| 최근 선택 라벨 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 최근 선택 칩 | `Wrap` < `ActionChip` > | style: Chip_Tag, 국기+국가명, 최대 5개 표시, horizontal scroll |
| 구분선 | `Divider` | color: outline (#EDEDED) |
| 초성 헤더 | `Text` | style: bodySmall (12sp, Bold), color: onSurfaceVariant, padding: spacing8 |
| 국가 행 | `ListTile` | leading: Text(국기, 24sp), title: Text(한글명, bodyLarge), subtitle: Text(영문명, bodySmall, onSurfaceVariant), trailing: 선택 시 Icon(check, primaryTeal) |
| 초성 인덱스 | `AlphabetScrollbar` (custom) | 우측 고정, ㄱ~ㅎ 14개 초성, 터치 시 해당 섹션 스크롤 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 검색 필드 비어있음, 최근 선택 국가 표시 (없으면 섹션 숨김), 전체 국가 목록 초성순 정렬 |
| 검색 입력 중 | 실시간 필터링 (한글 초성 검색 지원: "ㅇ" → 일본, 영국, ...), 최근 선택 섹션 숨김 |
| 검색 결과 없음 | "검색 결과가 없습니다" 안내 텍스트 (중앙, onSurfaceVariant) |
| 국가 선택 | 선택 행 우측에 체크 아이콘 (primaryTeal), 이전 선택 해제 |
| 국가 선택 완료 | 0.3초 후 바텀시트 닫힘, B-02 국가 필드에 국기+국가명 반영 |
| 로딩 | 국가 목록 로딩 중 → Shimmer placeholder |

**인터랙션**

- [입력] 검색 필드 → 실시간 국가 필터링 (초성 검색: "ㅇ" → 일본/영국/..., 전체 이름 검색)
- [탭] 최근 선택 칩 → 해당 국가 즉시 선택 → 바텀시트 닫힘
- [탭] 국가 행 → 해당 국가 선택 → 0.3초 후 바텀시트 닫힘 → B-02 반영
- [탭] 초성 인덱스 → 해당 초성 섹션으로 스크롤 이동
- [탭] 닫기 (✕) → 바텀시트 닫힘 (선택 변경 없음)
- [스와이프 하] 핸들 바 → 바텀시트 닫힘

---

### B-04 프라이버시 등급 선택 (Privacy Level)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | B-04 |
| 화면명 | 프라이버시 등급 선택 (Privacy Level) |
| Phase | P0 |
| 역할 | 캡틴 |
| 진입 경로 | B-02 여행 만들기 (다음 버튼) → B-04 |
| 이탈 경로 | B-04 → B-05 (다음 버튼) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 프라이버시 등급    2/4    │ AppBar_Standard + 스텝
├─────────────────────────────┤
│                             │
│  여행 참여자의 위치 공유       │ bodyMedium (14sp)
│  정책을 선택하세요            │ onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │🛡️                        ││
│  │ 안전 최우선               ││ Card_Selectable
│  │ Safety First             ││ 좌측 보더: #DA4C51
│  │                         ││
│  │ 미성년자, 학교 단체,       ││ bodySmall, onSurfaceVariant
│  │ 어학연수                  ││
│  │                         ││
│  │ • 가디언 24시간 실시간 접근 ││ bodySmall
│  │ • 멤버 일시정지 불가        ││
│  │                         ││
│  │ 👶 미성년자 포함 시 추천    ││ Chip_Tag (semanticError bg)
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │📍                    ✓   ││
│  │ 표준                     ││ Card_Selectable (기본 선택)
│  │ Standard                 ││ 좌측 보더: #00A2BD
│  │                         ││ 체크 아이콘: primaryTeal
│  │ 일반 단체, 가족 여행       ││
│  │                         ││
│  │ • ON 시간 실시간,          ││
│  │   OFF 시간 30분 스냅샷     ││
│  │ • 최대 12시간 일시정지      ││
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │🔒                        ││
│  │ 프라이버시 우선            ││ Card_Selectable
│  │ Privacy First            ││ 좌측 보더: #A7A7A7
│  │                         ││
│  │ 비즈니스 출장, 성인 투어    ││
│  │                         ││
│  │ • ON 시간만 실시간,        ││
│  │   OFF 시간 비공개          ││
│  │ • 최대 24시간 일시정지      ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │       다음               ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "프라이버시 등급", leading: BackButton, actions: Text("2/4", bodySmall), style: AppBar_Standard |
| 안내 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 안전 최우선 카드 | `Card` + `InkWell` | style: Card_Selectable, 선택 시 좌측 보더 #DA4C51 + 배경 tint, icon: 🛡️ |
| 표준 카드 | `Card` + `InkWell` | style: Card_Selectable, 기본 선택, 좌측 보더 #00A2BD + 우측 상단 체크 아이콘 (primaryTeal) |
| 프라이버시 우선 카드 | `Card` + `InkWell` | style: Card_Selectable, 선택 시 좌측 보더 #A7A7A7 + 배경 tint |
| 카드 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 카드 부제목 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 카드 설명 항목 | `Row` | leading: bullet (6dp 원), text: bodySmall (12sp), color: onSurface |
| 추천 칩 | `Container` | style: Chip_Tag, text: "👶 미성년자 포함 시 추천", backgroundColor: semanticError 10% opacity |
| 다음 버튼 | `ElevatedButton` | style: Button_Primary, text: "다음" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 표준 카드 기본 선택 (좌측 teal 보더 + 체크 아이콘 + 배경 tint), 다음 버튼 활성 |
| 안전 최우선 선택 | 해당 카드 좌측 #DA4C51 보더 + 배경 tint + 체크, 나머지 카드 unselected |
| 표준 선택 | 해당 카드 좌측 #00A2BD 보더 + 배경 tint + 체크 |
| 프라이버시 우선 선택 | 해당 카드 좌측 #A7A7A7 보더 + 배경 tint + 체크 |

**인터랙션**

- [탭] 안전 최우선 카드 → 선택 (나머지 해제)
- [탭] 표준 카드 → 선택 (나머지 해제)
- [탭] 프라이버시 우선 카드 → 선택 (나머지 해제)
- [탭] 다음 → Navigator.push → B-05 위치공유 모드 선택 (선택 등급 전달)
- [뒤로가기] → B-02 여행 만들기 (선택 데이터 유지)

---

### B-05 위치공유 모드 선택 (Location Sharing Mode)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | B-05 |
| 화면명 | 위치공유 모드 선택 (Location Sharing Mode) |
| Phase | P0 |
| 역할 | 캡틴 |
| 진입 경로 | B-04 프라이버시 등급 선택 (다음 버튼) → B-05 |
| 이탈 경로 | B-05 → B-06 (다음 버튼) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 위치공유 모드      3/4   │ AppBar_Standard + 스텝
├─────────────────────────────┤
│                             │
│  멤버들의 위치 공유           │ bodyMedium (14sp)
│  방식을 선택하세요            │ onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │ 🔗                   ✓  ││
│  │ 강제 공유                ││ Card_Selectable (기본 선택)
│  │ Mandatory Sharing       ││ 좌측 보더: primaryTeal
│  │                         ││
│  │ 캡틴이 설정한 스케줄을     ││ bodyMedium (14sp)
│  │ 모든 멤버가 따릅니다      ││ onSurfaceVariant
│  │                         ││
│  │ ✓ 통일된 관리             ││ bodySmall, primaryTeal
│  │ ✓ 간편한 설정             ││
│  │                         ││
│  │ ┌─────────────────────┐ ││
│  │ │ 단체 여행 추천        │ ││ Chip_Tag (primaryTeal bg)
│  │ └─────────────────────┘ ││
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │ 🔓                      ││
│  │ 자유 설정                ││ Card_Selectable
│  │ Free Setting            ││ 좌측 보더: onSurfaceVariant
│  │                         ││
│  │ 각 멤버가 자신의 공유      ││ bodyMedium (14sp)
│  │ 스케줄과 가시범위를        ││ onSurfaceVariant
│  │ 설정합니다                ││
│  │                         ││
│  │ ✓ 개인 프라이버시 존중     ││ bodySmall, primaryTeal
│  │ ✓ 유연한 설정             ││
│  │                         ││
│  │ ┌─────────────────────┐ ││
│  │ │ 소규모/성인 여행 추천  │ ││ Chip_Tag (gray bg)
│  │ └─────────────────────┘ ││
│  └─────────────────────────┘│
│                             │
│  ─────────────────────────── │ Divider
│                             │
│  ┌─────────────────────────┐│
│  │ 모드 비교                ││ Card_Standard (축소 가능)
│  │                         ││
│  │         강제공유  자유설정 ││ bodySmall, 비교 테이블
│  │ 스케줄   캡틴통합  개인별  ││
│  │ 가시범위 전체통일  개별설정 ││
│  │ 변경권한 캡틴전용  각멤버  ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │       다음               ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "위치공유 모드", leading: BackButton, actions: Text("3/4", bodySmall), style: AppBar_Standard |
| 안내 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 강제 공유 카드 | `Card` + `InkWell` | style: Card_Selectable, 기본 선택, 좌측 보더 primaryTeal + 체크, icon: 🔗 |
| 자유 설정 카드 | `Card` + `InkWell` | style: Card_Selectable, 선택 시 좌측 보더 primaryTeal, icon: 🔓 |
| 카드 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 카드 영문명 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 카드 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 장점 항목 | `Row` | leading: Icon(check, 14sp, primaryTeal), text: bodySmall (12sp) |
| 추천 칩 (강제) | `Container` | style: Chip_Tag, text: "단체 여행 추천", backgroundColor: primaryTeal 15% opacity, textColor: primaryTeal |
| 추천 칩 (자유) | `Container` | style: Chip_Tag, text: "소규모/성인 여행 추천", backgroundColor: surfaceVariant |
| 비교 테이블 | `Table` | style: Card_Standard 내부, 3행 3열 비교 테이블, headerRow: Bold |
| 다음 버튼 | `ElevatedButton` | style: Button_Primary, text: "다음" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 강제 공유 카드 기본 선택 (좌측 teal 보더 + 체크 아이콘 + 배경 tint), 다음 버튼 활성 |
| 강제 공유 선택 | 해당 카드 selected 상태, 자유 설정 카드 unselected |
| 자유 설정 선택 | 해당 카드 selected 상태, 강제 공유 카드 unselected |
| 비교 테이블 접기/펼치기 | ExpansionTile 토글, 기본 펼침 상태 |

**인터랙션**

- [탭] 강제 공유 카드 → 선택 (자유 설정 해제)
- [탭] 자유 설정 카드 → 선택 (강제 공유 해제)
- [탭] 모드 비교 카드 헤더 → 비교 테이블 접기/펼치기 토글
- [탭] 다음 → Navigator.push → B-06 여행 확인 (전체 데이터 전달)
- [뒤로가기] → B-04 프라이버시 등급 선택 (선택 데이터 유지)

---

### B-06 여행 확인 (Trip Confirmation)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | B-06 |
| 화면명 | 여행 확인 (Trip Confirmation) |
| Phase | P0 |
| 역할 | 캡틴 |
| 진입 경로 | B-05 위치공유 모드 선택 (다음 버튼) → B-06 |
| 이탈 경로 | B-06 → C-01 메인맵 (여행 생성 완료) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 여행 확인          4/4   │ AppBar_Standard + 스텝
├─────────────────────────────┤
│                             │
│  입력한 정보를 확인해주세요    │ bodyMedium (14sp)
│                             │ onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │                         ││ Card_Standard
│  │ 🇯🇵 도쿄 자유여행         ││ titleMedium (18sp, SemiBold)
│  │                         ││
│  │ ──────────────────────  ││ Divider (내부)
│  │                         ││
│  │ 📅 2026.03.15 ~ 03.22   ││ bodyMedium, onSurface
│  │    8일                  ││ bodySmall, onSurfaceVariant
│  │                         ││
│  │ 📍 일본, 도쿄            ││ bodyMedium, onSurface
│  │                         ││
│  │ 🛡️ 표준                  ││ bodyMedium + Badge (primaryTeal bg)
│  │    Standard             ││ bodySmall, onSurfaceVariant
│  │                         ││
│  │ 🔗 강제 공유              ││ bodyMedium, onSurface
│  │    Mandatory Sharing    ││ bodySmall, onSurfaceVariant
│  │                         ││
│  │ ✈️ 개인 여행              ││ bodyMedium, onSurface
│  │                         ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ 💡 여행 생성 후 초대코드로 ││ Card_Standard
│  │    멤버를 초대할 수        ││ backgroundColor: secondaryBeige
│  │    있습니다               ││ bodySmall, onSurface
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ ⚠️ 6명 이상 참여 시       ││ Card_Standard (조건부 표시)
│  │    9,900원이 발생합니다    ││ bodySmall, semanticWarning
│  └─────────────────────────┘│ Visibility (멤버 6명+ 시)
│                             │
│  ┌─────────────────────────┐│
│  │       여행 만들기          ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "여행 확인", leading: BackButton, actions: Text("4/4", bodySmall), style: AppBar_Standard |
| 안내 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 요약 카드 | `Card` | style: Card_Standard, radius16, padding: spacing16 |
| 여행명 (국기 포함) | `Row` | children: [Text(국기, 24sp), SizedBox(8), Text(여행명, titleMedium, SemiBold)] |
| 구분선 | `Divider` | color: outline (#EDEDED), height: 1 |
| 정보 행 | `Row` | leading: Text(이모지, 20sp), SizedBox(12), Column[Text(값, bodyMedium), Text(부가, bodySmall, onSurfaceVariant)] |
| 프라이버시 뱃지 | `Container` | pill shape, backgroundColor: primaryTeal 15% opacity, textColor: primaryTeal, text: 등급명 |
| 안내 카드 | `Card` | style: Card_Standard, backgroundColor: secondaryBeige (#F2EDE4), padding: spacing12 |
| 안내 텍스트 | `Row` | children: [Text("💡", 16sp), SizedBox(8), Text(안내 문구, bodySmall)] |
| 결제 안내 카드 | `Card` | style: Card_Standard, border: semanticWarning 1px, Visibility: 6명 이상 시 표시 |
| 여행 만들기 버튼 | `ElevatedButton` | style: Button_Primary, text: "여행 만들기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 요약 카드에 B-02~B-05에서 입력한 모든 정보 표시, 결제 안내 카드 숨김 (기본) |
| 결제 필요 시 | 결제 안내 카드 표시 (6명 이상 조건은 여행 생성 시점에는 1명이므로 기본 숨김) |
| 생성 중 | 여행 만들기 버튼 → CircularProgressIndicator (white, 24dp) |
| 생성 성공 | Toast "여행이 생성되었습니다!" + Navigator.pushReplacement → C-01 메인맵 (planning 상태) |
| 생성 실패 | SnackBar "여행 생성에 실패했습니다. 다시 시도해주세요." |
| 네트워크 오류 | SnackBar "인터넷 연결을 확인해주세요" + 버튼 활성 유지 |

**인터랙션**

- [탭] 여행 만들기 → POST /api/v1/trips (여행 생성 API) → 성공 시 C-01 메인맵
- [탭] 요약 카드 각 행 → 해당 스텝으로 Navigator.pop (수정 가능)
- [뒤로가기] → B-05 위치공유 모드 선택 (데이터 유지)

---

### B-07 초대코드 입력 (Invite Code Input)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | B-07 |
| 화면명 | 초대코드 입력 (Invite Code Input) |
| Phase | P0 |
| 역할 | 크루 (여행 참여자) |
| 진입 경로 | B-01 여행 없음 홈 (코드 입력 탭) → B-07 / 딥링크 → B-07 (코드 사전 입력) |
| 이탈 경로 | B-07 → B-08 (유효한 코드 입력 시) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 여행 참여                │ AppBar_Standard
├─────────────────────────────┤
│                             │
│                             │
│        ┌───────────┐        │
│        │           │        │
│        │  👥 🗺️     │        │ Image (일러스트)
│        │ (그룹+핀)  │        │ width: 160, height: 120
│        │           │        │
│        └───────────┘        │
│                             │
│  초대코드를 입력하세요        │ titleLarge (20sp, SemiBold)
│                             │ 중앙 정렬
│  캡틴에게 받은 6자리          │ bodyMedium (14sp)
│  코드를 입력해주세요          │ onSurfaceVariant, 중앙 정렬
│                             │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐│
│  │   │ │   │ │   │ │   │ │   │ │   ││ Input_OTP (6자리)
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘│ 영숫자 대문자
│                             │
│                             │
│                             │
│                             │
│                             │
│  ┌─────────────────────────┐│
│  │       참여하기            ││ Button_Primary
│  └─────────────────────────┘│
│                             │
│    📷 QR 코드로 참여          │ TextButton, primaryTeal
│                             │ 카메라 아이콘 + 텍스트
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "여행 참여", leading: BackButton, style: AppBar_Standard |
| 일러스트 | `Image.asset` | width: 160, height: 120, fit: BoxFit.contain, 그룹+위치핀 일러스트 |
| 제목 | `Text` | style: titleLarge (20sp, SemiBold), color: onSurface, textAlign: center |
| 부제목 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, textAlign: center |
| 코드 입력 | `Row` < `TextField` x 6 > | style: Input_OTP, 각 셀 48x56dp, radius8, 영숫자 대문자, 자동 포커스 이동, keyboardType: TextInputType.text, textCapitalization: characters |
| 참여하기 버튼 | `ElevatedButton` | style: Button_Primary, text: "참여하기", enabled: 6자리 입력 완료 시 |
| QR 참여 버튼 | `TextButton` | icon: Icons.camera_alt (16sp), text: "QR 코드로 참여", color: primaryTeal, style: labelMedium |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 첫 번째 셀 자동 포커스, 참여하기 버튼 비활성 (opacity 0.4) |
| 딥링크 진입 | 코드 6자리 사전 입력됨, 참여하기 버튼 활성, 자동 조회 시도 |
| 입력 중 | 활성 셀 보더 primaryTeal, 입력 완료 셀 자동 다음 포커스 이동 |
| 6자리 완료 | 참여하기 버튼 활성 (primaryTeal) |
| 조회 중 | 버튼 → CircularProgressIndicator (white, 24dp) |
| 조회 성공 | Navigator.push → B-08 여행 미리보기 (여행 데이터 전달) |
| 코드 무효 | 전체 셀 보더 semanticError (#DA4C51), 셀 내용 클리어, Toast "유효하지 않은 초대코드입니다" |
| 코드 만료 | 전체 셀 보더 semanticError, Toast "만료된 초대코드입니다. 캡틴에게 새 코드를 요청하세요" |
| 여행 정원 초과 | Toast "해당 여행의 참여 인원이 가득 찼습니다" |
| 네트워크 오류 | SnackBar "인터넷 연결을 확인해주세요" + 버튼 활성 유지 |

**인터랙션**

- [입력] 코드 셀 → 영숫자 입력 시 자동 대문자 변환 + 다음 셀 이동, 백스페이스 시 이전 셀 이동
- [탭] 참여하기 → GET /api/v1/trips/join-preview?code={code} → 성공 시 B-08
- [탭] QR 코드로 참여 → 카메라 권한 요청 → QR 스캐너 열림 → 코드 자동 입력
- [붙여넣기] 클립보드 6자리 코드 → 전체 셀 자동 채움
- [뒤로가기] → B-01 여행 없음 홈

---

### B-08 여행 미리보기 (Trip Preview)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | B-08 |
| 화면명 | 여행 미리보기 (Trip Preview) |
| Phase | P0 |
| 역할 | 크루 (여행 참여 전) |
| 진입 경로 | B-07 초대코드 입력 (유효 코드 조회 성공) → B-08 |
| 이탈 경로 | B-08 → C-01 메인맵 (참여 완료) / B-08 → B-07 (취소) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 여행 미리보기             │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │                         ││ Card_Standard (큰 그림자)
│  │         🇯🇵              ││ 국기 (48px), 중앙 정렬
│  │                         ││
│  │    도쿄 자유여행          ││ headlineMedium (24sp, SemiBold)
│  │                         ││ 중앙 정렬
│  │  ────────────────────── ││ Divider
│  │                         ││
│  │  📅 2026.03.15 ~ 03.22  ││ bodyMedium, onSurface
│  │     8일                 ││ bodySmall, onSurfaceVariant
│  │                         ││
│  │  👤 캡틴: 김철수          ││ bodyMedium, onSurface
│  │     ┌────┐              ││ CircleAvatar (24dp)
│  │     │ 아바│              ││ + Badge_Role (캡틴)
│  │     └────┘              ││
│  │                         ││
│  │  👥 현재 5명 참여 중      ││ bodyMedium, onSurface
│  │                         ││
│  │  🛡️ 프라이버시: 표준      ││ bodyMedium + Badge
│  │     ┌──────┐            ││ primaryTeal 배경 뱃지
│  │     │ 표준  │            ││
│  │     └──────┘            ││
│  │                         ││
│  └─────────────────────────┘│
│                             │
│                             │
│  ┌─────────────────────────┐│
│  │       참여하기            ││ Button_Primary
│  └─────────────────────────┘│
│                             │
│          취소                │ Button_Secondary (TextButton)
│                             │ onSurfaceVariant
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "여행 미리보기", leading: BackButton, style: AppBar_Standard |
| 미리보기 카드 | `Card` | style: Card_Standard, radius16, elevation: 8 (강조), padding: spacing20 |
| 국기 | `Text` | fontSize: 48, textAlign: center |
| 여행명 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface, textAlign: center |
| 구분선 | `Divider` | color: outline (#EDEDED), height: 1, indent/endIndent: spacing16 |
| 기간 행 | `Row` | leading: Text("📅", 20sp), Column[Text(기간, bodyMedium), Text(일수, bodySmall, onSurfaceVariant)] |
| 캡틴 행 | `Row` | leading: Text("👤", 20sp), Text("캡틴: ", bodyMedium), Text(이름, bodyMedium, SemiBold), CircleAvatar(12dp) + Badge_Role |
| 멤버 수 행 | `Row` | leading: Text("👥", 20sp), Text("현재 N명 참여 중", bodyMedium) |
| 프라이버시 행 | `Row` | leading: Text("🛡️", 20sp), Text("프라이버시: ", bodyMedium), Container(pill, primaryTeal 15% bg, text: 등급명, labelSmall) |
| 참여하기 버튼 | `ElevatedButton` | style: Button_Primary, text: "참여하기" |
| 취소 버튼 | `TextButton` | text: "취소", style: bodyMedium, color: onSurfaceVariant |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 여행 정보 카드에 서버에서 조회된 데이터 표시, 참여하기 버튼 활성 |
| 참여 중 | 참여하기 버튼 → CircularProgressIndicator (white, 24dp) |
| 참여 성공 | Toast "여행에 참여했습니다!" + Navigator.pushReplacement → C-01 메인맵 (planning 상태) |
| 참여 실패 | SnackBar "여행 참여에 실패했습니다. 다시 시도해주세요." |
| 이미 참여 중 | Toast "이미 참여 중인 여행입니다" + Navigator.pushReplacement → C-01 메인맵 |
| 여행 정원 초과 | 참여하기 버튼 비활성, 안내 텍스트 "참여 인원이 가득 찼습니다" (semanticError) |
| 네트워크 오류 | SnackBar "인터넷 연결을 확인해주세요" + 버튼 활성 유지 |

**인터랙션**

- [탭] 참여하기 → POST /api/v1/trips/{tripId}/join → 성공 시 C-01 메인맵
- [탭] 취소 → Navigator.pop → B-07 초대코드 입력
- [뒤로가기] → B-07 초대코드 입력

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 8개 화면 (B-01 ~ B-08) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 화면 구성 원칙: `Master_docs/10_T2_화면구성원칙.md`
