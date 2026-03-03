# O. AI 기능

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 AI 기능 5개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 5개 (O-01 ~ O-05)
- **Phase:** P2 3개 (O-01, O-02, O-04), P3 2개 (O-03, O-05)
- **핵심 역할:** 전체 (일부 AI Plus+/Pro 전용)
- **AI 3계층:** Safety AI (무료) → Convenience AI (Plus+) → Intelligence AI (Pro)

---

## AI 계층 구조

```
┌─────────────────────────────────────────────────────┐
│  Intelligence AI (Pro)                              │ #7C4DFF
│  이동 패턴 분석, 안전 인사이트, 일정 최적화            │
├─────────────────────────────────────────────────────┤
│  Convenience AI (Plus+)                             │ #FFB800
│  교통 최적화, 일정 추천, 주변 시설, 일일 브리핑         │
├─────────────────────────────────────────────────────┤
│  Safety AI (무료)                                    │ #D32F2F
│  위험 감지 알림, 인시던트 분석                          │
└─────────────────────────────────────────────────────┘
```

---

## AI 디자인 토큰

| 토큰명 | HEX | 용도 |
|--------|-----|------|
| `aiAccent` | `#7C4DFF` | AI 기능 공통 강조 색상 |
| `aiSafety` | `#D32F2F` | Safety AI 전용 (SOS와 동일) |
| `aiPlusBadge` | `#FFB800` | AI Plus+ 뱃지 색상 (`secondaryAmber` 계열) |
| `aiProBadge` | `#7C4DFF` | AI Pro 뱃지 색상 (`aiAccent` 동일) |
| `severity주의` | `#FFB800` | 주의 등급 |
| `severity경고` | `#FF5722` | 경고 등급 |
| `severity위험` | `#D32F2F` | 위험 등급 |

---

## User Journey Flow

