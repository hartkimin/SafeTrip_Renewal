# SafeTrip 디자인 목업 생성 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Stitch API를 사용하여 SafeTrip 앱의 89개 신규 화면 목업을 생성하고, 기존 21개 화면과 통합된 디자인 시스템을 완성한다.

**Architecture:** Stitch `generate_screen_from_text` API로 화면을 배치 생성한다. 각 배치는 동일한 User Journey 플로우에 속하는 3-5개 화면으로 구성되어 시각적 일관성을 확보한다. 생성 후 screen ID를 `docs/design/stitch-prompts.md`에 기록하고 커밋한다.

**Tech Stack:** Stitch MCP (generate_screen_from_text, list_screens), Project ID: `1860278016444342994`, Device: MOBILE

---

## 기존 Stitch 화면 매핑 (21개 생성됨 → 15개 고유 화면)

| 화면 ID | Stitch Screen ID | Stitch Title |
|---------|-----------------|--------------|
| A-01 | `45f8d678ff754e70af3e26402af2844c` | Splash Screen |
| A-02 | `e3636a6af4a04904b975e4debebf03c3` | Onboarding Screen |
| A-03 | `898b5d8123444e08b27dbd0e5747679b` | Role Selection Screen |
| A-06 | `0f2652a3fc4b4c6d98837a0d3aabf2ef` | Profile Setup Screen |
| B-02 | `89b2b832fb5141528f5ddfc5dcc9d865` | Create Trip Form |
| C-01 | `68a428dc0232412a83defd86ec09a776` | Main Map View |
| D-01 | `ddf72a4582c54f3ead3f8cb45d8201db` | Daily Schedule View |
| D-09 | `3d583bb4a2e446e38900649f53a9b4a6` | Member List View |
| D-10 | `71a3ae9116b5497d897743f70757a6b5` | Invite Code Screen |
| F-04 | `772d95b3bd67495bb3df3a261436ce20` | Guardian Home Screen |
| F-06 | `d6a8f571babd4b1b87816cbe51f05f90` | Guardian-Member Chat |
| G-02 | `5a6e36cbb1d64c24be6ab7bec3fac708` | SOS Emergency Screen |
| J-01 | `579897452d46403e8da7d298ebf47007` | Safety Guide Screen |
| K-01 | `54cdf9a6ee67430ea21ee892ba28905e` | Settings Screen |
| K-02 | `767baf3d42684cac83afe1a74777028a` | User Profile Screen |

> 추가 6개는 위 화면들의 variant/duplicate (Main Map ×2, Member Tab, Guardian Dashboard, Profile Details, Safety Guide View)

---

## 공통 디자인 시스템 프롬프트 프리픽스

모든 Stitch 프롬프트 앞에 아래 디자인 시스템 지시문을 붙인다:

```
DESIGN SYSTEM: SafeTrip travel safety app. Mobile (390×844).
COLORS: Primary teal #00A2BD, coral accent #FF807B, amber warning #FFC363, beige bg #F2EDE4.
Role colors: Captain #00A2BD, Crew Chief #015572, Crew #898989, Guardian #15A1A5.
Privacy: Safety First #DA4C51, Standard #00A2BD, Privacy First #A7A7A7.
SOS: #D32F2F (always).
TYPOGRAPHY: Plus Jakarta Sans. Headings semibold, body regular.
COMPONENTS: Buttons 52px height radius 12px. Cards radius 16px shadow 4% black. Bottom sheet top radius 20px.
STYLE: Clean, modern, minimal. White backgrounds, subtle shadows. Teal primary actions.
```

---

## Round 1: 핵심 User Journey (18개 신규 화면)

### Task 1: 인증 플로우 완성 (A-04, A-05, A-07)

**Files:**
- Update: `docs/design/stitch-prompts.md` — 신규 screen ID 추가
- Reference: `docs/DESIGN.md` — 디자인 시스템

**Step 1: A-04 전화번호 인증 화면 생성**

Stitch 프롬프트:
```
[DESIGN SYSTEM PREFIX]

Phone number authentication screen for SafeTrip travel safety app.

TOP: Back arrow + "Phone Verification" title.
CONTENT:
- Country code selector dropdown (showing 🇰🇷 +82 default) with chevron
- Phone number input field with placeholder "Phone number"
- Helper text: "We'll send you a verification code via SMS"
- Primary button "Send Code" (teal #00A2BD, full width, 52px height, radius 12px)

BOTTOM: "By continuing, you agree to our Terms of Service" subtle text.

Clean white background, single-purpose screen, no distractions.
Korean labels preferred: "전화번호 인증", "인증번호 받기"
```

Run: `mcp__stitch__generate_screen_from_text` with projectId `1860278016444342994`, deviceType `MOBILE`

**Step 2: A-05 OTP 인증 화면 생성**

Stitch 프롬프트:
```
[DESIGN SYSTEM PREFIX]

OTP verification screen for SafeTrip.

TOP: Back arrow + "Verify Code" title + subtitle "Code sent to +82 10-****-1234"
CONTENT:
- 6 individual digit input boxes in a row (each 48×56px, radius 8px, border #EDEDED)
- Active box highlighted with teal #00A2BD border
- Timer showing "2:45" in coral #FF807B below the boxes
- "Didn't receive the code?" text + "Resend" teal link button
- Primary button "Verify" (teal, full width, 52px)

Clean white background.
Korean: "인증번호 입력", "인증하기", "재전송"
```

Run: `mcp__stitch__generate_screen_from_text`

**Step 3: A-07 약관 동의 화면 생성**

Stitch 프롬프트:
```
[DESIGN SYSTEM PREFIX]

Terms and consent agreement screen for SafeTrip.

TOP: "약관 동의" title centered.
CONTENT:
- "전체 동의" master checkbox with teal checkmark, bold text, top card
- Divider line
- Required items (each with checkbox + expand arrow):
  1. "[필수] 서비스 이용약관" with right arrow to view full text
  2. "[필수] 개인정보 처리방침" with right arrow
  3. "[필수] 위치정보 이용약관" with right arrow
- Optional item:
  4. "[선택] 마케팅 수신 동의" with right arrow
- Each checkbox: unchecked = gray circle, checked = teal filled circle with white checkmark

BOTTOM (fixed):
- Primary button "동의하고 시작하기" (teal, full width, 52px)
- Button disabled (gray) until all required items checked

Clean white background, clear hierarchy between required and optional.
```

Run: `mcp__stitch__generate_screen_from_text`

**Step 4: 생성된 화면 확인**

Run: `mcp__stitch__list_screens` with projectId `1860278016444342994`
Expected: 3 new screens with titles containing phone/OTP/consent

**Step 5: stitch-prompts.md에 screen ID 기록 & 커밋**

```bash
# stitch-prompts.md 업데이트 후
git add docs/design/stitch-prompts.md
git commit -m "design: add auth flow screens (A-04, A-05, A-07)"
```

---

