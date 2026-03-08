# Demo Scenario Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 기존 3개 데모 시나리오 JSON 보강 + 신규 2개(S4 가족여행, S5 커플여행) JSON 생성 + DemoScenario 모델에 s4/s5 추가 + 시나리오 선택 UI 업데이트

**Architecture:** 기존 `assets/demo/scenario_*.json` 구조를 그대로 사용. `DemoScenarioId` enum에 `s4`, `s5` 추가. 시나리오 선택 화면에 2개 카드 추가. DB 시드는 별도 Phase로 분리 (이 플랜 범위 밖).

**Tech Stack:** Flutter/Dart, JSON, Riverpod

**Design Doc:** `docs/plans/2026-03-08-demo-scenario-master-design.md`

---

## Task 1: S1 JSON 보강 — 채팅·가디언 알림 이벤트 추가

**Files:**
- Modify: `safetrip-mobile/assets/demo/scenario_s1.json:96-109` (simulation_events)

**Step 1: S1 simulation_events를 보강된 버전으로 교체**

기존 12개 → 20개 이벤트로 확대. 설계서 §2.2 기준으로 2일차·3일차 채팅, 가디언 알림 상세 추가.

`scenario_s1.json`의 `simulation_events` 배열을 다음으로 교체:

```json
"simulation_events": [
  {"time_offset_minutes": 0, "type": "trip_start", "description": "여행이 시작되었습니다"},
  {"time_offset_minutes": 30, "type": "geofence_in", "description": "성산일출봉 일정 구역에 도착했습니다", "member_id": "m_captain"},
  {"time_offset_minutes": 60, "type": "all_arrived", "description": "전원 성산일출봉 도착 확인"},
  {"time_offset_minutes": 120, "type": "geofence_out", "description": "정민수 학생이 일정 구역을 벗어났습니다", "member_id": "m_crew01"},
  {"time_offset_minutes": 125, "type": "notification", "description": "가디언 알림: 정민수 어머니에게 '정민수 학생 이탈 감지' 전송"},
  {"time_offset_minutes": 130, "type": "geofence_in", "description": "정민수 학생이 구역으로 복귀했습니다", "member_id": "m_crew01"},
  {"time_offset_minutes": 135, "type": "member_left", "description": "장우진 학생이 그룹에서 일시적으로 이탈했습니다", "member_id": "m_crew05"},
  {"time_offset_minutes": 240, "type": "sos_drill", "description": "SOS 모의 훈련 시작", "member_id": "m_chief1"},
  {"time_offset_minutes": 245, "type": "sos_resolved", "description": "SOS 모의 훈련 종료"},
  {"time_offset_minutes": 480, "type": "daily_summary", "description": "1일차 요약: 전원 안전, 이탈 1건 복귀 완료"},
  {"time_offset_minutes": 600, "type": "chat_message", "description": "이반장: 15:30 중문관광단지 주차장으로 다 모여주세요!", "member_id": "m_chief1"},
  {"time_offset_minutes": 630, "type": "all_arrived", "description": "전원 중문관광단지 주차장 집합 확인"},
  {"time_offset_minutes": 960, "type": "daily_summary", "description": "2일차 요약: 전원 안전, 이상 없음"},
  {"time_offset_minutes": 1020, "type": "chat_message", "description": "박반장: 시장 넓으니까 1반은 왼쪽, 2반은 오른쪽으로!", "member_id": "m_chief2"},
  {"time_offset_minutes": 1380, "type": "notification", "description": "가디언 알림: 학부모 전원에게 '여행이 안전하게 종료되었습니다' 전송"},
  {"time_offset_minutes": 1440, "type": "trip_end", "description": "여행이 종료되었습니다. 전원 안전 귀환!"}
]
```

**Step 2: 파일 저장 후 JSON 유효성 확인**

Run: `cd safetrip-mobile && python3 -c "import json; json.load(open('assets/demo/scenario_s1.json'))"`
Expected: 에러 없이 종료

**Step 3: Commit**

```bash
git add safetrip-mobile/assets/demo/scenario_s1.json
git commit -m "feat(demo): S1 시나리오 이벤트 보강 — 채팅·가디언 알림 추가"
```

---

## Task 2: S2 JSON 보강 — 채팅 7건 확대, Day 4 자유시간 상세

**Files:**
- Modify: `safetrip-mobile/assets/demo/scenario_s2.json:96-109` (simulation_events)

