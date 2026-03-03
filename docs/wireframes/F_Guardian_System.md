# F. 가디언 시스템

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 가디언 시스템 10개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |
| 화면 목업 구현 | `docs/plans/2026-03-03-screen-mockup-implementation.md` |

---

## 개요

- **화면 수:** 10개 (F-01 ~ F-10)
- **Phase:** P0 7개 (F-01 ~ F-07), P1 3개 (F-08 ~ F-10)
- **핵심 역할:** 가디언 (보호자), 크루/캡틴 (연결 관리)
- **연관 문서:** 비즈니스 원칙 §06 가디언 시스템

---

## 하위 그룹

| 그룹 | 화면 | 설명 |
|------|------|------|
| 연결 & 관리 (크루 측) | F-01 ~ F-03 | 가디언 추가 / 관리 / 승인 |
| 가디언 전용 (가디언 모드) | F-04 ~ F-06 | 가디언 홈 / 멤버 상세 / 메시지 |
| 긴급 기능 | F-07 ~ F-09 | 긴급 알림 / 위치 요청 / 승인 |
| 전체여행 가디언 | F-10 | 캡틴 전용 전체여행 가디언 관리 |

---

## 디자인 토큰 (가디언 전용)

| 토큰 | HEX | 용도 |
|------|-----|------|
| Guardian Teal | `#15A1A5` | 가디언 역할 색상, 탭 활성, 마커 테두리 |
| SOS/Emergency | `#D32F2F` | SOS 전용 위험 색상 |
| Alert Coral | `#FF807B` | 긴급 알림 강조, 경고 아이콘 |
| Connected | `#4CAF50` | 연결됨 상태 뱃지 |
| Pending | `#FFB800` | 대기 중 상태 뱃지 |
| Rejected | `#DA4C51` | 거절됨 상태 뱃지 |

---

## User Journey Flow