```
[메인맵 C-01]
  ├── 푸시 알림 수신 ──────→ O-01 Safety AI 알림 (무료)
  ├── AI 탭 / AI 메뉴 ─────→ O-02 Convenience AI (Plus+)
  │                          ├── 교통 최적화
  │                          ├── 일정 추천
  │                          └── 주변 시설
  ├── AI 분석 대시보드 ─────→ O-03 Intelligence AI (Pro)
  ├── 아침 푸시 / AI 브리핑 ─→ O-04 AI 브리핑 (Plus+)
  └── 일정탭 → AI 최적화 ──→ O-05 AI 일정 최적화 (Pro)
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| C-01 메인맵 | 푸시 알림 탭 | O-01 Safety AI 알림 | O |
| C-01 메인맵 | AI 메뉴 진입 | O-02 Convenience AI | O |
| O-02 | AI Pro 기능 탭 | O-03 Intelligence AI | O |
| C-01 메인맵 | 아침 브리핑 푸시 | O-04 AI 브리핑 | O |
| D-02 일정탭 | AI 최적화 버튼 | O-05 AI 일정 최적화 | O |
| O-02 | "적용" 탭 | D-02 일정탭 | D |
| O-05 | "적용" 탭 | D-02 일정탭 | D |

---

## 화면 상세

---

### O-01 Safety AI 알림 (AI Safety Alert)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | O-01 |
| 화면명 | Safety AI 알림 (AI Safety Alert) |
| Phase | P2 |
| 역할 | 전체 (무료) |
| AI 계층 | Safety AI |
| 진입 경로 | 푸시 알림 탭 → O-01 / C-01 메인맵 알림 아이콘 → O-01 |
| 이탈 경로 | O-01 → C-01 (닫기/확인) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] Safety AI 알림      [🔔 이력]   │ AppBar_Standard
│                                     │ 배경: aiSafety tint
├─────────────────────────────────────┤
│                                     │
│  ⚠️ 안전 알림                        │ headlineMedium (24sp, SemiBold)
│  AI가 위험을 감지했습니다              │ bodyMedium, onSurfaceVariant
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 🔴 [위험] 자연재해               ││ Card_Alert (severity border)
│  │                                 ││
│  │ 태풍 "카눈" 접근 중               ││ titleMedium (18sp, SemiBold)
│  │                                 ││
│  │  유형    자연재해 (태풍)           ││ bodyMedium, row layout
│  │  심각도  ██████████ 위험          ││ LinearProgressIndicator + label
│  │  발생시각 2026-03-03 14:30       ││ bodySmall, onSurfaceVariant
│  │  영향범위 반경 50km               ││ bodySmall, onSurfaceVariant
│  │                                 ││
│  │ ┌─────────────────────────────┐ ││
│  │ │                             │ ││
│  │ │    📍 영향 지역 미니맵        │ ││ Google Map (120dp height)
│  │ │    (빨간 원형 영역 표시)      │ ││ 반투명 aiSafety 원
│  │ │                             │ ││
│  │ └─────────────────────────────┘ ││
│  │                                 ││
│  │ 📋 권장 조치                     ││ titleSmall, SemiBold
│  │  1. 실내로 즉시 대피하세요        ││ bodyMedium, numbered list
│  │  2. 창문에서 떨어지세요           ││
│  │  3. 긴급 연락처를 확인하세요      ││
│  │  4. 그룹 채팅에 안전 보고하세요   ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │ spacing16
│  ┌─────────────────────────────────┐│
│  │        확인했습니다               ││ Button_Primary
│  └─────────────────────────────────┘│
│                                     │
│  이 알림은 자동으로 기록됩니다         │ bodySmall, onSurfaceVariant
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "Safety AI 알림", leading: BackButton, actions: 이력 아이콘, style: AppBar_Standard |
| 알림 헤더 | `Text` | style: headlineMedium (24sp, SemiBold), icon: ⚠️ |
| 헤더 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 인시던트 카드 | `Card` | style: Card_Alert, borderColor: severity별 상이 (주의 #FFB800 / 경고 #FF5722 / 위험 #D32F2F) |
| 심각도 뱃지 | `Container` (pill) | backgroundColor: severity색상, text: "주의"/"경고"/"위험", labelSmall, #FFFFFF |
| 유형 태그 | `Chip_Tag` | text: "자연재해"/"범죄"/"질병"/"교통", backgroundColor: surfaceVariant |
| 인시던트 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 상세 행 | `Row` | leading: label (bodySmall, onSurfaceVariant), trailing: value (bodyMedium, onSurface) |
| 심각도 바 | `LinearProgressIndicator` | value: 0.0~1.0, color: severity색상, trackColor: outline, height: 8dp, radius4 |
| 영향 지역 맵 | `GoogleMap` (static) | height: 120dp, radius8, 반투명 aiSafety 원형 오버레이 |
| 권장 조치 목록 | `Column` < `Row` > | leading: 번호 (bodyMedium, aiSafety), trailing: 텍스트 (bodyMedium, onSurface) |
| 확인 버튼 | `ElevatedButton` | style: Button_Primary, text: "확인했습니다" |
| 기록 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (푸시 진입) | 인시던트 카드 1개 표시, 심각도에 따른 보더 색상 |
| 심각도 — 주의 | 카드 보더 #FFB800, 심각도 바 33%, 뱃지 배경 #FFB800 |
| 심각도 — 경고 | 카드 보더 #FF5722, 심각도 바 66%, 뱃지 배경 #FF5722 |
| 심각도 — 위험 | 카드 보더 #D32F2F, 심각도 바 100%, 뱃지 배경 #D32F2F, 상단 배너 진동 |
| 확인 완료 | 알림 읽음 처리 (PATCH /api/v1/ai/alerts/:alertId/acknowledge), Navigator.pop → C-01 |
| 복수 알림 | ScrollView로 인시던트 카드 복수 표시, 최신순 정렬 |
| 네트워크 오류 | Toast "알림 확인에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [자동] 푸시 알림 수신 → 기기 진동 + 알림 소리 (심각도별 상이)
- [탭] 푸시 알림 → 앱 실행 → O-01 Safety AI 알림 화면 직행
- [탭] 확인했습니다 → PATCH /api/v1/ai/alerts/:alertId/acknowledge → 알림 읽음 처리 → C-01 복귀
- [탭] 이력 아이콘 (🔔) → K-05 알림 이력 화면 (AI 알림 필터)
- [탭] 영향 지역 맵 → C-01 메인맵으로 해당 좌표 줌인
- [뒤로가기] → C-01 메인맵 (알림은 자동 기록, 확인 미완료 상태 유지)

---

### O-02 Convenience AI (AI Convenience)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | O-02 |
| 화면명 | Convenience AI (AI Convenience) |
| Phase | P2 |
| 역할 | 전체 (AI Plus+ 전용 기능) |
| AI 계층 | Convenience AI |
| 진입 경로 | C-01 메인맵 AI 메뉴 → O-02 |
| 이탈 경로 | O-02 → C-01 (뒤로가기) / O-02 → D-02 일정탭 (적용 시) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] AI 어시스턴트     [Plus+ 뱃지]   │ AppBar_Standard
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 🤖 AI가 여행을 도와드립니다       ││ Card_Standard
│  │ 현재 위치와 일정을 기반으로        ││ bodyMedium, onSurfaceVariant
│  │ 맞춤 추천을 제공합니다            ││
│  └─────────────────────────────────┘│
│                                     │
│  ── 🚗 교통 최적화 ──────────────── │ Section Header (titleLarge)
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 현재 → 다음 일정 이동 방법        ││ Card_Standard
│  │                                 ││
│  │ ┌──────────┐ ┌──────────┐      ││
│  │ │ 🚇 지하철  │ │ 🚕 택시   │      ││ 2-column grid
│  │ │ 35분     │ │ 15분     │      ││ Card_Selectable (mini)
│  │ │ ₩1,350   │ │ ₩8,500   │      ││
│  │ │ 추천 ⭐   │ │          │      ││ aiAccent 뱃지 (추천)
│  │ └──────────┘ └──────────┘      ││
│  │ ┌──────────┐ ┌──────────┐      ││
│  │ │ 🚌 버스   │ │ 🚶 도보   │      ││
│  │ │ 45분     │ │ 60분     │      ││
│  │ │ ₩1,200   │ │ 무료     │      ││
│  │ └──────────┘ └──────────┘      ││
│  │                                 ││
│  │  ┌───────────────────────────┐  ││
│  │  │     이 경로 적용            │  ││ Button_Secondary (inline)
│  │  └───────────────────────────┘  ││
│  └─────────────────────────────────┘│
│                                     │ spacing24
│  ── 📅 일정 추천 ────────────────── │ Section Header (titleLarge)
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 🕐 14:00-16:00 여유 시간 감지    ││ Card_Standard
│  │                                 ││
│  │ ┌───────────────────────────┐   ││
│  │ │ 📍 센소지 (浅草寺)          │   ││ 추천 장소 카드 (mini)
│  │ │ 도보 10분 · 인기 관광지      │   ││ bodySmall, onSurfaceVariant
│  │ │ ⭐ 4.5 · 무료              │   ││ rating + price
│  │ └───────────────────────────┘   ││
│  │ ┌───────────────────────────┐   ││
│  │ │ 📍 우에노 공원              │   ││ 추천 장소 카드 (mini)
│  │ │ 전철 15분 · 자연/공원       │   ││
│  │ │ ⭐ 4.3 · 무료              │   ││
│  │ └───────────────────────────┘   ││
│  │                                 ││
│  │  ┌───────────────────────────┐  ││
│  │  │   일정에 추가               │  ││ Button_Secondary (inline)
│  │  └───────────────────────────┘  ││
│  └─────────────────────────────────┘│
│                                     │ spacing24
│  ── 🏥 주변 시설 ────────────────── │ Section Header (titleLarge)
│                                     │
│  ┌─ 카테고리 필터 ─────────────────┐│
│  │ [🏥 병원] [💊 약국] [🏧 ATM]    ││ Chip_Tag (horizontal scroll)
│  │ [👮 경찰서] [🏪 편의점]          ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 🏥 도쿄대학 병원                 ││ ListTile-style row
│  │ 도보 8분 · 850m · 영어 가능      ││ bodySmall, onSurfaceVariant
│  │                          [길찾기]││ TextButton, primaryTeal
│  ├─────────────────────────────────┤│
│  │ 💊 마츠모토키요시 아키하바라점     ││ ListTile-style row
│  │ 도보 3분 · 200m · 24시간         ││
│  │                          [길찾기]││
│  └─────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "AI 어시스턴트", leading: BackButton, actions: Plus+ 뱃지, style: AppBar_Standard |
| Plus+ 뱃지 | `Container` (pill) | backgroundColor: aiPlusBadge (#FFB800), text: "Plus+", labelSmall, #FFFFFF |
| AI 안내 카드 | `Card` | style: Card_Standard, leading: 🤖, bodyMedium |
| 섹션 헤더 | `Text` | style: titleLarge (20sp, SemiBold), color: onSurface, leading: icon |
| 교통 카드 | `Card` | style: Card_Standard |
| 교통 옵션 그리드 | `GridView` (2열) | children: Card_Selectable (mini), 각 카드: 아이콘 + 이동수단명 + 소요시간 + 비용 |
| 추천 뱃지 | `Container` (pill) | backgroundColor: aiAccent (#7C4DFF), text: "추천 ⭐", labelSmall, #FFFFFF |
| 적용 버튼 (교통) | `OutlinedButton` | style: Button_Secondary, text: "이 경로 적용" |
| 일정 추천 카드 | `Card` | style: Card_Standard, header: 여유 시간 감지 텍스트 |
| 추천 장소 미니카드 | `Card` + `InkWell` | radius8, leading: 📍, title: 장소명 (bodyLarge), subtitle: 거리+카테고리 (bodySmall), trailing: 평점+가격 |
| 일정 추가 버튼 | `OutlinedButton` | style: Button_Secondary, text: "일정에 추가" |
| 카테고리 필터 | `SingleChildScrollView` + `Row` < `Chip_Tag` > | horizontal, 카테고리별 아이콘+텍스트 |
| 시설 목록 | `Column` < `ListTile` > | leading: 카테고리 아이콘, title: 시설명 (bodyLarge), subtitle: 거리+소요시간+특징 (bodySmall), trailing: 길찾기 TextButton |
| 길찾기 버튼 | `TextButton` | color: primaryTeal, text: "길찾기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (로딩) | 각 섹션 `ShimmerPlaceholder` (3개 카드 크기), AI 분석 중 인디케이터 |
| AI Plus+ 미구독 | 각 섹션 잠금 오버레이 + "Plus+ 구독으로 잠금 해제" 배너, 탭 시 L-01 구독 화면 이동 |
| 교통 데이터 로드 완료 | 4개 교통 옵션 그리드 표시, AI 추천 옵션에 aiAccent 뱃지 |
| 교통 옵션 선택 | 선택 카드 좌측 보더 aiAccent + 배경 tint, "이 경로 적용" 버튼 활성 |
| 일정 추천 로드 완료 | 여유 시간 + 추천 장소 2~3개 카드 표시 |
| 추천 장소 탭 | 장소 상세 바텀시트 (Modal_Bottom) 열림: 사진, 운영시간, 리뷰 발췌 |
| 주변 시설 카테고리 선택 | 선택 칩 활성 (aiAccent 배경), 해당 카테고리 시설 목록 필터링 |
| 적용 완료 | Toast "일정에 추가되었습니다" + Navigator.pop → D-02 일정탭 |
| 여행 없음 (none 상태) | 전체 비활성, "여행을 먼저 생성해주세요" 안내 |
| 네트워크 오류 | Toast "AI 데이터를 불러올 수 없습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 교통 옵션 카드 → 해당 교통 수단 선택 (단일 선택)
- [탭] 이 경로 적용 → POST /api/v1/ai/transport/apply → D-02 일정에 교통 정보 반영
- [탭] 추천 장소 미니카드 → Modal_Bottom (장소 상세: 사진, 운영시간, 리뷰)
- [탭] 일정에 추가 → POST /api/v1/ai/schedule/add → 일정탭에 반영 → Toast 확인
- [탭] 카테고리 필터 칩 → 해당 카테고리 시설 목록 필터링 (복수 선택 가능)
- [탭] 길찾기 → 외부 지도 앱 Intent (Google Maps / Kakao Map) 또는 C-01 경로 오버레이
- [스크롤] 전체 화면 수직 스크롤 (3개 섹션 연속 배치)
- [뒤로가기] → C-01 메인맵

---

### O-03 Intelligence AI (AI Intelligence)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | O-03 |
| 화면명 | Intelligence AI (AI Intelligence) |
| Phase | P3 |
| 역할 | 전체 (AI Pro 전용, 미성년자 제한: 그룹 수준 분석만) |
| AI 계층 | Intelligence AI |
| 진입 경로 | O-02 AI 메뉴 → Pro 영역 탭 → O-03 / C-01 메인맵 AI 대시보드 → O-03 |
| 이탈 경로 | O-03 → C-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] AI Intelligence    [Pro 뱃지]   │ AppBar_Standard
├─────────────────────────────────────┤
│                                     │
│  ┌─ 기간 필터 ─────────────────────┐│
│  │ [오늘] [3일] [7일] [전체]        ││ SegmentedButton
│  └─────────────────────────────────┘│
│                                     │
│  ── 🗺️ 이동 패턴 분석 ──────────── │ Section Header (titleLarge)
│                                     │
│  ┌─────────────────────────────────┐│
│  │                                 ││
│  │  ┌───────────────────────────┐  ││ Card_Standard
│  │  │                           │  ││
│  │  │    히트맵 오버레이 지도     │  ││ GoogleMap + Heatmap layer
│  │  │    (활동 밀집 지역 표시)    │  ││ 200dp height
│  │  │    🟡 → 🟠 → 🔴           │  ││ 밀도 그래디언트
│  │  │                           │  ││
│  │  └───────────────────────────┘  ││
│  │                                 ││
│  │  📊 자주 방문한 장소             ││ titleSmall, SemiBold
│  │                                 ││
│  │  1. 🏨 호텔 (숙소)        28회  ││ bodyMedium, numbered
│  │  2. 📍 시부야역          12회   ││ trailing: 방문 횟수
│  │  3. 📍 하라주쿠          8회    ││
│  │  4. 🍜 이치란라멘         5회   ││
│  │  5. 📍 신주쿠역          4회    ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │ spacing24
│  ── 🛡️ 안전 인사이트 ──────────── │ Section Header (titleLarge)
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 안전 점수 추이                   ││ Card_Standard
│  │                                 ││
│  │  100 ┐                          ││
│  │   80 ┤  ──●──●──●──            ││ LineChart
│  │   60 ┤          ╲              ││ aiAccent (#7C4DFF) 라인
│  │   40 ┤           ●──●          ││ 200dp height
│  │   20 ┤                          ││
│  │    0 └──┬──┬──┬──┬──┬──        ││
│  │         3/1 3/2 3/3 3/4 3/5     ││ 날짜 x축
│  │                                 ││
│  │  현재 안전 점수                   ││
│  │        ┌─────────┐              ││
│  │        │  72/100  │              ││ titleLarge, aiAccent
│  │        │   양호   │              ││ bodySmall, semanticSuccess
│  │        └─────────┘              ││
│  └─────────────────────────────────┘│
│                                     │ spacing16
│  ┌─────────────────────────────────┐│
│  │ ⚠️ 이상 감지 알림                ││ Card_Alert
│  │                                 ││ borderColor: semanticWarning
│  │ 3월 3일 22:30                   ││ bodySmall, onSurfaceVariant
│  │ 야간 시간대 비정상 이동 패턴 감지  ││ bodyMedium, onSurface
│  │ 숙소에서 2.3km 벗어남            ││ bodySmall, semanticWarning
│  │                                 ││
│  │                     [상세 보기]  ││ TextButton, aiAccent
│  ├─────────────────────────────────┤│
│  │ ✅ 이상 없음                     ││ Card_Standard (dimmed)
│  │                                 ││
│  │ 3월 2일 — 정상 활동 패턴          ││ bodyMedium, onSurfaceVariant
│  └─────────────────────────────────┘│
│                                     │
│  ⓘ 미성년자: 개인 추적이 아닌        │ bodySmall, onSurfaceVariant
│    그룹 수준 분석만 제공됩니다        │ italic, 하단 고정 안내
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "AI Intelligence", leading: BackButton, actions: Pro 뱃지, style: AppBar_Standard |
| Pro 뱃지 | `Container` (pill) | backgroundColor: aiProBadge (#7C4DFF), text: "Pro", labelSmall, #FFFFFF |
| 기간 필터 | `SegmentedButton` | segments: ["오늘", "3일", "7일", "전체"], selectedColor: aiAccent, radius8 |
| 섹션 헤더 | `Text` | style: titleLarge (20sp, SemiBold), color: onSurface, leading: icon |
| 히트맵 카드 | `Card` | style: Card_Standard |
| 히트맵 지도 | `GoogleMap` + `HeatmapTileOverlay` | height: 200dp, radius8, 밀도 그래디언트 (낮음: #FFD54F → 중간: #FF9800 → 높음: #D32F2F) |
| 자주 방문 목록 | `Column` < `Row` > | leading: 순번+아이콘, title: 장소명 (bodyMedium), trailing: 방문 횟수 (bodyMedium, aiAccent) |
| 안전 점수 차트 | `LineChart` (fl_chart) | height: 200dp, lineColor: aiAccent (#7C4DFF), dotColor: aiAccent, gridColor: outlineVariant |
| 현재 점수 | `Container` | 중앙 정렬, score (titleLarge, aiAccent), label (bodySmall, 점수 구간별 색상) |
| 이상 감지 카드 | `Card` | style: Card_Alert, borderColor: semanticWarning (#FFAC11) |
| 정상 카드 | `Card` | style: Card_Standard, opacity: 0.6 |
| 상세 보기 버튼 | `TextButton` | color: aiAccent (#7C4DFF), text: "상세 보기" |
| 미성년자 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, fontStyle: italic |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (로딩) | 히트맵/차트 영역 ShimmerPlaceholder, "AI가 데이터를 분석 중입니다" 텍스트 |
| AI Pro 미구독 | 전체 잠금 오버레이 + "Pro 구독으로 잠금 해제" 배너 + 블러 처리, 탭 시 L-01 구독 화면 |
| 기간 필터 변경 | 선택 segment aiAccent 배경, 히트맵/차트/목록 해당 기간 데이터로 갱신 |
| 데이터 충분 | 히트맵 표시 + 자주 방문 목록 최대 10개 + 안전 점수 차트 라인 |
| 데이터 부족 (여행 1일 미만) | 빈 상태: "아직 분석할 데이터가 부족합니다. 여행을 시작하면 AI가 분석을 시작합니다." |
| 안전 점수 — 양호 (70~100) | 점수 색상 semanticSuccess (#15A1A5), 라벨 "양호" |
| 안전 점수 — 주의 (40~69) | 점수 색상 semanticWarning (#FFAC11), 라벨 "주의" |
| 안전 점수 — 위험 (0~39) | 점수 색상 sosDanger (#D32F2F), 라벨 "위험" |
| 이상 감지 존재 | Card_Alert 표시 (semanticWarning 보더), 최대 5개 시간순 |
| 이상 감지 없음 | "✅ 이상 감지 없음 — 안전한 여행 중입니다" 안내 카드 |
| 미성년자 사용자 | 개인 히트맵 → 그룹 히트맵, 개인 방문 목록 → 그룹 통계, 하단 안내 문구 표시 |

**인터랙션**

- [탭] 기간 필터 segment → GET /api/v1/ai/intelligence?period=today|3d|7d|all → 데이터 갱신
- [탭] 히트맵 지도 → 해당 영역 줌인/줌아웃 (제스처 지원)
- [탭] 자주 방문 장소 항목 → C-01 메인맵에서 해당 좌표로 이동
- [탭] 이상 감지 카드 "상세 보기" → Modal_Bottom (상세: 감지 시각, 위치, AI 판단 근거, 권장 조치)
- [탭] Pro 뱃지 (미구독 시) → L-01 구독 화면
- [스크롤] 전체 화면 수직 스크롤 (2개 섹션 + 이상 감지 목록)
- [뒤로가기] → C-01 메인맵

---

### O-04 AI 브리핑 (AI Briefing)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | O-04 |
| 화면명 | AI 브리핑 (AI Briefing) |
| Phase | P2 |
| 역할 | 전체 (AI Plus+ 전용) |
| AI 계층 | Convenience AI |
| 진입 경로 | 푸시 알림 (매일 07:00 현지 시간) → O-04 / C-01 메인맵 AI 메뉴 → O-04 |
| 이탈 경로 | O-04 → C-01 (완료/닫기) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] AI 브리핑         [Plus+ 뱃지]  │ AppBar_Standard
├─────────────────────────────────────┤
│                                     │
│  ☀️ 좋은 아침이에요!                  │ headlineMedium (24sp, SemiBold)
│  3월 3일 화요일 안전 브리핑            │ bodyMedium, onSurfaceVariant
│                                     │
│  ┌── 카드 1/4 (스와이프) ──────────┐│
│  │                                 ││
│  │  ── 🌤️ 오늘 날씨 ──            ││ Card_Standard (swipeable)
│  │                                 ││ 전체 너비, 높이 280dp
│  │       ☁️  18°C                  ││ displayLarge (36sp)
│  │     구름 조금                    ││ bodyLarge, onSurface
│  │                                 ││
│  │  최저 12°C    최고 22°C          ││ bodyMedium, 2-column
│  │  습도 45%     강수확률 10%        ││
│  │  바람 북서풍 3m/s                ││
│  │                                 ││
│  │  💡 자외선 지수 높음 —            ││ bodySmall, semanticWarning
│  │     자외선 차단제를 챙기세요      ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│         ● ○ ○ ○                     │ PageIndicator (4 dots)
│                                     │
│  ┌── 카드 2/4 ─────────────────────┐│
│  │                                 ││
│  │  ── 🛡️ 안전지수 ──              ││ Card_Standard (swipeable)
│  │                                 ││
│  │       ┌──────────────┐          ││
│  │       │              │          ││ CircularProgressIndicator
│  │       │    78/100    │          ││ determinate, aiAccent
│  │       │     양호     │          ││ 120 x 120 dp
│  │       └──────────────┘          ││
│  │                                 ││
│  │  지역 범죄율: 낮음               ││ bodyMedium, row layout
│  │  자연재해 위험: 없음              ││ 각 항목 왼: 라벨, 우: 상태
│  │  교통 혼잡도: 보통               ││
│  │  전염병 경보: 없음               ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌── 카드 3/4 ─────────────────────┐│
│  │                                 ││
│  │  ── ⚠️ 주의사항 ──              ││ Card_Standard (swipeable)
│  │                                 ││
│  │  ┌─────────────────────────┐    ││
│  │  │ 🟡 소매치기 주의          │    ││ ListTile-style
│  │  │ 관광지 주변 소매치기 빈발  │    ││ severity: 주의 (#FFB800)
│  │  └─────────────────────────┘    ││
│  │  ┌─────────────────────────┐    ││
│  │  │ 🟡 야간 이동 주의         │    ││ ListTile-style
│  │  │ 22시 이후 대중교통 감소    │    ││ severity: 주의 (#FFB800)
│  │  └─────────────────────────┘    ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌── 카드 4/4 ─────────────────────┐│
│  │                                 ││
│  │  ── 🎯 추천 활동 ──             ││ Card_Standard (swipeable)
│  │                                 ││
│  │  ┌─────────────────────────┐    ││
│  │  │ 🏯 아사쿠사 산책           │    ││ 추천 카드 (mini)
│  │  │ 오전 시간대 방문 추천       │    ││ bodySmall
│  │  │ 날씨 좋음 · 혼잡도 낮음    │    ││ Chip_Tag (2개)
│  │  └─────────────────────────┘    ││
│  │  ┌─────────────────────────┐    ││
│  │  │ 🍜 츠키지 시장             │    ││ 추천 카드 (mini)
│  │  │ 점심 시간 방문 추천         │    ││
│  │  │ 신선 해산물 · 인기 맛집    │    ││
│  │  └─────────────────────────┘    ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │       좋은 여행 되세요! 👋       ││ Button_Primary
│  └─────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "AI 브리핑", leading: BackButton, actions: Plus+ 뱃지, style: AppBar_Standard |
| Plus+ 뱃지 | `Container` (pill) | backgroundColor: aiPlusBadge (#FFB800), text: "Plus+", labelSmall, #FFFFFF |
| 인사 텍스트 | `Text` | style: headlineMedium (24sp, SemiBold), 시간대별 변경 (아침/점심/저녁) |
| 날짜 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 브리핑 카드 뷰 | `PageView` | controller: PageController, pageCount: 4, height: 280dp |
| 페이지 인디케이터 | `SmoothPageIndicator` | activeColor: aiAccent (#7C4DFF), inactiveColor: outline, dotSize: 8 |
| 날씨 카드 | `Card` | style: Card_Standard, 날씨 아이콘 (64dp) + 온도 (displayLarge) + 상세 정보 grid |
| 날씨 팁 | `Row` | leading: 💡, text: bodySmall, color: semanticWarning |
| 안전지수 카드 | `Card` | style: Card_Standard |
| 안전지수 원형 | `CircularProgressIndicator` | determinate, value: score/100, size: 120dp, color: 점수 구간별 색상 |
| 안전지수 항목 | `Row` | leading: 라벨 (bodyMedium, onSurfaceVariant), trailing: 상태 텍스트 (bodyMedium, 상태별 색상) |
| 주의사항 카드 | `Card` | style: Card_Standard |
| 주의 항목 | `Card` (inner) | radius8, 좌측 보더 severity 색상, leading: severity 아이콘, title (bodyLarge), subtitle (bodySmall) |
| 추천 활동 카드 | `Card` | style: Card_Standard |
| 추천 항목 | `Card` (inner) | radius8, leading: 아이콘, title: 장소명 (bodyLarge), subtitle: 추천 사유 (bodySmall), chips: Chip_Tag |
| 완료 버튼 | `ElevatedButton` | style: Button_Primary, text: "좋은 여행 되세요!" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (로딩) | 카드 영역 ShimmerPlaceholder, "브리핑을 준비하고 있습니다..." 텍스트 |
| AI Plus+ 미구독 | 잠금 오버레이 + "Plus+ 구독으로 AI 브리핑을 받아보세요" + 블러, 탭 시 L-01 |
| 브리핑 준비 완료 | 4개 카드 스와이프 가능, 첫 카드 (날씨) 표시 |
| 푸시 진입 (07:00) | 앱 실행 → O-04 직행, 인사 텍스트 "좋은 아침이에요!" |
| 수동 진입 (낮) | 인사 텍스트 "오늘의 안전 브리핑", 동일 콘텐츠 |
| 수동 진입 (저녁) | 인사 텍스트 "오늘의 안전 요약", 활동 추천 → "내일 추천 활동" |
| 주의사항 없음 | 카드 3: "오늘은 특별한 주의사항이 없습니다. 안전한 하루 보내세요!" |
| 안전지수 — 양호 (70~100) | 원형 색상 semanticSuccess (#15A1A5), 라벨 "양호" |
| 안전지수 — 주의 (40~69) | 원형 색상 semanticWarning (#FFAC11), 라벨 "주의" |
| 안전지수 — 위험 (0~39) | 원형 색상 sosDanger (#D32F2F), 라벨 "위험" |
| 완료 탭 | 브리핑 읽음 처리, Navigator.pop → C-01 메인맵 |

**인터랙션**

- [자동] 매일 07:00 현지 시간 → 푸시 알림 "오늘의 SafeTrip 안전 브리핑이 도착했습니다"
- [탭] 푸시 알림 → 앱 실행 → O-04 AI 브리핑 화면 직행
- [스와이프 좌/우] 카드 영역 → 이전/다음 카드 전환 (300ms 슬라이드)
- [탭] 주의사항 항목 → Modal_Bottom (상세 설명 + 대처 방법)
- [탭] 추천 활동 항목 → Modal_Bottom (장소 상세: 사진, 운영시간, 접근 방법)
- [탭] 좋은 여행 되세요! → 브리핑 읽음 처리 → Navigator.pop → C-01 메인맵
- [뒤로가기] → C-01 메인맵 (브리핑 읽음 처리)

---

### O-05 AI 일정 최적화 (AI Itinerary)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | O-05 |
| 화면명 | AI 일정 최적화 (AI Itinerary) |
| Phase | P3 |
| 역할 | 캡틴, 크루장 (AI Pro 전용) |
| AI 계층 | Intelligence AI |
| 진입 경로 | D-02 일정탭 → AI 최적화 버튼 → O-05 |
| 이탈 경로 | O-05 → D-02 일정탭 (적용/취소) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] AI 일정 최적화      [Pro 뱃지]  │ AppBar_Standard
├─────────────────────────────────────┤
│                                     │
│  🤖 AI가 더 효율적인 동선을          │ bodyMedium, onSurfaceVariant
│     제안합니다                       │
│                                     │
│  ┌─────────────────────────────────┐│
│  │                                 ││
│  │     📍 A ─── ─ ─ ─ 📍 B        ││ GoogleMap
│  │      │              │          ││ 200dp height
│  │      │  ━━━━━━━━━━━ │          ││
│  │      │              │          ││
│  │     📍 C ━━━━━━━━━ 📍 D        ││
│  │                                 ││
│  │  ─ ─ 현재 경로 (gray)            ││ Legend
│  │  ━━━ 최적화 경로 (primaryTeal)   ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─ 절감 효과 ─────────────────────┐│
│  │  ⏱️ 45분 절약    📏 3.2km 단축   ││ Card_Standard
│  │  💰 ₩4,500 절약                 ││ 3-column, aiAccent 강조
│  └─────────────────────────────────┘│
│                                     │ spacing24
│  ── 현재 일정 vs 최적화 일정 ─────── │ Section Header
│                                     │
│  [현재 일정]       [최적화 일정]      │ Tab (2-tab)
│   ─────            ═══════          │ underline: gray vs aiAccent
│                                     │
│  ┌─────────────────────────────────┐│
│  │                                 ││ 최적화 일정 탭 (활성)
│  │  09:00  ┌─────────────────┐     ││
│  │    ○────│ 호텔 출발         │     ││ Timeline + ListTile_Schedule
│  │    │    └─────────────────┘     ││
│  │    │    🚇 지하철 20분           ││ 교통 연결 (bodySmall, aiAccent)
│  │    │                            ││
│  │  09:30  ┌─────────────────┐     ││
│  │    ●────│ 📍 츠키지 시장    │     ││ 변경됨 마커 (aiAccent 원)
│  │    │    │ ⏱️ 2시간         │     ││ 순서 변경 표시
│  │    │    │ [기존: 3번째]     │     ││ bodySmall, onSurfaceVariant
│  │    │    └─────────────────┘     ││
│  │    │    🚶 도보 10분             ││
│  │    │                            ││
│  │  11:40  ┌─────────────────┐     ││
│  │    ●────│ 📍 아사쿠사       │     ││ 변경됨 마커
│  │    │    │ ⏱️ 1.5시간       │     ││
│  │    │    │ [기존: 2번째]     │     ││
│  │    │    └─────────────────┘     ││
│  │    │                            ││
│  │  ≡ (드래그 핸들)                  ││ ReorderableListView
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌───────────────┐ ┌──────────────┐│
│  │    취소        │ │  적용        ││ Button_Secondary + Button_Primary
│  └───────────────┘ └──────────────┘│
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "AI 일정 최적화", leading: BackButton, actions: Pro 뱃지, style: AppBar_Standard |
| Pro 뱃지 | `Container` (pill) | backgroundColor: aiProBadge (#7C4DFF), text: "Pro", labelSmall, #FFFFFF |
| AI 안내 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, leading: 🤖 |
| 경로 비교 맵 | `GoogleMap` | height: 200dp, radius8 |
| 현재 경로 폴리라인 | `Polyline` | color: onSurfaceVariant (#8E8E93), width: 3, pattern: dashed |
| 최적화 경로 폴리라인 | `Polyline` | color: primaryTeal (#00A2BD), width: 4, pattern: solid |
| 경유지 마커 | `Marker` | 원형, 현재: gray (#8E8E93), 최적화: primaryTeal (#00A2BD) |
| 범례 | `Row` | 2개 항목: 점선+텍스트 (현재), 실선+텍스트 (최적화), bodySmall |
| 절감 효과 카드 | `Card` | style: Card_Standard, 3-column row, 각 항목: 아이콘 + 수치 (titleMedium, aiAccent) + 라벨 (bodySmall) |
| 일정 비교 탭 | `TabBar` | tabs: ["현재 일정", "최적화 일정"], indicatorColor: 현재=gray / 최적화=aiAccent (#7C4DFF) |
| 타임라인 | `Column` < `Row` > | 좌측: 시간 (bodySmall, primaryTeal) + 세로선 (2px, outline), 우측: 일정 카드 |
| 일정 항목 | `Card` (inline) | radius8, title: 장소명 (bodyLarge), subtitle: 소요시간 (bodySmall), 변경 표시: "[기존: N번째]" (bodySmall, onSurfaceVariant) |
| 변경됨 마커 | `Container` (circle) | 12dp, backgroundColor: aiAccent (#7C4DFF) |
| 미변경 마커 | `Container` (circle) | 12dp, border: outline (#EDEDED), backgroundColor: surface |
| 교통 연결 | `Row` | leading: 교통 아이콘, text: "🚇 지하철 20분" (bodySmall, aiAccent) |
| 드래그 핸들 | `Icon` (drag_handle) | color: onSurfaceVariant, ReorderableListView 연동 |
| 취소 버튼 | `OutlinedButton` | style: Button_Secondary, text: "취소", flex: 1 |
| 적용 버튼 | `ElevatedButton` | style: Button_Primary, text: "적용", flex: 1 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (로딩) | 맵 + 리스트 ShimmerPlaceholder, "AI가 최적 경로를 계산 중입니다..." (3~5초) |
| AI Pro 미구독 | 잠금 오버레이 + "Pro 구독으로 AI 일정 최적화를 사용하세요" + 블러, 탭 시 L-01 |
| 최적화 완료 | 맵에 두 경로 폴리라인 표시, 절감 효과 카드 표시, 최적화 일정 탭 활성 |
| 현재 일정 탭 선택 | 기존 일정 순서 표시 (회색 마커, 점선 경로), 드래그 핸들 비표시 |
| 최적화 일정 탭 선택 | 변경된 순서 표시 (aiAccent 마커), 변경 항목 "[기존: N번째]" 표시, 드래그 핸들 표시 |
| 수동 드래그 재정렬 | 드래그 중 항목 elevation 증가 + 그림자, 드롭 시 맵 경로 + 절감 효과 실시간 갱신 |
| 적용 중 | 적용 버튼 → CircularProgressIndicator |
| 적용 완료 | PUT /api/v1/ai/itinerary/apply → Toast "일정이 최적화되었습니다" → Navigator.pop → D-02 일정탭 |
| 적용 취소 | Navigator.pop → D-02 일정탭 (변경 없음) |
| 최적화 불가 (일정 2개 미만) | "최적화할 일정이 충분하지 않습니다" 안내 + Button_Secondary "돌아가기" |
| 캡틴/크루장 외 접근 | "일정 최적화는 캡틴 또는 크루장만 사용할 수 있습니다" 안내 |

**인터랙션**

- [탭] 현재 일정 탭 → 기존 일정 순서 표시, 맵에 gray 점선 경로만 강조
- [탭] 최적화 일정 탭 → AI 제안 순서 표시, 맵에 primaryTeal 실선 경로 강조
- [드래그] 일정 항목 드래그 핸들 → ReorderableListView로 수동 순서 변경 → 맵 경로 + 절감 효과 실시간 갱신
- [탭] 적용 → PUT /api/v1/ai/itinerary/apply { schedule_order: [...] } → D-02 일정탭에 반영
- [탭] 취소 → Navigator.pop → D-02 일정탭 (변경 없음)
- [탭] 맵 마커 → 해당 일정 항목으로 리스트 자동 스크롤
- [핀치 줌] 맵 영역 → 지도 줌인/줌아웃
- [뒤로가기] → Dialog_Confirm "최적화를 적용하지 않고 나가시겠습니까?" (확인 → D-02 / 취소 → 유지)

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 5개 화면 (O-01 ~ O-05) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
