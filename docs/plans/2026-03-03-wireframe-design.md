# SafeTrip 와이어프레임 문서 설계

> **작성일:** 2026-03-03
> **버전:** v1.0
> **목적:** Flutter 개발 가이드 + UX 흐름 검증용 와이어프레임 문서 체계
> **범위:** 전체 104개 화면 (Phase 0~3)

---

## 1. 개요

SafeTrip 앱의 104개 화면을 15개 카테고리별 마크다운 파일로 문서화한다. 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성되며, 각 파일 상단에 User Journey Flow 다이어그램을 포함한다.

### 1.1 문서 목적

| 목적 | 설명 |
|------|------|
| **Flutter 개발 가이드** | 위젯 트리, 컴포넌트명, 레이아웃 구조를 명세하여 개발자가 바로 구현 가능 |
| **UX 흐름 검증** | 화면 간 전환 로직, 역할별 분기, 에러/엣지케이스 흐름을 다이어그램으로 검증 |

### 1.2 참조 문서

- **디자인 시스템:** `docs/DESIGN.md`
- **화면 구성 원칙:** `Master_docs/10_T2_화면구성원칙.md`
- **비즈니스 원칙:** `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- **화면 목업 계획:** `docs/plans/2026-03-03-screen-design-mockup-plan.md`

---

## 2. 파일 구조

```
docs/wireframes/
├── 00_Global_Style_Guide.md             ← 공통 컴포넌트/토큰/매트릭스
├── A_Onboarding_Auth.md                 ← 7개 화면
├── B_Trip_Creation.md                   ← 8개 화면
├── C_MainMap_CommonUI.md                ← 12개 화면
├── D_Trip_Management.md                 ← 16개 화면
├── E_Location_Privacy.md                ← 8개 화면
├── F_Guardian_System.md                 ← 10개 화면
├── G_SOS_Emergency.md                   ← 5개 화면
├── H_Attendance.md                      ← 5개 화면
├── I_Chat_Communication.md              ← 5개 화면
├── J_Safety_Guide.md                    ← 7개 화면
├── K_Settings_Profile.md                ← 8개 화면
├── L_Payment_Subscription.md            ← 10개 화면
├── M_Minor_Protection.md                ← 4개 화면
├── N_B2B_Portal.md                      ← 8개 화면
└── O_AI_Features.md                     ← 5개 화면
```

---

## 3. 글로벌 스타일 가이드 (`00_Global_Style_Guide.md`)

### 3.1 레이아웃 기본값

| 항목 | 값 | 비고 |
|------|-----|------|
| 디바이스 기준 | 390×844px | iPhone 14 |
| AppBar 높이 | 56dp | 상단 고정 |
| NavigationBar 높이 | 60dp | 하단 고정 |
| Safe Area 상단 | 47dp | 상태바 |
| Safe Area 하단 | 34dp | 홈 인디케이터 |
| 화면 좌우 패딩 | 20px | `spacing20` |

### 3.2 공통 컴포넌트 사전

아래 컴포넌트를 정의한다 (이름, 크기, 색상, 상태 목록, Flutter 위젯 매핑):

| 컴포넌트명 | Flutter 위젯 | 크기 | 색상 토큰 | 비고 |
|-----------|-------------|------|----------|------|
| AppBar_Standard | AppBar | h:56 | primaryTeal | 뒤로가기 + 제목 + 액션 |
| AppBar_Map | Stack(Positioned) | h:56 | transparent | 지도 위 반투명 오버레이 |
| Button_Primary | ElevatedButton | h:52, r:12 | primaryTeal | 주요 CTA |
| Button_Secondary | OutlinedButton | h:52, r:12 | primaryTeal border | 보조 액션 |
| Button_Destructive | ElevatedButton | h:52, r:12 | semanticError | 삭제/취소 |
| Button_SOS | FloatingActionButton | 56×56, r:28 | sosDanger #D32F2F | 2초 롱프레스 |
| Card_Standard | Card | r:16, shadow 4% | surface | 일반 카드 |
| Card_Selectable | Card + InkWell | r:16 + left border | 선택 시 역할 색상 | 선택형 카드 |
| Card_Alert | Card | r:16 + colored border | semanticError/Warning | 알림 카드 |
| BottomSheet_Snap | DraggableScrollableSheet | 5단계 스냅 | surface + r:20 top | peek/collapsed/half/tall/expanded |
| NavBar_Crew | BottomNavigationBar | 4탭 + SOS FAB | primaryTeal active | 일정/멤버/채팅/가이드 |
| NavBar_Guardian | BottomNavigationBar | 3탭 | guardian #15A1A5 | 내멤버/일정/가이드 |
| Input_Text | TextFormField | h:48, r:8 | outline border | 텍스트 입력 |
| Input_OTP | Row(TextField×6) | 48×56 each, r:8 | teal active border | 6자리 |
| Input_Search | TextField | h:44, r:22 | outline + 🔍 prefix | 검색 |
| Modal_Bottom | showModalBottomSheet | r:20 top | surface | 모달 바텀시트 |
| Dialog_Confirm | AlertDialog | r:16 | surface | 확인/취소 |
| Toast | SnackBar | r:8 | onSurface | 임시 알림 |
| Badge_Role | Container | pill shape | 역할 색상 | 캡틴/크루장/크루/가디언 |
| Chip_Tag | Chip | r:4 | secondaryAmber/gray | 상태 태그 |
| ListTile_Member | ListTile | h:72 | avatar + name + role badge | 멤버 목록 |
| ListTile_Schedule | ListTile | h:64 | time + title + place | 일정 목록 |
| ListTile_Notification | ListTile | h:80 | icon + text + timestamp | 알림 목록 |

### 3.3 역할별 UI 매트릭스

| UI 요소 | 캡틴 | 크루장 | 크루 | 가디언 |
|---------|:----:|:-----:|:----:|:-----:|
| 프라이버시 등급 아이콘 | ✅ | ✅ | ❌ | ❌ |
| 위치공유 모드 표시 | ✅ | ✅ | ❌ | ❌ |
| SOS 버튼 | ✅ | ✅ | ✅ | ❌ |
| 채팅 탭 | ✅ | ✅ | ✅ | ❌ |
| 일정 편집 | ✅ | ✅ | ❌ | ❌ |
| 멤버 관리 | ✅ | 제한적 | ❌ | ❌ |

### 3.4 여행 상태별 UI 매트릭스

| UI 요소 | none | planning | active | completed |
|---------|:----:|:--------:|:------:|:---------:|
| 지도 마커 | ❌ | ❌ | ✅ | ❌ (스냅샷) |
| SOS 버튼 | ❌ | ❌ | ✅ | ❌ |
| D±N 표시 | ❌ | D-N | D+N | ❌ |
| 탭 활성화 | 가이드만 | 전체 | 전체 | 전체(읽기전용) |

### 3.5 프라이버시 등급별 UI 매트릭스

| 동작 | 안전최우선 | 표준 | 프라이버시우선 |
|------|:--------:|:----:|:----------:|
| OFF 시 마커 | ✅ 실시간 | 희미(30분) | ❌ |
| 가디언 위치 접근 | 항상 | 실시간 | 승인 후 1회 |
| 일시정지 | ❌ | 최대 12h | 최대 24h |

---

## 4. 화면별 5-섹션 템플릿

각 화면은 아래 5개 섹션으로 구성된다:

### 섹션 1: 메타데이터

```markdown
**메타데이터**
| 항목 | 값 |
|------|-----|
| ID | {카테고리}-{번호} (예: A-04) |
| 화면명 | 한글명 (English Name) |
| Phase | P0 / P1 / P2 / P3 |
| 역할 | 접근 가능한 역할 목록 |
| 진입 경로 | 이전 화면 → 현재 화면 (조건) |
| 이탈 경로 | 현재 화면 → 다음 화면 (조건) |
```

### 섹션 2: 레이아웃 (ASCII)

```
┌─────────────────────────────┐
│ [←] 화면 제목                │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─ 컴포넌트명 ──────────┐  │
│  │ 내용                   │  │ Flutter위젯
│  └────────────────────────┘  │
│                             │
│  ┌────────────────────────┐  │
│  │     버튼 텍스트          │  │ Button_Primary
│  └────────────────────────┘  │
└─────────────────────────────┘
```

### 섹션 3: 컴포넌트 명세

```markdown
| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | AppBar | title, leading, actions |
| 입력 필드 | TextFormField | keyboardType, validator |
| 주요 버튼 | ElevatedButton | color, size, onPressed |
```

### 섹션 4: 상태 분기

```markdown
| 상태 | UI 변화 |
|------|---------|
| 초기 | 기본 상태 설명 |
| 로딩 | 로딩 인디케이터 표시 |
| 성공 | 다음 화면 이동 |
| 에러 | 에러 메시지 표시 |
```

### 섹션 5: 인터랙션

```markdown
- [탭] 버튼명 → 동작 설명
- [스와이프] 방향 → 동작 설명
- [롱프레스] 대상 → 동작 설명
- [뒤로가기] → 이전 화면
```

---

## 5. 카테고리 파일 내부 구조

각 카테고리 파일은 다음 순서로 구성된다:

```markdown
# {카테고리 코드}. {카테고리명}