### Task 2: 여행 없음 + 여행 생성 전반부 (B-01, B-03, B-04)

**Step 1: B-01 여행 없음 홈 화면 생성**

```
[DESIGN SYSTEM PREFIX]

"No trip" home screen for SafeTrip - shown when user has no active trips.

TOP BAR: SafeTrip logo (teal) left + notification bell icon right + settings gear right.
MAP AREA: Full-screen map background (OpenStreetMap style, showing user's current city).
No member markers visible.

OVERLAY (center of screen):
- Semi-transparent card (white, radius 16px, shadow):
  - Illustration/icon of a suitcase or globe
  - "여행을 시작해보세요" heading (20px semibold)
  - "새 여행을 만들거나 초대코드로 참여하세요" subtitle (14px gray)
  - Two buttons side by side:
    - "여행 만들기" (teal filled, primary)
    - "코드 입력" (teal outlined, secondary)

BOTTOM: Tab bar with 4 tabs. Only "안전가이드 📖" tab is active/teal.
Other tabs (일정, 멤버, 채팅) are grayed out with lock icon.
```

**Step 2: B-03 국가 선택 화면 생성**

```
[DESIGN SYSTEM PREFIX]

Country picker bottom sheet for SafeTrip trip creation.

HEADER: "국가 선택" title + close X button.
SEARCH: Search input field with magnifying glass icon, placeholder "국가명 검색" (supports Korean consonant search).

RECENT SECTION:
- "최근 선택" label (12px gray)
- Horizontal chips: 🇯🇵 일본, 🇹🇭 태국, 🇻🇳 베트남

COUNTRY LIST (scrollable):
- Each row: Flag emoji (24px) + Country name (Korean) + Country name (English, gray 12px)
- Examples: 🇯🇵 일본 Japan, 🇰🇷 대한민국 South Korea, 🇹🇭 태국 Thailand, 🇺🇸 미국 USA
- Right side: checkmark for selected country (teal)
- Alphabetical section headers (ㄱ, ㄴ, ㄷ... for Korean)

White background, bottom sheet style with top radius 20px and drag handle.
```

**Step 3: B-04 프라이버시 등급 선택 화면 생성**

```
[DESIGN SYSTEM PREFIX]

Privacy level selection screen during SafeTrip trip creation.

TOP: Back arrow + step indicator "2/4" + "프라이버시 등급" title.
SUBTITLE: "여행 참여자의 위치 공유 정책을 선택하세요" (14px gray).

THREE CARDS (vertical, selectable):

1. SAFETY FIRST CARD (red-tinted border #DA4C51):
   - 🛡️ icon + "안전 최우선" title (bold)
   - "미성년자, 학교 단체, 어학연수"
   - Bullet: "가디언 24시간 실시간 접근"
   - Bullet: "멤버 일시정지 불가"
   - Recommended badge for minor groups

2. STANDARD CARD (teal border #00A2BD, pre-selected with teal checkmark):
   - 📍 icon + "표준" title (bold)
   - "일반 단체, 가족 여행"
   - Bullet: "ON 시간 실시간, OFF 시간 30분 스냅샷"
   - Bullet: "최대 12시간 일시정지"

3. PRIVACY FIRST CARD (gray border #A7A7A7):
   - 🔒 icon + "프라이버시 우선" title (bold)
   - "비즈니스 출장, 성인 투어"
   - Bullet: "ON 시간만 실시간, OFF 시간 비공개"
   - Bullet: "최대 24시간 일시정지"

BOTTOM: "다음" primary button (teal, full width).

Cards: white bg, radius 16px, shadow. Selected card has colored left border + checkmark.
```

**Step 4: 생성 확인 & 기록**

Run: `mcp__stitch__list_screens`, 기록, 커밋

```bash
git add docs/design/stitch-prompts.md
git commit -m "design: add no-trip home, country picker, privacy select (B-01, B-03, B-04)"
```

---

### Task 3: 여행 생성 후반부 (B-05, B-06, B-07, B-08)

**Step 1: B-05 위치공유 모드 선택**

```
[DESIGN SYSTEM PREFIX]

Location sharing mode selection during SafeTrip trip creation.

TOP: Back arrow + step "3/4" + "위치공유 모드" title.
SUBTITLE: "멤버들의 위치 공유 방식을 선택하세요"

TWO CARDS (vertical, large, selectable):

1. FORCED SHARING (selected, teal border):
   - Icon: chain link or lock
   - "강제 공유" title (bold 18px)
   - "캡틴이 설정한 스케줄을 모든 멤버가 따릅니다"
   - Pros (teal bullets): "통일된 관리", "간편한 설정"
   - Tag: "단체 여행 추천" (teal chip)

2. FREE SETTING:
   - Icon: unlock or person
   - "자유 설정" title (bold 18px)
   - "각 멤버가 자신의 공유 스케줄과 가시범위를 설정합니다"
   - Pros: "개인 프라이버시 존중", "유연한 설정"
   - Tag: "소규모/성인 여행 추천" (gray chip)

BOTTOM: "다음" primary button (teal, full width).
```

**Step 2: B-06 여행 확인**

```
[DESIGN SYSTEM PREFIX]

Trip confirmation/summary screen before final creation in SafeTrip.

TOP: Back arrow + "여행 확인" title.

SUMMARY CARD (white, radius 16px, shadow):
- 🇯🇵 Flag + "도쿄 자유여행" trip name (bold 20px)
- Row: 📅 "2026.03.15 ~ 2026.03.22" (8일)
- Row: 📍 "일본, 도쿄"
- Row: 🛡️ "표준" privacy level (teal badge)
- Row: 🔗 "강제 공유" sharing mode
- Row: 👤 "개인 여행" trip type

DIVIDER

INFO NOTICE (beige #F2EDE4 background card):
- "💡 여행 생성 후 초대코드로 멤버를 초대할 수 있습니다"

PRICING NOTICE (if applicable, hidden for <6 members):
- "6명 이상 참여 시 9,900원이 발생합니다"

BOTTOM: "여행 만들기" primary button (teal, full width, 52px).
```

**Step 3: B-07 초대코드 입력**

```
[DESIGN SYSTEM PREFIX]

Join trip by invite code screen in SafeTrip.

TOP: Back arrow + "여행 참여" title.

CENTER:
- Illustration: Group of people with location pins
- "초대코드를 입력하세요" heading (20px semibold)
- "캡틴에게 받은 6자리 코드를 입력해주세요" subtitle (14px gray)

CODE INPUT:
- 6 individual character boxes (each 48×56px, uppercase, monospace font)
- Boxes: white bg, radius 8px, border #EDEDED, active = teal border
- Auto-advance to next box on input

BOTTOM:
- "참여하기" primary button (teal, full width)
- "QR 코드로 참여" text link below (teal, with camera icon)

Korean text. Clean white background.
```

**Step 4: B-08 여행 미리보기**