**Step 1: S2 simulation_events를 보강된 버전으로 교체**

기존 13개 → 22개 이벤트. 설계서 §3.3 기준으로 멤버별 채팅, Day 4 자유시간 이벤트 추가.

`scenario_s2.json`의 `simulation_events` 배열을 다음으로 교체:

```json
"simulation_events": [
  {"time_offset_minutes": 0, "type": "trip_start", "description": "도쿄 여행이 시작되었습니다!"},
  {"time_offset_minutes": 60, "type": "geofence_in", "description": "시부야 일정 구역 도착", "member_id": "m_captain"},
  {"time_offset_minutes": 180, "type": "chat_message", "description": "이수현: 시부야 인크레더블! 사진 많이 찍었어", "member_id": "m_chief1"},
  {"time_offset_minutes": 720, "type": "daily_summary", "description": "1일차 완료: 전원 안전"},
  {"time_offset_minutes": 1200, "type": "chat_message", "description": "정우빈: 여기 피규어 가게 미쳤다... 나 좀 더 볼게", "member_id": "m_crew03"},
  {"time_offset_minutes": 1230, "type": "schedule_changed", "description": "김지민이 일정 변경: 도쿄타워 17:00→18:00 (정우빈 기다려주자)", "member_id": "m_captain"},
  {"time_offset_minutes": 1440, "type": "daily_summary", "description": "2일차 완료: 전원 안전"},
  {"time_offset_minutes": 2160, "type": "geofence_out", "description": "한소율님이 하라주쿠에서 맛집 찾아 1km 이상 이동", "member_id": "m_crew04"},
  {"time_offset_minutes": 2170, "type": "geofence_in", "description": "한소율님 복귀 확인", "member_id": "m_crew04"},
  {"time_offset_minutes": 2880, "type": "notification", "description": "자유시간이 시작되었습니다. 18:00 이케부쿠로 집합!"},
  {"time_offset_minutes": 2910, "type": "geofence_out", "description": "박도윤님이 카마쿠라로 혼자 이동", "member_id": "m_crew01"},
  {"time_offset_minutes": 3000, "type": "chat_message", "description": "박도윤: 나 카마쿠라 왔어! 대불 보는 중 ㅋㅋ", "member_id": "m_crew01"},
  {"time_offset_minutes": 3120, "type": "chat_message", "description": "최하린: 나는 시모키타자와에서 빈티지 쇼핑 중~", "member_id": "m_crew02"},
  {"time_offset_minutes": 3180, "type": "chat_message", "description": "정우빈: 아키하바라 2차전... 지갑이 위험", "member_id": "m_crew03"},
  {"time_offset_minutes": 3330, "type": "notification", "description": "자유시간 종료 30분 전 알림"},
  {"time_offset_minutes": 3360, "type": "all_arrived", "description": "전원 이케부쿠로 집합 확인"},
  {"time_offset_minutes": 4320, "type": "sos_drill", "description": "SOS 연습 발동 (정우빈)", "member_id": "m_crew03"},
  {"time_offset_minutes": 4325, "type": "sos_resolved", "description": "SOS 연습 종료"},
  {"time_offset_minutes": 7200, "type": "daily_summary", "description": "5일차 완료: 전원 안전"},
  {"time_offset_minutes": 9360, "type": "chat_message", "description": "김지민: 다들 공항 13:30까지 와! 체크인 서둘러야 해", "member_id": "m_captain"},
  {"time_offset_minutes": 10080, "type": "trip_end", "description": "도쿄 여행 종료! 전원 안전 귀국"}
]
```

**Step 2: JSON 유효성 확인**

Run: `cd safetrip-mobile && python3 -c "import json; json.load(open('assets/demo/scenario_s2.json'))"`
Expected: 에러 없이 종료

**Step 3: Commit**

```bash
git add safetrip-mobile/assets/demo/scenario_s2.json
git commit -m "feat(demo): S2 시나리오 이벤트 보강 — 채팅 7건, Day 4 자유시간 상세"
```

---

## Task 3: S3 JSON 보강 — 채팅·프라이버시·가디언 연동 추가

**Files:**
- Modify: `safetrip-mobile/assets/demo/scenario_s3.json:96-109` (simulation_events)

**Step 1: S3 simulation_events를 보강된 버전으로 교체**

기존 12개 → 18개 이벤트. 설계서 §4.2 기준으로 채팅 2건, SOS 가디언 연동, 프라이버시 모드 시연.

