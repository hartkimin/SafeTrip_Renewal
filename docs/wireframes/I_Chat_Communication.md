# I. 채팅 & 커뮤니케이션

> **버전:** v1.0 | **작성일:** 2026-03-03
>
> 이 문서는 SafeTrip 앱의 채팅 & 커뮤니케이션 플로우 5개 화면을 정의한다.
> 채팅탭은 여행 그룹 내 실시간 커뮤니케이션 채널로, 바텀시트 탭 컨텐츠(C-04의 💬 탭)로 제공된다.
> 각 화면은 5-섹션 템플릿(메타데이터, 레이아웃, 컴포넌트 명세, 상태 분기, 인터랙션)으로 구성된다.

**참조 문서:**

| 문서 | 경로 |
|------|------|
| 글로벌 스타일 가이드 | `docs/wireframes/00_Global_Style_Guide.md` |
| 채팅탭 원칙 | `Master_docs/20_T3_채팅탭_원칙.md` |
| 비즈니스 원칙 v5.1 | `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md` |
| 화면 목업 계획 | `docs/plans/2026-03-03-screen-design-mockup-plan.md` |
| 오프라인 동작 원칙 | `Master_docs/16_T2_오프라인_동작_통합_원칙.md` |

---

## 개요

- **화면 수:** 5개 (I-01 ~ I-05)
- **Phase:** P0 2개 (I-01, I-02), P1 2개 (I-03, I-05), P2 1개 (I-04)
- **핵심 역할:** 크루 (캡틴, 크루장, 크루 -- 전체 채팅 참여)
- **연관 문서:** `Master_docs/20_T3_채팅탭_원칙.md`
- **RTDB 채널:** `trip_{tripId}_chat` (실시간 리스너)

> **주의:** 가디언은 그룹 채팅에 접근할 수 없다 (채팅탭 원칙 §6). 가디언-멤버 1:1 보호자 채널은 별도 구현.

---

## 채팅 디자인 토큰

| 토큰명 | HEX | 용도 |
|--------|-----|------|
| 내 메시지 버블 배경 | `primaryTeal` (`#00A2BD`) | 본인 메시지 버블 (우측 정렬) |
| 내 메시지 텍스트 | `#FFFFFF` | 내 버블 내 텍스트 |
| 상대 메시지 버블 배경 | `surfaceContainerLow` (`#F5F5F5`) | 상대 메시지 버블 (좌측 정렬) |
| 상대 메시지 텍스트 | `onSurface` (`#1A1A1A`) | 상대 버블 내 텍스트 |
| 시스템 메시지 텍스트 | `onSurfaceVariant` (`#8E8E93`) | 시스템 메시지 (중앙 정렬) |
| 온라인 인디케이터 | `#4CAF50` | 멤버 온라인 상태 점 |
| 오프라인 배너 배경 | `secondaryAmber` (`#FFB800`) | 네트워크 오프라인 경고 바 |
| 타임스탬프 텍스트 | `onSurfaceVariant` (`#8E8E93`) | 메시지 시간 표시 |
| 읽음 확인 아이콘 | `primaryTeal` (`#00A2BD`) | 읽음 체크마크 |
| 날짜 구분선 텍스트 | `onSurfaceVariant` (`#8E8E93`) | 날짜 헤더 |
| 전송 대기 아이콘 | `onSurfaceVariant` (`#8E8E93`) | 오프라인 큐잉 시계 아이콘 |
| 전송 실패 아이콘 | `semanticError` (`#DA4C51`) | 발송 실패 경고 아이콘 |

---

## User Journey Flow

```
[바텀시트 탭 전환]
     │
     └── [💬 채팅 탭 선택] ──→ I-01 그룹 채팅 탭
                                   │
                              ┌────┴────────────────────────┐
                              │                             │
                         [메시지 작성]                  [미디어 탭]
                              │                             │
                         I-02 채팅 입력                 I-03 미디어 미리보기
                              │                        (P1, 전체화면 뷰어)
                              │
                         ┌────┼────────────┐
                         │    │            │
                    [온라인] [오프라인]   [검색]
                    전송 성공  큐잉       I-04 채팅 검색
                         │    │          (P2)
                         │    ↓
                         │  I-05 오프라인 전송 대기
                         │  (P1, 큐 관리)
                         │    │
                         │    ├── [네트워크 복구] → 자동 전송
                         │    └── [수동 재시도] → 개별 재전송
                         │
                         └── 메시지 목록에 반영
```

---

## 외부 진입/이탈 참조