```
[DESIGN SYSTEM PREFIX]

Trip preview screen shown after entering invite code in SafeTrip. User sees trip details before joining.

CARD (centered, white, radius 16px, large shadow):
- 🇯🇵 Flag large (48px) at top
- "도쿄 자유여행" trip name (bold 24px)
- Divider
- Row: 📅 "2026.03.15 ~ 2026.03.22"
- Row: 👤 Captain: "김철수" (with small avatar)
- Row: 👥 "현재 5명 참여 중"
- Row: 🛡️ Privacy: "표준" (teal badge)

BOTTOM OF CARD:
- "참여하기" primary button (teal, full width)
- "취소" secondary text button below

Background: subtle gradient or blurred map.
```

**Step 5: 확인 & 커밋**

```bash
git add docs/design/stitch-prompts.md
git commit -m "design: add trip creation flow (B-05, B-06, B-07, B-08)"
```

---

### Task 4: 메인 맵 핵심 컴포넌트 (C-02, C-03, C-04, C-05)

**Step 1: C-02 메인 맵 가디언 모드**

```
[DESIGN SYSTEM PREFIX]

Main map screen in GUARDIAN MODE for SafeTrip. Guardian sees only their connected members on the map.

TOP BAR: "SafeTrip" logo + 🔔 notification + ⚙️ settings.
No privacy level icon. No SOS button visible.

MAP: Full screen map (OpenStreetMap style) showing:
- 2 member markers only (connected members):
  - "김민지" with avatar, green #15A1A5 ring (guardian color)
  - "이준호" with avatar, green ring
- Each marker shows last-update timestamp: "3분 전"
- Other trip members NOT visible (grayed out or hidden)

BOTTOM: 3-tab navigation bar (NOT 4 tabs):
- 👥 내 멤버 (active, teal)
- 📅 일정
- 📖 안전가이드
NO SOS button. NO chat tab.

BOTTOM SHEET (collapsed, 18%):
- "내 멤버" tab active
- 2 member cards showing name, last location, status

Guardian-specific green accent color #15A1A5 for active elements.
```

**Step 2: C-03 맵 상단바 컴포넌트**

```
[DESIGN SYSTEM PREFIX]

Map top bar component detail view for SafeTrip. Show the top overlay on the map screen.

FULL WIDTH transparent overlay on map:
LEFT: 🔔 notification bell icon (with red dot badge if unread)
CENTER:
- Trip name "도쿄 자유여행" (16px semibold, white text with shadow for readability on map)
- Below: "D+3" day counter badge (teal pill shape, white text, 11px)
- Below trip name: Privacy icon 📍 "표준" (small, only visible to captain/crew chief)
RIGHT: ⚙️ settings gear icon

Show this overlaid on a map background to demonstrate readability.
White icons with drop shadow for contrast against map tiles.

Show TWO variants:
1. Captain view: with privacy icon + sharing mode visible
2. Crew view: without privacy/sharing indicators
```

**Step 3: C-04 바텀 네비게이션 (크루)**

```
[DESIGN SYSTEM PREFIX]

Bottom navigation bar for CREW mode in SafeTrip. Sits at the bottom of the main map screen.

NAVIGATION BAR (white background, top border #EDEDED):
4 tabs equally spaced:
1. 📅 일정 (gray when inactive)
2. 👥 멤버 (active = teal #00A2BD icon + text, with red dot badge for pending attendance)
3. 💬 채팅 (gray, with unread count badge "3" in coral #FF807B)
4. 📖 가이드 (gray)

SOS BUTTON: Floating above the nav bar, bottom-right corner.
- Red circle #D32F2F, 56×56dp
- "SOS" white bold text centered
- Elevated shadow (4dp)
- Positioned above the tab bar, overlapping slightly

Show the nav bar with bottom sheet handle (drag indicator, 44×4px gray pill) above it.
Tab labels in Korean.
```

**Step 4: C-05 바텀 네비게이션 (가디언)**

```
[DESIGN SYSTEM PREFIX]

Bottom navigation bar for GUARDIAN MODE in SafeTrip. Different from crew mode.

NAVIGATION BAR (white background):
3 tabs (NOT 4 - no chat tab):
1. 👥 내 멤버 (active = green #15A1A5)
2. 📅 일정 (gray)
3. 📖 안전가이드 (gray)

NO SOS BUTTON. Guardians cannot send SOS.

Accent color is #15A1A5 (guardian green) instead of #00A2BD (crew teal).
Bottom sheet handle visible above.
Tab labels in Korean.

Show side-by-side comparison with crew nav if possible, to highlight the differences:
- 3 tabs vs 4 tabs
- No SOS button
- Green accent vs teal accent
```

**Step 5: 확인 & 커밋**

```bash
git add docs/design/stitch-prompts.md
git commit -m "design: add main map components (C-02, C-03, C-04, C-05)"
```

---

### Task 5: 메인 맵 지원 화면 (C-06, C-07, C-08, C-09)

**Step 1: C-06 여행 전환 모달**

```
[DESIGN SYSTEM PREFIX]

Trip switch modal in SafeTrip. Shown when user taps the trip name to switch between their trips.

MODAL (bottom sheet, radius 20px top):
HEADER: "내 여행" title + close X button.

TRIP LIST (scrollable):
Each trip card (white, radius 12px, border):
1. ACTIVE (highlighted with teal left border):
   - 🇯🇵 "도쿄 자유여행" (bold)
   - "2026.03.15 ~ 03.22" | "D+3"
   - Green badge "진행 중"
   - Checkmark icon (currently selected)

2. PLANNING:
   - 🇹🇭 "방콕 팀 워크숍"
   - "2026.04.01 ~ 04.05" | "D-29"
   - Amber badge "계획 중"

3. COMPLETED:
   - 🇻🇳 "다낭 가족여행"
   - "2026.02.10 ~ 02.15"
   - Gray badge "완료"
   - Subtle opacity reduction

Tap a trip to switch. Currently selected trip has checkmark.
```

**Step 2: C-07 알림 목록**

```
[DESIGN SYSTEM PREFIX]

Notification list screen for SafeTrip. Shows push notification history.

TOP: Back arrow + "알림" title + "모두 읽음" text button (teal, right).

NOTIFICATION LIST (scrollable, grouped by date):

"오늘" section header:
1. 🆘 SOS notification (red left border):
   - "김민지님이 SOS를 발송했습니다"
   - "서울 강남구 역삼동" location
   - "2분 전" timestamp, unread (bold + blue dot)

2. ✅ Attendance:
   - "출석 체크가 시작되었습니다"
   - "마감: 15:00까지"
   - "35분 전"

3. 📍 Geofence:
   - "이준호님이 호텔 지오펜스를 벗어났습니다"
   - "1시간 전"

"어제" section:
4. 🛡️ Guardian:
   - "새로운 가디언 연결 요청이 있습니다"
   - "어제 18:30"

5. 💬 Chat:
   - "그룹 채팅에 새 메시지 3건"
   - "어제 14:22"

Each notification: avatar/icon left, text center, timestamp right.
Unread items have bold text and blue dot indicator.
White background, subtle dividers between items.
```

