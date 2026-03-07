# 바텀시트 타겟 버그 수정 설계

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-07 |
| 기준 문서 | DOC-T2-BSH-011 바텀시트 동작 규칙 v2.0 |
| 접근 방식 | 타겟 버그 수정 (접근 A) |

## 수정 항목

### 1. `_isProgrammaticMove` 타이밍 개선
- **파일**: `snapping_bottom_sheet.dart:90-95`
- **문제**: 350ms 하드코딩으로 실제 애니메이션 duration과 불일치
- **수정**: duration 파라미터 수신 → `duration + 50ms` 여유 적용
- **콜백 시그니처 변경**: `void Function()` → `void Function([Duration])`

### 2. Velocity 기반 직접 점프 허용 (§3.3)
- **파일**: `snapping_bottom_sheet.dart:97-133`
- **문제**: distance >= 3인 모든 점프를 리다이렉트 (velocity 무관)
- **수정**: 드래그 핸들에 velocity 캡처, velocity > 2000 dp/s 시 직접 전환 허용

### 3. 애니메이션 타이밍/커브 통일
- **파일**: `screen_main.dart`
- **수정**: SOS 해제 시 `Curves.elasticOut` → spring 느낌 반영 (스펙 §10.3)

### 4. 상세뷰 콜백 연결 (§7.4)
- **파일**: `bottom_sheet_2_member.dart`
- **문제**: `onEnterDetail`/`onExitDetail` 파라미터는 정의되었으나 멤버 카드 탭 시 호출 안됨
- **수정**: 멤버 카드 탭 → `onEnterDetail` 호출, 뒤로 → `onExitDetail` 호출

### 5. No-trip UI 동작 검증
- **파일**: `screen_main.dart`
- **상태**: 이미 구현됨 (CTA, 탭 비활성화), 동작 검증만 수행

## 테스트 시나리오 (10회)

| # | 시나리오 | 검증 항목 |
|---|---------|----------|
| 1 | 5단계 스냅 순회 | 모든 snap 포인트 도달 가능 |
| 2 | 동일 탭 재탭 | collapsed→half, half→collapsed, full→half |
| 3 | 다른 탭 전환 | 탭별 기본 높이/최소 높이 적용 |
| 4 | 키보드 출현/닫힘 | full 전환 + 이전 상태 복원 |
| 5 | SOS 발동/해제 | collapsed 잠금 + peek 복원 |
| 6 | No-trip 상태 | collapsed 고정 + CTA + 탭 비활성 |
| 7 | 두 손가락 스와이프 | collapsed→full 직접 전환 |
| 8 | 빠른 플릭 직접 점프 | velocity > 2000 허용 |
| 9 | 멤버 상세뷰 | full 전환 + 이전 레벨 복원 |
| 10 | 뒤로가기 | full→half → 종료 다이얼로그 |

## 영향 범위

- `snapping_bottom_sheet.dart` — 핵심 수정 (velocity, 타이밍)
- `screen_main.dart` — 애니메이션 커브 조정
- `bottom_sheet_2_member.dart` — 콜백 연결
- `main_screen_provider.dart` — 변경 없음
