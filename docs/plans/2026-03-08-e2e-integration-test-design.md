# SafeTrip E2E Integration Test Design

**Date**: 2026-03-08
**Type**: Flutter Integration Test (실제 UI 자동 조작)
**Backend**: Firebase Emulator + 로컬 NestJS 서버 (port 3001)
**Scope**: 전체 기능 커버리지 — 7개 Flow

---

## 디렉토리 구조

```
safetrip-mobile/
  integration_test/
    app_test.dart                ← 전체 실행 진입점
    flows/
      flow_1_onboarding.dart     ← 온보딩 (Welcome → Profile)
      flow_2_trip_create.dart    ← 여행 생성
      flow_3_main_screen.dart    ← 메인화면 (일정/멤버/채팅/가이드)
      flow_4_guardian.dart       ← 가디언 시스템
      flow_5_demo_mode.dart      ← 데모 모드
      flow_6_sos_offline.dart    ← SOS + 오프라인
      flow_7_settings.dart       ← 설정/프로필
    helpers/
      test_config.dart           ← 환경 설정 (emulator 주소)
      test_helpers.dart          ← 공통 유틸 (대기, 탭, 스크롤)
      firebase_test_helper.dart  ← Firebase Auth 테스트 헬퍼
    fixtures/
      test_data.dart             ← 테스트 데이터 상수
```

---

## Flow 1: 온보딩 (신규 유저)

| 단계 | 화면 | 검증 항목 |
|------|------|----------|
| 1-1 | Splash | 로고 표시 → 자동 전환 |
| 1-2 | Welcome | 4슬라이드 스와이프, 스킵 버튼 |
| 1-3 | Purpose Select | "여행 만들기" 선택 (Captain 역할) |
| 1-4 | Phone Auth | 전화번호 입력 → OTP 입력 |
| 1-5 | Terms Consent | 전체동의 체크 → 다음 |
| 1-6 | Birth Date | 성인 날짜 선택 |
| 1-7 | Profile Setup | 닉네임 + 아바타 선택 → 완료 |

- **Firebase Emulator**: `+82 010-0000-0000` / OTP `123456` 고정

---

## Flow 2: 여행 생성

| 단계 | 검증 항목 |
|------|----------|
| 2-1 | 여행 이름 입력 (2자 이상) |
| 2-2 | 국가 선택 (일본) |
| 2-3 | 도시 입력 (도쿄) |
| 2-4 | 날짜 범위 선택 (오늘 ~ 3일 후) |
| 2-5 | 생성 → API 호출 → 메인 화면 이동 확인 |

- **API**: `POST /api/v1/trips`
- **검증**: 메인 화면 로딩 + Trip 탭에 생성된 여행 표시

---

## Flow 3: 메인 화면 기능

| 단계 | 바텀시트 탭 | 검증 항목 |
|------|-----------|----------|
| 3-1 | Trip | 일정 추가 (제목, 시간, 장소) → 목록 표시 |
| 3-2 | Trip | 일정 수정/삭제 |
| 3-3 | Member | 멤버 목록 확인 (본인 = Captain) |
| 3-4 | Member | 초대 코드 생성 → 코드 표시 |
| 3-5 | Chat | 메시지 입력 → 전송 → 표시 확인 |
| 3-6 | Guide | 안전 가이드 5개 탭 로딩 |
| 3-7 | Map | 지도 표시, 레이어 토글, 줌 |

---

## Flow 4: 가디언 시스템

| 단계 | 검증 항목 |
|------|----------|
| 4-1 | 가디언 초대 링크 생성 (전화번호 입력) |
| 4-2 | 가디언 탭 초대 상태 (pending) |
| 4-3 | API 직접 호출로 가디언 수락 |
| 4-4 | 가디언 채팅 메시지 전송/수신 확인 |

- **API**: `POST /api/v1/trips/:tripId/guardians`, `PATCH .../respond`

---

## Flow 5: 데모 모드

| 단계 | 검증 항목 |
|------|----------|
| 5-1 | 로그아웃 → Purpose Select → "먼저 둘러보기" |
| 5-2 | 시나리오 선택 (T3_30) |
| 5-3 | 데모 메인화면 로딩 |
| 5-4 | 바텀시트 읽기 전용 확인 |
| 5-5 | 데모 종료 → 완료 화면 |

---

## Flow 6: SOS + 오프라인

| 단계 | 검증 항목 |
|------|----------|
| 6-1 | SOS 버튼 더블탭 → SOS 오버레이 |
| 6-2 | SOS 해제 → 오버레이 사라짐 |
| 6-3 | 오프라인 배너 표시 (connectivity mock) |
| 6-4 | 오프라인 일정 추가 → 로컬 저장 |

---

## Flow 7: 설정

| 단계 | 검증 항목 |
|------|----------|
| 7-1 | 프로필 화면 이동 → 정보 표시 |
| 7-2 | 닉네임 수정 → 저장 → 반영 |
| 7-3 | 로그아웃 → Welcome 복귀 |

---

## 기술적 고려사항

1. **Firebase Emulator 전화 인증**: 고정 번호/OTP 사용
2. **테스트 대기**: `pumpAndSettle()` + 커스텀 타임아웃
3. **네트워크**: Android 에뮬레이터 `10.0.2.2:3001`
4. **데이터 초기화**: 매 실행 전 Emulator 리셋
5. **실패 시 스크린샷**: 자동 캡처 저장
6. **Key 기반 위젯 탐색**: `Key('widget_name')` 또는 `find.byType()`
7. **역할별 접근**: Captain 기준 테스트 (Crew/Guardian은 API 레벨 검증)
