# M. 미성년자 보호

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 미성년자 보호 플로우 4개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 비즈니스 원칙 v5.1 §10 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 4개 (M-01 ~ M-04)
- **Phase:** 전체 P2
- **핵심 역할:** 보호자 (M-01), 미성년자+보호자 (M-02), 캡틴 (M-03), 크루/캡틴 (M-04)
- **연관 문서:** 비즈니스 원칙 §10 미성년자 보호 기반 원칙

---

## User Journey Flow

```
[14세 미만 사용자 가입]
     ↓
M-01 보호자 동의 (법정대리인 확인 + 동의서)
     ↓
     → A-04 전화번호 인증 (미성년자 본인)

[14~17세 사용자 가입]
     ↓
M-02 이중 동의 (Step 1: 본인 동의 → Step 2: 보호자 확인)
     ↓
     → A-04 전화번호 인증 (미성년자 본인)

[미성년자가 여행 참여 시 — 캡틴 화면]
     ↓
M-03 미성년자 여행 안내 (강제 Safety First + 제한 사항)
     ↓
     → C-01 메인맵 (여행 화면)

[미성년자 가디언 해제 요청 시]
     ↓
M-04 미성년자 가디언 해제 (사유 입력 → 캡틴 승인/거절)
     ↓
     → F-01 가디언 관리 화면
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| A-07 약관 동의 | 14세 미만 확인 | M-01 보호자 동의 | M |
| A-07 약관 동의 | 14~17세 확인 | M-02 이중 동의 | M |
| M-01 | 보호자 동의 완료 | A-04 전화번호 인증 | A |
| M-02 | 이중 동의 완료 | A-04 전화번호 인증 | A |
| 여행 참여 API | 미성년자 멤버 감지 | M-03 미성년자 여행 안내 | M |
| M-03 | 확인 완료 | C-01 메인맵 | C |
| F-01 가디언 관리 | 가디언 해제 요청 | M-04 가디언 해제 | M |
| M-04 | 승인/거절 완료 | F-01 가디언 관리 | F |

---

## 디자인 토큰 (미성년자 보호 전용)

| 토큰 | HEX | 용도 |
|------|-----|------|
| `semanticWarning` | `#FF9800` | 미성년자 보호 관련 경고, 주의 배경 |
| `semanticError` | `#DA4C51` | 강제 제한 Card_Alert 보더, 법적 경고 |
| `onSurfaceVariant` | `#8E8E93` | 법적 공지 텍스트 (`bodySmall`) |

> Card_Alert (red border): 미성년자 강제 제한 사항 표시 시 보더 색상 `semanticError` (`#DA4C51`) 사용

---

## 화면 상세

---

