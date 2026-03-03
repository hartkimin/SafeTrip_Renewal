# J. 안전 가이드 & 여행 정보

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 안전가이드 탭 7개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 안전가이드 원칙 | `Master_docs/21_T3_안전가이드_원칙.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 7개 (J-01 ~ J-07)
- **Phase:** P0 6개, P1 1개 (J-07)
- **핵심 역할:** 전체 (캡틴/크루장/크루/가디언 모두 동등 접근)
- **연관 문서:** `Master_docs/21_T3_안전가이드_원칙.md`

> **설계 원칙:** 안전가이드는 SafeTrip 내 유일하게 모든 역할이 100% 동등하게 접근하는 탭이다.
> 역할, 프라이버시 등급, 여행 참여 여부와 무관하게 전체 기능이 활성화된다. (원칙 S5)

---

## MOFA 여행경보 디자인 토큰

| Level | 명칭 | 색상 | HEX | 용도 |
|:-----:|------|------|-----|------|
| 1 | 여행유의 | Blue | `#2196F3` | 일반 주의 단계 |
| 2 | 여행자제 | Amber | `#FFB800` | 자제 권고 단계 |
| 3 | 출국권고 | Orange | `#FF5722` | 철수 권고 단계 |
| 4 | 여행금지 | Red | `#D32F2F` | 금지 (적색) 단계 |

---

## User Journey Flow

```
C-01 메인맵 → 바텀시트 [안전가이드 📖] 탭 선택
     ↓
J-01 안전가이드 탭 (바텀시트 컨텐츠)
  ├── [개요 칩] ────→ J-02 국가 개요 (서브탭)
  ├── [안전경보 칩] ──→ J-03 안전 경보 (서브탭)
  ├── [입국정보 칩] ──→ J-04 입국/비자 정보 (서브탭)
  ├── [의료건강 칩] ──→ J-05 의료/건강 정보 (서브탭)
  ├── [긴급연락처 칩] ─→ J-06 긴급 연락처 (서브탭)
  └── [국가 변경 🌐] ─→ J-07 국가 변경 (P1)
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| C-01 | 바텀시트 안전가이드 탭 선택 | J-01 안전가이드 탭 | J |
| J-06 | 원터치 전화 버튼 탭 | 네이티브 전화 앱 | 외부 |
| J-05 | 병원 지도 보기 탭 | 외부 지도 앱 또는 지도 뷰 | 외부 |
| J-07 | 국가 선택 완료 | J-01 (선택 국가 반영) | J |
| G-02 | SOS 화면에서 긴급연락처 | J-06 긴급 연락처 | J |

---

## 화면 상세

---

### J-01 안전가이드 탭 (Safety Guide Tab)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | J-01 |
| 화면명 | 안전가이드 탭 (Safety Guide Tab) |
| Phase | P0 |
| 역할 | 전체 (캡틴/크루장/크루/가디언) |
| 진입 경로 | C-01 메인맵 → 바텀시트 [📖 안전가이드] 탭 선택 → J-01 |
| 이탈 경로 | J-01 → 다른 바텀시트 탭 (일정/멤버/채팅) / J-01 → J-07 (국가 변경) |

> **참고:** J-01은 독립 화면이 아닌, 바텀시트 내 탭 컨텐츠로 렌더링된다.
> J-02~J-06 서브탭은 J-01 내부 컨텐츠 영역에서 전환된다.

**레이아웃**

```
┌─────────────────────────────┐
│                             │  ← Layer 1: 지도 뷰 (배경)
│       (Google Maps)         │
│                             │
├──── BottomSheet_Snap ───────┤  ← Layer 2: 바텀시트
│          ─────              │  handle (4px x 44px)
│                             │
│ [📅일정] [👥멤버] [💬채팅] [📖가이드]│  NavBar_Crew (📖 active)
├─────────────────────────────┤
│                             │
│  🇯🇵 일본 (Japan)     [🌐 변경]│  Country header + 국가 변경 버튼
│                             │
│  ┌─────┐ ┌──────┐ ┌──────┐ │
│  │ 개요 │ │안전경보│ │입국정보│ │  Chip_Tag row (scrollable)
│  └─────┘ └──────┘ └──────┘ │
│  ┌──────┐ ┌───────┐        │
│  │의료건강│ │긴급연락처│        │
│  └──────┘ └───────┘        │
│                             │
│ ┌─────────────────────────┐ │
│ │  [선택된 서브탭 컨텐츠]    │ │  Content area
│ │                         │ │  (J-02 ~ J-06 렌더링 영역)
│ │  기본: J-02 국가 개요      │ │
│ │                         │ │
│ └─────────────────────────┘ │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 바텀시트 | `DraggableScrollableSheet` | style: BottomSheet_Snap, 기본 높이: peek (6%), 드래그 시 half/tall/expanded |
| 탭 바 | `BottomNavigationBar` | style: NavBar_Crew (크루) / NavBar_Guardian (가디언), 안전가이드 탭 active |
| 국기 아이콘 | `Text` (emoji) / `Image.asset` | 국가 ISO 코드 기반 플래그, size: 28dp |
| 국가명 | `Text` | style: titleLarge (20sp, SemiBold 600), color: onSurface |
| 국가명 (영문) | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 국가 변경 버튼 | `TextButton` + `Icon` | icon: Icons.language (🌐), style: labelMedium, color: primaryTeal, onPressed: → J-07 |
| 서브탭 칩 | `SingleChildScrollView` > `Row` < `Chip` x 5 > | style: Chip_Tag, scrollDirection: horizontal, spacing: 8px |
| 컨텐츠 영역 | `IndexedStack` / `AnimatedSwitcher` | 서브탭 전환 시 페이드 애니메이션 (200ms) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (active 여행 있음) | 여행 목적지 국가 자동 선택, 기본 서브탭 "개요" (J-02) 표시 |
| 초기 (가디언) | 연결된 멤버의 여행 목적지 자동 선택 |
| 초기 (여행 없음) | 자유 탐색 모드, "국가를 선택해주세요" 안내 + J-07 국가 변경으로 유도 |
| 서브탭 전환 | 칩 selected 스타일 (`secondaryAmber` 배경), 컨텐츠 영역 해당 서브탭으로 전환 |
| 오프라인 | 상단 황색 배너 "오프라인 -- 저장된 데이터를 표시합니다. 최종 갱신: N시간 전" |
| API 오류 | 상단 배너 "외교부 서버에 연결할 수 없습니다. 캐시 데이터를 표시합니다." |
| 국가 미지원 | "해당 국가의 정보는 현재 준비 중입니다." + 영사콜센터 번호 표시 |
| 바텀시트 드래그 | peek → half → tall → expanded 스냅 전환 |

