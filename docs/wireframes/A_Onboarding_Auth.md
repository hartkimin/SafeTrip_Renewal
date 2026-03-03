# A. 온보딩 & 인증

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 온보딩 및 인증 플로우 7개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 온보딩 UX 시나리오 | `Master_docs/14_T3_온보딩_UX_시나리오.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 7개 (A-01 ~ A-07)
- **Phase:** 전체 P0
- **핵심 역할:** 신규 사용자 (크루/가디언 선택 전)
- **연관 문서:** `Master_docs/14_T3_온보딩_UX_시나리오.md`

---

## User Journey Flow

```
A-01 Splash
 ├── [토큰 유효] ─────────────────────────────→ C-01 메인맵
 └── [첫 실행 / 토큰 만료]
      ↓
A-02 웰컴 온보딩 (3~4페이지 스와이프)
      ↓
A-03 역할 선택
      ├── [크루 선택] ──→ A-07 약관 동의 → A-04 전화번호 인증
      └── [가디언 선택] ─→ A-07 약관 동의 → A-04 전화번호 인증
                                                ↓
                                          A-05 OTP 인증
                                                ↓
                                          A-06 프로필 설정
                                           ├── [크루 완료] → C-01 메인맵
                                           └── [가디언 완료] → F-04 가디언홈
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| A-01 | 토큰 유효 | C-01 메인맵 | C |
| A-06 | 크루 프로필 완료 | C-01 메인맵 | C |
| A-06 | 가디언 프로필 완료 | F-04 가디언홈 | F |
| 외부 딥링크 | 초대코드/가디언 초대 | A-01 → A-04 | A (인증 직행) |

---

## 화면 상세

---

### A-01 스플래시 (Splash)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | A-01 |
| 화면명 | 스플래시 (Splash) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | 앱 실행 → A-01 |
| 이탈 경로 | A-01 → C-01 (토큰 유효) / A-01 → A-02 (첫 실행/토큰 만료) |

**레이아웃**

```
┌─────────────────────────────┐
│                             │
│                             │
│                             │
│                             │
│                             │
│        ┌───────────┐        │
│        │           │        │
│        │  SafeTrip  │        │ Image (app logo)
│        │   Logo    │        │
│        │           │        │
│        └───────────┘        │
│                             │
│         SafeTrip            │ displayLarge, primaryTeal
│    안전한 여행의 시작          │ bodyMedium, onSurfaceVariant
│                             │
│                             │
│          ◌ ◌ ◌              │ CircularProgressIndicator
│                             │
│                             │
│                             │
│    v1.0.0                   │ bodySmall, onSurfaceVariant
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱 로고 | `Image.asset` | width: 120, height: 120, 중앙 정렬 |
| 앱 이름 | `Text` | style: displayLarge (36sp, Bold 700), color: primaryTeal |
| 서브 타이틀 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 로딩 인디케이터 | `CircularProgressIndicator` | color: primaryTeal, strokeWidth: 2.0 |
| 버전 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 로고 페이드인 애니메이션 (300ms) + 로딩 인디케이터 표시 |
| 토큰 확인 중 | 로딩 인디케이터 회전 (1~2초) |
| 토큰 유효 | Navigator.pushReplacement → C-01 메인맵 |
| 토큰 만료/없음 | Navigator.pushReplacement → A-02 웰컴 온보딩 |
| 네트워크 오류 | SnackBar "인터넷 연결을 확인해주세요" + 재시도 버튼 |

**인터랙션**

- [자동] 앱 실행 → 토큰 유효성 검사 (GET /api/v1/auth/verify-token)
- [자동] 토큰 유효 → 2초 후 C-01로 자동 이동
- [자동] 토큰 없음/만료 → 2초 후 A-02로 자동 이동
- [자동] 딥링크 파라미터 → SharedPreferences에 보존 후 분기

---

### A-02 웰컴 온보딩 (Welcome Onboarding)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | A-02 |
| 화면명 | 웰컴 온보딩 (Welcome Onboarding) |
| Phase | P0 |
| 역할 | 신규 사용자 |
| 진입 경로 | A-01 스플래시 (첫 실행/토큰 만료) → A-02 |
| 이탈 경로 | A-02 → A-03 (시작하기 탭 또는 마지막 페이지 완료) |

**레이아웃**

```
┌─────────────────────────────┐
│                      건너뛰기│ TextButton, bodyMedium
├─────────────────────────────┤
│                             │
│                             │
│        ┌───────────┐        │
│        │           │        │
│        │  일러스트   │        │ Image (onboarding illustration)
│        │  이미지    │        │ 240 x 240
│        │           │        │
│        └───────────┘        │
│                             │
│     실시간 위치 공유          │ headlineMedium (24sp, SemiBold)
│                             │
│   여행 중 그룹 멤버의         │ bodyMedium (14sp)
│   위치를 실시간으로           │ onSurfaceVariant
│   확인할 수 있습니다          │ 중앙 정렬, 최대 3줄
│                             │
│                             │
│         ● ○ ○ ○             │ PageIndicator (4 dots)
│                             │
│  ┌─────────────────────────┐│
│  │       시작하기            ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