## 개요
- 화면 수: N개
- Phase 분포: P0 x개, P1 y개, ...
- 핵심 역할: 캡틴/크루/가디언
- 연관 Master_docs: 해당 Tier 3 원칙 문서

## User Journey Flow
(ASCII 다이어그램)

## 외부 진입/이탈 참조
| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|

## 화면 상세

### {ID} {화면명}
(5-섹션 템플릿 × N개 화면)
```

---

## 6. 작성 대상 화면 목록 (104개)

| 카테고리 | 화면 수 | 화면 ID 범위 | Phase |
|---------|:------:|-------------|:-----:|
| A. 온보딩 & 인증 | 7 | A-01 ~ A-07 | P0 |
| B. 여행 생성 & 참여 | 8 | B-01 ~ B-08 | P0 |
| C. 메인 맵 & 공통 UI | 12 | C-01 ~ C-12 | P0-P1 |
| D. 여행 관리 | 16 | D-01 ~ D-16 | P0-P1 |
| E. 위치공유 & 프라이버시 | 8 | E-01 ~ E-08 | P0-P1 |
| F. 가디언 시스템 | 10 | F-01 ~ F-10 | P0-P1 |
| G. SOS & 긴급 기능 | 5 | G-01 ~ G-05 | P0-P1 |
| H. 출석 체크 | 5 | H-01 ~ H-05 | P1 |
| I. 채팅 & 커뮤니케이션 | 5 | I-01 ~ I-05 | P0-P2 |
| J. 안전 가이드 | 7 | J-01 ~ J-07 | P0-P1 |
| K. 설정 & 프로필 | 8 | K-01 ~ K-08 | P0-P1 |
| L. 결제 & 구독 | 10 | L-01 ~ L-10 | P2 |
| M. 미성년자 보호 | 4 | M-01 ~ M-04 | P2 |
| N. B2B 관리자 포털 | 8 | N-01 ~ N-08 | P3 |
| O. AI 기능 | 5 | O-01 ~ O-05 | P2-P3 |
| **합계** | **118** | | |

> 참고: 원래 계획은 104개이나, 일부 카테고리 화면이 세분화되어 118개로 조정될 수 있음. 최종 구현 계획에서 확정.

---

## 7. 작성 소스

각 화면의 상세 내용은 아래 소스에서 추출한다:

| 소스 | 용도 |
|------|------|
| `docs/plans/2026-03-03-screen-design-mockup-plan.md` | 104개 화면 정의 (ID, 설명, Phase, 역할) |
| `docs/plans/2026-03-03-screen-mockup-implementation.md` | 각 화면의 Stitch 프롬프트 (상세 UI 명세) |
| `Master_docs/10_T2_화면구성원칙.md` | 레이아웃 계층, 바텀시트, 역할별 규칙 |
| `Master_docs/11_T2_바텀시트_동작_규칙.md` | 바텀시트 5단계 스냅 포인트 |
| `Master_docs/14_T3_온보딩_UX_시나리오.md` | A 카테고리 상세 |
| `Master_docs/17_T3_지도_기본화면_고유_원칙.md` | C 카테고리 상세 |
| `Master_docs/18_T3_일정탭_원칙.md` | D 카테고리 일정 도메인 |
| `Master_docs/19_T3_멤버탭_원칙.md` | D 카테고리 멤버 도메인 |
| `Master_docs/20_T3_채팅탭_원칙.md` | I 카테고리 상세 |
| `Master_docs/21_T3_안전가이드_원칙.md` | J 카테고리 상세 |
| `Master_docs/15_T3_설정_메뉴_원칙.md` | K 카테고리 상세 |
| `Master_docs/13_T3_SOS_원칙.md` | G 카테고리 상세 |
| `docs/DESIGN.md` | 색상/타이포/스페이싱 토큰 |

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 |