| 출발 | 조건 | 도착 | 카테고리 |
|------|------|------|---------|
| C-04 바텀시트 | 💬 채팅 탭 선택 | I-01 그룹 채팅 탭 | I |
| I-01 | 이미지/파일 메시지 탭 | I-03 미디어 미리보기 | I |
| I-01 | 검색 아이콘 탭 | I-04 채팅 검색 | I |
| I-01 | 오프라인 배너 탭 | I-05 오프라인 전송 대기 | I |
| I-01 | SOS 시스템 메시지 "지도에서 확인" 탭 | C-01 메인맵 (발신자 위치) | C |
| I-01 | 일정 카드 탭 | D-02 일정 상세 | D |
| I-01 | 위치 카드 "지도에서 보기" 탭 | C-01 메인맵 (해당 위치) | C |
| G-02 SOS 활성 | SOS 발동 | I-01 시스템 메시지 자동 삽입 | I |

---

## 화면 상세

---

### I-01 그룹 채팅 탭 (Group Chat Tab)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | I-01 |
| 화면명 | 그룹 채팅 탭 (Group Chat Tab) |
| Phase | P0 |
| 역할 | 크루 (캡틴, 크루장, 크루) |
| 진입 경로 | C-04 바텀시트 → 💬 채팅 탭 선택 → I-01 |
| 이탈 경로 | I-01 → I-03 (미디어 탭) / I-01 → I-04 (검색) / I-01 → C-01 (위치 카드) |
| 표시 형태 | 바텀시트 탭 컨텐츠 (독립 화면 아님) |

> **참고:** I-01은 바텀시트(BottomSheet_Snap) 내 탭 컨텐츠로 렌더링된다.
> 기본 스냅 포인트는 `half` (35%)이며, 사용자 드래그로 `expanded` (75%)까지 확장 가능하다.

**레이아웃**

