# SafeTrip 와이어프레임 문서 작성 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 104개 SafeTrip 화면의 와이어프레임을 15개 카테고리별 마크다운 파일 + 글로벌 스타일 가이드로 작성하여 Flutter 개발 가이드 겸 UX 흐름 검증 문서를 완성한다.

**Architecture:** 각 태스크는 하나의 카테고리 파일을 생성한다. 글로벌 스타일 가이드를 먼저 작성한 뒤, A→O 카테고리 순으로 진행한다. 각 파일은 카테고리 개요 + User Journey Flow + 외부 참조 테이블 + 화면별 5-섹션 템플릿(메타데이터/ASCII 레이아웃/컴포넌트 명세/상태 분기/인터랙션)으로 구성된다.

**Tech Stack:** Markdown (ASCII wireframes), Flutter Material 3 위젯 매핑, SafeTrip Design System (`docs/DESIGN.md`)

---

## 소스 문서 참조 매핑

각 태스크에서 읽어야 할 소스 문서를 사전 정의한다. **모든 태스크에서 공통으로 참조:**

| 문서 | 경로 | 용도 |
|------|------|------|
| 디자인 시스템 | `docs/DESIGN.md` | 색상/타이포/스페이싱/컴포넌트 토큰 |
| 화면 구성 원칙 | `Master_docs/10_T2_화면구성원칙.md` | 레이아웃 계층, 역할별 규칙, 바텀시트 |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` | 화면 정의 (ID/설명/Phase/역할) |
| Stitch 프롬프트 | `docs/plans/2026-03-03-screen-mockup-implementation.md` | 상세 UI 명세 (Stitch 프롬프트 → ASCII 변환) |
| 와이어프레임 설계 | `docs/plans/2026-03-03-wireframe-design.md` | 5-섹션 템플릿 정의, 파일 구조 |

---

## Task 0: 디렉토리 생성

**Files:**
- Create: `docs/wireframes/` (directory)

**Step 1: wireframes 디렉토리 생성**

```bash
mkdir -p docs/wireframes
```

**Step 2: 커밋**

```bash
git add docs/wireframes/.gitkeep 2>/dev/null || true
git commit --allow-empty -m "docs: create wireframes directory structure"
```

---

## Task 1: 글로벌 스타일 가이드 (`00_Global_Style_Guide.md`)

**Files:**
- Create: `docs/wireframes/00_Global_Style_Guide.md`
- Reference: `docs/DESIGN.md`, `Master_docs/10_T2_화면구성원칙.md`

**Step 1: 글로벌 스타일 가이드 작성**

`docs/DESIGN.md`의 토큰 정의와 `Master_docs/10_T2_화면구성원칙.md`의 레이아웃 계층을 통합하여 작성한다.

파일 구조:

```markdown
# SafeTrip 글로벌 스타일 가이드

> 이 문서는 모든 와이어프레임 문서에서 참조하는 공통 컴포넌트 사전이다.
> 디자인 토큰: `docs/DESIGN.md` | 화면 구성 원칙: `Master_docs/10_T2_화면구성원칙.md`

---

## 1. 레이아웃 기본값
(디바이스 390×844, AppBar 56dp, NavBar 60dp, Safe Area, 패딩 20px)

## 2. 공통 컴포넌트 사전
(25개 컴포넌트: AppBar, Button, Card, BottomSheet, NavBar, Input, Modal, Badge 등)
각 컴포넌트별: 이름 | Flutter 위젯 | 크기 | 색상 토큰 | 상태 목록 | ASCII 미리보기

## 3. 역할별 UI 매트릭스 (캡틴/크루장/크루/가디언)
(화면구성원칙 §6에서 추출)

## 4. 여행 상태별 UI 매트릭스 (none/planning/active/completed)
(화면구성원칙 §5에서 추출)

## 5. 프라이버시 등급별 UI 매트릭스 (안전최우선/표준/프라이버시우선)
(화면구성원칙 §7에서 추출)

## 6. 바텀시트 5단계 스냅 포인트
(DESIGN.md §5.2 + 바텀시트 동작 규칙에서 추출)

## 7. 색상 팔레트 빠른 참조
(DESIGN.md §1에서 핵심만 추출)