**인터랙션**

- [탭] 바텀시트 탭 바 📖 → 안전가이드 탭 활성화, 이전 탭 높이/스크롤 유지
- [탭] 서브탭 칩 (개요/안전경보/입국정보/의료건강/긴급연락처) → 컨텐츠 영역 해당 서브탭 전환
- [탭] 국가 변경 버튼 (🌐) → Navigator.push → J-07 국가 변경
- [드래그] 바텀시트 핸들 → 스냅 포인트 간 전환 (peek/collapsed/half/tall/expanded)
- [스크롤] 컨텐츠 영역 → 서브탭 내부 스크롤 (바텀시트 높이 유지)

---

### J-02 국가 개요 (Country Overview)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | J-02 |
| 화면명 | 국가 개요 (Country Overview) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | J-01 서브탭 "개요" 칩 선택 → J-02 (기본 서브탭) |
| 이탈 경로 | J-02 → 다른 서브탭 (J-03~J-06) / 빠른 링크 → J-06 긴급연락처 |

> **참고:** J-02는 J-01 내부의 서브탭 컨텐츠이며, 독립 화면이 아니다.

**레이아웃**

```
┌─────────────────────────────┐
│ [개요●] [안전경보] [입국정보]  │  서브탭 칩 (개요 active)
│ [의료건강] [긴급연락처]        │
├─────────────────────────────┤
│                             │
│          🇯🇵                 │  국기 이미지 (64 x 64)
│        일본                  │  headlineMedium (24sp, SemiBold)
│       Japan                 │  bodyMedium (14sp), onSurfaceVariant
│                             │
│  ┌────── MOFA 안전등급 ─────┐│
│  │ 🔵 1단계: 여행유의         ││  Card_Standard, 좌측 보더 #2196F3
│  │ 2026.03.01 기준           ││  bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │  spacing16
│  ┌──────────┐ ┌──────────┐  │
│  │ 🏛️ 수도   │ │ 🗣️ 언어   │  │  Card_Standard grid (2열)
│  │ 도쿄      │ │ 일본어    │  │  titleMedium + bodyMedium
│  │ (東京)    │ │          │  │
│  └──────────┘ └──────────┘  │  spacing12
│  ┌──────────┐ ┌──────────┐  │
│  │ 💴 화폐   │ │ 🕐 시차   │  │
│  │ 엔 (JPY)  │ │ +0시간    │  │
│  │ ¥        │ │ (한국동일) │  │
│  └──────────┘ └──────────┘  │  spacing12
│  ┌──────────┐ ┌──────────┐  │
│  │ 🔌 전압   │ │ 🛂 비자   │  │
│  │ 100V     │ │ 90일     │  │
│  │ 60Hz     │ │ 무비자    │  │
│  └──────────┘ └──────────┘  │
│                             │  spacing24
│  ─── 빠른 링크 ─────────────│  섹션 구분
│                             │
│  대사관 정보 →               │  TextButton, primaryTeal → J-06
│  긴급 전화번호 →              │  TextButton, primaryTeal → J-06
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 국기 이미지 | `Text` (emoji) / `Image.network` | size: 64dp, alignment: center |
| 국가명 (한글) | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface, textAlign: center |
| 국가명 (영문) | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, textAlign: center |
| MOFA 안전등급 카드 | `Card` | style: Card_Standard, 좌측 보더 4px (Level 색상), padding: 16px |
| 안전등급 뱃지 | `Container` (pill) | backgroundColor: Level 색상, text: "N단계: 명칭", style: labelSmall, color: #FFFFFF |
| 기준 날짜 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 정보 그리드 | `GridView` | crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12 |
| 정보 카드 | `Card` | style: Card_Standard, 내부: 아이콘(24dp) + 라벨(bodySmall, onSurfaceVariant) + 값(titleMedium, SemiBold) |
| 빠른 링크 | `ListTile` | trailing: Icons.chevron_right, onTap: → J-06 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 데이터 로딩 중 | Shimmer placeholder (카드 영역 6개 + 안전등급 카드) |
| 데이터 로드 완료 | 국기, 국가명, 6개 정보 카드, MOFA 안전등급 표시 |
| MOFA Level 1 | 안전등급 카드 좌측 보더 `#2196F3` (Blue), 뱃지 "1단계: 여행유의" |
| MOFA Level 2 | 좌측 보더 `#FFB800` (Amber), 뱃지 "2단계: 여행자제" |
| MOFA Level 3 | 좌측 보더 `#FF5722` (Orange), 뱃지 "3단계: 출국권고" |
| MOFA Level 4 | 좌측 보더 `#D32F2F` (Red), 뱃지 "4단계: 여행금지" + 경고 배너 (하단 참조) |
| Level 4 경고 | 화면 최상단 빨간 배너: "외교부에서 여행금지를 권고하는 국가입니다." |
| 오프라인 (캐시 있음) | 캐시 데이터 표시, 기준 날짜에 "(캐시)" 표시 |
| 오프라인 (캐시 없음) | 국기/국가명만 표시, 정보 카드 "정보를 불러오지 못했습니다." |

