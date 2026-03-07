# 멤버탭 원칙(DOC-T3-MBR-019) 전체 구현 설계

| 항목 | 내용 |
|------|------|
| **기준 문서** | `Master_docs/19_T3_멤버탭_원칙.md` (DOC-T3-MBR-019 v1.1) |
| **작성일** | 2026-03-07 |
| **범위** | Phase 1~3 전체 (P0→P1→P2→P3) |
| **방식** | 기존 코드 유지 + 갭 보완 |
| **스택** | Flutter (프론트엔드) + Node.js/TypeScript (백엔드) |

---

## 갭 분석 요약

| 영역 | 기존 상태 | 갭 |
|------|:---------:|-----|
| 멤버 목록/카드/정렬 | ✅ | 세부 규격(색상값, dp 등) 검증 |
| 역할별 섹션 분리 | ✅ | — |
| SOS/오프라인 경고 배너 | ⚠️ | 복수 멤버 배너, 요약/펼침 |
| 가디언 무료/유료 배지 | ✅ | — |
| 가디언 관리 하프시트 | ⚠️ | 과금 UI, 결제 모달, 해제 다이얼로그 |
| 프라이버시 등급별 위치 | ✅ | — |
| 배터리 인디케이터 | ✅ | — |
| 출석 체크 시스템 | ⚠️ | Firebase↔API 연동, 자동 absent |
| B2B 역할명 | ⚠️ | UI 표시 검증, 20자 말줄임 |
| 유료 가디언 일정 요약 | ❌ | 전체 구현 필요 |
| 긴급 위치 요청 | ✅ | 프라이버시 등급별 응답 차이 검증 |
| 미성년자 가디언 해제 승인 | ❌ | 전체 플로우 구현 |
| 오프라인 모드 배너/캐시 | ❌ | §14 전체 구현 |

---

## Phase 1 — 런칭 필수 (P0 + P1)

### 1-A. SOS/오프라인 경고 배너 (§3.3)

- `WarningBannerWidget` 신규 위젯
  - SOS 배너: 빨간 배경(`#F44336`), 멤버 이름 + 위치 + "지도에서 보기"
  - 오프라인 배너: 주황 배경, 2명+ → "N명이 오프라인" 요약 + 탭 펼침
  - SOS가 오프라인 배너 위에 표시

### 1-B. 가디언 관리 하프시트 완성 (§5.2~5.4)

- `GuardianManagementSheet` — 무료/유료 슬롯 구분, 해제 버튼
- `GuardianPaymentModal` — 1,900원 결제 확인
- `GuardianReleaseDialog` — 유료 환불불가 안내, 미성년자 캡틴 승인
- **백엔드**: `POST /api/v1/trips/:tripId/guardians/add-paid`
- **백엔드**: `DELETE /api/v1/trips/:tripId/guardians/:linkId`

### 1-C. 기존 코드 원칙 준수 검증

- `MemberCard` — §4.2 규격 (40dp 프로필, 8dp 상태점, 색상값)
- 정렬 규칙(§7.1) — 4단계 정렬 로직 검증
- 프라이버시 등급별 위치(§11) — `locationDisplayText` 검증

---

## Phase 2 — 확장 기능 (P2)

### 2-A. 출석 체크 시스템 (§8)

- **백엔드**:
  - `POST /api/v1/trips/:tripId/attendance` — 세션 생성 + FCM
  - `PATCH /api/v1/trips/:tripId/attendance/:checkId/respond`
  - `PATCH /api/v1/trips/:tripId/attendance/:checkId/close` — 자동 absent
- **Flutter**: `AttendanceProvider` ↔ Firebase RTDB 실시간 연동
  - 진행 중 배너 (남은 시간 + 카운트)
  - 10분 마감 자동 absent

### 2-B. B2B 역할명 (§6)

- `MemberCard` B2B 역할명 표시 검증
- 20자 초과 말줄임 + 롱탭 전체 표시

### 2-C. 유료 가디언 일정 요약 (§9.3)

- `bottom_sheet_guardian_members.dart` 일정 섹션 추가
- **백엔드**: `GET /api/v1/trips/:tripId/guardians/:linkId/schedule-summary`

### 2-D. 긴급 위치 요청 (§9.2)

- **백엔드**: `POST /api/v1/trips/:tripId/guardians/:linkId/location-request`
- 프라이버시 등급별 응답 (safety_first=자동, standard=1회성, privacy_first=승인)

---

## Phase 3 — 고급 기능 (P3)

### 3-A. 미성년자 가디언 해제 캡틴 승인 (§10.2)

- **백엔드**:
  - `POST /api/v1/trips/:tripId/guardians/:linkId/release-request`
  - `PATCH /api/v1/trips/:tripId/guardians/release-requests/:requestId`
  - DB: `tb_guardian_release_request` 테이블
- **Flutter**: 크루 해제 시도 → 캡틴 알림 → 승인/거부 → 자동 해제

### 3-B. 오프라인 모드 배너 및 캐시 (§14)

- `ConnectivityService` → `MemberTabProvider.setOfflineMode(true)`
- 오프라인 배너: "[오프라인 모드] 마지막 동기화: N분 전"
- 멤버/가디언 목록 로컬 캐시
- 출석 응답 오프라인 큐잉 → 복귀 시 자동 전송
- 동기화 우선순위: SOS > 가디언 > 위치/상태 > 출석

---

## 아키텍처 원칙 매핑

| 원칙 | 구현 포인트 |
|------|-----------|
| **M1 상태 중심** | 경고 배너 최상단, SOS 카드 강조, 상태 인디케이터 |
| **M2 역할 구분** | 섹션 분리, 배지 색상/아이콘, B2B 역할명 |
| **M3 위험 강조** | SOS 빨간 펄싱, 오프라인 주황 배너, 최상단 정렬 |
| **M4 원터치 액션** | 카드 탭 1회 → 위치/메시지/SOS 지원 |
| **M5 프라이버시 준수** | 등급별 위치 텍스트, 비공유 시간대 숨김 |

---

## 파일 구조 (신규/수정)

```
safetrip-mobile/lib/
├── widgets/
│   ├── warning_banner.dart          ← 신규 (1-A)
│   ├── member_card.dart             ← 수정 (1-C, 2-B)
│   └── guardian_badge.dart          ← 검증
├── screens/main/bottom_sheets/
│   ├── bottom_sheet_2_member.dart   ← 수정 (배너 통합)
│   ├── bottom_sheet_guardian_members.dart ← 수정 (2-C)
│   └── modals/
│       ├── guardian_management_sheet.dart ← 신규 (1-B)
│       ├── guardian_payment_modal.dart    ← 신규 (1-B)
│       └── attendance_modal.dart         ← 수정 (2-A)
├── features/member/providers/
│   └── member_tab_provider.dart     ← 수정 (3-B 오프라인)
├── features/trip/providers/
│   └── attendance_provider.dart     ← 수정 (2-A)
├── services/
│   ├── api_service.dart             ← 수정 (API 추가)
│   ├── attendance_service.dart      ← 수정 (2-A)
│   └── connectivity_service.dart    ← 신규 또는 수정 (3-B)

safetrip-server-api/src/modules/
├── guardian/
│   ├── guardian.controller.ts       ← 수정 (1-B, 2-D, 3-A)
│   └── guardian.service.ts          ← 수정
├── attendance/
│   ├── attendance.controller.ts     ← 수정 (2-A)
│   └── attendance.service.ts        ← 수정
└── migrations/
    └── XXXX-guardian-release-request.sql ← 신규 (3-A)
```