## 8. 타이포그래피 빠른 참조
(DESIGN.md §2에서 핵심만 추출)
```

**상세 작성 지침:**
- 섹션 2 컴포넌트 사전은 `docs/plans/2026-03-03-wireframe-design.md` §3.2 테이블을 기반으로 하되, 각 컴포넌트에 ASCII 미리보기를 추가한다:

```markdown
### Button_Primary
- **Flutter:** `ElevatedButton`
- **크기:** h:52, radius:12
- **색상:** `primaryTeal` (#00A2BD) bg, white text
- **상태:** enabled | disabled (gray) | loading (CircularProgressIndicator)
```

- 섹션 3~5 매트릭스는 `Master_docs/10_T2_화면구성원칙.md` §5, §6, §7에서 테이블을 직접 가져온다.

**Step 2: 구조 확인**

파일에 최소 8개 섹션이 있는지 확인:
```bash
grep -c "^## " docs/wireframes/00_Global_Style_Guide.md
# Expected: 8 이상
```

**Step 3: 커밋**

```bash
git add docs/wireframes/00_Global_Style_Guide.md
git commit -m "docs: add wireframe global style guide (25 components, 3 matrices)"
```

---

## Task 2: A. 온보딩 & 인증 (7개 화면)

**Files:**
- Create: `docs/wireframes/A_Onboarding_Auth.md`
- Reference: `Master_docs/14_T3_온보딩_UX_시나리오.md`
- Source: `screen-design-mockup-plan.md` §A, `screen-mockup-implementation.md` Task 1 (A-04, A-05, A-07 프롬프트)

**Step 1: 카테고리 파일 작성**

파일 구조:

```markdown
# A. 온보딩 & 인증

## 개요
- 화면 수: 7개 (A-01 ~ A-07)
- Phase: 전체 P0
- 핵심 역할: 신규 사용자 (크루/가디언 선택 전)
- 연관 문서: `Master_docs/14_T3_온보딩_UX_시나리오.md`

## User Journey Flow
A-01 Splash
 ├─ [토큰 유효] → C-01 메인맵
 └─ [첫 실행/만료] → A-02 온보딩
      → A-03 역할 선택
        ├─ [크루] → A-07 약관 → A-04 전화인증 → A-05 OTP → A-06 프로필 → C-01
        └─ [가디언] → A-07 약관 → A-04 전화인증 → A-05 OTP → A-06 프로필 → F-04

## 외부 진입/이탈 참조
| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| A-01 | 토큰 유효 | C-01 메인맵 | C |
| A-06 | 크루 완료 | C-01 메인맵 | C |
| A-06 | 가디언 완료 | F-04 가디언홈 | F |

## 화면 상세

### A-01 스플래시 (Splash)
(5-섹션 템플릿)

### A-02 웰컴 온보딩 (Welcome Onboarding)
(5-섹션 템플릿)

### A-03 역할 선택 (Role Selection)
(5-섹션 템플릿)

### A-04 전화번호 인증 (Phone Auth)
(5-섹션 템플릿 — screen-mockup-implementation.md Task 1 Step 1 프롬프트 기반)

### A-05 OTP 인증 (OTP Verify)
(5-섹션 템플릿 — screen-mockup-implementation.md Task 1 Step 2 프롬프트 기반)

### A-06 프로필 설정 (Profile Setup)
(5-섹션 템플릿)

### A-07 약관 동의 (Consent/Terms)
(5-섹션 템플릿 — screen-mockup-implementation.md Task 1 Step 3 프롬프트 기반)
```

**상세 작성 지침:**

A-04 예시 (다른 화면도 동일 패턴으로):

```markdown
### A-04 전화번호 인증 (Phone Auth)

**메타데이터**
| 항목 | 값 |
|------|-----|
| ID | A-04 |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | A-07 약관 동의 완료 → A-04 |
| 이탈 경로 | A-04 → A-05 (인증번호 발송 성공 시) |

**레이아웃**
┌─────────────────────────────┐
│ [←] 전화번호 인증              │ AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─ Country Picker ───────┐ │
│  │ 🇰🇷 +82        ▼       │ │ DropdownButtonFormField
│  └─────────────────────────┘ │
│                             │
│  ┌─ Phone Input ──────────┐ │
│  │ 전화번호                 │ │ TextFormField (phone)
│  └─────────────────────────┘ │
│                             │
│  SMS로 인증번호를 보내드립니다  │ bodyMedium, onSurfaceVariant
│                             │
│  ┌─────────────────────────┐ │
│  │     인증번호 받기         │ │ Button_Primary
│  └─────────────────────────┘ │
│                             │
│  서비스 이용약관에 동의합니다   │ bodySmall, onSurfaceVariant
└─────────────────────────────┘

**컴포넌트 명세**
| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | AppBar | title: "전화번호 인증", leading: BackButton |
| 국가코드 | DropdownButtonFormField | items: countryList, value: "+82" |
| 전화번호 | TextFormField | keyboardType: TextInputType.phone, validator: 필수 |
| 인증 버튼 | ElevatedButton | style: Button_Primary, enabled: 번호 유효시 |

**상태 분기**
| 상태 | UI 변화 |
|------|---------|
| 초기 | 버튼 비활성 (onSurfaceVariant 배경) |
| 번호 입력 완료 | 버튼 활성 (primaryTeal) |
| 발송 중 | 버튼 → CircularProgressIndicator |
| 발송 성공 | Navigator.push → A-05 |
| 발송 실패 | SnackBar "인증번호 발송에 실패했습니다. 다시 시도해주세요." |

**인터랙션**
- [탭] 국가코드 → BottomSheet 국가 목록 (국기+국가명+코드)
- [탭] 인증번호 받기 → POST /api/v1/auth/send-otp → 성공 시 A-05
- [뒤로가기] → A-07
```

**Step 2: 구조 확인**

```bash
grep -c "^### A-" docs/wireframes/A_Onboarding_Auth.md
# Expected: 7
```

**Step 3: 커밋**

```bash
git add docs/wireframes/A_Onboarding_Auth.md
git commit -m "docs: add wireframe A. Onboarding & Auth (7 screens)"
```

---

## Task 3: B. 여행 생성 & 참여 (8개 화면)

**Files:**
- Create: `docs/wireframes/B_Trip_Creation.md`
- Source: `screen-design-mockup-plan.md` §B, `screen-mockup-implementation.md` Task 2-3 (B-01~B-08 프롬프트)

**Step 1: 카테고리 파일 작성**

- 개요: 8개 화면, 전체 P0, 캡틴/크루
- User Journey Flow: B-01 → B-02/B-07 분기 → C-01 합류
- 화면 상세: B-01~B-08 각각 5-섹션 템플릿
- B-01~B-08 상세 UI는 `screen-mockup-implementation.md` Task 2~3의 Stitch 프롬프트를 ASCII로 변환

**Step 2: 구조 확인**

```bash
grep -c "^### B-" docs/wireframes/B_Trip_Creation.md
# Expected: 8
```

**Step 3: 커밋**

```bash
git add docs/wireframes/B_Trip_Creation.md
git commit -m "docs: add wireframe B. Trip Creation (8 screens)"
```

---

## Task 4: C. 메인 맵 & 공통 UI (12개 화면)

**Files:**
- Create: `docs/wireframes/C_MainMap_CommonUI.md`
- Reference: `Master_docs/17_T3_지도_기본화면_고유_원칙.md`
- Source: `screen-mockup-implementation.md` Task 4-5 (C-02~C-09 프롬프트)

**Step 1: 카테고리 파일 작성**

- 개요: 12개 화면, P0 10개 + P1 2개
- **특별 지시:** C-01 메인맵은 레이어 구조도(상단 오버레이/지도/바텀시트)를 별도 ASCII로 표현
- C-02 가디언 모드는 C-01과 차이점 비교 테이블 포함
- C-03~C-05는 컴포넌트 수준 와이어프레임 (독립 화면이 아님)
- 화면 상세: C-01~C-12 각각 5-섹션 템플릿

**Step 2: 구조 확인**

```bash
grep -c "^### C-" docs/wireframes/C_MainMap_CommonUI.md
# Expected: 12
```

**Step 3: 커밋**

```bash
git add docs/wireframes/C_MainMap_CommonUI.md
git commit -m "docs: add wireframe C. Main Map & Common UI (12 screens)"
```

---

## Task 5: D. 여행 관리 (16개 화면)

**Files:**
- Create: `docs/wireframes/D_Trip_Management.md`
- Reference: `Master_docs/18_T3_일정탭_원칙.md`, `Master_docs/19_T3_멤버탭_원칙.md`, `Master_docs/23_T3_초대코드_원칙.md`
- Source: `screen-mockup-implementation.md` Task 8-10 (D-02~D-13 프롬프트)

**Step 1: 카테고리 파일 작성**

- 개요: 16개 화면, P0 14개 + P1 2개
- **하위 도메인 구분:** 일정 (D-01~D-05), 장소 (D-06~D-08), 멤버 (D-09~D-13), 여행 상태 (D-14~D-16)
- 각 하위 도메인별 서브 User Journey Flow 포함
- 화면 상세: D-01~D-16 각각 5-섹션 템플릿

**Step 2: 구조 확인**

```bash
grep -c "^### D-" docs/wireframes/D_Trip_Management.md
# Expected: 16
```

**Step 3: 커밋**

```bash
git add docs/wireframes/D_Trip_Management.md
git commit -m "docs: add wireframe D. Trip Management (16 screens)"
```

---

## Task 6: E. 위치공유 & 프라이버시 (8개 화면)

**Files:**
- Create: `docs/wireframes/E_Location_Privacy.md`
- Source: `screen-design-mockup-plan.md` §E, `screen-mockup-implementation.md` Task 13-14

**Step 1: 카테고리 파일 작성**

- 개요: 8개 화면, P0 1개 + P1 7개
- 프라이버시 등급별 UI 차이를 각 화면에 명시
- E-08 지오펜스는 지도 위 폴리곤 시각화 ASCII 포함
- 화면 상세: E-01~E-08 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### E-" docs/wireframes/E_Location_Privacy.md  # Expected: 8
git add docs/wireframes/E_Location_Privacy.md
git commit -m "docs: add wireframe E. Location & Privacy (8 screens)"
```

---

## Task 7: F. 가디언 시스템 (10개 화면)

**Files:**
- Create: `docs/wireframes/F_Guardian_System.md`
- Source: `screen-mockup-implementation.md` Task 6-7 (F-01~F-07 프롬프트), Task 18 (F-08~F-10)

**Step 1: 카테고리 파일 작성**

- 개요: 10개 화면, P0 7개 + P1 3개
- **하위 도메인:** 연결&관리(F-01~F-03), 가디언모드(F-04~F-06), 긴급(F-07~F-09), 전체여행(F-10)
- 크루↔가디언 양측 흐름 모두 표현
- 화면 상세: F-01~F-10 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### F-" docs/wireframes/F_Guardian_System.md  # Expected: 10
git add docs/wireframes/F_Guardian_System.md
git commit -m "docs: add wireframe F. Guardian System (10 screens)"
```

---

## Task 8: G. SOS & 긴급 (5개 화면)

**Files:**
- Create: `docs/wireframes/G_SOS_Emergency.md`
- Reference: `Master_docs/13_T3_SOS_원칙.md`
- Source: `screen-mockup-implementation.md` Task 15 (G-03~G-05)

**Step 1: 카테고리 파일 작성**

- 개요: 5개 화면, P0 4개 + P1 1개
- **SOS 규칙 섹션**: `Master_docs/13_T3_SOS_원칙.md`에서 핵심 규칙을 인라인 참조
- G-01은 컴포넌트 수준 (56×56 버튼 + 2초 롱프레스 프로그레스 링)
- G-02는 전체화면 오버레이
- 화면 상세: G-01~G-05 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### G-" docs/wireframes/G_SOS_Emergency.md  # Expected: 5
git add docs/wireframes/G_SOS_Emergency.md
git commit -m "docs: add wireframe G. SOS & Emergency (5 screens)"
```

---

## Task 9: H. 출석 체크 (5개 화면)

**Files:**
- Create: `docs/wireframes/H_Attendance.md`
- Source: `screen-mockup-implementation.md` Task 15-16 (H-01~H-05)

**Step 1: 카테고리 파일 작성**

- 개요: 5개 화면, 전체 P1
- 역할별 분기: 캡틴/크루장(생성, 진행, 결과) vs 크루(응답) vs 가디언(결과 읽기전용)
- H-03 프로그레스는 원형 차트 ASCII 표현
- 화면 상세: H-01~H-05 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### H-" docs/wireframes/H_Attendance.md  # Expected: 5
git add docs/wireframes/H_Attendance.md
git commit -m "docs: add wireframe H. Attendance Check (5 screens)"
```

---

## Task 10: I. 채팅 & 커뮤니케이션 (5개 화면)

**Files:**
- Create: `docs/wireframes/I_Chat_Communication.md`
- Reference: `Master_docs/20_T3_채팅탭_원칙.md`

**Step 1: 카테고리 파일 작성**

- 개요: 5개 화면, P0 2개 + P1 2개 + P2 1개
- 메시지 버블 ASCII (본인/타인 구분, 시간, 읽음)
- 오프라인 상태 표현 (I-05)
- 화면 상세: I-01~I-05 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### I-" docs/wireframes/I_Chat_Communication.md  # Expected: 5
git add docs/wireframes/I_Chat_Communication.md
git commit -m "docs: add wireframe I. Chat & Communication (5 screens)"
```

---

## Task 11: J. 안전 가이드 (7개 화면)

**Files:**
- Create: `docs/wireframes/J_Safety_Guide.md`
- Reference: `Master_docs/21_T3_안전가이드_원칙.md`
- Source: `screen-mockup-implementation.md` Task 12 (J-01~J-06 프롬프트)

**Step 1: 카테고리 파일 작성**

- 개요: 7개 화면, P0 6개 + P1 1개
- J-01은 5개 서브탭 허브 화면 (개요/안전/입국/의료/긴급연락처)
- J-02~J-06는 각 서브탭 상세
- J-07은 국가 변경 (B-03 국가선택과 유사하되 바텀시트 모달)
- 화면 상세: J-01~J-07 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### J-" docs/wireframes/J_Safety_Guide.md  # Expected: 7
git add docs/wireframes/J_Safety_Guide.md
git commit -m "docs: add wireframe J. Safety Guide (7 screens)"
```

---

## Task 12: K. 설정 & 프로필 (8개 화면)

**Files:**
- Create: `docs/wireframes/K_Settings_Profile.md`
- Reference: `Master_docs/15_T3_설정_메뉴_원칙.md`, `Master_docs/27_T3_프로필화면_원칙.md`

**Step 1: 카테고리 파일 작성**

- 개요: 8개 화면, P0 3개 + P1 5개
- K-01 설정 메인은 섹션별 메뉴 리스트 (프로필/위치/알림/앱정보/계정)
- K-07~K-08 계정 삭제는 7일 유예 플로우 표현
- 화면 상세: K-01~K-08 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### K-" docs/wireframes/K_Settings_Profile.md  # Expected: 8
git add docs/wireframes/K_Settings_Profile.md
git commit -m "docs: add wireframe K. Settings & Profile (8 screens)"
```

---

## Task 13: L. 결제 & 구독 (10개 화면)

**Files:**
- Create: `docs/wireframes/L_Payment_Subscription.md`
- Reference: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` §09 (과금 체계)

**Step 1: 카테고리 파일 작성**

- 개요: 10개 화면, 전체 P2
- **하위 도메인:** 여행 요금(L-01~L-04), 가디언&애드온(L-05~L-07), 환불&내역(L-08~L-10)
- 비즈니스 원칙 §09의 요금 체계를 참조하여 요금표 테이블 포함
- 화면 상세: L-01~L-10 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### L-" docs/wireframes/L_Payment_Subscription.md  # Expected: 10
git add docs/wireframes/L_Payment_Subscription.md
git commit -m "docs: add wireframe L. Payment & Subscription (10 screens)"
```

---

## Task 14: M. 미성년자 보호 (4개 화면)

**Files:**
- Create: `docs/wireframes/M_Minor_Protection.md`
- Reference: `Master_docs/05_T0_SafeTrip_미성년자_보호_원칙_v1_0.md`

**Step 1: 카테고리 파일 작성**

- 개요: 4개 화면, 전체 P2
- 법적 요건(개인정보보호법 §22의2, 아동·청소년 보호법)을 명시
- 연령별 분기: 14세 미만(M-01 보호자 동의) vs 14~17세(M-02 이중 동의)
- 화면 상세: M-01~M-04 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### M-" docs/wireframes/M_Minor_Protection.md  # Expected: 4
git add docs/wireframes/M_Minor_Protection.md
git commit -m "docs: add wireframe M. Minor Protection (4 screens)"
```

---

## Task 15: N. B2B 관리자 포털 (8개 화면)

**Files:**
- Create: `docs/wireframes/N_B2B_Portal.md`
- Reference: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` §10 (B2B 체계)

**Step 1: 카테고리 파일 작성**

- 개요: 8개 화면, 전체 P3
- **특별 지시:** B2B는 웹 앱 가능성이 있으므로 데스크톱 레이아웃(1280×900) + 모바일(390×844) 양쪽 ASCII 제공
- N-01 대시보드는 통계 카드 그리드 레이아웃
- 화면 상세: N-01~N-08 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### N-" docs/wireframes/N_B2B_Portal.md  # Expected: 8
git add docs/wireframes/N_B2B_Portal.md
git commit -m "docs: add wireframe N. B2B Portal (8 screens)"
```

---

## Task 16: O. AI 기능 (5개 화면)

**Files:**
- Create: `docs/wireframes/O_AI_Features.md`
- Reference: `Master_docs/26_T3_AI_기능_원칙.md`

**Step 1: 카테고리 파일 작성**

- 개요: 5개 화면, P2 3개 + P3 2개
- AI Plus/Pro 요금제에 따른 기능 잠금 UI 포함
- O-04 AI 브리핑은 카드 레이아웃 (날씨/안전지수/주의/추천)
- O-05 일정 최적화는 지도 경로 비교 ASCII
- 화면 상세: O-01~O-05 각각 5-섹션 템플릿

**Step 2/3: 확인 & 커밋**

```bash
grep -c "^### O-" docs/wireframes/O_AI_Features.md  # Expected: 5
git add docs/wireframes/O_AI_Features.md
git commit -m "docs: add wireframe O. AI Features (5 screens)"
```

---

## Task 17: 최종 검증 및 인덱스

**Files:**
- Verify: `docs/wireframes/` 내 16개 파일 존재 확인
- 총 화면 수 카운트

**Step 1: 전체 파일 확인**

```bash
ls docs/wireframes/*.md | wc -l
# Expected: 16

# 전체 화면 수 카운트 (### X-NN 패턴)
grep -c "^### [A-O]-" docs/wireframes/[A-O]_*.md | awk -F: '{sum+=$2} END {print sum}'
# Expected: 104 이상
```

**Step 2: 각 파일별 화면 수 확인**

```bash
for f in docs/wireframes/[A-O]_*.md; do
  count=$(grep -c "^### [A-O]-" "$f")
  echo "$(basename $f): $count screens"
done
```

Expected output:
```
A_Onboarding_Auth.md: 7 screens
B_Trip_Creation.md: 8 screens
C_MainMap_CommonUI.md: 12 screens
D_Trip_Management.md: 16 screens
E_Location_Privacy.md: 8 screens
F_Guardian_System.md: 10 screens
G_SOS_Emergency.md: 5 screens
H_Attendance.md: 5 screens
I_Chat_Communication.md: 5 screens
J_Safety_Guide.md: 7 screens
K_Settings_Profile.md: 8 screens
L_Payment_Subscription.md: 10 screens
M_Minor_Protection.md: 4 screens
N_B2B_Portal.md: 8 screens
O_AI_Features.md: 5 screens
```

**Step 3: 최종 커밋 (필요시)**

```bash
git add docs/wireframes/
git commit -m "docs: complete all 104 wireframe screens across 16 files"
```

---

## 요약

| Task | 파일 | 화면 수 | 참조 Master_docs |
|:----:|------|:------:|-----------------|
| 0 | (디렉토리) | — | — |
| 1 | `00_Global_Style_Guide.md` | — | 10_화면구성원칙 |
| 2 | `A_Onboarding_Auth.md` | 7 | 14_온보딩_UX |
| 3 | `B_Trip_Creation.md` | 8 | — |
| 4 | `C_MainMap_CommonUI.md` | 12 | 17_지도_기본화면 |
| 5 | `D_Trip_Management.md` | 16 | 18_일정탭, 19_멤버탭, 23_초대코드 |
| 6 | `E_Location_Privacy.md` | 8 | — |
| 7 | `F_Guardian_System.md` | 10 | — |
| 8 | `G_SOS_Emergency.md` | 5 | 13_SOS_원칙 |
| 9 | `H_Attendance.md` | 5 | — |
| 10 | `I_Chat_Communication.md` | 5 | 20_채팅탭 |
| 11 | `J_Safety_Guide.md` | 7 | 21_안전가이드 |
| 12 | `K_Settings_Profile.md` | 8 | 15_설정_메뉴, 27_프로필 |
| 13 | `L_Payment_Subscription.md` | 10 | 01_비즈니스_원칙 §09 |
| 14 | `M_Minor_Protection.md` | 4 | 05_미성년자_보호 |
| 15 | `N_B2B_Portal.md` | 8 | 01_비즈니스_원칙 §10 |
| 16 | `O_AI_Features.md` | 5 | 26_AI_기능 |
| 17 | (검증) | — | — |
| **합계** | **16 파일** | **118** | |