> PageView 구성 (4페이지):
> 1. 실시간 위치 공유 - "여행 중 그룹 멤버의 위치를 실시간으로 확인할 수 있습니다"
> 2. SOS 긴급 호출 - "위급한 상황에서 즉시 도움을 요청하세요"
> 3. 가디언 보호 - "소중한 사람의 여행을 안전하게 지켜보세요"
> 4. 함께 떠나요 - "안전한 여행의 시작, SafeTrip"

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 건너뛰기 | `TextButton` | style: bodyMedium, color: onSurfaceVariant, alignment: topRight |
| 페이지 뷰 | `PageView` | controller: PageController, pageCount: 4 |
| 일러스트 | `Image.asset` | width: 240, height: 240, fit: BoxFit.contain |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), textAlign: center |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, textAlign: center, maxLines: 3 |
| 페이지 인디케이터 | `SmoothPageIndicator` | activeColor: primaryTeal, inactiveColor: outline, dotSize: 8 |
| 시작 버튼 | `ElevatedButton` | style: Button_Primary, text: "시작하기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 페이지 1~3 | 시작 버튼 텍스트: "다음", 건너뛰기 표시 |
| 페이지 4 (마지막) | 시작 버튼 텍스트: "시작하기", 건너뛰기 숨김 |
| 스와이프 중 | 페이지 인디케이터 활성 dot 이동 애니메이션 |

**인터랙션**

- [스와이프 좌/우] 페이지 영역 → 이전/다음 페이지 전환 (300ms 슬라이드)
- [탭] 다음 → 다음 페이지로 스크롤 (페이지 1~3)
- [탭] 시작하기 → Navigator.push → A-03 역할 선택 (페이지 4)
- [탭] 건너뛰기 → Navigator.push → A-03 역할 선택

---

### A-03 역할 선택 (Role Selection)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | A-03 |
| 화면명 | 역할 선택 (Role Selection) |
| Phase | P0 |
| 역할 | 신규 사용자 |
| 진입 경로 | A-02 웰컴 온보딩 → A-03 |
| 이탈 경로 | A-03 → A-07 (역할 선택 완료) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←]                         │ AppBar (transparent, no title)
├─────────────────────────────┤
│                             │
│  어떤 역할로                 │ headlineMedium (24sp, SemiBold)
│  시작할까요?                 │ onSurface
│                             │
│  SafeTrip에서의 역할을       │ bodyMedium (14sp)
│  선택해주세요                │ onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │ ✈️                       ││
│  │ 크루 (여행자)             ││ Card_Selectable
│  │                         ││ 좌측 보더: primaryTeal
│  │ 여행을 떠나는 사람이에요.  ││ bodyMedium, onSurfaceVariant
│  │ 그룹을 만들거나 참여하고,  ││
│  │ 실시간 위치를 공유합니다.  ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ 🛡️                       ││
│  │ 가디언 (보호자)           ││ Card_Selectable
│  │                         ││ 좌측 보더: #15A1A5
│  │ 소중한 사람의 여행을       ││ bodyMedium, onSurfaceVariant
│  │ 지켜보는 사람이에요.       ││
│  │ 위치 확인과 긴급 알림을    ││
│  │ 받을 수 있습니다.         ││
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
| 앱바 | `AppBar` | backgroundColor: transparent, elevation: 0, leading: BackButton |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 크루 카드 | `Card` + `InkWell` | style: Card_Selectable, icon: ✈️, borderColor: primaryTeal (선택 시) |
| 가디언 카드 | `Card` + `InkWell` | style: Card_Selectable, icon: 🛡️, borderColor: #15A1A5 (선택 시) |
| 카드 제목 | `Text` | style: titleMedium (18sp, SemiBold) |
| 카드 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 다음 버튼 | `ElevatedButton` | style: Button_Primary, enabled: 카드 선택 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 두 카드 모두 unselected (회색 보더), 다음 버튼 비활성 (opacity 0.4) |
| 크루 선택 | 크루 카드 좌측 보더 primaryTeal + 배경 tint, 가디언 카드 unselected, 다음 버튼 활성 |
| 가디언 선택 | 가디언 카드 좌측 보더 #15A1A5 + 배경 tint, 크루 카드 unselected, 다음 버튼 활성 |

