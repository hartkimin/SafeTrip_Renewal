# 데모 데이터 보강 설계

**날짜**: 2026-03-08
**목적**: 일반 사용자 체험용 데모 데이터를 풍부하게 보강
**대상 시나리오**: S1 (학생 단체여행), S4 (가족여행)
**접근 방식**: 현실적 GPS 경로 + 지오펜스 정의 + 지도 표시

---

## 1. JSON 스키마 확장

### 1-1. `geofences` 필드 추가

각 시나리오 JSON에 최상위 필드로 `geofences` 배열 추가:

```json
"geofences": [
  {
    "id": "gf_seongsan",
    "name": "성산일출봉",
    "lat": 33.4621,
    "lng": 126.9407,
    "radius_m": 300,
    "schedule_day": 1,
    "active_from": "08:00",
    "active_to": "12:00",
    "color": "#4CAF50"
  }
]
```

**필드 설명:**
- `id`: 고유 식별자 (`gf_` 접두사)
- `name`: 지오펜스 장소명 (지도 라벨용)
- `lat/lng`: 중심 좌표
- `radius_m`: 반경 (200~600m, 장소 규모에 따라)
- `schedule_day`: 활성화 날짜 (1-indexed)
- `active_from/to`: 활성 시간대 (HH:MM, nullable → 종일)
- `color`: 지도 원형 오버레이 색상 (nullable → 기본 초록)

### 1-2. `location_tracks` 확장 전략

**S1 (33명):**
- 개별 상세 경로 4명: captain, chief1, chief2, crew01(이탈자)
- 그룹 대표 경로 4개: group_a~d (각 5명 학생 대표)
- 나머지 학생: 소속 그룹 대표 경로 + 미세 오프셋 (±0.00002°≈±2m)
- 가디언 10명: location_tracks 불필요 (원격 모니터링)

**S4 (6명):**
- 전원 개별 상세 경로 (가디언 2명은 한국 내 고정 위치)

**경로 포인트 밀도:**
- 장소 간 이동: 2~3개 중간 포인트
- 장소 체류: 2~4개 포인트 (미세 이동)
- 이탈 시나리오: 5~8개 포인트 (밀도 높게)
- 하루 기준 10~15개 포인트 / 멤버

### 1-3. `simulation_events` 확장

**S1**: 14개 → 25~30개
**S4**: 15개 → 30~35개

추가 이벤트 유형:
- 지오펜스 도착/출발 쌍 (각 장소)
- 인원 확인 이벤트 ("32/33명 도착")
- 가디언별 개별 알림 이벤트
- 배터리 부족 경고
- 다양한 채팅 메시지

---

## 2. S1 시나리오: 학생 단체여행 (제주도, 3일, 33명)

### 2-1. 지오펜스 정의 (11개)

| ID | 장소 | 반경(m) | Day | 시간 |
|---|---|---|---|---|
| gf_airport | 제주공항 | 500 | 1,3 | 도착/출발 |
| gf_seongsan | 성산일출봉 | 400 | 1 | 09:00~12:00 |
| gf_lunch_d1 | 점심식당(성산) | 200 | 1 | 12:00~13:30 |
| gf_manjang | 만장굴 | 350 | 1 | 14:00~16:30 |
| gf_hotel | 숙소(제주시) | 300 | 1,2,3 | 18:00~08:00 |
| gf_hallim | 한림공원 | 400 | 2 | 09:00~12:00 |
| gf_osulloc | 오설록 | 300 | 2 | 12:30~14:30 |
| gf_lunch_d2 | 점심식당(중문) | 200 | 2 | 14:30~15:30 |
| gf_jungmun | 중문관광단지 | 500 | 2 | 15:30~17:30 |
| gf_dongmun | 동문시장 | 300 | 3 | 09:00~11:30 |
| gf_yongduam | 용두암 | 250 | 3 | 12:00~13:30 |

### 2-2. location_tracks 구성

**개별 상세 경로:**
- `m_captain`: 전 일정 리더, 항상 선두
- `m_chief1`: captain과 유사, 약간 뒤
- `m_chief2`: 후미 담당, 그룹 뒤쪽
- `m_crew01`: Day 1 성산 이탈 → 복귀

**그룹 대표 경로:**
- `group_a` ~ `group_d`: captain 경로 기반 + 시간 오프셋

**그룹 배정:**
- group_a: crew02~crew06 (captain 근처)
- group_b: crew07~crew11 (chief1 근처)
- group_c: crew12~crew16 (chief2 근처)
- group_d: crew17~crew20 (captain 근처, 지연)

### 2-3. 시뮬레이션 이벤트 (25개)