**Step 3: C-08 권한 요청**

```
[DESIGN SYSTEM PREFIX]

Permission request screen for SafeTrip. Explains why each permission is needed.

TOP: SafeTrip logo + "앱 권한 설정" title.
SUBTITLE: "SafeTrip이 안전하게 작동하려면 아래 권한이 필요합니다"

PERMISSION CARDS (vertical stack, each with icon + explanation):

1. LOCATION (most important, highlighted card):
   - 📍 Large icon in teal circle
   - "위치 권한 (항상 허용)" title (bold)
   - "백그라운드에서도 위치를 공유하여 동행자의 안전을 지킵니다"
   - Status: ✅ "허용됨" green OR ⚠️ "설정 필요" amber button

2. NOTIFICATION:
   - 🔔 Icon in teal circle
   - "알림 권한"
   - "SOS, 출석체크, 긴급 알림을 받으려면 필요합니다"
   - Status toggle

3. BATTERY:
   - 🔋 Icon in teal circle
   - "배터리 최적화 해제"
   - "백그라운드 위치 추적이 중단되지 않도록 합니다"
   - Status toggle

BOTTOM: "계속하기" primary button (teal). Disabled if location not granted.
Warning text: "위치 권한 없이는 핵심 기능을 사용할 수 없습니다" (red, only if location denied)
```

**Step 4: C-09 데모 모드**

```
[DESIGN SYSTEM PREFIX]

Demo mode of SafeTrip main map. Shows simulated data for first-time users to explore.

Same layout as main map (C-01) but with demo overlays:

TOP BANNER (amber #FFC363 background, full width):
- "🎮 체험 모드 — 실제 데이터가 아닙니다" white text, 12px
- "닫기" X button right

MAP: Shows 5 simulated member markers with fake names and locations (Tokyo area):
- "Demo 김철수" (Captain, teal ring)
- "Demo 이영희" (Crew, gray ring)
- "Demo 박지수" (Crew, gray ring)
- Simulated geofence polygon (transparent teal overlay)

BOTTOM SHEET (half state):
- Schedule tab showing sample events
- "시부야 쇼핑" 10:00-12:00
- "센소지 관광" 14:00-16:00

SOS BUTTON: Present but with "(체험)" label below

COACHING OVERLAY (first time):
- Spotlight on SOS button with tooltip arrow: "SOS 버튼을 2초 누르면 긴급 신호를 보냅니다"
```

**Step 5: 확인 & 커밋**

```bash
git add docs/design/stitch-prompts.md
git commit -m "design: add trip switch, notifications, permissions, demo (C-06~C-09)"
```

---

## Round 2: 가디언 + 주요 기능 (25개 신규 화면)

### Task 6: 가디언 연결 플로우 (F-01, F-02, F-03)

**Step 1: F-01 가디언 추가**

```
[DESIGN SYSTEM PREFIX]

Add guardian screen in SafeTrip. Member adds a guardian (protector) to their trip.

TOP: Back arrow + "가디언 추가" title.

SLOT INDICATOR (top card, beige bg):
- "가디언 슬롯" heading
- Visual: 5 circles in a row
  - Circles 1-2: Filled teal (free, "무료")
  - Circles 3-5: Empty with "₩" icon (paid, "1,900원/인")
- "현재 1/5명 연결됨" text

FORM:
- Phone number input with country code selector (+82)
- "가디언에게 연결 요청을 보냅니다" helper text
- Optional message field: "메시지 (선택)"

INFO CARD (beige bg, light):
- "가디언은 회원님의 위치를 확인하고 긴급 시 알림을 보낼 수 있습니다"
- "프라이버시 등급에 따라 접근 범위가 달라집니다"

BOTTOM: "연결 요청 보내기" primary button (teal).
```

**Step 2: F-02 가디언 관리**

```
[DESIGN SYSTEM PREFIX]

Guardian management screen in SafeTrip. Shows list of connected guardians.

TOP: Back arrow + "가디언 관리" title.

SECTION: "전체여행 가디언" (2 slots, labeled "캡틴이 지정"):
- Card 1: "박부모" avatar + name + "연결됨" green badge + "해제" red text button
- Card 2: Empty slot with "+" dashed border "추가하기"

SECTION: "내 가디언" (5 slots total, 2 free + 3 paid):
- Card 1: "김보호자" + "연결됨" green badge + phone icon + "해제"
- Card 2: Empty "무료 슬롯" with "+"
- Card 3: "이안전" + "대기 중" amber badge (pending approval)
- Card 4-5: Empty "유료 슬롯 ₩1,900" with lock icon

STATUS LEGEND (bottom):
- 🟢 연결됨 | 🟡 대기 중 | 🔴 거절됨

Each guardian card shows: avatar, name, status badge, action button (release/cancel).
```

**Step 3: F-03 가디언 링크 승인**

```
[DESIGN SYSTEM PREFIX]

Guardian link approval screen. Shown to a guardian when they receive a connection request from a trip member.

FULL SCREEN CARD (centered):

TOP: SafeTrip logo + "가디언 연결 요청" heading.

REQUEST CARD (white, radius 16px, shadow):
- Requester avatar (large, 64px) centered
- "김민지님이 가디언 연결을 요청합니다" (bold 18px)
- Divider
- Trip info:
  - 🇯🇵 "도쿄 자유여행"
  - "2026.03.15 ~ 03.22"
  - 🛡️ "표준" privacy level badge
- "메시지: 엄마, 여행 중 위치 확인 부탁드려요" (gray italic)

BOTTOM ACTIONS (two buttons, full width):
- "수락" primary button (teal #00A2BD)
- "거절" secondary button (outlined, gray)

Info text: "수락하면 프라이버시 등급에 따라 멤버의 위치를 확인할 수 있습니다"
```

**Step 4: 확인 & 커밋**

```bash
git commit -m "design: add guardian connection flow (F-01, F-02, F-03)"
```

---

### Task 7: 가디언 상세 + 긴급 (F-05, F-07)

**Step 1: F-05 가디언 멤버 상세**

```
[DESIGN SYSTEM PREFIX]

Guardian's view of a connected member's detail in SafeTrip. Shows member location on map with limited info based on privacy level.

TOP: Back arrow + member name "김민지" + role badge "크루".

MAP (top 50% of screen):
- Member's location marker with avatar (green #15A1A5 ring)
- Last known position with accuracy circle
- Route/path trace if available (dotted teal line)

DETAIL CARD (bottom 50%, scrollable):
- "마지막 업데이트: 3분 전" timestamp
- Location: "도쿄 시부야구 진구마에"
- Status: 🟢 "위치 공유 중" green badge
- Privacy level: 📍 "표준" info (read-only)

ACTION BUTTONS:
- "긴급 알림 보내기" (coral #FF807B button, with ⚠️ icon)
- "위치 요청" (outlined teal button, with 📍 icon)
- "메시지 보내기" (outlined teal, with 💬 icon)

Footer: "시간당 위치 요청 3회 제한 | 남은 횟수: 2회"
```