`scenario_s3.json`의 `simulation_events` 배열을 다음으로 교체:

```json
"simulation_events": [
  {"time_offset_minutes": 0, "type": "trip_start", "description": "방콕 출장이 시작되었습니다"},
  {"time_offset_minutes": 60, "type": "geofence_in", "description": "호텔 도착 확인", "member_id": "m_captain"},
  {"time_offset_minutes": 120, "type": "all_arrived", "description": "전원 호텔 도착 확인"},
  {"time_offset_minutes": 200, "type": "member_left", "description": "김대리가 급한 업무 회의로 호텔 비즈니스센터 이동", "member_id": "m_crew01"},
  {"time_offset_minutes": 720, "type": "daily_summary", "description": "1일차 완료: 전원 안전"},
  {"time_offset_minutes": 1440, "type": "geofence_out", "description": "권대리님이 왓포에서 기념품 가게로 이탈", "member_id": "m_crew13"},
  {"time_offset_minutes": 1450, "type": "geofence_in", "description": "권대리님 복귀", "member_id": "m_crew13"},
  {"time_offset_minutes": 1560, "type": "chat_message", "description": "이과장: 카오산 로드 분위기 최고! 팀장님 맥주 한잔?", "member_id": "m_crew02"},
  {"time_offset_minutes": 1920, "type": "daily_summary", "description": "2일차 완료: 전원 안전"},
  {"time_offset_minutes": 2400, "type": "geofence_out", "description": "정사원님이 자유시간 중 방콕 시내 이동 (프라이버시 모드)", "member_id": "m_crew03"},
  {"time_offset_minutes": 2880, "type": "sos_drill", "description": "SOS 연습 발동 (김대리)", "member_id": "m_crew01"},
  {"time_offset_minutes": 2885, "type": "sos_resolved", "description": "SOS 연습 종료"},
  {"time_offset_minutes": 2890, "type": "notification", "description": "가디언 알림: 김대리 부모님에게 'SOS 연습이 실행되었습니다' 전송"},
  {"time_offset_minutes": 6480, "type": "chat_message", "description": "박팀장: 모두 수고했습니다! 공항 14시까지 도착 부탁드립니다", "member_id": "m_captain"},
  {"time_offset_minutes": 7200, "type": "trip_end", "description": "방콕 출장 종료! 전원 안전 귀국"}
]
```

**Step 2: JSON 유효성 확인**

Run: `cd safetrip-mobile && python3 -c "import json; json.load(open('assets/demo/scenario_s3.json'))"`
Expected: 에러 없이 종료

**Step 3: Commit**

```bash
git add safetrip-mobile/assets/demo/scenario_s3.json
git commit -m "feat(demo): S3 시나리오 이벤트 보강 — 채팅·SOS 가디언 연동 추가"
```

---

## Task 4: S4 JSON 생성 — 오사카 가족여행

**Files:**
- Create: `safetrip-mobile/assets/demo/scenario_s4.json`

**Step 1: S4 시나리오 JSON 파일 생성**

설계서 §5 전체 데이터를 JSON으로 작성. 구조는 기존 S1~S3과 동일한 스키마.