```
[크루 측 플로우]

F-02 가디언 관리 (가디언 목록)
 ├── [+ 추가] → F-01 가디언 추가 (전화번호 입력 → 링크 요청)
 │                 └── [요청 전송] → F-02 (대기 중 상태 반영)
 └── [가디언 카드 탭] → 상태별 분기
      ├── 연결됨 → 해제 확인 Dialog
      ├── 대기 중 → 요청 취소 확인 Dialog
      └── 거절됨 → 재요청 또는 삭제

[가디언 측 플로우]

F-03 가디언 링크 승인 (푸시 알림/인앱 알림 → 승인 화면)
 ├── [수락] → F-04 가디언 홈
 └── [거절] → 알림 목록으로 복귀

F-04 가디언 홈 (연결 멤버 카드 목록)
 ├── [멤버 카드 탭] → F-05 가디언 멤버 상세
 │                      ├── [메시지 보내기] → F-06 가디언 메시지
 │                      ├── [긴급 알림] → F-07 긴급 알림 발송
 │                      └── [위치 요청] → F-08 위치 요청 (P1)
 └── [긴급 알림 버튼] → F-07 긴급 알림 발송

F-08 가디언 위치 요청 (P1)
 └── [요청 전송] → 프라이버시 등급별 분기
      ├── 안전최우선 → 자동 승인 (위치 즉시 수신)
      ├── 표준 → 실시간 위치 수신
      └── 프라이버시우선 → F-09 위치 요청 승인 (멤버 측)

[캡틴 전용]
F-10 전체여행 가디언 관리 (P1)
 └── [추가/해제] → 전체 멤버 자동 적용
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| A-06 | 가디언 프로필 완료 | F-04 가디언 홈 | A → F |
| D-09 | 멤버 목록 → 가디언 관리 | F-02 가디언 관리 | D → F |
| C-01 | 가디언 모드 메인맵 | F-04 가디언 홈 (바텀시트) | C → F |
| F-03 | 링크 수락 완료 | F-04 가디언 홈 | F 내부 |
| F-05 | 메시지 보내기 | F-06 가디언 메시지 | F 내부 |
| F-05 | 긴급 알림 | F-07 긴급 알림 발송 | F 내부 |
| F-08 | 프라이버시우선 요청 | F-09 위치 요청 승인 | F 내부 |
| K-01 | 설정 → 가디언 관리 | F-02 가디언 관리 | K → F |
| 푸시 알림 | 가디언 연결 요청 수신 | F-03 가디언 링크 승인 | 외부 → F |
| 푸시 알림 | 긴급 알림 수신 (멤버) | G-03 긴급 알림 수신 | F → G |

---

## 화면 상세

---

### F-01 가디언 추가 (Add Guardian)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-01 |
| 화면명 | 가디언 추가 (Add Guardian) |
| 화면 ID | `guardian-add` |
| Phase | P0 |
| 역할 | 크루 / 캡틴 |
| 진입 경로 | F-02 가디언 관리 → [+ 추가] → F-01 |
| 이탈 경로 | F-01 → F-02 (요청 전송 성공) / F-01 → F-02 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 가디언 추가               │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │  가디언 슬롯              ││ Card_Standard (beige bg)
│  │                         ││
│  │  ●  ●  ○  ○  ○         ││ 5 circles in row
│  │  무료  무료  ₩   ₩   ₩   ││ labelSmall, 각 원 아래
│  │                         ││
│  │  현재 1/5명 연결됨        ││ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │ spacing24
│  전화번호                    │ labelMedium, onSurface
│  ┌─ Country Picker ───────┐ │
│  │ 🇰🇷 대한민국 (+82)  ▼    │ │ DropdownButtonFormField
│  └─────────────────────────┘ │
│                             │ spacing8
│  ┌─ Phone Input ──────────┐ │
│  │ 010-0000-0000           │ │ Input_Text (phone)
│  └─────────────────────────┘ │
│                             │ spacing16
│  메시지 (선택)               │ labelMedium, onSurfaceVariant
│  ┌─ Message Input ────────┐ │
│  │ 가디언에게 전할 메시지    │ │ Input_Text (multiline)
│  └─────────────────────────┘ │
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │ ℹ️ 가디언은 회원님의 위치를││ Card_Standard (beige bg)
│  │   확인하고 긴급 시 알림을 ││ bodySmall, onSurfaceVariant
│  │   보낼 수 있습니다        ││
│  │                         ││
│  │   프라이버시 등급에 따라   ││
│  │   접근 범위가 달라집니다   ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │    연결 요청 보내기        ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "가디언 추가", leading: BackButton, style: AppBar_Standard |
| 슬롯 카드 | `Card` | style: Card_Standard, backgroundColor: secondaryBeige (#F2EDE4) |
| 슬롯 원형 (무료) | `Container` (원형) | 24dp, filled, color: primaryTeal (#00A2BD) |
| 슬롯 원형 (유료) | `Container` (원형) | 24dp, outlined, border: outline (#EDEDED), 내부 "₩" 아이콘 |
| 슬롯 현황 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 국가코드 선택 | `DropdownButtonFormField` | items: countryList, value: "+82" |
| 전화번호 입력 | `TextFormField` | style: Input_Text, keyboardType: phone, hintText: "010-0000-0000" |
| 메시지 입력 | `TextFormField` | style: Input_Text, maxLines: 3, maxLength: 100, hintText: "가디언에게 전할 메시지" |
| 안내 카드 | `Card` | style: Card_Standard, backgroundColor: secondaryBeige, leading: ℹ️ 아이콘 |
| 요청 버튼 | `ElevatedButton` | style: Button_Primary, text: "연결 요청 보내기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 슬롯 현황 표시, 전화번호 비어있음, 요청 버튼 비활성 (opacity 0.4) |
| 전화번호 입력 중 | 입력 필드 보더 primaryTeal, 실시간 형식 검증 |
| 전화번호 유효 | 요청 버튼 활성 (primaryTeal) |
| 전화번호 무효 | 입력 필드 보더 semanticError, 에러 텍스트 "유효한 전화번호를 입력해주세요" |
| 무료 슬롯 소진 | 슬롯 카드에 "유료 슬롯 사용 (1,900원/인)" 안내 표시, 결제 플로우 연결 |
| 전체 슬롯 소진 (5/5) | 요청 버튼 비활성, "가디언 슬롯이 모두 사용 중입니다" 안내 |
| 요청 전송 중 | 버튼 → CircularProgressIndicator (white, 24dp) |
| 요청 전송 성공 | Toast "가디언 연결 요청을 보냈습니다", Navigator.pop → F-02 |
| 요청 전송 실패 | SnackBar "연결 요청에 실패했습니다. 다시 시도해주세요." |
| 이미 연결된 번호 | SnackBar "이미 연결된 가디언입니다" |
| 자기 자신 번호 | SnackBar "본인을 가디언으로 추가할 수 없습니다" |

**인터랙션**

- [탭] 국가코드 영역 → Modal_Bottom 국가 목록 표시 (국기 + 국가명 + 코드, 검색 가능)
- [탭] 전화번호 입력 → 숫자 키패드 표시
- [탭] 메시지 입력 → 텍스트 키보드 표시
- [탭] 연결 요청 보내기 → POST /api/v1/trips/:tripId/guardians { guardian_phone, message }
- [탭] 유료 슬롯 구매 안내 → Navigator.push → L-01 요금 안내 (결제 플로우)
- [뒤로가기] → F-02 가디언 관리

---

### F-02 가디언 관리 (Guardian Manage)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-02 |
| 화면명 | 가디언 관리 (Guardian Manage) |
| 화면 ID | `guardian-manage` |
| Phase | P0 |
| 역할 | 크루 / 캡틴 |
| 진입 경로 | D-09 멤버 목록 → F-02 / K-01 설정 → F-02 |
| 이탈 경로 | F-02 → F-01 (추가) / F-02 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 가디언 관리               │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  전체여행 가디언              │ titleMedium (18sp, SemiBold)
│  캡틴이 지정 · 무료 2명       │ bodySmall, onSurfaceVariant
│  ┌─────────────────────────┐│
│  │ 👤 박부모                 ││ ListTile: avatar + name
│  │ 🟢 연결됨       [해제]    ││ Badge(green) + TextButton(red)
│  ├─────────────────────────┤│
│  │ ┌ - - - - - - - - - ┐   ││ Dashed border card
│  │ │    + 추가하기       │   ││ TextButton, primaryTeal
│  │ └ - - - - - - - - - ┘   ││
│  └─────────────────────────┘│
│                             │ spacing24
│  내 가디언                   │ titleMedium (18sp, SemiBold)
│  무료 2명 + 유료 3명 (1,900원)│ bodySmall, onSurfaceVariant
│  ┌─────────────────────────┐│
│  │ 👤 김보호자               ││ ListTile: avatar + name
│  │ 🟢 연결됨   📞   [해제]   ││ Badge + phone icon + TextButton
│  ├─────────────────────────┤│
│  │ ┌ - - - - - - - - - ┐   ││ 무료 슬롯 빈칸
│  │ │  + 무료 슬롯 추가   │   ││ TextButton, primaryTeal
│  │ └ - - - - - - - - - ┘   ││
│  ├─────────────────────────┤│
│  │ 👤 이안전                 ││
│  │ 🟡 대기 중      [취소]    ││ Badge(amber) + TextButton(gray)
│  ├─────────────────────────┤│
│  │ 🔒 유료 슬롯 ₩1,900      ││ 잠금 아이콘 + 가격
│  ├─────────────────────────┤│
│  │ 🔒 유료 슬롯 ₩1,900      ││ 잠금 아이콘 + 가격
│  └─────────────────────────┘│
│                             │ spacing16
│  ─────────────────────────── │ Divider
│  🟢 연결됨  🟡 대기 중  🔴 거절됨│ 상태 범례 (bodySmall)
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "가디언 관리", leading: BackButton, style: AppBar_Standard |
| 섹션 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 섹션 부제 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 가디언 카드 (연결됨) | `ListTile` | leading: CircleAvatar (40dp), title: name (bodyLarge), trailing: Badge (green #4CAF50) + TextButton "해제" |
| 가디언 카드 (대기 중) | `ListTile` | leading: CircleAvatar (40dp), title: name (bodyLarge), trailing: Badge (amber #FFB800) + TextButton "취소" |
| 가디언 카드 (거절됨) | `ListTile` | leading: CircleAvatar (40dp, opacity 0.5), title: name + 취소선, trailing: Badge (red #DA4C51) + TextButton "삭제" |
| 빈 슬롯 (무료) | `Container` | dashed border, radius8, 중앙 "+" 아이콘 + "무료 슬롯 추가" 텍스트, primaryTeal |
| 빈 슬롯 (유료) | `Container` | dashed border, radius8, 잠금 아이콘 + "유료 슬롯 ₩1,900" 텍스트, onSurfaceVariant |
| 전화 아이콘 | `IconButton` | icon: Icons.phone, color: primaryTeal, onPressed: 전화 연결 |
| 상태 범례 | `Row` | 원형 뱃지 3개 + 텍스트 (bodySmall) |
| 전체여행 가디언 표시 | `Chip_Tag` | text: "전체여행", color: secondaryAmber (#FFC363) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 가디언 없음 | 빈 슬롯만 표시, 중앙에 "가디언을 추가해 여행을 더 안전하게 만드세요" 안내 |
| 가디언 1명 이상 | 연결/대기/거절 상태별 카드 표시 |
| 전체여행 가디언 섹션 | 캡틴이 지정한 가디언 별도 섹션 표시 (크루는 해제 불가, 캡틴만 해제 가능) |
| 해제 확인 | Dialog_Confirm "가디언 연결을 해제하시겠습니까?" (확인/취소) |
| 해제 성공 | 해당 카드 제거 + Toast "가디언 연결이 해제되었습니다" |
| 대기 중 취소 | Dialog_Confirm "연결 요청을 취소하시겠습니까?" → 카드 제거 |
| 거절됨 삭제 | 카드 제거 + 슬롯 복구 |

**인터랙션**

- [탭] 빈 슬롯 (무료) → Navigator.push → F-01 가디언 추가
- [탭] 빈 슬롯 (유료) → Navigator.push → L-01 요금 안내 (결제 후 F-01)
- [탭] 해제 버튼 → Dialog_Confirm → DELETE /api/v1/trips/:tripId/guardians/:linkId
- [탭] 취소 버튼 → Dialog_Confirm → DELETE /api/v1/trips/:tripId/guardians/:linkId
- [탭] 전화 아이콘 → url_launcher → tel: 전화 연결
- [탭] 가디언 카드 (연결됨) → 가디언 상세 정보 Modal_Bottom (이름, 전화, 연결일, 프라이버시 등급 안내)
- [뒤로가기] → 이전 화면 (D-09 또는 K-01)

---

### F-03 가디언 링크 승인 (Guardian Approval)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-03 |
| 화면명 | 가디언 링크 승인 (Guardian Approval) |
| 화면 ID | `guardian-approval` |
| Phase | P0 |
| 역할 | 가디언 |
| 진입 경로 | 푸시 알림 (가디언 연결 요청) → F-03 / 인앱 알림 목록 → F-03 |
| 이탈 경로 | F-03 → F-04 (수락) / F-03 → 알림 목록 (거절) |

**레이아웃**

```
┌─────────────────────────────┐
│ [×]                         │ 닫기 버튼 (우상단)
├─────────────────────────────┤
│                             │
│        SafeTrip 로고         │ Image (48dp), 중앙 정렬
│                             │
│     가디언 연결 요청          │ headlineMedium (24sp, SemiBold)
│                             │ 중앙 정렬
│  ┌─────────────────────────┐│
│  │                         ││ Card_Standard (shadow)
│  │       ┌──────┐          ││
│  │       │  👤  │          ││ CircleAvatar (64dp)
│  │       └──────┘          ││
│  │                         ││
│  │  김민지님이 가디언         ││ titleMedium (18sp, SemiBold)
│  │  연결을 요청합니다         ││ 중앙 정렬
│  │                         ││
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  🇯🇵  도쿄 자유여행        ││ bodyLarge, onSurface
│  │  📅  2026.03.15 ~ 03.22 ││ bodyMedium, onSurfaceVariant
│  │  🛡️  프라이버시: 표준      ││ bodyMedium + Badge (primaryTeal)
│  │                         ││
│  │  💬 "엄마, 여행 중 위치    ││ bodyMedium, onSurfaceVariant
│  │     확인 부탁드려요"       ││ italic, 좌측 정렬
│  │                         ││
│  └─────────────────────────┘│
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │         수락              ││ Button_Primary (teal)
│  └─────────────────────────┘│
│                             │ spacing8
│  ┌─────────────────────────┐│
│  │         거절              ││ Button_Secondary (outlined)
│  └─────────────────────────┘│
│                             │ spacing16
│  수락하면 프라이버시 등급에     │ bodySmall, onSurfaceVariant
│  따라 멤버의 위치를 확인할     │ 중앙 정렬
│  수 있습니다                  │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 닫기 버튼 | `IconButton` | icon: Icons.close, color: onSurfaceVariant, alignment: topRight |
| 로고 | `Image.asset` | width: 48, height: 48, centerAlignment |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), textAlign: center |
| 요청 카드 | `Card` | style: Card_Standard, elevation: 2, radius16, padding: spacing16 |
| 요청자 아바타 | `CircleAvatar` | radius: 32 (64dp), backgroundColor: secondaryBeige |
| 요청자 메시지 | `Text` | style: titleMedium (18sp, SemiBold), textAlign: center |
| 여행 정보 행 | `Row` | leading: emoji, text: bodyLarge/bodyMedium |
| 프라이버시 뱃지 | `Chip_Tag` | text: 등급명, color: 등급별 HEX (§5 참조) |
| 개인 메시지 | `Text` | style: bodyMedium (14sp), fontStyle: italic, color: onSurfaceVariant |
| 수락 버튼 | `ElevatedButton` | style: Button_Primary, text: "수락" |
| 거절 버튼 | `OutlinedButton` | style: Button_Secondary, text: "거절" |
| 안내 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 요청 카드에 멤버 정보 + 여행 정보 표시, 수락/거절 활성 |
| 메시지 없음 | 개인 메시지 영역 숨김 (메시지 미첨부 시) |
| 수락 처리 중 | 수락 버튼 → CircularProgressIndicator, 거절 버튼 비활성 |
| 수락 완료 | Toast "가디언 연결이 완료되었습니다", Navigator.pushReplacement → F-04 가디언 홈 |
| 거절 처리 중 | 거절 버튼 → CircularProgressIndicator, 수락 버튼 비활성 |
| 거절 완료 | Toast "연결 요청을 거절했습니다", Navigator.pop |
| 이미 처리됨 | "이미 처리된 요청입니다" 안내 표시, 버튼 비활성 |
| 만료된 요청 | "만료된 요청입니다" 안내 표시, 버튼 비활성 |