**Step 2: F-07 가디언 긴급 알림 발송**

```
[DESIGN SYSTEM PREFIX]

Guardian emergency alert sending screen in SafeTrip.

TOP: Back arrow + "긴급 알림" title (coral #FF807B text).

ALERT CARD (coral-tinted border):
- ⚠️ Large warning icon (coral)
- "김민지님에게 긴급 알림을 보냅니다" (bold 18px)
- "이 알림은 멤버와 해당 멤버의 캡틴/크루장에게 전달됩니다"

MESSAGE INPUT:
- Multiline text field (4 lines visible)
- Placeholder: "긴급 상황을 설명해주세요 (선택)"
- Character count "0/200"

RECIPIENTS PREVIEW:
- 수신자: "김민지 (크루), 이캡틴 (캡틴)"
- Avatar row showing recipients

BOTTOM:
- "긴급 알림 보내기" button (coral #FF807B background, white text, full width)
- "취소" text button below

Warning: "긴급 상황이 아닌 경우 사용을 자제해주세요"
```

**Step 3: 확인 & 커밋**

```bash
git commit -m "design: add guardian detail and emergency alert (F-05, F-07)"
```

---

### Task 8: 일정 모달 (D-02, D-03, D-05)

**Step 1: D-02 일정 추가 모달**

```
[DESIGN SYSTEM PREFIX]

Add schedule/event modal in SafeTrip. Captain/crew chief creates a new schedule item.

MODAL (bottom sheet, tall state 55%):
HEADER: "일정 추가" + close X.

FORM FIELDS:
- "제목" text input (placeholder: "일정 이름을 입력하세요")
- "날짜" date picker (showing "2026.03.17 (수)")
- Time row:
  - "시작" time picker "10:00"
  - "~" divider
  - "종료" time picker "12:00"
  - Toggle: "종일" switch (if on, hides time pickers)
- "장소" input with 📍 icon + "장소 검색" placeholder (tappable, opens place search)
- "메모" multiline text (placeholder: "추가 메모", optional)

BOTTOM: "추가하기" primary button (teal, full width).

Clean white modal, input fields with subtle gray borders radius 8px.
```

**Step 2: D-03 일정 직접 입력**

```
[DESIGN SYSTEM PREFIX]

Quick schedule entry in SafeTrip. Text-based rapid schedule input.

MODAL (bottom sheet, half state):
HEADER: "빠른 일정 입력" + close X.

INPUT:
- Large single-line text input
- Placeholder: "10:00 시부야 쇼핑"
- Helper: "시간 + 내용을 입력하세요 (예: 14:00 센소지 관광)"

PREVIEW (appears below input as user types):
- Parsed result card:
  - ⏰ "10:00 ~ 11:00" (auto-estimated 1hr duration)
  - 📝 "시부야 쇼핑"
  - "시간을 수정하려면 탭하세요" (gray hint)

QUICK ADD BUTTON: "+" teal circle button next to input (add and clear for next entry)

RECENT ENTRIES (below):
- "방금 추가: 10:00 시부야 쇼핑 ✅"
- "방금 추가: 14:00 센소지 관광 ✅"

BOTTOM: "완료" primary button.
```

**Step 3: D-05 일정 상세**

```
[DESIGN SYSTEM PREFIX]

Schedule detail view in SafeTrip. Shows full information for a single schedule event.

TOP: Back arrow + "일정 상세" title + edit pencil icon (captain/crew chief only).

EVENT CARD (white, radius 16px):
- "시부야 쇼핑" title (bold 20px)
- Date: 📅 "2026년 3월 17일 (수)"
- Time: ⏰ "10:00 ~ 12:00" (2시간)
- Location: 📍 "시부야 109빌딩" (tappable, teal)

MINI MAP (small map showing the location pin, 150px height, radius 12px):
- Single pin on the event location
- "지도에서 보기" link below

PARTICIPANTS SECTION:
- "참석자" heading
- Avatar row: 5 member avatars with names
- "전체 8명" count

NOTES:
- "메모" heading
- "쇼핑 후 하치코 동상 앞에서 집합" text

If event-linked sharing mode:
- Info banner: "📍 이 일정 중 위치가 자동 공유됩니다 (15분 버퍼)"
```

**Step 4: 확인 & 커밋**

```bash
git commit -m "design: add schedule modals (D-02, D-03, D-05)"
```

---

### Task 9: 장소 모달 (D-06, D-07, D-08)

**Step 1: D-06 장소 추가 모달**

```
[DESIGN SYSTEM PREFIX]

Add place/POI modal in SafeTrip. Map-based place selection.

MODAL (full screen):
TOP: Back arrow + "장소 추가" title.

MAP (top 60%):
- Interactive map with crosshair pin in center
- "지도를 움직여 위치를 선택하세요" instruction overlay
- Current pin shows location name dynamically: "시부야 109빌딩 근처"

BOTTOM SHEET (bottom 40%):
FORM:
- "장소 이름" input (auto-filled from geocoding: "시부야 109")
- "카테고리" chip selector:
  - 🏨 숙소 | 🍽️ 식당 | 🏛️ 관광 | 🛍️ 쇼핑 | ✈️ 공항 | 📌 기타
- "메모" optional input
- "🔍 검색으로 찾기" text link (opens D-08)

BOTTOM: "장소 추가" primary button (teal).
```

**Step 2: D-07 장소 직접 입력**

```
[DESIGN SYSTEM PREFIX]

Direct place entry in SafeTrip. Manual address or coordinates input.

MODAL (bottom sheet, tall):
HEADER: "직접 입력" + close X.

TAB SELECTOR: "주소" | "좌표" (two tabs)

ADDRESS TAB (selected):
- "주소" large text input
- Placeholder: "도로명 또는 지번 주소를 입력하세요"
- "상세주소" secondary input (optional)
- Geocode result preview: mini map with pin + "서울특별시 강남구 역삼동 123-45"

COORDINATES TAB:
- "위도" number input: "35.6762"
- "경도" number input: "139.6503"
- Map preview showing the pin at those coordinates

BOTTOM: "확인" primary button.
```

**Step 3: D-08 장소 검색**

```
[DESIGN SYSTEM PREFIX]

Place search screen in SafeTrip using Nominatim geocoding.

TOP: Search input field (auto-focused, with magnifying glass icon):
- Placeholder: "장소, 주소, 랜드마크 검색"
- Clear X button when text entered

SEARCH RESULTS (scrollable list):
1. "시부야 109" - "東京都渋谷区道玄坂2丁目" (address) - "1.2km"
2. "시부야 스크램블 교차로" - "東京都渋谷区渋谷2丁目" - "1.5km"
3. "시부야 PARCO" - "東京都渋谷区宇田川町15-1" - "1.3km"

Each result: 📍 icon left, place name (bold) + address (gray 12px) center, distance right.

MAP PREVIEW (bottom 30%):
- Shows pins for all search results
- Tapping a result highlights it on map and scrolls map to it

BOTTOM: "이 장소 선택" button (appears when a result is tapped, teal).
```

