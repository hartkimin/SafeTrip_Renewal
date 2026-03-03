# G. SOS & 긴급 기능

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 SOS 긴급 안전 시스템 5개 화면(컴포넌트 포함)을 정의한다.
> SOS는 SafeTrip의 최상위 안전 기능으로, 모든 프라이버시 설정을 무시하는 생명 안전(life-critical) 기능이다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| SOS 원칙 | `Master_docs/13_T3_SOS_원칙.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |
| 바텀시트 동작 규칙 | `Master_docs/11_T2_바텀시트_동작_규칙.md` |

---

## 개요

- **화면 수:** 5개 (G-01 ~ G-05)
- **Phase:** P0 4개, P1 1개 (G-05)
- **핵심 역할:** 크루 (SOS 발신), 전체 (수신/연락처)
- **연관 문서:** `Master_docs/13_T3_SOS_원칙.md`

---

## SOS 디자인 토큰

| 토큰명 | HEX | 용도 |
|--------|-----|------|
| `sosDanger` | `#D32F2F` | SOS 버튼 배경, SOS 오버레이 배경, SOS 관련 전체 |
| SOS 오버레이 배경 | `#D32F2F` (90% opacity) | G-02 전체 화면 배경 |
| SOS 취소 버튼 | `#FFFFFF` outline on `#D32F2F` | G-02 취소 버튼 |
| SOS 프로그레스 링 | `#FFFFFF` on `#D32F2F` | G-01 2초 롱프레스 프로그레스 |
| 긴급 전화 | `tel:` protocol | G-04 원터치 전화 발신 |

