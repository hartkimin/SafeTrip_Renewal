# K. 설정 & 프로필

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 설정 및 프로필 관리 8개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 설정 메뉴 원칙 | `Master_docs/15_T3_설정_메뉴_원칙.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 8개 (K-01 ~ K-08)
- **Phase:** P0 4개 (K-01, K-02, K-03, K-05), P1 4개 (K-04, K-06, K-07, K-08)
- **핵심 역할:** 전체 (캡틴/크루장/크루/가디언)
- **연관 문서:** `Master_docs/15_T3_설정_메뉴_원칙.md`

---

## User Journey Flow

```
[지도 상단바 ⚙️] ──→ K-01 설정 메인
                      ├── [프로필 카드 탭] ──→ K-02 프로필 편집
                      ├── [위치 설정] ──→ K-03 위치 설정
                      ├── [알림 설정] ──→ K-04 알림 설정 (P1)
                      ├── [앱 정보] ──→ K-05 앱 정보
                      │                  └── [약관 링크] ──→ WebView
                      ├── [약관 재동의] ──→ K-06 약관 재동의 (P1, 업데이트 시)
                      └── [계정 관리]
                           ├── [로그아웃] ──→ Dialog_Confirm ──→ A-01
                           ├── [계정 삭제] ──→ K-07 계정 삭제 (P1)
                           │                  └── [삭제 요청 완료] ──→ A-01
                           └── [삭제 철회] ──→ K-08 삭제 철회 (P1, 유예 기간 중)
                                              └── [철회 완료] ──→ K-01
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| C-01 메인맵 상단 ⚙️ | 탭 | K-01 설정 메인 | K |
| K-01 | 로그아웃 확인 | A-01 스플래시 | A |
| K-07 | 계정 삭제 완료 | A-01 스플래시 | A |
| K-08 | 삭제 철회 완료 | K-01 설정 메인 | K |
| A-01 | 삭제 유예 기간 중 로그인 | K-08 삭제 철회 (배너) | K |
| K-06 | 필수 약관 거절 | 서비스 차단 → A-01 | A |

---

## 화면 상세

---

### K-01 설정 메인 (Settings Main)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | K-01 |
| 화면명 | 설정 메인 (Settings Main) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | C-01 메인맵 상단바 ⚙️ 아이콘 → K-01 |
| 이탈 경로 | K-01 → K-02 (프로필) / K-03 (위치) / K-04 (알림) / K-05 (앱 정보) / K-06 (약관) / K-07 (삭제) / A-01 (로그아웃) |

**레이아웃**