**인터랙션**

- [탭] MOFA 안전등급 카드 → 서브탭 "안전경보" (J-03)로 전환
- [탭] 빠른 링크 "대사관 정보" → 서브탭 "긴급연락처" (J-06) 스크롤 to 대사관 섹션
- [탭] 빠른 링크 "긴급 전화번호" → 서브탭 "긴급연락처" (J-06)로 전환
- [풀다운] 컨텐츠 영역 → pull-to-refresh → MOFA API 재조회 (캐시 무효화)
- [스크롤] 하단 → 정보 카드 그리드 + 빠른 링크 노출

---

### J-03 안전 경보 (Safety Alerts)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | J-03 |
| 화면명 | 안전 경보 (Safety Alerts) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | J-01 서브탭 "안전경보" 칩 선택 → J-03 |
| 이탈 경로 | J-03 → 다른 서브탭 (J-02, J-04~J-06) |

**레이아웃**

```
┌─────────────────────────────┐
│ [개요] [안전경보●] [입국정보]  │  서브탭 칩 (안전경보 active)
│ [의료건강] [긴급연락처]        │
├─────────────────────────────┤
│                             │
│  ┌─── MOFA 여행경보 등급 ───┐│
│  │                         ││
│  │  🔵 1단계               ││  Card_Standard
│  │  여행유의                ││  Level 색상 배경 (10% opacity)
│  │                         ││  Level 텍스트: headlineMedium
│  │  해당 국가에 대한 일반적인  ││  bodyMedium, onSurfaceVariant
│  │  주의가 필요합니다.       ││
│  │                         ││
│  │  갱신: 2026.03.01        ││  bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │  spacing24
│  ─── 최근 안전 공지 ─────────│  섹션 헤더
│                             │
│  ┌─────────────────────────┐│
│  │⚠️ 도쿄 지역 태풍 주의보   ││  Card_Alert (amber 좌측 보더)
│  │  2026.03.15 발령         ││  bodySmall, onSurfaceVariant
│  │  3월 18-19일 태풍 접근    ││  bodyMedium, onSurface
│  │  예상. 외출 자제 권고     ││
│  └─────────────────────────┘│  spacing12
│  ┌─────────────────────────┐│
│  │📢 오사카 소매치기 주의     ││  Card_Alert (amber 좌측 보더)
│  │  2026.02.28              ││
│  │  관광지 밀집 지역에서      ││
│  │  소매치기 피해 증가       ││
│  └─────────────────────────┘│
│                             │  spacing24
│  ─── 안전 수칙 ──────────────│  섹션 헤더
│                             │
│  ✅ 여권 사본을 별도 보관하세요 │  DO 항목 (green icon)
│  ✅ 현지 긴급번호를 저장하세요  │
│  ❌ 밤늦게 골목길 혼자 다니지   │  DON'T 항목 (red icon)
│     마세요                   │
│  ❌ 귀중품을 겉에 드러내지     │
│     마세요                   │
│                             │
│  최종 갱신: 2026.03.01 14:30 │  bodySmall, onSurfaceVariant
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 여행경보 등급 카드 | `Card` | style: Card_Standard, 배경 Level 색상 10% opacity, 전체 너비, radius16, padding: 24px |
| Level 아이콘 | `Container` (circle) | size: 48dp, backgroundColor: Level 색상, child: Text(단계 숫자, white, Bold) |
| Level 명칭 | `Text` | style: headlineMedium (24sp, SemiBold), color: Level 색상 |
| Level 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 갱신 날짜 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 섹션 헤더 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 안전 공지 카드 | `Card` | style: Card_Alert, 좌측 보더 `semanticWarning` (#FFAC11), padding: 16px |
| 공지 제목 | `Text` | style: bodyLarge (16sp, SemiBold), color: onSurface |
| 공지 날짜 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 공지 내용 | `Text` | style: bodyMedium (14sp), color: onSurface, maxLines: 3, overflow: ellipsis |
| DO 항목 | `Row` | leading: Icon(check_circle, #15A1A5), title: bodyMedium, spacing: 8px |
| DON'T 항목 | `Row` | leading: Icon(cancel, #DA4C51), title: bodyMedium, spacing: 8px |
| 최종 갱신 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 데이터 로딩 중 | Shimmer placeholder (여행경보 카드 + 공지 리스트 2개) |
| Level 1 (여행유의) | 등급 카드 배경 `#2196F3` 10%, 아이콘/텍스트 `#2196F3` |
| Level 2 (여행자제) | 등급 카드 배경 `#FFB800` 10%, 아이콘/텍스트 `#FFB800` |
| Level 3 (출국권고) | 등급 카드 배경 `#FF5722` 10%, 아이콘/텍스트 `#FF5722` |
| Level 4 (여행금지) | 등급 카드 배경 `#D32F2F` 10%, 상단 빨간 경고 배너 추가: "외교부에서 여행금지를 권고하는 국가입니다. 방문이 불가피한 경우 영사 확인서를 반드시 취득하세요." |
| 안전 공지 0건 | "현재 발령된 안전 공지가 없습니다." placeholder |
| 안전 공지 5건+ | 최대 5건 표시 + "더보기" 버튼 → 전체 공지 리스트 |
| 오프라인 | 캐시 데이터 표시, 최종 갱신 시각에 "(오프라인)" 표시 |