> SOS 관련 모든 텍스트는 최소 16sp 이상 (접근성 기준, 글로벌 스타일 가이드 Section 8.3).
> `sosDanger` (#D32F2F)는 다크 모드에서도 동일하게 유지한다.

---

## User Journey Flow

```
[여행 active 상태]
     │
     ├── [크루/크루장/캡틴] ──→ G-01 SOS 버튼 (항상 표시)
     │                              │
     │                         [2초 롱프레스]
     │                              ↓
     │                         G-02 SOS 활성 오버레이
     │                              │
     │                         ├── [30초 내 취소] → SOS 취소, 오버레이 닫힘
     │                         └── [자동 전송] → FCM 알림 전달
     │                                              │
     │                                    ┌─────────┴──────────┐
     │                                    ↓                    ↓
     │                              [멤버 수신]          [가디언 수신]
     │                              G-03 SOS 수신        G-03 SOS 수신
     │                              알림                  알림
     │                                    │
     │                               ├── [확인] → 알림 닫힘
     │                               └── [위치 보기] → C-01 맵 (발신자 위치)
     │
     ├── [전체 역할] ──→ G-04 비상 연락처 (안전가이드 탭 내)
     │
     └── [캡틴/크루장] ──→ G-05 SOS 이력 (P1)
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| C-01 메인맵 | 여행 active + 크루 역할 | G-01 SOS 버튼 (상시 표시) | G |
| G-01 | 2초 롱프레스 완료 | G-02 SOS 활성 오버레이 | G |
| G-02 | 30초 내 취소 | C-01 메인맵 (복귀) | C |
| FCM SOS 수신 | 앱 포그라운드/백그라운드 | G-03 SOS 수신 알림 | G |
| G-03 | "위치 보기" 탭 | C-01 메인맵 (발신자 위치 센터링) | C |
| 안전가이드 탭 | 비상 연락처 선택 | G-04 비상 연락처 | G |
| D-09 멤버 관리 | SOS 이력 보기 | G-05 SOS 이력 | G |

---

## 화면 상세

---

### G-01 SOS 버튼 (SOS Button Component)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | G-01 |
| 화면명 | SOS 버튼 (SOS Button Component) |
| 유형 | **컴포넌트** (독립 화면 아님, 메인맵 위 오버레이 요소) |
| Phase | P0 |
| 역할 | 캡틴, 크루장, 크루 (가디언 미표시) |
| 표시 조건 | 여행 상태 `active` + 크루 역할 (캡틴/크루장/크루) |
| 위치 | 화면 우하단, 바텀시트 탭 바 위에 고정 (Layer 3 — 상단 오버레이) |
| Stitch ID | N/A (C-01 메인맵에 포함) |

> G-01은 독립 화면이 아닌 **컴포넌트 레벨 와이어프레임**이다.
> C-01 메인맵 화면의 Layer 3 (상단 오버레이)에 상시 표시되며, 별도 라우트를 갖지 않는다.

**레이아웃**

```
┌─────────────────────────────┐
│                             │
│        [Layer 1: 지도]       │
│                             │
│                             │
│                             │
│                             │
│                             │
│                             │
│                             │
│                             │
│                             │
│                     ┌─────┐ │
│                     │ SOS │ │  ← FAB 56×56dp
│                     │     │ │     sosDanger #D32F2F
│                     └─────┘ │     "SOS" white bold
│  ┌─────────────────────────┐│
│  │ [일정] [멤버] [채팅] [가이드]││  ← 바텀시트 탭 바
│  └─────────────────────────┘│
└─────────────────────────────┘
```

**롱프레스 프로그레스 상태:**

```
┌─────────────────────────────┐
│                             │
│                             │
│         (배경 dim 처리)       │
│          black 40%          │
│                             │
│                             │
│         ┌───────────┐       │
│         │  ╭─────╮  │       │
│         │  │ SOS │  │       │  ← 56×56dp 버튼 확대 표시
│         │  ╰─────╯  │       │
│         │  ◠◡◠◡◠◡  │       │  ← CircularProgressIndicator
│         │  2초 진행 링│       │     white, 2초 duration
│         └───────────┘       │
│                             │
│     손을 떼면 취소됩니다       │  bodyMedium, #FFFFFF
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| SOS FAB | `FloatingActionButton` | width: 56, height: 56, radius48 (원형), backgroundColor: sosDanger (#D32F2F), elevation: 4dp |
| SOS 라벨 | `Text` | text: "SOS", style: labelLarge (16sp, Bold 700), color: #FFFFFF, textAlign: center |
| 프로그레스 링 | `CircularProgressIndicator` | color: #FFFFFF, strokeWidth: 3.0, duration: 2000ms, size: 60dp (FAB 외곽) |
| 배경 스크림 | `Container` | color: #000000 at 40% opacity, 전체 화면 커버 |
| 취소 안내 | `Text` | text: "손을 떼면 취소됩니다", style: bodyMedium (14sp), color: #FFFFFF |
| 햅틱 피드백 | `HapticFeedback` | heavyImpact — 롱프레스 시작 시 1회, 완료 시 1회 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| idle (기본) | FAB 56×56dp, "SOS" 텍스트, elevation 4dp. 바텀시트 탭 바 우측 상단에 고정 |
| pressing (롱프레스 중) | 배경 스크림 표시 (black 40%), CircularProgressIndicator 0% → 100% (2초), 햅틱 피드백 시작 |
| 프로그레스 50% | 1초 경과, 프로그레스 링 반원 완성, 기기 진동 지속 |
| triggered (2초 완료) | 프로그레스 링 100%, 강한 햅틱 피드백 → G-02 SOS 활성 오버레이로 전환 |
| cancelled (중도 해제) | 프로그레스 링 리셋, 스크림 페이드아웃 (200ms), idle 복귀 |
| 여행 non-active | FAB 미표시 (Visibility.gone) |
| 가디언 역할 | FAB 미표시 (Visibility.gone) |
| 데모 모드 | FAB 표시 + "(체험)" 라벨, 발동 시 "체험 모드에서는 SOS가 전송되지 않습니다" Toast |

**인터랙션**

- [롱프레스 시작] SOS FAB → 배경 스크림 + 프로그레스 링 시작 (0% → 100%, 2초), 햅틱 피드백
- [롱프레스 2초 완료] → SOS 발동 → G-02 SOS 활성 오버레이 전환
- [롱프레스 도중 해제] → 프로그레스 취소, idle 복귀 (오발송 방지)
- [탭 (짧은 터치)] → 무반응 (롱프레스만 유효, 오발송 방지)
- [SOS 발동 시] → 바텀시트 강제 `collapsed` 전환 (바텀시트 동작 규칙 Section 10)

---

### G-02 SOS 활성 오버레이 (SOS Emergency Active)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | G-02 |
| 화면명 | SOS 활성 오버레이 (SOS Emergency Active) |
| Phase | P0 |
| 역할 | 발신자 (캡틴/크루장/크루) |
| 진입 경로 | G-01 SOS 버튼 2초 롱프레스 완료 → G-02 |
| 이탈 경로 | G-02 → C-01 (30초 내 취소) / G-02 → C-01 (SOS 해제) |
| Stitch ID | `5a6e36cbb1d64c24be6ab7bec3fac708` |

**레이아웃**

```
┌─────────────────────────────┐
│           #D32F2F           │  전체 화면 빨간 배경 (90% opacity)
│         (90% opacity)       │
│                             │
│                             │
│         🆘                  │  아이콘 48×48dp, #FFFFFF
│                             │
│      SOS 전송됨              │  headlineMedium (24sp, Bold)
│                             │  #FFFFFF
│                             │
│  ┌─────────────────────────┐│
│  │  📍 현재 위치             ││  Card (white, radius16)
│  │  서울특별시 강남구 역삼동   ││  bodyLarge (16sp), onSurface
│  │  37.5012° N, 127.0396° E ││  bodySmall (12sp), onSurfaceVariant
│  │  2026-03-03 14:32:05     ││  bodySmall (12sp), onSurfaceVariant
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │  👤 발신자: 김민지         ││  Card (white, radius16)
│  │  🔔 알림 발송: 멤버 4명,  ││  bodyMedium (14sp)
│  │     가디언 2명            ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │  📞 긴급 구조기관 연결     ││  Button (white bg, sosDanger text)
│  └─────────────────────────┘│  높이 52px, radius12
│                             │
│  ┌─────────────────────────┐│
│  │     SOS 취소 (27초)      ││  OutlinedButton (white outline)
│  └─────────────────────────┘│  높이 52px, radius12
│                             │
│  SafeTrip SOS는 보조 수단입  │  bodySmall (12sp), #FFFFFF
│  니다. 실제 응급 시 119/112를 │  70% opacity
│  먼저 연락하세요.             │
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 전체 배경 | `Container` | color: sosDanger (#D32F2F) at 90% opacity, 전체 화면 |
| SOS 아이콘 | `Icon` | icon: emergency (또는 커스텀 SOS 아이콘), size: 48, color: #FFFFFF |
| SOS 전송됨 | `Text` | text: "SOS 전송됨", style: headlineMedium (24sp, Bold 700), color: #FFFFFF |
| 위치 카드 | `Card` | backgroundColor: #FFFFFF, radius16, padding: spacing16 |
| 위치 주소 | `Text` | style: bodyLarge (16sp), color: onSurface, 역지오코딩 주소 |
| 좌표 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, GPS 좌표 |
| 시각 텍스트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, SOS 발동 시각 |
| 발신자 카드 | `Card` | backgroundColor: #FFFFFF, radius16, padding: spacing16 |
| 발신자 정보 | `Text` | style: bodyMedium (14sp), 발신자 이름 + 알림 수신 인원 수 |
| 긴급 구조기관 버튼 | `ElevatedButton` | backgroundColor: #FFFFFF, textColor: sosDanger (#D32F2F), 높이 52px, radius12 |
| SOS 취소 버튼 | `OutlinedButton` | borderColor: #FFFFFF, textColor: #FFFFFF, 높이 52px, radius12 |
| 취소 카운트다운 | `Text` | 30초 카운트다운, style: labelLarge (16sp, SemiBold), color: #FFFFFF |
| 투명성 고지 | `Text` | style: bodySmall (12sp), color: #FFFFFF at 70% opacity |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (전송 중) | 오버레이 페이드인 (300ms), 위치 수집 중 → ProgressIndicator, 좌표 "수집 중..." |
| 전송 완료 | 위치 카드에 주소/좌표 표시, 알림 발송 인원 수 확정, 취소 카운트다운 30초 시작 |
| 취소 가능 (30초 내) | "SOS 취소 (N초)" 버튼 활성, 카운트다운 매초 갱신 |
| 취소 만료 (30초 경과) | 취소 버튼 비활성 (opacity 0.3), 텍스트 "취소 불가" 변경 |
| SOS 취소 완료 | Dialog_Confirm "SOS를 취소하시겠습니까?" → 확인 시 오버레이 닫힘 → C-01 복귀, 수신자에게 "SOS 취소됨" 알림 |
| SOS 해제 (발신자/캡틴) | Dialog_Confirm "SOS를 해제하시겠습니까? 실제 응급 상황이 아님을 확인하셨나요?" + "오발송이었나요?" 체크박스 |
| 오프라인 | "네트워크 없음 — SMS로 발송됩니다" 배너 표시, SMS 발송 상태 표시, 로컬 알람 작동 |
| GPS 신호 없음 | 위치 카드에 "GPS 신호 없음 — 마지막 알려진 위치" 표시, semanticWarning 보더 |
| 앱 재진입 (SOS 활성 중) | SOS 이벤트 active 상태 확인 → 자동으로 G-02 오버레이 다시 표시 |

**인터랙션**

- [자동] SOS 발동 즉시 → POST `/api/v1/trips/{tripId}/sos` → 서버 이벤트 생성 + FCM 발송
- [자동] 위치 수집 → GPS 좌표 + 역지오코딩 주소 표시
- [자동] 채팅탭에 SOS 시스템 메시지 자동 삽입: "[SOS] {사용자명}이 긴급 도움을 요청했습니다. 위치: {주소}"
- [자동] 바텀시트 → collapsed 강제 전환
- [탭] 긴급 구조기관 연결 → G-04 비상 연락처 화면 (현지 긴급전화 섹션 포커스)
- [탭] SOS 취소 (30초 내) → Dialog_Confirm → PATCH `/api/v1/trips/{tripId}/sos/{sosEventId}/resolve` → 수신자에게 취소 알림 → C-01 복귀
- [탭] SOS 해제 (30초 이후, 발신자 또는 캡틴) → Dialog_Confirm + 오발송 확인 → PATCH resolve → 오버레이 닫힘
- [스와이프 다운] → 무반응 (실수 닫힘 방지, 명시적 버튼만 허용)

---

### G-03 SOS 수신 알림 (SOS Received Alert)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | G-03 |
| 화면명 | SOS 수신 알림 (SOS Received Alert) |
| Phase | P0 |
| 역할 | 전체 (멤버 + 가디언) |
| 진입 경로 | FCM 푸시 알림 수신 → G-03 |
| 이탈 경로 | G-03 → C-01 메인맵 ("위치 보기") / G-03 닫힘 ("확인") |

**레이아웃**

```
┌─────────────────────────────┐
│                             │
│         (배경 스크림)         │  black 60% opacity
│                             │
│  ┌─────────────────────────┐│
│  │                         ││  Card_Alert (sosDanger 보더)
│  │      🆘 SOS 긴급 알림    ││  titleLarge (20sp, Bold)
│  │                         ││  sosDanger (#D32F2F)
│  │  ┌───────────────────┐  ││
│  │  │   👤              │  ││  CircleAvatar 48×48
│  │  │  김민지            │  ││  titleMedium (18sp, SemiBold)
│  │  │  크루              │  ││  Badge_Role (Crew, #898989)
│  │  └───────────────────┘  ││
│  │                         ││
│  │  ┌───────────────────┐  ││
│  │  │  🗺️ 미니맵         │  ││  Google Map (static)
│  │  │                   │  ││  200×150dp, radius8
│  │  │    📍 (발신자 위치)  │  ││  마커: sosDanger 핀
│  │  │                   │  ││
│  │  └───────────────────┘  ││
│  │                         ││
│  │  📍 서울 강남구 역삼동    ││  bodyMedium (14sp)
│  │  🕐 14:32:05 (2분 전)   ││  bodySmall (12sp)
│  │                         ││  onSurfaceVariant
│  │  ┌──────────┐ ┌────────┐││
│  │  │   확인    │ │위치 보기│││  Button_Secondary / Button_Primary
│  │  └──────────┘ └────────┘││  각 높이 52px
│  │                         ││
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 배경 스크림 | `Container` | color: #000000 at 60% opacity, 전체 화면, GestureDetector 탭 무시 (닫힘 방지) |
| 알림 카드 | `Card` | backgroundColor: #FFFFFF, radius16, border: 2px sosDanger (#D32F2F), padding: spacing16, elevation: 8dp |
| SOS 아이콘 + 제목 | `Row` | icon: 🆘 (24dp), Text: "SOS 긴급 알림", style: titleLarge (20sp, Bold), color: sosDanger |
| 발신자 아바타 | `CircleAvatar` | radius: 24, backgroundImage: 프로필 사진 (없으면 기본 아이콘) |
| 발신자 이름 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 역할 뱃지 | `Container` (pill) | style: Badge_Role, 발신자 역할에 따른 색상 |
| 미니맵 | `GoogleMap` (static) | width: 전체, height: 150dp, radius8, 발신자 위치 마커 (sosDanger 핀), zoom: 15, interactionEnabled: false |
| 위치 주소 | `Text` | style: bodyMedium (14sp), color: onSurface, leading: 📍 아이콘 |
| 시각 정보 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, leading: 🕐 아이콘, 경과 시간 포함 |
| 확인 버튼 | `OutlinedButton` | style: Button_Secondary, text: "확인", flex: 1 |
| 위치 보기 버튼 | `ElevatedButton` | style: Button_Primary, text: "위치 보기", flex: 1 |
| 사운드 | `AudioPlayer` | SOS 전용 알림음 (`sos_alert.caf` / `sos_alert.mp3`), 기기 최대 볼륨 무시 불가 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 앱 포그라운드 수신 | 전체 화면 오버레이로 G-03 즉시 표시, SOS 알림음 재생, 기기 진동 |
| 앱 백그라운드 수신 | 시스템 푸시 알림 표시 (높은 우선순위), 탭 시 앱 열림 → G-03 표시 |
| 앱 종료 상태 수신 | 시스템 푸시 알림 표시, 탭 시 앱 실행 → 스플래시 → G-03 표시 |
| SOS 활성 중 (지속) | 알림 카드 상단에 "SOS 활성 중" 빨간 점(pulse animation) 표시 |
| SOS 해제됨 | 알림 카드 업데이트: "SOS 해제됨 — {시간}", sosDanger 보더 → outline 보더, 확인 버튼만 표시 |
| SOS 취소됨 (오발송) | 알림 카드 업데이트: "SOS 취소됨 (오발송 확인)", 확인 버튼만 표시 |
| 다중 SOS 수신 | 가장 최근 SOS가 최상위, 이전 SOS는 카드 하단에 축소 표시 |
| 가디언 수신 | 동일 UI, 단 "위치 보기" 탭 시 가디언 맵 뷰 (연결 멤버만 표시) |

**인터랙션**

- [자동] FCM 수신 → SOS 알림음 재생 + 기기 진동 (3초) + G-03 오버레이 표시
- [자동] 앱 열림 시 → 지도 자동 센터링 (발신자 위치)
- [탭] 확인 → G-03 닫힘, 앱 내 상단 배너 "[이름] SOS 발송 중" 유지
- [탭] 위치 보기 → G-03 닫힘 → C-01 메인맵 (발신자 위치 센터링, 줌 레벨 15)
- [배경 탭] 스크림 영역 → 무반응 (실수 닫힘 방지)
- [뒤로가기] → Dialog_Confirm "SOS 알림을 닫으시겠습니까?" (확인 → 닫힘 / 취소 → 유지)

---

### G-04 비상 연락처 (Emergency Contacts)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | G-04 |
| 화면명 | 비상 연락처 (Emergency Contacts) |
| Phase | P0 |
| 역할 | 전체 |
| 진입 경로 | 안전가이드 탭 → G-04 / G-02 "긴급 구조기관 연결" → G-04 / 설정 → G-04 |
| 이탈 경로 | G-04 → 이전 화면 (뒤로가기) / G-04 → 전화 앱 (원터치 전화) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 비상 연락처               │  AppBar_Standard
│                      [🇯🇵 ▼]│  국가 선택 드롭다운
├─────────────────────────────┤
│                             │
│  🚨 현지 긴급전화             │  titleMedium (18sp, SemiBold)
│  ─────────────────────────  │  Divider
│                             │
│  ┌─────────────────────────┐│
│  │ 🚔 경찰 (Police)         ││  ListTile
│  │    110                   ││  titleMedium, sosDanger
│  │              [📞 전화]   ││  원터치 전화 버튼
│  ├─────────────────────────┤│
│  │ 🚒 소방/구급 (Fire/EMS)   ││  ListTile
│  │    119                   ││  titleMedium, sosDanger
│  │              [📞 전화]   ││  원터치 전화 버튼
│  ├─────────────────────────┤│
│  │ 🚑 구급 (Ambulance)      ││  ListTile
│  │    119                   ││  titleMedium, sosDanger
│  │              [📞 전화]   ││  원터치 전화 버튼
│  └─────────────────────────┘│
│                             │
│  🏛️ 대사관 정보              │  titleMedium (18sp, SemiBold)
│  ─────────────────────────  │  Divider
│                             │
│  ┌─────────────────────────┐│
│  │ 🇰🇷 주일본 대한민국 대사관  ││  Card_Standard
│  │ 📍 東京都港区南麻布1-2-5   ││  bodyMedium, onSurfaceVariant
│  │ 📞 +81-3-3452-7611      ││  bodyMedium, primaryTeal
│  │ 🕐 09:00~18:00 (평일)    ││  bodySmall, onSurfaceVariant
│  │         [📞 전화] [📍 지도]││  버튼 2개
│  └─────────────────────────┘│
│                             │
│  👤 개인 비상연락처            │  titleMedium (18sp, SemiBold)
│  ─────────────────────────  │  Divider
│                             │
│  ┌─────────────────────────┐│
│  │ 👤 김영수 (아버지)         ││  Card_Standard
│  │ 📞 010-1234-5678        ││  bodyMedium, primaryTeal
│  │              [📞 전화]   ││  원터치 전화 버튼
│  ├─────────────────────────┤│
│  │ ＋ 비상연락처 추가          ││  TextButton, primaryTeal
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "비상 연락처", leading: BackButton, actions: 국가 선택 드롭다운, style: AppBar_Standard |
| 국가 선택 | `DropdownButton` | items: 여행 목적지 국가 목록, value: 현재 여행 국가 (자동 설정) |
| 섹션 제목 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface, leading: 이모지 아이콘 |
| 구분선 | `Divider` | color: outline (#EDEDED), height: 1px |
| 긴급전화 리스트 | `ListTile` | leading: 이모지 아이콘, title: 기관명 (bodyLarge), subtitle: 전화번호 (titleMedium, sosDanger), trailing: 전화 버튼 |
| 원터치 전화 버튼 | `ElevatedButton.icon` | icon: Icons.phone, backgroundColor: sosDanger (#D32F2F), textColor: #FFFFFF, 높이 40dp, radius8, onPressed: `url_launcher.launch('tel:{number}')` |
| 대사관 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 대사관 주소 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, leading: 📍 |
| 대사관 전화 | `Text` + `InkWell` | style: bodyMedium (14sp), color: primaryTeal (#00A2BD), leading: 📞, onTap: tel: launch |
| 대사관 시간 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, leading: 🕐 |
| 지도 버튼 | `OutlinedButton.icon` | icon: Icons.map, borderColor: primaryTeal, textColor: primaryTeal, onPressed: Google Maps intent |
| 개인 연락처 카드 | `Card` | style: Card_Standard, padding: spacing16 |
| 개인 연락처 이름 | `Text` | style: bodyLarge (16sp), color: onSurface, 관계 표시 포함 |
| 비상연락처 추가 | `TextButton.icon` | icon: Icons.add, text: "비상연락처 추가", color: primaryTeal |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 (자동 국가 설정) | 여행 목적지 국가 기반 긴급전화/대사관 자동 표시 |
| 국가 변경 | 드롭다운 선택 → 해당 국가 긴급전화/대사관 정보 갱신 |
| 개인 연락처 있음 | 프로필에 등록된 비상연락처 표시 |
| 개인 연락처 없음 | "비상연락처가 없습니다. 추가해주세요." 안내 + 추가 버튼 |
| SOS 활성 중 진입 | 상단에 빨간 배너 "SOS 활성 중 — 긴급전화를 먼저 이용하세요", 경찰/소방 버튼 강조 (pulse animation) |
| 대사관 정보 없음 | 해당 국가 대사관 미등록 시 "등록된 대사관 정보가 없습니다" 표시 |
| 오프라인 | 캐싱된 데이터 표시 + "오프라인 — 마지막 업데이트: {시간}" 배너, 전화 버튼은 정상 작동 (tel: protocol) |

**인터랙션**

- [탭] 긴급전화 전화 버튼 → `url_launcher.launch('tel:{number}')` 즉시 전화 발신
- [탭] 대사관 전화 버튼 → `url_launcher.launch('tel:{number}')` 즉시 전화 발신
- [탭] 대사관 지도 버튼 → Google Maps / Apple Maps 인텐트 (주소 기반 내비게이션)
- [탭] 개인 연락처 전화 버튼 → `url_launcher.launch('tel:{number}')` 즉시 전화 발신
- [탭] 비상연락처 추가 → Navigator.push → 프로필 설정 화면 (비상연락처 섹션)
- [탭] 국가 드롭다운 → Modal_Bottom 국가 목록 (검색 가능)
- [뒤로가기] → 이전 화면 (안전가이드 탭 / G-02 오버레이 / 설정)

---

### G-05 SOS 이력 (SOS History)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | G-05 |
| 화면명 | SOS 이력 (SOS History) |
| Phase | P1 |
| 역할 | 캡틴, 크루장 |
| 진입 경로 | 여행 관리 / 멤버탭 → G-05 |
| 이탈 경로 | G-05 → 이전 화면 (뒤로가기) / G-05 → SOS 상세 (리스트 아이템 탭) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] SOS 이력                 │  AppBar_Standard
│                      [필터 ▼]│  필터 드롭다운
├─────────────────────────────┤
│                             │
│  ┌─ 필터 칩 ───────────────┐│
│  │ [전체] [활성] [해제됨]    ││  Chip_Tag (3개)
│  │ [오발송]                 ││  선택 시 secondaryAmber 배경
│  └─────────────────────────┘│
│                             │
│  총 3건의 SOS 이력           │  bodySmall (12sp)
│                             │  onSurfaceVariant
│  ┌─────────────────────────┐│
│  │ 🔴 활성 중                ││  상태 뱃지 (sosDanger)
│  │                         ││
│  │ 김민지                    ││  titleMedium (18sp, SemiBold)
│  │ 2026-03-03 14:32         ││  bodySmall (12sp)
│  │ 📍 서울 강남구 역삼동      ││  bodyMedium (14sp)
│  │                         ││  onSurfaceVariant
│  │ 수동 발동 | 알림 6명      ││  bodySmall (12sp), 칩 스타일
│  │                    [→]  ││  chevron_right
│  └─────────────────────────┘│
│                             │  spacing12
│  ┌─────────────────────────┐│
│  │ ✅ 해제됨                 ││  상태 뱃지 (semanticSuccess)
│  │                         ││
│  │ 이철수                    ││  titleMedium (18sp, SemiBold)
│  │ 2026-03-02 09:15         ││  bodySmall (12sp)
│  │ 📍 도쿄 시부야구          ││  bodyMedium (14sp)
│  │                         ││
│  │ Watchdog 자동 | 해제: 캡틴 ││  bodySmall (12sp)
│  │                    [→]  ││  chevron_right
│  └─────────────────────────┘│
│                             │  spacing12
│  ┌─────────────────────────┐│
│  │ ⚠️ 오발송                 ││  상태 뱃지 (semanticWarning)
│  │                         ││
│  │ 박지수                    ││  titleMedium (18sp, SemiBold)
│  │ 2026-03-01 16:48         ││  bodySmall (12sp)
│  │ 📍 오사카 난바            ││  bodyMedium (14sp)
│  │                         ││
│  │ 수동 발동 | 오발송 확인    ││  bodySmall (12sp)
│  │                    [→]  ││  chevron_right
│  └─────────────────────────┘│
│                             │
└─────────────────────────────┘
```

**SOS 상세 (탭 시 확장 뷰):**

```
┌─────────────────────────────┐
│ [←] SOS 상세                 │  AppBar_Standard
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │  🗺️ 지도                 ││  GoogleMap (interactive)
│  │                         ││  300dp 높이, radius16
│  │     📍 (SOS 발동 위치)    ││  마커: sosDanger 핀
│  │                         ││
│  └─────────────────────────┘│
│                             │
│  ⏱️ 타임라인                  │  titleMedium (18sp, SemiBold)
│  ─────────────────────────  │
│                             │
│  ● 14:32:05  SOS 발동        │  타임라인 아이템
│  │           김민지 (수동)    │  sosDanger 색상 원
│  │                         │
│  ● 14:32:06  FCM 알림 발송    │  타임라인 아이템
│  │           멤버 4명,       │  primaryTeal 색상 원
│  │           가디언 2명      │
│  │                         │
│  ● 14:32:08  채팅 메시지 삽입  │  타임라인 아이템
│  │                         │  onSurfaceVariant 색상 원
│  │                         │
│  ● 14:45:00  SOS 해제        │  타임라인 아이템
│  │           캡틴 (해제)     │  semanticSuccess 색상 원
│  │                         │
│  └──────────────────────── │
│                             │
│  📋 상세 정보                 │  titleMedium (18sp, SemiBold)
│  ─────────────────────────  │
│  발동 유형: 수동 발동          │  bodyMedium
│  GPS 좌표: 37.50°N, 127.04°E │  bodyMedium
│  주소: 서울 강남구 역삼동      │  bodyMedium
│  상태: 해제됨                 │  bodyMedium + 뱃지
│  해제자: 홍길동 (캡틴)        │  bodyMedium
│  소요 시간: 12분 55초         │  bodyMedium
│                             │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "SOS 이력", leading: BackButton, actions: 필터 드롭다운, style: AppBar_Standard |
| 필터 칩 | `Chip` (Wrap) | style: Chip_Tag, items: 전체/활성/해제됨/오발송, 선택 시 secondaryAmber 배경 |
| 총 건수 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| SOS 이력 카드 | `Card` + `InkWell` | style: Card_Standard, padding: spacing16, trailing: chevron_right |
| 상태 뱃지 — 활성 | `Container` (pill) | backgroundColor: sosDanger (#D32F2F), text: "활성 중", color: #FFFFFF, labelSmall |
| 상태 뱃지 — 해제 | `Container` (pill) | backgroundColor: semanticSuccess (#15A1A5), text: "해제됨", color: #FFFFFF, labelSmall |
| 상태 뱃지 — 오발송 | `Container` (pill) | backgroundColor: semanticWarning (#FFAC11), text: "오발송", color: #FFFFFF, labelSmall |
| 발신자 이름 | `Text` | style: titleMedium (18sp, SemiBold), color: onSurface |
| 발동 시각 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 위치 주소 | `Text` | style: bodyMedium (14sp), color: onSurfaceVariant, leading: 📍 |
| 발동 유형 칩 | `Chip` | style: Chip_Tag, text: "수동 발동" / "Watchdog 자동" / "지오펜스 이탈" |
| 상세 지도 | `GoogleMap` | height: 300dp, radius16, 마커: sosDanger 핀, interactionEnabled: true |
| 타임라인 | `ListView` (custom) | 좌측 수직선 + 원형 마커, 각 이벤트별 시각 + 설명 |
| 타임라인 원 — SOS 발동 | `Container` (circle) | size: 12dp, color: sosDanger (#D32F2F) |
| 타임라인 원 — 알림 발송 | `Container` (circle) | size: 12dp, color: primaryTeal (#00A2BD) |
| 타임라인 원 — 해제 | `Container` (circle) | size: 12dp, color: semanticSuccess (#15A1A5) |
| 타임라인 연결선 | `Container` | width: 2dp, color: outline (#EDEDED) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 전체 필터 선택, 최신순 정렬, 모든 SOS 이력 표시 |
| 필터 — 활성 | 현재 활성 중인 SOS만 표시 (status = 'active') |
| 필터 — 해제됨 | 해제된 SOS만 표시 (status = 'resolved') |
| 필터 — 오발송 | 오발송 확인된 SOS만 표시 (false_alarm = true) |
| 이력 없음 | 빈 상태 일러스트 + "SOS 이력이 없습니다" 텍스트 |
| 로딩 중 | 스켈레톤 카드 3개 표시 |
| 에러 | "이력을 불러올 수 없습니다. 다시 시도해주세요." + 재시도 버튼 |
| 활성 SOS 존재 | 활성 카드 최상단 고정, sosDanger 좌측 보더 + pulse animation |

**인터랙션**

- [탭] 필터 칩 → 선택된 필터 기준 목록 갱신, 다중 선택 불가 (단일 선택)
- [탭] SOS 이력 카드 → Navigator.push → SOS 상세 화면 (지도 + 타임라인)
- [당겨서 새로고침] → GET `/api/v1/trips/{tripId}/sos` → 목록 갱신
- [스크롤] → 페이지네이션 (20건씩 로드)
- [뒤로가기] → 이전 화면 (여행 관리 / 멤버탭)

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 5개 화면 (G-01 ~ G-05) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- SOS 원칙: `Master_docs/13_T3_SOS_원칙.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 디자인 시스템: `docs/DESIGN.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 바텀시트 동작 규칙: `Master_docs/11_T2_바텀시트_동작_규칙.md`