```
┌─────────────────────────────┐
│       ── handle bar ──       │ BottomSheet_Snap 핸들
├─────────────────────────────┤
│ 📅일정 │ 👥멤버 │ 💬채팅 │ 🛡️가이드 │ NavBar_Crew (탭 바)
│                    ▔▔▔▔     │ 활성탭: primaryTeal 언더라인
├─────────────────────────────┤
│                             │
│ ─── 3월 15일 (토) ───────── │ 날짜 구분선
│                             │ bodySmall (12sp), onSurfaceVariant
│  ┌──┐                       │
│  │👤│ 홍길동  [캡틴]         │ 32px 아바타 + 이름 + Badge_Role
│  └──┘                       │
│  ┌─────────────────────┐    │
│  │ 10시에 광화문에서     │    │ 상대 메시지 버블 (좌측)
│  │ 만나요!              │    │ surfaceContainerLow (#F5F5F5)
│  │            10:23 AM  │    │ onSurface 텍스트, radius12
│  └─────────────────────┘    │
│                             │
│    ┌─────────────────────┐  │
│    │ 네 알겠습니다! 🙂    │  │ 내 메시지 버블 (우측)
│    │  10:24 AM  ✓✓       │  │ primaryTeal (#00A2BD) 배경
│    └─────────────────────┘  │ 흰색 텍스트, 읽음 확인
│                             │
│  ┌──┐                       │
│  │👤│ 이영희  [크루]         │ 아바타 + 이름 + Badge_Role
│  └──┘                       │
│  ┌─────────────────────┐    │
│  │ 혹시 우산 챙기셨나요?  │    │ 상대 메시지 버블
│  │ 비 온다는데          │    │
│  │            10:30 AM  │    │
│  └─────────────────────┘    │
│                             │
│  ── 박지수님이 그룹에 ───── │ 시스템 메시지
│  ── 참여했습니다 ────────── │ bodySmall, 중앙 정렬, onSurfaceVariant
│                             │
├─────────────────────────────┤
│ [📎]  메시지 입력...   [➤]  │ 입력 영역 (I-02 참조)
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 바텀시트 | `DraggableScrollableSheet` | style: BottomSheet_Snap, 기본 `half` (35%), 탭 전환 시 높이 유지 |
| 탭 바 | `TabBar` | style: NavBar_Crew, 4탭, 활성 탭 `primaryTeal` 언더라인 |
| 메시지 목록 | `ListView.builder` | reverse: true (최신 메시지 하단), physics: ClampingScrollPhysics |
| 날짜 구분선 | `Container` + `Text` | style: bodySmall (12sp), color: onSurfaceVariant, 중앙 정렬, 좌우 Divider |
| 상대 아바타 | `CircleAvatar` | radius: 16 (32dp), backgroundColor: secondaryBeige (#F2EDE4) |
| 상대 이름 | `Text` | style: bodySmall (12sp, SemiBold 600), color: onSurface |
| 역할 뱃지 | `Container` (pill) | style: Badge_Role, 이름 우측에 인라인 표시 |
| 상대 버블 | `Container` | backgroundColor: surfaceContainerLow (#F5F5F5), borderRadius: radius12, padding: spacing12 |
| 내 버블 | `Container` | backgroundColor: primaryTeal (#00A2BD), borderRadius: radius12, padding: spacing12 |
| 상대 버블 텍스트 | `Text` | style: bodyMedium (14sp), color: onSurface (#1A1A1A) |
| 내 버블 텍스트 | `Text` | style: bodyMedium (14sp), color: #FFFFFF |
| 타임스탬프 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant (#8E8E93), 버블 우하단 |
| 읽음 확인 | `Icon` | Icons.done_all, size: 14, color: #FFFFFF (내 버블 내), 읽음 시 표시 |
| 시스템 메시지 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, textAlign: center |
| 입력 영역 | `Row` | 하단 고정, 첨부 버튼 + Input_Text + 전송 버튼 (I-02 상세) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 로딩 | ProgressIndicator (circular, primaryTeal) 중앙 표시 |
| 메시지 있음 | 메시지 목록 표시, 최하단(최신 메시지)으로 자동 스크롤 |
| 메시지 없음 | 빈 상태 일러스트 + "첫 메시지를 보내보세요!" (bodyMedium, onSurfaceVariant) |
| 실시간 수신 | RTDB 리스너로 새 메시지 수신 → 목록 하단에 추가 → 자동 스크롤 (현재 최하단인 경우만) |
| 스크롤 올림 | 새 메시지 수신 시 하단에 "새 메시지 ↓" FAB 표시 (자동 스크롤 안 함) |
| "새 메시지 ↓" 탭 | 최하단으로 스크롤 + FAB 사라짐 |
| 여행 completed | 입력 영역 비활성화 → "종료된 여행입니다" placeholder, 전송 버튼 disabled |
| 여행 planning | 채팅 가능 (여행 시작 전에도 그룹 대화 허용) |
| SOS 시스템 메시지 수신 | SOS 카드(Card_Alert, sosDanger 보더) 자동 삽입 → 바텀시트 `collapsed` 강제 전환 |
| 오프라인 | 상단에 오프라인 배너 표시 (I-02 참조), 캐시된 최근 200건 메시지 열람 가능 |

**인터랙션**

- [스크롤 위] 메시지 영역 → 이전 메시지 로드 (페이지네이션, 50건 단위)
- [탭] 상대 아바타/이름 → 멤버 프로필 바텀시트 표시
- [탭] SOS 시스템 메시지 "지도에서 확인" → Navigator.push → C-01 (발신자 위치 포커스)
- [탭] 위치 카드 "지도에서 보기" → Navigator.push → C-01 (해당 좌표 포커스)
- [탭] 일정 카드 "일정 상세 보기" → Navigator.push → D-02 일정 상세
- [롱프레스] 메시지 버블 → 컨텍스트 메뉴 (복사 / 삭제 / 공지 고정)
- [탭] 다른 탭 → 바텀시트 높이/스크롤 위치 유지, 탭 전환
- [RTDB] `trip_{tripId}_chat` 리스너 → 실시간 메시지 수신

---

### I-02 채팅 입력 상태 (Chat Input States)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | I-02 |
| 화면명 | 채팅 입력 상태 (Chat Input States) |
| Phase | P0 |
| 역할 | 크루 (캡틴, 크루장, 크루) |
| 진입 경로 | I-01 그룹 채팅 탭 (입력 영역, 하단 고정) |
| 이탈 경로 | 입력 완료 → I-01 메시지 목록에 반영 |
| 표시 형태 | I-01 하단 입력 영역 (독립 화면 아님) |

**레이아웃**

```
===== 상태 1: 빈 입력 (Empty) =====

┌─────────────────────────────┐
│ [📎]  메시지 입력...   [➤]  │ 전송 버튼 비활성 (opacity 0.4)
│                             │ height: 48dp
└─────────────────────────────┘

===== 상태 2: 타이핑 중 (Typing) =====

┌─────────────────────────────┐
│ [📎]  오늘 날씨가 좋네요!   │ 텍스트 입력 중
│       128 / 2,000    [➤]   │ 전송 버튼 활성 (primaryTeal)
└─────────────────────────────┘  글자 수 카운트: bodySmall

===== 상태 3: 첨부 선택 (Attachment) =====

┌─────────────────────────────┐
│ ┌──────┐ ┌──────┐           │ 선택된 이미지 썸네일
│ │ 📷   │ │ 📷   │           │ 64x64, radius8
│ │  [X] │ │  [X] │           │ X 버튼으로 개별 제거
│ └──────┘ └──────┘           │
├─────────────────────────────┤
│ [📎]  메시지 입력...   [➤]  │ 첨부와 함께 전송 가능
└─────────────────────────────┘

===== 상태 4: 오프라인 (Offline) =====

