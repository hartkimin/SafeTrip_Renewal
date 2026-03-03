# N. B2B 관리자 포털

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 B2B 관리자 포털 8개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.
> B2B 포털은 웹 앱으로 구현될 가능성이 높으나, 모바일 뷰도 함께 디자인한다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 8개 (N-01 ~ N-08)
- **Phase:** 전체 P3
- **핵심 역할:** B2B 관리자 (학교/여행사/기업)
- **참고:** B2B 포털은 웹 앱으로 구현될 가능성이 높으나, 모바일 뷰도 함께 디자인
- **B2B 액센트:** `#1565C0` (dark blue)

---

## Design Tokens (B2B 전용)

| 토큰명 | HEX | 용도 |
|--------|-----|------|
| `b2bAccent` | `#1565C0` | B2B 포털 주요 액센트 색상, AppBar 배경, CTA 버튼 |
| `b2bAccentLight` | `#1E88E5` | 호버 상태, 보조 강조 |
| `b2bAccentDark` | `#0D47A1` | 프레스 상태, 헤더 텍스트 |
| `b2bSurface` | `#F5F7FA` | 대시보드 배경 |
| `b2bCardBg` | `#FFFFFF` | 카드 배경 (elevation 2) |

> B2B 포털은 일반 앱의 `primaryTeal` 대신 `b2bAccent` (`#1565C0`)를 주요 색상으로 사용한다.
> 나머지 시맨틱 컬러(success, warning, error)는 글로벌 스타일 가이드와 동일하다.

---

## User Journey Flow