```json
{
  "scenario_id": "s4",
  "title": "가족 여행",
  "subtitle": "오사카 5일간 가족여행 · 안전최우선 모드",
  "privacy_grade": "safety_first",
  "duration_days": 5,
  "destination": {
    "name": "오사카",
    "country_code": "JP",
    "country_name": "일본",
    "lat": 34.6937,
    "lng": 135.5023,
    "timezone": "Asia/Tokyo"
  },
  "members": [
    {"id": "m_captain", "name": "김아빠", "role": "captain"},
    {"id": "m_chief1", "name": "이엄마", "role": "crew_chief"},
    {"id": "m_crew01", "name": "김하준", "role": "crew"},
    {"id": "m_crew02", "name": "김서아", "role": "crew"},
    {"id": "g_guard01", "name": "김할머니", "role": "guardian"},
    {"id": "g_guard02", "name": "이할아버지", "role": "guardian"}
  ],
  "guardian_links": [
    {"member_id": "m_crew01", "guardian_id": "g_guard01", "is_paid": false},
    {"member_id": "m_crew02", "guardian_id": "g_guard02", "is_paid": false}
  ],
  "schedules": [
    {
      "day": 1,
      "title": "오사카 도착 & 도톤보리",
      "items": [
        {"time": "11:00", "title": "간사이공항 도착", "lat": 34.4347, "lng": 135.2440},
        {"time": "13:30", "title": "호텔 체크인 (난바)", "lat": 34.6659, "lng": 135.5013},
        {"time": "15:00", "title": "도톤보리 산책", "lat": 34.6687, "lng": 135.5032},
        {"time": "17:00", "title": "저녁 (타코야키)", "lat": 34.6693, "lng": 135.5025}
      ]
    },
    {
      "day": 2,
      "title": "유니버설 스튜디오",
      "items": [
        {"time": "08:30", "title": "USJ 도착", "lat": 34.6654, "lng": 135.4323},
        {"time": "12:00", "title": "점심 (USJ 내)", "lat": 34.6660, "lng": 135.4330},
        {"time": "15:00", "title": "해리포터 존", "lat": 34.6668, "lng": 135.4318},
        {"time": "18:00", "title": "USJ 퇴장", "lat": 34.6654, "lng": 135.4323},
        {"time": "19:00", "title": "저녁 (오코노미야키)", "lat": 34.6700, "lng": 135.5000}
      ]
    },
    {
      "day": 3,
      "title": "오사카성 & 가이유칸",
      "items": [
        {"time": "09:00", "title": "오사카성", "lat": 34.6873, "lng": 135.5262},
        {"time": "12:00", "title": "점심 (우동)", "lat": 34.6850, "lng": 135.5250},
        {"time": "14:00", "title": "가이유칸 수족관", "lat": 34.6545, "lng": 135.4290},
        {"time": "17:00", "title": "덴포잔 대관람차", "lat": 34.6525, "lng": 135.4320}
      ]
    },
    {
      "day": 4,
      "title": "나라 당일치기",
      "items": [
        {"time": "09:00", "title": "나라역 도착", "lat": 34.6810, "lng": 135.8200},
        {"time": "09:30", "title": "나라공원 (사슴)", "lat": 34.6851, "lng": 135.8430},
        {"time": "12:00", "title": "점심", "lat": 34.6820, "lng": 135.8300},
        {"time": "14:00", "title": "도다이지", "lat": 34.6890, "lng": 135.8399},
        {"time": "16:00", "title": "오사카 복귀", "lat": 34.6937, "lng": 135.5023}
      ]
    },
    {
      "day": 5,
      "title": "신사이바시 쇼핑 & 귀국",
      "items": [
        {"time": "09:00", "title": "신사이바시 쇼핑", "lat": 34.6750, "lng": 135.5014},
        {"time": "12:00", "title": "점심 (라멘)", "lat": 34.6730, "lng": 135.5020},
        {"time": "14:00", "title": "간사이공항 출발", "lat": 34.4347, "lng": 135.2440}
      ]
    }
  ],
  "simulation_events": [
    {"time_offset_minutes": 0, "type": "trip_start", "description": "오사카 가족여행이 시작되었습니다!"},
    {"time_offset_minutes": 60, "type": "geofence_in", "description": "호텔 도착 확인", "member_id": "m_captain"},
    {"time_offset_minutes": 90, "type": "all_arrived", "description": "전원 호텔 도착 확인"},
    {"time_offset_minutes": 150, "type": "geofence_out", "description": "김하준(12세)이 도톤보리에서 게임센터 쪽으로 이탈", "member_id": "m_crew01"},
    {"time_offset_minutes": 152, "type": "notification", "description": "가디언 알림: 김할머니에게 '김하준이 일정 구역을 이탈했습니다' 전송"},
    {"time_offset_minutes": 155, "type": "chat_message", "description": "이엄마: 하준아 어디야? 빨리 타코야키 가게 앞으로 와!", "member_id": "m_chief1"},
    {"time_offset_minutes": 158, "type": "geofence_in", "description": "김하준이 구역으로 복귀했습니다", "member_id": "m_crew01"},
    {"time_offset_minutes": 480, "type": "daily_summary", "description": "1일차 요약: 전원 안전, 미성년자 이탈 1건 즉시 복귀"},
    {"time_offset_minutes": 540, "type": "geofence_in", "description": "USJ 도착", "member_id": "m_captain"},
    {"time_offset_minutes": 570, "type": "all_arrived", "description": "전원 USJ 진입 확인"},
    {"time_offset_minutes": 720, "type": "chat_message", "description": "김아빠: 해리포터 존 앞에서 만나요! 서아가 빨리 가고 싶대", "member_id": "m_captain"},
    {"time_offset_minutes": 960, "type": "daily_summary", "description": "2일차 요약: 전원 안전, 이상 없음"},
    {"time_offset_minutes": 1080, "type": "geofence_in", "description": "오사카성 도착", "member_id": "m_captain"},
    {"time_offset_minutes": 1260, "type": "sos_drill", "description": "김서아(9세)가 수족관에서 잠시 부모를 놓침 — SOS 발동", "member_id": "m_crew02"},
    {"time_offset_minutes": 1261, "type": "notification", "description": "가디언 알림: 이할아버지에게 '김서아 SOS 발동!' 전송"},
    {"time_offset_minutes": 1263, "type": "chat_message", "description": "이엄마: 서아야! 상어 수조 앞에 있어! 움직이지 마!", "member_id": "m_chief1"},
    {"time_offset_minutes": 1265, "type": "sos_resolved", "description": "SOS 해제 — 김서아 부모 합류 완료"},
    {"time_offset_minutes": 1266, "type": "notification", "description": "가디언 알림: 이할아버지에게 'SOS 해제, 안전 확인' 전송"},
    {"time_offset_minutes": 1440, "type": "daily_summary", "description": "3일차 요약: SOS 1건 발생, 5분 내 해결"},
    {"time_offset_minutes": 1560, "type": "geofence_in", "description": "나라공원 도착", "member_id": "m_captain"},
    {"time_offset_minutes": 1680, "type": "geofence_out", "description": "김하준이 사슴 쫓다가 이탈", "member_id": "m_crew01"},
    {"time_offset_minutes": 1682, "type": "notification", "description": "가디언 알림: 김할머니에게 '김하준 이탈 감지' 전송"},
    {"time_offset_minutes": 1685, "type": "chat_message", "description": "김아빠: 하준아, GPS 보니까 동대사 쪽이네. 거기서 기다려!", "member_id": "m_captain"},
    {"time_offset_minutes": 1690, "type": "geofence_in", "description": "김하준 복귀", "member_id": "m_crew01"},
    {"time_offset_minutes": 1920, "type": "daily_summary", "description": "4일차 요약: 미성년자 이탈 1건, 10분 내 복귀"},
    {"time_offset_minutes": 2400, "type": "notification", "description": "가디언 알림: 전원에게 '여행이 안전하게 종료되었습니다' 전송"},
    {"time_offset_minutes": 2400, "type": "trip_end", "description": "오사카 가족여행 종료! 전원 안전 귀환!"}
  ],
  "location_tracks": {
    "m_captain": [
      {"t": 0, "lat": 34.4347, "lng": 135.2440},
      {"t": 30, "lat": 34.5500, "lng": 135.3700},
      {"t": 60, "lat": 34.6659, "lng": 135.5013},
      {"t": 90, "lat": 34.6687, "lng": 135.5032},
      {"t": 120, "lat": 34.6693, "lng": 135.5025},
      {"t": 150, "lat": 34.6659, "lng": 135.5013},
      {"t": 180, "lat": 34.6654, "lng": 135.4323},
      {"t": 210, "lat": 34.6873, "lng": 135.5262}
    ],
    "m_crew01": [
      {"t": 0, "lat": 34.4347, "lng": 135.2440},
      {"t": 30, "lat": 34.5502, "lng": 135.3702},
      {"t": 60, "lat": 34.6660, "lng": 135.5015},
      {"t": 90, "lat": 34.6690, "lng": 135.5035},
      {"t": 95, "lat": 34.6720, "lng": 135.5060},
      {"t": 100, "lat": 34.6690, "lng": 135.5035},
      {"t": 120, "lat": 34.6695, "lng": 135.5027},
      {"t": 150, "lat": 34.6660, "lng": 135.5015},
      {"t": 180, "lat": 34.6656, "lng": 135.4325},
      {"t": 210, "lat": 34.6875, "lng": 135.5264}
    ],
    "m_chief1": [
      {"t": 0, "lat": 34.4347, "lng": 135.2440},
      {"t": 30, "lat": 34.5498, "lng": 135.3698},
      {"t": 60, "lat": 34.6658, "lng": 135.5011},
      {"t": 90, "lat": 34.6685, "lng": 135.5030},
      {"t": 120, "lat": 34.6691, "lng": 135.5023},
      {"t": 150, "lat": 34.6658, "lng": 135.5011},
      {"t": 180, "lat": 34.6652, "lng": 135.4321},
      {"t": 210, "lat": 34.6871, "lng": 135.5260}
    ]
  }
}
```