```
┌─────────────────────────────────┐
│ [←] 설정                         │ AppBar_Standard
├─────────────────────────────────┤
│                                 │
│  ┌─────────────────────────────┐│
│  │ ┌────┐                      ││
│  │ │ 👤 │ 홍길동                ││ 프로필 카드 (Card_Standard)
│  │ │    │ +82 10-1234-5678     ││ 아바타 56dp + 이름 + 전화번호
│  │ └────┘              [→]    ││ trailing: chevron_right
│  └─────────────────────────────┘│
│                                 │ spacing24
│  ── 위치 설정 ───────────────── │ 섹션 헤더 (labelMedium, onSurfaceVariant)
│  ┌─────────────────────────────┐│
│  │ 📍 위치 공유 설정        [→] ││ ListTile (height: 56dp)
│  ├─────────────────────────────┤│
│  │ 🔋 배터리 최적화 안내    [→] ││ ListTile
│  └─────────────────────────────┘│
│                                 │ spacing8 + Divider (8dp height, surfaceContainerLow)
│  ── 알림 설정 ───────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 🔔 알림 설정             [→] ││ ListTile
│  └─────────────────────────────┘│
│                                 │ spacing8 + Divider (8dp)
│  ── 앱 정보 ────────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ ℹ️  앱 정보               [→] ││ ListTile
│  ├─────────────────────────────┤│
│  │ 📄 약관 및 정책           [→] ││ ListTile
│  └─────────────────────────────┘│
│                                 │ spacing8 + Divider (8dp)
│  ── 계정 관리 ───────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 🔓 로그아웃               [→] ││ ListTile
│  ├─────────────────────────────┤│
│  │ ⚠️ 계정 삭제              [→] ││ ListTile (semanticError 텍스트)
│  └─────────────────────────────┘│
│                                 │
│  앱 버전 v1.0.0                  │ bodySmall, onSurfaceVariant, 중앙 정렬
│                                 │
└─────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "설정", leading: BackButton, style: AppBar_Standard |
| 프로필 카드 | `Card` + `InkWell` | style: Card_Standard, radius16, 내부 패딩 16px |
| 아바타 | `CircleAvatar` | radius: 28 (56dp), backgroundImage: 프로필 사진 또는 기본 아이콘 |
| 프로필 이름 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 전화번호 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 섹션 헤더 | `Text` | style: labelMedium (14sp, Medium 500), color: onSurfaceVariant, 좌측 패딩 20px |
| 섹션 구분선 | `Container` | height: 8dp, color: surfaceContainerLow (#F2F2F7) |
| 메뉴 아이템 | `ListTile` | height: 56dp, leading: Icon (24dp), title: bodyLarge (16sp), trailing: Icon(chevron_right, onSurfaceVariant) |
| 삭제 메뉴 | `ListTile` | title color: semanticError (#DA4C51), icon color: semanticError |
| 버전 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 기본 | 프로필 카드에 사용자 이름/전화번호/아바타 표시, 전체 메뉴 리스트 |
| 프로필 사진 없음 | CircleAvatar에 기본 아이콘 (👤), secondaryBeige 배경 |
| 계정 삭제 유예 중 | 상단에 경고 배너: "계정 삭제 요청 중 — N일 후 삭제됩니다 [철회하기]", semanticWarning 배경 |
| 약관 업데이트 대기 | "약관 및 정책" 항목 우측에 Badge (빨간 점) 표시 |
| 위치 권한 미허용 | "위치 공유 설정" 항목에 ⚠️ 경고 아이콘 추가 |
| 오프라인 | 프로필 편집, 로그아웃, 계정 삭제 비활성화, Toast "인터넷 연결이 필요합니다" |

**인터랙션**

- [탭] 프로필 카드 → Navigator.push → K-02 프로필 편집
- [탭] 위치 공유 설정 → Navigator.push → K-03 위치 설정
- [탭] 배터리 최적화 안내 → K-03 위치 설정 (배터리 섹션으로 스크롤)
- [탭] 알림 설정 → Navigator.push → K-04 알림 설정
- [탭] 앱 정보 → Navigator.push → K-05 앱 정보
- [탭] 약관 및 정책 → Navigator.push → K-06 약관 재동의
- [탭] 로그아웃 → Dialog_Confirm "로그아웃하시겠습니까?" → 확인 시 토큰 삭제 → A-01
- [탭] 계정 삭제 → Navigator.push → K-07 계정 삭제
- [탭] 삭제 유예 배너 [철회하기] → Navigator.push → K-08 삭제 철회
- [뒤로가기] → C-01 메인맵

---

### K-02 프로필 편집 (User Profile)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | K-02 |
| 화면명 | 프로필 편집 (User Profile) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | K-01 설정 메인 → 프로필 카드 탭 → K-02 |
| 이탈 경로 | K-02 → K-01 (저장 완료/취소) |

**레이아웃**

```
┌─────────────────────────────────┐
│ [←] 프로필 편집                    │ AppBar_Standard
├─────────────────────────────────┤
│                                 │
│        ┌──────────┐             │
│        │          │             │
│        │  👤  📷  │             │ CircleAvatar + 카메라 오버레이
│        │          │             │ 96 x 96, radius48
│        └──────────┘             │
│       프로필 사진 변경             │ bodySmall, primaryTeal
│                                 │ spacing24
│  이름                            │ labelMedium, onSurfaceVariant
│  ┌─────────────────────────────┐│
│  │ 홍길동                       ││ Input_Text
│  └─────────────────────────────┘│
│                                 │ spacing16
│  전화번호                        │ labelMedium, onSurfaceVariant
│  ┌─────────────────────────────┐│
│  │ +82 10-1234-5678    🔒      ││ Input_Text (read-only)
│  └─────────────────────────────┘│ 배경: surfaceVariant (#F9F9F9)
│  전화번호는 변경할 수 없습니다     │ bodySmall, onSurfaceVariant
│                                 │ spacing16
│  비상 연락처                      │ labelMedium, onSurfaceVariant
│  ┌─────────────────────────────┐│
│  │ 010-9876-5432                ││ Input_Text (phone)
│  └─────────────────────────────┘│
│  SOS 발동 시 함께 전달됩니다      │ bodySmall, onSurfaceVariant
│                                 │
│                                 │
│  ┌─────────────────────────────┐│
│  │         저장                  ││ Button_Primary
│  └─────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "프로필 편집", leading: BackButton, style: AppBar_Standard |
| 아바타 영역 | `GestureDetector` + `CircleAvatar` | radius: 48 (96dp), backgroundColor: secondaryBeige (#F2EDE4) |
| 카메라 오버레이 | `Positioned` + `Container` | 우하단, 28dp 원형, primaryTeal 배경, Icons.camera_alt (white, 16dp) |
| 사진 변경 텍스트 | `Text` | style: bodySmall (12sp), color: primaryTeal |
| 필드 라벨 | `Text` | style: labelMedium (14sp, Medium 500), color: onSurfaceVariant |
| 이름 입력 | `TextFormField` | style: Input_Text, validator: 필수 (2~20자), maxLength: 20 |
| 전화번호 필드 | `TextFormField` | style: Input_Text, enabled: false, filled: true, fillColor: surfaceVariant (#F9F9F9), suffixIcon: Icons.lock (onSurfaceVariant) |
| 전화번호 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 비상연락처 입력 | `TextFormField` | style: Input_Text, keyboardType: TextInputType.phone, hintText: "비상 시 연락할 번호" |
| 비상연락처 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 저장 버튼 | `ElevatedButton` | style: Button_Primary, text: "저장", enabled: 이름 유효 + 변경사항 있을 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 기존 프로필 데이터 로드하여 각 필드에 표시, 저장 버튼 비활성 (변경사항 없음) |
| 이름 수정됨 | 저장 버튼 활성 (primaryTeal) |
| 이름 비어있음 | 이름 필드 보더 semanticError, 에러 텍스트 "이름을 입력해주세요", 저장 버튼 비활성 |
| 이름 1자 | 에러 텍스트 "이름은 2자 이상 입력해주세요" |
| 사진 선택 중 | Modal_Bottom (촬영하기 / 앨범에서 선택 / 기본 이미지로 변경) |
| 사진 선택 완료 | CircleAvatar에 선택한 이미지 표시, 저장 버튼 활성 |
| 비상연락처 형식 오류 | 보더 semanticError, 에러 텍스트 "유효한 전화번호를 입력해주세요" |
| 저장 중 | 저장 버튼 → CircularProgressIndicator (white, 24dp) |
| 저장 성공 | Toast "프로필이 저장되었습니다", Navigator.pop → K-01 |
| 저장 실패 | Toast "프로필 저장에 실패했습니다. 다시 시도해주세요." |
| 오프라인 | 로컬 임시 저장 → 복구 시 서버 동기화, Toast "오프라인 상태입니다. 연결 시 저장됩니다" |

**인터랙션**

- [탭] 아바타 영역 / 사진 변경 텍스트 → Modal_Bottom (촬영하기 / 앨범에서 선택 / 기본 이미지로 변경)
- [탭] 이름 필드 → 키보드 표시
- [탭] 비상연락처 필드 → 숫자 키패드 표시
- [탭] 전화번호 필드 → 반응 없음 (disabled), 필드 탭 시 Toast "전화번호는 변경할 수 없습니다"
- [탭] 저장 → PUT /api/v1/users/profile → 성공 시 K-01로 복귀
- [뒤로가기] → 변경사항 있을 시 Dialog_Confirm "변경사항을 저장하지 않고 나가시겠습니까?" → 확인 시 K-01, 취소 시 유지

---

### K-03 위치 설정 (Location Settings)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | K-03 |
| 화면명 | 위치 설정 (Location Settings) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | K-01 설정 메인 → 위치 공유 설정 → K-03 |
| 이탈 경로 | K-03 → K-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────┐
│ [←] 위치 설정                     │ AppBar_Standard
├─────────────────────────────────┤
│                                 │
│  ── 위치 공유 ──────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 위치 공유                    ││
│  │ 여행 중 내 위치를 그룹       ││ bodySmall, onSurfaceVariant
│  │ 멤버에게 공유합니다     [🔘] ││ CupertinoSwitch (primaryTeal)
│  └─────────────────────────────┘│
│                                 │ spacing8
│  ┌─────────────────────────────┐│
│  │ 백그라운드 위치 추적          ││
│  │ 앱을 닫아도 위치를            ││ bodySmall, onSurfaceVariant
│  │ 계속 공유합니다          [🔘] ││ CupertinoSwitch (primaryTeal)
│  └─────────────────────────────┘│
│                                 │ spacing24
│  ── 위치 권한 ──────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 현재 상태                    ││ Card_Standard
│  │ ✅ "항상 허용" 설정됨        ││ semanticSuccess 텍스트
│  │              또는            ││
│  │ ⚠️ "앱 사용 중만" 설정됨     ││ semanticWarning 텍스트
│  │              또는            ││
│  │ ❌ 위치 권한 거부됨          ││ semanticError 텍스트
│  │                      [설정] ││ TextButton → 시스템 설정
│  └─────────────────────────────┘│
│                                 │ spacing16
│  ┌─────────────────────────────┐│
│  │ 💡 "항상 허용" 권장           ││ Card_Standard (primaryTeal 좌측 보더 4px)
│  │                             ││
│  │ SafeTrip의 모든 안전 기능을  ││ bodyMedium, onSurface
│  │ 사용하려면 위치 권한을        ││
│  │ "항상 허용"으로 설정해        ││
│  │ 주세요.                     ││
│  │                             ││
│  │ • SOS 발동 시 정확한 위치 전송││ bodySmall, onSurfaceVariant
│  │ • 지오펜스 이탈 알림          ││
│  │ • 백그라운드 위치 공유        ││
│  └─────────────────────────────┘│
│                                 │ spacing24
│  ── 배터리 최적화 ───────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 📱 배터리 최적화 해제 안내    ││ Card_Standard
│  │                             ││
│  │ [Android]                   ││ Chip_Tag (선택 상태: OS 감지)
│  │ 설정 → 앱 → SafeTrip →      ││ bodyMedium
│  │ 배터리 → "제한 없음" 선택    ││
│  │                             ││
│  │ [iOS]                       ││ Chip_Tag
│  │ 설정 → SafeTrip →            ││ bodyMedium
│  │ 위치 → "항상" 선택           ││
│  │                             ││
│  │         [시스템 설정 열기]    ││ Button_Secondary (소형)
│  └─────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "위치 설정", leading: BackButton, style: AppBar_Standard |
| 섹션 헤더 | `Text` | style: labelMedium (14sp, Medium 500), color: onSurfaceVariant |
| 위치 공유 토글 | `CupertinoSwitch` | activeColor: primaryTeal (#00A2BD), value: locationSharingEnabled |
| 백그라운드 추적 토글 | `CupertinoSwitch` | activeColor: primaryTeal, value: backgroundTrackingEnabled |
| 토글 설명 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 권한 상태 카드 | `Card` | style: Card_Standard, 상태별 아이콘/색상 변경 |
| 권한 상태 텍스트 | `Text` | style: bodyLarge (16sp), color: 상태별 (success/warning/error) |
| 설정 버튼 | `TextButton` | style: labelMedium, color: primaryTeal, onPressed: openAppSettings() |
| 추천 카드 | `Card` | style: Card_Standard, 좌측 보더 4px primaryTeal |
| 추천 항목 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, bullet list |
| OS 탭 | `Chip` | style: Chip_Tag, 기기 OS 자동 감지하여 해당 탭 활성 |
| 시스템 설정 버튼 | `OutlinedButton` | style: Button_Secondary (작은 사이즈), text: "시스템 설정 열기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 권한: 항상 허용 | 상태 카드 ✅ "항상 허용 설정됨" (semanticSuccess), 추천 카드 숨김 |
| 권한: 앱 사용 중만 | 상태 카드 ⚠️ "앱 사용 중만 설정됨" (semanticWarning), 추천 카드 표시 |
| 권한: 거부 | 상태 카드 ❌ "위치 권한 거부됨" (semanticError), 토글 2개 비활성, 추천 카드 표시 |
| 위치 공유 OFF | 백그라운드 추적 토글 비활성 (gray), "위치 공유를 먼저 켜주세요" 안내 |
| Android 기기 | 배터리 최적화 안내에서 Android 탭 자동 선택 |
| iOS 기기 | 배터리 최적화 안내에서 iOS 탭 자동 선택 |
| 토글 변경 | 즉시 반영 (별도 저장 버튼 없음), Toast "설정이 변경되었습니다" |
| 오프라인 | 토글 변경 로컬 저장, 복구 시 서버 동기화 |

**인터랙션**

- [토글] 위치 공유 → PATCH /api/v1/users/settings (location_sharing) → 즉시 반영
- [토글] 백그라운드 위치 추적 → 위치 공유 ON 시에만 토글 가능, PATCH /api/v1/users/settings
- [탭] [설정] 버튼 → `openAppSettings()` 시스템 앱 설정 화면 이동
- [탭] [시스템 설정 열기] → `openAppSettings()` 시스템 앱 설정 화면 이동
- [뒤로가기] → K-01 설정 메인

---

### K-04 알림 설정 (Notification Settings)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | K-04 |
| 화면명 | 알림 설정 (Notification Settings) |
| Phase | P1 |
| 역할 | 전체 |
| 진입 경로 | K-01 설정 메인 → 알림 설정 → K-04 |
| 이탈 경로 | K-04 → K-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────┐
│ [←] 알림 설정                     │ AppBar_Standard
├─────────────────────────────────┤
│                                 │
│  알림 유형별로 수신 여부를        │ bodyMedium, onSurfaceVariant
│  설정할 수 있습니다              │
│                                 │ spacing24
│  ── 안전 알림 ──────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 🚨 SOS 긴급 알림             ││
│  │ 항상 수신 (해제 불가)    [🔘] ││ CupertinoSwitch (ON, disabled)
│  ├─────────────────────────────┤│ Divider (outlineVariant)
│  │ ✅ 출석 체크 알림             ││
│  │ 출석 체크 요청 및 결과   [🔘] ││ CupertinoSwitch
│  ├─────────────────────────────┤│
│  │ 📍 지오펜스 알림              ││
│  │ 안전 영역 이탈/진입      [🔘] ││ CupertinoSwitch
│  └─────────────────────────────┘│
│                                 │ spacing8 + Divider (8dp)
│  ── 소통 알림 ──────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 🛡️ 가디언 알림               ││
│  │ 가디언 연결/메시지       [🔘] ││ CupertinoSwitch
│  ├─────────────────────────────┤│
│  │ 💬 채팅 알림                  ││
│  │ 그룹 채팅 메시지         [🔘] ││ CupertinoSwitch
│  └─────────────────────────────┘│
│                                 │ spacing8 + Divider (8dp)
│  ── 시스템 알림 ─────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 🔔 시스템 공지                ││
│  │ 앱 업데이트, 공지사항    [🔘] ││ CupertinoSwitch
│  ├─────────────────────────────┤│
│  │ 📢 마케팅 알림                ││
│  │ 이벤트, 프로모션         [🔘] ││ CupertinoSwitch
│  └─────────────────────────────┘│
│                                 │
│  알림 권한이 꺼져 있으면 알림을   │ bodySmall, onSurfaceVariant
│  받을 수 없습니다.               │ spacing4
│  시스템 설정에서 알림을 허용해    │
│  주세요.        [알림 설정 열기]  │ TextButton, primaryTeal
│                                 │
└─────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "알림 설정", leading: BackButton, style: AppBar_Standard |
| 안내 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 섹션 헤더 | `Text` | style: labelMedium (14sp, Medium 500), color: onSurfaceVariant |
| 알림 아이템 | `ListTile` | height: 72dp, leading: Icon (24dp), title: bodyLarge (16sp), subtitle: bodySmall (12sp, onSurfaceVariant) |
| SOS 스위치 | `CupertinoSwitch` | value: true, onChanged: null (disabled), activeColor: sosDanger (#D32F2F) |
| 일반 스위치 | `CupertinoSwitch` | activeColor: primaryTeal (#00A2BD), value: 카테고리별 설정값 |
| 구분선 (항목 간) | `Divider` | color: outlineVariant (#F5F5F5), indent: 56 (아이콘 영역 제외) |
| 섹션 구분선 | `Container` | height: 8dp, color: surfaceContainerLow (#F2F2F7) |
| 알림 설정 링크 | `TextButton` | style: labelMedium, color: primaryTeal, text: "알림 설정 열기" |
| 하단 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 기본 | 각 카테고리별 저장된 ON/OFF 상태 반영, SOS 항상 ON (disabled) |
| SOS 알림 | 항상 ON, 스위치 disabled (터치 불가), 스위치 색상 sosDanger (#D32F2F) |
| 알림 권한 미허용 | 상단에 경고 배너 "알림 권한이 꺼져 있습니다" (semanticWarning 배경), 모든 스위치 gray 표시 |
| 토글 변경 | 즉시 반영, 서버 동기화 (PATCH), Toast "알림 설정이 변경되었습니다" |
| 가디언 역할 | 채팅 알림 항목 숨김 (가디언은 채팅 미참여) |
| 마케팅 알림 OFF→ON | Dialog_Confirm "마케팅 정보 수신에 동의하시겠습니까?" → 확인 시 ON |

**인터랙션**

- [토글] SOS 긴급 알림 → 반응 없음 (disabled), 탭 시 Toast "SOS 알림은 안전을 위해 해제할 수 없습니다"
- [토글] 각 카테고리 → PATCH /api/v1/users/notification-settings → 즉시 반영
- [탭] 알림 설정 열기 → 시스템 알림 설정 화면 이동
- [뒤로가기] → K-01 설정 메인

---

### K-05 앱 정보 (App Info)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | K-05 |
| 화면명 | 앱 정보 (App Info) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | K-01 설정 메인 → 앱 정보 → K-05 |
| 이탈 경로 | K-05 → K-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────┐
│ [←] 앱 정보                      │ AppBar_Standard
├─────────────────────────────────┤
│                                 │
│        ┌───────────┐            │
│        │           │            │
│        │  SafeTrip  │            │ Image (app logo)
│        │   Logo    │            │ 80 x 80
│        │           │            │
│        └───────────┘            │
│         SafeTrip                │ titleLarge, primaryTeal, 중앙
│       버전 1.0.0 (100)          │ bodyMedium, onSurfaceVariant, 중앙
│                                 │ spacing32
│  ┌─────────────────────────────┐│
│  │ 📄 서비스 이용약관       [↗] ││ ListTile + external_link 아이콘
│  ├─────────────────────────────┤│ Divider (outlineVariant)
│  │ 🔒 개인정보 처리방침     [↗] ││ ListTile + external_link 아이콘
│  ├─────────────────────────────┤│
│  │ 📍 위치기반서비스 이용약관 [↗]││ ListTile + external_link 아이콘
│  ├─────────────────────────────┤│
│  │ 📜 오픈소스 라이선스     [→] ││ ListTile + chevron_right
│  └─────────────────────────────┘│
│                                 │ spacing24
│  ┌─────────────────────────────┐│
│  │ 💬 문의하기              [↗] ││ ListTile + external_link 아이콘
│  ├─────────────────────────────┤│
│  │ ⭐ 앱 평가하기           [↗] ││ ListTile + external_link 아이콘
│  └─────────────────────────────┘│
│                                 │
│                                 │
│  Copyright 2026 SafeTrip.       │ bodySmall, onSurfaceVariant, 중앙
│  All rights reserved.           │
│                                 │
└─────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "앱 정보", leading: BackButton, style: AppBar_Standard |
| 앱 로고 | `Image.asset` | width: 80, height: 80, 중앙 정렬 |
| 앱 이름 | `Text` | style: titleLarge (20sp, SemiBold 600), color: primaryTeal, textAlign: center |
| 버전 정보 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, textAlign: center |
| 약관 링크 아이템 | `ListTile` | height: 56dp, leading: Icon (24dp), title: bodyLarge (16sp), trailing: Icon(open_in_new, onSurfaceVariant) |
| 라이선스 아이템 | `ListTile` | height: 56dp, leading: Icon (24dp), title: bodyLarge (16sp), trailing: Icon(chevron_right, onSurfaceVariant) |
| 문의/평가 아이템 | `ListTile` | height: 56dp, leading: Icon (24dp), title: bodyLarge (16sp), trailing: Icon(open_in_new, onSurfaceVariant) |
| 구분선 | `Divider` | color: outlineVariant (#F5F5F5), indent: 56 |
| 저작권 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 기본 | 앱 로고, 버전 정보, 메뉴 리스트 표시 |
| 앱 업데이트 가능 | 버전 정보 하단에 "새 버전이 있습니다 (v1.1.0)" 텍스트 + "업데이트" TextButton (primaryTeal) |
| WebView 로드 실패 | Toast "페이지를 불러올 수 없습니다. 인터넷 연결을 확인해주세요." |

**인터랙션**

- [탭] 서비스 이용약관 → WebView (약관 전문 URL)
- [탭] 개인정보 처리방침 → WebView (개인정보 처리방침 URL)
- [탭] 위치기반서비스 이용약관 → WebView (위치 약관 URL)
- [탭] 오픈소스 라이선스 → Navigator.push → `LicensePage` (Flutter 기본 라이선스 페이지)
- [탭] 문의하기 → 외부 이메일 앱 (mailto: support@safetrip.com)
- [탭] 앱 평가하기 → 스토어 리뷰 페이지 (App Store / Google Play)
- [뒤로가기] → K-01 설정 메인

---

### K-06 약관 재동의 (Terms Re-consent)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | K-06 |
| 화면명 | 약관 재동의 (Terms Re-consent) |
| Phase | P1 |
| 역할 | 전체 |
| 진입 경로 | K-01 설정 메인 → 약관 및 정책 → K-06 / 앱 실행 시 약관 업데이트 감지 → K-06 (강제 진입) |
| 이탈 경로 | K-06 → K-01 (동의 완료) / K-06 → 서비스 차단 → A-01 (필수 약관 거절) |

**레이아웃**

```
┌─────────────────────────────────┐
│ [←] 약관 및 정책                  │ AppBar_Standard
├─────────────────────────────────┤
│                                 │
│  [약관 업데이트 시 상단 배너]      │
│  ┌─────────────────────────────┐│
│  │ ⚠️ 약관이 업데이트되었습니다    ││ Card_Alert (semanticWarning 보더)
│  │ 서비스 이용을 위해 재동의가    ││ bodyMedium, onSurface
│  │ 필요합니다.                   ││
│  └─────────────────────────────┘│
│                                 │ spacing16
│  ── 필수 약관 ──────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ ☑ [필수] 서비스 이용약관      ││ CheckboxListTile
│  │ 동의일: 2026-01-15      [→] ││ bodySmall + 전문 보기 화살표
│  │       ⓘ 2026-03-01 업데이트  ││ bodySmall, semanticWarning
│  ├─────────────────────────────┤│
│  │ ☑ [필수] 개인정보 처리방침    ││ CheckboxListTile
│  │ 동의일: 2026-01-15      [→] ││
│  ├─────────────────────────────┤│
│  │ ☑ [필수] 위치기반서비스       ││ CheckboxListTile
│  │       이용약관               ││
│  │ 동의일: 2026-01-15      [→] ││
│  └─────────────────────────────┘│
│                                 │ spacing16
│  ── 선택 약관 ──────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ ☐ [선택] 마케팅 수신 동의    ││ CheckboxListTile
│  │ 미동의                  [→] ││
│  └─────────────────────────────┘│
│                                 │
│                                 │
│  ┌─────────────────────────────┐│
│  │       동의하기               ││ Button_Primary
│  └─────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "약관 및 정책", leading: BackButton, style: AppBar_Standard |
| 업데이트 배너 | `Card` | style: Card_Alert (semanticWarning 보더), icon: ⚠️, 약관 업데이트 시에만 표시 |
| 섹션 헤더 | `Text` | style: labelMedium (14sp, Medium 500), color: onSurfaceVariant |
| 필수 약관 항목 | `CheckboxListTile` | activeColor: primaryTeal, 접두어 "[필수]" (primaryCoral), trailing: IconButton(chevron_right) |
| 선택 약관 항목 | `CheckboxListTile` | activeColor: primaryTeal, 접두어 "[선택]" (onSurfaceVariant), trailing: IconButton(chevron_right) |
| 동의일 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 업데이트 표시 | `Text` | style: bodySmall (12sp), color: semanticWarning (#FFAC11), prefix: ⓘ |
| 전문 보기 화살표 | `IconButton` | icon: Icons.chevron_right, color: onSurfaceVariant |
| 동의 버튼 | `ElevatedButton` | style: Button_Primary, text: "동의하기", enabled: 업데이트된 필수 약관 전체 체크 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 약관 업데이트 없음 | 배너 숨김, 기존 동의 현황만 표시, 필수 약관 체크박스 모두 checked + disabled |
| 약관 업데이트 있음 (강제 진입) | 배너 표시, 업데이트된 항목에 "업데이트" 라벨, 해당 체크박스 unchecked + 활성, 뒤로가기 비활성 |
| 약관 업데이트 있음 (자발적 진입) | 배너 표시, 업데이트 항목 체크박스 unchecked, 뒤로가기 활성 |
| 필수 약관 미동의 시 뒤로가기 (강제) | Dialog_Confirm "필수 약관에 동의하지 않으면 서비스를 이용할 수 없습니다. 로그아웃하시겠습니까?" |
| 필수 약관 거절 확인 | 로그아웃 처리 → A-01 스플래시 |
| 선택 약관 변경 | 마케팅 토글 ON/OFF 즉시 반영, `tb_user_consent` INSERT |
| 동의 저장 중 | 버튼 → CircularProgressIndicator |
| 동의 저장 성공 | Toast "약관 동의가 완료되었습니다", Navigator.pop → K-01 |
| 동의 저장 실패 | Toast "약관 동의 저장에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 체크박스 → 해당 약관 동의/해제 토글
- [탭] 약관 항목 우측 화살표 [→] → WebView로 약관 전문 표시
- [탭] 동의하기 → POST /api/v1/users/consent → 성공 시 K-01
- [뒤로가기] (강제 진입) → Dialog_Confirm (서비스 차단 안내) → 로그아웃 또는 유지
- [뒤로가기] (자발적 진입) → K-01 설정 메인

---

### K-07 계정 삭제 (Account Delete)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | K-07 |
| 화면명 | 계정 삭제 (Account Delete) |
| Phase | P1 |
| 역할 | 전체 |
| 진입 경로 | K-01 설정 메인 → 계정 삭제 → K-07 |
| 이탈 경로 | K-07 → K-01 (취소) / K-07 → A-01 (삭제 요청 완료) |

**레이아웃**

```
┌─────────────────────────────────┐
│ [←] 계정 삭제                     │ AppBar_Standard
├─────────────────────────────────┤
│                                 │
│  ⚠️ 계정을 삭제하시겠습니까?     │ headlineMedium (24sp, SemiBold)
│                                 │ semanticError 색상
│  계정 삭제를 요청하면 7일의       │ bodyMedium (14sp)
│  유예 기간이 시작됩니다.         │ onSurfaceVariant
│  유예 기간 동안 철회할 수        │
│  있습니다.                      │
│                                 │ spacing24
│  ── 삭제 시 영향 ─────────────  │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 즉시 삭제                    ││ Card_Alert (semanticError 보더)
│  │ • 프로필 정보 (이름, 사진)    ││ bodyMedium, bullet list
│  │ • 비상 연락처                 ││
│  │ • 가디언 연결 해제            ││
│  │                             ││
│  │ 익명화 보관 (90일)            ││ titleMedium, SemiBold
│  │ • 위치 데이터                 ││ bodyMedium, bullet list
│  │ • 이벤트 로그                 ││
│  │                             ││
│  │ 영구 보관 (법적 의무)          ││ titleMedium, SemiBold
│  │ • SOS 발동 기록               ││ bodyMedium, bullet list
│  │ • 결제 내역                   ││
│  └─────────────────────────────┘│
│                                 │ spacing16
│  ┌─────────────────────────────┐│
│  │ ⚠️ 참여 중인 여행             ││ Card_Alert (semanticWarning 보더)
│  │ [도쿄 여행] 에서 자동으로      ││ 여행 참여 중일 때만 표시
│  │ 탈퇴됩니다.                   ││
│  └─────────────────────────────┘│
│                                 │ spacing24
│  ── 본인 확인 ──────────────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ 전화번호 인증이 필요합니다    ││ bodyMedium
│  │                             ││
│  │ +82 10-****-1234            ││ bodyLarge, SemiBold
│  │                             ││
│  │    [인증번호 받기]            ││ Button_Secondary
│  └─────────────────────────────┘│
│                                 │
│  ┌─────────────────────────────┐│
│  │    계정 삭제 요청              ││ Button_Destructive
│  └─────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "계정 삭제", leading: BackButton, style: AppBar_Standard |
| 경고 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: semanticError (#DA4C51), prefix: ⚠️ |
| 유예 안내 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 섹션 헤더 | `Text` | style: labelMedium (14sp, Medium 500), color: onSurfaceVariant |
| 삭제 영향 카드 | `Card` | style: Card_Alert (semanticError 보더), 내부 3개 섹션 (즉시 삭제/익명화/영구 보관) |
| 영향 항목 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 영향 항목 내용 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, bullet list |
| 여행 탈퇴 경고 | `Card` | style: Card_Alert (semanticWarning 보더), Visibility: 여행 참여 중일 때만 표시 |
| 마스킹 전화번호 | `Text` | style: bodyLarge (16sp, SemiBold), color: onSurface |
| 인증번호 받기 | `OutlinedButton` | style: Button_Secondary, text: "인증번호 받기" |
| 삭제 요청 버튼 | `ElevatedButton` | style: Button_Destructive, text: "계정 삭제 요청", enabled: OTP 인증 완료 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 삭제 영향 카드 표시, 인증 미완료, 삭제 버튼 비활성 (opacity 0.4) |
| 여행 참여 중 | 여행 탈퇴 경고 카드 표시 (여행명 포함) |
| 여행 미참여 | 여행 탈퇴 경고 카드 숨김 |
| 인증번호 받기 탭 | 버튼 → CircularProgressIndicator → 성공 시 OTP 입력 UI (Input_OTP) 표시 |
| OTP 입력 중 | Input_OTP 6자리 입력 필드 표시, 타이머 3:00 카운트다운 |
| OTP 인증 성공 | ✅ "인증 완료" 표시, 삭제 요청 버튼 활성 (semanticError 배경) |
| OTP 인증 실패 | OTP 셀 보더 semanticError, Toast "인증번호가 올바르지 않습니다" |
| 삭제 요청 탭 | Dialog_Confirm "정말로 계정을 삭제하시겠습니까? 7일 후 모든 데이터가 삭제됩니다." (취소/삭제 확인) |
| 삭제 확인 | DELETE /api/v1/users/account → tb_user.deletion_requested_at = NOW() |
| 삭제 요청 성공 | Toast "계정 삭제가 요청되었습니다. 7일 후 삭제됩니다." → 로그아웃 → A-01 |
| 삭제 요청 실패 | Toast "계정 삭제 요청에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 인증번호 받기 → POST /api/v1/auth/send-otp → OTP 입력 UI 표시
- [입력] OTP 6자리 → POST /api/v1/auth/verify-otp → 인증 완료
- [탭] 계정 삭제 요청 → Dialog_Confirm 표시
- [탭] Dialog 삭제 확인 → DELETE /api/v1/users/account → 로그아웃 → A-01
- [탭] Dialog 취소 → Dialog 닫기
- [뒤로가기] → K-01 설정 메인

---

### K-08 삭제 철회 (Delete Withdrawal)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | K-08 |
| 화면명 | 삭제 철회 (Delete Withdrawal) |
| Phase | P1 |
| 역할 | 전체 |
| 진입 경로 | K-01 설정 메인 삭제 유예 배너 [철회하기] → K-08 / 앱 실행 시 유예 기간 감지 → K-08 |
| 이탈 경로 | K-08 → K-01 (철회 완료) / K-08 → K-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────────┐
│ [←] 계정 삭제 철회                │ AppBar_Standard
├─────────────────────────────────┤
│                                 │
│  계정 삭제가 예정되어 있습니다    │ headlineMedium (24sp, SemiBold)
│                                 │ onSurface
│                                 │ spacing24
│  ┌─────────────────────────────┐│
│  │                             ││ Card_Alert (semanticWarning 보더)
│  │     ┌──────────────────┐    ││
│  │     │   남은 기간        │    ││
│  │     │                  │    ││
│  │     │   5일 12시간      │    ││ headlineMedium, semanticError
│  │     │                  │    ││
│  │     │   ──────────     │    ││ LinearProgressIndicator
│  │     │   (7일 중 1.5일   │    ││ bodySmall, onSurfaceVariant
│  │     │    경과)          │    ││
│  │     └──────────────────┘    ││
│  │                             ││
│  │  삭제 예정일: 2026-03-10     ││ bodyMedium, onSurfaceVariant
│  │  요청일: 2026-03-03          ││ bodySmall, onSurfaceVariant
│  │                             ││
│  └─────────────────────────────┘│
│                                 │ spacing24
│  ── 철회 시 복원 항목 ──────── │ 섹션 헤더
│  ┌─────────────────────────────┐│
│  │ ✅ 프로필 정보               ││ Card_Standard
│  │    이름, 사진, 비상 연락처    ││ bodySmall, onSurfaceVariant
│  │                             ││
│  │ ✅ 가디언 연결                ││
│  │    기존 가디언 연결 복원      ││ bodySmall, onSurfaceVariant
│  │                             ││
│  │ ✅ 여행 데이터                ││
│  │    참여 여행 및 일정 복원     ││ bodySmall, onSurfaceVariant
│  │                             ││
│  │ ✅ 알림 설정                  ││
│  │    기존 알림 설정 유지        ││ bodySmall, onSurfaceVariant
│  └─────────────────────────────┘│
│                                 │ spacing24
│  철회 후 기존과 동일하게          │ bodyMedium, onSurfaceVariant
│  서비스를 이용할 수 있습니다.     │ 중앙 정렬
│                                 │ spacing16
│  ┌─────────────────────────────┐│
│  │       삭제 취소               ││ Button_Primary
│  └─────────────────────────────┘│
│                                 │ spacing8
│  ┌─────────────────────────────┐│
│  │    삭제 유지 (나가기)          ││ Button_Secondary
│  └─────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "계정 삭제 철회", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 카운트다운 카드 | `Card` | style: Card_Alert (semanticWarning 보더) |
| 남은 기간 라벨 | `Text` | style: labelMedium (14sp), color: onSurfaceVariant |
| 남은 기간 값 | `Text` | style: headlineMedium (24sp, SemiBold), color: semanticError (#DA4C51) |
| 진행률 바 | `LinearProgressIndicator` | value: 경과일/7, color: semanticError, trackColor: outline (#EDEDED) |
| 진행률 설명 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 삭제 예정일 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 요청일 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 섹션 헤더 | `Text` | style: labelMedium (14sp, Medium 500), color: onSurfaceVariant |
| 복원 항목 카드 | `Card` | style: Card_Standard, 내부 4개 항목 (✅ 아이콘 + 제목 + 설명) |
| 복원 항목 제목 | `Text` | style: bodyLarge (16sp), color: onSurface, prefix: ✅ |
| 복원 항목 설명 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 안내 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, textAlign: center |
| 삭제 취소 버튼 | `ElevatedButton` | style: Button_Primary, text: "삭제 취소" |
| 삭제 유지 버튼 | `OutlinedButton` | style: Button_Secondary, text: "삭제 유지 (나가기)" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 기본 (유예 기간 중) | 남은 기간 카운트다운 표시, 진행률 바, 복원 항목 리스트 |
| 남은 1일 미만 | 남은 기간 텍스트 semanticError + 볼드 강조, "곧 삭제됩니다!" 경고 추가 |
| 남은 기간 실시간 갱신 | Timer로 매분 남은 시간 업데이트 (N일 N시간 N분) |
| 철회 버튼 탭 | Dialog_Confirm "계정 삭제를 취소하시겠습니까? 기존과 동일하게 서비스를 이용할 수 있습니다." |
| 철회 확인 | PATCH /api/v1/users/account/cancel-deletion → deletion_requested_at = NULL |
| 철회 성공 | Toast "계정 삭제가 취소되었습니다", Navigator.pop → K-01 |
| 철회 실패 | Toast "처리에 실패했습니다. 다시 시도해주세요." |
| 유예 기간 만료 | 화면 진입 불가, 이미 삭제 처리됨, A-01로 리다이렉트 |
| 오프라인 | 삭제 취소 버튼 비활성, Toast "인터넷 연결이 필요합니다" |

**인터랙션**

- [탭] 삭제 취소 → Dialog_Confirm "계정 삭제를 취소하시겠습니까?" → 확인 시 PATCH API
- [탭] Dialog 확인 → PATCH /api/v1/users/account/cancel-deletion → 성공 시 K-01
- [탭] Dialog 취소 → Dialog 닫기
- [탭] 삭제 유지 (나가기) → Navigator.pop → K-01
- [뒤로가기] → K-01 설정 메인

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 8개 화면 (K-01 ~ K-08) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 설정 메뉴 원칙: `Master_docs/15_T3_설정_메뉴_원칙.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 온보딩 약관 화면: `docs/wireframes/A_Onboarding_Auth.md` (A-07)