```
N-01 B2B 대시보드
 ├── [대량 여행 생성] → N-02 대량 여행 생성
 ├── [대량 초대]     → N-03 대량 초대 코드
 ├── [가디언 연결]   → N-04 대량 가디언 연결
 ├── [계약 관리]     → N-05 계약 관리
 ├── [안전 리포트]   → N-06 안전 리포트
 ├── [멤버 관리]     → N-07 멤버 관리
 └── [브랜딩 설정]   → N-08 조직 브랜딩
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| 로그인 | B2B 관리자 인증 완료 | N-01 B2B 대시보드 | N |
| N-01 | 대량 여행 생성 버튼 | N-02 대량 여행 생성 | N |
| N-01 | 대량 초대 버튼 | N-03 대량 초대 코드 | N |
| N-01 | 가디언 연결 버튼 | N-04 대량 가디언 연결 | N |
| N-01 | 계약 관리 버튼 | N-05 계약 관리 | N |
| N-01 | 안전 리포트 버튼 | N-06 안전 리포트 | N |
| N-01 | 멤버 관리 버튼 | N-07 멤버 관리 | N |
| N-01 | 브랜딩 설정 버튼 | N-08 조직 브랜딩 | N |

---

## 화면 상세

---

### N-01 B2B 대시보드 (B2B Dashboard)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | N-01 |
| 화면명 | B2B 대시보드 (B2B Dashboard) |
| Phase | P3 |
| 역할 | B2B 관리자 |
| 진입 경로 | B2B 로그인 완료 → N-01 |
| 이탈 경로 | N-01 → N-02 ~ N-08 (각 기능 화면) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [☰]  SafeTrip B2B       [🔔] [👤]  │ AppBar (b2bAccent #1565C0)
├─────────────────────────────────────┤
│                                     │
│  ┌──────────┐  조직명               │ Organization header
│  │  Logo    │  학교/여행사/기업       │ 조직 로고 (48x48) + 조직명 + 유형
│  └──────────┘                       │
│                                     │
│  ┌────────┐ ┌────────┐              │ Statistics Cards (2x2 grid)
│  │ 📊     │ │ 👥     │              │
│  │ 활성    │ │ 전체   │              │ Card_Standard, elevation 2
│  │ 여행    │ │ 멤버   │              │
│  │  12    │ │  348   │              │ headlineMedium (값)
│  └────────┘ └────────┘              │ bodySmall (라벨)
│  ┌────────┐ ┌────────┐              │
│  │ 🚨     │ │ ✅     │              │
│  │ 안전    │ │ 출석률  │              │
│  │ 이벤트  │ │        │              │
│  │   3    │ │ 94.2%  │              │
│  └────────┘ └────────┘              │
│                                     │
│  ── 여행 현황 차트 ──────────────     │ Section header (titleMedium)
│  ┌─────────────────────────────┐    │
│  │  BarChart                   │    │ 월별 여행 수 (최근 6개월)
│  │  ║ ║                        │    │ b2bAccent bars
│  │  ║ ║ ║                      │    │
│  │  ║ ║ ║ ║                    │    │
│  │  1  2  3  4  5  6 (월)      │    │
│  └─────────────────────────────┘    │
│                                     │
│  ── 안전 이벤트 추이 ────────────    │ Section header (titleMedium)
│  ┌─────────────────────────────┐    │
│  │  LineChart                  │    │ 주간 SOS/지오펜스 이벤트
│  │     .    .                  │    │ semanticError (SOS line)
│  │  .    .    .                │    │ semanticWarning (geofence line)
│  │  1  2  3  4  5  (주차)      │    │
│  └─────────────────────────────┘    │
│                                     │
│  ── 빠른 실행 ────────────────       │ Section header (titleMedium)
│  ┌─────────┐ ┌─────────┐           │ Quick action buttons (grid)
│  │ 📋 대량  │ │ ✉️ 대량  │           │
│  │ 여행생성 │ │ 초대    │           │ Card_Standard + IconButton
│  └─────────┘ └─────────┘           │
│  ┌─────────┐ ┌─────────┐           │
│  │ 🛡️ 가디언│ │ 📊 리포트│           │
│  │ 연결    │ │ 조회    │           │
│  └─────────┘ └─────────┘           │
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | backgroundColor: b2bAccent (#1565C0), leading: 햄버거 메뉴, title: "SafeTrip B2B", actions: [알림, 프로필] |
| 조직 헤더 | `Row` | leading: `CircleAvatar` (48dp, 조직 로고), title: 조직명 (`titleLarge`), subtitle: 조직 유형 (`bodySmall`) |
| 통계 카드 (4개) | `Card` | style: Card_Standard, elevation: 2, radius16, 2x2 `GridView`, 아이콘 + 수치 (`headlineMedium`) + 라벨 (`bodySmall`) |
| 여행 현황 차트 | `BarChart` (fl_chart) | barColor: b2bAccent (#1565C0), 6개월 데이터, x축 월, y축 여행 수 |
| 안전 이벤트 차트 | `LineChart` (fl_chart) | line1: semanticError (#DA4C51, SOS), line2: semanticWarning (#FFAC11, 지오펜스), 5주 데이터 |
| 빠른 실행 버튼 (4개) | `Card` + `InkWell` | style: Card_Standard, elevation: 1, 아이콘 (32dp) + 라벨 (`labelMedium`), 2x2 `GridView` |
| 섹션 헤더 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 로딩 | 통계 카드 4개 Shimmer 효과, 차트 영역 Skeleton 표시 |
| 데이터 로드 완료 | 통계 카드 수치 표시, 차트 애니메이션 렌더링 (500ms) |
| 안전 이벤트 0 | 안전 이벤트 카드 수치 "0", semanticSuccess 색상 + "안전" 라벨 |
| 안전 이벤트 > 0 | 안전 이벤트 카드 수치 빨강, semanticError 색상 + 깜박임 점 |
| 활성 여행 0 | "활성 여행 없음" 안내 + "새 여행 만들기" CTA 표시 |
| 네트워크 오류 | SnackBar "데이터를 불러올 수 없습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 햄버거 메뉴 (☰) → Drawer 사이드바 (N-02 ~ N-08 메뉴 목록)
- [탭] 통계 카드 (활성 여행) → N-07 멤버 관리 (여행 필터 적용)
- [탭] 통계 카드 (전체 멤버) → N-07 멤버 관리
- [탭] 통계 카드 (안전 이벤트) → N-06 안전 리포트
- [탭] 통계 카드 (출석률) → N-06 안전 리포트 (출석 섹션)
- [탭] 빠른 실행 버튼 → 각 기능 화면으로 이동 (N-02 ~ N-06)
- [탭] 알림 아이콘 → 알림 목록 Modal_Bottom
- [탭] 프로필 아이콘 → 관리자 설정 / 로그아웃

---

### N-02 대량 여행 생성 (Trip Bulk Create)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | N-02 |
| 화면명 | 대량 여행 생성 (Trip Bulk Create) |
| Phase | P3 |
| 역할 | B2B 관리자 |
| 진입 경로 | N-01 대시보드 → 빠른 실행 / 사이드바 → N-02 |
| 이탈 경로 | N-02 → N-01 (생성 완료 시) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 대량 여행 생성           [?]    │ AppBar (b2bAccent)
├─────────────────────────────────────┤
│                                     │
│  CSV 파일로 여행을                   │ headlineMedium (24sp, SemiBold)
│  일괄 생성합니다                     │
│                                     │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐ │
│  ╎                               ╎ │ Dropzone (dotted border)
│  ╎       📁                      ╎ │ b2bAccent icon (48dp)
│  ╎                               ╎ │
│  ╎   CSV 파일을 끌어다 놓거나     ╎ │ bodyMedium, onSurfaceVariant
│  ╎   탭하여 파일을 선택하세요     ╎ │
│  ╎                               ╎ │
│  ╎   [📥 샘플 CSV 다운로드]       ╎ │ TextButton, b2bAccent
│  ╎                               ╎ │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ │
│                                     │
│  ── 업로드 상태 ─────────────────    │
│  ┌─────────────────────────────┐    │
│  │ trips_2026_spring.csv       │    │ 파일명 + 크기
│  │ ████████████░░░  78%        │    │ LinearProgressIndicator
│  │ 150건 파싱 중...             │    │ bodySmall, onSurfaceVariant
│  └─────────────────────────────┘    │
│                                     │
│  ── 검증 결과 ───────────────────    │ Section header
│  ┌─────────────────────────────┐    │
│  │ # │ 여행명    │ 기간    │상태│    │ DataTable header
│  ├─────────────────────────────┤    │
│  │ 1 │ 제주수학..│ 3/15-18│ ✅ │    │ 성공 행 (semanticSuccess)
│  │ 2 │ 부산체험..│ 3/20-22│ ✅ │    │
│  │ 3 │ 도쿄연수..│ invalid│ ❌ │    │ 오류 행 (semanticError bg)
│  │   │ → 날짜 형식 오류       │    │ 에러 메시지 (bodySmall, red)
│  │ 4 │ 오사카..  │ 4/01-05│ ✅ │    │
│  │...│          │        │    │    │
│  └─────────────────────────────┘    │
│  성공: 147건 / 오류: 3건            │ bodyMedium, 색상 분기
│                                     │
│  [📥 오류 리포트 다운로드]           │ TextButton, semanticError
│                                     │
│  ┌─────────────────────────────┐    │
│  │    일괄 생성 (147건)          │    │ Button_Primary (b2bAccent)
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | backgroundColor: b2bAccent (#1565C0), title: "대량 여행 생성", leading: BackButton, actions: [도움말 아이콘] |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 드롭존 | `DottedBorder` + `GestureDetector` | border: dashed 2px b2bAccent (#1565C0), radius16, 배경: b2bAccent 5% opacity, 높이: 180dp |
| 파일 아이콘 | `Icon` | Icons.cloud_upload, size: 48, color: b2bAccent (#1565C0) |
| 샘플 다운로드 | `TextButton` | icon: Icons.download, text: "샘플 CSV 다운로드", color: b2bAccent |
| 업로드 진행 | `Card` + `LinearProgressIndicator` | Card_Standard, progressColor: b2bAccent (#1565C0), trackColor: outline (#EDEDED) |
| 파일 정보 | `Text` | 파일명 (`bodyLarge`), 파일 크기 (`bodySmall`), 진행률 (`bodySmall`) |
| 검증 결과 테이블 | `DataTable` | columns: [#, 여행명, 기간, 상태], sortable: true, 행 높이: 56dp |
| 성공 행 | `DataRow` | 배경: surface (#FFFFFF), trailing: Icons.check_circle (semanticSuccess) |
| 오류 행 | `DataRow` | 배경: semanticError 5% opacity, trailing: Icons.error (semanticError), 확장 시 에러 메시지 표시 |
| 결과 요약 | `Text` | "성공: N건" (semanticSuccess) + " / 오류: N건" (semanticError) |
| 오류 리포트 | `TextButton` | icon: Icons.download, text: "오류 리포트 다운로드", color: semanticError |
| 생성 버튼 | `ElevatedButton` | backgroundColor: b2bAccent (#1565C0), text: "일괄 생성 (N건)", style: Button_Primary |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 드롭존만 표시, 업로드 상태/검증 결과 영역 숨김 |
| 파일 드래그 오버 | 드롭존 보더 색상 b2bAccent 진하게, 배경 b2bAccent 10% opacity |
| 업로드 중 | 드롭존 → 파일 정보 카드 전환, LinearProgressIndicator 진행 표시 |
| 업로드 완료 | 파싱 중 스피너 표시, "N건 파싱 중..." 텍스트 |
| 검증 완료 (오류 0) | 결과 테이블 전체 녹색, "전체 N건 성공" 메시지, 생성 버튼 활성 |
| 검증 완료 (오류 > 0) | 오류 행 빨강 하이라이트, 오류 리포트 다운로드 링크 표시, 생성 버튼 "일괄 생성 (성공건수만)" |
| 파일 형식 오류 | SnackBar "CSV 형식의 파일만 업로드할 수 있습니다." |
| 생성 진행 중 | 생성 버튼 → CircularProgressIndicator, "생성 중... N/M건" 진행률 |
| 생성 완료 | Dialog_Confirm "N건의 여행이 생성되었습니다." + N-01 이동 옵션 |

**인터랙션**

- [탭] 드롭존 → 파일 피커 (FilePicker, CSV 필터) → 파일 선택
- [드래그&드롭] CSV 파일 → 드롭존 → 업로드 시작 (웹 환경)
- [탭] 샘플 CSV 다운로드 → 브라우저 다운로드 (trip_template.csv)
- [탭] 오류 행 → 확장하여 상세 에러 메시지 표시
- [탭] 오류 리포트 다운로드 → CSV 형식 에러 리포트 다운로드
- [탭] 일괄 생성 → POST /api/v1/b2b/trips/bulk → 성공 시 완료 다이얼로그
- [탭] 도움말 (?) → Modal_Bottom CSV 형식 안내 (컬럼 설명, 날짜 형식 등)
- [뒤로가기] → N-01 대시보드

---

### N-03 대량 초대 코드 (Invite Bulk)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | N-03 |
| 화면명 | 대량 초대 코드 (Invite Bulk) |
| Phase | P3 |
| 역할 | B2B 관리자 |
| 진입 경로 | N-01 대시보드 → 빠른 실행 / 사이드바 → N-03 |
| 이탈 경로 | N-03 → N-01 (발송 완료 시) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 대량 초대 코드           [?]    │ AppBar (b2bAccent)
├─────────────────────────────────────┤
│                                     │
│  초대 코드를 대량으로                │ headlineMedium (24sp, SemiBold)
│  생성하고 발송합니다                 │
│                                     │
│  ── Step 1: 파일 업로드 ──────       │ Step indicator (1/3)
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐ │
│  ╎       📁                      ╎ │ Dropzone (dotted border)
│  ╎   CSV 파일을 선택하세요        ╎ │
│  ╎   (이름, 이메일/전화번호,      ╎ │ bodySmall, onSurfaceVariant
│  ╎    여행ID)                    ╎ │
│  ╎   [📥 샘플 CSV 다운로드]       ╎ │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ │
│                                     │
│  ── Step 2: 미리보기 ────────────    │ Step indicator (2/3)
│  ┌─────────────────────────────┐    │
│  │ # │ 이름    │연락처    │여행 │    │ DataTable
│  ├─────────────────────────────┤    │
│  │ 1 │ 김민수  │ kim@..  │ T01│    │
│  │ 2 │ 이영희  │ 010-..  │ T01│    │
│  │ 3 │ 박지훈  │ invalid │ T02│    │ 오류 행 (semanticError)
│  │...│         │         │    │    │
│  └─────────────────────────────┘    │
│  전체: 50명 / 유효: 48명 / 오류: 2명 │ bodyMedium
│                                     │
│  ── Step 3: 발송 방법 ───────────    │ Step indicator (3/3)
│  ┌─────────────────────────────┐    │
│  │ ○ 이메일 발송                │    │ RadioListTile
│  │ ○ SMS 발송                  │    │ RadioListTile
│  │ ● 이메일 + SMS 동시 발송     │    │ RadioListTile (selected)
│  └─────────────────────────────┘    │
│                                     │
│  ── 발송 진행 ───────────────────    │
│  ┌─────────────────────────────┐    │
│  │ ████████████████░░  85%     │    │ LinearProgressIndicator
│  │ 41/48명 발송 완료            │    │ bodyMedium
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │    초대 코드 발송 (48명)      │    │ Button_Primary (b2bAccent)
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | backgroundColor: b2bAccent (#1565C0), title: "대량 초대 코드", leading: BackButton |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 스텝 인디케이터 | `Text` | style: titleMedium (18sp, SemiBold), "Step N:" prefix, b2bAccent 색상 |
| 드롭존 | `DottedBorder` + `GestureDetector` | border: dashed 2px b2bAccent, radius16, 높이: 140dp |
| 샘플 다운로드 | `TextButton` | icon: Icons.download, text: "샘플 CSV 다운로드", color: b2bAccent |
| 미리보기 테이블 | `DataTable` | columns: [#, 이름, 연락처, 여행], 최대 10행 표시 + "더 보기" |
| 오류 행 | `DataRow` | 배경: semanticError 5% opacity, 연락처 셀 빨강 텍스트 |
| 요약 텍스트 | `Text` | "전체: N명" (onSurface) + " / 유효: N명" (semanticSuccess) + " / 오류: N명" (semanticError) |
| 발송 방법 | `RadioListTile` x 3 | activeColor: b2bAccent (#1565C0), groupValue: deliveryMethod |
| 발송 진행 | `Card` + `LinearProgressIndicator` | progressColor: b2bAccent, 텍스트: "N/M명 발송 완료" |
| 발송 버튼 | `ElevatedButton` | backgroundColor: b2bAccent (#1565C0), text: "초대 코드 발송 (N명)" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | Step 1 드롭존만 활성, Step 2~3 비활성 (opacity 0.4) |
| 파일 업로드 완료 | Step 1 완료 체크 (✅), Step 2 미리보기 테이블 활성 |
| 검증 완료 (오류 0) | 전체 유효, 발송 방법 선택 활성화 |
| 검증 완료 (오류 > 0) | 오류 행 빨강 하이라이트, "오류 제외 후 발송" 안내 |
| 발송 방법 선택 완료 | 발송 버튼 활성 (b2bAccent) |
| 발송 중 | 발송 버튼 비활성, 발송 진행 바 표시, 실시간 카운트 업데이트 |
| 발송 완료 | Dialog_Confirm "N명에게 초대 코드가 발송되었습니다." + 결과 요약 |
| 발송 일부 실패 | 결과 요약에 실패 건수 표시, "실패 목록 다운로드" 링크 |

**인터랙션**

- [탭] 드롭존 → 파일 피커 (CSV 필터) → 파일 선택 → 자동 파싱
- [탭] 샘플 CSV 다운로드 → invite_template.csv 다운로드
- [탭] 발송 방법 라디오 → 선택값 변경 (email / sms / both)
- [탭] 초대 코드 발송 → POST /api/v1/b2b/invites/bulk → 발송 진행 표시
- [탭] 오류 행 → 상세 에러 메시지 확장
- [탭] 도움말 (?) → Modal_Bottom CSV 형식 안내
- [뒤로가기] → N-01 대시보드

---

### N-04 대량 가디언 연결 (Guardian Bulk)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | N-04 |
| 화면명 | 대량 가디언 연결 (Guardian Bulk) |
| Phase | P3 |
| 역할 | B2B 관리자 |
| 진입 경로 | N-01 대시보드 → 빠른 실행 / 사이드바 → N-04 |
| 이탈 경로 | N-04 → N-01 (연결 완료 시) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 대량 가디언 연결          [?]   │ AppBar (b2bAccent)
├─────────────────────────────────────┤
│                                     │
│  멤버-가디언 매핑을                  │ headlineMedium (24sp, SemiBold)
│  일괄 등록합니다                     │
│                                     │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐ │
│  ╎       📁                      ╎ │ Dropzone (dotted border)
│  ╎   멤버-가디언 매핑 CSV         ╎ │
│  ╎   (멤버이름, 멤버전화,         ╎ │ bodySmall
│  ╎    가디언이름, 가디언전화)      ╎ │
│  ╎   [📥 샘플 CSV 다운로드]       ╎ │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ │
│                                     │
│  ── 동의 추적 현황 ─────────────     │ Section header
│  ┌─────────────────────────────┐    │
│  │ 전체: 50건                   │    │ 요약 바
│  │ ███████░░░░░░░░             │    │ SegmentedProgressBar
│  │ ✅ 수락 12  ⏳ 대기 30       │    │ (green/amber/gray/red)
│  │ 📨 발송 5   ❌ 거절 3        │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ # │멤버    │가디언  │ 상태  │    │ DataTable
│  ├─────────────────────────────┤    │
│  │ 1 │김민수  │김부모  │ ✅수락│    │ Chip_Tag (green)
│  │ 2 │이영희  │이부모  │ ⏳대기│    │ Chip_Tag (amber)
│  │ 3 │박지훈  │박부모  │ 📨발송│    │ Chip_Tag (blue)
│  │ 4 │최서연  │최부모  │ ❌거절│    │ Chip_Tag (red)
│  │...│        │       │      │    │
│  └─────────────────────────────┘    │
│  ◀ 1 2 3 ... 5 ▶                   │ Pagination
│                                     │
│  ┌──────────────┐ ┌──────────────┐  │
│  │ 대기 건 재발송 │ │ 결과 다운로드 │  │ Button_Secondary x 2
│  └──────────────┘ └──────────────┘  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │    동의 요청 발송 (30건)      │    │ Button_Primary (b2bAccent)
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | backgroundColor: b2bAccent (#1565C0), title: "대량 가디언 연결", leading: BackButton |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 드롭존 | `DottedBorder` + `GestureDetector` | border: dashed 2px b2bAccent, radius16, 높이: 140dp |
| 동의 요약 바 | `Card` + `SegmentedProgressBar` | 4색 세그먼트: semanticSuccess (수락) / secondaryAmber (대기) / b2bAccent (발송) / semanticError (거절) |
| 동의 추적 테이블 | `DataTable` | columns: [#, 멤버, 가디언, 상태], sortable: true, 페이지네이션 |
| 상태 칩 (수락) | `Chip` | backgroundColor: semanticSuccess 10%, text: "수락", textColor: semanticSuccess |
| 상태 칩 (대기) | `Chip` | backgroundColor: secondaryAmber 10%, text: "대기", textColor: secondaryAmber |
| 상태 칩 (발송) | `Chip` | backgroundColor: b2bAccent 10%, text: "발송", textColor: b2bAccent |
| 상태 칩 (거절) | `Chip` | backgroundColor: semanticError 10%, text: "거절", textColor: semanticError |
| 페이지네이션 | `Row` | 이전/다음 `IconButton` + 페이지 번호 `Text` |
| 재발송 버튼 | `OutlinedButton` | style: Button_Secondary, borderColor: b2bAccent, text: "대기 건 재발송" |
| 결과 다운로드 | `OutlinedButton` | style: Button_Secondary, icon: Icons.download, text: "결과 다운로드" |
| 동의 요청 버튼 | `ElevatedButton` | backgroundColor: b2bAccent (#1565C0), text: "동의 요청 발송 (N건)" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 드롭존만 표시, 동의 추적 영역 숨김 |
| CSV 업로드 완료 | 드롭존 축소, 매핑 검증 결과 테이블 표시 |
| 동의 요청 미발송 | 상태 전체 "발송 전", 동의 요청 버튼 활성 |
| 동의 요청 발송 완료 | 상태 "발송"으로 변경, 실시간 상태 갱신 (10초 폴링) |
| 일부 수락 | 수락 건 녹색, 진행 바 업데이트 |
| 일부 거절 | 거절 건 빨강, 사유 표시 (탭으로 확장) |
| 전체 수락 완료 | 축하 배너 "전체 가디언 연결이 완료되었습니다" |
| 대기 건 재발송 | 재발송 확인 Dialog_Confirm → 발송 진행 표시 |

**인터랙션**

- [탭] 드롭존 → 파일 피커 (CSV 필터) → 파일 선택 → 자동 파싱
- [탭] 샘플 CSV 다운로드 → guardian_mapping_template.csv 다운로드
- [탭] 동의 요청 발송 → POST /api/v1/b2b/guardians/bulk → SMS/이메일 동의 요청
- [탭] 대기 건 재발송 → Dialog_Confirm "대기 중인 N건에 동의 요청을 재발송하시겠습니까?" → 확인 시 재발송
- [탭] 결과 다운로드 → CSV 형식 동의 추적 결과 다운로드
- [탭] 테이블 행 → 해당 멤버-가디언 상세 Modal_Bottom (연락처, 발송 이력, 상태 변경 히스토리)
- [탭] 도움말 (?) → Modal_Bottom CSV 형식 및 동의 프로세스 안내
- [뒤로가기] → N-01 대시보드

---

### N-05 계약 관리 (Contract Manage)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | N-05 |
| 화면명 | 계약 관리 (Contract Manage) |
| Phase | P3 |
| 역할 | B2B 관리자 |
| 진입 경로 | N-01 대시보드 → 사이드바 → N-05 |
| 이탈 경로 | N-05 → N-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 계약 관리                       │ AppBar (b2bAccent)
├─────────────────────────────────────┤
│                                     │
│  ── 계약 정보 ───────────────────    │ Section header
│  ┌─────────────────────────────┐    │
│  │ 계약 유형                    │    │ Card_Standard, elevation 2
│  │ ┌──────────────────────┐    │    │
│  │ │  🏫 학교              │    │    │ Badge (b2bAccent bg, white text)
│  │ └──────────────────────┘    │    │
│  │                             │    │
│  │ 계약 기간                    │    │ bodySmall (라벨)
│  │ 2026-01-01 ~ 2026-12-31     │    │ bodyLarge (값)
│  │                             │    │
│  │ 잔여 기간                    │    │
│  │ 304일 남음                   │    │ bodyLarge, b2bAccent
│  │ ████████████████░░░░  83%   │    │ LinearProgressIndicator
│  │                             │    │
│  │ ──────────────────────────  │    │ Divider
│  │                             │    │
│  │ 이용 가능 여행 수             │    │ bodySmall (라벨)
│  │ 38 / 50                     │    │ bodyLarge (잔여/전체)
│  │ ██████████████░░░░░░  76%   │    │ LinearProgressIndicator
│  │                             │    │
│  │ 이용 가능 멤버 수             │    │
│  │ 812 / 1000                  │    │ bodyLarge
│  │ ████████████████░░░░  81%   │    │ LinearProgressIndicator
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  ── 결제 정보 ───────────────────    │ Section header
│  ┌─────────────────────────────┐    │
│  │ 플랜                        │    │ Card_Standard
│  │ Enterprise (연간)            │    │ titleMedium, b2bAccent
│  │                             │    │
│  │ 결제 금액                    │    │
│  │ ₩12,000,000 / 연             │    │ headlineMedium, onSurface
│  │                             │    │
│  │ 다음 결제일                   │    │
│  │ 2027-01-01                   │    │ bodyLarge
│  │                             │    │
│  │ 결제 수단                    │    │
│  │ 법인카드 **** 1234           │    │ bodyLarge
│  └─────────────────────────────┘    │
│                                     │
│  ── 사용량 추이 ─────────────────    │ Section header
│  ┌─────────────────────────────┐    │
│  │  LineChart                  │    │ 월별 여행/멤버 사용량
│  │     .    .                  │    │
│  │  .    .    .                │    │
│  │  1  2  3  4  5  (월)        │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │    계약 갱신 요청             │    │ Button_Primary (b2bAccent)
│  └─────────────────────────────┘    │
│                                     │
│  결제 내역 조회 >                    │ TextButton, b2bAccent
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | backgroundColor: b2bAccent (#1565C0), title: "계약 관리", leading: BackButton |
| 계약 유형 뱃지 | `Container` (pill) | backgroundColor: b2bAccent (#1565C0), text: 유형명 (학교/여행사/기업), textColor: #FFFFFF, radius48 |
| 계약 기간 라벨 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 계약 기간 값 | `Text` | style: bodyLarge (16sp), color: onSurface |
| 잔여 기간 | `Text` | style: bodyLarge (16sp), color: b2bAccent (#1565C0) |
| 진행 바 (잔여 기간) | `LinearProgressIndicator` | value: 잔여일/전체일, color: b2bAccent, trackColor: outline |
| 진행 바 (여행 수) | `LinearProgressIndicator` | value: 사용/전체, color: b2bAccent, 80% 이상 시 secondaryAmber, 95% 이상 시 semanticError |
| 진행 바 (멤버 수) | `LinearProgressIndicator` | value: 사용/전체, color: b2bAccent, 임계값 동일 |
| 플랜 라벨 | `Text` | style: titleMedium (18sp, SemiBold), color: b2bAccent |
| 결제 금액 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 사용량 차트 | `LineChart` (fl_chart) | line1: b2bAccent (여행), line2: b2bAccentLight (멤버), 월별 데이터 |
| 갱신 요청 버튼 | `ElevatedButton` | backgroundColor: b2bAccent (#1565C0), text: "계약 갱신 요청" |
| 결제 내역 링크 | `TextButton` | style: bodyMedium, color: b2bAccent, trailing: chevron_right |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 로딩 | 카드 영역 Shimmer 효과 |
| 데이터 로드 완료 | 계약 정보 및 진행 바 표시 |
| 잔여 여행 80% 이상 사용 | 여행 진행 바 secondaryAmber, "한도 도달이 가까워지고 있습니다" 경고 배너 |
| 잔여 여행 95% 이상 사용 | 여행 진행 바 semanticError, Card_Alert 경고 "여행 생성 한도에 도달하였습니다" |
| 잔여 멤버 95% 이상 사용 | 멤버 진행 바 semanticError, 경고 배너 |
| 계약 만료 30일 이내 | 상단 Card_Alert "계약 만료가 30일 이내입니다. 갱신을 요청해주세요." |
| 계약 만료 | 전체 화면 비활성 상태, "계약이 만료되었습니다" 오버레이, 갱신 요청 버튼만 활성 |
| 갱신 요청 성공 | SnackBar "갱신 요청이 전송되었습니다. 담당자가 연락드리겠습니다." |

**인터랙션**

- [스크롤] 화면 전체 → SingleChildScrollView
- [탭] 계약 갱신 요청 → Dialog_Confirm "계약 갱신을 요청하시겠습니까?" → POST /api/v1/b2b/contracts/renew
- [탭] 결제 내역 조회 → 결제 내역 리스트 화면 (Modal_Bottom, 날짜/금액/상태)
- [탭] 계약 유형 뱃지 → 계약 유형별 혜택 비교 Modal_Bottom
- [뒤로가기] → N-01 대시보드

---

### N-06 안전 리포트 (Safety Report)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | N-06 |
| 화면명 | 안전 리포트 (Safety Report) |
| Phase | P3 |
| 역할 | B2B 관리자 |
| 진입 경로 | N-01 대시보드 → 빠른 실행 / 사이드바 → N-06 |
| 이탈 경로 | N-06 → N-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 안전 리포트           [📥 PDF]  │ AppBar (b2bAccent)
├─────────────────────────────────────┤
│                                     │
│  ── 기간 필터 ───────────────────    │
│  ┌──────────┐  ~  ┌──────────┐     │ DateRangePicker
│  │ 2026-02-01│     │ 2026-02-28│    │ Input_Text (date)
│  └──────────┘     └──────────┘     │
│  [최근 7일] [최근 30일] [전체]       │ Chip_Tag filter group
│                                     │
│  ── 여행 선택 ───────────────────    │
│  ┌─────────────────────────────┐    │
│  │ 전체 여행              ▼    │    │ DropdownButton
│  └─────────────────────────────┘    │
│                                     │
│  ── SOS 발생 현황 ──────────────     │ Section header
│  ┌─────────────────────────────┐    │
│  │ 🚨 SOS 발생              3건│    │ Card_Standard, elevation 2
│  │                             │    │
│  │ 유형별                      │    │
│  │ ■ 안전위험  2건              │    │ semanticError dot
│  │ ■ 건강위기  1건              │    │ secondaryAmber dot
│  │ ■ 분실/도난 0건              │    │ onSurfaceVariant dot
│  │                             │    │
│  │ 평균 응답 시간: 2분 34초      │    │ bodyMedium
│  └─────────────────────────────┘    │
│                                     │
│  ── 위치 추적 통계 ─────────────     │ Section header
│  ┌─────────────────────────────┐    │
│  │ 📍 위치 공유율           92% │    │ Card_Standard
│  │ ████████████████████░░  92% │    │ LinearProgressIndicator
│  │                             │    │
│  │ 평균 위치 업데이트 주기       │    │
│  │ 38초                        │    │ bodyLarge, b2bAccent
│  └─────────────────────────────┘    │
│                                     │
│  ── 출석 현황 ───────────────────    │ Section header
│  ┌─────────────────────────────┐    │
│  │ ✅ 전체 출석률          94.2%│    │ Card_Standard
│  │ ████████████████████░░ 94.2%│    │ LinearProgressIndicator
│  │                             │    │
│  │ 일별 출석률 추이             │    │
│  │  LineChart                  │    │ fl_chart LineChart
│  │  .  .  .  .  .  .  .       │    │ b2bAccent line
│  │  월 화 수 목 금 토 일       │    │
│  └─────────────────────────────┘    │
│                                     │
│  ── 지오펜스 이벤트 ────────────     │ Section header
│  ┌─────────────────────────────┐    │
│  │ ⚠️ 지오펜스 이탈          7건│    │ Card_Standard
│  │                             │    │
│  │ # │ 멤버   │ 시각   │ 유형 │    │ DataTable (compact)
│  ├─────────────────────────────┤    │
│  │ 1 │ 김민수 │ 14:22 │ 이탈 │    │
│  │ 2 │ 이영희 │ 15:03 │ 복귀 │    │
│  │...│        │       │     │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │    📥 PDF 리포트 내보내기     │    │ Button_Primary (b2bAccent)
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | backgroundColor: b2bAccent (#1565C0), title: "안전 리포트", actions: [PDF 내보내기 아이콘] |
| 날짜 필터 | `Row` < `TextField` (date) x 2 > | style: Input_Text, suffixIcon: Icons.calendar_today, onTap: showDatePicker |
| 기간 칩 | `Chip` x 3 | style: Chip_Tag, selected: b2bAccent bg + white text, unselected: surfaceVariant bg |
| 여행 선택 | `DropdownButtonFormField` | items: 전체 여행 목록, value: "전체 여행" |
| SOS 카드 | `Card` | style: Card_Standard, elevation: 2, 좌측 4px 보더: semanticError |
| SOS 유형 리스트 | `Column` < `Row` > | 색상 점 (8dp) + 유형명 (`bodyMedium`) + 건수 (`bodyMedium`, Bold) |
| 위치 추적 카드 | `Card` + `LinearProgressIndicator` | Card_Standard, progressColor: b2bAccent |
| 출석 현황 카드 | `Card` + `LineChart` | Card_Standard, 일별 출석률 라인 차트 |
| 지오펜스 카드 | `Card` + `DataTable` | Card_Standard, compact DataTable (4 columns), 좌측 보더: secondaryAmber |
| PDF 버튼 | `ElevatedButton` | backgroundColor: b2bAccent (#1565C0), icon: Icons.picture_as_pdf, text: "PDF 리포트 내보내기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 로딩 | 전체 카드 Shimmer 효과, 기본 기간: 최근 30일 |
| 데이터 로드 완료 | 모든 통계 카드 및 차트 표시 |
| SOS 발생 0건 | SOS 카드 "SOS 발생 없음" 안내, semanticSuccess 아이콘 |
| SOS 발생 > 0 | SOS 카드 좌측 빨강 보더, 건수 Bold + semanticError 색상 |
| 기간 변경 | 로딩 스피너 → 데이터 재로드 → 차트/통계 업데이트 |
| 여행 선택 변경 | 해당 여행 데이터만 필터링하여 재표시 |
| PDF 내보내기 중 | 버튼 → CircularProgressIndicator, "PDF 생성 중..." |
| PDF 내보내기 완료 | SnackBar "PDF가 다운로드되었습니다." + 파일 공유 옵션 |
| 데이터 없음 | "선택한 기간에 데이터가 없습니다." 안내 (빈 상태 일러스트) |

**인터랙션**

- [탭] 날짜 필터 → DateRangePicker 표시 → 기간 선택 → 데이터 재로드
- [탭] 기간 칩 (최근 7일 / 30일 / 전체) → 해당 기간 자동 적용
- [탭] 여행 드롭다운 → 여행 선택 → 해당 여행 데이터 필터링
- [탭] SOS 카드 → 확장하여 SOS 발생 상세 리스트 표시
- [탭] 지오펜스 이벤트 행 → 해당 이벤트 상세 (멤버, 위치, 시각, 지오펜스 영역)
- [탭] PDF 리포트 내보내기 → GET /api/v1/b2b/reports/safety/pdf → 파일 다운로드
- [탭] 앱바 PDF 아이콘 → PDF 내보내기 (동일)
- [뒤로가기] → N-01 대시보드

---

### N-07 멤버 관리 (B2B Member List)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | N-07 |
| 화면명 | 멤버 관리 (B2B Member List) |
| Phase | P3 |
| 역할 | B2B 관리자 |
| 진입 경로 | N-01 대시보드 → 사이드바 / 통계 카드 탭 → N-07 |
| 이탈 경로 | N-07 → N-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 멤버 관리                [⋮]   │ AppBar (b2bAccent)
├─────────────────────────────────────┤
│                                     │
│  전체 멤버: 348명                    │ titleLarge, onSurface
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🔍 멤버 검색...              │    │ Input_Search
│  └─────────────────────────────┘    │
│                                     │
│  ── 필터 ────────────────────────    │
│  [전체여행 ▼] [전체역할 ▼] [전체상태▼]│ FilterChip x 3
│                                     │
│  ── 일괄 작업 ───────────────────    │
│  ☐ 전체 선택 (348명)                │ Checkbox + label
│  [역할 변경] [멤버 제거]  disabled    │ ActionChip x 2 (선택 시 활성)
│                                     │
│  ┌─────────────────────────────┐    │
│  │☐│이름   │여행  │역할 │상태 │    │ DataTable (selectable rows)
│  ├─────────────────────────────┤    │
│  │☐│김민수 │제주..│캡틴 │활성 │    │ Badge_Role (teal)
│  │☐│이영희 │제주..│크루 │활성 │    │ Badge_Role (gray)
│  │☐│박지훈 │부산..│크루장│활성 │    │ Badge_Role (teal dark)
│  │☐│최서연 │도쿄..│크루 │비활성│    │ 비활성: onSurfaceVariant
│  │☐│정다혜 │오사카│가디언│활성 │    │ Badge_Role (soft green)
│  │...│      │     │    │    │    │
│  └─────────────────────────────┘    │
│  ◀ 1 2 3 ... 35 ▶                  │ Pagination
│  페이지당: [10 ▼] 건                │ DropdownButton
│                                     │
│  ── 선택된 멤버: 3명 ────────────    │ 선택 시 하단 Action Bar 표시
│  ┌──────────────┐ ┌──────────────┐  │
│  │  역할 변경    │ │  멤버 제거    │  │ Button_Secondary + Button_Destructive
│  └──────────────┘ └──────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | backgroundColor: b2bAccent (#1565C0), title: "멤버 관리", actions: [더보기 메뉴] |
| 전체 멤버 수 | `Text` | style: titleLarge (20sp, SemiBold), color: onSurface |
| 검색 필드 | `TextField` | style: Input_Search, hintText: "멤버 검색...", prefixIcon: Icons.search |
| 필터 칩 (여행) | `FilterChip` + `DropdownButton` | text: "전체 여행", items: 여행 목록, selectedColor: b2bAccent |
| 필터 칩 (역할) | `FilterChip` + `DropdownButton` | text: "전체 역할", items: [캡틴, 크루장, 크루, 가디언] |
| 필터 칩 (상태) | `FilterChip` + `DropdownButton` | text: "전체 상태", items: [활성, 비활성] |
| 전체 선택 | `Checkbox` + `Text` | label: "전체 선택 (N명)", activeColor: b2bAccent |
| 데이터 테이블 | `DataTable` | columns: [선택, 이름, 여행, 역할, 상태], selectable: true, sortable: true |
| 역할 뱃지 | `Container` (pill) | style: Badge_Role (캡틴 #00A2BD / 크루장 #015572 / 크루 #898989 / 가디언 #15A1A5) |
| 페이지네이션 | `Row` | 이전/다음 `IconButton` + 페이지 번호 + 페이지당 건수 드롭다운 |
| 역할 변경 버튼 | `OutlinedButton` | style: Button_Secondary, borderColor: b2bAccent, text: "역할 변경", enabled: 선택 > 0 |
| 멤버 제거 버튼 | `ElevatedButton` | style: Button_Destructive, text: "멤버 제거", enabled: 선택 > 0 |
| 더보기 메뉴 | `PopupMenuButton` | items: [CSV 내보내기, 전체 이메일 발송] |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 로딩 | DataTable Shimmer 효과, 필터 기본값 "전체" |
| 데이터 로드 완료 | 테이블 데이터 표시, 총 멤버 수 업데이트 |
| 검색 입력 | 디바운스 300ms 후 필터링, 매칭 텍스트 하이라이트 |
| 필터 적용 | 테이블 데이터 필터링, 총 멤버 수 업데이트 ("필터 결과: N명") |
| 멤버 미선택 | 일괄 작업 버튼 비활성 (opacity 0.4), 하단 Action Bar 숨김 |
| 멤버 1개 이상 선택 | 하단 Action Bar 표시, "선택된 멤버: N명" + 역할 변경/제거 버튼 활성 |
| 전체 선택 | 현재 페이지 전체 체크, "전체 N명 선택" 확인 배너 |
| 역할 변경 | Modal_Bottom (역할 선택 리스트) → 확인 → 변경 반영 |
| 멤버 제거 | Dialog_Confirm "선택한 N명을 제거하시겠습니까?" → 확인 시 제거 |
| 데이터 없음 (필터 결과) | "조건에 맞는 멤버가 없습니다" 빈 상태 표시 |

**인터랙션**

- [입력] 검색 필드 → 디바운스 300ms → GET /api/v1/b2b/members?q=검색어 → 테이블 업데이트
- [탭] 필터 칩 → DropdownButton 표시 → 선택 → 테이블 필터링
- [탭] 체크박스 (행) → 해당 행 선택/해제
- [탭] 전체 선택 체크박스 → 현재 페이지 전체 선택/해제
- [탭] 역할 변경 → Modal_Bottom 역할 목록 → 선택 → PATCH /api/v1/b2b/members/bulk-role
- [탭] 멤버 제거 → Dialog_Confirm → DELETE /api/v1/b2b/members/bulk-remove
- [탭] 테이블 행 (체크박스 외) → 멤버 상세 Modal_Bottom (프로필, 참여 여행 목록, 활동 이력)
- [탭] 컬럼 헤더 → 해당 컬럼 정렬 (오름차순/내림차순 토글)
- [탭] 더보기 메뉴 → CSV 내보내기 / 전체 이메일 발송
- [탭] 페이지네이션 → 페이지 이동
- [뒤로가기] → N-01 대시보드

---

### N-08 조직 브랜딩 (B2B Branding)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | N-08 |
| 화면명 | 조직 브랜딩 (B2B Branding) |
| Phase | P3 |
| 역할 | B2B 관리자 |
| 진입 경로 | N-01 대시보드 → 사이드바 → N-08 |
| 이탈 경로 | N-08 → N-01 (저장 완료 / 뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────────┐
│ [←] 조직 브랜딩                     │ AppBar (b2bAccent)
├─────────────────────────────────────┤
│                                     │
│  조직의 브랜드 정보를                │ headlineMedium (24sp, SemiBold)
│  설정합니다                          │
│                                     │
│  ── 로고 ────────────────────────    │ Section header
│  ┌─────────────────────────────┐    │
│  │                             │    │ Card_Standard
│  │     ┌──────────────┐        │    │
│  │     │              │        │    │
│  │     │  조직 로고    │        │    │ Image placeholder
│  │     │  120 x 120   │        │    │ GestureDetector + Container
│  │     │     📷       │        │    │ dotted border when empty
│  │     │              │        │    │
│  │     └──────────────┘        │    │
│  │     로고 업로드               │    │ TextButton, b2bAccent
│  │     PNG/SVG, 최대 2MB        │    │ bodySmall, onSurfaceVariant
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  ── 조직 정보 ───────────────────    │ Section header
│  ┌─────────────────────────────┐    │
│  │ 조직명                      │    │ Card_Standard
│  │ ┌─────────────────────────┐ │    │
│  │ │ 한국국제학교              │ │    │ Input_Text
│  │ └─────────────────────────┘ │    │
│  │                             │    │
│  │ 환영 메시지                  │    │
│  │ ┌─────────────────────────┐ │    │
│  │ │ 한국국제학교와 함께하는   │ │    │ Input_Text (multiline)
│  │ │ 안전한 수학여행           │ │    │ maxLines: 3
│  │ └─────────────────────────┘ │    │
│  │                             │    │
│  │ 주요 색상 (Primary Color)    │    │
│  │ ┌────┐ #1565C0              │    │ ColorPicker swatch
│  │ │████│ [색상 변경]           │    │ Container (32x32) + TextButton
│  │ └────┘                      │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  ── 미리보기 ────────────────────    │ Section header
│  ┌─────────────────────────────┐    │
│  │ ┌───────────────────────┐   │    │ Preview Card
│  │ │                       │   │    │ 실제 브랜딩 적용 미리보기
│  │ │   ┌────────┐          │   │    │
│  │ │   │ 로고    │          │   │    │ 조직 로고 (64x64)
│  │ │   └────────┘          │   │    │
│  │ │                       │   │    │
│  │ │  한국국제학교           │   │    │ 조직명 (titleLarge)
│  │ │                       │   │    │ 주요 색상 적용
│  │ │  한국국제학교와 함께하는 │   │    │ 환영 메시지 (bodyMedium)
│  │ │  안전한 수학여행        │   │    │
│  │ │                       │   │    │
│  │ │  ┌─────────────────┐  │   │    │
│  │ │  │  SafeTrip 시작   │  │   │    │ 미리보기 CTA (주요 색상 bg)
│  │ │  └─────────────────┘  │   │    │
│  │ │                       │   │    │
│  │ └───────────────────────┘   │    │
│  │                             │    │
│  │ 이 화면은 멤버가 초대 링크를  │    │ bodySmall, onSurfaceVariant
│  │ 통해 접속했을 때 보게 됩니다  │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │    저장                      │    │ Button_Primary (b2bAccent)
│  └─────────────────────────────┘    │
│                                     │
│  기본값으로 초기화 >                 │ TextButton, onSurfaceVariant
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | backgroundColor: b2bAccent (#1565C0), title: "조직 브랜딩", leading: BackButton |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 로고 영역 | `GestureDetector` + `Container` | size: 120x120, border: dashed 2px b2bAccent (empty) / solid 1px outline (filled), radius16 |
| 로고 업로드 | `TextButton` | text: "로고 업로드", color: b2bAccent, onTap: ImagePicker |
| 파일 제한 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, "PNG/SVG, 최대 2MB" |
| 조직명 입력 | `TextFormField` | style: Input_Text, hintText: "조직명을 입력하세요", validator: 필수 (2~50자) |
| 환영 메시지 입력 | `TextFormField` | style: Input_Text, maxLines: 3, hintText: "멤버에게 보여질 환영 메시지", maxLength: 100 |
| 색상 미리보기 | `Container` | size: 32x32, color: 선택된 색상, radius8, border: 1px outline |
| 색상 변경 버튼 | `TextButton` | text: "색상 변경", color: b2bAccent, onTap: showColorPicker |
| 미리보기 카드 | `Card` | style: Card_Standard, elevation: 3, 내부에 브랜딩 적용된 스플래시 스타일 레이아웃 |
| 미리보기 로고 | `Image` | width: 64, height: 64, 업로드된 로고 또는 기본 아이콘 |
| 미리보기 조직명 | `Text` | style: titleLarge (20sp, SemiBold), color: 주요 색상 |
| 미리보기 메시지 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 미리보기 CTA | `Container` | backgroundColor: 주요 색상, text: "SafeTrip 시작", radius12 |
| 미리보기 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 저장 버튼 | `ElevatedButton` | backgroundColor: b2bAccent (#1565C0), text: "저장" |
| 초기화 링크 | `TextButton` | text: "기본값으로 초기화", color: onSurfaceVariant |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (데이터 없음) | 기본 아이콘 로고, 빈 조직명/메시지, 기본 색상 b2bAccent (#1565C0) |
| 초기 (기존 데이터) | 저장된 로고/조직명/메시지/색상 로드, 미리보기 자동 렌더링 |
| 로고 업로드 중 | 로고 영역 로딩 스피너, 업로드 진행률 표시 |
| 로고 업로드 완료 | 로고 영역에 이미지 표시, 미리보기 즉시 반영 |
| 로고 파일 오류 | SnackBar "PNG 또는 SVG 형식의 2MB 이하 파일만 업로드할 수 있습니다." |
| 조직명 입력 | 미리보기 카드 조직명 실시간 반영 |
| 환영 메시지 입력 | 미리보기 카드 메시지 실시간 반영, 잔여 글자수 표시 (100자 제한) |
| 색상 변경 | ColorPicker Modal_Bottom → 색상 선택 → 미리보기 CTA/조직명 색상 즉시 반영 |
| 변경 사항 있음 | 저장 버튼 활성 (b2bAccent), 뒤로가기 시 "저장하지 않은 변경 사항이 있습니다" 확인 |
| 변경 사항 없음 | 저장 버튼 비활성 (opacity 0.4) |
| 저장 중 | 저장 버튼 → CircularProgressIndicator |
| 저장 성공 | SnackBar "브랜딩 설정이 저장되었습니다." |
| 저장 실패 | SnackBar "저장에 실패했습니다. 다시 시도해주세요." |
| 기본값 초기화 | Dialog_Confirm "브랜딩 설정을 기본값으로 초기화하시겠습니까?" → 확인 시 기본 로고/색상 복원 |

**인터랙션**

- [탭] 로고 영역 / 로고 업로드 → ImagePicker (카메라/갤러리/파일) → 이미지 크롭 → 업로드
- [입력] 조직명 → 미리보기 카드 조직명 실시간 반영
- [입력] 환영 메시지 → 미리보기 카드 메시지 실시간 반영
- [탭] 색상 변경 → Modal_Bottom ColorPicker (프리셋 8색 + 커스텀 HEX 입력) → 선택 → 미리보기 반영
- [탭] 저장 → PUT /api/v1/b2b/branding → 성공 시 SnackBar
- [탭] 기본값으로 초기화 → Dialog_Confirm → 확인 시 기본 브랜딩으로 복원
- [뒤로가기] → 변경 사항 있으면 Dialog_Confirm "저장하지 않은 변경 사항이 있습니다" → N-01 대시보드

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 8개 화면 (N-01 ~ N-08) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
