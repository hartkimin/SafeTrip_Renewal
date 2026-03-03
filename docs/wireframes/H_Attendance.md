# H. 출석 체크

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 출석 체크 플로우 5개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| DB 설계 v3.5 | `Master_docs/07_T2_DB_설계_및_관계_v3_5.md` |
| API 명세서 Part2 | `Master_docs/37_T2_API_명세서_Part2.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 5개 (H-01 ~ H-05)
- **Phase:** 전체 P1
- **핵심 역할:** 캡틴/크루장 (생성), 크루 (응답), 가디언 (결과 조회)
- **연관 테이블:** `TB_ATTENDANCE_CHECK`, `TB_ATTENDANCE_RESPONSE`
- **API 엔드포인트:** `POST /api/v1/groups/:group_id/attendance/start`

---

## User Journey Flow

```
[캡틴/크루장]                    [크루]                      [가디언]
     │                            │                           │
  H-01 출석 체크 생성              │                           │
     │                            │                           │
     ├── [출석 시작] ──→ FCM Push ──→ H-02 출석 응답             │
     │                            │                           │
     │                      [출석/결석 응답]                    │
     │                            │                           │
  H-03 출석 진행 현황 ←──── 실시간 업데이트 ──────────────────────│
     │                                                        │
     ├── [마감 시간 경과]                                      │
     │                                                        │
  H-04 출석 결과 ──────────────────────────────────→ H-05 가디언 출석 결과
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| D-01 멤버탭 | 캡틴/크루장 "출석 체크" 액션 | H-01 출석 체크 생성 | H |
| FCM Push 알림 | 크루 알림 탭 | H-02 출석 응답 | H |
| H-01 | 출석 시작 완료 | H-03 출석 진행 현황 | H |
| H-03 | 마감 시간 경과 | H-04 출석 결과 | H |
| F-04 가디언홈 | 출석 결과 알림 | H-05 가디언 출석 결과 | H |
| H-04 | 완료 | D-01 멤버탭 | D |

---

## 디자인 토큰 (출석 전용)

| 토큰명 | HEX | 용도 |
|--------|-----|------|
| `attendanceGreen` | `#4CAF50` | 출석 상태 배경, 출석 버튼 |
| `absentRed` | `#DA4C51` | 결석 상태 배경, 결석 버튼 (`semanticError`) |
| `noResponseGray` | `#8E8E93` | 미응답 상태 배경 (`onSurfaceVariant`) |
| `timerUrgent` | `#FF807B` | 마감 5분 이내 카운트다운 (`primaryCoral`) |
| `progressTrack` | `#EDEDED` | 진행률 바 트랙 (`outline`) |

---

## 화면 상세

---

