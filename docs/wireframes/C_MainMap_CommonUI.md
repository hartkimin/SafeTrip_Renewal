# C. 메인 맵 & 공통 UI

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 메인 맵 화면과 공통 UI 컴포넌트 12개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 지도 기본화면 고유 원칙 | `Master_docs/17_T3_지도_기본화면_고유_원칙.md` |
| 화면 구성 원칙 | `Master_docs/10_T2_화면구성원칙.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 12개 (C-01 ~ C-12)
- **Phase:** P0 10개, P1 2개 (C-10, C-12)
- **핵심 역할:** 전체 (크루/가디언 각각 다른 UI)
- **연관 문서:** `Master_docs/17_T3_지도_기본화면_고유_원칙.md`

---

## User Journey Flow

```
C-01 메인 맵 (크루)
 ├── [지도 마커 탭] ────────────────→ C-11 마커 상세 팝업
 ├── [여행정보카드 탭] ──────────────→ C-06 여행 전환 모달
 ├── [알림 아이콘 탭] ───────────────→ C-07 알림 목록
 ├── [설정 아이콘 탭] ───────────────→ K-01 설정 메인
 ├── [SOS 롱프레스] ─────────────────→ G-01 SOS 발동
 ├── [바텀시트 탭 전환] ─────────────→ D-01 일정탭 / D-09 멤버탭 / I-01 채팅탭 / J-01 가이드탭
 └── [맵 컨트롤] ────────────────────→ C-12 맵 컨트롤

C-02 가디언 맵 모드
 ├── [마커 탭] ──────────────────────→ C-11 마커 상세 팝업
 ├── [여행정보카드 탭] ──────────────→ C-06 여행 전환 모달
 ├── [알림 아이콘 탭] ───────────────→ C-07 알림 목록
 └── [바텀시트 탭 전환] ─────────────→ F-05 내 멤버탭 / D-01 일정탭 / J-01 가이드탭

C-08 권한 요청
 └── [모든 권한 완료] ───────────────→ C-01 메인 맵

C-09 데모 모드
 └── [가입하기 탭] ──────────────────→ A-02 웰컴 온보딩
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| A-01 | 토큰 유효 (크루) | C-01 메인맵 | A → C |
| A-06 | 크루 프로필 완료 | C-01 메인맵 | A → C |
| B-02 | 여행 생성 완료 | C-01 메인맵 | B → C |
| B-07 | 여행 참여 완료 | C-01 메인맵 | B → C |
| C-01 | 설정 아이콘 탭 | K-01 설정 메인 | C → K |
| C-01 | SOS 롱프레스 | G-01 SOS 발동 | C → G |
| C-01 | 바텀시트 탭 전환 | D/I/J 화면 | C → D/I/J |
| C-07 | SOS 알림 탭 | G-02 SOS 수신 | C → G |
| C-08 | 권한 완료 | C-01 메인맵 | C 내부 |
| C-09 | 가입하기 | A-02 웰컴 온보딩 | C → A |

---

## 메인 맵 레이어 구조도

C-01 메인 맵은 앱 전체의 허브 화면이다. 4개의 독립 레이어로 구성되며, z-index 순서대로 렌더링된다.

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  [Layer 4] SOS FAB                              │  ← z-index 최상위
│  우하단 고정, 바텀시트 위에 플로팅                  │
│  56x56dp, sosDanger #D32F2F, 항상 표시            │
│                                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  [Layer 3] 상단 오버레이 (C-03)                   │  ← AppBar_Map
│  transparent 배경, 지도 위에 떠 있음               │
│  여행정보카드 | D±N | 프라이버시 아이콘 | ⚙️ | 🔔   │
│                                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  [Layer 2] 지도 영역                              │  ← Google Maps SDK
│  Google Maps + 멤버 마커 (역할별 색상)              │
│  + 지오펜스 오버레이 (반투명 원형)                  │
│  + 클러스터링 (줌 레벨별)                          │
│  + 내 위치 펄스 애니메이션                         │
│                                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  [Layer 1] 바텀시트 (C-04/C-05)                   │  ← DraggableScrollableSheet
│  5단계 스냅: peek(6%) / collapsed(18%)             │
│            / half(35%) / tall(55%) / expanded(75%)│
│  상단 radius20, 핸들바 4x44px                     │
│  크루: 4탭 (일정/멤버/채팅/가이드) + SOS FAB       │
│  가디언: 3탭 (내멤버/일정/가이드)                  │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 7단계 지도 레이어 시스템 (상세)

> 출처: `Master_docs/17_T3_지도_기본화면_고유_원칙.md` SS3

| 레이어 | 이름 | 내용 | 토글 | Phase |
|:------:|------|------|:----:|:-----:|
| Layer 6 | 긴급 오버레이 | SOS 발동 시 전체화면 빨간 오버레이 | 강제 | P0 |
| Layer 5 | UI 컨트롤 | SOS 버튼, 여행정보카드, 알림 아이콘 | 항상 | P0 |
| Layer 4 | 이벤트/알림 마커 | 지오펜스 경보, 출석 체크 위치 마커 | ON/OFF | P1 |
| Layer 3 | 일정/장소 마커 | 여행 일정 장소 핀, 경로 라인 | ON/OFF | P1 |
| Layer 2 | 멤버 위치 마커 | 역할별 색상 마커, 클러스터링 | ON/OFF | P0 |
| Layer 1 | 안전시설 오버레이 | 병원, 경찰서, 대사관 핀 | ON/OFF | P1 |
| Layer 0 | 지도 타일 | Google Maps SDK / 오프라인 캐시 | 항상 | P0 |

---

## 화면 상세

---

