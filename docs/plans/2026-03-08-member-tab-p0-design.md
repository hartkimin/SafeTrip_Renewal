# 멤버탭 P0 원칙 준수 설계

| 항목 | 내용 |
|------|------|
| **날짜** | 2026-03-08 |
| **기준 문서** | DOC-T3-MBR-019 (멤버탭 원칙 v1.1) §15 P0 항목 |
| **범위** | P0 필수 항목 5건 (Phase 1) |
| **접근법** | 백엔드 API 보강 + 프론트엔드 데이터 연결 |

---

## 1. 문제 진단

### 1.1 근본 원인
백엔드 `getMembers(tripId)` (groups.service.ts:164)가 `tb_group_member` 엔티티만 raw 반환하여 Flutter가 필요한 필드가 누락:
- `user_name` / `display_name` / `profile_image_url` — `tb_user` JOIN 필요
- `is_online` / `battery_level` / `last_location_text` — RTDB 상태 병합 필요
- `guardian_links` — `tb_guardian_link` 서브쿼리 필요

### 1.2 현재 프론트엔드 상태
- 멤버 카드 위젯(`MemberCard`), 상태 점(`_StatusDot`), 역할 배지(`_RoleBadge`), SOS 강조 등 **UI 컴포넌트는 이미 구현 완료**
- 데이터가 비어있어 화면에 아무것도 표시되지 않음

---

## 2. P0 항목별 설계

### P0-1. 멤버 목록 표시 (기본 카드, 역할 배지)

**백엔드 변경:**
```sql
SELECT
  gm.user_id,
  u.display_name AS user_name,
  u.profile_image_url,
  gm.member_role,
  gm.b2b_role_name,
  u.birth_date,  -- 미성년자 판단용
  gm.location_sharing_enabled AS is_schedule_on
FROM tb_group_member gm
JOIN tb_user u ON gm.user_id = u.user_id
WHERE gm.trip_id = $1 AND gm.status = 'active'
ORDER BY
  CASE gm.member_role
    WHEN 'captain' THEN 0
    WHEN 'crew_chief' THEN 1
    WHEN 'crew' THEN 2
  END
```

**응답 필드 (멤버 1건):**
```json
{
  "user_id": "string",
  "user_name": "string",
  "profile_image_url": "string | null",
  "member_role": "captain | crew_chief | crew",
  "b2b_role_name": "string | null",
  "is_online": false,
  "is_sos_active": false,
  "battery_level": null,
  "last_location_text": null,
  "last_location_updated_at": null,
  "latitude": null,
  "longitude": null,
  "privacy_level": "standard",
  "is_schedule_on": true,
  "is_minor": false,
  "guardian_links": []
}
```

**프론트 변경:** 없음 — `TripMember.fromJson` 이미 호환

### P0-2. SOS 활성 멤버 강조 표시 (경고 배너)

- 이미 `_SosAlertBanner` 구현됨
- RTDB에서 SOS 상태를 병합하면 자동 동작
- 백엔드: RTDB `trips/{tripId}/members/{userId}/sos_active` 읽어서 `is_sos_active` 필드 설정

### P0-3. 온/오프라인 상태 인디케이터

- 이미 `_StatusDot` 구현됨 (녹색/회색/빨간 펄싱)
- 백엔드: RTDB `trips/{tripId}/members/{userId}/online` 읽어서 `is_online` 필드 설정

### P0-4. 역할별 섹션 분리 (관리자/멤버/보호자)

- 이미 `MemberTabState.adminMembers` / `crewMembers` 구현됨
- 보호자 섹션: 현재 `guardianSlots`를 `_GuardianSlotCard`로 표시 중
  → 가디언도 `tb_guardian_link` 기반으로 조회하여 표시
- **자기 자신 포함**: 멤버 목록 필터에서 currentUser를 제외하지 않음 (현재 코드에도 제외 로직 없음, 데이터만 오면 됨)

### P0-5. 가디언 무료/유료 배지 (🆓/💎)

- 이미 `MemberCard`에 `showGuardianBadge` / `isPaidGuardian` 속성 존재
- 백엔드: `tb_guardian_link.is_paid` 필드를 `guardian_links` 배열에 포함하여 반환
- 보호자 섹션 헤더에 슬롯 카운트 표시: `무료: N/2 사용 | 유료: N/3 사용`

---

## 3. RTDB 상태 병합 설계

### 3.1 RTDB 경로 구조
```
trips/{tripId}/members/{userId}/
  ├── online: boolean
  ├── sos_active: boolean
  ├── battery: number
  ├── latitude: number
  ├── longitude: number
  ├── location_text: string
  └── location_updated_at: number (timestamp ms)
```

### 3.2 병합 로직 (groups.service.ts)
```typescript
async getMembers(tripId: string) {
  // 1. PostgreSQL에서 멤버 + 유저 프로필 조회
  const members = await this.dataSource.query(JOIN_QUERY, [tripId]);

  // 2. RTDB에서 trip 멤버 상태 일괄 조회
  const rtdbRef = this.firebaseAdmin.database()
    .ref(`trips/${tripId}/members`);
  const snapshot = await rtdbRef.once('value');
  const rtdbData = snapshot.val() || {};

  // 3. 병합
  return members.map(m => ({
    ...m,
    is_online: rtdbData[m.user_id]?.online ?? false,
    is_sos_active: rtdbData[m.user_id]?.sos_active ?? false,
    battery_level: rtdbData[m.user_id]?.battery ?? null,
    latitude: rtdbData[m.user_id]?.latitude ?? null,
    longitude: rtdbData[m.user_id]?.longitude ?? null,
    last_location_text: rtdbData[m.user_id]?.location_text ?? null,
    last_location_updated_at: rtdbData[m.user_id]?.location_updated_at ?? null,
  }));
}
```

### 3.3 가디언 링크 서브쿼리
```sql
SELECT
  gl.id AS link_id,
  gl.guardian_user_id,
  gu.display_name AS guardian_name,
  gu.profile_image_url AS guardian_profile_image_url,
  gl.is_paid,
  gl.status,
  gl.payment_id,
  gl.paused_until
FROM tb_guardian_link gl
LEFT JOIN tb_user gu ON gl.guardian_user_id = gu.user_id
WHERE gl.trip_id = $1 AND gl.member_user_id = $2
  AND gl.status != 'rejected'
```

---

## 4. 변경 파일 목록

### 백엔드
| 파일 | 변경 내용 |
|------|----------|
| `groups.service.ts` | `getMembers()` — JOIN 쿼리 + RTDB 병합 + 가디언 링크 서브쿼리 |
| `groups.controller.ts` | 응답 래핑 (`{ success: true, data: [...] }`) |

### 프론트엔드
| 파일 | 변경 내용 |
|------|----------|
| `member_tab_provider.dart` | groupId/tripId 파라미터 정리 (API 호출 시 올바른 ID 사용 확인) |
| `bottom_sheet_2_member.dart` | 보호자 섹션 가디언 카드를 TripMember 기반으로 개선 (가디언 역할 멤버도 MemberCard로 표시) |

---

## 5. 비변경 사항 (P1 이후)

- 가디언 관리 하프시트 (P1)
- 멤버 정렬 규칙 전체 (P1) — 현재 기본 정렬은 구현됨
- 프라이버시 등급별 위치 텍스트 (P1) — `locationDisplayText` 이미 구현됨
- 가디언 전용 상태 탭 (P1)
- 배터리 인디케이터 20% 빨간색 (P1) — `_buildBatteryIndicator` 이미 구현됨