### H-01 출석 체크 생성 (Attendance Create)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | H-01 |
| 화면명 | 출석 체크 생성 (Attendance Create) |
| Phase | P1 |
| 역할 | 캡틴, 크루장 |
| 진입 경로 | D-01 멤버탭 → "출석 체크" 액션 → H-01 |
| 이탈 경로 | H-01 → H-03 (출석 시작 성공) / H-01 → D-01 (취소) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 출석 체크 생성             │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  출석 체크를 시작합니다       │ headlineMedium (24sp, SemiBold)
│                             │
│  마감 시간과 대상 멤버를      │ bodyMedium (14sp)
│  설정해주세요                │ onSurfaceVariant
│                             │
│  ┌─ 마감 시간 ──────────────┐│
│  │ ⏰  마감 시간 설정         ││ Card_Standard
│  │                          ││
│  │    14:30                 ││ headlineMedium, primaryTeal
│  │    (30분 후)              ││ bodySmall, onSurfaceVariant
│  │                          ││
│  │  [15분] [30분] [1시간]    ││ Chip_Tag (퀵 선택)
│  │  [직접 입력]              ││ Chip_Tag (outlined)
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ 대상 멤버 ──────────────┐│
│  │ 👥  대상 멤버 선택         ││ Card_Standard
│  │                          ││
│  │  ☑ 전체 선택 (8명)        ││ CheckboxListTile (master)
│  │  ─────────────────────── ││ Divider
│  │  ☑ 👤 홍길동    캡틴       ││ CheckboxListTile + Badge_Role
│  │  ☑ 👤 김철수    크루장     ││ CheckboxListTile + Badge_Role
│  │  ☑ 👤 이영희    크루       ││ CheckboxListTile + Badge_Role
│  │  ☑ 👤 박민수    크루       ││ CheckboxListTile + Badge_Role
│  │  ...                     ││
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ 메시지 (선택) ──────────┐│
│  │ 출석체크를 확인해주세요     ││ Input_Text (multiline)
│  └──────────────────────────┘│ hintText
│                             │
│  ┌─────────────────────────┐│
│  │       출석 시작           ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "출석 체크 생성", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 마감 시간 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 시간 표시 | `Text` | style: headlineMedium (24sp, SemiBold), color: primaryTeal, 탭 시 TimePicker 표시 |
| 상대 시간 표시 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, "(N분 후)" 형식 |
| 퀵 선택 칩 | `Chip` | style: Chip_Tag, items: ["15분", "30분", "1시간", "직접 입력"], 선택 시 secondaryAmber 배경 |
| 대상 멤버 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 전체 선택 | `CheckboxListTile` | activeColor: primaryTeal, title: "전체 선택 (N명)" (titleMedium, SemiBold) |
| 구분선 | `Divider` | color: outline (#EDEDED), height: 1 |
| 멤버 항목 | `CheckboxListTile` | activeColor: primaryTeal, leading: CircleAvatar (40dp), subtitle: Badge_Role |
| 메시지 입력 | `TextFormField` | style: Input_Text, maxLines: 3, hintText: "출석체크를 확인해주세요", maxLength: 200 |
| 출석 시작 버튼 | `ElevatedButton` | style: Button_Primary, text: "출석 시작", enabled: 마감 시간 설정 + 1명 이상 선택 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 마감 시간 기본값 30분 후, 전체 선택 체크됨, 메시지 비어있음, 출석 시작 버튼 활성 |
| 퀵 선택 탭 (15분/30분/1시간) | 해당 칩 selected (secondaryAmber), 시간 표시 업데이트, 상대 시간 갱신 |
| 직접 입력 탭 | showTimePicker 다이얼로그 → 선택 시간 반영, "직접 입력" 칩 selected |
| 전체 선택 토글 | 모든 멤버 체크/해제, "(N명)" 카운트 갱신 |
| 개별 멤버 해제 | 전체 선택 indeterminate (─), 선택 인원 카운트 갱신 |
| 선택 멤버 0명 | 출석 시작 버튼 비활성 (opacity 0.4) |
| 전송 중 | 출석 시작 버튼 → CircularProgressIndicator (white, 24dp) |
| 전송 성공 | Toast "출석 체크가 시작되었습니다", Navigator.pushReplacement → H-03 |
| 전송 실패 | SnackBar "출석 체크 시작에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 퀵 선택 칩 → 마감 시간 = 현재 시각 + 선택 값 (15분/30분/1시간)
- [탭] "직접 입력" 칩 → `showTimePicker()` → 선택 시간 반영
- [탭] 시간 표시 영역 → `showTimePicker()` → 선택 시간 반영
- [탭] 전체 선택 → 모든 멤버 일괄 체크/해제
- [탭] 개별 멤버 체크박스 → 해당 멤버만 토글
- [탭] 출석 시작 → POST /api/v1/groups/:group_id/attendance/start → 성공 시 H-03
- [뒤로가기] → Dialog_Confirm "출석 체크 생성을 취소할까요?" (확인 → D-01 / 취소 → 유지)

---

### H-02 출석 응답 (Attendance Respond)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | H-02 |
| 화면명 | 출석 응답 (Attendance Respond) |
| Phase | P1 |
| 역할 | 크루 |
| 진입 경로 | FCM Push 알림 → H-02 / 알림 탭 → H-02 |
| 이탈 경로 | H-02 → C-01 메인맵 (응답 완료 후) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 출석 체크                 │ AppBar_Standard
├─────────────────────────────┤
│                             │
│                             │
│        ┌───────────┐        │
│        │           │        │
│        │   ⏱️       │        │ 카운트다운 타이머
│        │  14:32    │        │ displayLarge (36sp, Bold)
│        │           │        │ primaryTeal (> 5분)
│        │           │        │ primaryCoral (≤ 5분)
│        └───────────┘        │
│                             │
│      마감까지 남은 시간        │ bodyMedium, onSurfaceVariant
│                             │
│  ─────────────────────────  │ Divider
│                             │
│  ┌─────────────────────────┐│
│  │ 💬 캡틴의 메시지           ││ Card_Standard
│  │                          ││
│  │ "집결 장소로 모여주세요.    ││ bodyLarge (16sp)
│  │  10분 후 출발합니다."      ││ onSurface
│  │                          ││
│  │ 홍길동 (캡틴) · 14:00      ││ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │
│                             │
│                             │
│  ┌─────────────────────────┐│
│  │        출석              ││ ElevatedButton
│  └─────────────────────────┘│ 배경 #4CAF50, 텍스트 #FFFFFF
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │        결석              ││ OutlinedButton
│  └─────────────────────────┘│ 보더 #DA4C51, 텍스트 #DA4C51
│                             │
└─────────────────────────────┘
```

> **응답 완료 후 레이아웃:**

```
┌─────────────────────────────┐
│ [←] 출석 체크                 │ AppBar_Standard
├─────────────────────────────┤
│                             │
│                             │
│        ┌───────────┐        │
│        │           │        │
│        │    ✅      │        │ 출석 완료 아이콘
│        │           │        │ 80 x 80dp, #4CAF50
│        └───────────┘        │
│                             │
│       출석이 확인되었습니다    │ titleLarge (20sp, SemiBold)
│                             │ onSurface
│       14:02 응답             │ bodyMedium, onSurfaceVariant
│                             │
│  ─────────────────────────  │ Divider
│                             │
│  ┌─────────────────────────┐│
│  │ 💬 캡틴의 메시지           ││ Card_Standard
│  │ "집결 장소로 모여주세요."   ││
│  └─────────────────────────┘│
│                             │
│                             │
│  ┌─────────────────────────┐│
│  │        확인              ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "출석 체크", leading: BackButton, style: AppBar_Standard |
| 카운트다운 타이머 | `Text` + `Timer` | style: displayLarge (36sp, Bold 700), color: primaryTeal (#00A2BD) → primaryCoral (#FF807B, 5분 이내), format: "MM:SS" |
| 타이머 안내 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, text: "마감까지 남은 시간" |
| 구분선 | `Divider` | color: outline (#EDEDED), height: 1 |
| 메시지 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 메시지 내용 | `Text` | style: bodyLarge (16sp), color: onSurface |
| 발신자 정보 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, format: "이름 (역할) -- HH:MM" |
| 출석 버튼 | `ElevatedButton` | height: 52px, width: 전체 너비, radius12, backgroundColor: attendanceGreen (#4CAF50), text: "출석", textColor: #FFFFFF, labelLarge (16sp, SemiBold) |
| 결석 버튼 | `OutlinedButton` | height: 52px, width: 전체 너비, radius12, borderColor: absentRed (#DA4C51), text: "결석", textColor: #DA4C51, labelLarge (16sp, SemiBold) |
| 완료 아이콘 | `Icon` | Icons.check_circle, size: 80dp, color: attendanceGreen (#4CAF50) 또는 absentRed (#DA4C51) |
| 완료 텍스트 | `Text` | style: titleLarge (20sp, SemiBold), color: onSurface |
| 응답 시간 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, format: "HH:MM 응답" |
| 확인 버튼 | `ElevatedButton` | style: Button_Primary, text: "확인" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (미응답) | 카운트다운 타이머 활성, 출석/결석 버튼 표시, 메시지 카드 표시 |
| 타이머 > 5분 | 타이머 색상 primaryTeal (#00A2BD) |
| 타이머 <= 5분 | 타이머 색상 primaryCoral (#FF807B), 1초마다 깜빡이는 애니메이션 |
| 출석 탭 | Dialog_Confirm "출석으로 응답하시겠습니까?" → 확인 → 출석 완료 화면 |
| 결석 탭 | Dialog_Confirm "결석으로 응답하시겠습니까?" → 확인 → 결석 완료 화면 |
| 출석 완료 | 카운트다운 영역 → ✅ 아이콘 (#4CAF50) + "출석이 확인되었습니다" + 응답 시간 |
| 결석 완료 | 카운트다운 영역 → ❌ 아이콘 (#DA4C51) + "결석으로 응답했습니다" + 응답 시간 |
| 응답 전송 중 | 선택 버튼 → CircularProgressIndicator |
| 응답 실패 | SnackBar "응답에 실패했습니다. 다시 시도해주세요." |
| 타이머 만료 (0:00) | 출석/결석 버튼 비활성 (opacity 0.4), "마감 시간이 경과했습니다" 안내 표시 |
| 메시지 없음 | 메시지 카드 영역 숨김 |

**인터랙션**

- [자동] 화면 진입 → 남은 시간 계산 (deadline_at - now) → 카운트다운 시작
- [탭] 출석 → Dialog_Confirm → PATCH /api/v1/groups/:group_id/attendance/:check_id/respond { response_type: 'present' }
- [탭] 결석 → Dialog_Confirm → PATCH /api/v1/groups/:group_id/attendance/:check_id/respond { response_type: 'absent' }
- [탭] 확인 (응답 완료 후) → Navigator.pop → C-01 메인맵
- [뒤로가기] → 미응답 상태 유지, Navigator.pop (알림 탭에서 재진입 가능)

---

### H-03 출석 진행 현황 (Attendance Progress)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | H-03 |
| 화면명 | 출석 진행 현황 (Attendance Progress) |
| Phase | P1 |
| 역할 | 캡틴, 크루장 |
| 진입 경로 | H-01 출석 시작 성공 → H-03 |
| 이탈 경로 | H-03 → H-04 (마감 시간 경과) / H-03 → D-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 출석 진행 현황       [⋮]  │ AppBar_Standard + 더보기 메뉴
├─────────────────────────────┤
│                             │
│  ┌─ 진행 상태 ──────────────┐│
│  │                          ││ Card_Standard
│  │  ⏱️ 남은 시간: 12:45      ││ bodyLarge, primaryCoral
│  │                          ││
│  │  ▓▓▓▓▓▓▓▓▓░░░░░░  5/8   ││ LinearProgressIndicator
│  │                          ││ 62.5%, primaryTeal
│  │  응답 5명 / 전체 8명       ││ bodySmall, onSurfaceVariant
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ 응답 현황 ──────────────┐│
│  │                          ││
│  │  [출석 3] [결석 1] [미응답 4]│ 탭 형태 필터
│  │                          ││
│  │  ── 출석 (3명) ────────── ││ Section Header, #4CAF50
│  │  👤 김철수    크루장  14:02 ││ ListTile_Member
│  │  👤 이영희    크루    14:05 ││ + 응답 시간
│  │  👤 박민수    크루    14:08 ││
│  │                          ││
│  │  ── 결석 (1명) ────────── ││ Section Header, #DA4C51
│  │  👤 최지훈    크루    14:03 ││ ListTile_Member
│  │                          ││
│  │  ── 미응답 (4명) ──────── ││ Section Header, #8E8E93
│  │  👤 정수진    크루     --   ││ ListTile_Member
│  │  👤 한지민    크루     --   ││ (회색 텍스트)
│  │  👤 윤서연    크루     --   ││
│  │  👤 강도윤    크루     --   ││
│  │                          ││
│  └──────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │      즉시 마감            ││ Button_Destructive
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "출석 진행 현황", leading: BackButton, actions: [PopupMenuButton], style: AppBar_Standard |
| 더보기 메뉴 | `PopupMenuButton` | items: ["취소"] |
| 진행 상태 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 남은 시간 | `Text` + `Timer` | style: bodyLarge (16sp, SemiBold), color: primaryCoral (#FF807B, 5분 이내) / primaryTeal (> 5분), icon: ⏱️, format: "남은 시간: MM:SS" |
| 진행률 바 | `LinearProgressIndicator` | height: 8dp, radius4, color: primaryTeal (#00A2BD), backgroundColor: outline (#EDEDED), value: responded/total |
| 응답 카운트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, format: "응답 N명 / 전체 N명" |
| 탭 필터 | `Row` < `FilterChip` > | 3개: "출석 N" (#4CAF50), "결석 N" (#DA4C51), "미응답 N" (#8E8E93) |
| 섹션 헤더 (출석) | `Text` | style: labelMedium (14sp, Medium 500), color: attendanceGreen (#4CAF50), text: "출석 (N명)" |
| 섹션 헤더 (결석) | `Text` | style: labelMedium (14sp, Medium 500), color: absentRed (#DA4C51), text: "결석 (N명)" |
| 섹션 헤더 (미응답) | `Text` | style: labelMedium (14sp, Medium 500), color: noResponseGray (#8E8E93), text: "미응답 (N명)" |
| 멤버 항목 | `ListTile` | style: ListTile_Member 변형, leading: CircleAvatar (40dp), title: 이름 (bodyLarge), subtitle: Badge_Role, trailing: 응답 시간 (bodySmall) |
| 출석 멤버 항목 | `ListTile` | 좌측 4px 보더 attendanceGreen (#4CAF50), trailing: 응답 시간 (bodySmall, #4CAF50) |
| 결석 멤버 항목 | `ListTile` | 좌측 4px 보더 absentRed (#DA4C51), trailing: 응답 시간 (bodySmall, #DA4C51) |
| 미응답 멤버 항목 | `ListTile` | opacity: 0.5, trailing: "--" (bodySmall, #8E8E93) |
| 즉시 마감 버튼 | `ElevatedButton` | style: Button_Destructive, text: "즉시 마감" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 전체 멤버 미응답 상태, 진행률 0%, 타이머 활성 |
| 실시간 응답 수신 | RTDB 리스너로 응답 수신 → 해당 멤버 섹션 이동 (미응답 → 출석/결석), 진행률 바 갱신, 카운트 갱신 |
| 전원 응답 완료 | Toast "전원 응답 완료!", 자동으로 H-04 출석 결과 화면 전환 (2초 후) |
| 타이머 > 5분 | 남은 시간 색상 primaryTeal |
| 타이머 <= 5분 | 남은 시간 색상 primaryCoral, 깜빡이는 애니메이션 |
| 타이머 만료 (0:00) | 자동으로 H-04 출석 결과 화면 전환, 미응답자 자동 결석 처리 |
| 즉시 마감 탭 | Dialog_Confirm "즉시 마감하시겠습니까? 미응답자는 자동 결석 처리됩니다." → 확인 → H-04 |
| 취소 (더보기 메뉴) | Dialog_Confirm "출석 체크를 취소하시겠습니까?" → 확인 → 출석 체크 취소 API → D-01 |
| 탭 필터 선택 | 해당 상태 멤버만 필터링 (전체/출석/결석/미응답) |

**인터랙션**

- [자동] 화면 진입 → RTDB `/attendance/{check_id}` 리스너 등록 → 실시간 응답 상태 업데이트
- [자동] 타이머 1초 간격 갱신 → 만료 시 자동 H-04 전환
- [자동] 전원 응답 완료 → 2초 후 자동 H-04 전환
- [탭] 탭 필터 (출석/결석/미응답) → 해당 멤버만 표시
- [탭] 즉시 마감 → Dialog_Confirm → PATCH /api/v1/groups/:group_id/attendance/:check_id/close → H-04
- [탭] 더보기 → 취소 → Dialog_Confirm → DELETE /api/v1/groups/:group_id/attendance/:check_id → D-01
- [풀 리프레시] → 최신 응답 현황 재조회
- [뒤로가기] → Dialog_Confirm "진행 중인 출석 체크가 있습니다. 나가시겠습니까?" (출석 체크는 유지됨)

---

### H-04 출석 결과 (Attendance Result)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | H-04 |
| 화면명 | 출석 결과 (Attendance Result) |
| Phase | P1 |
| 역할 | 캡틴, 크루장 |
| 진입 경로 | H-03 마감 시간 경과/즉시 마감 → H-04 |
| 이탈 경로 | H-04 → D-01 멤버탭 (완료) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 출석 결과           [↗️]  │ AppBar_Standard + 공유 버튼
├─────────────────────────────┤
│                             │
│  ┌─ 통계 요약 ──────────────┐│
│  │                          ││ Card_Standard
│  │   ┌─────────────────┐    ││
│  │   │                 │    ││
│  │   │   🟢 3  🔴 2     │    ││ 파이 차트 (PieChart)
│  │   │     ⚪ 3         │    ││ 출석/결석/미응답(자동결석)
│  │   │                 │    ││
│  │   └─────────────────┘    ││
│  │                          ││
│  │  전체 8명                 ││ titleMedium, onSurface
│  │  출석 3 · 결석 2 · 자동결석 3││ bodyMedium, onSurfaceVariant
│  │                          ││
│  │  마감: 14:30 · 생성: 14:00 ││ bodySmall, onSurfaceVariant
│  └──────────────────────────┘│
│                             │ spacing16
│  ┌─ 멤버별 결과 ────────────┐│
│  │                          ││
│  │  ── 출석 (3명) ────────── ││ Section Header, #4CAF50
│  │  👤 김철수   크루장  14:02 ││ ListTile + ✅ 출석 뱃지
│  │  👤 이영희   크루    14:05 ││
│  │  👤 박민수   크루    14:08 ││
│  │                          ││
│  │  ── 결석 (2명) ────────── ││ Section Header, #DA4C51
│  │  👤 최지훈   크루    14:03 ││ ListTile + ❌ 결석 뱃지
│  │  👤 한지민   크루    14:12 ││
│  │                          ││
│  │  ── 자동 결석 (3명) ───── ││ Section Header, #8E8E93
│  │  👤 정수진   크루    미응답 ││ ListTile + ⚪ 자동결석 뱃지
│  │  👤 윤서연   크루    미응답 ││
│  │  👤 강도윤   크루    미응답 ││
│  │                          ││
│  └──────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │        완료              ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "출석 결과", leading: BackButton, actions: [ShareButton], style: AppBar_Standard |
| 공유 버튼 | `IconButton` | icon: Icons.ios_share, onPressed: 결과 텍스트 공유 |
| 통계 요약 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 파이 차트 | `PieChart` (fl_chart) | sections: 3개 (출석 #4CAF50, 결석 #DA4C51, 자동결석 #8E8E93), size: 160dp, centerText: 전체 인원 |
| 전체 인원 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 통계 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, format: "출석 N -- 결석 N -- 자동결석 N" |
| 시간 정보 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, format: "마감: HH:MM -- 생성: HH:MM" |
| 섹션 헤더 (출석) | `Text` | style: labelMedium (14sp, Medium 500), color: attendanceGreen (#4CAF50) |
| 섹션 헤더 (결석) | `Text` | style: labelMedium (14sp, Medium 500), color: absentRed (#DA4C51) |
| 섹션 헤더 (자동 결석) | `Text` | style: labelMedium (14sp, Medium 500), color: noResponseGray (#8E8E93) |
| 출석 멤버 항목 | `ListTile` | leading: CircleAvatar (40dp), title: 이름 (bodyLarge), subtitle: Badge_Role, trailing: Row [응답 시간 + 출석 뱃지 (Container, #4CAF50, pill, "출석")] |
| 결석 멤버 항목 | `ListTile` | trailing: Row [응답 시간 + 결석 뱃지 (Container, #DA4C51, pill, "결석")] |
| 자동결석 멤버 항목 | `ListTile` | trailing: Row ["미응답" + 자동결석 뱃지 (Container, #8E8E93, pill, "자동결석")], opacity: 0.7 |
| 완료 버튼 | `ElevatedButton` | style: Button_Primary, text: "완료" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 자동결석 처리 완료된 최종 결과 표시, 파이 차트 애니메이션 (500ms) |
| 미응답자 자동결석 | deadline_at 경과 시 response_type='unknown' → 'absent' 자동 변환, "자동결석" 뱃지 별도 표시 |
| 공유 탭 | Share 시트 → 텍스트 형태 결과 요약 (이름/상태/시간 테이블) |
| 결과 없음 (전원 미응답) | 파이 차트 전체 회색, "응답한 멤버가 없습니다" 안내 |
| 완료 탭 | Navigator.popUntil → D-01 멤버탭 |

**인터랙션**

- [자동] 화면 진입 → GET /api/v1/groups/:group_id/attendance/:check_id/result → 최종 결과 렌더링
- [자동] 파이 차트 500ms 애니메이션 (0% → 실제 비율)
- [탭] 공유 (↗️) → `Share.share()` → 텍스트 형태 결과 (출석 체크 결과 | 날짜 | 출석 N명 / 결석 N명 / 미응답 N명)
- [탭] 멤버 항목 → 확장 패널 (응답 시간 상세, 위치 정보 등) (P2 확장 예정)
- [탭] 완료 → Navigator.popUntil → D-01 멤버탭
- [뒤로가기] → Navigator.popUntil → D-01 멤버탭

---

### H-05 가디언 출석 결과 (Guardian Attendance View)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | H-05 |
| 화면명 | 가디언 출석 결과 (Guardian Attendance View) |
| Phase | P1 |
| 역할 | 가디언 |
| 진입 경로 | F-04 가디언홈 → 출석 결과 알림/이력 → H-05 |
| 이탈 경로 | H-05 → F-04 가디언홈 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 출석 결과                 │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─ 내 멤버 출석 상태 ───────┐│
│  │                          ││ Card_Standard
│  │  👤 이영희                 ││ CircleAvatar (56dp)
│  │  크루                     ││ Badge_Role
│  │                          ││
│  │  ┌────────────────────┐  ││
│  │  │     ✅ 출석         │  ││ 상태 뱃지 (대형)
│  │  └────────────────────┘  ││ 배경 #4CAF50/20%, 텍스트 #4CAF50
│  │                          ││ 또는 ❌ 결석 (#DA4C51)
│  │  14:05 응답               ││ 또는 ⚪ 미응답 (#8E8E93)
│  │                          ││ bodyMedium, onSurfaceVariant
│  └──────────────────────────┘│
│                             │ spacing24
│  출석 체크 이력               │ titleMedium (18sp, SemiBold)
│                             │
│  ┌─ 이력 리스트 ────────────┐│
│  │                          ││
│  │  📋 3월 3일 14:00         ││ ListTile
│  │  캡틴: 홍길동              ││ bodySmall, onSurfaceVariant
│  │                 ✅ 출석   ││ 상태 뱃지 (소형, trailing)
│  │  ─────────────────────── ││ Divider
│  │                          ││
│  │  📋 3월 2일 09:30         ││ ListTile
│  │  캡틴: 홍길동              ││
│  │                 ❌ 결석   ││ 상태 뱃지
│  │  ─────────────────────── ││ Divider
│  │                          ││
│  │  📋 3월 1일 08:00         ││ ListTile
│  │  캡틴: 홍길동              ││
│  │                 ✅ 출석   ││ 상태 뱃지
│  │                          ││
│  └──────────────────────────┘│
│                             │
│  이전 기록 더 보기 >           │ TextButton, primaryTeal
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "출석 결과", leading: BackButton, style: AppBar_Standard |
| 멤버 카드 | `Card` | style: Card_Standard, padding: spacing16, alignment: center |
| 멤버 아바타 | `CircleAvatar` | radius: 28dp (56dp 직경), backgroundColor: secondaryBeige (#F2EDE4) |
| 멤버 이름 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 역할 뱃지 | `Container` | style: Badge_Role (크루: #898989) |
| 대형 상태 뱃지 | `Container` | width: 160dp, height: 48dp, radius12, 상태별 색상 분기 (아래 참조) |
| 출석 뱃지 (대형) | `Container` | backgroundColor: #4CAF50/20% (투명도), text: "✅ 출석", textColor: #4CAF50, titleMedium (18sp, SemiBold) |
| 결석 뱃지 (대형) | `Container` | backgroundColor: #DA4C51/20%, text: "❌ 결석", textColor: #DA4C51 |
| 미응답 뱃지 (대형) | `Container` | backgroundColor: #8E8E93/20%, text: "⚪ 미응답", textColor: #8E8E93 |
| 응답 시간 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, format: "HH:MM 응답" |
| 섹션 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface, text: "출석 체크 이력" |
| 이력 항목 | `ListTile` | leading: 📋 아이콘, title: 날짜+시간 (bodyLarge), subtitle: "캡틴: 이름" (bodySmall, onSurfaceVariant), trailing: 상태 뱃지 (소형) |
| 소형 상태 뱃지 | `Container` | height: 24dp, radius4, padding: 4px 8px, 상태별 배경색 (출석 #4CAF50, 결석 #DA4C51, 미응답 #8E8E93), text: labelSmall (11sp), textColor: #FFFFFF |
| 구분선 | `Divider` | color: outlineVariant (#F5F5F5), height: 1 |
| 더 보기 버튼 | `TextButton` | style: labelMedium (14sp), color: primaryTeal, text: "이전 기록 더 보기 >" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 최신 출석 체크 결과 + 이력 리스트 표시 |
| 출석 결과 | 대형 뱃지 "✅ 출석" (#4CAF50/20% 배경), 응답 시간 표시 |
| 결석 결과 | 대형 뱃지 "❌ 결석" (#DA4C51/20% 배경), 응답 시간 표시 |
| 자동결석 (미응답) | 대형 뱃지 "⚪ 미응답" (#8E8E93/20% 배경), "마감 시간 내 미응답" 안내 |
| 진행 중 (아직 미마감) | 대형 뱃지 "⏳ 진행 중" (primaryTeal/20% 배경), 카운트다운 표시 |
| 이력 없음 | "출석 체크 이력이 없습니다" + 일러스트 (빈 상태) |
| 이력 로딩 | 이력 영역 Shimmer 효과 |
| 더 보기 탭 | 이전 이력 10건씩 추가 로드 (페이지네이션) |
| 다중 멤버 연결 | 멤버 선택 드롭다운 표시 (가디언이 여러 멤버를 보호하는 경우) |

**인터랙션**

- [자동] 화면 진입 → GET /api/v1/guardians/:guardian_id/attendance/:member_id → 연결 멤버 출석 결과 조회
- [자동] 이력 리스트 → GET /api/v1/guardians/:guardian_id/attendance/:member_id/history?page=1&limit=10
- [탭] 이력 항목 → 상세 정보 확장 (생성자 메시지, 정확한 응답 시간)
- [탭] 이전 기록 더 보기 → 다음 페이지 로드 (page+1)
- [탭] 멤버 선택 드롭다운 (다중 연결 시) → 선택 멤버의 출석 결과로 갱신
- [뒤로가기] → Navigator.pop → F-04 가디언홈

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 5개 화면 (H-01 ~ H-05) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- DB 설계 v3.5: `Master_docs/07_T2_DB_설계_및_관계_v3_5.md`
- API 명세서 Part2: `Master_docs/37_T2_API_명세서_Part2.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