**Step 2: JSON 유효성 확인**

Run: `cd safetrip-mobile && python3 -c "import json; json.load(open('assets/demo/scenario_s4.json'))"`
Expected: 에러 없이 종료

**Step 3: Commit**

```bash
git add safetrip-mobile/assets/demo/scenario_s4.json
git commit -m "feat(demo): S4 오사카 가족여행 시나리오 JSON 추가"
```

---

## Task 5: S5 JSON 생성 — 다낭 커플여행

**Files:**
- Create: `safetrip-mobile/assets/demo/scenario_s5.json`

**Step 1: S5 시나리오 JSON 파일 생성**

설계서 §6 전체 데이터를 JSON으로 작성.

```json
{
  "scenario_id": "s5",
  "title": "커플 여행",
  "subtitle": "다낭 4일간 커플여행 · 프라이버시우선 모드",
  "privacy_grade": "privacy_first",
  "duration_days": 4,
  "destination": {
    "name": "다낭",
    "country_code": "VN",
    "country_name": "베트남",
    "lat": 16.0544,
    "lng": 108.2022,
    "timezone": "Asia/Ho_Chi_Minh"
  },
  "members": [
    {"id": "m_captain", "name": "박준혁", "role": "captain"},
    {"id": "m_crew01", "name": "서윤아", "role": "crew"},
    {"id": "g_guard01", "name": "서윤아 엄마", "role": "guardian"}
  ],
  "guardian_links": [
    {"member_id": "m_crew01", "guardian_id": "g_guard01", "is_paid": false}
  ],
  "schedules": [
    {
      "day": 1,
      "title": "다낭 도착 & 미케 비치",
      "items": [
        {"time": "13:00", "title": "다낭공항 도착", "lat": 16.0559, "lng": 108.1990},
        {"time": "15:00", "title": "호텔 체크인 (미케비치)", "lat": 16.0640, "lng": 108.2480},
        {"time": "16:30", "title": "미케 비치 산책", "lat": 16.0680, "lng": 108.2510},
        {"time": "18:30", "title": "저녁 (해산물)", "lat": 16.0620, "lng": 108.2450}
      ]
    },
    {
      "day": 2,
      "title": "바나힐즈",
      "items": [
        {"time": "08:00", "title": "호텔 출발", "lat": 16.0640, "lng": 108.2480},
        {"time": "09:30", "title": "바나힐즈 도착", "lat": 15.9977, "lng": 107.9961},
        {"time": "10:00", "title": "골든 브릿지", "lat": 16.0000, "lng": 107.9950},
        {"time": "12:00", "title": "점심 (바나힐즈 내)", "lat": 15.9985, "lng": 107.9965},
        {"time": "15:00", "title": "케이블카 하산", "lat": 15.9977, "lng": 107.9961},
        {"time": "17:00", "title": "호텔 복귀", "lat": 16.0640, "lng": 108.2480}
      ]
    },
    {
      "day": 3,
      "title": "호이안",
      "items": [
        {"time": "09:00", "title": "호이안 출발", "lat": 15.8801, "lng": 108.3380},
        {"time": "10:00", "title": "호이안 올드타운", "lat": 15.8775, "lng": 108.3380},
        {"time": "12:00", "title": "점심 (까오라우)", "lat": 15.8770, "lng": 108.3375},
        {"time": "14:00", "title": "아오자이 체험", "lat": 15.8780, "lng": 108.3370},
        {"time": "17:00", "title": "등불 시장", "lat": 15.8765, "lng": 108.3385},
        {"time": "19:00", "title": "다낭 복귀", "lat": 16.0640, "lng": 108.2480}
      ]
    },
    {
      "day": 4,
      "title": "한시장 & 귀국",
      "items": [
        {"time": "09:00", "title": "한시장 쇼핑", "lat": 16.0679, "lng": 108.2240},
        {"time": "10:30", "title": "용다리", "lat": 16.0611, "lng": 108.2279},
        {"time": "12:00", "title": "점심 (분짜)", "lat": 16.0650, "lng": 108.2260},
        {"time": "14:00", "title": "다낭공항 출발", "lat": 16.0559, "lng": 108.1990}
      ]
    }
  ],
  "simulation_events": [
    {"time_offset_minutes": 0, "type": "trip_start", "description": "다낭 커플여행이 시작되었습니다!"},
    {"time_offset_minutes": 60, "type": "geofence_in", "description": "호텔 도착", "member_id": "m_captain"},
    {"time_offset_minutes": 65, "type": "all_arrived", "description": "전원 도착 확인"},
    {"time_offset_minutes": 120, "type": "chat_message", "description": "서윤아: 비치 너무 이쁘다! 사진 찍어줘", "member_id": "m_crew01"},
    {"time_offset_minutes": 480, "type": "daily_summary", "description": "1일차 요약: 전원 안전"},
    {"time_offset_minutes": 570, "type": "geofence_in", "description": "바나힐즈 도착", "member_id": "m_captain"},
    {"time_offset_minutes": 630, "type": "chat_message", "description": "박준혁: 골든브릿지 도착! 줄 좀 서야 할 듯", "member_id": "m_captain"},
    {"time_offset_minutes": 780, "type": "schedule_changed", "description": "박준혁이 일정 변경: 케이블카 하산 15:00→16:00 (더 구경하고 싶대)", "member_id": "m_captain"},
    {"time_offset_minutes": 960, "type": "daily_summary", "description": "2일차 요약: 전원 안전"},
    {"time_offset_minutes": 1080, "type": "geofence_in", "description": "호이안 올드타운 도착", "member_id": "m_captain"},
    {"time_offset_minutes": 1350, "type": "geofence_out", "description": "서윤아가 아오자이 가게 찾아 올드타운 밖으로 이탈", "member_id": "m_crew01"},
    {"time_offset_minutes": 1352, "type": "notification", "description": "가디언 알림: 서윤아 엄마에게 '서윤아가 일정 구역을 이탈했습니다' 전송"},
    {"time_offset_minutes": 1355, "type": "chat_message", "description": "서윤아: 오빠 나 근처 예쁜 아오자이 가게 발견! 5분만!", "member_id": "m_crew01"},
    {"time_offset_minutes": 1360, "type": "geofence_in", "description": "서윤아 복귀", "member_id": "m_crew01"},
    {"time_offset_minutes": 1500, "type": "chat_message", "description": "서윤아: 등불 시장 분위기 최고...", "member_id": "m_crew01"},
    {"time_offset_minutes": 1440, "type": "daily_summary", "description": "3일차 요약: 이탈 1건, 즉시 복귀"},
    {"time_offset_minutes": 1560, "type": "chat_message", "description": "박준혁: 마지막 날이네... 한시장에서 선물 사자", "member_id": "m_captain"},
    {"time_offset_minutes": 1920, "type": "notification", "description": "가디언 알림: 서윤아 엄마에게 '여행이 안전하게 종료되었습니다' 전송"},
    {"time_offset_minutes": 1920, "type": "trip_end", "description": "다낭 커플여행 종료! 안전 귀국!"}
  ],
  "location_tracks": {
    "m_captain": [
      {"t": 0, "lat": 16.0559, "lng": 108.1990},
      {"t": 30, "lat": 16.0600, "lng": 108.2200},
      {"t": 60, "lat": 16.0640, "lng": 108.2480},
      {"t": 90, "lat": 16.0680, "lng": 108.2510},
      {"t": 120, "lat": 16.0640, "lng": 108.2480},
      {"t": 150, "lat": 15.9977, "lng": 107.9961},
      {"t": 180, "lat": 15.8775, "lng": 108.3380},
      {"t": 210, "lat": 16.0559, "lng": 108.1990}
    ],
    "m_crew01": [
      {"t": 0, "lat": 16.0559, "lng": 108.1990},
      {"t": 30, "lat": 16.0602, "lng": 108.2202},
      {"t": 60, "lat": 16.0642, "lng": 108.2482},
      {"t": 90, "lat": 16.0682, "lng": 108.2512},
      {"t": 120, "lat": 16.0642, "lng": 108.2482},
      {"t": 150, "lat": 15.9979, "lng": 107.9963},
      {"t": 175, "lat": 15.8775, "lng": 108.3380},
      {"t": 180, "lat": 15.8810, "lng": 108.3420},
      {"t": 185, "lat": 15.8775, "lng": 108.3380},
      {"t": 210, "lat": 16.0559, "lng": 108.1990}
    ]
  }
}
```