### M-01 보호자 동의 (Minor Consent - Parent)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | M-01 |
| 화면명 | 보호자 동의 (Minor Consent - Parent) |
| Phase | P2 |
| 역할 | 보호자 (법정대리인) |
| 진입 경로 | A-07 약관 동의 (14세 미만 사용자) → M-01 |
| 이탈 경로 | M-01 → A-04 (보호자 동의 완료 시) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 보호자 동의               │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  법정대리인 동의가            │ headlineMedium (24sp, SemiBold)
│  필요합니다                  │ onSurface
│                             │
│  14세 미만 사용자는 법정대리인  │ bodyMedium (14sp)
│  (부모/보호자)의 동의가       │ onSurfaceVariant
│  필요합니다.                  │
│                             │
│  ┌─ 법정대리인 정보 ─────────┐│
│  │ 이름                      ││
│  │ ┌───────────────────────┐││
│  │ │ 보호자 이름 입력         │││ Input_Text
│  │ └───────────────────────┘││
│  │                          ││ spacing12
│  │ 연락처                    ││
│  │ ┌───────────────────────┐││
│  │ │ 010-0000-0000          │││ Input_Text (phone)
│  │ └───────────────────────┘││
│  │                          ││ spacing12
│  │ 관계                      ││
│  │ ┌───────────────────────┐││
│  │ │ 부모 / 법정후견인  ▼    │││ DropdownButtonFormField
│  │ └───────────────────────┘││
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ SMS 인증 ──────────────┐│
│  │  보호자 휴대폰으로         ││
│  │  인증번호를 발송합니다      ││ bodyMedium, onSurfaceVariant
│  │                          ││
│  │  ┌────────────────────┐  ││
│  │  │   인증번호 발송      │  ││ Button_Secondary
│  │  └────────────────────┘  ││
│  │                          ││
│  │  ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐││
│  │  │  ││  ││  ││  ││  ││  │││ Input_OTP (6자리)
│  │  └──┘└──┘└──┘└──┘└──┘└──┘││
│  │          2:45             ││ bodyLarge, primaryCoral
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ 동의서 ────────────────┐│
│  │ 📄 미성년자 개인정보      ││ Card_Standard
│  │    수집·이용 동의서        ││ titleMedium, onSurface
│  │                          ││
│  │ (동의서 본문 스크롤 영역)  ││ bodySmall, onSurfaceVariant
│  │ - 수집 목적: 위치 기반     ││ 최대 높이 160dp, 스크롤
│  │   안전 서비스 제공         ││
│  │ - 수집 항목: 이름, 위치,   ││
│  │   비상연락처              ││
│  │ - 보유 기간: 여행 종료 후  ││
│  │   30일 (§10, §13)        ││
│  │                          ││
│  │ ☐ [필수] 위 동의서 내용을  ││ CheckboxListTile
│  │   확인하였으며 동의합니다   ││ activeColor: semanticWarning
│  │                          ││
│  │ ☐ [필수] 법정대리인으로서  ││ CheckboxListTile
│  │   본인의 자녀/피후견인의   ││ activeColor: semanticWarning
│  │   SafeTrip 서비스 이용에   ││
│  │   동의합니다              ││
│  └──────────────────────────┘│
│                             │ spacing12
│  ⚖️ 본 동의는 개인정보 보호법  │ bodySmall (12sp)
│  제22조(동의를 받는 방법) 및   │ onSurfaceVariant
│  아동·청소년 개인정보 보호     │
│  규정(COPPA/GDPR-K)에 따라   │
│  수집됩니다.                  │
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │       동의 완료            ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "보호자 동의", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 보호자 이름 입력 | `TextFormField` | style: Input_Text, hintText: "보호자 이름 입력", validator: 필수 (2~20자) |
| 보호자 연락처 입력 | `TextFormField` | style: Input_Text, keyboardType: TextInputType.phone, hintText: "010-0000-0000" |
| 관계 선택 | `DropdownButtonFormField` | items: ["부모", "법정후견인", "기타"], value: null, validator: 필수 |
| 인증번호 발송 버튼 | `OutlinedButton` | style: Button_Secondary, text: "인증번호 발송", enabled: 연락처 유효 시 |
| OTP 입력 | `Row` < `TextField` x 6 > | style: Input_OTP, 각 셀 48x56dp, radius8, 자동 포커스 이동 |
| 타이머 | `Text` | style: bodyLarge (16sp), color: primaryCoral (#FF807B), 180초 카운트다운 |
| 동의서 카드 | `Card` | style: Card_Standard, 내부 스크롤 가능, maxHeight: 160dp |
| 동의서 본문 | `SingleChildScrollView` + `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 동의 체크박스 1 | `CheckboxListTile` | activeColor: semanticWarning (#FF9800), title: "[필수] 위 동의서 내용을 확인하였으며 동의합니다" |
| 동의 체크박스 2 | `CheckboxListTile` | activeColor: semanticWarning (#FF9800), title: "[필수] 법정대리인으로서 ... 동의합니다" |
| 법적 고지 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, icon: ⚖️ prefix |
| 동의 완료 버튼 | `ElevatedButton` | style: Button_Primary, text: "동의 완료", enabled: SMS 인증 완료 + 체크박스 2개 모두 체크 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 모든 입력 필드 비어 있음, OTP 영역 비활성, 체크박스 unchecked, 동의 완료 버튼 비활성 (opacity 0.4) |
| 보호자 정보 입력 중 | 입력 필드 보더 primaryTeal, 실시간 형식 검증 |
| 연락처 유효 | 인증번호 발송 버튼 활성 (primaryTeal 보더) |
| 인증번호 발송 중 | 발송 버튼 → CircularProgressIndicator |
| 인증번호 발송 완료 | OTP 입력 필드 활성화, 타이머 3:00 시작, Toast "인증번호가 발송되었습니다" |
| OTP 입력 중 | 활성 셀 보더 primaryTeal, 자동 다음 셀 이동 |
| OTP 인증 성공 | OTP 영역에 ✅ 인증 완료 표시, 셀 비활성화 |
| OTP 인증 실패 | 전체 셀 보더 semanticError, SnackBar "인증번호가 올바르지 않습니다" |
| 타이머 만료 | OTP 셀 비활성, "인증번호가 만료되었습니다" 안내, 재발송 버튼 표시 |
| 체크박스 2개 모두 체크 + OTP 인증 완료 | 동의 완료 버튼 활성 (primaryTeal) |
| 동의 저장 중 | 동의 완료 버튼 → CircularProgressIndicator |
| 동의 저장 성공 | Navigator.push → A-04 전화번호 인증 (미성년자 본인 인증) |
| 동의 저장 실패 | SnackBar "동의 처리에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 보호자 이름 입력 → 키보드 표시
- [탭] 보호자 연락처 입력 → 숫자 키패드 표시
- [탭] 관계 선택 → DropdownMenu (부모 / 법정후견인 / 기타)
- [탭] 인증번호 발송 → POST /api/v1/auth/minor-consent/send-otp → 보호자 폰에 SMS 발송
- [입력] OTP 셀 → 숫자 입력 시 자동 다음 셀 이동, 6자리 완료 시 자동 인증 요청
- [탭] 동의서 영역 → 스크롤하여 전문 확인 가능
- [탭] 동의 체크박스 → 개별 토글
- [탭] 동의 완료 → POST /api/v1/auth/minor-consent/parent → 성공 시 A-04
- [뒤로가기] → Dialog_Confirm "동의를 중단하시겠습니까? 입력된 정보가 사라집니다." (확인 → A-07 / 취소 → 유지)

---

### M-02 이중 동의 (Minor Consent - Dual)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | M-02 |
| 화면명 | 이중 동의 (Minor Consent - Dual) |
| Phase | P2 |
| 역할 | 미성년자 (14~17세) + 보호자 |
| 진입 경로 | A-07 약관 동의 (14~17세 사용자) → M-02 |
| 이탈 경로 | M-02 → A-04 (이중 동의 완료 시) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 이중 동의                │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  본인과 보호자의             │ headlineMedium (24sp, SemiBold)
│  동의가 필요합니다           │ onSurface
│                             │
│  14세 이상 18세 미만 사용자는 │ bodyMedium (14sp)
│  본인과 보호자 모두의 동의가  │ onSurfaceVariant
│  필요합니다.                 │
│                             │
│  ┌─ 진행 상황 ─────────────┐│
│  │  ① 본인 동의    ② 보호자  ││ ProgressIndicator (step)
│  │  ●━━━━━━━━━━━━━○         ││ step 1 활성: primaryTeal
│  │  진행 중        대기 중    ││ step 2 대기: outline
│  └──────────────────────────┘│
│                             │ spacing16
│ ┌─────────────────────────┐ │
│ │ [Step 1] 본인 동의        │ │ Card_Standard
│ │                          │ │ 활성 상태: 좌측 보더 primaryTeal
│ │ ┌─ 동의 항목 ──────────┐ │ │
│ │ │ ☐ [필수] 개인정보      │ │ │ CheckboxListTile
│ │ │    수집·이용 동의       │→│ │ activeColor: primaryTeal
│ │ │                       │ │ │
│ │ │ ☐ [필수] 위치정보      │ │ │ CheckboxListTile
│ │ │    이용 동의           │→│ │ activeColor: primaryTeal
│ │ │                       │ │ │
│ │ │ ☐ [필수] 미성년자      │ │ │ CheckboxListTile
│ │ │    서비스 이용 동의     │→│ │ activeColor: primaryTeal
│ │ └───────────────────────┘ │ │
│ │                          │ │
│ │ ┌────────────────────┐   │ │
│ │ │    본인 동의 확인     │   │ │ Button_Primary (step 1용)
│ │ └────────────────────┘   │ │
│ └─────────────────────────┘ │
│                             │ spacing16
│ ┌─────────────────────────┐ │
│ │ [Step 2] 보호자 확인      │ │ Card_Standard
│ │                          │ │ 비활성 상태: opacity 0.5
│ │  보호자 연락처             │ │
│ │ ┌───────────────────────┐│ │
│ │ │ 010-0000-0000          ││ │ Input_Text (phone, disabled)
│ │ └───────────────────────┘│ │
│ │                          │ │
│ │  확인 방식                │ │
│ │ ┌───────────────────┐    │ │
│ │ │ ○ SMS 인증          │    │ │ RadioListTile
│ │ │ ○ 인앱 승인 요청     │    │ │ RadioListTile
│ │ └───────────────────┘    │ │
│ │                          │ │
│ │ ┌────────────────────┐   │ │
│ │ │  보호자 확인 요청     │   │ │ Button_Primary (disabled)
│ │ └────────────────────┘   │ │
│ │                          │ │
│ │  ⏳ 보호자 확인 대기 중    │ │ bodySmall, onSurfaceVariant
│ └─────────────────────────┘ │
│                             │ spacing12
│  ⚖️ 개인정보 보호법 제22조 및  │ bodySmall (12sp)
│  아동·청소년 보호 규정에 따른  │ onSurfaceVariant
│  이중 동의 절차입니다.        │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "이중 동의", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 진행 인디케이터 | `Stepper` (custom) | 2-step, activeColor: primaryTeal (#00A2BD), inactiveColor: outline (#EDEDED) |
| Step 1 카드 | `Card` | style: Card_Standard, 활성 시 좌측 보더 primaryTeal 4px |
| 동의 체크박스 (3개) | `CheckboxListTile` | activeColor: primaryTeal, 접두어 "[필수]", trailing: IconButton (chevron_right) |
| 본인 동의 버튼 | `ElevatedButton` | style: Button_Primary, text: "본인 동의 확인", enabled: 3개 모두 체크 시 |
| Step 2 카드 | `Card` | style: Card_Standard, 초기: opacity 0.5 (비활성), Step 1 완료 후 활성 |
| 보호자 연락처 입력 | `TextFormField` | style: Input_Text, keyboardType: TextInputType.phone, hintText: "010-0000-0000" |
| 확인 방식 선택 | `RadioListTile` x 2 | groupValue: confirmMethod, items: ["SMS 인증", "인앱 승인 요청"] |
| 보호자 확인 요청 버튼 | `ElevatedButton` | style: Button_Primary, text: "보호자 확인 요청", enabled: Step 1 완료 + 연락처 유효 + 방식 선택 |
| 대기 상태 표시 | `Row` (icon + text) | icon: ⏳, style: bodySmall (12sp), color: onSurfaceVariant |
| 법적 고지 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, icon: ⚖️ prefix |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | Step 1 활성 (좌측 보더 primaryTeal), Step 2 비활성 (opacity 0.5), 진행 인디케이터 Step 1 활성 |
| Step 1 체크박스 일부 체크 | 본인 동의 버튼 비활성 (opacity 0.4) |
| Step 1 체크박스 전체 체크 | 본인 동의 버튼 활성 (primaryTeal) |
| Step 1 완료 | Step 1 카드에 ✅ 완료 표시, 체크박스 비활성화 (locked), Step 2 카드 활성화 (opacity 1.0), 진행 인디케이터 Step 2 활성 |
| Step 2 — SMS 인증 선택 | SMS 인증 플로우 표시 (Input_OTP + 타이머, M-01과 동일) |
| Step 2 — 인앱 승인 선택 | "보호자 앱에 승인 요청을 보냅니다" 안내 표시, 푸시 알림으로 전달 |
| 보호자 확인 요청 전송 중 | 버튼 → CircularProgressIndicator |
| SMS 인증 대기 중 | OTP 입력 필드 + 타이머 3:00 표시 |
| 인앱 승인 대기 중 | "⏳ 보호자 확인 대기 중..." 텍스트 + 실시간 폴링 (10초 간격), "재요청" 링크 (60초 후 활성) |
| 보호자 확인 완료 | Step 2 카드에 ✅ 완료 표시, Toast "보호자 동의가 완료되었습니다", 자동 이동 A-04 |
| 보호자 확인 거절 | Card_Alert (semanticWarning 보더): "보호자가 동의를 거부했습니다. 보호자에게 문의하세요." |
| 보호자 확인 타임아웃 (24시간) | "보호자 확인이 만료되었습니다. 다시 요청해주세요." 안내 표시 |

**인터랙션**

- [탭] 동의 체크박스 → 개별 토글
- [탭] 약관 항목 우측 화살표 (→) → WebView로 해당 약관 전문 표시
- [탭] 본인 동의 확인 → 로컬 상태 저장, Step 2 활성화
- [탭] 확인 방식 라디오 → SMS 또는 인앱 선택
- [탭] 보호자 확인 요청 → POST /api/v1/auth/minor-consent/dual → SMS 발송 또는 인앱 푸시
- [입력] OTP 셀 (SMS 선택 시) → 숫자 입력, 6자리 완료 시 자동 인증
- [자동] 인앱 승인 폴링 → GET /api/v1/auth/minor-consent/status (10초 간격)
- [탭] 재요청 → POST /api/v1/auth/minor-consent/dual (재전송)
- [뒤로가기] → Dialog_Confirm "동의 진행을 중단하시겠습니까?" (확인 → A-07 / 취소 → 유지)

---

### M-03 미성년자 여행 안내 (Minor Trip Notice)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | M-03 |
| 화면명 | 미성년자 여행 안내 (Minor Trip Notice) |
| Phase | P2 |
| 역할 | 캡틴 |
| 진입 경로 | 미성년자 멤버 가입 시 → M-03 (자동 팝업) |
| 이탈 경로 | M-03 → C-01 메인맵 (확인 완료 시) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 미성년자 여행 안내         │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  🛡️ 미성년자 멤버가           │ headlineMedium (24sp, SemiBold)
│  참여합니다                  │ onSurface
│                             │
│  미성년자가 포함된 여행은      │ bodyMedium (14sp)
│  안전 규정에 따라 제약이       │ onSurfaceVariant
│  적용됩니다.                  │
│                             │ spacing16
│  ┌─ 강제 적용 사항 ─────────┐│
│  │                          ││ Card_Alert
│  │  ⚠️ 프라이버시 등급 강제    ││ semanticError 보더 (#DA4C51)
│  │                          ││
│  │  이 여행의 프라이버시 등급이 ││ bodyMedium, onSurface
│  │  안전 최우선 (Safety First) ││
│  │  으로 자동 전환됩니다.     ││
│  │                          ││
│  │  🛡️ Safety First          ││ Badge: semanticError 배경
│  │  → 위치가 항상 공유됩니다   ││ bodySmall, onSurfaceVariant
│  │                          ││
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ 제한 사항 목록 ─────────┐│
│  │                          ││ Card_Alert
│  │  🚫 미성년자 제한 사항      ││ semanticError 보더 (#DA4C51)
│  │                          ││
│  │  • 프라이버시우선 모드       ││ bodyMedium, onSurface
│  │    사용 불가               ││
│  │                          ││
│  │  • 가디언 위치 공유         ││
│  │    일시 중지 불가           ││
│  │                          ││
│  │  • 가디언 연결 필수         ││
│  │    (해제 시 캡틴 승인 필요) ││
│  │                          ││
│  │  • 위치 데이터 보유:        ││
│  │    여행 종료 후 30일        ││ bodySmall, onSurfaceVariant
│  │    (성인 90일보다 단축)     ││
│  │                          ││
│  │  • Intelligence AI 개인    ││
│  │    분석 제한               ││
│  │    (그룹 단위만 허용)       ││
│  │                          ││
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ 미성년자 멤버 정보 ──────┐│
│  │ 👤 홍길동 (15세)           ││ ListTile_Member
│  │    크루 · 가디언: 홍부모    ││ subtitle: 역할 + 가디언명
│  └──────────────────────────┘│
│                             │ spacing16
│  ⚖️ 비즈니스 원칙 §10에 따라   │ bodySmall (12sp)
│  미성년자 보호 정책이          │ onSurfaceVariant
│  자동 적용됩니다.             │
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │       확인                ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "미성년자 여행 안내", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface, prefix: 🛡️ |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 강제 적용 카드 | `Card` | style: Card_Alert, borderColor: semanticError (#DA4C51), borderWidth: 1px |
| 강제 적용 제목 | `Text` | style: titleMedium (18sp, SemiBold), prefix: ⚠️, color: onSurface |
| Safety First 뱃지 | `Container` (pill) | backgroundColor: semanticError (#DA4C51), text: "Safety First", textColor: #FFFFFF, style: labelSmall |
| 뱃지 설명 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 제한 사항 카드 | `Card` | style: Card_Alert, borderColor: semanticError (#DA4C51), borderWidth: 1px |
| 제한 사항 제목 | `Text` | style: titleMedium (18sp, SemiBold), prefix: 🚫, color: onSurface |
| 제한 사항 목록 | `Column` < `Row` (bullet + text) > | style: bodyMedium (14sp), color: onSurface, bullet: "•" |
| 제한 사항 부연 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 미성년자 정보 카드 | `Card` + `ListTile` | style: Card_Standard, leading: CircleAvatar (40dp), title: 이름 + 나이, subtitle: 역할 + 가디언 |
| 법적 고지 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, prefix: ⚖️ |
| 확인 버튼 | `ElevatedButton` | style: Button_Primary, text: "확인" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 전체 정보 표시, 확인 버튼 활성 |
| 미성년자 1명 | 미성년자 정보 카드 1개 표시 |
| 미성년자 복수 | 미성년자 정보 카드 목록으로 표시 (스크롤 가능) |
| 이미 Safety First 등급인 경우 | 강제 적용 카드에 "현재 등급이 유지됩니다" 표시 (등급 전환 없음) |
| Safety First 아닌 등급에서 전환 | 강제 적용 카드에 "기존 [등급명] → Safety First로 변경됩니다" 강조 표시 |
| 확인 중 | 버튼 → CircularProgressIndicator |
| 확인 완료 | PATCH /api/v1/trips/:tripId/privacy-level → safety_first, Navigator.pop → C-01 메인맵 |

**인터랙션**

- [자동] 미성년자 멤버 가입 감지 시 자동 팝업 (캡틴 화면)
- [스크롤] 제한 사항 카드 영역 → 전체 내용 확인 가능
- [탭] 확인 → 프라이버시 등급 강제 전환 확인 + Navigator.pop → C-01
- [뒤로가기] → 확인 버튼과 동일 동작 (이 안내는 건너뛸 수 없음, 반드시 확인 필요)

---

### M-04 미성년자 가디언 해제 (Minor Guardian Release)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | M-04 |
| 화면명 | 미성년자 가디언 해제 (Minor Guardian Release) |
| Phase | P2 |
| 역할 | 크루 (요청) / 캡틴 (승인) |
| 진입 경로 | F-01 가디언 관리 → 가디언 해제 → M-04 |
| 이탈 경로 | M-04 → F-01 (요청 완료/승인·거절 완료 시) |

**레이아웃 — 크루 (요청 화면)**

```
┌─────────────────────────────┐
│ [←] 가디언 해제 요청          │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  가디언 해제를               │ headlineMedium (24sp, SemiBold)
│  요청합니다                  │ onSurface
│                             │
│  미성년자의 가디언 해제는      │ bodyMedium (14sp)
│  캡틴의 승인이 필요합니다.    │ onSurfaceVariant
│                             │ spacing16
│  ┌─ 안전 경고 ─────────────┐│
│  │                          ││ Card_Alert
│  │  ⚠️ 안전 경고              ││ semanticWarning 보더 (#FF9800)
│  │                          ││
│  │  가디언을 해제하면 보호자가 ││ bodyMedium, onSurface
│  │  더 이상 위치를 확인하거나  ││
│  │  긴급 알림을 받을 수       ││
│  │  없습니다.                ││
│  │                          ││
│  │  미성년자의 안전을 위해     ││ bodySmall, onSurfaceVariant
│  │  신중하게 결정해 주세요.    ││
│  │                          ││
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ 해제 대상 ─────────────┐│
│  │ 👤 홍부모 (가디언)        ││ ListTile_Member
│  │    연결 일자: 2026-02-15  ││ subtitle: 연결 일자
│  │    담당 멤버: 홍길동       ││ trailing: 담당 멤버명
│  └──────────────────────────┘│
│                             │ spacing16
│  해제 사유 *                 │ labelMedium, onSurface
│  ┌─────────────────────────┐│
│  │ 해제 사유를 입력해주세요    ││ TextFormField
│  │                          ││ Input_Text (multiline)
│  │                          ││ maxLines: 4, maxLength: 200
│  │                          ││ validator: 필수 (10자 이상)
│  └─────────────────────────┘│
│  10자 이상 입력해주세요.      │ bodySmall, onSurfaceVariant
│                  (0/200)    │ bodySmall, 우측 정렬
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │    캡틴에게 승인 요청       ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**레이아웃 — 캡틴 (승인/거절 다이얼로그)**

```
┌─────────────────────────────────────┐
│                                     │ 스크림: black 40%
│                                     │
│    ┌────────────────────────────┐   │
│    │     가디언 해제 승인 요청    │   │ Dialog_Confirm (확장형)
│    │                            │   │ radius16
│    │  홍길동(크루)이 가디언       │   │
│    │  홍부모의 해제를             │   │ bodyMedium, onSurface
│    │  요청했습니다.              │   │
│    │                            │   │
│    │  ┌─ 안전 경고 ────────┐    │   │
│    │  │ ⚠️ 미성년자의       │    │   │ Card_Alert (inline)
│    │  │ 가디언을 해제하면    │    │   │ semanticWarning 보더
│    │  │ 안전 보호가 약화    │    │   │
│    │  │ 됩니다.            │    │   │
│    │  └────────────────────┘    │   │
│    │                            │   │
│    │  해제 사유:                 │   │ labelMedium, onSurfaceVariant
│    │  "여행 일정 변경으로 인해    │   │ bodyMedium, onSurface
│    │   가디언 교체가 필요합니다"  │   │ 인용 스타일
│    │                            │   │
│    │  ┌──────────┐ ┌──────────┐│   │
│    │  │   거절    │ │   승인    ││   │
│    │  │          │ │          ││   │
│    │  └──────────┘ └──────────┘│   │ 거절: Button_Secondary
│    │                            │   │ 승인: Button_Destructive
│    └────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 (크루) | `AppBar` | title: "가디언 해제 요청", leading: BackButton, style: AppBar_Standard |
| 제목 (크루) | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 (크루) | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 안전 경고 카드 | `Card` | style: Card_Alert, borderColor: semanticWarning (#FF9800), borderWidth: 1px |
| 경고 제목 | `Text` | style: titleMedium (18sp, SemiBold), prefix: ⚠️, color: onSurface |
| 경고 본문 | `Text` | style: bodyMedium (14sp), color: onSurface |
| 경고 부연 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 해제 대상 카드 | `Card` + `ListTile` | style: Card_Standard, leading: CircleAvatar (40dp), title: 가디언명 + Badge_Role(가디언) |
| 해제 대상 정보 | `Text` | subtitle: 연결 일자, trailing: 담당 멤버명, style: bodySmall (12sp) |
| 사유 라벨 | `Text` | style: labelMedium (14sp, Medium 500), color: onSurface, "*" suffix: semanticError |
| 사유 입력 | `TextFormField` | style: Input_Text, maxLines: 4, maxLength: 200, hintText: "해제 사유를 입력해주세요", validator: 필수 (10자 이상) |
| 글자 수 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, alignment: right |
| 승인 요청 버튼 | `ElevatedButton` | style: Button_Primary, text: "캡틴에게 승인 요청", enabled: 사유 10자 이상 |
| 캡틴 다이얼로그 | `AlertDialog` | style: Dialog_Confirm (확장형), radius16, 너비 320dp |
| 다이얼로그 제목 | `Text` | style: titleMedium (18sp, SemiBold), text: "가디언 해제 승인 요청" |
| 다이얼로그 본문 | `Text` | style: bodyMedium (14sp), color: onSurface |
| 다이얼로그 경고 | `Card` (inline) | style: Card_Alert, borderColor: semanticWarning (#FF9800) |
| 사유 표시 | `Container` | style: bodyMedium (14sp), 인용 스타일 (좌측 보더 4px, outline 색상) |
| 거절 버튼 | `OutlinedButton` | style: Button_Secondary, text: "거절" |
| 승인 버튼 | `ElevatedButton` | style: Button_Destructive, text: "승인" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| **크루 화면** | |
| 초기 | 사유 입력 비어 있음, 승인 요청 버튼 비활성 (opacity 0.4) |
| 사유 입력 중 | 글자 수 카운터 실시간 업데이트 (n/200) |
| 사유 10자 미만 | 승인 요청 버튼 비활성, 안내 텍스트 "10자 이상 입력해주세요" |
| 사유 10자 이상 | 승인 요청 버튼 활성 (primaryTeal) |
| 요청 전송 중 | 버튼 → CircularProgressIndicator |
| 요청 전송 성공 | Toast "캡틴에게 승인 요청을 보냈습니다", Navigator.pop → F-01 (대기 상태 표시) |
| 요청 전송 실패 | SnackBar "요청 전송에 실패했습니다. 다시 시도해주세요." |
| **캡틴 다이얼로그** | |
| 알림 수신 | 푸시 알림: "홍길동이 가디언 해제를 요청했습니다" → 탭 시 다이얼로그 표시 |
| 다이얼로그 표시 | 요청 정보 + 안전 경고 + 사유 표시, 거절/승인 버튼 활성 |
| 승인 처리 중 | 승인 버튼 → CircularProgressIndicator |
| 승인 완료 | PATCH /api/v1/trips/:tripId/guardians/:linkId/release → approved, Toast "가디언이 해제되었습니다", 다이얼로그 닫힘 |
| 거절 완료 | PATCH /api/v1/trips/:tripId/guardians/:linkId/release → rejected, Toast "해제 요청을 거절했습니다", 다이얼로그 닫힘 |
| 거절 → 크루 알림 | 크루에게 푸시: "캡틴이 가디언 해제를 거절했습니다", F-01에서 상태 "거절됨" 표시 |

**인터랙션**

- [탭] 사유 입력 필드 → 키보드 표시 (multiline)
- [탭] 캡틴에게 승인 요청 → POST /api/v1/trips/:tripId/guardians/:linkId/release-request { reason } → 캡틴에게 푸시 알림
- [캡틴 푸시 탭] → 앱 열림 + 다이얼로그 자동 표시
- [탭] 거절 → PATCH /api/v1/trips/:tripId/guardians/:linkId/release { action: "rejected" }
- [탭] 승인 → Dialog_Confirm (2차 확인) "정말 가디언을 해제하시겠습니까?" → 확인 시 PATCH { action: "approved" }
- [뒤로가기 / 다이얼로그 외부 탭] → 다이얼로그 닫힘 (미결 상태 유지, 알림에서 재진입 가능)
- [뒤로가기 — 크루 화면] → F-01 가디언 관리

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 4개 화면 (M-01 ~ M-04) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 비즈니스 원칙 §10: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 가디언 시스템 와이어프레임: `docs/wireframes/F_Guardian_System.md`
