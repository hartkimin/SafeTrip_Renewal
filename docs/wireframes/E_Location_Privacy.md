# E. 위치공유 & 프라이버시

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 위치공유 설정 및 프라이버시 관련 8개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |
| 와이어프레임 설계 스펙 | `docs/plans/2026-03-03-wireframe-design.md` |
| DB 설계 | `Master_docs/07_T2_DB_설계_및_관계_v3_4.md` |

---

## 개요

- **화면 수:** 8개 (E-01 ~ E-08)
- **Phase:** P0 1개 (E-01), P1 7개 (E-02 ~ E-08)
- **핵심 역할:** 크루 (위치 설정), 캡틴 (프라이버시/모드 변경)
- **연관 문서:** 비즈니스 원칙 &sect;04 위치공유, &sect;05 프라이버시

### 프라이버시 등급별 UI 매트릭스

> 출처: 화면구성원칙 &sect;7, 와이어프레임 설계 &sect;3.5

| 동작 | 안전최우선 (🛡️ `#DA4C51`) | 표준 (📍 `#00A2BD`) | 프라이버시우선 (🔒 `#A7A7A7`) |
|------|:------------------------:|:------------------:|:--------------------------:|
| 스케줄 ON 시 마커 | ✅ 실시간 | ✅ 실시간 | ✅ 실시간 |
| 스케줄 OFF 시 마커 | ✅ 실시간 | ✅ 희미 (30분 스냅샷) | ❌ 마커 제거 |
| 가디언 위치 접근 | 항상 (실시간) | 실시간 | 승인 후 1회 |
| 가디언 일시정지 | ❌ 불가 | ✅ 최대 12h | ✅ 최대 24h |
| 위치 공유 OFF 허용 | ❌ (토글 비활성) | ✅ | ✅ |
| 가시범위 설정 | ❌ (전체 고정) | ✅ (자유 모드 시) | ✅ (자유 모드 시) |

### 공유 모드 비교

| 항목 | 강제 모드 (Forced) | 자유 모드 (Free) |
|------|:-----------------:|:---------------:|
| 위치 공유 ON/OFF 토글 | 비활성 (항상 ON) | 활성 (사용자 선택) |
| 스케줄 설정 | 캡틴만 설정 | 각 멤버 개별 설정 |
| 가시범위 설정 | 전체 고정 | 멤버별 자유 설정 |
| 수동 활성화 | 불가 | 가능 |

---

## User Journey Flow

