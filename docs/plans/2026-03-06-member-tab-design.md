# Member Tab Implementation Design

**Date**: 2026-03-06
**Source**: `Master_docs/19_T3_멤버탭_원칙.md` (DOC-T3-MBR-019 v1.1)
**Scope**: Phase 1~3 전체 (P0~P3)

---

## Architecture

### Provider Layer (Riverpod)
- `MemberTabProvider` — 멤버 목록 fetch, 정렬, 섹션 분리
- `GuardianManageProvider` — 가디언 슬롯 관리, 과금 상태
- `AttendanceProvider` — 기존 확장 (실시간 배너, 6인 조건)
- `MemberPresenceProvider` — 온/오프라인, 배터리, SOS 상태

### UI Layer
```
bottom_sheet_2_member.dart (전면 재구현)
├── _WarningBanner (SOS/오프라인 경고)
├── _AttendanceBanner (출석체크 진행중)
├── _AdminSection (캡틴 + 크루장)
├── _MemberSection (크루)
├── _GuardianSection (무료/유료 구분)
└── _ActionButtons (멤버초대/가디언추가 — 캡틴/크루장만)

bottom_sheet_guardian_members.dart (가디언 상태탭 재구현)
├── _LinkedMemberCard (연결 멤버 정보)
├── _EmergencyLocationButton (긴급 위치 요청)
└── _ScheduleSummary (유료 가디언만)

widgets/member_card.dart (통합 멤버카드)
modals/guardian_manage_sheet.dart (가디언 관리 하프시트)
modals/guardian_payment_modal.dart (과금 결제 모달)
```

---

## Key Features

### Phase 1 (P0+P1)
- 멤버 목록 API 연동 (mock → real data)
- 역할별 섹션 분리 (관리자/멤버/보호자)
- SOS 경고 배너 + 카드 빨간 강조
- 온/오프라인 상태 인디케이터 (녹/회/펄싱)
- 가디언 무료/유료 배지 (🆓/💎)
- 가디언 관리 하프시트 (캡틴 전용)
- 가디언 과금 결제 모달
- 멤버 정렬 (SOS→역할→온오프→이름)
- 프라이버시 등급별 위치 텍스트
- 가디언 전용 상태 탭
- 배터리 인디케이터 (20% 빨간색)

### Phase 2 (P2)
- 출석 체크 시스템 (시작/응답/현황 배너)
- B2B 커스텀 역할명 표시
- 유료 가디언 일정 요약
- 긴급 위치 요청 (1시간 3회 제한)

### Phase 3 (P3)
- 미성년자 가디언 해제 캡틴 승인
- 오프라인 모드 배너 + 캐시 표시

---

## Sorting Algorithm (§7)

```
1. SOS active → top (red highlight)
2. Role: captain > crew_chief > crew > guardian(free) > guardian(paid)
3. Online > Offline
4. Name alphabetical (가나다순)
```

## Validation Strategy (3 rounds)
- Round 1: Implement + verify §16 checklist
- Round 2: Edge cases §12 full coverage
- Round 3: Role permissions §10 + Privacy §11 scenarios