**인터랙션**

- [탭] 크루 카드 → 크루 역할 선택 (가디언 해제)
- [탭] 가디언 카드 → 가디언 역할 선택 (크루 해제)
- [탭] 다음 → Navigator.push → A-07 약관 동의 (선택 역할 파라미터 전달)
- [뒤로가기] → A-02 웰컴 온보딩

---

### A-04 전화번호 인증 (Phone Auth)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | A-04 |
| 화면명 | 전화번호 인증 (Phone Auth) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | A-07 약관 동의 완료 → A-04 |
| 이탈 경로 | A-04 → A-05 (인증번호 발송 성공 시) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 전화번호 인증              │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  전화번호를 입력해주세요      │ headlineMedium (24sp, SemiBold)
│                             │
│  SMS로 인증번호를             │ bodyMedium (14sp)
│  보내드립니다                 │ onSurfaceVariant
│                             │
│  ┌─ Country Picker ───────┐ │
│  │ 🇰🇷 대한민국 (+82)  ▼    │ │ DropdownButtonFormField
│  └─────────────────────────┘ │
│                             │ spacing16
│  ┌─ Phone Input ──────────┐ │
│  │ 010-0000-0000           │ │ Input_Text (phone)
│  └─────────────────────────┘ │
│                             │
│                             │
│                             │
│                             │
│                             │
│                             │
│  ┌─────────────────────────┐ │
│  │     인증번호 받기         │ │ Button_Primary
│  └─────────────────────────┘ │
│                             │
│  서비스 이용약관에 동의합니다   │ bodySmall, onSurfaceVariant
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "전화번호 인증", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 국가코드 선택 | `DropdownButtonFormField` | items: countryList (국기+국가명+코드), value: "+82" |
| 전화번호 입력 | `TextFormField` | keyboardType: TextInputType.phone, hintText: "010-0000-0000", validator: 필수+형식 검증, style: Input_Text |
| 인증 버튼 | `ElevatedButton` | style: Button_Primary, text: "인증번호 받기", enabled: 전화번호 유효 시 |
| 약관 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 인증 버튼 비활성 (opacity 0.4, onSurfaceVariant 배경) |
| 번호 입력 중 | 입력 필드 보더 primaryTeal, 실시간 형식 검증 |
| 번호 유효 | 인증 버튼 활성 (primaryTeal 배경) |
| 번호 무효 | 입력 필드 보더 semanticError, 에러 텍스트 "유효한 전화번호를 입력해주세요" |
| 발송 중 | 버튼 → CircularProgressIndicator (white, 24dp) |
| 발송 성공 | Navigator.push → A-05 OTP 인증 (전화번호 파라미터 전달) |
| 발송 실패 | SnackBar "인증번호 발송에 실패했습니다. 다시 시도해주세요." |
| 이미 가입된 번호 | 복귀 사용자 분기 → 시나리오 D (OTP 후 메인 직행) |