**Step 4: 확인 & 커밋**

```bash
git commit -m "design: add place modals (D-06, D-07, D-08)"
```

---

### Task 10: 멤버 관리 (D-11, D-12, D-13)

**Step 1: D-11 초대코드 관리**

```
[DESIGN SYSTEM PREFIX]

Invite code management screen in SafeTrip. Captain manages active invite codes.

TOP: Back arrow + "초대코드 관리" title + "+ 새 코드" button (teal, top right).

ACTIVE CODES LIST:
Card 1 (white, radius 12px):
- Code: "A7B3K9" (large monospace, teal, tappable to copy)
- Created: "2026.03.15"
- Used: "3/10회" with progress bar
- Status: 🟢 "활성"
- Actions: 📋 "복사" | 🔗 "공유" | 🗑️ "삭제"

Card 2:
- Code: "X2P8M1"
- Created: "2026.03.14"
- Used: "10/10회"
- Status: ⚪ "만료"
- "재생성" teal text button

SHARE SECTION (bottom card):
- "딥링크로 초대" heading
- Copy-able deep link URL
- Share buttons: 카카오톡, SMS, 기타
- QR code small preview thumbnail

BOTTOM: "새 초대코드 생성" outlined button.
```

**Step 2: D-12 멤버 상세**

```
[DESIGN SYSTEM PREFIX]

Member detail screen in SafeTrip. Captain/crew chief views a member's full profile and status.

TOP: Back arrow + member name.

PROFILE CARD (top):
- Large avatar (80px) with role-colored ring (gray for crew)
- "이영희" name (bold 20px)
- "크루" role badge (gray #898989)
- "📞 010-****-5678" phone (partially masked)

STATUS SECTION:
- "위치 공유": 🟢 "공유 중" or 🔴 "비공유" toggle status
- "마지막 위치": "도쿄 시부야" + "5분 전"
- "프라이버시": 📍 "표준" (read-only info)

GUARDIAN SECTION:
- "연결된 가디언" heading
- "박보호 (엄마)" + "연결됨" green badge
- "1명 연결됨 / 최대 5명"

ACTIONS (captain only):
- "역할 변경" → dropdown: 크루장 승급 / 크루 유지
- "멤버 내보내기" red text button (destructive)
- "리더 이관" teal text button

Clean layout, card-based sections with 16px padding.
```

**Step 3: D-13 리더 이관**

```
[DESIGN SYSTEM PREFIX]

Leadership transfer modal in SafeTrip. Captain transfers their role to another member.

MODAL (bottom sheet, tall):
HEADER: "리더 이관" title + close X.
WARNING BANNER (amber #FFC363 bg):
- ⚠️ "캡틴 권한을 이관하면 되돌릴 수 없습니다"

MEMBER SELECTION:
- "새 캡틴을 선택하세요" heading

RECOMMENDED (highlighted):
- "크루장" section header with ⭐ star
- Radio: "박지수" (크루장 badge, teal dark) — recommended

OTHER MEMBERS:
- Radio: "이영희" (크루 badge, gray)
- Radio: "김준호" (크루 badge, gray)
- Radio: "최민아" (크루 badge, gray)

Each member row: radio button + avatar + name + current role badge

CHANGE PREVIEW:
- "이관 후 변경사항" box (beige bg):
  - "박지수: 크루장 → 캡틴"
  - "나 (김철수): 캡틴 → 크루장"

BOTTOM: "이관 확인" destructive button (coral background) + "취소" text button.
```

**Step 4: 확인 & 커밋**

```bash
git commit -m "design: add member management screens (D-11, D-12, D-13)"
```

---

### Task 11: 채팅 (I-01, I-02)

**Step 1: I-01 채팅 탭**

```
[DESIGN SYSTEM PREFIX]

Group chat tab in SafeTrip bottom sheet. Shows messaging interface within the trip.

BOTTOM SHEET (expanded state, 75%):
TAB BAR: 📅일정 | 👥멤버 | 💬채팅 (active, teal underline) | 📖가이드

CHAT MESSAGES (scrollable):

Date separator: "─── 3월 17일 (수) ───"

Incoming message:
- Small avatar left (32px) + "김철수" name (bold 12px, teal = captain)
- Message bubble (light gray #F5F5F5, radius 12px):
  - "10시에 시부야역 하치코 앞에서 만나요!"
  - "10:23" timestamp (gray 11px, bottom right)

Outgoing message (mine):
- Bubble aligned right (teal #00A2BD background, white text):
  - "네 알겠습니다! 🙂"
  - "10:24" + ✓✓ read receipt (two checkmarks)

Incoming (another member):
- Avatar + "이영희" (gray = crew)
- "혹시 우산 챙기셨나요? 비 온다는데"
- "10:30"

System message (centered, gray text, no bubble):
- "박지수님이 그룹에 참여했습니다"

INPUT BAR at bottom of sheet:
- Attachment 📎 icon left
- Text input field "메시지 입력..."
- Send arrow button right (teal circle)
```

**Step 2: I-02 채팅 입력 (오프라인 상태 포함)**

```
[DESIGN SYSTEM PREFIX]

Chat input area detail and offline state in SafeTrip.

TWO STATES shown:

STATE 1 - ONLINE:
- Chat input bar at bottom
- 📎 attachment icon (opens image picker)
- Text input with "메시지 입력..." placeholder
- Send button (teal arrow circle)
- Attachment preview: selected image thumbnail with X remove button

STATE 2 - OFFLINE:
- Top banner: "📡 네트워크 연결 없음" (orange #FFAC11 bg, white text)
- Chat input still functional
- Send button shows ⏳ clock icon instead of arrow
- Sent message bubble shows "전송 대기 중..." with ⏳ indicator
- Gray text: "네트워크 연결 시 자동으로 전송됩니다"

Show both states vertically for comparison.
```

**Step 3: 확인 & 커밋**

```bash
git commit -m "design: add chat screens (I-01, I-02)"
```

---

### Task 12: 안전 가이드 서브탭 (J-02, J-03, J-04, J-05, J-06)

**Step 1: J-02 국가 개요**

