# L. 결제 & 구독

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 결제 및 구독 플로우 10개 화면을 정의한다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| DB 설계 v3.4 | `Master_docs/07_T2_DB_설계_및_관계_v3_4.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |

---

## 개요

- **화면 수:** 10개 (L-01 ~ L-10)
- **Phase:** 전체 P2
- **핵심 역할:** 캡틴 (여행 결제), 크루/캡틴 (가디언 슬롯), 전체 (내역)
- **하위 그룹:** 여행 기본 요금 (L-01~L-04), 가디언 & 애드온 (L-05~L-07), 환불 & 내역 (L-08~L-10)

---

## 디자인 토큰 (Payment 전용)

| 토큰 | HEX | 용도 |
|------|-----|------|
| Payment Green | `#4CAF50` | 결제 성공 아이콘, 완료 체크마크 |
| Payment Red | `#DA4C51` | 결제 실패, 환불 상태 (`semanticError` 동일) |
| Price Highlight | `primaryTeal` (`#00A2BD`) | 가격 강조 텍스트, `headlineMedium` |
| Card Brand Icon | -- | 40 x 24 dp, Visa/Mastercard/KakaoPay/NaverPay 로고 |

---

## User Journey Flow

```
L-01 여행 요금 안내
 └── [결제하기]
      ↓
L-02 결제 수단
      ↓
L-03 결제 확인
      ├── [결제 성공] → L-04 결제 완료
      └── [결제 실패] → L-10 결제 실패
                          ├── [다시 시도] → L-03
                          └── [다른 카드] → L-02

L-05 가디언 슬롯 구매 → L-02 → L-03 → L-04 / L-10
L-06 이동 세션 뷰 구매 → L-02 → L-03 → L-04 / L-10
L-07 AI 요금제 → L-02 → L-03 → L-04 / L-10

L-08 환불 요청 → Toast (요청 완료)
L-09 결제 내역 (독립 열람)
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| D-xx 여행 관리 | 6명+ 멤버 초과 시 안내 | L-01 여행 요금 안내 | L |
| L-04 | 결제 완료 → 여행으로 이동 | D-xx 여행 상세 | D |
| K-01 | 설정 > 결제 내역 | L-09 결제 내역 | L |
| F-xx 가디언 시스템 | 슬롯 추가 구매 | L-05 가디언 슬롯 구매 | L |
| K-01 | 설정 > AI 요금제 | L-07 AI 요금제 | L |

---

## 화면 상세

---

### L-01 여행 요금 안내 (Payment Trip Upgrade)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-01 |
| 화면명 | 여행 요금 안내 (Payment Trip Upgrade) |
| Phase | P2 |
| 역할 | 캡틴 |
| 진입 경로 | 여행 멤버 6명 이상 시 자동 안내 → L-01 |
| 이탈 경로 | L-01 → L-02 (결제하기) / L-01 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 여행 요금 안내             │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  더 많은 멤버와               │ headlineMedium (24sp, SemiBold)
│  함께 떠나세요                │
│                             │
│  6명 이상 그룹은             │ bodyMedium (14sp)
│  유료 요금제가 필요합니다     │ onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │ 📊  요금표               ││ Card_Standard
│  │                         ││
│  │  인원        가격        ││
│  │ ─────────────────────── ││ Divider
│  │  6~10명    4,900원/여행  ││ bodyLarge, primaryTeal (price)
│  │  11~20명   8,900원/여행  ││ bodyLarge, primaryTeal (price)
│  │  21~50명  14,900원/여행  ││ bodyLarge, primaryTeal (price)
│  │                         ││
│  │  현재 인원: 8명 → 4,900원 ││ bodyMedium, SemiBold
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ 무료 vs 유료 비교         ││ Card_Standard
│  │                         ││
│  │  기능       무료   유료   ││
│  │ ─────────────────────── ││ Divider
│  │  멤버 수    ~5명   ~50명  ││
│  │  실시간 위치  ✅    ✅    ││
│  │  SOS        ✅    ✅    ││
│  │  채팅        ✅    ✅    ││
│  │  가디언 슬롯  2개   2개+  ││
│  │  출석 체크    ❌    ✅    ││
│  │  이동 세션 뷰 ❌   애드온  ││
│  └─────────────────────────┘│
│                             │
│  * 1회 결제, 여행 종료 시      │ bodySmall, onSurfaceVariant
│    자동 만료                  │
│                             │
│  ┌─────────────────────────┐│
│  │      결제하기              ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "여행 요금 안내", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 요금표 카드 | `Card` | style: Card_Standard, radius16, 내부 패딩 16px |
| 요금 행 | `Row` | leading: 인원 범위 (bodyLarge), trailing: 가격 (bodyLarge, primaryTeal, SemiBold) |
| 현재 인원 표시 | `Container` | backgroundColor: surfaceVariant, radius8, 패딩 12px, 텍스트 bodyMedium SemiBold |
| 비교 카드 | `Card` | style: Card_Standard, radius16, 2열 테이블 레이아웃 |
| 비교 체크 아이콘 | `Icon` | Icons.check_circle (semanticSuccess), Icons.cancel (onSurfaceVariant) |
| 안내 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 결제 버튼 | `ElevatedButton` | style: Button_Primary, text: "결제하기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 현재 여행 인원 기반 해당 가격대 행 하이라이트 (배경 tint) |
| 이미 결제 완료 | 결제 버튼 → "결제 완료" (disabled), 상단에 Badge "결제 완료" 표시 |
| 네트워크 오류 | SnackBar "요금 정보를 불러올 수 없습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 결제하기 → Navigator.push → L-02 결제 수단 (tripId, amount 파라미터 전달)
- [뒤로가기] → 이전 화면 (여행 관리)

---

### L-02 결제 수단 (Payment Method)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-02 |
| 화면명 | 결제 수단 (Payment Method) |
| Phase | P2 |
| 역할 | 캡틴 |
| 진입 경로 | L-01 결제하기 → L-02 / L-05~L-07 결제 진행 → L-02 |
| 이탈 경로 | L-02 → L-03 (수단 선택 완료) / L-02 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 결제 수단                 │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  결제 수단을 선택해주세요     │ headlineMedium (24sp, SemiBold)
│                             │
│  ── 저장된 카드 ────────────  │ bodySmall, onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │ [Visa]  **** 1234       ││ Card_Selectable
│  │  홍길동  12/27           ││ bodySmall, onSurfaceVariant
│  │                    [✓]  ││ 선택 체크 (primaryTeal)
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │ [MC]  **** 5678         ││ Card_Selectable
│  │  홍길동  03/26           ││ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │
│  ── 간편결제 ────────────────  │ bodySmall, onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │ [KakaoPay 아이콘]        ││ Card_Selectable
│  │  카카오페이               ││
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │ [NaverPay 아이콘]        ││ Card_Selectable
│  │  네이버페이               ││
│  └─────────────────────────┘│
│                             │
│  + 새 카드 등록              │ TextButton, primaryTeal
│                             │
│  ┌─────────────────────────┐│
│  │       다음                ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "결제 수단", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 섹션 라벨 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, SemiBold |
| 저장된 카드 | `Card` + `InkWell` | style: Card_Selectable, leading: 카드 브랜드 아이콘 (40x24dp), title: 마스킹된 카드번호 (bodyLarge), subtitle: 소유자명 + 만료일 (bodySmall) |
| 간편결제 항목 | `Card` + `InkWell` | style: Card_Selectable, leading: 결제사 아이콘 (40x24dp), title: 결제사명 (bodyLarge) |
| 선택 인디케이터 | `Icon` | Icons.check_circle, color: primaryTeal (선택 시) / transparent (미선택) |
| 새 카드 등록 | `TextButton` | icon: Icons.add, text: "새 카드 등록", color: primaryTeal |
| 다음 버튼 | `ElevatedButton` | style: Button_Primary, text: "다음", enabled: 수단 선택 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (저장 카드 있음) | 마지막 사용 카드 자동 선택 (좌측 보더 primaryTeal + 체크 아이콘), 다음 버튼 활성 |
| 초기 (저장 카드 없음) | "저장된 카드" 섹션 빈 상태, "새 카드를 등록해주세요" 안내 텍스트, 다음 버튼 비활성 |
| 카드 선택 | 해당 Card_Selectable 좌측 보더 primaryTeal + 배경 tint, 이전 선택 해제, 다음 버튼 활성 |
| 간편결제 선택 | 해당 카드 좌측 보더 primaryTeal, 저장된 카드 선택 해제 |
| 새 카드 등록 탭 | Modal_Bottom (카드 등록 폼: 카드번호 / 유효기간 / CVC / 소유자명) |
| 카드 등록 중 | Modal 내 Button_Primary → CircularProgressIndicator |
| 카드 등록 성공 | Modal 닫힘, 저장된 카드 목록에 추가 + 자동 선택 |
| 카드 등록 실패 | Modal 내 에러 텍스트 표시 "카드 등록에 실패했습니다" |

**인터랙션**

- [탭] 저장된 카드 → 해당 카드 선택 (단일 선택)
- [탭] 간편결제 → 해당 결제사 선택 (단일 선택)
- [탭] + 새 카드 등록 → Modal_Bottom 카드 등록 폼 표시
- [탭] 다음 → Navigator.push → L-03 결제 확인 (paymentMethod 파라미터 전달)
- [롱프레스] 저장된 카드 → Dialog_Confirm "이 카드를 삭제할까요?" (삭제 / 취소)
- [뒤로가기] → 이전 화면

---

### L-03 결제 확인 (Payment Confirm)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-03 |
| 화면명 | 결제 확인 (Payment Confirm) |
| Phase | P2 |
| 역할 | 캡틴 |
| 진입 경로 | L-02 결제 수단 선택 완료 → L-03 |
| 이탈 경로 | L-03 → L-04 (결제 성공) / L-03 → L-10 (결제 실패) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 결제 확인                 │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  주문 내역을 확인해주세요     │ headlineMedium (24sp, SemiBold)
│                             │
│  ┌─────────────────────────┐│
│  │ 주문 내역               ││ Card_Standard
│  │                         ││
│  │  상품        여행 요금제  ││ bodyLarge
│  │  여행명      도쿄 여행    ││ bodyMedium, onSurfaceVariant
│  │  인원        8명         ││ bodyMedium, onSurfaceVariant
│  │  기간     3/15 ~ 3/20   ││ bodyMedium, onSurfaceVariant
│  │ ─────────────────────── ││ Divider
│  │  금액       4,900원      ││ bodyLarge, SemiBold
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ 결제 수단               ││ Card_Standard
│  │                         ││
│  │  [Visa] **** 1234       ││ bodyLarge + 카드 아이콘
│  │              변경 >      ││ TextButton, primaryTeal
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ 총 결제 금액             ││ Card_Standard
│  │                         ││
│  │         4,900원          ││ headlineMedium, primaryTeal
│  └─────────────────────────┘│
│                             │ spacing24
│  ┌─────────────────────────┐│
│  │ ☑ 결제 진행에 동의합니다   ││ CheckboxListTile
│  │   환불 정책 확인 >        ││ TextButton, primaryTeal
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │   4,900원 결제            ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "결제 확인", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 주문 내역 카드 | `Card` | style: Card_Standard, 내부 `Column` 레이아웃 |
| 주문 행 | `Row` | leading: 라벨 (bodyMedium, onSurfaceVariant), trailing: 값 (bodyMedium, onSurface) |
| 금액 행 | `Row` | leading: "금액" (bodyLarge, SemiBold), trailing: 가격 (bodyLarge, SemiBold, primaryTeal) |
| 결제 수단 카드 | `Card` | style: Card_Standard, 카드 브랜드 아이콘 + 마스킹 번호 + "변경" TextButton |
| 변경 버튼 | `TextButton` | text: "변경", color: primaryTeal, → L-02로 이동 |
| 총 결제 금액 | `Text` | style: headlineMedium (24sp, SemiBold), color: primaryTeal, textAlign: center |
| 동의 체크 | `CheckboxListTile` | activeColor: primaryTeal, title: "결제 진행에 동의합니다" (bodyMedium) |
| 환불 정책 링크 | `TextButton` | text: "환불 정책 확인", color: primaryTeal, → Modal_Bottom 환불 정책 |
| 결제 버튼 | `ElevatedButton` | style: Button_Primary, text: "4,900원 결제", enabled: 동의 체크 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 동의 체크 unchecked, 결제 버튼 비활성 (opacity 0.4) |
| 동의 체크 완료 | 결제 버튼 활성 (primaryTeal) |
| 결제 처리 중 | 결제 버튼 → CircularProgressIndicator (white), 전체 화면 터치 비활성, 스크림 오버레이 (black 20%) |
| 결제 성공 | Navigator.pushReplacement → L-04 결제 완료 |
| 결제 실패 | Navigator.push → L-10 결제 실패 (errorCode, errorMessage 파라미터 전달) |
| 카드 인증 필요 | 외부 WebView (3D Secure 인증) 열림 → 인증 완료 → 결제 재시도 |

**인터랙션**

- [탭] 변경 → Navigator.pop → L-02 결제 수단 (변경 후 복귀)
- [탭] 환불 정책 확인 → Modal_Bottom (환불 정책 전문 표시)
- [탭] 동의 체크박스 → 체크/해제 토글
- [탭] 4,900원 결제 → POST /api/v1/payments → 결제 PG 연동 → 결과에 따라 L-04 또는 L-10
- [뒤로가기] → Dialog_Confirm "결제를 취소할까요?" (확인 → L-01 / 취소 → 유지)

---

### L-04 결제 완료 (Payment Success)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-04 |
| 화면명 | 결제 완료 (Payment Success) |
| Phase | P2 |
| 역할 | 캡틴 |
| 진입 경로 | L-03 결제 성공 → L-04 |
| 이탈 경로 | L-04 → 여행 상세 (여행으로 이동) / L-04 → L-09 (내역 확인) |

**레이아웃**

```
┌─────────────────────────────┐
│ [×] 결제 완료                 │ AppBar_Standard (close 버튼)
├─────────────────────────────┤
│                             │
│                             │
│          ┌──────┐           │
│          │  ✓   │           │ 체크마크 아이콘
│          │      │           │ 64dp, Payment Green (#4CAF50)
│          └──────┘           │ Lottie 애니메이션 (성공)
│                             │
│     결제가 완료되었습니다     │ headlineMedium (24sp, SemiBold)
│                             │ textAlign: center
│                             │
│  ┌─────────────────────────┐│
│  │ 결제 영수증              ││ Card_Standard
│  │                         ││
│  │  주문번호   PAY-20260315 ││ bodyMedium
│  │  상품      여행 요금제    ││ bodyMedium
│  │  결제일    2026.03.15    ││ bodyMedium
│  │  결제수단  Visa *1234    ││ bodyMedium
│  │ ─────────────────────── ││ Divider
│  │  결제 금액   4,900원     ││ titleMedium, SemiBold
│  └─────────────────────────┘│
│                             │
│                             │
│  ┌─────────────────────────┐│
│  │    여행으로 이동           ││ Button_Primary
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │    영수증 저장             ││ Button_Secondary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "결제 완료", leading: CloseButton (×), style: AppBar_Standard |
| 성공 아이콘 | `Lottie` / `Icon` | Icons.check_circle, size: 64dp, color: Payment Green (#4CAF50), Lottie 애니메이션 (1.5초, 1회) |
| 완료 텍스트 | `Text` | style: headlineMedium (24sp, SemiBold), textAlign: center, color: onSurface |
| 영수증 카드 | `Card` | style: Card_Standard, radius16, 내부 패딩 16px |
| 영수증 행 | `Row` | leading: 라벨 (bodyMedium, onSurfaceVariant), trailing: 값 (bodyMedium, onSurface) |
| 결제 금액 행 | `Row` | leading: "결제 금액" (titleMedium, SemiBold), trailing: 가격 (titleMedium, SemiBold, primaryTeal) |
| 여행 이동 버튼 | `ElevatedButton` | style: Button_Primary, text: "여행으로 이동" |
| 영수증 저장 버튼 | `OutlinedButton` | style: Button_Secondary, text: "영수증 저장" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 진입 시 | 체크마크 Lottie 애니메이션 재생 (1.5초), 영수증 카드 페이드인 (300ms 딜레이) |
| 영수증 저장 중 | 저장 버튼 → CircularProgressIndicator |
| 영수증 저장 성공 | Toast "영수증이 저장되었습니다" (갤러리/파일에 이미지 저장) |
| 영수증 저장 실패 | Toast "저장에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 여행으로 이동 → Navigator.pushReplacement → 여행 상세 화면 (tripId 파라미터)
- [탭] 영수증 저장 → 영수증 카드 스크린샷 캡처 → 기기 갤러리/파일에 저장
- [탭] × (닫기) → Navigator.pushReplacement → 여행 상세 화면
- [시스템 뒤로가기] → 여행 상세 화면 (결제 화면 스택 전체 제거)

---

### L-05 가디언 슬롯 구매 (Guardian Slot Purchase)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-05 |
| 화면명 | 가디언 슬롯 구매 (Guardian Slot Purchase) |
| Phase | P2 |
| 역할 | 크루 / 캡틴 |
| 진입 경로 | 가디언 관리 > 슬롯 추가 → L-05 |
| 이탈 경로 | L-05 → L-02 (구매 진행) / L-05 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 가디언 슬롯 구매          │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  가디언 슬롯을               │ headlineMedium (24sp, SemiBold)
│  추가할 수 있습니다           │
│                             │
│  여행당 최대 5명의 가디언을    │ bodyMedium (14sp)
│  연결할 수 있습니다           │ onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │ 현재 슬롯 상태            ││ Card_Standard
│  │                         ││
│  │  (●) (●) (○) (○) (○)   ││ 5개 원형 인디케이터
│  │  사용   사용   빈칸  빈칸  빈칸││ bodySmall
│  │                         ││
│  │  무료 슬롯: 2/2 사용 중   ││ bodyMedium, SemiBold
│  │  유료 슬롯: 0/3 사용 중   ││ bodyMedium, onSurfaceVariant
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ 슬롯 구매                ││ Card_Standard
│  │                         ││
│  │  1,900원 / 인 / 여행      ││ headlineMedium, primaryTeal
│  │                         ││
│  │  구매 수량               ││ bodyMedium
│  │  [−]    1    [+]        ││ Counter (1~3)
│  │                         ││
│  │ ─────────────────────── ││ Divider
│  │  합계      1,900원       ││ titleMedium, SemiBold
│  └─────────────────────────┘│
│                             │
│  * 유료 슬롯은 해당 여행      │ bodySmall, onSurfaceVariant
│    종료 시 자동 만료됩니다     │
│                             │
│  ┌─────────────────────────┐│
│  │   1,900원 결제하기         ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "가디언 슬롯 구매", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 설명 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant |
| 슬롯 상태 카드 | `Card` | style: Card_Standard, radius16 |
| 슬롯 인디케이터 | `Row` < `Container` x 5 > | 사용 중: 40dp 원형, backgroundColor: primaryTeal / 빈 슬롯: outline 보더, backgroundColor: surfaceVariant |
| 무료/유료 슬롯 표시 | `Text` | style: bodyMedium (14sp), SemiBold (무료) / Regular (유료) |
| 단가 | `Text` | style: headlineMedium (24sp, SemiBold), color: primaryTeal |
| 수량 카운터 | `Row` | IconButton (−) + Text (수량, titleMedium) + IconButton (+), 범위: 1 ~ (5 - 현재 유료 슬롯) |
| 합계 행 | `Row` | leading: "합계" (titleMedium), trailing: 합계 금액 (titleMedium, SemiBold, primaryTeal) |
| 안내 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 결제 버튼 | `ElevatedButton` | style: Button_Primary, text: "{합계}원 결제하기", 수량 변경 시 금액 동적 업데이트 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 현재 슬롯 사용 상태 반영, 수량 1, 합계 1,900원 |
| 수량 변경 | 합계 금액 실시간 업데이트, 결제 버튼 금액 업데이트 |
| 최대 수량 도달 | (+) 버튼 비활성 (opacity 0.4), Toast "최대 구매 가능 수량입니다" |
| 최소 수량 (1) | (−) 버튼 비활성 (opacity 0.4) |
| 모든 유료 슬롯 구매 완료 | 전체 화면 → "모든 가디언 슬롯이 활성화되어 있습니다" 안내 + 뒤로가기 버튼 |

**인터랙션**

- [탭] (−) → 수량 1 감소 (최소 1)
- [탭] (+) → 수량 1 증가 (최대: 5 - 현재 유료 슬롯 수)
- [탭] 결제하기 → Navigator.push → L-02 결제 수단 (item: "guardian_slot", quantity, amount 전달)
- [뒤로가기] → 이전 화면 (가디언 관리)

---

### L-06 이동 세션 뷰 구매 (Movement Session Addon)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-06 |
| 화면명 | 이동 세션 뷰 구매 (Movement Session Addon) |
| Phase | P2 |
| 역할 | 전체 |
| 진입 경로 | 여행 상세 > 이동 세션 뷰 잠금 탭 → L-06 / 설정 > 애드온 → L-06 |
| 이탈 경로 | L-06 → L-02 (구매 진행) / L-06 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 이동 세션 뷰              │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │                         ││ Preview Area
│  │   ~~~~ 이동 경로 ~~~~    ││ 지도 미리보기
│  │   ~~~ 재생 프리뷰 ~~~    ││ 높이: 200dp
│  │         ▶               ││ 재생 아이콘 (중앙, 반투명 오버레이)
│  │                         ││
│  └─────────────────────────┘│
│                             │
│  이동 경로를                 │ headlineMedium (24sp, SemiBold)
│  다시 볼 수 있습니다          │
│                             │
│  ┌─────────────────────────┐│
│  │ 기능 소개                ││ Card_Standard
│  │                         ││
│  │  📍 이동 경로 재생        ││ ListTile-style row
│  │     멤버의 이동 경로를     ││ bodySmall, onSurfaceVariant
│  │     시간순으로 재생        ││
│  │                         ││
│  │  📊 이동 통계             ││ ListTile-style row
│  │     일별 이동 거리,       ││ bodySmall, onSurfaceVariant
│  │     방문 장소 요약        ││
│  │                         ││
│  │  📸 여행 기록             ││ ListTile-style row
│  │     경로 위 사진/메모     ││ bodySmall, onSurfaceVariant
│  │     타임라인 표시         ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │                         ││ Card_Standard (가격 카드)
│  │   2,900원 / 여행          ││ headlineMedium, primaryTeal
│  │   1회 구매, 여행 종료까지  ││ bodySmall, onSurfaceVariant
│  │                         ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │   2,900원 구매하기         ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "이동 세션 뷰", leading: BackButton, style: AppBar_Standard |
| 프리뷰 영역 | `Stack` | 높이: 200dp, 배경: 지도 이미지 (블러 처리), 중앙: 재생 아이콘 (56dp, white, opacity 0.8) |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 기능 소개 카드 | `Card` | style: Card_Standard, radius16 |
| 기능 행 | `Row` | leading: 아이콘 (24dp, primaryTeal), title: 기능명 (bodyLarge, SemiBold), subtitle: 설명 (bodySmall, onSurfaceVariant) |
| 가격 카드 | `Card` | style: Card_Standard, radius16, textAlign: center |
| 가격 텍스트 | `Text` | style: headlineMedium (24sp, SemiBold), color: primaryTeal |
| 가격 부연 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 구매 버튼 | `ElevatedButton` | style: Button_Primary, text: "2,900원 구매하기" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 프리뷰 영역에 샘플 경로 이미지 표시 (블러), 구매 버튼 활성 |
| 이미 구매 완료 | 구매 버튼 → "이미 구매한 기능입니다" (disabled), 상단 Badge "구매 완료" |
| 여행 미참여 | 구매 버튼 비활성, "여행에 참여 후 구매할 수 있습니다" 안내 |

**인터랙션**

- [탭] 프리뷰 영역 → 간단한 데모 애니메이션 재생 (3초, 경로 라인 그리기)
- [탭] 2,900원 구매하기 → Navigator.push → L-02 결제 수단 (item: "movement_session", amount: 2900 전달)
- [뒤로가기] → 이전 화면

---

### L-07 AI 요금제 (AI Plans)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-07 |
| 화면명 | AI 요금제 (AI Plans) |
| Phase | P2 |
| 역할 | 전체 |
| 진입 경로 | 설정 > AI 요금제 → L-07 / AI 기능 사용 시 업그레이드 유도 → L-07 |
| 이탈 경로 | L-07 → L-02 (업그레이드 결제) / L-07 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] AI 요금제                 │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  AI로 더 스마트한             │ headlineMedium (24sp, SemiBold)
│  여행을 만드세요              │
│                             │
│  ┌─────────────────────────┐│
│  │ AI Plus        현재 플랜  ││ Card_Selectable
│  │                         ││ 좌측 보더: primaryTeal
│  │  4,900원/월               ││ titleMedium, primaryTeal
│  │                         ││
│  │  ✅ AI 일정 추천          ││ bodyMedium, Row (icon + text)
│  │  ✅ 안전 요약 리포트       ││
│  │  ✅ 실시간 번역 (3회/일)   ││
│  │  ❌ 무제한 번역            ││ onSurfaceVariant (비활성)
│  │  ❌ AI 경로 최적화         ││
│  │  ❌ 음성 번역              ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ AI Pro          인기     ││ Card_Selectable
│  │                         ││ 좌측 보더: secondaryAmber
│  │  9,900원/월               ││ titleMedium, secondaryAmber
│  │                         ││ (#FFC363)
│  │  ✅ AI 일정 추천          ││ bodyMedium
│  │  ✅ 안전 요약 리포트       ││
│  │  ✅ 실시간 번역 (무제한)   ││
│  │  ✅ 무제한 번역            ││
│  │  ✅ AI 경로 최적화         ││
│  │  ✅ 음성 번역              ││
│  └─────────────────────────┘│
│                             │ spacing16
│  자동 갱신 | 언제든 해지 가능  │ bodySmall, onSurfaceVariant
│                             │ textAlign: center
│                             │
│  ┌─────────────────────────┐│
│  │     업그레이드              ││ Button_Primary
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "AI 요금제", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| AI Plus 카드 | `Card` + `InkWell` | style: Card_Selectable, 좌측 보더: primaryTeal |
| AI Pro 카드 | `Card` + `InkWell` | style: Card_Selectable, 좌측 보더: secondaryAmber (#FFC363) |
| 현재 플랜 뱃지 | `Container` (pill) | backgroundColor: primaryTeal, text: "현재 플랜", labelSmall, white |
| 인기 뱃지 | `Container` (pill) | backgroundColor: secondaryAmber (#FFC363), text: "인기", labelSmall, onSurface |
| 가격 | `Text` | style: titleMedium (18sp, SemiBold), color: primaryTeal / secondaryAmber |
| 기능 행 (활성) | `Row` | leading: Icons.check_circle (semanticSuccess #15A1A5, 20dp), trailing: 기능명 (bodyMedium, onSurface) |
| 기능 행 (비활성) | `Row` | leading: Icons.cancel (onSurfaceVariant, 20dp), trailing: 기능명 (bodyMedium, onSurfaceVariant) |
| 안내 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |
| 업그레이드 버튼 | `ElevatedButton` | style: Button_Primary, text: "업그레이드" |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 무료 사용자 | 두 카드 모두 선택 가능, "현재 플랜" 뱃지 없음, 버튼: "시작하기" |
| AI Plus 구독 중 | Plus 카드에 "현재 플랜" 뱃지, Plus 카드 자동 선택 + 비활성, Pro 카드 선택 가능, 버튼: "Pro로 업그레이드" |
| AI Pro 구독 중 | Pro 카드에 "현재 플랜" 뱃지, 업그레이드 버튼 → "현재 최고 플랜입니다" (disabled), 하단 "구독 해지" TextButton 표시 |
| Pro 카드 선택 | Pro 카드 좌측 보더 secondaryAmber + 배경 tint, 버튼 활성: "9,900원/월 시작하기" |
| Plus 카드 선택 | Plus 카드 좌측 보더 primaryTeal + 배경 tint, 버튼 활성: "4,900원/월 시작하기" |

**인터랙션**

- [탭] AI Plus 카드 → Plus 플랜 선택 (Pro 해제)
- [탭] AI Pro 카드 → Pro 플랜 선택 (Plus 해제)
- [탭] 업그레이드 / 시작하기 → Navigator.push → L-02 결제 수단 (item: "ai_plan", plan: selected, amount 전달)
- [탭] 구독 해지 (Pro 구독 중일 때) → Dialog_Confirm "구독을 해지할까요? 현재 결제 주기 종료까지 이용 가능합니다." (확인 → 해지 API → Toast "구독이 해지되었습니다")
- [뒤로가기] → 이전 화면

---

### L-08 환불 요청 (Refund Request)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-08 |
| 화면명 | 환불 요청 (Refund Request) |
| Phase | P2 |
| 역할 | 캡틴 |
| 진입 경로 | L-09 결제 내역 > 환불 가능 항목 탭 → L-08 |
| 이탈 경로 | L-08 → L-09 (환불 요청 완료) / L-08 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 환불 요청                 │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  환불을 요청합니다            │ headlineMedium (24sp, SemiBold)
│                             │
│  ┌─────────────────────────┐│
│  │ 환불 정책                ││ Card_Alert (warning 보더)
│  │                         ││
│  │  ⚠ 결제 후 7일 이내      ││ bodyMedium, SemiBold
│  │    미사용 시 전액 환불     ││
│  │                         ││
│  │  • 여행 시작 전: 전액 환불 ││ bodySmall
│  │  • 여행 시작 후: 환불 불가 ││ bodySmall
│  │  • AI 구독: 당월 해지,    ││ bodySmall
│  │    잔여 기간 이용 가능     ││
│  └─────────────────────────┘│
│                             │ spacing16
│  ┌─────────────────────────┐│
│  │ 환불 대상                ││ Card_Standard
│  │                         ││
│  │  상품     여행 요금제     ││ bodyMedium
│  │  결제일   2026.03.15     ││ bodyMedium, onSurfaceVariant
│  │  결제금액  4,900원        ││ bodyMedium
│  │ ─────────────────────── ││ Divider
│  │  환불 금액  4,900원       ││ titleMedium, SemiBold,
│  │                         ││ semanticError (#DA4C51)
│  └─────────────────────────┘│
│                             │ spacing16
│  환불 사유                    │ bodyMedium, SemiBold
│                             │
│  ┌─────────────────────────┐│
│  │ 사유를 선택해주세요    ▼  ││ DropdownButtonFormField
│  └─────────────────────────┘│
│                             │ spacing8
│  ┌─────────────────────────┐│
│  │ 추가 사유 (선택)          ││ Input_Text (multiline)
│  │                         ││ maxLines: 3
│  └─────────────────────────┘│
│                             │ spacing16
│  환불 처리까지 3~5영업일      │ bodySmall, onSurfaceVariant
│  소요됩니다                  │
│                             │
│  ┌─────────────────────────┐│
│  │     환불 요청              ││ Button_Destructive
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "환불 요청", leading: BackButton, style: AppBar_Standard |
| 제목 | `Text` | style: headlineMedium (24sp, SemiBold), color: onSurface |
| 환불 정책 카드 | `Card` | style: Card_Alert (warning), 보더: semanticWarning (#FFAC11), 1px |
| 정책 항목 | `Text` | style: bodySmall (12sp), color: onSurface, 불릿 리스트 |
| 환불 대상 카드 | `Card` | style: Card_Standard, radius16 |
| 환불 금액 | `Text` | style: titleMedium (18sp, SemiBold), color: semanticError (#DA4C51) |
| 사유 드롭다운 | `DropdownButtonFormField` | items: ["여행 취소", "멤버 변동", "서비스 불만", "단순 변심", "기타"], radius8, 보더: outline |
| 추가 사유 | `TextFormField` | style: Input_Text, hintText: "추가 사유를 입력해주세요 (선택)", maxLines: 3 |
| 처리 기간 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 환불 요청 버튼 | `ElevatedButton` | style: Button_Destructive, text: "환불 요청", enabled: 사유 선택 시 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 사유 미선택, 환불 요청 버튼 비활성 (opacity 0.4) |
| 사유 선택 완료 | 환불 요청 버튼 활성 (semanticError 배경) |
| 환불 불가 항목 | 환불 대상 카드에 "환불 불가" 뱃지 (빨강), 환불 금액 → "0원", 버튼 비활성, 사유: "여행 시작 후에는 환불이 불가합니다" 안내 |
| 환불 요청 중 | 버튼 → CircularProgressIndicator (white) |
| 환불 요청 성공 | Navigator.pop → L-09, Toast "환불 요청이 접수되었습니다. 3~5영업일 내 처리됩니다." |
| 환불 요청 실패 | SnackBar "환불 요청에 실패했습니다. 다시 시도해주세요." |

**인터랙션**

- [탭] 사유 드롭다운 → Modal_Bottom 사유 목록 표시
- [탭] 추가 사유 입력 → 키보드 표시
- [탭] 환불 요청 → Dialog_Confirm "환불을 요청할까요? 처리 후 취소할 수 없습니다." (확인 → POST /api/v1/payments/{paymentId}/refund → 결과 처리)
- [뒤로가기] → L-09 결제 내역

---

### L-09 결제 내역 (Payment History)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-09 |
| 화면명 | 결제 내역 (Payment History) |
| Phase | P2 |
| 역할 | 전체 |
| 진입 경로 | 설정 > 결제 내역 → L-09 |
| 이탈 경로 | L-09 → L-08 (환불 요청) / L-09 → 영수증 상세 (항목 탭) / L-09 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 결제 내역                 │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  [전체] [완료] [환불] [실패]  │ Chip_Tag (필터, 수평 스크롤)
│                             │
│  ── 2026년 3월 ──────────── │ bodySmall, onSurfaceVariant
│                             │
│  ┌─────────────────────────┐│
│  │ 2026.03.15              ││ 결제 아이템
│  │ 여행 요금제 - 도쿄 여행   ││ bodyLarge
│  │                [완료]   ││ Badge (semanticSuccess)
│  │           4,900원       ││ titleMedium, SemiBold
│  │                    > ││ trailing chevron
│  └─────────────────────────┘│
│  ─────────────────────────── │ Divider
│  ┌─────────────────────────┐│
│  │ 2026.03.10              ││ 결제 아이템
│  │ 가디언 슬롯 x2           ││ bodyLarge
│  │                [환불]   ││ Badge (semanticError)
│  │           3,800원       ││ titleMedium, SemiBold
│  │                    > ││ trailing chevron
│  └─────────────────────────┘│
│  ─────────────────────────── │ Divider
│  ┌─────────────────────────┐│
│  │ 2026.03.05              ││ 결제 아이템
│  │ AI Plus 구독             ││ bodyLarge
│  │                [실패]   ││ Badge (Payment Red)
│  │           4,900원       ││ titleMedium, SemiBold
│  │                    > ││ trailing chevron
│  └─────────────────────────┘│
│                             │
│  ── 2026년 2월 ──────────── │ bodySmall, onSurfaceVariant
│  ...                        │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "결제 내역", leading: BackButton, style: AppBar_Standard |
| 필터 칩 | `Row` < `Chip` x 4 > | style: Chip_Tag, items: ["전체", "완료", "환불", "실패"], selectedColor: primaryTeal, 수평 스크롤 |
| 월별 구분 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, SemiBold |
| 결제 아이템 | `ListTile` | leading: 날짜 (bodySmall, onSurfaceVariant), title: 상품명 (bodyLarge), trailing: 상태 뱃지 + 금액 + chevron |
| 상태 뱃지 (완료) | `Container` (pill) | backgroundColor: semanticSuccess (#15A1A5), text: "완료", labelSmall, white |
| 상태 뱃지 (환불) | `Container` (pill) | backgroundColor: semanticError (#DA4C51), text: "환불", labelSmall, white |
| 상태 뱃지 (실패) | `Container` (pill) | backgroundColor: Payment Red (#DA4C51), text: "실패", labelSmall, white |
| 금액 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 구분선 | `Divider` | color: outlineVariant (#F5F5F5) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | "전체" 필터 활성, 모든 결제 내역 월별 그룹으로 표시 |
| "완료" 필터 | 완료 상태 항목만 표시 |
| "환불" 필터 | 환불/환불 진행 중 항목만 표시 |
| "실패" 필터 | 실패 항목만 표시 |
| 내역 없음 | 빈 상태 일러스트 + "결제 내역이 없습니다" (bodyMedium, onSurfaceVariant, 중앙) |
| 로딩 중 | ProgressIndicator (Circular, 중앙 표시) |
| 스크롤 끝 | 추가 데이터 로딩 (pagination), 하단 CircularProgressIndicator |
| 네트워크 오류 | 에러 상태 + "다시 시도" 버튼 (중앙) |

**인터랙션**

- [탭] 필터 칩 → 해당 상태로 목록 필터링 (애니메이션 전환, 300ms)
- [탭] 결제 아이템 → Modal_Bottom 영수증 상세 (주문번호, 상품, 결제일, 수단, 금액, 상태), 환불 가능 시 "환불 요청" 버튼 표시
- [탭] 영수증 상세 내 "환불 요청" → Navigator.push → L-08 환불 요청 (paymentId 파라미터)
- [스크롤 하단] → 다음 페이지 로딩 (GET /api/v1/payments?page=N&status=filter)
- [뒤로가기] → 이전 화면 (설정)

---

### L-10 결제 실패 (Payment Failed)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | L-10 |
| 화면명 | 결제 실패 (Payment Failed) |
| Phase | P2 |
| 역할 | 캡틴 |
| 진입 경로 | L-03 결제 실패 → L-10 |
| 이탈 경로 | L-10 → L-03 (다시 시도) / L-10 → L-02 (다른 카드) / L-10 → 이전 화면 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [×] 결제 실패                 │ AppBar_Standard (close 버튼)
├─────────────────────────────┤
│                             │
│                             │
│          ┌──────┐           │
│          │  ✕   │           │ 실패 아이콘
│          │      │           │ 64dp, Payment Red (#DA4C51)
│          └──────┘           │
│                             │
│     결제에 실패했습니다       │ headlineMedium (24sp, SemiBold)
│                             │ textAlign: center
│                             │
│  ┌─────────────────────────┐│
│  │ 실패 사유                ││ Card_Alert (error 보더)
│  │                         ││
│  │  카드 잔액이 부족합니다   ││ bodyMedium, onSurface
│  │                         ││
│  │  오류 코드: PG-4001      ││ bodySmall, onSurfaceVariant
│  └─────────────────────────┘│
│                             │
│                             │
│                             │
│                             │
│  ┌─────────────────────────┐│
│  │      다시 시도             ││ Button_Primary
│  └─────────────────────────┘│
│                             │ spacing12
│  ┌─────────────────────────┐│
│  │      다른 카드로 결제       ││ Button_Secondary
│  └─────────────────────────┘│
│                             │ spacing16
│  문제가 계속되면 고객센터로    │ bodySmall, onSurfaceVariant
│  문의해주세요                │ textAlign: center
│  고객센터 연결 >              │ TextButton, primaryTeal
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "결제 실패", leading: CloseButton (×), style: AppBar_Standard |
| 실패 아이콘 | `Icon` | Icons.cancel, size: 64dp, color: Payment Red (#DA4C51) |
| 실패 텍스트 | `Text` | style: headlineMedium (24sp, SemiBold), textAlign: center, color: onSurface |
| 실패 사유 카드 | `Card` | style: Card_Alert (error), 보더: semanticError (#DA4C51), 1px |
| 사유 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurface |
| 오류 코드 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 다시 시도 버튼 | `ElevatedButton` | style: Button_Primary, text: "다시 시도" |
| 다른 카드 버튼 | `OutlinedButton` | style: Button_Secondary, text: "다른 카드로 결제" |
| 고객센터 안내 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |
| 고객센터 링크 | `TextButton` | text: "고객센터 연결", color: primaryTeal |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 잔액 부족 | 사유: "카드 잔액이 부족합니다", 코드: PG-4001 |
| 카드 만료 | 사유: "카드 유효기간이 만료되었습니다", 코드: PG-4002, "다른 카드로 결제" 강조 |
| 한도 초과 | 사유: "카드 결제 한도를 초과했습니다", 코드: PG-4003 |
| 네트워크 오류 | 사유: "일시적인 네트워크 오류가 발생했습니다", 코드: NET-5001, "다시 시도" 강조 |
| PG사 오류 | 사유: "결제 시스템 점검 중입니다. 잠시 후 다시 시도해주세요.", 코드: PG-5000 |
| 알 수 없는 오류 | 사유: "알 수 없는 오류가 발생했습니다", 코드: UNKNOWN, 고객센터 링크 강조 (primaryCoral) |

**인터랙션**

- [탭] 다시 시도 → Navigator.pop → L-03 결제 확인 (동일 주문 정보로 재시도)
- [탭] 다른 카드로 결제 → Navigator.popUntil → L-02 결제 수단 (새 수단 선택)
- [탭] 고객센터 연결 → 외부 링크 (고객센터 URL) 또는 인앱 채팅 연결
- [탭] × (닫기) → Navigator.popUntil → L-01 (결제 플로우 전체 종료)
- [시스템 뒤로가기] → L-01 (결제 플로우 전체 종료)

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 10개 화면 (L-01 ~ L-10) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- DB 설계: `Master_docs/07_T2_DB_설계_및_관계_v3_4.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