**인터랙션**

- [탭] 수락 → PATCH /api/v1/trips/:tripId/guardians/:linkId/respond { action: 'accepted' }
- [탭] 거절 → PATCH /api/v1/trips/:tripId/guardians/:linkId/respond { action: 'rejected' }
- [탭] 닫기 (×) → Navigator.pop (미처리 상태 유지, 알림 목록에서 재접근 가능)
- [뒤로가기] → Navigator.pop (닫기와 동일)

---

### F-04 가디언 홈 (Guardian Home)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-04 |
| 화면명 | 가디언 홈 (Guardian Home) |
| 화면 ID | `guardian-home` |
| Phase | P0 |
| 역할 | 가디언 |
| 진입 경로 | A-06 프로필 완료 (가디언) → F-04 / F-03 수락 완료 → F-04 / C-01 메인맵 바텀시트 → F-04 |
| 이탈 경로 | F-04 → F-05 (멤버 상세) / F-04 → F-07 (긴급 알림) |
| Stitch | `772d95b3bd67495bb3df3a261436ce20` |

**레이아웃**

```
┌─────────────────────────────┐
│ [여행정보카드]    [알림🔔] [⚙️]│ AppBar_Map (오버레이)
├─────────────────────────────┤
│                             │
│    지도 (연결된 멤버 위치 표시) │ Google Maps
│    멤버 마커 (#15A1A5 테두리)  │ 가디언 색상 마커
│                             │
├─────────────────────────────┤
│  ═══════ handle bar ═══════ │ BottomSheet_Snap
│  [내 담당 멤버] [일정] [안전가이드]│ NavBar_Guardian (3탭)
├─────────────────────────────┤
│                             │
│  내 담당 멤버 (3명)           │ titleMedium, onSurface
│                             │
│  ┌─────────────────────────┐│
│  │ 👤 김민지          ✈️ 크루 ││ Card_Standard
│  │ 📍 도쿄 시부야구         ││ bodySmall, onSurfaceVariant
│  │ 🕐 3분 전 업데이트        ││ bodySmall, onSurfaceVariant
│  │ 🇯🇵 도쿄 자유여행         ││ bodySmall, primaryTeal
│  │                  [⚠️ 긴급]││ TextButton, coral (#FF807B)
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │ 👤 박지수         ✈️ 크루  ││ Card_Standard
│  │ 📍 오사카 난바           ││
│  │ 🕐 15분 전 업데이트       ││
│  │ 🇯🇵 도쿄 자유여행         ││
│  │                  [⚠️ 긴급]││
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │ 👤 이서준      ✈️ 크루    ││ Card_Standard
│  │ 🔒 위치 비공유 중         ││ bodySmall, onSurfaceVariant
│  │ 🕐 --                   ││ 프라이버시 모드
│  │ 🇹🇭 방콕 배낭여행          ││
│  │                  [⚠️ 긴급]││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 상단 오버레이 | `Stack` + `Positioned` | AppBar_Map, 여행정보카드 + 알림/설정 아이콘 |
| 지도 | `GoogleMap` | 연결된 멤버만 마커 표시, 마커 테두리 #15A1A5 |
| 바텀시트 | `DraggableScrollableSheet` | BottomSheet_Snap, 기본 높이: half (35%) |
| 가디언 탭바 | `BottomNavigationBar` | NavBar_Guardian (3탭: 내 담당 멤버/일정/안전가이드) |
| 멤버 카드 | `Card` + `InkWell` | style: Card_Standard, padding: spacing16 |
| 멤버 아바타 | `CircleAvatar` | radius: 20 (40dp), backgroundColor: secondaryBeige |
| 멤버명 | `Text` | style: bodyLarge (16sp), color: onSurface |
| 역할 뱃지 | `Container` (pill) | Badge_Role (크루: #898989) |
| 위치 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, 📍 프리픽스 |
| 업데이트 시간 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, 🕐 프리픽스 |
| 여행명 | `Text` | style: bodySmall (12sp), color: primaryTeal |
| 긴급 알림 버튼 | `TextButton` | text: "⚠️ 긴급", color: primaryCoral (#FF807B) |
| 미읽음 뱃지 | `Container` | 원형 8dp, color: primaryCoral, 메시지 카드 우상단 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 연결 멤버 없음 | 중앙 "아직 연결된 멤버가 없습니다" + 일러스트 표시 |
| 멤버 위치 공유 중 | 마커 표시 (초록 #4CAF50 상태 점), 위치 텍스트 + 업데이트 시간 표시 |
| 멤버 위치 비공유 | 마커 미표시, "🔒 위치 비공유 중" 표시, 업데이트 시간 "--" |
| 멤버 위치 희미 (스케줄 OFF, 표준) | 마커 반투명 (opacity 0.4), "⏸ 스케줄 외 시간" 표시 |
| 미읽음 메시지 있음 | 해당 멤버 카드 우상단에 빨간 원형 뱃지 (숫자) |
| SOS 수신 | 해당 멤버 카드 → Card_Alert (빨간 보더), 카드 상단 "🆘 SOS 발동" 뱃지, 진동 + 사운드 |
| 여행 종료 | 멤버 카드 opacity 0.5, "종료된 여행" 뱃지 표시 |

**인터랙션**

- [탭] 멤버 카드 → Navigator.push → F-05 가디언 멤버 상세
- [탭] 긴급 알림 버튼 (⚠️) → Navigator.push → F-07 긴급 알림 발송 (멤버 정보 전달)
- [탭] 지도 마커 → 해당 멤버 카드로 바텀시트 스크롤 + 카드 하이라이트
- [스와이프] 탭 전환 → 일정 / 안전가이드 탭 내용 표시
- [드래그] 바텀시트 → 5단계 스냅 포인트 전환

---

### F-05 가디언 멤버 상세 (Guardian Member Detail)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-05 |
| 화면명 | 가디언 멤버 상세 (Guardian Member Detail) |
| 화면 ID | `guardian-member-detail` |
| Phase | P0 |
| 역할 | 가디언 |
| 진입 경로 | F-04 가디언 홈 → 멤버 카드 탭 → F-05 |
| 이탈 경로 | F-05 → F-06 (메시지) / F-05 → F-07 (긴급 알림) / F-05 → F-08 (위치 요청) / F-05 → F-04 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 김민지       Badge_Role  │ AppBar_Standard + 역할 뱃지
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │                         ││
│  │    지도 (상단 50%)        ││ Google Maps
│  │                         ││
│  │    👤 ←---- 멤버 마커     ││ #15A1A5 링 + 아바타
│  │    ···· 이동 경로 ····    ││ dotted teal line
│  │         ○ 정확도 원       ││ 반투명 원
│  │                         ││
│  └─────────────────────────┘│
├─────────────────────────────┤
│  ═══════ handle bar ═══════ │
│                             │
│  마지막 업데이트: 3분 전      │ bodySmall, onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │ 📍 위치                   ││ Card_Standard
│  │   도쿄 시부야구 진구마에    ││ bodyLarge, onSurface
│  │                         ││
│  │ 🟢 상태                   ││
│  │   위치 공유 중             ││ Badge (green #4CAF50)
│  │                         ││
│  │ 🛡️ 프라이버시              ││
│  │   📍 표준                 ││ Chip_Tag (primaryTeal)
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │  ⚠️ 긴급 알림 보내기       ││ Button: coral bg (#FF807B)
│  └─────────────────────────┘│ white text, full width
│                             │ spacing8
│  ┌─────────────────────────┐│
│  │  📍 위치 요청              ││ Button_Secondary (outlined teal)
│  └─────────────────────────┘│
│                             │ spacing8
│  ┌─────────────────────────┐│
│  │  💬 메시지 보내기           ││ Button_Secondary (outlined teal)
│  └─────────────────────────┘│
│                             │ spacing8
│  시간당 위치 요청 3회 제한     │ bodySmall, onSurfaceVariant
│  남은 횟수: 2회               │ bodySmall, primaryTeal
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: 멤버명, trailing: Badge_Role, leading: BackButton, style: AppBar_Standard |
| 지도 영역 | `GoogleMap` | height: 화면 50%, 멤버 위치 마커 (#15A1A5 링), 이동 경로 (dotted teal polyline) |
| 멤버 마커 | `Marker` (커스텀) | 아바타 이미지 + #15A1A5 원형 테두리, 정확도 반투명 원 오버레이 |
| 이동 경로 | `Polyline` | color: #15A1A5, opacity: 0.6, dashPattern: [10, 5] |
| 정보 카드 | `Card` | style: Card_Standard, 위치/상태/프라이버시 정보 표시 |
| 업데이트 시간 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 위치 텍스트 | `Text` | style: bodyLarge (16sp), color: onSurface |
| 상태 뱃지 | `Container` (pill) | color: green (#4CAF50), text: "위치 공유 중" (labelSmall, white) |
| 프라이버시 등급 | `Chip_Tag` | text: 등급명, color: 등급별 HEX |
| 긴급 알림 버튼 | `ElevatedButton` | backgroundColor: #FF807B, text: "⚠️ 긴급 알림 보내기", textColor: white |
| 위치 요청 버튼 | `OutlinedButton` | style: Button_Secondary, text: "📍 위치 요청" |
| 메시지 버튼 | `OutlinedButton` | style: Button_Secondary, text: "💬 메시지 보내기" |
| 잔여 횟수 | `Text` | style: bodySmall (12sp), "남은 횟수: N회" (primaryTeal 색상) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 위치 공유 중 | 지도에 마커 + 이동 경로 표시, 상태: 🟢 "위치 공유 중" |
| 위치 비공유 (프라이버시우선, OFF) | 지도 빈 화면 + "위치 정보가 공유되지 않는 시간입니다" 중앙 표시 |
| 위치 희미 (표준, 스케줄 OFF) | 마커 반투명, 상태: "⏸ 30분 간격 스냅샷" |
| 위치 요청 0회 남음 | 위치 요청 버튼 비활성 (opacity 0.4), "다음 요청 가능: 42분 후" |
| SOS 활성 | 카드 보더 sosDanger (#D32F2F), 상태: "🆘 SOS 발동 중", 지도 마커 빨간색 펄스 |
| 여행 종료 | 마지막 위치 스냅샷만 표시, 모든 액션 버튼 비활성, "종료된 여행" 뱃지 |
| 로딩 | 지도 영역 ProgressIndicator, 정보 카드 Skeleton 표시 |

**인터랙션**

- [탭] 긴급 알림 보내기 → Navigator.push → F-07 긴급 알림 발송 (멤버 정보 전달)
- [탭] 위치 요청 → Navigator.push → F-08 가디언 위치 요청 (P1, 미구현 시 Toast "준비 중인 기능입니다")
- [탭] 메시지 보내기 → Navigator.push → F-06 가디언 메시지 (link_id 전달)
- [핀치/줌] 지도 → 지도 확대/축소
- [탭] 지도 마커 → 마커 정보 말풍선 표시 (멤버명 + 시간)
- [뒤로가기] → F-04 가디언 홈

---

### F-06 가디언 메시지 (Guardian Messages)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-06 |
| 화면명 | 가디언 메시지 (Guardian Messages) |
| 화면 ID | `guardian-messages` |
| Phase | P0 |
| 역할 | 가디언 / 크루 |
| 진입 경로 | F-05 멤버 상세 → 메시지 보내기 → F-06 / F-04 가디언 홈 → 메시지 알림 → F-06 |
| 이탈 경로 | F-06 → F-05 (뒤로가기, 가디언) / F-06 → 이전 화면 (뒤로가기, 크루) |
| Stitch | `d6a8f571babd4b1b87816cbe51f05f90` |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 김민지 (가디언 메시지)     │ AppBar_Standard
│                     [👤 정보]│ 상대방 프로필 버튼
├─────────────────────────────┤
│                             │
│      2026년 3월 15일          │ Date separator (bodySmall, center)
│                             │
│  ┌──────────────┐           │
│  │ 안녕하세요,    │           │ 상대방 버블 (좌측 정렬)
│  │ 잘 도착했어?   │           │ surfaceVariant bg (#F9F9F9)
│  └──────────────┘           │ radius12, padding spacing12
│              오전 10:23      │ bodySmall, onSurfaceVariant
│                             │
│           ┌──────────────┐  │
│           │ 네, 무사히     │  │ 내 버블 (우측 정렬)
│           │ 도착했어요!    │  │ #15A1A5 bg (가디언 색상)
│           └──────────────┘  │ white text, radius12
│  오전 10:25                  │ bodySmall, onSurfaceVariant
│                             │
│  ┌──────────────┐           │
│  │ 다행이다.     │           │ 상대방 버블
│  │ 호텔 체크인   │           │
│  │ 했으면 알려줘  │           │
│  └──────────────┘           │
│              오전 10:26      │
│                             │
│           ┌──────────────┐  │
│           │ 네, 곧        │  │ 내 버블
│           │ 체크인해요!    │  │
│           └──────────────┘  │
│  오전 10:30       ✓✓ 읽음    │
│                             │
├─────────────────────────────┤
│  ┌─ Message Input ────┐ [▶]│ Input bar
│  │ 메시지를 입력하세요   │    │ Input_Text + Send button
│  └────────────────────┘    │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: 상대방 이름 + "(가디언 메시지)", trailing: 프로필 IconButton, style: AppBar_Standard |
| 날짜 구분선 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center, 배경 chip |
| 상대방 메시지 버블 | `Container` | backgroundColor: surfaceVariant (#F9F9F9), radius12, padding: spacing12, maxWidth: 75% |
| 내 메시지 버블 | `Container` | backgroundColor: #15A1A5, textColor: white, radius12, padding: spacing12, maxWidth: 75% |
| 메시지 텍스트 | `Text` | style: bodyMedium (14sp) |
| 시간 표시 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 읽음 표시 | `Text` | "✓✓ 읽음", style: bodySmall (12sp), color: primaryTeal |
| 입력 영역 | `Row` | TextField (flex) + IconButton (send) |
| 메시지 입력 | `TextField` | style: Input_Text, hintText: "메시지를 입력하세요", maxLines: 4, autofocus: false |
| 전송 버튼 | `IconButton` | icon: Icons.send, color: primaryTeal (#00A2BD), enabled: 텍스트 입력 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 메시지 없음 (첫 대화) | 중앙 "첫 메시지를 보내보세요" 안내 텍스트 |
| 메시지 로딩 | 메시지 영역 ProgressIndicator (중앙) |
| 메시지 목록 | 시간순 정렬, 날짜 변경 시 날짜 구분선 삽입 |
| 메시지 전송 중 | 내 버블 opacity 0.6 + ProgressIndicator (작은 원형, 버블 하단) |
| 메시지 전송 완료 | 내 버블 opacity 1.0, 시간 표시 |
| 메시지 전송 실패 | 내 버블 + 빨간 "!" 아이콘, 탭 시 재전송 옵션 |
| 상대방 입력 중 | 하단에 "..." 타이핑 인디케이터 (좌측 정렬, 점 3개 애니메이션) |
| 새 메시지 수신 | 자동 스크롤 (하단에 있을 때), 상단에 있으면 "↓ 새 메시지" 배너 |
| 연결 해제 | 입력 필드 비활성, "가디언 연결이 해제되어 메시지를 보낼 수 없습니다" 안내 |

**인터랙션**

- [입력] 텍스트 → 전송 버튼 활성화 (primaryTeal)
- [탭] 전송 (▶) → POST /api/v1/trips/:tripId/guardian-messages/member { link_id, message }
- [탭] 프로필 (👤) → Modal_Bottom 상대방 프로필 (이름, 역할, 연결일)
- [스크롤 상단] → 이전 메시지 페이지네이션 로드 (20개씩)
- [롱프레스] 메시지 버블 → 복사 옵션 팝업
- [뒤로가기] → 이전 화면
- RTDB 채널: `link_{linkId}` 실시간 수신

---

### F-07 가디언 긴급 알림 발송 (Guardian Emergency Alert)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-07 |
| 화면명 | 가디언 긴급 알림 발송 (Guardian Emergency Alert) |
| 화면 ID | `guardian-emergency-alert` |
| Phase | P0 |
| 역할 | 가디언 |
| 진입 경로 | F-04 긴급 버튼 → F-07 / F-05 긴급 알림 보내기 → F-07 |
| 이탈 경로 | F-07 → F-04 (전송 완료) / F-07 → F-05 (취소) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 긴급 알림                │ AppBar_Standard (title: coral)
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │                         ││ Card_Alert (coral border)
│  │     ⚠️                   ││ 큰 경고 아이콘 (48dp, coral)
│  │                         ││
│  │  김민지님에게              ││ titleMedium (18sp, SemiBold)
│  │  긴급 알림을 보냅니다      ││ 중앙 정렬
│  │                         ││
│  │  이 알림은 멤버와 해당     ││ bodySmall (12sp)
│  │  멤버의 캡틴/크루장에게     ││ onSurfaceVariant
│  │  전달됩니다                ││
│  └─────────────────────────┘│
│                             │ spacing24
│  심각도 선택                  │ labelMedium, onSurface
│  ┌────────┐┌────────┐┌─────┐│
│  │  주의   ││  경고   ││ 긴급 ││ SegmentedButton (3단)
│  │  🟡    ││  🟠    ││ 🔴   ││ amber / orange / red
│  └────────┘└────────┘└─────┘│
│                             │ spacing16
│  메시지 (선택)               │ labelMedium, onSurfaceVariant
│  ┌─────────────────────────┐│
│  │ 긴급 상황을 설명해주세요   ││ Input_Text (multiline, 4줄)
│  │                         ││
│  │                         ││
│  │                         ││
│  │                 0/200   ││ 글자수 카운터
│  └─────────────────────────┘│
│                             │ spacing16
│  수신자                      │ labelMedium, onSurface
│  ┌─────────────────────────┐│
│  │ 👤 김민지 (크루)           ││ Card_Standard
│  │ 👤 이캡틴 (캡틴)           ││ 수신자 목록
│  └─────────────────────────┘│
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │   ⚠️ 긴급 알림 보내기      ││ ElevatedButton
│  └─────────────────────────┘│ bg: coral (#FF807B), white text
│                             │ spacing8
│           취소               │ TextButton, onSurfaceVariant
│                             │ spacing8
│  ⚠️ 긴급 상황이 아닌 경우     │ bodySmall, semanticWarning
│    사용을 자제해주세요         │ 중앙 정렬
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "긴급 알림" (color: #FF807B), leading: BackButton, style: AppBar_Standard |
| 경고 카드 | `Card` | style: Card_Alert (coral border #FF807B), padding: spacing16 |
| 경고 아이콘 | `Icon` | Icons.warning_rounded, size: 48, color: #FF807B |
| 대상 멤버명 | `Text` | style: titleMedium (18sp, SemiBold), textAlign: center |
| 전달 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 심각도 선택 | `SegmentedButton` | 3단: 주의 (#FFB800) / 경고 (#FF6B00) / 긴급 (#D32F2F), 기본값: 경고 |
| 메시지 입력 | `TextFormField` | style: Input_Text, maxLines: 4, maxLength: 200, hintText: "긴급 상황을 설명해주세요" |
| 글자수 카운터 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, alignment: bottomRight |
| 수신자 카드 | `Card` | style: Card_Standard, 수신자 목록 (아바타 + 이름 + 역할) |
| 전송 버튼 | `ElevatedButton` | backgroundColor: #FF807B, text: "⚠️ 긴급 알림 보내기", textColor: white |
| 취소 버튼 | `TextButton` | text: "취소", color: onSurfaceVariant |
| 경고 문구 | `Text` | style: bodySmall (12sp), color: semanticWarning (#FFAC11) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 심각도 "경고" 기본 선택, 메시지 비어있음, 전송 버튼 활성 |
| 심각도 변경 | 선택된 심각도에 따라 배경 색상 변경, 전송 버튼 색상도 심각도에 맞춤 |
| 메시지 입력 중 | 글자수 카운터 업데이트, 200자 초과 시 입력 불가 |
| 전송 확인 | Dialog_Confirm "긴급 알림을 보내시겠습니까? 수신자: 김민지, 이캡틴" (확인/취소) |
| 전송 중 | 전송 버튼 → CircularProgressIndicator, 취소 버튼 비활성 |
| 전송 완료 | Toast "긴급 알림이 전송되었습니다", Navigator.pop → F-04 |
| 전송 실패 | SnackBar "알림 전송에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 심각도 버튼 → 주의/경고/긴급 선택 전환
- [탭] 메시지 입력 → 텍스트 키보드 표시
- [탭] 긴급 알림 보내기 → Dialog_Confirm → POST /api/v1/trips/:tripId/guardian-alerts { link_id, severity, message }
- [탭] 취소 → Navigator.pop
- 전송 성공 시 → 멤버 + 캡틴/크루장에게 푸시 알림 트리거
- [뒤로가기] → Dialog_Confirm "작성 중인 내용이 있습니다. 나가시겠습니까?" (메시지 입력 시)

---

### F-08 가디언 위치 요청 (Guardian Location Request)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-08 |
| 화면명 | 가디언 위치 요청 (Guardian Location Request) |
| 화면 ID | `guardian-location-request` |
| Phase | P1 |
| 역할 | 가디언 |
| 진입 경로 | F-05 멤버 상세 → 위치 요청 → F-08 |
| 이탈 경로 | F-08 → F-05 (요청 완료/취소) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 위치 요청                │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │  📍 김민지님의 위치를      ││ Card_Standard
│  │     요청합니다             ││ titleMedium (18sp, SemiBold)
│  │                         ││
│  │  1회성 위치 요청입니다.     ││ bodyMedium (14sp)
│  │  멤버의 현재 위치를        ││ onSurfaceVariant
│  │  한 번 확인할 수 있습니다.  ││
│  └─────────────────────────┘│
│                             │ spacing24
│  요청 제한                   │ labelMedium, onSurface
│  ┌─────────────────────────┐│
│  │  시간당 최대 3회           ││ Card_Standard
│  │                         ││
│  │  ████████░░  2/3 사용     ││ LinearProgressIndicator
│  │                         ││
│  │  남은 횟수: 1회            ││ bodyMedium, primaryTeal
│  │  다음 초기화: 42분 후      ││ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │ spacing24
│  프라이버시 등급별 처리        │ labelMedium, onSurface
│  ┌─────────────────────────┐│
│  │ 🛡️ 안전최우선             ││ Card_Standard (infobox)
│  │   → 자동 승인 (즉시 수신)  ││
│  │                         ││
│  │ 📍 표준                   ││
│  │   → 실시간 위치 전송       ││
│  │                         ││
│  │ 🔒 프라이버시우선           ││
│  │   → 멤버 승인 필요         ││ 강조: primaryCoral
│  │     (자동 만료: 5분)       ││
│  │                         ││
│  │ 현재 등급: 📍 표준         ││ bodyMedium, primaryTeal
│  └─────────────────────────┘│
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │    📍 위치 요청 보내기      ││ Button_Primary
│  └─────────────────────────┘│
│                             │ spacing8
│           취소               │ TextButton, onSurfaceVariant
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "위치 요청", leading: BackButton, style: AppBar_Standard |
| 요청 안내 카드 | `Card` | style: Card_Standard, 📍 아이콘 + 멤버명 + 설명 |
| 제한 카드 | `Card` | style: Card_Standard, LinearProgressIndicator + 횟수/초기화 시간 |
| 프로그레스 바 | `LinearProgressIndicator` | color: primaryTeal, trackColor: outline, value: 사용량/3 |
| 남은 횟수 | `Text` | style: bodyMedium (14sp), color: primaryTeal |
| 초기화 시간 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 등급별 처리 카드 | `Card` | style: Card_Standard, 3개 등급 설명 리스트 |
| 현재 등급 표시 | `Chip_Tag` | 해당 등급 아이콘 + 텍스트, color: 등급별 HEX |
| 요청 버튼 | `ElevatedButton` | style: Button_Primary, text: "📍 위치 요청 보내기" |
| 취소 버튼 | `TextButton` | text: "취소", color: onSurfaceVariant |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 잔여 횟수 표시, 요청 버튼 활성 |
| 요청 0회 남음 | 요청 버튼 비활성 (opacity 0.4), "요청 횟수를 모두 사용했습니다" 안내, 다음 초기화 시간 강조 |
| 요청 전송 중 | 버튼 → CircularProgressIndicator |
| 안전최우선 → 즉시 응답 | Toast "위치를 수신했습니다", Navigator.pop → F-05 (위치 갱신됨) |
| 표준 → 실시간 전송 | Toast "위치를 수신했습니다", Navigator.pop → F-05 (위치 갱신됨) |
| 프라이버시우선 → 승인 대기 | Toast "멤버에게 승인 요청을 보냈습니다 (5분 이내 응답 필요)", Navigator.pop → F-05 (대기 상태) |
| 요청 거절됨 | Toast "멤버가 위치 요청을 거절했습니다" |
| 요청 만료 | Toast "위치 요청이 만료되었습니다 (5분 초과)" |
| 요청 실패 | SnackBar "위치 요청에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 위치 요청 보내기 → POST /api/v1/trips/:tripId/guardian-location-request { link_id }
- [탭] 취소 → Navigator.pop → F-05
- [뒤로가기] → F-05 멤버 상세

---

### F-09 위치 요청 승인 (Location Request Approve)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-09 |
| 화면명 | 위치 요청 승인 (Location Request Approve) |
| 화면 ID | `location-request-approve` |
| Phase | P1 |
| 역할 | 크루 |
| 진입 경로 | 푸시 알림 (위치 요청 수신, 프라이버시우선 등급) → F-09 |
| 이탈 경로 | F-09 → 이전 화면 (승인/거절/만료 후 자동 닫힘) |

**레이아웃**

```
┌─────────────────────────────┐
│                             │
│          (기존 화면 배경)      │ 반투명 스크림 (black 40%)
│                             │
│  ┌─────────────────────────┐│
│  │                         ││ Dialog (radius16, 중앙)
│  │     📍 위치 요청          ││ titleMedium (18sp, SemiBold)
│  │                         ││ 중앙 정렬
│  │  ─────────────────────  ││ Divider
│  │                         ││
│  │  👤 김보호자 (가디언)     ││ 요청자 정보
│  │     님이 회원님의          ││ bodyMedium, onSurface
│  │     현재 위치를            ││
│  │     요청합니다             ││
│  │                         ││
│  │  1회성 위치 공유입니다.     ││ bodySmall, onSurfaceVariant
│  │  승인 후 현재 위치만       ││
│  │  한 번 전송됩니다.         ││
│  │                         ││
│  │  ⏱️ 자동 만료: 4:32       ││ bodyMedium, primaryCoral
│  │                         ││ 카운트다운 타이머
│  │  ┌───────────────────┐  ││
│  │  │      승인           │  ││ Button_Primary
│  │  └───────────────────┘  ││
│  │                         ││ spacing8
│  │  ┌───────────────────┐  ││
│  │  │      거절           │  ││ Button_Secondary
│  │  └───────────────────┘  ││
│  │                         ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 스크림 (배경) | `GestureDetector` + `Container` | color: black 40% opacity, 탭 시 닫기 방지 |
| 다이얼로그 | `Dialog` | radius16, backgroundColor: surface (#FFFFFF), padding: spacing24, width: 320dp |
| 제목 | `Text` | style: titleMedium (18sp, SemiBold), textAlign: center, 📍 프리픽스 |
| 요청자 정보 | `Row` | CircleAvatar (40dp) + 이름 + Badge_Role (가디언 #15A1A5) |
| 설명 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurface |
| 1회성 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 만료 타이머 | `Text` | style: bodyMedium (14sp), color: primaryCoral (#FF807B), ⏱️ 프리픽스, 5분 카운트다운 |
| 승인 버튼 | `ElevatedButton` | style: Button_Primary, text: "승인" |
| 거절 버튼 | `OutlinedButton` | style: Button_Secondary, text: "거절" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 타이머 5:00 시작, 승인/거절 활성 |
| 타이머 1분 미만 | 타이머 텍스트 sosDanger (#D32F2F), 깜빡임 효과 |
| 타이머 만료 (0:00) | 자동 거절 처리, "요청이 만료되었습니다" 안내 후 2초 뒤 자동 닫힘 |
| 승인 처리 중 | 승인 버튼 → CircularProgressIndicator, 거절 비활성 |
| 승인 완료 | Toast "위치가 전송되었습니다", 다이얼로그 자동 닫힘 |
| 거절 처리 중 | 거절 버튼 → CircularProgressIndicator, 승인 비활성 |
| 거절 완료 | Toast "위치 요청을 거절했습니다", 다이얼로그 자동 닫힘 |
| 이미 처리됨 | "이미 처리된 요청입니다" 안내, 버튼 비활성, 2초 후 자동 닫힘 |

**인터랙션**

- [탭] 승인 → PATCH /api/v1/trips/:tripId/guardian-location-request/:requestId/respond { action: 'approved' }
- [탭] 거절 → PATCH /api/v1/trips/:tripId/guardian-location-request/:requestId/respond { action: 'rejected' }
- 스크림 탭 시 닫히지 않음 (중요한 의사결정 화면)
- 뒤로가기 → 닫히지 않음 (반드시 승인 또는 거절 선택 필요, 무시 시 자동 만료)

---

### F-10 전체여행 가디언 관리 (Whole Trip Guardian)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | F-10 |
| 화면명 | 전체여행 가디언 관리 (Whole Trip Guardian) |
| 화면 ID | `whole-trip-guardian` |
| Phase | P1 |
| 역할 | 캡틴 전용 |
| 진입 경로 | D-09 멤버 관리 → 전체여행 가디언 → F-10 / K-01 설정 → 전체여행 가디언 → F-10 |
| 이탈 경로 | F-10 → F-01 (추가) / F-10 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 전체여행 가디언 관리       │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │ ℹ️ 전체여행 가디언이란?    ││ Card_Standard (beige bg)
│  │                         ││
│  │ 캡틴이 지정하는 가디언으로  ││ bodyMedium, onSurfaceVariant
│  │ 여행의 모든 멤버에게       ││
│  │ 자동으로 연결됩니다.       ││
│  │                         ││
│  │ • 무료 2명까지 지정 가능   ││ bodySmall, bullet list
│  │ • 신규 멤버 가입 시 자동   ││
│  │   연결                   ││
│  │ • 캡틴만 추가/해제 가능    ││
│  └─────────────────────────┘│
│                             │ spacing24
│  전체여행 가디언 (1/2명)      │ titleMedium (18sp, SemiBold)
│                             │
│  ┌─────────────────────────┐│
│  │ 👤 박부모                 ││ ListTile: avatar + name
│  │ 📞 010-****-5678         ││ bodySmall, masked phone
│  │ 🟢 연결됨                 ││ Badge (green)
│  │ 연결 멤버: 5명 전원        ││ bodySmall, primaryTeal
│  │                  [해제]   ││ TextButton (red)
│  ├─────────────────────────┤│
│  │ ┌ - - - - - - - - - ┐   ││ Dashed border (빈 슬롯)
│  │ │  + 전체여행 가디언   │   ││ TextButton, primaryTeal
│  │ │     추가하기        │   ││
│  │ └ - - - - - - - - - ┘   ││
│  └─────────────────────────┘│
│                             │ spacing24
│  적용 현황                   │ titleMedium (18sp, SemiBold)
│  ┌─────────────────────────┐│
│  │ 전체 멤버: 5명            ││ Card_Standard
│  │ 연결 완료: 5명 ✅          ││ bodyMedium, green
│  │ 대기 중: 0명              ││ bodyMedium, amber
│  │                         ││
│  │ 새 멤버 가입 시 자동으로   ││ bodySmall, onSurfaceVariant
│  │ 연결됩니다                ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "전체여행 가디언 관리", leading: BackButton, style: AppBar_Standard |
| 안내 카드 | `Card` | style: Card_Standard, backgroundColor: secondaryBeige (#F2EDE4), ℹ️ 아이콘 + 설명 |
| 섹션 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 가디언 카드 (연결됨) | `ListTile` | leading: CircleAvatar (40dp), title: name, subtitle: phone (masked) + 연결 멤버 수 |
| 상태 뱃지 | `Container` (pill) | color: green (#4CAF50), text: "연결됨" (labelSmall, white) |
| 연결 멤버 수 | `Text` | style: bodySmall (12sp), color: primaryTeal |
| 해제 버튼 | `TextButton` | text: "해제", color: semanticError (#DA4C51) |
| 빈 슬롯 | `Container` | dashed border, radius8, "+" 아이콘 + "전체여행 가디언 추가하기" 텍스트 |
| 적용 현황 카드 | `Card` | style: Card_Standard, 전체/연결/대기 멤버 수 + 자동 연결 안내 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 가디언 0명 | 빈 슬롯 2개 표시, 적용 현황 카드 "전체여행 가디언이 없습니다" |
| 가디언 1명 | 1개 카드 + 1개 빈 슬롯, 적용 현황 업데이트 |
| 가디언 2명 (최대) | 2개 카드, 빈 슬롯 없음, "최대 2명까지 지정 가능합니다" 안내 |
| 해제 확인 | Dialog_Confirm "전체여행 가디언을 해제하시겠습니까? 모든 멤버와의 연결이 해제됩니다." |
| 해제 성공 | 카드 제거 → 빈 슬롯 표시, 적용 현황 업데이트, Toast "전체여행 가디언이 해제되었습니다" |
| 추가 중 | Navigator.push → F-01 (전체여행 가디언 모드 파라미터 전달) |
| 캡틴 아닌 경우 | 이 화면 진입 불가 (권한 체크 → Toast "캡틴만 관리할 수 있습니다", Navigator.pop) |
| 여행 종료 | 모든 버튼 비활성, "종료된 여행의 가디언은 변경할 수 없습니다" 안내 |

**인터랙션**

- [탭] 빈 슬롯 → Navigator.push → F-01 가디언 추가 (isWholeTripGuardian: true)
- [탭] 해제 → Dialog_Confirm → DELETE /api/v1/trips/:tripId/whole-trip-guardians/:linkId
- [탭] 가디언 카드 → Modal_Bottom (가디언 상세: 이름, 전화, 연결일, 연결 멤버 목록)
- [뒤로가기] → 이전 화면

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 10개 화면 (F-01 ~ F-10) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 화면 목업 구현: `docs/plans/2026-03-03-screen-mockup-implementation.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