```
[DESIGN SYSTEM PREFIX]

Country overview tab in SafeTrip safety guide. Shows basic country information.

BOTTOM SHEET (tall state):
TAB: 안전가이드 active. Sub-tabs: 개요(active) | 안전경보 | 입국정보 | 의료 | 긴급연락처

CONTENT:
FLAG + COUNTRY (hero section):
- 🇯🇵 Japan flag (large 64px)
- "일본" (bold 24px) / "Japan" (gray 14px)

INFO GRID (2 columns):
- 수도: 도쿄 (東京)
- 언어: 일본어
- 화폐: 엔 (¥, JPY)
- 시차: +0시간 (한국과 동일)
- 전압: 100V, 60Hz
- 비자: 90일 무비자

SAFETY LEVEL CARD (colored):
- Current MOFA safety level badge
- Level 1: "여행유의" (blue)
- Updated: "2026.03.01 기준"

QUICK LINKS:
- "대사관 정보 →"
- "긴급 전화번호 →"
```

**Step 2: J-03 안전 경보**

```
[DESIGN SYSTEM PREFIX]

Safety alert tab in SafeTrip guide. Shows MOFA safety level and current warnings.

Sub-tab: 안전경보 (active, highlighted)

SAFETY LEVEL BANNER:
- Large colored card based on level:
  - Level 1 (blue): "1단계: 여행유의"
  - Level 2 (yellow): "2단계: 여행자제"
  - Level 3 (orange): "3단계: 출국권고"
  - Level 4 (red): "4단계: 여행금지"
- Show Level 1 example with blue bg

ALERTS LIST:
Alert 1 (card, amber left border):
- "⚠️ 도쿄 지역 태풍 주의보"
- "2026.03.15 발령"
- "3월 18-19일 태풍 접근 예상. 외출 자제 권고"

Alert 2:
- "📢 오사카 지역 소매치기 주의"
- "2026.02.28"
- "관광지 밀집 지역에서 소매치기 피해 증가"

DO/DON'T SECTION:
- ✅ "여권 사본을 별도 보관하세요"
- ✅ "현지 긴급번호를 저장하세요"
- ❌ "밤늦게 골목길 혼자 다니지 마세요"
- ❌ "귀중품을 겉에 드러내지 마세요"
```

**Step 3: J-04 입국/비자**

```
[DESIGN SYSTEM PREFIX]

Entry/visa information tab in SafeTrip guide.

Sub-tab: 입국정보 (active)

VISA SECTION:
- "비자 요건" heading
- Status card (green bg): "✅ 90일 무비자 입국 가능 (관광 목적)"
- "여권 잔여 유효기간: 6개월 이상 필요"

REQUIRED DOCUMENTS:
- Checklist style:
  - ☐ 여권 (잔여 6개월 이상)
  - ☐ 왕복 항공권 (또는 출국 증빙)
  - ☐ 숙소 예약 확인서
  - ☐ Visit Japan Web 등록 (권장)

ENTRY PROCESS:
- Step 1: 입국 심사 → Step 2: 수하물 수취 → Step 3: 세관 신고
- Simple horizontal stepper UI

CUSTOMS INFO:
- "반입 금지 품목" expandable section
- "면세 한도" info: "주류 3병, 담배 400개비, 향수 2온스"
```

**Step 4: J-05 의료/건강**

```
[DESIGN SYSTEM PREFIX]

Medical and health information tab in SafeTrip guide.

Sub-tab: 의료 (active)

VACCINATION SECTION:
- "권장 예방접종" heading
- No required vaccinations for Japan (green check)
- "권장: 독감, B형 간염" (optional items)

HEALTH WARNINGS:
- Card: "🦟 모기 매개 질환: 낮음"
- Card: "🥤 수돗물: 안전 (음용 가능)"
- Card: "🏥 의료 수준: 매우 높음"

NEARBY HOSPITALS (if trip location known):
- "근처 병원" heading
- 1. "도쿄 대학 병원" - "2.3km" - 📞 "03-3815-5411"
- 2. "성루카 국제병원 (영어 가능)" - "4.1km" - 📞

INSURANCE:
- "해외 여행자 보험 가입을 권장합니다" info banner
- "일본 응급실 비용: 약 30~50만원" warning

EMERGENCY:
- "응급 전화: 119 (소방/구급)"
- Tappable phone number with call icon
```

**Step 5: J-06 긴급 연락처**

```
[DESIGN SYSTEM PREFIX]

Emergency contacts tab in SafeTrip guide. One-touch calling support.

Sub-tab: 긴급연락처 (active)

LOCAL EMERGENCY (red card section):
- "🚨 현지 긴급전화" heading (bold, red bg)
- 📞 경찰: 110 — [CALL button teal]
- 📞 소방/구급: 119 — [CALL button teal]
- 📞 해양구조: 118 — [CALL button teal]
Each row: icon + label + number + one-touch call button

EMBASSY SECTION (teal card):
- "🇰🇷 주일본 대한민국 대사관"
- "📍 도쿄 미나토구 미나미아자부 1-2-5"
- "📞 03-3452-7611" — [CALL]
- "🕐 평일 09:00-12:00, 13:30-18:00"
- "긴급(24시간): 03-3452-7611" — [CALL red]

PERSONAL CONTACTS:
- "내 비상연락처" heading
- "김부모 (아버지)" — "010-1234-5678" — [CALL]
- "+ 비상연락처 추가" teal text link

All phone numbers are large, tappable, with clear call-to-action buttons.
```

**Step 6: 확인 & 커밋**

```bash
git commit -m "design: add safety guide sub-tabs (J-02~J-06)"
```

---

## Round 3: 확장 기능 (27개 신규 화면)

### Task 13: 위치공유 설정 (E-01, E-02, E-03, E-04)

**Step 1-4:** 각 화면을 위의 패턴과 동일하게 생성.

E-01 프롬프트 핵심: 위치공유 ON/OFF 토글 + 현재 프라이버시 등급 표시 + 공유 스케줄 요약
E-02 프롬프트 핵심: 요일별 타임 슬라이더 (24h range selector) + 특정 일자 오버라이드
E-03 프롬프트 핵심: 이벤트 목록 + 버퍼 시간 셀렉터 (0/15/30분 라디오)
E-04 프롬프트 핵심: 가시범위 3단 라디오 (전체/관리자/지정) + 멤버 체크리스트

```bash
git commit -m "design: add location sharing settings (E-01~E-04)"
```

---

### Task 14: 프라이버시 변경 + 지오펜스 (E-05, E-06, E-07, E-08)

E-05: 가디언 일시정지 — 슬라이더(시간) + 등급별 최대 표시 + 타이머 카운트다운
E-06: 등급 변경 확인 — before/after 비교 카드 + 영향 목록 + 알림 대상
E-07: 모드 전환 확인 — 강제↔자유 비교 + "전 멤버에게 알림" 확인 체크박스
E-08: 지오펜스 관리 — 지도 위 폴리곤 목록 + 추가 버튼 + 반경 슬라이더

```bash
git commit -m "design: add privacy & geofence screens (E-05~E-08)"
```

---

### Task 15: SOS 확장 + 출석 (G-03, G-04, G-05, H-01, H-02)