### C-01 메인 맵 (Main Map View)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-01 |
| 화면명 | 메인 맵 (Main Map View) |
| Phase | P0 |
| 역할 | 캡틴, 크루장, 크루 |
| 진입 경로 | A-01 스플래시 (토큰 유효) / A-06 프로필 완료 / B-02 여행 생성 완료 → C-01 |
| 이탈 경로 | C-01 → K-01 (설정) / C-07 (알림) / G-01 (SOS) / C-06 (여행 전환) / D/I/J (탭 컨텐츠) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [🔔 2]  도쿄 자유여행  D+3  📍 [⚙️] │ C-03 AppBar_Map (transparent overlay)
│         5명 참여 중                  │ 프라이버시 아이콘: 캡틴/크루장만 표시
├─────────────────────────────────────┤
│                                     │
│         ⭐ 김철수 (캡틴)              │ 마커: 황금색 #FFD700, 별 아이콘
│                                     │
│    🔷 이준호 (크루장)                 │ 마커: 주황색 #FF8C00, 다이아몬드
│                                     │
│         ● 박지수 (크루)              │ 마커: 파란색 #2196F3, 원형
│    ● 최유나 (크루)                   │
│                                     │
│     ╔═══════════╗                   │ 지오펜스: 반투명 teal 원형 오버레이
│     ║  호텔 주변  ║                   │ 반경 표시, 라벨
│     ╚═══════════╝                   │
│                                     │
│              ◉ 내 위치               │ 내 위치: 초록색 #4CAF50, 펄스 애니메이션
│                                     │
│                             [+]     │ C-12 맵 컨트롤 (P1)
│                             [-]     │
│                             [📍]    │
│                             [👥]    │
├─────────────────────── radius20 ────┤
│          ━━━━━━━━━━━                │ 핸들바: 4px x 44px, line04
│  ┌─📅일정─┬─👥멤버─┬─💬채팅─┬─📖가이드─┐│ NavBar_Crew: 4탭
│  │        │        │        │        ││ 활성탭: primaryTeal #00A2BD
│  │  탭 컨텐츠 (바텀시트 내부)         ││ 비활성탭: onSurfaceVariant #8E8E93
│  │                                  ││
│  └──────────────────────────────────┘│
│                              [SOS]  │ Button_SOS: 56x56dp, sosDanger #D32F2F
└─────────────────────────────────────┘  우하단 고정, 바텀시트 탭바 위
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 전체 레이아웃 | `Stack` | children: [GoogleMap, BottomSheet, AppBar_Map, SOS FAB] |
| 지도 | `GoogleMap` | initialCameraPosition: 내 위치 (줌 15), myLocationEnabled: true, markers: Set<Marker>, polygons: Set<Polygon> |
| 상단바 | `Stack` + `Positioned` | style: AppBar_Map (transparent), top: SafeArea.top, 상세: C-03 참조 |
| 여행정보카드 | `GestureDetector` + `Container` | radius8, shadow, 탭 시 C-06 여행 전환 모달 |
| 멤버 마커 | `Marker` + `BitmapDescriptor` | 역할별 색상 (캡틴 #FFD700, 크루장 #FF8C00, 크루 #2196F3), 최소 터치 44dp |
| 내 위치 마커 | `Marker` | color: #4CAF50 (초록), 펄스 애니메이션, 위치 정확도 원 표시 |
| 지오펜스 오버레이 | `Circle` / `Polygon` | strokeColor: primaryTeal (opacity 0.6), fillColor: primaryTeal (opacity 0.1), 라벨 표시 |
| 바텀시트 | `DraggableScrollableSheet` | style: BottomSheet_Snap, 5단계 스냅 포인트, 상세: 글로벌 스타일 가이드 SS6 참조 |
| 탭 바 | `BottomNavigationBar` | style: NavBar_Crew, 4탭, 활성: primaryTeal #00A2BD, 상세: C-04 참조 |
| SOS 버튼 | `FloatingActionButton` | style: Button_SOS, 56x56dp, sosDanger #D32F2F, 2초 롱프레스 활성화 |
| 맵 컨트롤 | `Column` < `FloatingActionButton.small` > | 우측 배치, 상세: C-12 참조 (P1) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| `active` 여행 | 실시간 멤버 마커 표시, SOS 버튼 활성, D+N 경과일 표시, 4탭 전체 활성 |
| `planning` 여행 | 멤버 마커 미표시, SOS 버튼 미표시, D-N 남은일 표시, 일정 편집 가능 |
| `completed` 여행 | 마지막 스냅샷 마커 표시, SOS 미표시, "종료된 여행" 뱃지, 전체 열람 전용 |
| `none` (여행 없음) | 지도 배경만 표시, "+ 새 여행 만들기" 버튼 중앙, 탭바 비활성화 (회색), 온보딩 안내 배너 |
| SOS 발동 중 | Layer 6 긴급 오버레이 활성, 바텀시트 강제 `collapsed`, 발신자 위치 카메라 이동 (줌 16) |
| 오프라인 | 오렌지 배너 "오프라인 상태", 캐시 타일 표시, 멤버 마커 "마지막 알려진 위치" 표시 |
| 위치 권한 없음 | 내 위치 마커 미표시, 권한 요청 다이얼로그 → 거부 시 설정 이동 안내 |
| 멤버 오프라인 | 해당 마커 회색 처리 + "오프라인" 배지 + 마지막 업데이트 시각 표시 |

**인터랙션**

- [탭] 여행정보카드 → C-06 여행 전환 모달 열림
- [탭] 알림 아이콘 (🔔) → Navigator.push → C-07 알림 목록
- [탭] 설정 아이콘 (⚙️) → Navigator.push → K-01 설정 메인
- [탭] 멤버 마커 → C-11 마커 상세 팝업 (이름, 역할, 마지막 위치 시간)
- [탭] 지오펜스 영역 → 지오펜스 정보 팝업 (캡틴/크루장: 편집 버튼 포함)
- [탭] 빈 영역 → 열려 있는 팝업/미니 카드 모두 닫기
- [롱프레스 2초] SOS 버튼 → 2초 프로그레스 링 → G-01 SOS 발동 화면
- [드래그 상하] 바텀시트 → 5단계 스냅 포인트 간 전환
- [탭] 바텀시트 탭 → 해당 탭 컨텐츠 표시 (바텀시트 높이/스크롤 위치 유지)
- [자동] 앱 복귀 (백그라운드 → 포어그라운드) → 내 위치로 카메라 복귀
- [자동] SOS 수신 → 발신자 위치로 카메라 이동, Layer 6 활성화

> **터치 인터랙션 우선순위:** SOS 버튼 > 멤버 마커 > 이벤트 마커 > 일정 마커 > 지오펜스 영역 > 빈 영역

---

### C-02 가디언 맵 모드 (Guardian Map Mode)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-02 |
| 화면명 | 가디언 맵 모드 (Guardian Map Mode) |
| Phase | P0 |
| 역할 | 가디언 |
| 진입 경로 | A-06 가디언 프로필 완료 → C-02 / 여행 전환 → C-02 |
| 이탈 경로 | C-02 → C-07 (알림) / K-01 (설정) / C-06 (여행 전환) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [🔔 1]  도쿄 자유여행       [⚙️]    │ AppBar_Map (transparent)
│         2명 연결 중                  │ 프라이버시 아이콘 미표시
├─────────────────────────────────────┤
│                                     │
│    🟢 김민지                         │ 연결 멤버 마커: 보라색 #9C27B0
│         "3분 전"                    │ 방패 아이콘 + 마지막 업데이트 시각
│                                     │
│              🟢 이준호               │ 연결 멤버만 표시
│                   "1분 전"          │ 비연결 멤버는 미표시
│                                     │
│                                     │
│                                     │
│                                     │ SOS 버튼 없음
│                                     │ 지오펜스 미표시
│                             [📍]    │ 내 위치 버튼만 표시
│                             [👥]    │ 전체 보기 (연결 멤버 바운딩 박스)
├─────────────────────── radius20 ────┤
│          ━━━━━━━━━━━                │ 핸들바
│  ┌─👥내 멤버─┬─📅일정──┬─📖안전가이드─┐│ NavBar_Guardian: 3탭
│  │          │         │            ││ 활성탭: #15A1A5 (guardian green)
│  │  탭 컨텐츠 (바텀시트 내부)        ││ 비활성탭: #8E8E93
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │ SOS FAB 없음
└─────────────────────────────────────┘
```

**C-01 크루 맵 vs C-02 가디언 맵 비교 테이블**

| 항목 | C-01 크루 맵 | C-02 가디언 맵 |
|------|:-----------:|:------------:|
| 멤버 마커 범위 | 전체 멤버 | 연결 멤버만 |
| 마커 색상 | 역할별 (캡틴 #FFD700, 크루장 #FF8C00, 크루 #2196F3) | 보라색 #9C27B0 (방패) |
| 지오펜스 표시 | ✅ | ❌ |
| SOS 버튼 | ✅ (56dp, sosDanger) | ❌ |
| 바텀시트 탭 수 | 4탭 (일정/멤버/채팅/가이드) | 3탭 (내멤버/일정/가이드) |
| 채팅탭 | ✅ | ❌ |
| 활성 탭 색상 | primaryTeal #00A2BD | guardian #15A1A5 |
| 프라이버시 아이콘 | 캡틴/크루장만 표시 | ❌ |
| 카메라 기본 위치 | 내 현재 위치 (줌 15) | 연결 멤버 바운딩 박스 자동 피트 |
| 일정 편집 | 캡틴/크루장 가능 | 열람 전용 |
| 멤버 관리 | 역할별 가능 | 연결 멤버 열람만 |
| D+N 표시 | ✅ (active 시) | ✅ (active 시) |

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 전체 레이아웃 | `Stack` | C-01과 동일 구조, SOS FAB 제외 |
| 지도 | `GoogleMap` | markers: 연결 멤버만, polygons: 빈 Set (지오펜스 미표시) |
| 상단바 | `Stack` + `Positioned` | style: AppBar_Map, 프라이버시 아이콘 미포함 |
| 연결 멤버 마커 | `Marker` + `BitmapDescriptor` | color: #9C27B0 (보라), 방패 아이콘, 마지막 업데이트 시각 라벨 |
| 바텀시트 | `DraggableScrollableSheet` | style: BottomSheet_Snap, 5단계 스냅 포인트 |
| 탭 바 | `BottomNavigationBar` | style: NavBar_Guardian, 3탭, 활성: #15A1A5 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 연결 멤버 1명 | 해당 멤버 위치 중심, 줌 레벨 15 |
| 연결 멤버 2명 이상 | 전체 멤버 바운딩 박스 자동 피트 |
| 연결 멤버 위치 미확인 | 여행 목적지 기준 중심 이동, "위치 확인 중" 표시 |
| 연결 멤버 전원 탈퇴 | "연결된 멤버가 없습니다" 안내 화면 |
| 프라이버시 우선 + 스케줄 OFF | 연결 멤버 마커 미표시, "비공유 시간" 안내 |
| 표준 + 스케줄 OFF | 연결 멤버 마커 반투명 (30분 스냅샷) |
| 안전최우선 | 연결 멤버 항상 실시간 표시 |
| 오프라인 | 마지막 캐시된 멤버 위치 + "오프라인" 배너 |

**인터랙션**

- [탭] 여행정보카드 → C-06 여행 전환 모달
- [탭] 알림 아이콘 (🔔) → Navigator.push → C-07 알림 목록
- [탭] 설정 아이콘 (⚙️) → Navigator.push → K-01 설정 메인
- [탭] 연결 멤버 마커 → C-11 마커 상세 팝업
- [드래그 상하] 바텀시트 → 5단계 스냅 포인트 간 전환
- [탭] 바텀시트 탭 → 해당 탭 컨텐츠 표시

---

### C-03 맵 상단바 (Map Top Bar)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-03 |
| 화면명 | 맵 상단바 (Map Top Bar) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | C-01/C-02의 하위 컴포넌트 (항상 표시) |
| 이탈 경로 | 여행정보카드 탭 → C-06 / 알림 탭 → C-07 / 설정 탭 → K-01 |

**레이아웃**

```
┌─────────────────────────────────────────────┐
│                                             │ Safe Area 상단 47dp
├─────────────────────────────────────────────┤
│ [🔔 2]                              [⚙️]   │ 높이 56dp, transparent 배경
│                                             │
│  ┌───────────────────────────┐              │
│  │ 🇯🇵 도쿄 자유여행           │              │ 여행정보카드: radius8, shadow
│  │    D+3  │  5명  │ 📍 표준  │              │ 탭 가능 (→ C-06)
│  └───────────────────────────┘              │
│                                             │
└─────────────────────────────────────────────┘
  (지도 배경 위에 투명 오버레이)
```

> **Variant 1 (캡틴/크루장 뷰):** 프라이버시 등급 아이콘 (📍/🛡️/🔒) + 위치 공유 모드 표시
> **Variant 2 (크루 뷰):** 프라이버시 아이콘 미표시, 위치 공유 모드 미표시
> **Variant 3 (가디언 뷰):** 프라이버시 아이콘 미표시, 연결 멤버 수 표시

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 상단바 컨테이너 | `Stack` + `Positioned` | top: 0, width: 전체, backgroundColor: transparent |
| 알림 아이콘 | `IconButton` | icon: Icons.notifications, color: onSurface #1A1A1A, shadow 적용 (지도 위 가독성) |
| 알림 뱃지 | `Badge` | count: 미읽은 알림 수, backgroundColor: primaryCoral #FF807B, max: 99+ |
| 여행정보카드 | `GestureDetector` + `Container` | radius8, backgroundColor: surface #FFFFFF (opacity 0.95), shadow: black 8% |
| 여행명 | `Text` | style: titleMedium (18sp, SemiBold 600), color: onSurface, maxLines: 1, overflow: ellipsis |
| D+N / D-N 뱃지 | `Container` (pill) | backgroundColor: primaryTeal #00A2BD, text: #FFFFFF, style: labelSmall (11sp) |
| 멤버 수 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 프라이버시 아이콘 | `Icon` + `Text` | 등급별: 🛡️ #DA4C51 / 📍 #00A2BD / 🔒 #A7A7A7, 캡틴/크루장에게만 Visibility |
| 설정 아이콘 | `IconButton` | icon: Icons.settings, color: onSurface #1A1A1A, shadow 적용 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| `active` 여행 | D+N 경과일 뱃지 (teal), 멤버 수 표시 |
| `planning` 여행 | D-N 남은일 뱃지 (amber), "시작 전" 라벨 |
| `completed` 여행 | "종료된 여행" 회색 뱃지, 재활성화 버튼 (24h 이내 + 캡틴) |
| `none` (여행 없음) | 여행정보카드 대신 "+ 새 여행 만들기" CTA 표시 |
| 미읽은 알림 존재 | 알림 아이콘에 빨간 점(dot) 뱃지 + 숫자 |
| 알림 0건 | 알림 아이콘만 표시 (뱃지 없음) |
| 캡틴/크루장 | 프라이버시 등급 아이콘 + 위치 공유 모드 표시 |
| 크루/가디언 | 프라이버시 아이콘 미표시 |

**인터랙션**

- [탭] 여행정보카드 → C-06 여행 전환 모달 (Modal_Bottom)
- [탭] 알림 아이콘 → Navigator.push → C-07 알림 목록
- [탭] 설정 아이콘 → Navigator.push → K-01 설정 메인
- [탭] 프라이버시 아이콘 (캡틴만) → 프라이버시 등급 변경 바텀시트

---

### C-04 크루 네비바 + SOS (Crew Nav + SOS)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-04 |
| 화면명 | 크루 네비바 + SOS (Crew Nav + SOS) |
| Phase | P0 |
| 역할 | 캡틴, 크루장, 크루 |
| 진입 경로 | C-01의 하위 컴포넌트 (바텀시트 하단 탭 바) |
| 이탈 경로 | 탭 전환 → 해당 탭 컨텐츠 / SOS 롱프레스 → G-01 |

**레이아웃**

```
┌─────────────────────────────────────────────┐
│          ━━━━━━━━━━━                        │ 핸들바: 4x44px, line04
├─────────────────────────────────────────────┤
│                                             │
│  ┌────────┬────────┬────────┬────────┐      │ BottomNavigationBar, 높이 60dp
│  │  📅    │  👥    │  💬    │  📖    │      │ 4탭 균등 배치
│  │  일정   │  멤버   │  채팅   │  가이드 │      │
│  │        │  🔴    │   3    │        │      │ 뱃지: 출석(빨간 점), 채팅(숫자)
│  └────────┴────────┴────────┴────────┘      │
│                                      ┌────┐ │
│                                      │SOS │ │ Button_SOS: 56x56dp
│                                      │    │ │ sosDanger #D32F2F
│                                      └────┘ │ 탭 바 위, 우하단
└─────────────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 네비게이션 바 | `BottomNavigationBar` | style: NavBar_Crew, 높이 60dp, 상단 보더 outline #EDEDED |
| 일정 탭 | `BottomNavigationBarItem` | icon: Icons.calendar_today, label: "일정", activeColor: primaryTeal #00A2BD |
| 멤버 탭 | `BottomNavigationBarItem` | icon: Icons.people, label: "멤버", badge: 출석 대기 시 빨간 점 |
| 채팅 탭 | `BottomNavigationBarItem` | icon: Icons.chat_bubble, label: "채팅", badge: 미읽음 수 (primaryCoral #FF807B) |
| 가이드 탭 | `BottomNavigationBarItem` | icon: Icons.shield, label: "가이드" |
| 비활성 탭 | — | color: onSurfaceVariant #8E8E93, style: labelMedium (14sp, Medium 500) |
| 활성 탭 | — | color: primaryTeal #00A2BD, style: labelMedium (14sp, Medium 500) |
| SOS 버튼 | `FloatingActionButton` | style: Button_SOS, 56x56dp, backgroundColor: sosDanger #D32F2F, "SOS" white Bold, elevation: 4dp |
| 핸들바 | `Container` | width: 44, height: 4, color: line04, borderRadius: radius48, 중앙 정렬 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 기본 | 일정 탭 활성 (teal), 나머지 비활성 (gray) |
| 출석 체크 대기 | 멤버 탭에 빨간 점 뱃지 |
| 미읽은 채팅 | 채팅 탭에 숫자 뱃지 (primaryCoral 배경, max 99+) |
| SOS idle | SOS 버튼 기본 상태 (빨간 원 + "SOS" 흰색) |
| SOS pressing | 2초 프로그레스 링 애니메이션 (원형, 흰색) |
| SOS triggered | 전체화면 SOS 오버레이 전환 (G-01) |
| `planning` / `completed` | SOS 버튼 미표시 |
| `none` | 전체 탭 비활성화 (회색 처리, 전환 불가) |

**인터랙션**

- [탭] 각 탭 아이콘 → 해당 탭 컨텐츠로 바텀시트 전환 (높이/스크롤 유지)
- [롱프레스 2초] SOS 버튼 → 프로그레스 링 → G-01 SOS 발동
- [드래그] 핸들바 → 바텀시트 5단계 스냅 전환

---

### C-05 가디언 네비바 (Guardian Nav)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-05 |
| 화면명 | 가디언 네비바 (Guardian Nav) |
| Phase | P0 |
| 역할 | 가디언 |
| 진입 경로 | C-02의 하위 컴포넌트 (바텀시트 하단 탭 바) |
| 이탈 경로 | 탭 전환 → 해당 탭 컨텐츠 |

**레이아웃**

```
┌─────────────────────────────────────────────┐
│          ━━━━━━━━━━━                        │ 핸들바: 4x44px, line04
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┬──────────┬──────────┐         │ BottomNavigationBar, 높이 60dp
│  │  👥      │  📅      │  📖      │         │ 3탭 균등 배치
│  │  내 멤버  │  일정     │  안전가이드│         │ SOS 버튼 없음
│  │          │          │          │         │ 채팅 탭 없음
│  └──────────┴──────────┴──────────┘         │
│                                             │ (SOS 버튼 없음)
└─────────────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 네비게이션 바 | `BottomNavigationBar` | style: NavBar_Guardian, 높이 60dp, 상단 보더 outline #EDEDED |
| 내 멤버 탭 | `BottomNavigationBarItem` | icon: Icons.people, label: "내 멤버", activeColor: #15A1A5 |
| 일정 탭 | `BottomNavigationBarItem` | icon: Icons.calendar_today, label: "일정", activeColor: #15A1A5 |
| 안전가이드 탭 | `BottomNavigationBarItem` | icon: Icons.shield, label: "안전가이드", activeColor: #15A1A5 |
| 비활성 탭 | — | color: onSurfaceVariant #8E8E93, style: labelMedium (14sp, Medium 500) |
| 활성 탭 | — | color: guardian #15A1A5 (Soft Green), style: labelMedium (14sp, Medium 500) |
| 핸들바 | `Container` | width: 44, height: 4, color: line04, borderRadius: radius48, 중앙 정렬 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 기본 | 내 멤버 탭 활성 (#15A1A5), 나머지 비활성 (gray) |
| 연결 멤버 0명 | 내 멤버 탭 컨텐츠: "연결된 멤버가 없습니다" 안내 |
| 탭 전환 | 바텀시트 높이/스크롤 유지, 탭 컨텐츠 전환 |

**인터랙션**

- [탭] 각 탭 아이콘 → 해당 탭 컨텐츠로 바텀시트 전환
- [드래그] 핸들바 → 바텀시트 5단계 스냅 전환
- SOS 버튼 없음 (가디언은 SOS 발송 불가, 가디언 전용 안전 화면에서 긴급 알림 발송)

> **C-04 크루 네비바 vs C-05 가디언 네비바 핵심 차이:**
> - 탭 수: 4탭 vs 3탭 (채팅 탭 없음)
> - SOS 버튼: 있음 vs 없음
> - 활성 색상: primaryTeal #00A2BD vs guardian #15A1A5

---

### C-06 여행 전환 모달 (Trip Switch Modal)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-06 |
| 화면명 | 여행 전환 모달 (Trip Switch Modal) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | C-01/C-02 여행정보카드 탭 → C-06 |
| 이탈 경로 | C-06 → C-01/C-02 (여행 선택 시 해당 여행으로 전환) |

**레이아웃**

```
┌─────────────────────────────────────┐
│                                     │ 스크림: black 40% opacity
│                                     │
│                                     │
├─────────────────────── radius20 ────┤
│          ━━━━━━━━━━━                │ 핸들바
│                                     │
│  내 여행                       ✕    │ headlineMedium (24sp), 닫기 버튼
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 🇯🇵 도쿄 자유여행                ││ Card_Selectable (선택됨)
│  │ ├─ teal │  2026.03.15 ~ 03.22  ││ 좌측 보더: primaryTeal
│  │ 보더   │  D+3                  ││ ✓ 체크마크 (우측)
│  │        │  ┌────────┐           ││
│  │        │  │ 진행 중  │           ││ Chip_Tag: semanticSuccess #15A1A5
│  │        │  └────────┘           ││
│  └─────────────────────────────────┘│
│                                     │ spacing12
│  ┌─────────────────────────────────┐│
│  │ 🇹🇭 방콕 팀 워크숍                ││ Card_Selectable (미선택)
│  │    2026.04.01 ~ 04.05          ││ 좌측 보더 없음
│  │    D-29                        ││
│  │    ┌────────┐                  ││
│  │    │ 계획 중  │                  ││ Chip_Tag: secondaryAmber #FFC363
│  │    └────────┘                  ││
│  └─────────────────────────────────┘│
│                                     │ spacing12
│  ┌─────────────────────────────────┐│
│  │ 🇻🇳 다낭 가족여행                 ││ Card_Selectable (미선택)
│  │    2026.02.10 ~ 02.15          ││ opacity 0.7 (완료 상태)
│  │    ┌────────┐                  ││
│  │    │  완료   │                  ││ Chip_Tag: gray #F9F9F9
│  │    └────────┘                  ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │     + 새 여행 만들기              ││ Button_Secondary
│  └─────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 모달 | `showModalBottomSheet` | style: Modal_Bottom, radius20, 스크림 black 40% |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), text: "내 여행" |
| 닫기 버튼 | `IconButton` | icon: Icons.close, color: onSurfaceVariant |
| 여행 카드 (활성) | `Card` + `InkWell` | style: Card_Selectable, 좌측 보더 primaryTeal, trailing: 체크마크 아이콘 |
| 여행 카드 (일반) | `Card` + `InkWell` | style: Card_Selectable, 좌측 보더 없음 |
| 국기 아이콘 | `Text` | 이모지 국기, 크기 24sp |
| 여행명 | `Text` | style: titleMedium (18sp, SemiBold) |
| 여행 기간 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| D+N / D-N 뱃지 | `Container` (pill) | style: Badge_Role 참조, 크기/색상 여행 상태별 |
| 상태 칩 | `Chip` | style: Chip_Tag, 진행 중: #15A1A5 / 계획 중: #FFC363 / 완료: #F9F9F9 |
| 새 여행 버튼 | `OutlinedButton` | style: Button_Secondary, text: "+ 새 여행 만들기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 여행 1개 | 해당 여행 카드만 표시, 체크마크 표시 |
| 여행 다수 | 스크롤 가능 리스트, 현재 선택된 여행에 체크마크 + teal 보더 |
| 여행 0개 | "참여 중인 여행이 없습니다" 안내 + "새 여행 만들기" 버튼만 표시 |
| completed 여행 | opacity 0.7 감소, 완료 칩 (gray) |
| 여행 전환 중 | 로딩 인디케이터 (teal CircularProgressIndicator) |

**인터랙션**

- [탭] 여행 카드 → 해당 여행으로 전환 (C-01/C-02 리로드), 모달 닫힘
- [탭] 새 여행 만들기 → Navigator.push → B-01 여행 생성
- [탭] 닫기 (✕) → 모달 닫힘
- [하단 스와이프] → 모달 닫힘 (300ms 슬라이드 아웃)

---

### C-07 알림 목록 (Notifications)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-07 |
| 화면명 | 알림 목록 (Notifications) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | C-01/C-02 알림 아이콘 탭 → C-07 |
| 이탈 경로 | C-07 → C-01/C-02 (뒤로가기) / SOS 알림 탭 → G-02 / 출석 알림 탭 → H-01 |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 알림                  모두 읽음  │ AppBar_Standard
├─────────────────────────────────────┤
│                                     │
│  오늘                                │ bodySmall, onSurfaceVariant, 섹션 헤더
│  ─────────────────────────────────── │
│  ┌─────────────────────────────────┐│
│  │ 🆘│ 김민지님이 SOS를 발송했습니다  ││ ListTile_Notification
│  │   │ 서울 강남구 역삼동            ││ unread: bold + 배경 #F9F9F9
│  │   │                    2분 전  🔵││ 좌측 보더: semanticError #DA4C51
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ✅│ 출석 체크가 시작되었습니다     ││ ListTile_Notification
│  │   │ 마감: 15:00까지              ││ unread
│  │   │                   35분 전 🔵││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ 📍│ 이준호님이 호텔 지오펜스를     ││ ListTile_Notification
│  │   │ 벗어났습니다                  ││ read: 일반 텍스트
│  │   │                   1시간 전  ││
│  └─────────────────────────────────┘│
│                                     │
│  어제                                │ 섹션 헤더
│  ─────────────────────────────────── │
│  ┌─────────────────────────────────┐│
│  │ 🛡️│ 새로운 가디언 연결 요청이     ││ ListTile_Notification
│  │   │ 있습니다                     ││ read
│  │   │                 어제 18:30  ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ 💬│ 그룹 채팅에 새 메시지 3건     ││ ListTile_Notification
│  │   │                 어제 14:22  ││ read
│  └─────────────────────────────────┘│
│                                     │
│  이전                                │ 섹션 헤더
│  ─────────────────────────────────── │
│  │ ...                             ││
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "알림", leading: BackButton, actions: "모두 읽음" TextButton (primaryTeal), style: AppBar_Standard |
| 섹션 헤더 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, padding: spacing20 좌 |
| 알림 아이템 | `ListTile` | style: ListTile_Notification, 높이 80dp |
| 유형 아이콘 (leading) | `Container` + `Icon` | 32dp 원형, 유형별 아이콘/색상 (아래 표) |
| 알림 제목 (title) | `Text` | style: bodyLarge (16sp), unread: FontWeight.w600, read: FontWeight.w400 |
| 알림 내용+시간 (subtitle) | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 미읽음 인디케이터 | `Container` | 8dp 원형, color: primaryTeal #00A2BD |
| 구분선 | `Divider` | color: outlineVariant #F5F5F5, height: 1 |

**알림 유형별 아이콘**

| 유형 | 아이콘 | 색상 | 좌측 보더 |
|------|:------:|------|:--------:|
| SOS | 🆘 | sosDanger #D32F2F | semanticError #DA4C51 |
| 출석 | ✅ | semanticSuccess #15A1A5 | 없음 |
| 지오펜스 | 📍 | primaryTeal #00A2BD | 없음 |
| 가디언 | 🛡️ | guardian #15A1A5 | 없음 |
| 채팅 | 💬 | primaryCoral #FF807B | 없음 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 미읽은 알림 존재 | bold 제목 + 배경 surfaceVariant #F9F9F9 + 파란 점 인디케이터 |
| 모든 알림 읽음 | 일반 텍스트, 흰색 배경 |
| 알림 0건 | "알림이 없습니다" 빈 상태 일러스트 + 안내 텍스트 |
| 로딩 중 | Shimmer 스켈레톤 (3개 ListTile 플레이스홀더) |
| SOS 알림 | 좌측 빨간 보더 강조, 최상단 고정 |

**인터랙션**

- [탭] SOS 알림 → Navigator.push → G-02 SOS 수신 화면
- [탭] 출석 알림 → Navigator.push → H-01 출석 체크
- [탭] 지오펜스 알림 → 지도로 복귀, 해당 멤버 마커 포커스
- [탭] 가디언 알림 → Navigator.push → F-01 가디언 연결 관리
- [탭] 채팅 알림 → 바텀시트 채팅탭 전환
- [탭] "모두 읽음" → 전체 알림 읽음 처리 (POST /api/v1/notifications/read-all)
- [스와이프 좌] 개별 알림 → 삭제 확인 (빨간 배경 + 삭제 아이콘)
- [뒤로가기] → Navigator.pop → C-01/C-02 복귀

---

### C-08 권한 요청 (Permissions)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-08 |
| 화면명 | 권한 요청 (Permissions) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | A-06 프로필 완료 → C-08 (첫 실행 시) / K-01 설정 → C-08 (권한 재설정) |
| 이탈 경로 | C-08 → C-01 메인맵 (모든 권한 완료 시) |

**레이아웃**

```
┌─────────────────────────────────────┐
│                                     │
│        ┌──────────┐                 │
│        │ SafeTrip │                 │ 앱 로고: 48x48
│        │   Logo   │                 │
│        └──────────┘                 │
│                                     │
│    앱 권한 설정                       │ headlineMedium (24sp, SemiBold)
│                                     │
│    SafeTrip이 안전하게 작동하려면      │ bodyMedium (14sp)
│    아래 권한이 필요합니다              │ onSurfaceVariant
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 📍  위치 권한 (항상 허용)          ││ Card_Standard (강조)
│  │     백그라운드에서도 위치를         ││ 좌측 보더: primaryTeal
│  │     공유하여 동행자의 안전을        ││ 가장 중요한 권한
│  │     지킵니다                      ││
│  │                 [✅ 허용됨]       ││ 또는 [⚠️ 설정 필요] (amber 버튼)
│  └─────────────────────────────────┘│
│                                     │ spacing16
│  ┌─────────────────────────────────┐│
│  │ 🔔  알림 권한                     ││ Card_Standard
│  │     SOS, 출석체크, 긴급 알림을     ││
│  │     받으려면 필요합니다             ││
│  │                 [✅ 허용됨]       ││ 또는 토글 스위치
│  └─────────────────────────────────┘│
│                                     │ spacing16
│  ┌─────────────────────────────────┐│
│  │ 🔋  배터리 최적화 해제             ││ Card_Standard
│  │     백그라운드 위치 추적이          ││
│  │     중단되지 않도록 합니다          ││
│  │                 [✅ 허용됨]       ││ 또는 토글 스위치
│  └─────────────────────────────────┘│
│                                     │
│  ⚠️ 위치 권한 없이는 핵심 기능을       │ bodySmall, semanticError #DA4C51
│    사용할 수 없습니다                 │ (위치 미허용 시에만 표시)
│                                     │
│  ┌─────────────────────────────────┐│
│  │       계속하기                    ││ Button_Primary
│  └─────────────────────────────────┘│ disabled: 위치 권한 미허용 시
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱 로고 | `Image.asset` | width: 48, height: 48, 중앙 정렬 |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 권한 카드 (위치) | `Card` | style: Card_Standard, 좌측 보더 primaryTeal, 내부 패딩 spacing16 |
| 권한 카드 (일반) | `Card` | style: Card_Standard, 내부 패딩 spacing16 |
| 권한 아이콘 | `Container` (원형) + `Icon` | 40dp, backgroundColor: primaryTeal (opacity 0.1), icon color: primaryTeal |
| 권한 제목 | `Text` | style: titleMedium (18sp, SemiBold) |
| 권한 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 상태 뱃지 (허용됨) | `Chip` | icon: Icons.check_circle, color: semanticSuccess #15A1A5, text: "허용됨" |
| 상태 버튼 (설정 필요) | `ElevatedButton` (small) | backgroundColor: secondaryAmber #FFC363, text: "설정 필요" |
| 경고 텍스트 | `Text` | style: bodySmall (12sp), color: semanticError #DA4C51, Visibility: 위치 미허용 시만 |
| 계속하기 버튼 | `ElevatedButton` | style: Button_Primary, enabled: 위치 권한 허용 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (모든 권한 미설정) | 3개 카드 모두 "설정 필요" 버튼, 계속하기 비활성 |
| 위치 권한 허용 | 위치 카드 ✅ "허용됨", 경고 텍스트 숨김, 계속하기 활성 |
| 위치 권한 거부 | 위치 카드 ⚠️ "설정 필요" (amber), 경고 텍스트 표시 (빨강), 계속하기 비활성 |
| 알림 권한 허용 | 알림 카드 ✅ "허용됨" |
| 알림 권한 거부 | 알림 카드 ⚠️ "설정 필요" + "SOS 수신 제한" 경고 |
| 배터리 최적화 해제 완료 | 배터리 카드 ✅ "허용됨" |
| 모든 권한 완료 | 계속하기 버튼 활성 (primaryTeal) |

**인터랙션**

- [탭] 위치 권한 "설정 필요" → 시스템 위치 권한 다이얼로그 표시 (항상 허용 옵션)
- [탭] 알림 권한 "설정 필요" → 시스템 알림 권한 다이얼로그 표시
- [탭] 배터리 최적화 "설정 필요" → 시스템 배터리 최적화 설정 이동
- [탭] 계속하기 → Navigator.pushReplacement → C-01 메인맵
- [자동] 각 권한 결과 반환 시 → 해당 카드 상태 업데이트 (실시간)

---

### C-09 데모 모드 (Demo Mode)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-09 |
| 화면명 | 데모 모드 (Demo Mode) |
| Phase | P0 |
| 역할 | 신규 사용자 (미로그인) |
| 진입 경로 | A-02 웰컴 온보딩 "둘러보기" 탭 → C-09 |
| 이탈 경로 | C-09 → A-02 웰컴 온보딩 (가입하기 탭) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ ┌─────────────────────────────── ✕ ┐│ 데모 배너: secondaryAmber #FFC363
│ │ 🎮 체험 모드 — 실제 데이터가       ││ bodySmall (12sp), #FFFFFF
│ │    아닙니다                 닫기  ││ 전체 너비, 닫기 버튼
│ └─────────────────────────────────┘│
│ [🔔]  Demo: 도쿄 체험 여행  D+3 [⚙️]│ AppBar_Map (데모 데이터)
├─────────────────────────────────────┤
│                                     │
│    ⭐ Demo 김철수 (캡틴)              │ 시뮬레이션 마커들
│                                     │
│    ● Demo 이영희 (크루)              │ 가짜 이름/위치 (도쿄 주변)
│         ● Demo 박지수 (크루)         │
│                                     │
│     ╔═══════════╗                   │ 시뮬레이션 지오펜스
│     ║  시부야역   ║                   │
│     ╚═══════════╝                   │
│                                     │
│                                     │
├─────────────────────── radius20 ────┤
│          ━━━━━━━━━━━                │
│  ┌─📅일정─┬─👥멤버─┬─💬채팅─┬─📖가이드─┐│
│  │ 시부야 쇼핑  10:00-12:00         ││ 샘플 일정 데이터
│  │ 센소지 관광  14:00-16:00         ││
│  └──────────────────────────────────┘│
│                              [SOS]  │ SOS: "(체험)" 라벨
│                             (체험)   │
└─────────────────────────────────────┘

[코칭 오버레이 — 첫 진입 시]
┌─────────────────────────────────────┐
│                                     │
│                                     │
│              ┌──────────────────┐   │
│              │ SOS 버튼을 2초    │   │ Tooltip 화살표
│              │ 누르면 긴급 신호를 │   │ SOS 버튼 spotlight
│              │ 보냅니다          │   │
│              └──────────────────┘   │
│                              [SOS]  │
│                                     │
│  ┌─────────────────────────────────┐│
│  │    가입하고 시작하기               ││ Button_Primary
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 데모 배너 | `Container` | backgroundColor: secondaryAmber #FFC363, padding: spacing8, 전체 너비 |
| 배너 텍스트 | `Text` | style: bodySmall (12sp), color: #FFFFFF, "🎮 체험 모드 -- 실제 데이터가 아닙니다" |
| 배너 닫기 | `IconButton` | icon: Icons.close, color: #FFFFFF, 크기 16dp |
| 시뮬레이션 마커 | `Marker` + `BitmapDescriptor` | 역할별 색상, "Demo " 접두어 이름, 도쿄 주변 고정 좌표 |
| 시뮬레이션 지오펜스 | `Circle` | 시부야역 좌표, radius: 500m, 반투명 teal |
| 샘플 일정 | `ListTile_Schedule` | 고정 데이터: "시부야 쇼핑 10:00-12:00", "센소지 관광 14:00-16:00" |
| SOS 버튼 (데모) | `FloatingActionButton` | style: Button_SOS, 아래 "(체험)" 라벨 표시 |
| 코칭 오버레이 | `Stack` + `Positioned` | 반투명 검정 배경, SOS 버튼 spotlight, 툴팁 화살표 |
| 가입 버튼 | `ElevatedButton` | style: Button_Primary, text: "가입하고 시작하기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 첫 진입 | 코칭 오버레이 표시 (SOS 버튼 spotlight + 툴팁) |
| 코칭 완료 | 오버레이 사라짐, 일반 데모 모드 |
| SOS 탭 (데모) | Toast "데모에서는 SOS가 발송되지 않습니다" (3초) |
| 채팅 전송 시도 | Toast "데모에서는 메시지를 보낼 수 없습니다" |
| 설정 접근 | 제한적 설정 (탈퇴/삭제 비활성화) |
| 배너 닫기 | 데모 배너 숨김 (세션 내 유지) |

**인터랙션**

- [탭] 데모 배너 닫기 (✕) → 배너 숨김
- [탭] SOS 버튼 → Toast "데모에서는 SOS가 발송되지 않습니다"
- [탭] 코칭 오버레이 빈 영역 → 오버레이 닫힘
- [탭] 가입하고 시작하기 → Navigator.pushReplacement → A-02 웰컴 온보딩
- [드래그] 바텀시트 → 샘플 데이터로 탭 컨텐츠 탐색 가능
- [탭] 각 탭 → 시뮬레이션 데이터 표시 (편집/전송 비활성화)

---

### C-10 이벤트 로그 (Event Log)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-10 |
| 화면명 | 이벤트 로그 (Event Log) |
| Phase | P1 |
| 역할 | 캡틴, 크루장 |
| 진입 경로 | K-01 설정 → C-10 / C-03 상단바 메뉴 → C-10 |
| 이탈 경로 | C-10 → C-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 이벤트 로그                      │ AppBar_Standard
├─────────────────────────────────────┤
│                                     │
│  ┌─전체─┬─출입─┬─SOS─┬─출석─┬─위치─┐ │ 필터 칩: Chip_Tag
│  └──────┴─────┴─────┴─────┴─────┘ │ 수평 스크롤
│                                     │
│  2026.03.18 (오늘)                   │ 날짜 헤더: bodySmall
│  ─────────────────────────────────── │
│  ┌─────────────────────────────────┐│
│  │ 14:32  📍 이준호님이 호텔         ││ 타임라인 아이템
│  │  │        지오펜스에 진입했습니다   ││ 좌측: 시간 (teal)
│  │  │                              ││ 중앙: 이벤트 설명
│  ├──┼──────────────────────────────┤│
│  │ 13:15  🆘 김민지님이 SOS를        ││ SOS 이벤트: 빨간 강조
│  │  │        발송했습니다 (해제됨)    ││
│  ├──┼──────────────────────────────┤│
│  │ 11:00  ✅ 오전 출석 체크 완료      ││ 출석 이벤트
│  │  │        (5/5명 응답)            ││
│  ├──┼──────────────────────────────┤│
│  │ 09:30  📍 박지수님이 숙소          ││ 지오펜스 이탈 이벤트
│  │  │        지오펜스를 벗어났습니다   ││
│  └──┘                              ││
│                                     │
│  2026.03.17 (어제)                   │ 이전 날짜 섹션
│  ─────────────────────────────────── │
│  │ ...                              │
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "이벤트 로그", leading: BackButton, style: AppBar_Standard |
| 필터 칩 바 | `SingleChildScrollView` + `Row` < `Chip` > | style: Chip_Tag, 수평 스크롤, 선택 시 primaryTeal 배경 |
| 날짜 헤더 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, fontWeight: w600 |
| 타임라인 라인 | `CustomPaint` / `Container` | width: 2px, color: outline #EDEDED, 세로 연결선 |
| 타임라인 점 | `Container` (원형) | 12dp, 이벤트 유형별 색상 |
| 시간 텍스트 | `Text` | style: bodySmall (12sp), color: primaryTeal #00A2BD |
| 이벤트 설명 | `Text` | style: bodyMedium (14sp), color: onSurface |
| 이벤트 카드 | `Container` | padding: spacing12, 좌측 타임라인 연결 |

**이벤트 유형별 아이콘/색상**

| 유형 | 아이콘 | 타임라인 점 색상 |
|------|:------:|:-------------:|
| 지오펜스 진입/이탈 | 📍 | primaryTeal #00A2BD |
| SOS 발동/해제 | 🆘 | sosDanger #D32F2F |
| 출석 체크 | ✅ | semanticSuccess #15A1A5 |
| 위치 변경 | 🔄 | onSurfaceVariant #8E8E93 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 기본 | "전체" 필터 선택, 모든 이벤트 시간순 표시 |
| 필터 선택 | 해당 유형 이벤트만 필터링 표시 |
| 이벤트 0건 | "기록된 이벤트가 없습니다" 빈 상태 |
| 로딩 중 | Shimmer 스켈레톤 |
| SOS 이벤트 | 빨간 좌측 보더 + bold 텍스트 강조 |

**인터랙션**

- [탭] 필터 칩 → 해당 유형 이벤트만 필터링 (다중 선택 가능)
- [탭] 이벤트 아이템 → 상세 정보 확장 (아코디언) 또는 지도에서 해당 위치 표시
- [스크롤 하단] → 이전 날짜 이벤트 페이지네이션 로드
- [뒤로가기] → Navigator.pop

---

### C-11 마커 상세 (Marker Detail)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-11 |
| 화면명 | 마커 상세 (Marker Detail) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | C-01/C-02 멤버 마커 탭 → C-11 |
| 이탈 경로 | C-11 → C-01/C-02 (빈 영역 탭 또는 닫기) |

**레이아웃**

```
       ┌─────────────────────────────┐
       │ ┌───┐                       │ 마커 상세 팝업 카드
       │ │👤 │ 김민지                  │ Card 오버레이, 지도 위 표시
       │ │   │ ┌────────┐            │ 해당 마커 바로 위에 위치
       │ └───┘ │ 크루장   │            │
       │       └────────┘            │
       │ 마지막 위치: 3분 전            │ bodySmall, onSurfaceVariant
       │ 프라이버시: 📍 표준            │ (캡틴/크루장에게만)
       │                             │
       │ ┌─────┐ ┌─────┐            │ 미니 액션 버튼
       │ │ 💬  │ │ 📞  │            │ IconButton 32dp
       │ │메시지│ │ 전화 │            │
       │ └─────┘ └─────┘            │
       └──────────┬──────────────────┘
                  │ (마커 방향 화살표)
                  ▼
            [멤버 마커]
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 팝업 컨테이너 | `Card` (또는 `CustomInfoWindow`) | radius12, backgroundColor: surface #FFFFFF, shadow: black 8%, 최대 너비 240dp |
| 아바타 | `CircleAvatar` | radius: 20dp, backgroundColor: secondaryBeige #F2EDE4 |
| 멤버 이름 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 역할 뱃지 | `Container` (pill) | style: Badge_Role, 역할별 색상 |
| 마지막 위치 시간 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, "마지막 위치: N분 전" |
| 프라이버시 상태 | `Row` < `Icon` + `Text` > | 등급별 아이콘/색상, Visibility: 캡틴/크루장만 |
| 메시지 버튼 | `IconButton` | icon: Icons.message, size: 32dp, color: primaryTeal, onTap: 1:1 메시지 |
| 전화 버튼 | `IconButton` | icon: Icons.phone, size: 32dp, color: primaryTeal, onTap: 전화 앱 연결 |
| 마커 화살표 | `CustomPaint` | 삼각형, color: surface #FFFFFF, 하단 중앙 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 온라인 멤버 | 아바타 테두리 초록 (#4CAF50), "N분 전" 시간 표시 |
| 오프라인 멤버 | 아바타 테두리 회색 (#8E8E93), "오프라인" 라벨 |
| SOS 발동 중 멤버 | 아바타 테두리 빨강 (#D32F2F), "SOS 발동 중" 빨간 라벨 |
| 가디언 뷰 | 메시지 버튼 → "긴급 메시지" 라벨, 전화 버튼 유지 |
| 위치 공유 OFF | "위치 비공유 중" 회색 라벨 |

**인터랙션**

- [탭] 메시지 버튼 → 1:1 메시지 화면 이동 (채팅탭 내 개인 채널)
- [탭] 전화 버튼 → 시스템 전화 앱 실행 (멤버 전화번호)
- [탭] 팝업 외부 (지도 빈 영역) → 팝업 닫힘
- [탭] 멤버 이름/아바타 → 멤버 상세 프로필 화면 이동
- [자동] 다른 마커 탭 → 현재 팝업 닫히고 새 팝업 열림

---

### C-12 맵 컨트롤 (Map Controls)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | C-12 |
| 화면명 | 맵 컨트롤 (Map Controls) |
| Phase | P1 |
| 역할 | 전체 |
| 진입 경로 | C-01/C-02의 하위 컴포넌트 (지도 우측에 상시 표시) |
| 이탈 경로 | 없음 (컴포넌트 수준, 지도 카메라 제어만) |

**레이아웃**

```
                          ┌──────┐
                          │  +   │ 줌 인: FloatingActionButton.small
                          ├──────┤ spacing8
                          │  -   │ 줌 아웃: FloatingActionButton.small
                          ├──────┤ spacing16
                          │  📍  │ 내 위치: FloatingActionButton.small
                          ├──────┤ spacing8
                          │  👥  │ 전체 보기: FloatingActionButton.small
                          └──────┘

(지도 우측, 바텀시트 위에 Positioned)
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 컨트롤 컨테이너 | `Positioned` + `Column` | right: spacing20, bottom: 바텀시트 높이 + spacing16 |
| 줌 인 | `FloatingActionButton.small` | icon: Icons.add, backgroundColor: surface #FFFFFF, iconColor: onSurface #1A1A1A, elevation: 2 |
| 줌 아웃 | `FloatingActionButton.small` | icon: Icons.remove, backgroundColor: surface #FFFFFF, iconColor: onSurface #1A1A1A, elevation: 2 |
| 내 위치 | `FloatingActionButton.small` | icon: Icons.my_location, backgroundColor: surface #FFFFFF, iconColor: primaryTeal #00A2BD, elevation: 2 |
| 전체 보기 | `FloatingActionButton.small` | icon: Icons.people, backgroundColor: surface #FFFFFF, iconColor: primaryTeal #00A2BD, elevation: 2 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 기본 | 4개 버튼 모두 표시 (흰색 배경) |
| 내 위치 추적 중 | 내 위치 버튼 아이콘 primaryTeal 강조, 반복 펄스 |
| 최대 줌 도달 | 줌 인 버튼 비활성 (opacity 0.4) |
| 최소 줌 도달 | 줌 아웃 버튼 비활성 (opacity 0.4) |
| 멤버 1명 이하 | 전체 보기 버튼 비활성 (바운딩 박스 불필요) |
| 바텀시트 expanded | 컨트롤 버튼 위치 자동 조정 (바텀시트 위) |
| 가디언 모드 | 전체 보기 → 연결 멤버만 바운딩 박스 피트 |

**인터랙션**

- [탭] 줌 인 (+) → 지도 줌 레벨 +1 (애니메이션 200ms)
- [탭] 줌 아웃 (-) → 지도 줌 레벨 -1 (애니메이션 200ms)
- [탭] 내 위치 (📍) → 지도 카메라를 내 현재 위치로 이동 (줌 15)
- [탭] 전체 보기 (👥) → 모든 멤버(가디언: 연결 멤버)를 포함하는 바운딩 박스로 카메라 피트 (애니메이션 300ms)

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 12개 화면 (C-01 ~ C-12) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 지도 기본화면 고유 원칙: `Master_docs/17_T3_지도_기본화면_고유_원칙.md`
- 화면 구성 원칙: `Master_docs/10_T2_화면구성원칙.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 바텀시트 동작 규칙: `Master_docs/11_T2_바텀시트_동작_규칙.md`