**인터랙션**

- [탭] 여행경보 등급 카드 → 외교부 해외안전여행 웹 링크 (외부 브라우저)
- [탭] 안전 공지 카드 → 카드 확장 (전문 표시) 또는 상세 바텀시트
- [풀다운] 컨텐츠 → pull-to-refresh → MOFA API 안전 공지 재조회
- [스크롤] 하단 → 안전 수칙 DO/DON'T 섹션 노출

---

### J-04 입국/비자 정보 (Entry/Visa Info)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | J-04 |
| 화면명 | 입국/비자 정보 (Entry/Visa Info) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | J-01 서브탭 "입국정보" 칩 선택 → J-04 |
| 이탈 경로 | J-04 → 다른 서브탭 (J-02, J-03, J-05, J-06) |

**레이아웃**

```
┌─────────────────────────────┐
│ [개요] [안전경보] [입국정보●]  │  서브탭 칩 (입국정보 active)
│ [의료건강] [긴급연락처]        │
├─────────────────────────────┤
│                             │
│  ─── 비자 요건 ──────────────│  섹션 헤더 (titleMedium)
│                             │
│  ┌─────────────────────────┐│
│  │ ✅ 90일 무비자 입국 가능   ││  Card_Standard (green tint)
│  │    (관광 목적)            ││  semanticSuccess bg 10%
│  └─────────────────────────┘│
│                             │
│  여권 잔여 유효기간:          │  bodyMedium, onSurface
│  6개월 이상 필요             │  bodyLarge, SemiBold
│                             │  spacing24
│  ─── 필요 서류 체크리스트 ────│  섹션 헤더
│                             │
│  ☐ 여권 (잔여 6개월 이상)     │  CheckboxListTile
│  ☐ 왕복 항공권               │  CheckboxListTile
│     (또는 출국 증빙)          │
│  ☐ 숙소 예약 확인서           │  CheckboxListTile
│  ☐ Visit Japan Web 등록      │  CheckboxListTile
│     (권장)                   │
│                             │  spacing24
│  ─── 입국 절차 ──────────────│  섹션 헤더
│                             │
│  ① 입국 심사 → ② 수하물 →    │  Stepper (horizontal)
│  ③ 세관 신고                 │  3단계 스텝퍼
│                             │  spacing24
│  ─── 통관 정보 ──────────────│  섹션 헤더
│                             │
│  ▸ 반입 금지 품목             │  ExpansionTile (접힌 상태)
│  ▸ 면세 한도                 │  ExpansionTile (접힌 상태)
│    "주류 3병, 담배 400개비,   │
│     향수 2온스"              │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 비자 상태 카드 | `Card` | style: Card_Standard, 배경 `semanticSuccess` 10% (무비자) / `semanticWarning` 10% (비자 필요), padding: 16px |
| 비자 상태 아이콘 | `Icon` | check_circle (무비자) / info (비자 필요), color: semanticSuccess / semanticWarning |
| 비자 상태 텍스트 | `Text` | style: bodyLarge (16sp, SemiBold), color: semanticSuccess / semanticWarning |
| 여권 유효기간 | `Text` | style: bodyMedium (14sp), color: onSurface |
| 체크리스트 항목 | `CheckboxListTile` | activeColor: primaryTeal, controlAffinity: leading, dense: true |
| 체크 완료 카운터 | `Text` | style: bodySmall (12sp), color: primaryTeal, "N/M 완료" |
| 입국 절차 스텝퍼 | `Row` < `Step` x 3 > | horizontal, connectorColor: primaryTeal, circleColor: primaryTeal |
| 통관 정보 | `ExpansionTile` | tilePadding: 0, 접힌 상태 기본, children: bodyMedium 텍스트 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 무비자 입국 가능 | 비자 카드 green tint + check 아이콘 + "N일 무비자 입국 가능" |
| 비자 필요 | 비자 카드 amber tint + info 아이콘 + "비자 발급이 필요합니다" + 비자 종류/발급처 안내 |
| 체크리스트 항목 체크 | 체크박스 활성 (primaryTeal), 완료 카운터 갱신 ("N/M 완료") |
| 체크리스트 전체 완료 | 섹션 헤더 옆 Badge "완료" (semanticSuccess) |
| 데이터 로딩 중 | Shimmer placeholder (비자 카드 + 체크리스트 4줄 + 스텝퍼) |
| 오프라인 (캐시 있음) | 캐시 데이터 표시, 체크리스트 체크 상태는 로컬 저장 유지 |

**인터랙션**

- [탭] 체크박스 → 해당 항목 체크/해제 (체크 상태 로컬 `SharedPreferences` 저장)
- [탭] ExpansionTile (반입 금지 품목 / 면세 한도) → 섹션 펼침/접힘
- [풀다운] 컨텐츠 → pull-to-refresh → MOFA API 입국 정보 재조회
- [스크롤] 하단 → 통관 정보 섹션 노출

---

### J-05 의료/건강 정보 (Medical/Health)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | J-05 |
| 화면명 | 의료/건강 정보 (Medical/Health) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | J-01 서브탭 "의료건강" 칩 선택 → J-05 |
| 이탈 경로 | J-05 → 다른 서브탭 / 외부 지도 앱 (병원 위치) |

**레이아웃**

```
┌─────────────────────────────┐
│ [개요] [안전경보] [입국정보]  │  서브탭 칩 (의료건강 active)
│ [의료건강●] [긴급연락처]      │
├─────────────────────────────┤
│                             │
│  ─── 예방접종 ───────────────│  섹션 헤더 (titleMedium)
│                             │
│  ┌─────────────────────────┐│
│  │ ✅ 필수 예방접종 없음      ││  Card_Standard (green tint)
│  │    (일본)                ││
│  └─────────────────────────┘│
│                             │
│  권장: 독감, B형 간염         │  bodyMedium, onSurfaceVariant
│                             │  spacing24
│  ─── 건강 주의사항 ──────────│  섹션 헤더
│                             │
│  ┌──────────┐ ┌──────────┐  │
│  │ 🦟 모기   │ │ 🥤 수돗물 │  │  Card_Standard grid (2열)
│  │ 매개 질환 │ │ 안전     │  │
│  │ 낮음 ✅   │ │ 음용가능  │  │
│  └──────────┘ └──────────┘  │  spacing12
│  ┌──────────┐ ┌──────────┐  │
│  │ 🏥 의료   │ │ 💊 약품   │  │
│  │ 수준     │ │ 규제     │  │
│  │ 매우높음  │ │ 없음     │  │
│  └──────────┘ └──────────┘  │
│                             │  spacing24
│  ─── 근처 병원 ──────────────│  섹션 헤더
│                             │
│  ┌─────────────────────────┐│
│  │ 🏥 도쿄 대학 병원         ││  Card_Standard
│  │    2.3km                ││  bodySmall, onSurfaceVariant
│  │    📞 03-3815-5411  [📞] ││  trailing: call 버튼
│  └─────────────────────────┘│  spacing12
│  ┌─────────────────────────┐│
│  │ 🏥 성루카 국제병원        ││  Card_Standard
│  │    4.1km · 영어 가능 🌐  ││  언어 통역 뱃지
│  │    📞 03-3541-5151  [📞] ││
│  └─────────────────────────┘│
│                             │
│  [🗺️ 지도에서 병원 보기]      │  Button_Secondary
│                             │  spacing24
│  ─── 여행자 보험 ─────────────│  섹션 헤더
│                             │
│  ┌─────────────────────────┐│
│  │ ℹ️ 해외 여행자 보험 가입을  ││  Card_Alert (warning 보더)
│  │   권장합니다.             ││
│  │                         ││
│  │ 일본 응급실 비용:         ││  bodyMedium, semanticWarning
│  │ 약 30~50만원             ││
│  └─────────────────────────┘│
│                             │
│  응급 전화: 119 (소방/구급)   │  bodyLarge, primaryTeal
│  📞 즉시 전화              │  TextButton, sosDanger
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 예방접종 카드 | `Card` | style: Card_Standard, 배경 semanticSuccess 10% (불필요) / semanticWarning 10% (필요) |
| 건강 정보 그리드 | `GridView` | crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12 |
| 건강 카드 | `Card` | style: Card_Standard, 아이콘 + 라벨 + 상태값, padding: 12px |
| 병원 카드 | `Card` + `InkWell` | style: Card_Standard, leading: 🏥 아이콘, title: 병원명 (bodyLarge), subtitle: 거리 + 언어 뱃지, trailing: call IconButton |
| 언어 뱃지 | `Chip` | style: Chip_Tag, label: "영어 가능" / "한국어 가능", size: small |
| 지도 보기 버튼 | `OutlinedButton` | style: Button_Secondary, icon: Icons.map, text: "지도에서 병원 보기" |
| 보험 안내 카드 | `Card` | style: Card_Alert (warning), 좌측 보더 `semanticWarning` (#FFAC11) |
| 응급 전화 링크 | `InkWell` + `Row` | icon: Icons.phone (sosDanger), text: "119", style: bodyLarge, onTap: tel:119 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 필수 예방접종 없음 | green 카드 + check 아이콘 + "필수 예방접종 없음" |
| 필수 예방접종 있음 | amber 카드 + warning 아이콘 + 접종 목록 (bullet list) |
| 근처 병원 정보 있음 | 병원 카드 리스트 (최대 5개) + 지도 보기 버튼 |
| 근처 병원 정보 없음 (위치 미상) | "여행 위치 정보가 없어 근처 병원을 표시할 수 없습니다." |
| 데이터 로딩 중 | Shimmer placeholder |
| 오프라인 (캐시 있음) | 캐시 데이터 표시, 병원 거리 정보 숨김 |

**인터랙션**

- [탭] 병원 카드 전화 아이콘 → 네이티브 전화 앱 발신 (tel: URL scheme)
- [탭] 병원 카드 본문 → 외부 지도 앱에서 병원 위치 표시
- [탭] "지도에서 병원 보기" → 외부 지도 앱 또는 인앱 지도 뷰 (병원 마커 표시)
- [탭] 응급 전화 링크 (119) → 네이티브 전화 앱 즉시 발신
- [풀다운] 컨텐츠 → pull-to-refresh → 의료 정보 재조회

---

### J-06 긴급 연락처 (Emergency Contacts)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | J-06 |
| 화면명 | 긴급 연락처 (Emergency Contacts) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | J-01 서브탭 "긴급연락처" 칩 선택 → J-06 |
| 이탈 경로 | J-06 → 다른 서브탭 / 네이티브 전화 앱 (원터치 전화) |

> **핵심 원칙:** 탭 진입 후 1초 이내에 긴급연락처가 노출되어야 한다. (원칙 S6)
> 모든 전화번호는 원터치 전화 버튼으로 제공하며, 오프라인 상태에서도 발신 가능하다.

**레이아웃**

```
┌─────────────────────────────┐
│ [개요] [안전경보] [입국정보]  │  서브탭 칩 (긴급연락처 active)
│ [의료건강] [긴급연락처●]      │
├─────────────────────────────┤
│                             │
│  ─── 🚨 현지 긴급전화 ───────│  섹션 헤더 (titleMedium, sosDanger)
│                             │
│  ┌─────────────────────────┐│
│  │ 👮 경찰                  ││  Card_Standard (red tint bg)
│  │                         ││
│  │ 110         ┌──────────┐││
│  │             │ 📞 전화  │││  원터치 전화 버튼
│  │             └──────────┘││  56dp 높이, sosDanger bg
│  ├─────────────────────────┤│  Divider
│  │ 🚒 소방/구급             ││
│  │                         ││
│  │ 119         ┌──────────┐││
│  │             │ 📞 전화  │││  원터치 전화 버튼
│  │             └──────────┘││
│  ├─────────────────────────┤│  Divider
│  │ ⚓ 해양구조              ││
│  │                         ││
│  │ 118         ┌──────────┐││
│  │             │ 📞 전화  │││  원터치 전화 버튼
│  │             └──────────┘││
│  └─────────────────────────┘│
│                             │  spacing24
│  ─── 🇰🇷 대사관/영사관 ──────│  섹션 헤더
│                             │
│  ┌─────────────────────────┐│
│  │ 🇰🇷 주일본 대한민국 대사관 ││  Card_Standard (teal tint)
│  │                         ││
│  │ 📍 도쿄 미나토구          ││  bodyMedium, onSurfaceVariant
│  │    미나미아자부 1-2-5     ││
│  │                         ││
│  │ 📞 03-3452-7611         ││
│  │             ┌──────────┐││
│  │             │ 📞 전화  │││  Button (primaryTeal bg)
│  │             └──────────┘││
│  │                         ││
│  │ 🕐 평일 09:00-12:00,    ││  bodySmall, onSurfaceVariant
│  │    13:30-18:00          ││
│  │                         ││
│  │ 긴급(24시간):           ││  bodyMedium, sosDanger
│  │ 03-3452-7611            ││
│  │             ┌──────────┐││
│  │             │ 🆘 긴급  │││  Button (sosDanger bg)
│  │             └──────────┘││
│  └─────────────────────────┘│
│                             │  spacing24
│  ─── 📞 영사콜센터 ──────────│  섹션 헤더
│                             │
│  ┌─────────────────────────┐│
│  │ 🇰🇷 영사콜센터 (24시간)   ││  Card_Standard
│  │                         ││
│  │ +82-2-3210-0404         ││  bodyLarge, SemiBold
│  │             ┌──────────┐││
│  │             │ 📞 전화  │││  Button (primaryTeal bg)
│  │             └──────────┘││
│  │                         ││
│  │ 해외에서: 현지국번 +      ││  bodySmall, onSurfaceVariant
│  │ 822-3210-0404           ││
│  └─────────────────────────┘│
│                             │  spacing24
│  ─── 👤 내 비상연락처 ────────│  섹션 헤더
│                             │
│  ┌─────────────────────────┐│
│  │ 김부모 (아버지)           ││  Card_Standard
│  │ 010-1234-5678    [📞]   ││  trailing: call IconButton
│  └─────────────────────────┘│
│                             │
│  + 비상연락처 추가            │  TextButton, primaryTeal
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 긴급전화 섹션 카드 | `Card` | style: Card_Standard, 배경 sosDanger 5% opacity, radius16, padding: 0 (내부 ListTile 사용) |
| 긴급전화 행 | `ListTile` | leading: Icon (24dp), title: 서비스명 (bodyLarge, SemiBold), subtitle: 전화번호 (headlineMedium, 24sp), trailing: call 버튼 |
| 원터치 전화 버튼 | `ElevatedButton` + `Icon` | minHeight: 56dp, backgroundColor: sosDanger (#D32F2F), icon: Icons.phone (white), text: "전화", style: labelLarge (white) |
| 대사관 카드 | `Card` | style: Card_Standard, 배경 primaryTeal 5% opacity, padding: 16px |
| 대사관 주소 | `Row` | leading: Icon(location_on, 16dp), title: bodyMedium, color: onSurfaceVariant |
| 대사관 전화 버튼 | `ElevatedButton` | backgroundColor: primaryTeal, text: "전화" |
| 대사관 긴급 버튼 | `ElevatedButton` | backgroundColor: sosDanger, text: "긴급 전화" |
| 운영 시간 | `Row` | leading: Icon(access_time, 16dp), title: bodySmall, color: onSurfaceVariant |
| 영사콜센터 카드 | `Card` | style: Card_Standard, padding: 16px |
| 비상연락처 카드 | `Card` + `InkWell` | style: Card_Standard, title: 이름(관계), trailing: call IconButton (primaryTeal) |
| 비상연락처 추가 | `TextButton` | icon: Icons.add, text: "비상연락처 추가", color: primaryTeal |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 데이터 로드 완료 | 현지 긴급전화 + 대사관 + 영사콜센터 + 내 비상연락처 전체 표시 |
| 현지 긴급번호 미등록 | 긴급전화 섹션: "현지 긴급번호 정보 없음" + 영사콜센터 대체 표시 (강조) |
| 대사관 정보 없음 | 대사관 섹션 숨김, 영사콜센터만 표시 |
| 내 비상연락처 미등록 | "비상연락처를 등록해주세요" 안내 + 추가 버튼 강조 |
| 전화 권한 미허용 | 전화 버튼 탭 시 시스템 권한 다이얼로그 표시 |
| 오프라인 | 캐시된 번호로 전체 표시, 원터치 전화 버튼 정상 동작 (전화는 오프라인 무관) |
| 데이터 로딩 중 | 긴급전화 섹션은 하드코딩 즉시 표시 (1초 이내), 나머지 Shimmer |

**인터랙션**

- [탭] 원터치 전화 버튼 (경찰/소방/구급) → 네이티브 전화 앱 즉시 연결 (url_launcher: tel:)
- [탭] 대사관 전화 버튼 → 네이티브 전화 앱 발신
- [탭] 대사관 긴급 전화 버튼 → 네이티브 전화 앱 즉시 발신
- [탭] 영사콜센터 전화 버튼 → tel:+82-2-3210-0404
- [탭] 내 비상연락처 전화 아이콘 → 해당 번호로 전화 발신
- [탭] "+ 비상연락처 추가" → Navigator.push → K-02 프로필 편집 (비상연락처 섹션)
- [탭] 대사관 주소 → 외부 지도 앱에서 위치 표시

---

### J-07 국가 변경 (Country Select)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | J-07 |
| 화면명 | 국가 변경 (Country Select) |
| Phase | P1 |
| 역할 | 전체 |
| 진입 경로 | J-01 국가 변경 버튼 (🌐) → J-07 |
| 이탈 경로 | J-07 → J-01 (선택 국가 반영) / J-07 → 뒤로가기 (변경 취소) |

> **참고:** 여행 목적지와 별개로 다른 국가의 안전 정보를 자유롭게 탐색할 수 있다.
> 수동 변경 후 여행 상태가 변경되면 컨텍스트 자동 선택으로 복원된다.

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 국가 변경                │  AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─ 🔍 ────────────────────┐│
│  │ 국가명을 검색하세요        ││  Input_Search (pill shape)
│  └─────────────────────────┘│
│                             │  spacing24
│  ─── 현재 선택 ──────────────│  섹션 헤더
│                             │
│  ┌─────────────────────────┐│
│  │ 🇯🇵 일본 (Japan)    ✅   ││  Card_Selectable (selected)
│  │    여행 목적지            ││  bodySmall, primaryTeal
│  └─────────────────────────┘│
│                             │  spacing24
│  ─── 최근 조회 ──────────────│  섹션 헤더
│                             │
│  ┌─────────────────────────┐│
│  │ 🇹🇭 태국 (Thailand)      ││  Card_Standard
│  │    3일 전 조회            ││  bodySmall, onSurfaceVariant
│  └─────────────────────────┘│  spacing8
│  ┌─────────────────────────┐│
│  │ 🇻🇳 베트남 (Vietnam)     ││  Card_Standard
│  │    5일 전 조회            ││
│  └─────────────────────────┘│
│                             │  spacing24
│  ─── 인기 여행지 ─────────────│  섹션 헤더
│                             │
│  ┌──────┐ ┌──────┐ ┌──────┐│
│  │ 🇯🇵   │ │ 🇹🇭   │ │ 🇻🇳   ││  Chip_Tag grid (wrap)
│  │ 일본  │ │ 태국  │ │ 베트남 ││
│  └──────┘ └──────┘ └──────┘│
│  ┌──────┐ ┌──────┐ ┌──────┐│
│  │ 🇺🇸   │ │ 🇫🇷   │ │ 🇬🇧   ││
│  │ 미국  │ │ 프랑스 │ │ 영국  ││
│  └──────┘ └──────┘ └──────┘│
│                             │  spacing24
│  ─── 전체 국가 (가나다순) ────│  섹션 헤더
│                             │
│  🇬🇭 가나                    │  ListTile
│  🇬🇦 가봉                    │  ListTile
│  🇬🇾 가이아나                 │  ListTile
│  ...                        │  (스크롤 가능)
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "국가 변경", leading: BackButton, style: AppBar_Standard |
| 검색 입력 | `TextField` | style: Input_Search (pill shape), hintText: "국가명을 검색하세요", prefixIcon: Icons.search, clearButton: filled 시 표시 |
| 현재 선택 카드 | `Card` + `InkWell` | style: Card_Selectable (selected), trailing: check 아이콘 (primaryTeal), subtitle: "여행 목적지" (컨텍스트 선택 시) |
| 최근 조회 카드 | `Card` + `InkWell` | style: Card_Standard, leading: 국기 emoji, title: 국가명, subtitle: "N일 전 조회" |
| 인기 여행지 칩 | `Wrap` < `ActionChip` > | style: Chip_Tag, avatar: 국기 emoji, label: 국가명, spacing: 8px, runSpacing: 8px |
| 전체 국가 리스트 | `ListView.builder` | itemBuilder: ListTile (국기 + 국가명), separator: Divider (outlineVariant) |
| 알파벳 인덱스 | `AlphabetScrollbar` (optional) | 우측 세로 알파벳 인덱스, 가나다순 빠른 이동 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 현재 선택 국가 표시 + 최근 조회 (최대 5개) + 인기 여행지 + 전체 국가 리스트 |
| 검색 입력 중 | 전체 국가 리스트에서 실시간 필터링, 일치 결과만 표시, 최근 조회/인기 섹션 숨김 |
| 검색 결과 있음 | 필터링된 국가 리스트 표시 (국가명 한글/영문 매칭) |
| 검색 결과 없음 | "검색 결과가 없습니다." placeholder + "영사콜센터로 문의" 링크 |
| 국가 선택 완료 | Navigator.pop → J-01 (선택 국가 반영), 최근 조회 목록에 추가 |
| 최근 조회 없음 | "최근 조회" 섹션 숨김 |
| 여행 목적지 국가 선택 | 현재 선택 카드 subtitle: "여행 목적지" (primaryTeal) |
| 수동 선택 국가 | 현재 선택 카드 subtitle: "수동 선택" (onSurfaceVariant) |

**인터랙션**

- [입력] 검색 필드 → 실시간 국가명 필터링 (한글/영문, debounce 300ms)
- [탭] 검색 필드 클리어 버튼 (X) → 검색어 초기화, 전체 리스트 복원
- [탭] 최근 조회 카드 → 해당 국가 선택 → J-01로 복귀
- [탭] 인기 여행지 칩 → 해당 국가 선택 → J-01로 복귀
- [탭] 전체 국가 리스트 항목 → 해당 국가 선택 → J-01로 복귀
- [뒤로가기] → J-01 (국가 변경 없이 복귀)

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 7개 화면 (J-01 ~ J-07) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 안전가이드 원칙: `Master_docs/21_T3_안전가이드_원칙.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