**인터랙션**

- [탭] 국가코드 영역 → Modal_Bottom 국가 목록 표시 (국기 + 국가명 + 코드, 검색 가능)
- [탭] 전화번호 입력 필드 → 숫자 키패드 표시
- [탭] 인증번호 받기 → POST /api/v1/auth/send-otp → 성공 시 A-05
- [뒤로가기] → A-07 약관 동의

---

### A-05 OTP 인증 (OTP Verify)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | A-05 |
| 화면명 | OTP 인증 (OTP Verify) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | A-04 전화번호 인증 (인증번호 발송 성공) → A-05 |
| 이탈 경로 | A-05 → A-06 (OTP 인증 성공 시) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 인증번호 입력              │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  인증번호를 입력해주세요      │ headlineMedium (24sp, SemiBold)
│                             │
│  +82 10-****-1234로          │ bodyMedium (14sp)
│  전송된 6자리 코드를          │ onSurfaceVariant
│  입력해주세요                 │
│                             │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ │
│  │   │ │   │ │   │ │   │ │   │ │   │ │ Input_OTP
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ │ (6 x TextField)
│                             │
│          2:45               │ bodyLarge, primaryCoral (#FF807B)
│                             │
│  인증번호를 받지 못하셨나요?   │ bodySmall, onSurfaceVariant
│           재전송              │ TextButton, primaryTeal
│                             │
│                             │
│                             │
│                             │
│  ┌─────────────────────────┐ │
│  │       인증하기            │ │ Button_Primary
│  └─────────────────────────┘ │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "인증번호 입력", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 전송 안내 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, 마스킹된 번호 표시 |
| OTP 입력 | `Row` < `TextField` x 6 > | style: Input_OTP, 각 셀 48x56dp, radius8, 자동 포커스 이동, keyboardType: number |
| 타이머 | `Text` | style: bodyLarge (16sp), color: primaryCoral (#FF807B), 180초 카운트다운 |
| 재전송 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 재전송 버튼 | `TextButton` | style: labelMedium, color: primaryTeal, text: "재전송" |
| 인증 버튼 | `ElevatedButton` | style: Button_Primary, text: "인증하기", enabled: 6자리 입력 완료 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 첫 번째 셀 자동 포커스, 타이머 3:00 시작, 인증 버튼 비활성, 재전송 비활성 (60초간) |
| 입력 중 | 활성 셀 보더 primaryTeal, 입력 완료 셀 자동 다음 포커스 이동 |
| 6자리 완료 | 인증 버튼 활성 (primaryTeal), 자동 인증 시도 가능 |
| 인증 중 | 버튼 → CircularProgressIndicator |
| 인증 성공 | Navigator.pushReplacement → A-06 프로필 설정 |
| 인증 실패 | 전체 셀 보더 semanticError (#DA4C51), 셀 내용 클리어, SnackBar "인증번호가 올바르지 않습니다" |
| 3회 연속 실패 | 입력 비활성화, "1분 후 다시 시도해주세요" 안내 표시 |
| 타이머 만료 (0:00) | OTP 셀 비활성, "인증번호가 만료되었습니다" 안내, 재전송 버튼 강조 |
| 재전송 가능 (60초 경과) | 재전송 버튼 활성화 (primaryTeal 색상) |
| 재전송 완료 | 타이머 3:00 리셋, OTP 셀 클리어, SnackBar "인증번호가 재전송되었습니다" |

**인터랙션**

- [입력] OTP 셀 → 숫자 입력 시 자동 다음 셀 이동, 백스페이스 시 이전 셀 이동
- [탭] 인증하기 → POST /api/v1/auth/verify-otp → 성공 시 A-06
- [탭] 재전송 → POST /api/v1/auth/send-otp (재발송) → 타이머 리셋
- [붙여넣기] 클립보드 6자리 숫자 → 전체 셀 자동 채움
- [뒤로가기] → A-04 전화번호 인증 (타이머 유지 안 됨)

---

### A-06 프로필 설정 (Profile Setup)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | A-06 |
| 화면명 | 프로필 설정 (Profile Setup) |
| Phase | P0 |
| 역할 | 신규 사용자 |
| 진입 경로 | A-05 OTP 인증 성공 → A-06 |
| 이탈 경로 | A-06 → C-01 메인맵 (크루) / A-06 → F-04 가디언홈 (가디언) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 프로필 설정               │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  프로필을 설정해주세요        │ headlineMedium (24sp, SemiBold)
│                             │
│  다른 멤버에게 보여지는        │ bodyMedium (14sp)
│  정보입니다                   │ onSurfaceVariant
│                             │
│        ┌──────────┐         │
│        │          │         │
│        │  👤 +    │         │ Avatar Picker
│        │          │         │ GestureDetector + CircleAvatar
│        └──────────┘         │ 96 x 96, radius48
│       프로필 사진 추가         │ bodySmall, primaryTeal
│                             │
│  ┌─ 이름 ─────────────────┐ │
│  │ 이름을 입력하세요         │ │ Input_Text
│  └─────────────────────────┘ │
│                             │ spacing16
│  ┌─ 비상 연락처 ──────────┐  │
│  │ 비상 시 연락할 번호       │ │ Input_Text (phone)
│  └─────────────────────────┘ │
│                             │
│  비상 연락처는 SOS 발동 시    │ bodySmall, onSurfaceVariant
│  함께 전달됩니다              │
│                             │
│  ┌─────────────────────────┐ │
│  │       완료               │ │ Button_Primary
│  └─────────────────────────┘ │
│                             │
│         나중에 설정 >         │ TextButton, onSurfaceVariant
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "프로필 설정", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 아바타 영역 | `GestureDetector` + `CircleAvatar` | radius: 48, backgroundColor: secondaryBeige (#F2EDE4), 카메라 아이콘 오버레이 |
| 사진 추가 텍스트 | `Text` | style: bodySmall (12sp), color: primaryTeal |
| 이름 입력 | `TextFormField` | style: Input_Text, hintText: "이름을 입력하세요", validator: 필수 (2~20자), maxLength: 20 |
| 비상연락처 입력 | `TextFormField` | style: Input_Text, keyboardType: TextInputType.phone, hintText: "비상 시 연락할 번호" |
| 비상연락처 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 완료 버튼 | `ElevatedButton` | style: Button_Primary, text: "완료", enabled: 이름 입력 완료 시 |
| 나중에 설정 | `TextButton` | style: bodyMedium (14sp), color: onSurfaceVariant |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 기본 아바타 (👤 아이콘), 완료 버튼 비활성 |
| 이름 입력 완료 | 완료 버튼 활성 (primaryTeal) |
| 이름 미입력 | 완료 버튼 비활성, 에러 텍스트 "이름을 입력해주세요" (탭 시) |
| 사진 선택 중 | Modal_Bottom (카메라/갤러리 선택) |
| 사진 선택 완료 | CircleAvatar에 선택한 이미지 표시, 카메라 아이콘 → 편집 아이콘 |
| 저장 중 | 완료 버튼 → CircularProgressIndicator |
| 저장 성공 (크루) | Navigator.pushReplacement → C-01 메인맵 |
| 저장 성공 (가디언) | Navigator.pushReplacement → F-04 가디언홈 |
| 저장 실패 | SnackBar "프로필 저장에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 아바타 영역 → Modal_Bottom (촬영하기 / 앨범에서 선택 / 기본 이미지)
- [탭] 이름 입력 → 키보드 표시
- [탭] 비상연락처 입력 → 숫자 키패드 표시
- [탭] 완료 → PUT /api/v1/users/profile → 성공 시 역할별 메인 화면으로 이동
- [탭] 나중에 설정 → 기본 프로필로 저장 후 역할별 메인 화면으로 이동
- [뒤로가기] → Dialog_Confirm "프로필 설정을 건너뛸까요?" (확인 → 메인 / 취소 → 유지)

---

### A-07 약관 동의 (Consent/Terms)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | A-07 |
| 화면명 | 약관 동의 (Consent/Terms) |
| Phase | P0 |
| 역할 | 신규 사용자 |
| 진입 경로 | A-03 역할 선택 완료 → A-07 |
| 이탈 경로 | A-07 → A-04 (필수 동의 완료 시) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 약관 동의                │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  서비스 이용을 위한           │ headlineMedium (24sp, SemiBold)
│  약관 동의가 필요합니다       │
│                             │
│  ┌─────────────────────────┐│
│  │ ☑ 전체 동의              ││ CheckboxListTile (master)
│  │                         ││ titleMedium, SemiBold
│  └─────────────────────────┘│
│  ─────────────────────────── │ Divider
│  ┌─────────────────────────┐│
│  │ ☐ [필수] 서비스 이용약관  │→│ CheckboxListTile + IconButton
│  ├─────────────────────────┤│
│  │ ☐ [필수] 개인정보 처리방침│→│ CheckboxListTile + IconButton
│  ├─────────────────────────┤│
│  │ ☐ [필수] 위치정보        │→│ CheckboxListTile + IconButton
│  │       이용약관           │ │
│  ├─────────────────────────┤│
│  │ ☐ [선택] 마케팅 수신 동의 │→│ CheckboxListTile + IconButton
│  └─────────────────────────┘│
│                             │
│  [EU 사용자만 표시]           │ Visibility (locale 기반)
│  ┌─────────────────────────┐│
│  │ ☐ [필수] GDPR 동의       │→│ CheckboxListTile + IconButton
│  ├─────────────────────────┤│
│  │ ☐ [필수] Firebase       │→│ CheckboxListTile + IconButton
│  │       국외 이전 동의      │ │
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │    동의하고 시작하기       ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "약관 동의", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 전체 동의 | `CheckboxListTile` | value: allChecked, activeColor: primaryTeal, title: "전체 동의" (titleMedium, SemiBold) |
| 구분선 | `Divider` | color: outline (#EDEDED), height: 1 |
| 필수 항목 (3개) | `CheckboxListTile` | activeColor: primaryTeal, 접두어 "[필수]" (primaryCoral), trailing: IconButton (chevron_right) |
| 선택 항목 (1개) | `CheckboxListTile` | activeColor: primaryTeal, 접두어 "[선택]" (onSurfaceVariant), trailing: IconButton (chevron_right) |
| EU 항목 (2개) | `CheckboxListTile` | Visibility 래핑, locale == EU 시 표시, activeColor: primaryTeal |
| 전문 보기 화살표 | `IconButton` | icon: Icons.chevron_right, onPressed: → WebView 약관 전문 |
| 동의 버튼 | `ElevatedButton` | style: Button_Primary, text: "동의하고 시작하기", enabled: 필수 항목 전체 체크 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 모든 체크박스 unchecked (회색 원), 동의 버튼 비활성 (opacity 0.4) |
| 일부 필수 체크 | 전체 동의 체크박스 indeterminate (─), 동의 버튼 비활성 |
| 필수 전체 체크 | 동의 버튼 활성 (primaryTeal), 마케팅 체크 여부와 무관 |
| 전체 동의 탭 | 모든 항목 (필수+선택) 일괄 체크, 동의 버튼 활성 |
| 전체 동의 해제 | 모든 항목 일괄 해제, 동의 버튼 비활성 |
| 약관 전문 보기 | Navigator.push → WebView 화면 (약관 전문 표시, 뒤로가기로 복귀) |
| 동의 저장 중 | 버튼 → CircularProgressIndicator |
| 동의 저장 성공 | POST /api/v1/users/consent → Navigator.push → A-04 전화번호 인증 |
| 동의 저장 실패 | SnackBar "동의 저장에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 전체 동의 → 모든 체크박스 일괄 토글 (체크/해제)
- [탭] 개별 체크박스 → 해당 항목만 토글
- [탭] 약관 항목 우측 화살표 (→) → WebView로 약관 전문 표시
- [탭] 동의하고 시작하기 → POST /api/v1/users/consent → A-04 전화번호 인증
- [뒤로가기] → A-03 역할 선택

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 7개 화면 (A-01 ~ A-07) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 온보딩 UX 시나리오: `Master_docs/14_T3_온보딩_UX_시나리오.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