Day 1:
1. trip_start: "제주도 수학여행 시작!"
2. geofence_in(gf_airport): "제주공항 도착"
3. all_arrived: "33/33명 공항 집합 완료"
4. geofence_out(gf_airport): "공항 출발"
5. geofence_in(gf_seongsan): "성산일출봉 도착"
6. all_arrived: "33/33명 성산일출봉 도착"
7. geofence_out(m_crew01): "학생 이탈 감지 — 김민준"
8. notification(guardian): "자녀 이탈 알림 발송"
9. chat_message(m_chief1): "김민준 학생 위치 확인 중"
10. geofence_in(m_crew01): "김민준 학생 복귀 완료"
11. notification(guardian): "자녀 복귀 알림"
12. geofence_in(gf_manjang): "만장굴 도착"
13. daily_summary: "Day 1 완료 — 이상 없음"

Day 2:
14. geofence_in(gf_hallim): "한림공원 도착"
15. all_arrived: "33/33명 도착"
16. battery_low(m_crew05): "학생 배터리 부족 (18%)"
17. geofence_in(gf_osulloc): "오설록 도착"
18. chat_message(m_captain): "자유시간 30분, 집합장소: 출구"
19. geofence_in(gf_jungmun): "중문관광단지 도착"
20. sos_drill(m_chief1): "SOS 모의훈련 시작"
21. sos_resolved: "SOS 모의훈련 종료 (5분)"
22. daily_summary: "Day 2 완료"

Day 3:
23. geofence_in(gf_dongmun): "동문시장 도착"
24. geofence_in(gf_yongduam): "용두암 도착"
25. trip_end: "제주도 수학여행 종료!"

---

## 3. S4 시나리오: 가족여행 (오사카, 5일, 6명)

### 3-1. 지오펜스 정의 (13개)

| ID | 장소 | 반경(m) | Day | 특이사항 |
|---|---|---|---|---|
| gf_kansai | 간사이공항 | 500 | 1,5 | 도착/출발 |
| gf_hotel | 난바 호텔 | 200 | 1~5 | 숙소 |
| gf_dotonbori | 도톤보리 | 350 | 1 | **아이 이탈** |
| gf_usj | USJ | 600 | 2 | 넓은 테마파크 |
| gf_castle | 오사카성 | 400 | 3 | |
| gf_kaiyukan | 카이유칸 수족관 | 300 | 3 | **SOS 발생** |
| gf_tempozan | 텐포잔 대관람차 | 250 | 3 | |
| gf_nara_park | 나라공원 | 500 | 4 | **사슴 추적 이탈** |
| gf_todaiji | 도다이지 | 300 | 4 | |
| gf_shinsaibashi | 신사이바시 | 400 | 5 | 쇼핑 |
| gf_lunch_d1 | 타코야키집 | 150 | 1 | |
| gf_lunch_d3 | 점심식당 | 150 | 3 | |
| gf_lunch_d4 | 나라 식당 | 150 | 4 | |

### 3-2. location_tracks (전원 6명)

**m_captain (아빠):** 전 일정 리더, 선두
**m_chief1 (엄마):** 아빠와 함께, 아이들 케어로 약간 뒤
**m_crew01 (딸, 12세):** 3건의 이탈/SOS 시나리오

핵심 이탈 경로:

**Day 1 도톤보리 이탈:**
```
19:00 가족 도톤보리 도착 (34.6687, 135.5027)
19:15 타코야키집 식사 (34.6690, 135.5030)
19:40 딸 글리코 간판 쪽 이동 (34.6693, 135.5022)
19:45 지오펜스 이탈 (250m+) → 가디언 알림
19:48 부모 채팅 "서아야 어디야!"
19:50 복귀 시작 (34.6695, 135.5018)
19:55 지오펜스 복귀 → 가디언 알림
```

**Day 3 수족관 SOS:**
```
14:30 카이유칸 입장 (34.6545, 135.4290)
15:00 상어 수조 앞 (34.6548, 135.4293)
15:10 부모와 분리 → SOS 발동 (34.6551, 135.4295)
15:11 가디언 SOS 알림
15:12 채팅 "서아야! 상어 수조 앞에 있어! 움직이지 마!"
15:15 부모 합류
15:16 SOS 해제 → 가디언 알림
```

**Day 4 나라 사슴 추격:**
```
10:00 나라공원 도착 (34.6851, 135.8430)
10:30 사슴 먹이주기 (34.6855, 135.8435)
10:40 딸 사슴 쫓아가며 이동 (34.6870, 135.8445)
10:45 지오펜스 이탈 → 가디언 알림
10:48 채팅 "서아야 너무 멀리 가지 마!"
10:52 복귀 (34.6855, 135.8435)
10:53 지오펜스 복귀 → 가디언 알림
```

**m_crew02 (아들, 9세):** 부모 경로와 유사, 수족관에서 부모 곁에 남음
**g_guard01 (외할머니):** 서울 (37.5665, 126.9780) 고정
**g_guard02 (친할아버지):** 부산 (35.1796, 129.0756) 고정

### 3-3. 시뮬레이션 이벤트 (32개)

Day 1:
1. trip_start: "오사카 가족여행 시작!"
2. geofence_in(gf_kansai): "간사이공항 도착"
3. geofence_in(gf_hotel): "호텔 체크인"
4. geofence_in(gf_dotonbori): "도톤보리 도착"
5. geofence_out(m_crew01): "서아 이탈 감지"
6. notification(g_guard01): "손녀 이탈 알림"
7. chat_message(m_captain): "서아야 어디야!"
8. geofence_in(m_crew01): "서아 복귀"
9. notification(g_guard01): "손녀 복귀 알림"
10. daily_summary: "Day 1 완료"