┌─────────────────────────────┐
│ ⚠️ 오프라인 - 전송 대기      │ secondaryAmber (#FFB800) 배경
│ 연결 시 자동 전송됩니다      │ #FFFFFF 텍스트, bodySmall
├─────────────────────────────┤
│ [📎]  메시지 입력...   [⏳]  │ 전송 버튼 → 시계 아이콘
└─────────────────────────────┘  입력은 가능, 로컬 큐잉

===== 첨부 메뉴 모달 (Attachment Menu) =====

┌─────────────────────────────┐
│       ── handle bar ──       │ Modal_Bottom
├─────────────────────────────┤
│  📷 사진/동영상               │ ListTile
│     갤러리 또는 카메라 촬영    │ bodySmall, onSurfaceVariant
├─────────────────────────────┤
│  📍 현재 위치 공유            │ ListTile
│     위치 카드 생성            │
├─────────────────────────────┤
│  📅 일정 공유                │ ListTile
│     여행 일정에서 선택         │
├─────────────────────────────┤
│  📎 파일 첨부                │ ListTile
│     파일 선택 (최대 50MB)     │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 입력 컨테이너 | `Container` | height: 48dp (기본), maxHeight: 120dp (멀티라인 확장), backgroundColor: surface (#FFFFFF), 상단 보더 outline (#EDEDED) |
| 첨부 버튼 | `IconButton` | icon: Icons.add_circle_outline, size: 24, color: onSurfaceVariant, onPressed: Modal_Bottom 첨부 메뉴 표시 |
| 텍스트 입력 | `TextField` | hintText: "메시지 입력...", style: bodyMedium (14sp), maxLines: 3, maxLength: 2000, scrollPhysics: ClampingScrollPhysics |
| 글자 수 카운터 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, "현재수 / 2,000" 형식, 1500자 초과 시 semanticError 색상 |
| 전송 버튼 (활성) | `IconButton` | icon: Icons.send, size: 24, backgroundColor: primaryTeal (#00A2BD), iconColor: #FFFFFF, shape: circle (40dp) |
| 전송 버튼 (비활성) | `IconButton` | icon: Icons.send, size: 24, backgroundColor: outline (#EDEDED), iconColor: onSurfaceVariant, opacity: 0.4 |
| 전송 버튼 (오프라인) | `IconButton` | icon: Icons.schedule, size: 24, backgroundColor: onSurfaceVariant (#8E8E93), iconColor: #FFFFFF |
| 오프라인 배너 | `Container` | backgroundColor: secondaryAmber (#FFB800), padding: spacing8 x spacing16, 아이콘 ⚠️ + 텍스트 |
| 배너 텍스트 | `Text` | "오프라인 - 전송 대기", style: bodySmall (12sp, SemiBold), color: #FFFFFF |
| 배너 서브텍스트 | `Text` | "연결 시 자동 전송됩니다", style: bodySmall (12sp), color: #FFFFFF (opacity 0.8) |
| 첨부 메뉴 | `showModalBottomSheet` | style: Modal_Bottom, 4개 항목 (사진/위치/일정/파일) |
| 첨부 썸네일 | `ClipRRect` + `Image` | width: 64, height: 64, borderRadius: radius8, X 버튼 오버레이 |
| 첨부 제거 버튼 | `GestureDetector` + `Container` | 16dp 원형, backgroundColor: onSurface (opacity 0.6), icon: Icons.close (12dp, #FFFFFF) |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 빈 입력 | 전송 버튼 비활성 (opacity 0.4), 힌트 텍스트 표시, 글자 수 카운터 숨김 |
| 타이핑 중 | 전송 버튼 활성 (primaryTeal), 글자 수 카운터 표시, 입력 영역 최대 3줄까지 확장 |
| 첨부 선택됨 | 입력 영역 위에 썸네일 프리뷰 행 표시, 전송 버튼 활성 (텍스트 없어도 첨부만으로 전송 가능) |
| 전송 중 | 전송 버튼 → ProgressIndicator (circular, 20dp, #FFFFFF), 입력 비활성화 |
| 전송 성공 | 입력 필드 클리어, 첨부 제거, 전송 버튼 비활성으로 복귀 |
| 전송 실패 (온라인) | Toast "메시지 전송에 실패했습니다. 다시 시도해주세요." + 메시지 버블에 ⚠️ 표시 |
| 오프라인 | 전송 버튼 아이콘 → 시계 (⏳), 상단 오프라인 배너 표시, 전송 시 로컬 큐잉 |
| 오프라인 전송 | 메시지 버블에 ⏳ "전송 대기" 표시, 회색 텍스트, 큐에 추가 (최대 100건) |
| 큐 100건 초과 | Toast "오프라인 메시지 한도(100건)에 도달했습니다", 전송 버튼 비활성화 |
| 2,000자 초과 시도 | maxLength 제한으로 입력 차단, 카운터 semanticError 색상 |
| 여행 completed | 입력 영역 전체 비활성화, placeholder: "종료된 여행입니다", 첨부 버튼 disabled |

**인터랙션**

- [탭] 입력 필드 → 키보드 표시, 바텀시트 `expanded` 자동 전환
- [입력] 텍스트 → 실시간 글자 수 카운터 업데이트
- [탭] 📎 첨부 버튼 → Modal_Bottom 첨부 메뉴 표시
- [탭] 📷 사진/동영상 → ImagePicker (카메라/갤러리 선택), 선택 후 썸네일 프리뷰
- [탭] 📍 현재 위치 공유 → 위치 권한 확인 → 위치 카드 미리보기 → 전송
- [탭] 📅 일정 공유 → 일정 목록 모달 → 선택 → 일정 카드 전송
- [탭] 📎 파일 첨부 → FilePicker (50MB 이하) → 파일 업로드 후 전송
- [탭] ➤ 전송 버튼 → POST /api/v1/trips/:tripId/chat/messages → 메시지 전송
- [탭] ⏳ 전송 버튼 (오프라인) → SQLite 로컬 큐에 저장 → 버블에 대기 표시
- [탭] X (첨부 제거) → 해당 첨부 제거, 모든 첨부 제거 시 텍스트 없으면 전송 버튼 비활성

---

### I-03 미디어 미리보기 (Chat Media Preview)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | I-03 |
| 화면명 | 미디어 미리보기 (Chat Media Preview) |
| Phase | P1 |
| 역할 | 크루 (캡틴, 크루장, 크루) |
| 진입 경로 | I-01 채팅 → 이미지/파일 메시지 탭 → I-03 |
| 이탈 경로 | I-03 → I-01 (닫기) |

**레이아웃**

```
┌─────────────────────────────┐
│                        [X]  │ 닫기 버튼 (우상단)
│                             │ IconButton, #FFFFFF
│                             │
│                             │
│                             │ 다크 배경 (#000000, opacity 0.95)
│                             │
│        ┌───────────┐        │
│        │           │        │
│        │           │        │
│        │  이미지    │        │ InteractiveViewer
│        │  전체화면  │        │ 핀치 줌 + 팬 제스처
│        │           │        │
│        │           │        │
│        └───────────┘        │
│                             │
│                             │
│         ● ○ ○ ○             │ 미디어 인디케이터
│                             │ (채팅 내 미디어 순서)
├─────────────────────────────┤
│                             │
│  홍길동 · 3월 15일 10:23 AM │ 전송자 + 시간
│                             │ bodySmall, #FFFFFF (opacity 0.7)
│  ┌──────┐  ┌──────┐        │
│  │ 💾   │  │ 📤   │        │ 하단 액션 바
│  │ 저장  │  │ 공유  │        │ IconButton + Text
│  └──────┘  └──────┘        │ #FFFFFF 아이콘/텍스트
│                             │
└─────────────────────────────┘

===== 파일 미리보기 (비이미지) =====

┌─────────────────────────────┐
│                        [X]  │
│                             │
│                             │
│                             │
│        ┌───────────┐        │
│        │  📄       │        │ 파일 아이콘 (64dp)
│        │           │        │
│        │ report.pdf│        │ 파일명: bodyLarge, #FFFFFF
│        │  2.3 MB   │        │ 파일 크기: bodySmall
│        └───────────┘        │   #FFFFFF (opacity 0.7)
│                             │
│  ┌─────────────────────────┐│
│  │      💾 다운로드          ││ Button_Secondary (흰색 변형)
│  └─────────────────────────┘│ outline #FFFFFF, text #FFFFFF
│                             │
├─────────────────────────────┤
│  홍길동 · 3월 15일 10:23 AM │
│  ┌──────┐  ┌──────┐        │
│  │ 💾   │  │ 📤   │        │
│  │ 저장  │  │ 공유  │        │
│  └──────┘  └──────┘        │
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 전체화면 배경 | `Scaffold` | backgroundColor: Colors.black (opacity 0.95) |
| 닫기 버튼 | `IconButton` | icon: Icons.close, size: 28, color: #FFFFFF, alignment: topRight, padding: spacing16 |
| 이미지 뷰어 | `InteractiveViewer` | minScale: 1.0, maxScale: 5.0, panEnabled: true, boundaryMargin: EdgeInsets.zero |
| 이미지 스와이프 | `PageView.builder` | scrollDirection: Axis.horizontal, 채팅 내 미디어 목록 순서 |
| 미디어 인디케이터 | `SmoothPageIndicator` | activeColor: #FFFFFF, inactiveColor: #FFFFFF (opacity 0.3), dotSize: 6 |
| 전송자 정보 | `Text` | style: bodySmall (12sp), color: #FFFFFF (opacity 0.7), "이름 + 날짜 시간" |
| 저장 버튼 | `Column` < `IconButton` + `Text` > | icon: Icons.download, color: #FFFFFF, text: "저장", style: bodySmall |
| 공유 버튼 | `Column` < `IconButton` + `Text` > | icon: Icons.share, color: #FFFFFF, text: "공유", style: bodySmall |
| 파일 아이콘 | `Icon` | icon: Icons.insert_drive_file, size: 64, color: #FFFFFF |
| 파일명 | `Text` | style: bodyLarge (16sp), color: #FFFFFF, textAlign: center |
| 파일 크기 | `Text` | style: bodySmall (12sp), color: #FFFFFF (opacity 0.7) |
| 다운로드 버튼 | `OutlinedButton` | style: Button_Secondary (흰색 변형), borderColor: #FFFFFF, textColor: #FFFFFF, icon: Icons.download |
| 하단 액션 바 | `Container` | backgroundColor: Colors.black (opacity 0.6), padding: spacing16, 하단 고정 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 이미지 로딩 | 중앙 ProgressIndicator (circular, #FFFFFF) |
| 이미지 표시 | InteractiveViewer에 이미지 렌더링, 핀치 줌 가능 |
| 줌 인 상태 | 스와이프 비활성화 (줌 해제 시 스와이프 복원) |
| 스와이프 | 좌/우 PageView 전환 (300ms 슬라이드 애니메이션), 인디케이터 업데이트 |
| 파일 미리보기 | 이미지 뷰어 대신 파일 아이콘 + 파일명 + 크기 + 다운로드 버튼 표시 |
| 다운로드 중 | 다운로드 버튼 → ProgressIndicator, 버튼 텍스트 "다운로드 중..." |
| 다운로드 완료 | Toast "저장되었습니다" + 버튼 텍스트 "다운로드 완료 ✓" |
| 다운로드 실패 | Toast "다운로드에 실패했습니다. 다시 시도해주세요." |
| 이미지 로드 실패 | 깨진 이미지 아이콘 + "이미지를 불러올 수 없습니다" 텍스트 |

**인터랙션**

- [핀치] 이미지 영역 → 줌 인/아웃 (1x ~ 5x)
- [드래그] 줌 인 상태 → 이미지 팬 (이동)
- [스와이프 좌/우] → 이전/다음 미디어로 전환 (줌 1x 상태에서만)
- [탭] X 닫기 → Navigator.pop → I-01 복귀
- [탭] 저장 → 갤러리에 이미지 저장 (저장소 권한 확인)
- [탭] 공유 → Share.share (시스템 공유 시트)
- [탭] 다운로드 (파일) → 로컬 저장소에 다운로드
- [하단 스와이프 다운] → 화면 닫기 (dismiss gesture)

---

### I-04 채팅 검색 (Chat Search)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | I-04 |
| 화면명 | 채팅 검색 (Chat Search) |
| Phase | P2 |
| 역할 | 크루 (캡틴, 크루장, 크루) |
| 진입 경로 | I-01 채팅 탭 → 🔍 검색 아이콘 탭 → I-04 |
| 이탈 경로 | I-04 → I-01 (닫기/취소) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] ┌─ 🔍 검색 ─────────┐  │ Input_Search
│     │ 메시지 검색...       │  │ pill shape, radius22
│     └────────────────────┘  │
│          3건 중 2번째  [▲][▼]│ 매치 카운트 + 네비게이션
│                             │ bodySmall, onSurfaceVariant
├─────────────────────────────┤
│                             │
│ ─── 3월 15일 (토) ───────── │
│                             │
│  [👤] 홍길동                 │
│  ┌─────────────────────┐    │
│  │ 내일 [광화문]에서     │    │ 검색어 "광화문" 하이라이트
│  │ 만나요               │    │ 하이라이트: secondaryAmber 배경
│  │            10:23 AM  │    │
│  └─────────────────────┘    │ ← 현재 매치 (강조 보더)
│                             │
│  ...                        │
│                             │
│  [👤] 이영희                 │
│  ┌─────────────────────┐    │
│  │ [광화문] 가는 길에    │    │ 다른 매치
│  │ 커피 한 잔 할까요?    │    │ 하이라이트: secondaryAmber 배경
│  │            14:05 PM  │    │
│  └─────────────────────┘    │
│                             │
├─────────────────────────────┤
│ [📎]  메시지 입력...   [➤]  │ 입력 영역 (검색 중에도 유지)
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 검색 입력 | `TextField` | style: Input_Search, hintText: "메시지 검색...", autofocus: true, pill shape (radius22) |
| 뒤로가기 | `IconButton` | icon: Icons.arrow_back, onPressed: 검색 모드 종료 → I-01 복귀 |
| 매치 카운트 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant, "N건 중 M번째" 형식 |
| 위 화살표 | `IconButton` | icon: Icons.keyboard_arrow_up, size: 20, color: onSurfaceVariant, 이전 매치 이동 |
| 아래 화살표 | `IconButton` | icon: Icons.keyboard_arrow_down, size: 20, color: onSurfaceVariant, 다음 매치 이동 |
| 하이라이트 텍스트 | `RichText` + `TextSpan` | 매칭 부분 backgroundColor: secondaryAmber (#FFC363, opacity 0.4), fontWeight: SemiBold |
| 현재 매치 표시 | `Container` (보더) | 현재 포커스 매치 메시지에 primaryTeal 좌측 보더 (3px) |
| 메시지 목록 | `ListView.builder` | 매치 메시지만 필터링하지 않고 전체 메시지 표시, 매치 위치로 자동 스크롤 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 초기 | 검색 입력 autofocus, 키보드 표시, 매치 카운트/네비게이션 숨김 |
| 입력 중 (1자 이상) | 실시간 검색 실행 (300ms 디바운스), 매치 결과 하이라이트 |
| 매치 있음 | 매치 카운트 "N건 중 1번째" 표시, ▲▼ 네비게이션 활성, 첫 매치로 자동 스크롤 |
| 매치 없음 | "검색 결과가 없습니다" 중앙 텍스트 (bodyMedium, onSurfaceVariant) |
| 네비게이션 | ▲ 이전 매치, ▼ 다음 매치 → 해당 메시지로 스크롤 + 현재 매치 보더 이동 |
| 검색 클리어 | 입력 필드 X 버튼 → 검색어 삭제, 하이라이트 제거, 카운트 숨김 |
| 검색 종료 | ← 뒤로가기 → 검색 모드 해제, I-01 기본 상태로 복귀 |

**인터랙션**

- [입력] 검색어 → 300ms 디바운스 후 로컬 메시지 캐시에서 검색 실행
- [탭] ▲ 위 화살표 → 이전 매치 메시지로 스크롤 + 카운트 업데이트
- [탭] ▼ 아래 화살표 → 다음 매치 메시지로 스크롤 + 카운트 업데이트
- [탭] 입력 필드 X (클리어) → 검색어 삭제, 하이라이트 제거
- [탭] ← 뒤로가기 → 검색 모드 종료, I-01 채팅 탭 복귀
- [탭] 하이라이트된 메시지 → 해당 메시지를 현재 매치로 설정

---

### I-05 오프라인 전송 대기 (Chat Offline Queue)

**메타데이터**

| 항목 | 값 |
|------|-----|
| ID | I-05 |
| 화면명 | 오프라인 전송 대기 (Chat Offline Queue) |
| Phase | P1 |
| 역할 | 크루 (캡틴, 크루장, 크루) |
| 진입 경로 | I-01 채팅 탭 → 오프라인 배너 탭 → I-05 / K-설정 → 채팅 → 전송 대기 |
| 이탈 경로 | I-05 → I-01 (뒤로가기) |

**레이아웃**

```
┌─────────────────────────────┐
│ [←] 전송 대기 메시지     N건  │ AppBar_Standard
│                             │ title + 대기 건수 뱃지
├─────────────────────────────┤
│                             │
│ ⚠️ 오프라인 상태입니다       │ 상태 배너
│ 네트워크 연결 시 자동으로    │ secondaryAmber (#FFB800) 배경
│ 전송됩니다                  │ #FFFFFF 텍스트
│                             │
├─────────────────────────────┤
│                             │
│  ┌─────────────────────────┐│
│  │ ⏳ 대기중                ││ 상태 Chip_Tag (amber)
│  │                         ││
│  │ 오늘 날씨가 좋네요!      ││ 메시지 내용 미리보기
│  │                         ││ bodyMedium, onSurface
│  │ 오후 3:15               ││ bodySmall, onSurfaceVariant
│  │              [삭제]     ││ TextButton, semanticError
│  └─────────────────────────┘│ Card_Standard, spacing12
│                             │
│  ┌─────────────────────────┐│
│  │ ⏳ 대기중                ││
│  │                         ││
│  │ [📷 이미지 첨부]         ││ 이미지 썸네일 (48x48)
│  │ 이 사진 봐봐             ││
│  │ 오후 3:18               ││
│  │              [삭제]     ││
│  └─────────────────────────┘│
│                             │
│  ┌─────────────────────────┐│
│  │ ⚠️ 전송실패              ││ 상태 Chip_Tag (semanticError)
│  │                         ││
│  │ 여기 어디에요?           ││
│  │ 오후 3:20               ││
│  │       [재시도]   [삭제]  ││ Button_Secondary + TextButton
│  └─────────────────────────┘│ Card_Alert (semanticError 보더)
│                             │
├─────────────────────────────┤
│                             │
│  전체 삭제                   │ TextButton, semanticError
│                             │ 하단 고정
└─────────────────────────────┘
```

**컴포넌트 명세**

| 컴포넌트 | Flutter 위젯 | 속성 |
|----------|-------------|------|
| 앱바 | `AppBar` | title: "전송 대기 메시지", style: AppBar_Standard, trailing: 대기 건수 뱃지 (Badge_Role 스타일, primaryCoral 배경) |
| 상태 배너 | `Container` | backgroundColor: secondaryAmber (#FFB800), padding: spacing12 x spacing16, width: 전체 |
| 배너 아이콘 | `Icon` | Icons.wifi_off, size: 20, color: #FFFFFF |
| 배너 텍스트 | `Text` | "오프라인 상태입니다", style: bodyMedium (14sp, SemiBold), color: #FFFFFF |
| 배너 서브텍스트 | `Text` | "네트워크 연결 시 자동으로 전송됩니다", style: bodySmall (12sp), color: #FFFFFF (opacity 0.8) |
| 대기 카드 | `Card` | style: Card_Standard, radius16, padding: spacing16 |
| 실패 카드 | `Card` | style: Card_Alert, borderColor: semanticError (#DA4C51), radius16, padding: spacing16 |
| 상태 칩 (대기중) | `Chip` | style: Chip_Tag, backgroundColor: secondaryAmber (#FFC363), label: "⏳ 대기중", labelSmall |
| 상태 칩 (전송실패) | `Chip` | style: Chip_Tag, backgroundColor: semanticError (#DA4C51), textColor: #FFFFFF, label: "⚠️ 전송실패", labelSmall |
| 메시지 미리보기 | `Text` | style: bodyMedium (14sp), color: onSurface, maxLines: 2, overflow: ellipsis |
| 이미지 썸네일 | `ClipRRect` + `Image` | width: 48, height: 48, borderRadius: radius8 |
| 타임스탬프 | `Text` | style: bodySmall (12sp), color: onSurfaceVariant |
| 재시도 버튼 | `OutlinedButton` | style: Button_Secondary, text: "재시도", height: 36dp, 실패 카드에만 표시 |
| 삭제 버튼 | `TextButton` | text: "삭제", style: bodySmall, color: semanticError (#DA4C51) |
| 전체 삭제 | `TextButton` | text: "전체 삭제", style: bodyMedium, color: semanticError, 하단 고정, padding: spacing16 |

**상태 분기**

| 상태 | UI 변화 |
|------|---------|
| 대기 메시지 있음 | 카드 목록 표시, 큐 순서대로 나열 (가장 오래된 것이 상단) |
| 대기 메시지 없음 | 빈 상태 일러스트 + "전송 대기 중인 메시지가 없습니다" (bodyMedium, onSurfaceVariant) |
| 네트워크 복구 | 상태 배너 → 녹색 (#4CAF50) "온라인 - 전송 중...", 카드 순서대로 자동 전송 시작 |
| 자동 전송 중 | 해당 카드에 LinearProgressIndicator (primaryTeal) 표시 |
| 자동 전송 성공 | 카드 fade-out 애니메이션 (300ms) → 목록에서 제거 |
| 자동 전송 실패 | 대기중 → 전송실패 상태 변경, Card_Standard → Card_Alert, 재시도 버튼 표시 |
| 전체 전송 완료 | 빈 상태 표시 + Toast "모든 메시지가 전송되었습니다" |
| 삭제 확인 | Dialog_Confirm "이 메시지를 삭제하시겠습니까?" (확인/취소) |
| 전체 삭제 확인 | Dialog_Confirm "대기 중인 메시지 N건을 모두 삭제하시겠습니까?" (확인/취소) |

**인터랙션**

- [탭] ← 뒤로가기 → Navigator.pop → I-01 채팅 탭 복귀
- [탭] 재시도 (실패 카드) → 해당 메시지 재전송 시도 → 성공 시 카드 제거, 실패 시 Toast
- [탭] 삭제 (개별) → Dialog_Confirm → 확인 시 SQLite 큐에서 제거 + 카드 fade-out
- [탭] 전체 삭제 → Dialog_Confirm → 확인 시 전체 큐 클리어 + 빈 상태 표시
- [자동] 네트워크 복구 감지 (ConnectivityPlus) → 큐 순서대로 자동 전송 시작
- [자동] 전송 성공 → 카드 제거 + I-01 메시지 목록에 반영 (⏳ → 정상 표시)

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2026-03-03 | v1.0 | 최초 작성 -- 5개 화면 (I-01 ~ I-05) 5-섹션 템플릿 |

---

## 참조

- 글로벌 스타일 가이드: `docs/wireframes/00_Global_Style_Guide.md`
- 채팅탭 원칙: `Master_docs/20_T3_채팅탭_원칙.md`
- 화면 목업 계획: `docs/plans/2026-03-03-screen-design-mockup-plan.md`
- 오프라인 동작 원칙: `Master_docs/16_T2_오프라인_동작_통합_원칙.md`
- 비즈니스 원칙: `Master_docs/01_T1_SafeTrip_비즈니스_원칙_v5.1.md`
- 디자인 시스템: `docs/DESIGN.md`