G-03: SOS 수신 — 전체화면 알림 카드 + 발신자 위치 미니맵 + "확인"/"위치 보기" 버튼
G-04: 비상 연락처 — J-06과 유사하나 독립 화면 (설정에서 접근)
G-05: SOS 이력 — 타임라인 형태 리스트 + 필터
H-01: 출석 생성 — 마감 시간 피커 + 대상 멤버 체크리스트 + 메시지
H-02: 출석 응답 — 풀스크린 카드 + "출석"(녹) / "결석"(적) 대형 버튼 + 카운트다운

```bash
git commit -m "design: add SOS extended + attendance create/respond (G-03~G-05, H-01, H-02)"
```

---

### Task 16: 출석 결과 + 나머지 (H-03, H-04, H-05, C-10, C-11, C-12)

H-03: 출석 진행 — 프로그레스 원형 차트 + 멤버별 상태 아이콘 리스트
H-04: 출석 결과 — 최종 통계 카드 + 멤버별 결과 테이블
H-05: 가디언 출석뷰 — H-04의 축소판 (연결 멤버만)
C-10: 이벤트 로그 — 타임라인 + 유형별 필터 칩
C-11: 마커 상세 — 작은 팝업 카드 (이름/역할/시간/상태)
C-12: 맵 컨트롤 — 플로팅 버튼 그룹 (줌+/-, 내 위치, 전체보기)

```bash
git commit -m "design: add attendance results, event log, map components (H-03~H-05, C-10~C-12)"
```

---

### Task 17: 설정 확장 + 여행 상태 (K-03~K-08, D-14~D-16)

**Batch A: 설정 화면 (K-03~K-08)**
K-03: 위치 설정 — 토글 + 배터리 최적화 안내 카드
K-04: 알림 설정 — 유형별 ON/OFF 스위치 리스트
K-05: 앱 정보 — 버전/라이선스/약관 링크 리스트
K-06: 약관 재동의 — 업데이트 diff 표시 + 체크박스
K-07: 계정 삭제 — 경고 + 7일 유예 + 데이터 보존 기간 표
K-08: 삭제 철회 — 남은 유예기간 카운트다운 + 철회 버튼

**Batch B: 여행 상태 (D-14~D-16)**
D-14: 여행 시작 — 체크리스트 (멤버 ✓, 권한 ✓, 일정 ✓) + "시작" 버튼
D-15: 여행 완료 — 요약 통계 카드 + "완료" 버튼
D-16: 재활성화 — 24시간 카운트다운 + 1회 제한 안내

```bash
git commit -m "design: add settings extended + trip state screens (K-03~K-08, D-14~D-16)"
```

---

### Task 18: 가디언 확장 + 채팅 확장 + 가이드 확장 (F-08~F-10, I-03~I-05, J-07, D-04)

F-08: 가디언 위치 요청 — 요청 폼 + 시간당 3회 제한 표시 + 등급별 처리 설명
F-09: 위치 요청 승인 (멤버) — 팝업 알림 + 승인/거절 + 1회성 공유 안내
F-10: 전체여행 가디언 — 2슬롯 관리 + 자동 적용 안내
I-03: 미디어 미리보기 — 전체화면 이미지 뷰어 + 줌/스와이프
I-05: 오프라인 큐 — 대기 메시지 리스트 + 상태 인디케이터
J-07: 국가 변경 — 국가 검색 + 최근 조회 리스트
D-04: 일정 NLP 변환 — 텍스트 입력 → 구조화 미리보기 + 수정 UI

```bash
git commit -m "design: add guardian extended, chat extended, guide search, NLP schedule (F-08~F-10, I-03~I-05, J-07, D-04)"
```

---

## Round 4: Phase 2-3 (27개 신규 화면)

### Task 19: 결제 플로우 (L-01~L-05)

L-01: 요금 안내 — 단계별 요금표 + 현재 멤버 수 하이라이트
L-02: 결제 수단 — 카드 등록 + 간편결제 옵션
L-03: 결제 확인 — 주문 요약 + 최종 금액
L-04: 결제 완료 — 성공 체크 애니메이션 + 영수증
L-05: 가디언 슬롯 구매 — 슬롯 비주얼 + 1,900원 표시

```bash
git commit -m "design: add payment flow (L-01~L-05)"
```

---

### Task 20: 결제 확장 + 미성년자 (L-06~L-10, M-01~M-04)

L-06~L-10: 애드온 상품, 환불, 결제 내역, 결제 실패
M-01~M-04: 보호자 동의, 이중 동의, 미성년자 여행 안내, 미성년자 가디언 해제

```bash
git commit -m "design: add payment extended + minor protection (L-06~L-10, M-01~M-04)"
```

---

### Task 21: B2B 포털 (N-01~N-04)

> **Note:** B2B 화면은 DESKTOP deviceType으로 생성

N-01: 대시보드 — 통계 카드 그리드 + 차트
N-02: 대량 여행 생성 — CSV 업로드 + 프로그레스
N-03: 대량 초대코드 — 코드 테이블 + 발송 옵션
N-04: 대량 가디언 — 매핑 테이블 + 동의 추적

```bash
git commit -m "design: add B2B portal part 1 (N-01~N-04)"
```

---

### Task 22: B2B 나머지 + AI (N-05~N-08, O-01~O-05)

N-05~N-08: 계약 관리, 안전 리포트, 멤버 관리, 브랜딩
O-01~O-05: Safety AI, Convenience AI, Intelligence AI, 브리핑, 일정 최적화

```bash
git commit -m "design: add B2B portal part 2 + AI features (N-05~N-08, O-01~O-05)"
```

---

### Task 23: 최종 검증 및 stitch-prompts.md 완성

**Step 1: 전체 화면 목록 확인**

```bash
# Stitch에서 전체 화면 목록 확인
mcp__stitch__list_screens projectId=1860278016444342994
```

Expected: 110+ screens (기존 21 + 신규 89)

**Step 2: stitch-prompts.md 최종 업데이트**

모든 screen ID를 화면 ID와 매핑하여 기록

**Step 3: 디자인 문서 업데이트**

`docs/plans/2026-03-03-screen-design-mockup-plan.md`에서 Stitch 컬럼을 전부 ✅로 업데이트

**Step 4: 최종 커밋**

```bash
git add docs/design/stitch-prompts.md docs/plans/2026-03-03-screen-design-mockup-plan.md
git commit -m "design: complete all 104 screen mockups - final verification"
```

---

## 참조 문서

| 문서 | 경로 |
|------|------|
| 화면 목록 (디자인 문서) | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |
| 디자인 시스템 | `docs/DESIGN.md` |
| 기존 Stitch 기록 | `docs/design/stitch-prompts.md` |
| 비즈니스 원칙 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| DB 설계 | `Master_docs/07_T2_DB_설계_및_관계_v3_4.md` |
| 화면구성원칙 | `Master_docs/10_T2_화면구성원칙.md` |
| 바텀시트 규칙 | `Master_docs/11_T2_바텀시트_동작_규칙.md` |