Day 2:
11. geofence_in(gf_usj): "USJ 도착!"
12. chat_message(m_crew01): "롤러코스터 무서워요!"
13. chat_message(m_chief1): "서아 잘하고 있어~"
14. battery_low(m_crew02): "준이 배터리 부족 (22%)"
15. daily_summary: "Day 2 완료"

Day 3:
16. geofence_in(gf_castle): "오사카성 도착"
17. geofence_in(gf_kaiyukan): "카이유칸 수족관 도착"
18. sos_start(m_crew01): "서아 SOS 발동!"
19. notification(g_guard01): "손녀 SOS 알림!"
20. notification(g_guard02): "손녀 SOS 알림!"
21. chat_message(m_captain): "서아야! 상어 수조 앞에 있어! 움직이지 마!"
22. sos_resolved(m_crew01): "서아 SOS 해제 — 부모 합류"
23. notification(g_guard01): "SOS 해제 알림"
24. geofence_in(gf_tempozan): "텐포잔 대관람차"
25. daily_summary: "Day 3 완료"

Day 4:
26. geofence_in(gf_nara_park): "나라공원 도착"
27. geofence_out(m_crew01): "서아 사슴 쫓아감 — 이탈"
28. notification(g_guard01): "손녀 이탈 알림"
29. chat_message(m_chief1): "서아야 너무 멀리 가지 마!"
30. geofence_in(m_crew01): "서아 복귀"
31. daily_summary: "Day 4 완료"

Day 5:
32. trip_end: "오사카 가족여행 종료!"

---

## 4. Dart 코드 변경

### 4-1. 모델 확장 (`demo_scenario.dart`)

```dart
class DemoGeofence {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int radiusM;
  final int scheduleDay;      // 또는 List<int> scheduleDays (복수 날짜)
  final String? activeFrom;
  final String? activeTo;
  final String? color;
}
```

`DemoScenario`에 `List<DemoGeofence> geofences` 필드 추가.

### 4-2. 어댑터 확장 (`demo_data_adapter.dart`)

```dart
static List<DemoGeofence> getActiveGeofences({
  required DemoScenario scenario,
  required int currentSimMinutes,
}) → 현재 시간에 활성화된 지오펜스만 필터링
```

### 4-3. 지도 Circle 오버레이

`demo_mode_wrapper.dart` 또는 `screen_main.dart`에서:
- 데모 모드일 때 `FlutterMap`에 `CircleLayer` 추가
- 반투명 원형 (opacity 0.15) + 테두리 (opacity 0.4)
- 중심에 장소명 라벨 (MarkerLayer)
- 시간 슬라이더 변경 시 활성 지오펜스 자동 갱신

### 4-4. 그룹 오프셋 로직 (`demo_location_simulator.dart`)

S1 대규모 그룹에서 `group_ref` 필드가 있는 멤버는 해당 그룹 대표 경로에서 미세 오프셋:

```dart
static LatLng applyGroupOffset(LatLng base, String memberId) {
  final hash = memberId.hashCode;
  final offsetLat = (hash % 100 - 50) * 0.00002;
  final offsetLng = ((hash ~/ 100) % 100 - 50) * 0.00002;
  return LatLng(base.latitude + offsetLat, base.longitude + offsetLng);
}
```

---

## 5. 변경 파일 목록

### JSON 데이터:
- `safetrip-mobile/assets/demo/scenario_s1.json` — 지오펜스 + location_tracks + events 보강
- `safetrip-mobile/assets/demo/scenario_s4.json` — 지오펜스 + location_tracks + events 보강

### Dart 코드:
- `lib/features/demo/models/demo_scenario.dart` — DemoGeofence 클래스 + 파싱
- `lib/features/demo/data/demo_data_adapter.dart` — getActiveGeofences() 메서드
- `lib/features/demo/data/demo_location_simulator.dart` — 그룹 오프셋 로직
- `lib/features/demo/presentation/widgets/demo_mode_wrapper.dart` — 지오펜스 지도 표시

### 영향 없는 파일 (변경 불필요):
- S2, S3, S5 시나리오 JSON (이번 범위 아님)
- 기존 UI 위젯들 (호환성 유지)
- 백엔드 코드 (데모는 순수 로컬)

---

## 6. 제약사항 및 고려사항

- JSON 파일 크기: S1은 ~80KB, S4는 ~30KB 예상 (기존 ~10KB, ~9KB)
- `pubspec.yaml`에 demo asset 경로 이미 등록됨
- 지오펜스 모델은 `scheduleDays: List<int>` 형태로 복수 날짜 지원 (호텔, 공항)
- Circle 오버레이는 flutter_map의 `CircleLayer` 위젯 사용
- 가디언은 location_tracks 없이 고정 좌표만 표시