```
C-01 메인맵 → 멤버탭/설정
 │
 └──→ E-01 위치공유 설정 모달
       ├── [스케줄 설정] ──→ E-02 공유 스케줄 설정
       ├── [이벤트 연동] ──→ E-03 이벤트 연동 설정
       ├── [가시범위] ────→ E-04 가시범위 설정 (자유 모드만)
       └── [가디언 일시정지] → E-05 가디언 접근 일시정지

C-01 메인맵 → 설정 (캡틴 전용)
 ├──→ E-06 프라이버시 등급 변경 확인
 ├──→ E-07 공유모드 전환 확인
 └──→ E-08 지오펜스 관리 (캡틴/크루장)
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| C-01 메인맵 (멤버탭) | 내 위치 설정 탭 | E-01 위치공유 설정 모달 | E |
| C-01 메인맵 (설정) | 위치공유 설정 메뉴 | E-01 위치공유 설정 모달 | E |
| E-01 | 스케줄 설정 탭 | E-02 공유 스케줄 설정 | E |
| E-01 | 이벤트 연동 탭 | E-03 이벤트 연동 설정 | E |
| E-01 | 가시범위 탭 (자유 모드) | E-04 가시범위 설정 | E |
| E-01 | 가디언 일시정지 | E-05 가디언 접근 일시정지 | E |
| D-04 여행 설정 | 프라이버시 등급 변경 (캡틴) | E-06 프라이버시 등급 변경 확인 | E |
| D-04 여행 설정 | 공유 모드 전환 (캡틴) | E-07 공유모드 전환 확인 | E |
| C-01 메인맵 (지도) | 지오펜스 편집 버튼 (캡틴/크루장) | E-08 지오펜스 관리 | E |
| E-08 | 완료/닫기 | C-01 메인맵 | C |

---

## 화면 상세

---

### E-01 위치공유 설정 모달 (Location Sharing Main)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | E-01 |
| 화면명 | 위치공유 설정 모달 (Location Sharing Main) |
| Phase | P0 |
| 역할 | 크루 (캡틴, 크루장, 크루) |
| 진입 경로 | C-01 멤버탭 (내 위치 설정) → E-01 / C-01 설정 아이콘 → E-01 |
| 이탈 경로 | E-01 → E-02 (스케줄) / E-03 (이벤트) / E-04 (가시범위) / E-05 (가디언 일시정지) / 닫기 → C-01 |

**레이아웃**

```
┌─────────────────────────────┐
│         ─────               │ 핸들 바 (4px x 44px)
│                             │
│  위치 공유 설정              │ titleLarge (20sp, SemiBold)
│                             │
│  ┌─────────────────────────┐│
│  │ 🛡️ 안전최우선              ││ 현재 프라이버시 등급
│  │ 강제 모드                 ││ 현재 공유 모드
│  │ ────────────────────     ││
│  │                         ││ Card_Standard
│  │  위치 공유               ││
│  │  ──────────── [ON ◉]    ││ CupertinoSwitch
│  │                         ││
│  │  현재 상태: 공유 중 ●     ││ bodySmall, semanticSuccess
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ 📅 공유 스케줄            >││ ListTile → E-02
│  │    월~금 09:00-18:00     ││ bodySmall, onSurfaceVariant
│  ├─────────────────────────┤│
│  │ 🔗 이벤트 연동 설정       >││ ListTile → E-03
│  │    3개 일정 연동 중       ││ bodySmall, onSurfaceVariant
│  ├─────────────────────────┤│
│  │ 👁️ 가시범위 설정          >││ ListTile → E-04
│  │    전체 멤버              ││ bodySmall, onSurfaceVariant
│  ├─────────────────────────┤│
│  │ ⏸️ 가디언 접근 일시정지    >││ ListTile → E-05
│  │    사용 가능 (최대 12h)   ││ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │
│  ⓘ 강제 모드에서는 위치 공유를 │ bodySmall, onSurfaceVariant
│    끌 수 없습니다. 캡틴에게    │ (강제 모드 시에만 표시)
│    문의하세요.               │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 모달 컨테이너 | `showModalBottomSheet` | style: Modal_Bottom, radius20, 동적 높이 |
| 핸들 바 | `Container` | width: 44, height: 4, color: line04, 중앙 정렬 |
| 제목 | `Text` | style: titleLarge (20sp, SemiBold), color: onSurface |
| 프라이버시 등급 표시 | `Row` | leading: 등급 아이콘 (🛡️/📍/🔒), text: 등급명, color: 등급별 HEX |
| 공유 모드 표시 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, text: "강제 모드" / "자유 모드" |
| 상태 카드 | `Card` | style: Card_Standard, radius16, padding: spacing16 |
| 위치 공유 토글 | `CupertinoSwitch` | activeColor: primaryTeal (#00A2BD), value: sharingEnabled |
| 현재 상태 텍스트 | `Text` | style: bodySmall (12sp), color: semanticSuccess (공유 중) / semanticError (공유 중지) |
| 상태 인디케이터 | `Container` (원형) | width: 8, height: 8, color: semanticSuccess / semanticError |
| 메뉴 목록 | `ListView` | children: ListTile x 4, separator: Divider (outlineVariant) |
| 스케줄 메뉴 | `ListTile` | leading: 📅, title: "공유 스케줄", subtitle: 스케줄 요약, trailing: chevron_right |
| 이벤트 메뉴 | `ListTile` | leading: 🔗, title: "이벤트 연동 설정", subtitle: 연동 일정 수, trailing: chevron_right |
| 가시범위 메뉴 | `ListTile` | leading: 👁️, title: "가시범위 설정", subtitle: 현재 범위, trailing: chevron_right |
| 가디언 일시정지 메뉴 | `ListTile` | leading: ⏸️, title: "가디언 접근 일시정지", subtitle: 가용 상태, trailing: chevron_right |
| 강제 모드 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, 앞에 ⓘ 아이콘 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 자유 모드 + 공유 ON | 토글 ON (primaryTeal), 상태 "공유 중" (녹색 점), 모든 메뉴 활성 |
| 자유 모드 + 공유 OFF | 토글 OFF (gray), 상태 "공유 중지" (빨간 점), 스케줄/이벤트 메뉴 비활성 (opacity 0.4) |
| 강제 모드 + 공유 ON | 토글 ON 고정 (disabled, opacity 0.6), 강제 모드 안내 텍스트 표시, 가시범위 메뉴 비활성 |
| 강제 모드 (안전최우선) | 토글 ON 고정, 가디언 일시정지 메뉴 비활성, subtitle: "안전최우선에서 사용 불가" |
| 강제 모드 (표준) | 토글 ON 고정, 가디언 일시정지 메뉴 활성, subtitle: "최대 12시간" |
| 프라이버시우선 등급 | 토글 활성 (자유 모드 시), 가디언 일시정지 subtitle: "최대 24시간" |
| 가디언 일시정지 중 | 일시정지 메뉴 subtitle: "일시정지 중 -- Nh Nm 남음" (primaryCoral) |
| 여행 미시작 (planning) | 토글 비활성 (위치 공유 불가), 안내 텍스트 "여행 시작 후 이용 가능합니다" |

**인터랙션**

- [탭] 위치 공유 토글 → 자유 모드: ON/OFF 즉시 전환 + PATCH /api/v1/trips/:tripId/location-sharing
- [탭] 위치 공유 토글 (강제 모드) → 토글 비활성 상태, 탭 시 Toast "강제 모드에서는 위치 공유를 끌 수 없습니다"
- [탭] 공유 스케줄 → Navigator.push → E-02 공유 스케줄 설정
- [탭] 이벤트 연동 설정 → Navigator.push → E-03 이벤트 연동 설정
- [탭] 가시범위 설정 → Navigator.push → E-04 가시범위 설정 (강제 모드 시 비활성)
- [탭] 가디언 접근 일시정지 → Navigator.push → E-05 가디언 접근 일시정지
- [하단 스와이프] 모달 → 모달 닫기 (300ms 슬라이드 아웃)

---

### E-02 공유 스케줄 설정 (Sharing Schedule)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | E-02 |
| 화면명 | 공유 스케줄 설정 (Sharing Schedule) |
| Phase | P1 |
| 역할 | 크루 (자유 모드 시 본인), 캡틴 (강제 모드 시 전체 적용) |
| 진입 경로 | E-01 위치공유 설정 모달 (스케줄 설정 메뉴) → E-02 |
| 이탈 경로 | E-02 → E-01 (저장/뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 공유 스케줄 설정    [저장]│ AppBar_Standard
├─────────────────────────────┤
│                             │
│  위치가 공유되는 시간을       │ bodyMedium (14sp)
│  설정합니다                  │ onSurfaceVariant
│                             │
│  ┌── 요일별 스케줄 ─────────┐│
│  │                         ││
│  │  월 [◉ ON ]  09:00 ─ 18:00 │ │ Row: 요일 + Switch + RangeSlider
│  │  ▔▔▔▔▔▔▔▔▔▔▔███████▔▔▔  ││ 24h 타임라인 바
│  │                         ││
│  │  화 [◉ ON ]  09:00 ─ 18:00 │ │
│  │  ▔▔▔▔▔▔▔▔▔▔▔███████▔▔▔  ││
│  │                         ││
│  │  수 [◉ ON ]  09:00 ─ 18:00 │ │
│  │  ▔▔▔▔▔▔▔▔▔▔▔███████▔▔▔  ││
│  │                         ││
│  │  목 [◉ ON ]  09:00 ─ 18:00 │ │
│  │  ▔▔▔▔▔▔▔▔▔▔▔███████▔▔▔  ││
│  │                         ││
│  │  금 [◉ ON ]  09:00 ─ 18:00 │ │
│  │  ▔▔▔▔▔▔▔▔▔▔▔███████▔▔▔  ││
│  │                         ││
│  │  토 [  OFF]  ── : ── ── : ──│ │ OFF 시 슬라이더 비활성
│  │  ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔  ││
│  │                         ││
│  │  일 [  OFF]  ── : ── ── : ──│ │
│  │  ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔  ││
│  └─────────────────────────┘│
│                             │ spacing24
│  ┌── 특정 일자 오버라이드 ──┐ │
│  │                         ││
│  │  특정 날짜에 다른 스케줄을 ││ bodySmall, onSurfaceVariant
│  │  적용합니다               ││
│  │                         ││
│  │  + 특정 일자 추가         ││ TextButton, primaryTeal
│  │                         ││
│  │  ┌─────────────────────┐││
│  │  │ 03/05 (수) 종일 공유  │✕│ │ Chip_Tag + 삭제 버튼
│  │  └─────────────────────┘││
│  │  ┌─────────────────────┐││
│  │  │ 03/08 (토) 10:00-14:00│✕│ │
│  │  └─────────────────────┘││
│  └─────────────────────────┘│
│                             │
│  ┌── 비주얼 타임라인 ───────┐│
│  │  오늘 (월요일)            ││ bodySmall, primaryTeal
│  │  ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░  ││ 24h 바: 활성(teal) / 비활성(gray)
│  │  0  3  6  9  12 15 18 21 ││ 시간 라벨
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "공유 스케줄 설정", leading: BackButton, actions: [저장 TextButton], style: AppBar_Standard |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 요일 라벨 | `Text` | style: bodyLarge (16sp, SemiBold), width: 28dp |
| 요일별 토글 | `CupertinoSwitch` | activeColor: primaryTeal, size: compact |
| 시간 범위 슬라이더 | `RangeSlider` | min: 0, max: 24, divisions: 96 (15분 단위), activeColor: primaryTeal, inactiveColor: outline |
| 시간 라벨 | `Text` | style: bodySmall (12sp), color: onSurface, format: "HH:mm" |
| 24h 타임라인 바 | `CustomPaint` | height: 8dp, activeColor: primaryTeal (20% opacity fill), inactiveColor: outlineVariant |
| 특정 일자 섹션 | `Column` | padding: spacing16, separator: Divider |
| 특정 일자 추가 버튼 | `TextButton` | icon: Icons.add, text: "특정 일자 추가", color: primaryTeal |
| 특정 일자 칩 | `Chip` | style: Chip_Tag, deleteIcon: Icons.close, onDeleted: 삭제 |
| 비주얼 타임라인 | `CustomPaint` | height: 24dp, 24h 시간축 + 활성 구간 하이라이트 |
| 저장 버튼 | `TextButton` | style: labelLarge, color: primaryTeal, text: "저장" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 저장된 스케줄 로드. 변경 없으면 저장 버튼 비활성 (opacity 0.4) |
| 요일 ON 전환 | 해당 요일 슬라이더 활성, 기본 시간 09:00-18:00 적용, 타임라인 바 업데이트 |
| 요일 OFF 전환 | 해당 요일 슬라이더 비활성 (gray), 시간 라벨 "──:── ──:──" |
| 슬라이더 드래그 | 시간 라벨 실시간 업데이트, 타임라인 바 활성 구간 실시간 변경 |
| 특정 일자 추가 탭 | DatePicker 표시 → 날짜 선택 → 시간 범위 선택 다이얼로그 (종일 / 시간 지정) |
| 특정 일자 삭제 | 해당 칩 제거, 비주얼 타임라인 업데이트 |
| 변경사항 있음 | 저장 버튼 활성 (primaryTeal) |
| 저장 중 | 저장 버튼 → ProgressIndicator |
| 저장 성공 | Toast "스케줄이 저장되었습니다" → Navigator.pop → E-01 |
| 저장 실패 | Toast "저장에 실패했습니다. 다시 시도해주세요." |
| 강제 모드 (캡틴 접근) | 상단 안내 배너: "이 스케줄은 전체 멤버에게 적용됩니다" (Card_Alert, warning) |

**인터랙션**

- [탭] 요일별 토글 → ON/OFF 전환, 슬라이더 활성/비활성
- [드래그] RangeSlider → 시작/종료 시간 조절 (15분 단위 snap)
- [탭] 특정 일자 추가 → showDatePicker → showTimePicker (시작/종료) → 칩 추가
- [탭] 특정 일자 칩 X → Dialog_Confirm "이 날짜를 삭제할까요?" → 삭제
- [탭] 저장 → PUT /api/v1/trips/:tripId/location-schedule → 성공 시 E-01 복귀
- [뒤로가기] 변경사항 있으면 → Dialog_Confirm "변경사항을 저장하지 않고 나가시겠습니까?" (확인 → pop / 취소 → 유지)

---

### E-03 이벤트 연동 설정 (Event-Linked Sharing)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | E-03 |
| 화면명 | 이벤트 연동 설정 (Event-Linked Sharing) |
| Phase | P1 |
| 역할 | 크루 (자유 모드 시), 캡틴 (강제 모드 시) |
| 진입 경로 | E-01 위치공유 설정 모달 (이벤트 연동 메뉴) → E-03 |
| 이탈 경로 | E-03 → E-01 (저장/뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 이벤트 연동 설정    [저장]│ AppBar_Standard
├─────────────────────────────┤
│                             │
│  일정에 맞춰 위치 공유가      │ bodyMedium (14sp)
│  자동으로 활성화됩니다        │ onSurfaceVariant
│                             │
│  ┌── 버퍼 시간 ────────────┐│
│  │                         ││
│  │  일정 시작 전 미리 공유를  ││ bodySmall, onSurfaceVariant
│  │  시작합니다               ││
│  │                         ││
│  │  ○ 0분 (일정 시작과 동시) ││ Radio, bodyMedium
│  │  ● 15분 전부터            ││ Radio (selected), bodyMedium
│  │  ○ 30분 전부터            ││ Radio, bodyMedium
│  │                         ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 수동 활성화 ───────────┐│
│  │                         ││
│  │  수동 활성화          [◉] ││ CupertinoSwitch
│  │                         ││
│  │  일정이 없는 시간에도 위치 ││ bodySmall, onSurfaceVariant
│  │  공유를 수동으로 켤 수     ││
│  │  있습니다 (자유 모드만)    ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 연동된 일정 목록 ──────┐│
│  │                         ││
│  │  오늘의 일정              ││ bodyMedium, SemiBold
│  │                         ││
│  │  ┌─────────────────────┐││
│  │  │ 09:00  호텔 조식     [◉]│ │ ListTile_Schedule + Switch
│  │  │        호텔 레스토랑   ││ │ 개별 연동 ON/OFF
│  │  ├─────────────────────┤││
│  │  │ 11:00  시내 관광     [◉]│ │
│  │  │        명동           ││ │
│  │  ├─────────────────────┤││
│  │  │ 18:00  저녁 식사     [ ]│ │ OFF 상태
│  │  │        레스토랑       ││ │
│  │  └─────────────────────┘││
│  │                         ││
│  │  내일의 일정              ││ bodyMedium, SemiBold
│  │  ┌─────────────────────┐││
│  │  │ 10:00  자유 활동     [◉]│ │
│  │  │        해운대          ││ │
│  │  └─────────────────────┘││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "이벤트 연동 설정", leading: BackButton, actions: [저장], style: AppBar_Standard |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 버퍼 시간 섹션 | `Card` | style: Card_Standard, padding: spacing16 |
| 버퍼 시간 라디오 | `RadioListTile` x 3 | activeColor: primaryTeal, values: [0, 15, 30], groupValue: selectedBuffer |
| 수동 활성화 섹션 | `Card` | style: Card_Standard, padding: spacing16 |
| 수동 활성화 토글 | `CupertinoSwitch` | activeColor: primaryTeal |
| 수동 활성화 설명 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 일정 날짜 헤더 | `Text` | style: bodyMedium (14sp, SemiBold), color: onSurface |
| 일정 아이템 | `ListTile` | style: ListTile_Schedule 변형, trailing: CupertinoSwitch (개별 연동 토글) |
| 일정 시간 | `Text` | style: bodySmall (12sp), color: primaryTeal |
| 일정 제목 | `Text` | style: bodyLarge (16sp), color: onSurface |
| 일정 장소 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 저장된 버퍼 시간 + 연동 상태 로드, 변경 없으면 저장 버튼 비활성 |
| 버퍼 시간 변경 | 선택 라디오 primaryTeal 하이라이트 |
| 수동 활성화 ON | 토글 primaryTeal, 설명 텍스트 "자유 모드에서 수동 공유 가능" |
| 수동 활성화 OFF | 토글 gray, "일정에 따라서만 위치가 공유됩니다" |
| 강제 모드 접근 시 | 수동 활성화 섹션 비활성 (opacity 0.4), 안내: "강제 모드에서는 수동 활성화를 사용할 수 없습니다" |
| 일정 없음 | 빈 상태: "연동할 일정이 없습니다. 일정탭에서 일정을 추가해주세요." + 일정 추가 버튼 |
| 개별 일정 OFF | 해당 일정 연동 해제, 시간 텍스트 onSurfaceVariant (비강조) |
| 변경사항 있음 | 저장 버튼 활성 (primaryTeal) |
| 저장 성공 | Toast "이벤트 연동이 저장되었습니다" → Navigator.pop |
| 저장 실패 | Toast "저장에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 버퍼 시간 라디오 → 선택 변경 (0분 / 15분 / 30분)
- [탭] 수동 활성화 토글 → ON/OFF 전환
- [탭] 개별 일정 토글 → 해당 일정 연동 ON/OFF
- [탭] 저장 → PUT /api/v1/trips/:tripId/event-sharing-settings → 성공 시 E-01 복귀
- [뒤로가기] 변경 시 → Dialog_Confirm "변경사항을 저장하지 않고 나가시겠습니까?"

---

### E-04 가시범위 설정 (Visibility Range)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | E-04 |
| 화면명 | 가시범위 설정 (Visibility Range) |
| Phase | P1 |
| 역할 | 크루 (자유 모드 전용) |
| 진입 경로 | E-01 위치공유 설정 모달 (가시범위 메뉴) → E-04 |
| 이탈 경로 | E-04 → E-01 (저장/뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 가시범위 설정       [저장]│ AppBar_Standard
├─────────────────────────────┤
│                             │
│  내 위치를 볼 수 있는         │ bodyMedium (14sp)
│  멤버를 설정합니다            │ onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │                         ││
│  │  ● 전체 멤버             ││ RadioListTile (selected)
│  │    그룹 내 모든 멤버가    ││ bodySmall, onSurfaceVariant
│  │    내 위치를 볼 수 있습니다││
│  │                         ││
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  ○ 관리자만              ││ RadioListTile
│  │    캡틴과 크루장만 내      ││ bodySmall, onSurfaceVariant
│  │    위치를 볼 수 있습니다   ││
│  │                         ││
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  ○ 지정 멤버             ││ RadioListTile
│  │    선택한 멤버만 내       ││ bodySmall, onSurfaceVariant
│  │    위치를 볼 수 있습니다   ││
│  │                         ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 멤버 선택 (지정 시) ───┐│ AnimatedContainer
│  │                         ││ (지정 멤버 선택 시에만 표시)
│  │  ☑ 김캡틴 (캡틴)         ││ CheckboxListTile + Badge_Role
│  │  ☑ 이크루장 (크루장)      ││
│  │  ☐ 박크루 (크루)          ││
│  │  ☐ 최크루 (크루)          ││
│  │  ☑ 정크루 (크루)          ││
│  │                         ││
│  │  선택된 멤버: 3명         ││ bodySmall, primaryTeal
│  └─────────────────────────┘│
│                             │
│  ⓘ 가디언은 별도의 접근      │ bodySmall, onSurfaceVariant
│    설정으로 관리됩니다        │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "가시범위 설정", leading: BackButton, actions: [저장], style: AppBar_Standard |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 가시범위 라디오 그룹 | `Card` + `RadioListTile` x 3 | style: Card_Standard, activeColor: primaryTeal |
| 라디오 제목 | `Text` | style: bodyLarge (16sp), color: onSurface |
| 라디오 설명 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 멤버 선택 컨테이너 | `AnimatedContainer` | duration: 300ms, curve: easeInOut, 지정 멤버 선택 시 확장 |
| 멤버 체크박스 | `CheckboxListTile` | activeColor: primaryTeal, secondary: CircleAvatar (40dp), trailing: Badge_Role |
| 멤버 아바타 | `CircleAvatar` | radius: 20, backgroundColor: secondaryBeige |
| 선택 카운트 | `Text` | style: bodySmall (12sp), color: primaryTeal |
| 가디언 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, prefix: ⓘ |
| 저장 버튼 | `TextButton` | style: labelLarge, color: primaryTeal |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (전체 멤버) | "전체 멤버" 라디오 선택, 멤버 선택 영역 숨김, 저장 버튼 비활성 |
| 관리자만 선택 | "관리자만" 라디오 선택, 멤버 선택 영역 숨김 |
| 지정 멤버 선택 | "지정 멤버" 라디오 선택, 멤버 선택 영역 슬라이드 다운 표시 (300ms) |
| 멤버 체크 변경 | 선택 카운트 실시간 업데이트, 저장 버튼 활성 |
| 지정 멤버 0명 | 저장 버튼 비활성, 안내 "최소 1명을 선택해주세요" (semanticError) |
| 강제 모드 접근 | 전체 화면 비활성, 안내: "강제 모드에서는 가시범위를 변경할 수 없습니다" → 뒤로가기만 활성 |
| 변경사항 있음 | 저장 버튼 활성 (primaryTeal) |
| 저장 성공 | Toast "가시범위가 저장되었습니다" → Navigator.pop |
| 저장 실패 | Toast "저장에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 라디오 항목 → 가시범위 변경 (전체 / 관리자만 / 지정 멤버)
- [탭] 멤버 체크박스 → 개별 멤버 선택/해제
- [탭] 저장 → PUT /api/v1/trips/:tripId/visibility-range → 성공 시 E-01 복귀
- [뒤로가기] 변경 시 → Dialog_Confirm "변경사항을 저장하지 않고 나가시겠습니까?"

---

### E-05 가디언 접근 일시정지 (Guardian Pause)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | E-05 |
| 화면명 | 가디언 접근 일시정지 (Guardian Pause) |
| Phase | P1 |
| 역할 | 크루 (캡틴, 크루장, 크루) |
| 진입 경로 | E-01 위치공유 설정 모달 (가디언 일시정지 메뉴) → E-05 |
| 이탈 경로 | E-05 → E-01 (활성화/뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 가디언 접근 일시정지      │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  가디언의 위치 접근을          │ bodyMedium (14sp)
│  일시적으로 중지합니다         │ onSurfaceVariant
│                             │
│  ┌── 프라이버시 등급 안내 ──┐ │
│  │ 📍 현재 등급: 표준        │ │ Badge, 등급 색상
│  │    최대 일시정지: 12시간   │ │ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 일시정지 시간 설정 ────┐│
│  │                         ││
│  │          6h              ││ headlineMedium (24sp, SemiBold)
│  │                         ││ primaryTeal
│  │  ▔▔▔▔▔▔▔▔▔▔▔████▔▔▔▔  ││
│  │  1h   3h   6h   12h     ││ Slider + 라벨
│  │                         ││
│  │  만료 시각: 오후 11:00    ││ bodyMedium, onSurface
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 사유 입력 (선택) ──────┐│
│  │                         ││
│  │  ┌─────────────────────┐││
│  │  │ 사유를 입력해주세요    │││ Input_Text (optional)
│  │  │ (선택 사항)           │││ maxLength: 100
│  │  └─────────────────────┘││
│  │                         ││
│  └─────────────────────────┘│
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │    일시정지 시작           ││ Button_Primary
│  └─────────────────────────┘│
│                             │
│  ⓘ 일시정지 중에는 가디언이   │ bodySmall, onSurfaceVariant
│    위치를 확인할 수 없습니다.  │
│    만료 30분 전 알림이        │
│    발송됩니다.                │
│                             │
└─────────────────────────────┘
```

**일시정지 활성 상태 레이아웃:**

```
┌─────────────────────────────┐
│ [←] 가디언 접근 일시정지      │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌── 카운트다운 ────────────┐│
│  │                         ││ Card_Standard
│  │    ⏸️ 일시정지 중         ││ titleMedium, primaryCoral
│  │                         ││
│  │       05:32:17           ││ displayLarge (36sp, Bold)
│  │                         ││ primaryCoral (#FF807B)
│  │   ○○○○○○○○○●●●●●●●●●   ││ LinearProgressIndicator
│  │                         ││ (남은 시간 비율)
│  │   만료: 오후 11:00        ││ bodySmall, onSurfaceVariant
│  │                         ││
│  │   사유: 개인 사정          ││ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │    일시정지 해제           ││ Button_Destructive
│  └─────────────────────────┘│
│                             │
│  ⓘ 해제 시 가디언에게         │ bodySmall, onSurfaceVariant
│    즉시 위치가 공유됩니다      │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "가디언 접근 일시정지", leading: BackButton, style: AppBar_Standard |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 등급 안내 카드 | `Card` | style: Card_Standard, padding: spacing12 |
| 등급 아이콘/라벨 | `Row` | icon: 등급 아이콘, text: 등급명, Badge 스타일, color: 등급별 HEX |
| 최대 시간 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 시간 설정 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 시간 표시 | `Text` | style: headlineMedium (24sp, SemiBold), color: primaryTeal |
| 시간 슬라이더 | `Slider` | min: 1, max: 등급별 최대 (12/24), divisions: 등급별 최대-1, activeColor: primaryTeal |
| 슬라이더 라벨 | `Row` | children: Text x 4 ("1h", "3h", "6h", "12h"/"24h"), style: bodySmall |
| 만료 시각 | `Text` | style: bodyMedium (14sp), color: onSurface |
| 사유 입력 | `TextFormField` | style: Input_Text, hintText: "사유를 입력해주세요 (선택 사항)", maxLength: 100 |
| 시작 버튼 | `ElevatedButton` | style: Button_Primary, text: "일시정지 시작" |
| 카운트다운 표시 | `Text` | style: displayLarge (36sp, Bold), color: primaryCoral (#FF807B), format: "HH:mm:ss" |
| 진행률 바 | `LinearProgressIndicator` | value: 남은시간/전체시간, color: primaryCoral, trackColor: outline |
| 해제 버튼 | `ElevatedButton` | style: Button_Destructive, text: "일시정지 해제" |
| 안내 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, prefix: ⓘ |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (비활성) | 시간 설정 UI 표시, 기본값 6h, 시작 버튼 활성 |
| 안전최우선 등급 | 전체 화면 비활성, Card_Alert (error): "안전최우선 등급에서는 가디언 접근을 일시정지할 수 없습니다" |
| 표준 등급 | 최대 슬라이더 12h, 라벨: "1h 3h 6h 12h" |
| 프라이버시우선 등급 | 최대 슬라이더 24h, 라벨: "1h 6h 12h 24h" |
| 슬라이더 드래그 | 시간 표시 실시간 업데이트, 만료 시각 계산 표시 |
| 일시정지 시작 | Dialog_Confirm "가디언에게 위치 공유를 Nh 동안 중지합니다. 계속할까요?" |
| 일시정지 활성 | 카운트다운 레이아웃으로 전환, 실시간 타이머, 진행률 바 감소 |
| 만료 30분 전 | 카운트다운 색상 semanticWarning (#FFAC11) 전환, Push 알림 발송 |
| 만료 | Toast "가디언 접근 일시정지가 종료되었습니다" → 비활성 레이아웃 복귀 |
| 해제 탭 | Dialog_Confirm "일시정지를 해제하면 가디언에게 즉시 위치가 공유됩니다" → 확인 시 해제 |

**인터랙션**

- [드래그] 시간 슬라이더 → 일시정지 시간 조절 (1h 단위)
- [입력] 사유 필드 → 선택적 사유 입력
- [탭] 일시정지 시작 → Dialog_Confirm → POST /api/v1/trips/:tripId/guardian-pause → 카운트다운 시작
- [탭] 일시정지 해제 → Dialog_Confirm → DELETE /api/v1/trips/:tripId/guardian-pause → 비활성 상태 복귀
- [뒤로가기] → Navigator.pop → E-01

---

### E-06 프라이버시 등급 변경 확인 (Privacy Level Change)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | E-06 |
| 화면명 | 프라이버시 등급 변경 확인 (Privacy Level Change) |
| Phase | P1 |
| 역할 | 캡틴 전용 |
| 진입 경로 | D-04 여행 설정 (프라이버시 등급 변경 메뉴) → E-06 |
| 이탈 경로 | E-06 → D-04 (변경 완료/취소) |

**레이아웃**

```
┌─────────────────────────────┐
│                             │
│  ┌─────────────────────────┐│ Dialog_Confirm (확장형)
│  │                         ││ radius16, width: 320dp
│  │  프라이버시 등급 변경      ││ titleMedium (18sp, SemiBold)
│  │                         ││
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  ┌──── 변경 전 ────────┐││
│  │  │ 🛡️ 안전최우선         │││ Badge, #DA4C51
│  │  │ • 위치 항상 공유      │││ bodySmall, onSurfaceVariant
│  │  │ • 가디언 항상 접근     │││
│  │  │ • 일시정지 불가        │││
│  │  └─────────────────────┘││
│  │           ↓              ││ Icon: arrow_downward
│  │  ┌──── 변경 후 ────────┐││
│  │  │ 📍 표준              │││ Badge, #00A2BD
│  │  │ • OFF 시 30분 스냅샷  │││ bodySmall, onSurfaceVariant
│  │  │ • 가디언 실시간 접근   │││
│  │  │ • 일시정지 최대 12h   │││
│  │  └─────────────────────┘││
│  │                         ││
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  변경 영향               ││ bodyMedium, SemiBold
│  │                         ││
│  │  • 전체 멤버 (5명)의      ││ bodySmall, onSurfaceVariant
│  │    위치 공유 정책이        ││
│  │    변경됩니다              ││
│  │  • 연결된 가디언 (3명)에게 ││
│  │    알림이 발송됩니다       ││
│  │  • 멤버의 가디언 일시정지  ││
│  │    기능이 활성화됩니다     ││
│  │                         ││
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  ☑ 멤버 전체에게 알림     ││ CheckboxListTile
│  │  ☑ 가디언에게 알림        ││ CheckboxListTile
│  │                         ││
│  │  ┌──────┐  ┌──────────┐││
│  │  │ 취소  │  │  변경하기  │││ Button_Secondary + Button_Primary
│  │  └──────┘  └──────────┘││
│  │                         ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 다이얼로그 | `AlertDialog` (확장형) | style: Dialog_Confirm, radius16, width: 320dp, maxHeight: 화면 80% |
| 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 변경 전 카드 | `Container` | padding: spacing12, radius8, backgroundColor: 등급 HEX (10% opacity) |
| 변경 전 아이콘/라벨 | `Row` | icon: 등급 아이콘, text: 등급명, color: 등급 HEX |
| 변경 전 항목 | `Text` (bullet list) | style: bodySmall (12sp), color: onSurfaceVariant |
| 화살표 아이콘 | `Icon` | icon: Icons.arrow_downward, color: onSurfaceVariant, size: 24dp |
| 변경 후 카드 | `Container` | padding: spacing12, radius8, backgroundColor: 등급 HEX (10% opacity), border: 등급 HEX (1px) |
| 변경 후 아이콘/라벨 | `Row` | icon: 등급 아이콘, text: 등급명, color: 등급 HEX |
| 변경 후 항목 | `Text` (bullet list) | style: bodySmall (12sp), color: onSurfaceVariant |
| 영향 제목 | `Text` | style: bodyMedium (14sp, SemiBold), color: onSurface |
| 영향 항목 | `Text` (bullet list) | style: bodySmall (12sp), color: onSurfaceVariant |
| 알림 체크 (멤버) | `CheckboxListTile` | activeColor: primaryTeal, value: true (기본 체크), title: "멤버 전체에게 알림" |
| 알림 체크 (가디언) | `CheckboxListTile` | activeColor: primaryTeal, value: true (기본 체크), title: "가디언에게 알림" |
| 취소 버튼 | `OutlinedButton` | style: Button_Secondary, text: "취소", flex: 1 |
| 변경 버튼 | `ElevatedButton` | style: Button_Primary, text: "변경하기", flex: 2 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 변경 전/후 등급 비교 표시, 알림 체크박스 기본 체크, 변경 버튼 활성 |
| 안전최우선 → 표준 | 변경 후 카드: 📍 표준 + "OFF 시 30분 스냅샷", "가디언 일시정지 최대 12h 활성화" 강조 |
| 안전최우선 → 프라이버시우선 | 변경 후 카드: 🔒 프라이버시우선 + "OFF 시 마커 제거", "가디언 승인 후 1회 접근" 강조 |
| 표준 → 안전최우선 | 변경 후 카드: 🛡️ 안전최우선 + "위치 항상 공유", "가디언 일시정지 기능 비활성화" 경고 |
| 표준 → 프라이버시우선 | 변경 후 카드: 🔒 프라이버시우선 + "OFF 시 마커 제거" |
| 프라이버시우선 → 안전최우선 | 변경 후 카드: 🛡️ 안전최우선 + "활성 일시정지 강제 해제됨" 경고 (semanticWarning) |
| 프라이버시우선 → 표준 | 변경 후 카드: 📍 표준 + "OFF 시 30분 스냅샷 적용" |
| 변경 중 | 변경 버튼 → CircularProgressIndicator |
| 변경 성공 | Toast "프라이버시 등급이 변경되었습니다" → dismiss dialog → D-04 복귀 |
| 변경 실패 | Toast "변경에 실패했습니다. 다시 시도해주세요." |
| 알림 체크 해제 | 해당 대상 알림 미발송 (최소 1개는 체크 필수) |

**인터랙션**

- [탭] 알림 체크박스 → 개별 토글 (최소 1개 필수, 둘 다 해제 시 Toast "최소 1개 대상에게 알림을 보내야 합니다")
- [탭] 변경하기 → PATCH /api/v1/trips/:tripId/privacy-level → 성공 시 다이얼로그 닫기 + 알림 발송
- [탭] 취소 → 다이얼로그 닫기 (변경 없음)
- [외부 탭 / 뒤로가기] → 다이얼로그 닫기 (변경 없음)

---

### E-07 공유모드 전환 확인 (Mode Switch Confirm)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | E-07 |
| 화면명 | 공유모드 전환 확인 (Mode Switch Confirm) |
| Phase | P1 |
| 역할 | 캡틴 전용 |
| 진입 경로 | D-04 여행 설정 (공유 모드 변경 메뉴) → E-07 |
| 이탈 경로 | E-07 → D-04 (전환 완료/취소) |

**레이아웃**

```
┌─────────────────────────────┐
│                             │
│  ┌─────────────────────────┐│ Dialog_Confirm (확장형)
│  │                         ││ radius16, width: 320dp
│  │  ⚠️ 공유 모드 전환        ││ titleMedium (18sp, SemiBold)
│  │                         ││ semanticWarning icon
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  ┌──── 현재 ───────────┐││
│  │  │ 🔒 강제 모드          │││ Badge
│  │  │ • 모든 멤버 위치 항상  │││ bodySmall
│  │  │   공유                │││
│  │  │ • 스케줄/가시범위      │││
│  │  │   캡틴 관리            │││
│  │  │ • 개별 OFF 불가        │││
│  │  └─────────────────────┘││
│  │           ↓              ││
│  │  ┌──── 변경 후 ────────┐││
│  │  │ 🔓 자유 모드          │││ Badge
│  │  │ • 멤버가 공유 ON/OFF  │││ bodySmall
│  │  │   자유 선택            │││
│  │  │ • 스케줄/가시범위      │││
│  │  │   멤버 개별 설정       │││
│  │  │ • 수동 활성화 가능     │││
│  │  └─────────────────────┘││
│  │                         ││
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  ⚠️ 주의사항              ││ bodyMedium, SemiBold
│  │                         ││ semanticWarning
│  │  • 전체 멤버 (5명)에게    ││ bodySmall
│  │    알림이 발송됩니다       ││
│  │  • 멤버들이 위치 공유를   ││
│  │    끌 수 있게 됩니다      ││
│  │  • 기존 스케줄 설정이     ││
│  │    초기화됩니다            ││
│  │                         ││
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  ☑ 전 멤버에게 알림 발송  ││ CheckboxListTile (필수)
│  │                         ││
│  │  ┌──────┐  ┌──────────┐││
│  │  │ 취소  │  │  전환하기  │││ Button_Secondary + Button_Primary
│  │  └──────┘  └──────────┘││
│  │                         ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 다이얼로그 | `AlertDialog` (확장형) | style: Dialog_Confirm, radius16, width: 320dp |
| 경고 아이콘 | `Icon` | icon: Icons.warning_amber_rounded, color: semanticWarning (#FFAC11), size: 24dp |
| 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 현재 모드 카드 | `Container` | padding: spacing12, radius8, backgroundColor: surfaceVariant |
| 현재 모드 아이콘 | `Icon` | icon: 🔒 (강제) / 🔓 (자유), size: 20dp |
| 모드 라벨 | `Text` | style: bodyMedium (14sp, SemiBold) |
| 모드 특성 | `Text` (bullet list) | style: bodySmall (12sp), color: onSurfaceVariant |
| 변경 후 모드 카드 | `Container` | padding: spacing12, radius8, backgroundColor: primaryTeal (5% opacity), border: primaryTeal (1px) |
| 화살표 아이콘 | `Icon` | icon: Icons.arrow_downward, color: onSurfaceVariant |
| 주의사항 제목 | `Row` | icon: warning (semanticWarning), text: "주의사항" (bodyMedium, SemiBold) |
| 주의사항 항목 | `Text` (bullet list) | style: bodySmall (12sp), color: onSurfaceVariant |
| 알림 체크 | `CheckboxListTile` | activeColor: primaryTeal, value: true (기본 체크, 필수), enabled: false (해제 불가) |
| 취소 버튼 | `OutlinedButton` | style: Button_Secondary, text: "취소", flex: 1 |
| 전환 버튼 | `ElevatedButton` | style: Button_Primary, text: "전환하기", flex: 2 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 강제 → 자유 전환 | 현재: 🔒 강제 모드 특성 나열, 변경 후: 🔓 자유 모드 특성 나열, 주의: "멤버들이 위치 공유를 끌 수 있게 됩니다" |
| 자유 → 강제 전환 | 현재: 🔓 자유 모드, 변경 후: 🔒 강제 모드, 주의: "모든 멤버의 위치 공유가 강제 ON됩니다", "개별 스케줄/가시범위 설정이 초기화됩니다" |
| 전환 중 | 전환 버튼 → CircularProgressIndicator |
| 전환 성공 | Toast "공유 모드가 전환되었습니다. 전체 멤버에게 알림을 발송했습니다." → dismiss → D-04 복귀 |
| 전환 실패 | Toast "전환에 실패했습니다. 다시 시도해주세요." |
| 안전최우선 + 자유 → 강제 | 추가 주의: "안전최우선 등급에서 강제 모드 전환 시 모든 멤버의 위치가 항상 공유됩니다" (semanticError 색상) |

**인터랙션**

- [탭] 전환하기 → PATCH /api/v1/trips/:tripId/sharing-mode → 성공 시 다이얼로그 닫기 + 전 멤버 Push 알림
- [탭] 취소 → 다이얼로그 닫기 (변경 없음)
- [외부 탭 / 뒤로가기] → 다이얼로그 닫기 (변경 없음)

---

### E-08 지오펜스 관리 (Geofence Manage)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | E-08 |
| 화면명 | 지오펜스 관리 (Geofence Manage) |
| Phase | P1 |
| 역할 | 캡틴, 크루장 |
| 진입 경로 | C-01 메인맵 (지오펜스 편집 버튼) → E-08 |
| 이탈 경로 | E-08 → C-01 메인맵 (완료/뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 지오펜스 관리     [+ 추가]│ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │                         ││
│  │     ┌────────────┐      ││
│  │     │   미니맵     │      ││ Google Maps (mini)
│  │     │  ◇ 폴리곤1  │      ││ 높이: 200dp
│  │     │    ○ 원형2   │      ││ 지오펜스 오버레이 표시
│  │     │             │      ││ 20% opacity fill + border
│  │     └────────────┘      ││
│  │                         ││
│  └─────────────────────────┘│
│                             │ spacing16
│  활성 지오펜스 (2)           │ bodyMedium, SemiBold
│                             │
│  ┌─────────────────────────┐│
│  │ 📍 호텔 안전 구역        ││ Card_Standard
│  │    반경: 500m | 원형     ││ bodySmall, onSurfaceVariant
│  │    알림 대상: 전체 멤버   ││
│  │    상태: [◉ 활성]        ││ CupertinoSwitch
│  │                  [편집]  ││ TextButton, primaryTeal
│  ├─────────────────────────┤│
│  │ 📍 관광지 구역           ││ Card_Standard
│  │    반경: 1km | 폴리곤    ││
│  │    알림 대상: 크루만      ││
│  │    상태: [◉ 활성]        ││
│  │                  [편집]  ││
│  └─────────────────────────┘│
│                             │ spacing16
│  비활성 지오펜스 (1)         │ bodyMedium, SemiBold
│                             │ onSurfaceVariant
│  ┌─────────────────────────┐│
│  │ 📍 이전 숙소             ││ Card_Standard (opacity 0.6)
│  │    반경: 300m | 원형     ││
│  │    상태: [  비활성]      ││ CupertinoSwitch (OFF)
│  │           [편집] [삭제]  ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**지오펜스 추가/편집 화면 (Modal_Bottom):**

```
┌─────────────────────────────┐
│         ─────               │ 핸들 바
│                             │
│  지오펜스 추가               │ titleLarge (20sp, SemiBold)
│                             │
│  ┌─ 이름 ──────────────────┐│
│  │ 지오펜스 이름을 입력하세요  ││ Input_Text
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 영역 유형 ────────────┐│
│  │  ● 원형 (반경)           ││ RadioListTile
│  │  ○ 폴리곤 (다각형)       ││ RadioListTile
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 반경 설정 (원형 시) ───┐│
│  │                         ││
│  │       500m               ││ headlineMedium, primaryTeal
│  │  ▔▔▔▔▔▔▔████▔▔▔▔▔▔▔▔  ││ Slider
│  │  100m        2km         ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 알림 대상 ────────────┐│
│  │  ● 전체 멤버             ││ RadioListTile
│  │  ○ 관리자만              ││ RadioListTile
│  │  ○ 지정 멤버             ││ RadioListTile
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌── 지도에서 위치 선택 ────┐│
│  │                         ││
│  │  [지도에서 중심점 선택]    ││ Button_Secondary
│  │                         ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │       저장               ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "지오펜스 관리", leading: BackButton, actions: [+ 추가 TextButton], style: AppBar_Standard |
| 미니맵 | `GoogleMap` | height: 200dp, radius16, 지오펜스 오버레이 표시, interactionEnabled: true (줌/팬 가능) |
| 지오펜스 오버레이 (원형) | `Circle` | fillColor: primaryTeal (20% opacity), strokeColor: primaryTeal, strokeWidth: 2 |
| 지오펜스 오버레이 (폴리곤) | `Polygon` | fillColor: primaryTeal (20% opacity), strokeColor: primaryTeal, strokeWidth: 2 |
| 섹션 제목 | `Text` | style: bodyMedium (14sp, SemiBold), color: onSurface |
| 지오펜스 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 지오펜스 이름 | `Text` | style: bodyLarge (16sp), color: onSurface, prefix: 📍 |
| 지오펜스 정보 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 활성 토글 | `CupertinoSwitch` | activeColor: primaryTeal |
| 편집 버튼 | `TextButton` | style: labelMedium, color: primaryTeal, text: "편집" |
| 삭제 버튼 | `TextButton` | style: labelMedium, color: semanticError, text: "삭제" |
| 추가 버튼 (앱바) | `TextButton` | icon: Icons.add, text: "추가", color: #FFFFFF |
| 추가 모달 | `showModalBottomSheet` | style: Modal_Bottom |
| 이름 입력 | `TextFormField` | style: Input_Text, hintText: "지오펜스 이름을 입력하세요", validator: 필수 |
| 영역 유형 라디오 | `RadioListTile` x 2 | activeColor: primaryTeal, values: ["circle", "polygon"] |
| 반경 슬라이더 | `Slider` | min: 100, max: 2000, divisions: 19, activeColor: primaryTeal, label: "${value}m" |
| 반경 표시 | `Text` | style: headlineMedium (24sp, SemiBold), color: primaryTeal |
| 알림 대상 라디오 | `RadioListTile` x 3 | activeColor: primaryTeal, values: ["all", "admins", "selected"] |
| 지도 선택 버튼 | `OutlinedButton` | style: Button_Secondary, text: "지도에서 중심점 선택", icon: Icons.map |
| 저장 버튼 | `ElevatedButton` | style: Button_Primary, text: "저장" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 저장된 지오펜스 목록 로드, 미니맵에 모든 활성 지오펜스 오버레이 표시 |
| 지오펜스 0개 | 빈 상태: "설정된 지오펜스가 없습니다. + 추가 버튼으로 새로운 지오펜스를 만들어보세요." + 큰 일러스트 |
| 지오펜스 활성 토글 | ON: 미니맵 오버레이 표시, OFF: 미니맵 오버레이 제거, 비활성 섹션 이동 |
| 추가 버튼 탭 | Modal_Bottom 추가 폼 표시, 기본 유형: 원형 |
| 원형 선택 | 반경 슬라이더 표시 (100m~2km) |
| 폴리곤 선택 | 반경 슬라이더 숨김, "지도에서 꼭짓점을 찍어 영역을 그리세요" 안내 + 지도 열기 버튼 |
| 폴리곤 그리기 모드 | 전체화면 지도, 탭으로 꼭짓점 추가 (최소 3개), 실시간 폴리곤 미리보기, 완료 버튼 |
| 지도 중심점 선택 | 전체화면 지도, 중앙 핀 마커 고정, 드래그로 위치 조절, 확인 버튼 |
| 알림 대상 "지정 멤버" | 멤버 체크리스트 추가 표시 (E-04와 유사) |
| 편집 탭 | Modal_Bottom 편집 폼 (기존 값 로드) |
| 삭제 탭 | Dialog_Confirm "이 지오펜스를 삭제할까요? 삭제 후 복구할 수 없습니다." |
| 저장 성공 | Toast "지오펜스가 저장되었습니다" → 모달 닫기 → 목록 새로고침 |
| 저장 실패 | Toast "저장에 실패했습니다. 다시 시도해주세요." |
| 삭제 성공 | Toast "지오펜스가 삭제되었습니다" → 목록 새로고침 |

**인터랙션**

- [탭] + 추가 → Modal_Bottom 지오펜스 추가 폼
- [탭] 활성 토글 → 지오펜스 활성/비활성 전환 + PATCH /api/v1/trips/:tripId/geofences/:id
- [탭] 편집 → Modal_Bottom 편집 폼 (기존 데이터 로드)
- [탭] 삭제 → Dialog_Confirm → DELETE /api/v1/trips/:tripId/geofences/:id
- [탭] 지도에서 중심점 선택 → Navigator.push → 전체화면 지도 (핀 드래그, 확인 버튼)
- [탭] 영역 유형 라디오 → 원형/폴리곤 전환
- [드래그] 반경 슬라이더 → 100m~2km (100m 단위)
- [탭] 저장 → POST /api/v1/trips/:tripId/geofences → 성공 시 모달 닫기
- [지도 탭] (폴리곤 모드) → 꼭짓점 추가, 최소 3개 후 완료 가능
- [핀치 줌/드래그] 미니맵 → 지오펜스 위치 확인
- [뒤로가기] → Navigator.pop → C-01 메인맵

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 8개 화면 (E-01 ~ E-08) 5-섹션 템플릿, 프라이버시 등급 매트릭스, 공유 모드 비교 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 비즈니스 원칙 &sect;04 위치공유: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 비즈니스 원칙 &sect;05 프라이버시: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 와이어프레임 설계 스펙: `docs/plans/2026-03-03-wireframe-design.md`
- DB 설계: `Master_docs/07_T2_DB_설계_및_관계_v3_4.md`
- 디자인 시스템: `docs/DESIGN.md`
