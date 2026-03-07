# Welcome Screen GAP Fix Design

| 항목 | 내용 |
|------|------|
| **날짜** | 2026-03-07 |
| **기준 문서** | DOC-T3-WLC-029 v1.2 |
| **목적** | 웰컴화면 코드와 원칙 문서 간 6건의 불일치 수정 |

## GAP 목록

### P0 — 원칙 위반
1. **§6.1, §6.2**: 딥링크 파싱 실패 시 Phase 3 직행 + 토스트 미구현

### P1 — 기능 누락
2. **§3.2**: 인디케이터 도트 탭 미구현
3. **§3.6**: A/B CTA 텍스트 변형 미적용

### P2 — 개선
4. **§3.5, §3.7**: 도트 인디케이터 Semantics 다국어
5. **§7.3**: 딥링크 직행 시 welcome_view analytics 미기록

### P3 — 테스트
6. **§10**: 테스트 커버리지 보강

## 수정 파일 (11개)

1. `deeplink_service.dart` — inviteDeeplinkReceived 플래그
2. `auth_notifier.dart` — inviteDeeplinkFailed 상태
3. `main.dart` — 딥링크 실패 전파
4. `app_router.dart` — 실패 플래그 라우팅
5. `welcome_dot_indicator.dart` — 탭 기능 + semantics 다국어
6. `screen_welcome.dart` — 도트 탭 핸들러
7. `screen_purpose_select.dart` — 토스트, A/B CTA, analytics
8. `welcome_strings.dart` — 새 문자열
9. `welcome_analytics.dart` — 중복 방지 플래그
10. `ab_test_service.dart` — 기존 활용 (변경 불필요)
11. `welcome_screen_test.dart` — 테스트 보강

## 구현 순서

1. 기반 수정 (deeplink_service, auth_notifier, main.dart, router)
2. UI 수정 (dot indicator, welcome strings, screens)
3. Analytics 수정
4. 테스트 작성 및 검증