**Step 2: JSON 유효성 확인**

Run: `cd safetrip-mobile && python3 -c "import json; json.load(open('assets/demo/scenario_s5.json'))"`
Expected: 에러 없이 종료

**Step 3: Commit**

```bash
git add safetrip-mobile/assets/demo/scenario_s5.json
git commit -m "feat(demo): S5 다낭 커플여행 시나리오 JSON 추가"
```

---

## Task 6: DemoScenarioId enum에 s4, s5 추가

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/models/demo_scenario.dart:3`

**Step 1: enum 수정**

```dart
// Before (line 3):
enum DemoScenarioId { s1, s2, s3 }

// After:
enum DemoScenarioId { s1, s2, s3, s4, s5 }
```

이 변경만으로 `DemoScenarioLoader.load(DemoScenarioId.s4)` 호출이 가능해짐 — 로더는 이미 `id.name`으로 파일명을 생성하므로 (`assets/demo/scenario_s4.json`) 추가 수정 불필요.

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/demo/models/demo_scenario.dart
git commit -m "feat(demo): DemoScenarioId enum에 s4, s5 추가"
```

---

## Task 7: 시나리오 선택 화면에 S4, S5 카드 추가

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart:129-163`

**Step 1: S3 카드 뒤에 S4, S5 카드 추가**

기존 S3 카드(`_ScenarioCard(icon: Icons.business_center, ...)`) 다음에 추가:

```dart
const SizedBox(height: AppSpacing.md),
_ScenarioCard(
  icon: Icons.family_restroom,
  iconColor: AppColors.privacySafetyFirst,
  title: '가족 여행',
  subtitle: '오사카 5일 가족여행',
  memberCount: 6,
  durationDays: 5,
  gradeBadge: '안전최우선',
  gradeColor: AppColors.privacySafetyFirst,
  onTap: () => _selectScenario(DemoScenarioId.s4),
),
const SizedBox(height: AppSpacing.md),
_ScenarioCard(
  icon: Icons.favorite,
  iconColor: AppColors.privacyFirst,
  title: '커플 여행',
  subtitle: '다낭 4일 커플여행',
  memberCount: 3,
  durationDays: 4,
  gradeBadge: '프라이버시우선',
  gradeColor: AppColors.privacyFirst,
  onTap: () => _selectScenario(DemoScenarioId.s5),
),
```

**Step 2: Commit**

```bash
git add safetrip-mobile/lib/features/demo/presentation/screens/screen_demo_scenario_select.dart
git commit -m "feat(demo): 시나리오 선택 화면에 S4 가족여행, S5 커플여행 카드 추가"
```

---

## Task 8: 전체 JSON 유효성 + 로딩 테스트

**Files:**
- Read only — no modifications

**Step 1: 5개 JSON 전체 유효성 검증**

Run:
```bash
cd safetrip-mobile
for f in assets/demo/scenario_s{1,2,3,4,5}.json; do
  python3 -c "import json; d=json.load(open('$f')); print(f'✅ {\"$f\"}: {len(d[\"members\"])} members, {len(d[\"simulation_events\"])} events')" || echo "❌ $f: INVALID"
done
```

Expected:
```
✅ assets/demo/scenario_s1.json: 33 members, 16 events
✅ assets/demo/scenario_s2.json: 6 members, 21 events
✅ assets/demo/scenario_s3.json: 18 members, 15 events
✅ assets/demo/scenario_s4.json: 6 members, 27 events
✅ assets/demo/scenario_s5.json: 3 members, 19 events
```

**Step 2: Flutter analyze (컴파일 에러 확인)**

Run: `cd safetrip-mobile && flutter analyze --no-fatal-infos 2>&1 | tail -5`
Expected: `No issues found!` 또는 기존 warning만 (새 에러 없음)

---

## Summary

| Task | 내용 | 파일 |
|------|------|------|
| 1 | S1 이벤트 보강 | scenario_s1.json |
| 2 | S2 이벤트 보강 | scenario_s2.json |
| 3 | S3 이벤트 보강 | scenario_s3.json |
| 4 | S4 신규 JSON | scenario_s4.json (new) |
| 5 | S5 신규 JSON | scenario_s5.json (new) |
| 6 | enum 확장 | demo_scenario.dart |
| 7 | UI 카드 추가 | screen_demo_scenario_select.dart |
| 8 | 전체 검증 | read-only |
