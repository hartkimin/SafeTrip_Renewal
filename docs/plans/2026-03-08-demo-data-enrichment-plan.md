# 데모 데이터 보강 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** S1(학생단체)·S4(가족여행) 시나리오의 location_tracks를 전 멤버로 확장하고, geofences 정의를 JSON에 추가하여 지도에 Circle 오버레이로 표시

**Architecture:** JSON 스키마에 `geofences` 필드 추가 → Dart 모델 `DemoGeofence` 파싱 → `DemoDataAdapter`에서 활성 지오펜스 필터링 → `screen_main.dart`의 기존 `GeofenceMapRenderer` + `_geofenceCirclesNotifier`에 데모 데이터 주입. 멤버별 `group_ref` 필드로 대표 경로 참조 + 오프셋 적용.

**Tech Stack:** Flutter/Dart, flutter_map (CircleLayer), JSON asset, Riverpod

---

### Task 1: DemoGeofence 모델 추가 및 DemoScenario 파싱 확장

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/models/demo_scenario.dart`

**Step 1: DemoGeofence 클래스 추가**

`DemoLocationPoint` 클래스 위에 새 클래스를 추가:

```dart
class DemoGeofence {
  const DemoGeofence({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.scheduleDays,
    this.activeFrom,
    this.activeTo,
    this.color,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final int radiusM;
  final List<int> scheduleDays;
  final String? activeFrom;
  final String? activeTo;
  final String? color;

  LatLng get latLng => LatLng(lat, lng);

  factory DemoGeofence.fromJson(Map<String, dynamic> json) {
    // schedule_day can be int or list of ints
    final rawDay = json['schedule_day'];
    final List<int> days;
    if (rawDay is List) {
      days = rawDay.cast<int>();
    } else if (rawDay is int) {
      days = [rawDay];
    } else {
      days = [1];
    }

    return DemoGeofence(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: json['radius_m'] as int,
      scheduleDays: days,
      activeFrom: json['active_from'] as String?,
      activeTo: json['active_to'] as String?,
      color: json['color'] as String?,
    );
  }
}
```

**Step 2: DemoScenario에 geofences 필드 추가**

`DemoScenario` 클래스에 `final List<DemoGeofence> geofences;` 추가:

```dart
class DemoScenario {
  const DemoScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.privacyGrade,
    required this.durationDays,
    required this.destination,
    required this.members,
    required this.guardianLinks,
    required this.schedules,
    required this.simulationEvents,
    required this.locationTracks,
    this.geofences = const [],
  });

  // ... existing fields ...
  final List<DemoGeofence> geofences;
```

`fromJson` factory에 파싱 추가:

```dart
geofences: (json['geofences'] as List? ?? [])
    .map((e) => DemoGeofence.fromJson(e))
    .toList(),
```

**Step 3: DemoMember에 groupRef 필드 추가**

`DemoMember`에 선택 필드 추가:

```dart
/// 그룹 대표 경로 참조 (S1 대규모 그룹용)
final String? groupRef;
```

`fromJson`에 파싱 추가:

```dart
groupRef: json['group_ref'] as String?,
```

생성자에도 `this.groupRef` 추가.

**Step 4: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/features/demo/models/demo_scenario.dart`
Expected: No errors

**Step 5: 커밋**

```bash
git add safetrip-mobile/lib/features/demo/models/demo_scenario.dart
git commit -m "feat(demo): add DemoGeofence model and groupRef to DemoMember"
```

---

### Task 2: DemoLocationSimulator에 그룹 오프셋 로직 추가

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/data/demo_location_simulator.dart`

**Step 1: applyGroupOffset 정적 메서드 추가**

`_interpolate` 메서드 아래에 추가:

```dart
/// S1 등 대규모 그룹에서 그룹 대표 경로에 멤버별 미세 오프셋 적용.
/// 약 ±2m 범위 내 분산.
static LatLng applyGroupOffset(LatLng base, String memberId) {
  final hash = memberId.hashCode.abs();
  final offsetLat = ((hash % 100) - 50) * 0.00002;
  final offsetLng = (((hash ~/ 100) % 100) - 50) * 0.00002;
  return LatLng(base.latitude + offsetLat, base.longitude + offsetLng);
}
```

**Step 2: getPositions에서 groupRef 지원**

`getPositions` 메서드를 확장하여 location_tracks에 없는 멤버의 `groupRef`를 참조:

```dart
static Map<String, LatLng> getPositions({
  required DemoScenario scenario,
  required int currentSimMinutes,
}) {
  final result = <String, LatLng>{};

  // 1) location_tracks에 있는 멤버 직접 보간
  for (final entry in scenario.locationTracks.entries) {
    final memberId = entry.key;
    final points = entry.value;
    if (points.isEmpty) continue;
    result[memberId] = _interpolate(points, currentSimMinutes);
  }

  // 2) groupRef가 있는 멤버 → 참조 경로 + 오프셋
  for (final member in scenario.members) {
    if (result.containsKey(member.id)) continue;
    if (member.role == 'guardian') continue;

    if (member.groupRef != null) {
      final refPoints = scenario.locationTracks[member.groupRef];
      if (refPoints != null && refPoints.isNotEmpty) {
        final basePos = _interpolate(refPoints, currentSimMinutes);
        result[member.id] = applyGroupOffset(basePos, member.id);
        continue;
      }
    }

    // Fallback: destination 좌표
    // (getMemberData에서도 이 fallback을 사용)
  }

  return result;
}
```

**Step 3: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/features/demo/data/demo_location_simulator.dart`
Expected: No errors

**Step 4: 커밋**

```bash
git add safetrip-mobile/lib/features/demo/data/demo_location_simulator.dart
git commit -m "feat(demo): add group offset logic for large-group member tracking"
```

---

### Task 3: DemoDataAdapter에 getActiveGeofences 메서드 추가

**Files:**
- Modify: `safetrip-mobile/lib/features/demo/data/demo_data_adapter.dart`

**Step 1: getActiveGeofences 정적 메서드 추가**

Schedule 섹션 아래, Location data 섹션 위에 추가:

```dart
// ---------------------------------------------------------------------------
// Geofences (데모 지오펜스 필터링)
// ---------------------------------------------------------------------------

/// 현재 시뮬레이션 시간에 활성화된 지오펜스 목록 반환.
/// schedule_day와 active_from/to를 기반으로 필터링.
static List<DemoGeofence> getActiveGeofences({
  required DemoScenario scenario,
  required int currentSimMinutes,
}) {
  if (scenario.geofences.isEmpty) return [];

  final dayNumber = (currentSimMinutes ~/ (24 * 60)) + 1;
  final minuteInDay = currentSimMinutes % (24 * 60);

  return scenario.geofences.where((gf) {
    // Day 필터
    if (!gf.scheduleDays.contains(dayNumber)) return false;

    // 시간 필터 (activeFrom/To 없으면 종일 활성)
    if (gf.activeFrom != null && gf.activeTo != null) {
      final fromParts = gf.activeFrom!.split(':');
      final toParts = gf.activeTo!.split(':');
      final fromMinutes = (int.tryParse(fromParts[0]) ?? 0) * 60 +
          (fromParts.length > 1 ? (int.tryParse(fromParts[1]) ?? 0) : 0);
      final toMinutes = (int.tryParse(toParts[0]) ?? 0) * 60 +
          (toParts.length > 1 ? (int.tryParse(toParts[1]) ?? 0) : 0);

      // 야간 지오펜스 (예: 18:00~08:00) 지원
      if (fromMinutes > toMinutes) {
        if (minuteInDay < fromMinutes && minuteInDay > toMinutes) return false;
      } else {
        if (minuteInDay < fromMinutes || minuteInDay > toMinutes) return false;
      }
    }

    return true;
  }).toList();
}

/// 데모 지오펜스 → GeofenceData 변환 (GeofenceMapRenderer 호환).
static List<GeofenceData> toGeofenceData({
  required DemoScenario scenario,
  required int currentSimMinutes,
}) {
  final active = getActiveGeofences(
    scenario: scenario,
    currentSimMinutes: currentSimMinutes,
  );

  return active.map((gf) => GeofenceData(
    geofenceId: gf.id,
    name: gf.name,
    type: 'safe',
    shapeType: 'circle',
    centerLatitude: gf.lat,
    centerLongitude: gf.lng,
    radiusMeters: gf.radiusM,
    isActive: true,
  )).toList();
}
```

**Step 2: import GeofenceData 추가**

파일 상단에 import 추가:

```dart
import '../../../models/geofence.dart';
```

**Step 3: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/features/demo/data/demo_data_adapter.dart`
Expected: No errors

**Step 4: 커밋**

```bash
git add safetrip-mobile/lib/features/demo/data/demo_data_adapter.dart
git commit -m "feat(demo): add getActiveGeofences and toGeofenceData methods"
```

---

### Task 4: screen_main.dart에 데모 지오펜스 렌더링 통합

**Files:**
- Modify: `safetrip-mobile/lib/screens/main/screen_main.dart`

**Step 1: _initializeDemoMode에 지오펜스 렌더링 추가**

`_initializeDemoMode()` 메서드 내 `// 5d. Update schedule markers` 블록 아래에 추가:

```dart
// 5d-2. 데모 지오펜스 렌더링
final demoGeofences = DemoDataAdapter.toGeofenceData(
  scenario: scenario,
  currentSimMinutes: currentSimMinutes,
);
if (demoGeofences.isNotEmpty) {
  _geofenceMapRenderer.updateGeofencesOnMap(demoGeofences);
}
```

**Step 2: _setupDemoStateListener의 timeChanged 블록에 지오펜스 갱신 추가**

`_setupDemoStateListener()` 내 `if (timeChanged) { ... }` 블록 끝에 추가 (polylines 업데이트 바로 위):

```dart
// 데모 지오펜스 갱신 (day/시간 변경 시)
final demoGeofences = DemoDataAdapter.toGeofenceData(
  scenario: scenario,
  currentSimMinutes: currentSimMinutes,
);
_geofenceMapRenderer.updateGeofencesOnMap(demoGeofences);
```

**Step 3: 빌드 확인**

Run: `cd safetrip-mobile && flutter analyze lib/screens/main/screen_main.dart`
Expected: No errors (DemoDataAdapter import는 이미 존재)

**Step 4: 커밋**

```bash
git add safetrip-mobile/lib/screens/main/screen_main.dart
git commit -m "feat(demo): integrate geofence rendering in demo mode"
```

---

### Task 5: S1 시나리오 JSON 데이터 보강

**Files:**
- Modify: `safetrip-mobile/assets/demo/scenario_s1.json`

**Step 1: geofences 필드 추가**

`"schedules"` 키 앞에 `"geofences"` 배열 삽입 (11개 지오펜스):

```json
"geofences": [
  {"id": "gf_airport", "name": "제주공항", "lat": 33.5104, "lng": 126.4914, "radius_m": 500, "schedule_day": [1, 3]},
  {"id": "gf_seongsan", "name": "성산일출봉", "lat": 33.4621, "lng": 126.9407, "radius_m": 400, "schedule_day": 1, "active_from": "09:00", "active_to": "12:00"},
  {"id": "gf_lunch_d1", "name": "점심식당(성산)", "lat": 33.4580, "lng": 126.9300, "radius_m": 200, "schedule_day": 1, "active_from": "12:00", "active_to": "13:30"},
  {"id": "gf_manjang", "name": "만장굴", "lat": 33.5283, "lng": 126.7717, "radius_m": 350, "schedule_day": 1, "active_from": "14:00", "active_to": "16:30"},
  {"id": "gf_hotel", "name": "숙소", "lat": 33.4996, "lng": 126.5312, "radius_m": 300, "schedule_day": [1, 2, 3], "active_from": "17:00", "active_to": "09:00"},
  {"id": "gf_hallim", "name": "한림공원", "lat": 33.3884, "lng": 126.2392, "radius_m": 400, "schedule_day": 2, "active_from": "09:00", "active_to": "11:30"},
  {"id": "gf_osulloc", "name": "오설록", "lat": 33.3056, "lng": 126.2892, "radius_m": 300, "schedule_day": 2, "active_from": "11:30", "active_to": "13:00"},
  {"id": "gf_lunch_d2", "name": "점심식당(중문)", "lat": 33.2500, "lng": 126.2500, "radius_m": 200, "schedule_day": 2, "active_from": "13:00", "active_to": "15:00"},
  {"id": "gf_jungmun", "name": "중문관광단지", "lat": 33.2481, "lng": 126.4119, "radius_m": 500, "schedule_day": 2, "active_from": "15:00", "active_to": "17:00"},
  {"id": "gf_dongmun", "name": "동문시장", "lat": 33.5125, "lng": 126.5264, "radius_m": 300, "schedule_day": 3, "active_from": "09:00", "active_to": "11:00"},
  {"id": "gf_yongduam", "name": "용두암", "lat": 33.5168, "lng": 126.5109, "radius_m": 250, "schedule_day": 3, "active_from": "11:00", "active_to": "13:00"}
],
```

**Step 2: members에 group_ref 추가 (학생 20명)**

기존 학생 멤버에 `group_ref` 필드 추가:

- crew02~crew06: `"group_ref": "m_captain"` (Captain 따라감)
- crew07~crew11: `"group_ref": "m_chief1"` (Chief1 따라감)
- crew12~crew16: `"group_ref": "m_chief2"` (Chief2 따라감)
- crew17~crew20: `"group_ref": "m_captain"` (Captain 따라감, 약간 다른 오프셋)

crew01은 이미 개별 경로가 있으므로 group_ref 불필요.

**Step 3: location_tracks 확장**

기존 3명(m_captain, m_crew01, m_chief1)에 추가:

**m_chief2 (후미 담당, 3일치):**

Day 1 (t=0~480):
```json
"m_chief2": [
  {"t": 0, "lat": 33.5104, "lng": 126.4916},
  {"t": 12, "lat": 33.5078, "lng": 126.5005},
  {"t": 35, "lat": 33.4619, "lng": 126.9409},
  {"t": 65, "lat": 33.4619, "lng": 126.9409},
  {"t": 95, "lat": 33.4578, "lng": 126.9303},
  {"t": 125, "lat": 33.5281, "lng": 126.7720},
  {"t": 155, "lat": 33.5281, "lng": 126.7720},
  {"t": 185, "lat": 33.4994, "lng": 126.5315},
  {"t": 480, "lat": 33.4994, "lng": 126.5315},
  {"t": 510, "lat": 33.3882, "lng": 126.2395},
  {"t": 630, "lat": 33.3054, "lng": 126.2895},
  {"t": 720, "lat": 33.2502, "lng": 126.2503},
  {"t": 810, "lat": 33.2479, "lng": 126.4122},
  {"t": 900, "lat": 33.4994, "lng": 126.5315},
  {"t": 960, "lat": 33.4994, "lng": 126.5315},
  {"t": 990, "lat": 33.5123, "lng": 126.5267},
  {"t": 1080, "lat": 33.5166, "lng": 126.5112},
  {"t": 1200, "lat": 33.5098, "lng": 126.5203},
  {"t": 1350, "lat": 33.5104, "lng": 126.4916},
  {"t": 1440, "lat": 33.5104, "lng": 126.4916}
]
```

**m_captain 확장 (3일치):** 기존 Day 1(t=0~180) 유지 + Day 2~3 추가:

```json
"m_captain": [
  {"t": 0, "lat": 33.5104, "lng": 126.4914},
  {"t": 10, "lat": 33.5080, "lng": 126.5000},
  {"t": 30, "lat": 33.4621, "lng": 126.9407},
  {"t": 60, "lat": 33.4621, "lng": 126.9407},
  {"t": 90, "lat": 33.4580, "lng": 126.9300},
  {"t": 120, "lat": 33.5283, "lng": 126.7717},
  {"t": 150, "lat": 33.5283, "lng": 126.7717},
  {"t": 180, "lat": 33.4996, "lng": 126.5312},
  {"t": 480, "lat": 33.4996, "lng": 126.5312},
  {"t": 500, "lat": 33.3884, "lng": 126.2392},
  {"t": 620, "lat": 33.3056, "lng": 126.2892},
  {"t": 710, "lat": 33.2500, "lng": 126.2500},
  {"t": 800, "lat": 33.2481, "lng": 126.4119},
  {"t": 890, "lat": 33.4996, "lng": 126.5312},
  {"t": 960, "lat": 33.4996, "lng": 126.5312},
  {"t": 980, "lat": 33.5125, "lng": 126.5264},
  {"t": 1070, "lat": 33.5168, "lng": 126.5109},
  {"t": 1190, "lat": 33.5100, "lng": 126.5200},
  {"t": 1340, "lat": 33.5104, "lng": 126.4914},
  {"t": 1440, "lat": 33.5104, "lng": 126.4914}
]
```

**m_chief1 확장 (3일치):** 기존 Day 1 유지 + Day 2~3 추가 (captain과 유사하되 약간 뒤처짐).

**m_crew01 확장 (3일치):** 기존 Day 1 이탈 경로 유지 + Day 2~3 추가 (group_a 대표와 유사하되 captain 근처).

**Step 4: simulation_events 확장**

기존 14개 → 25개 확장 (설계문서 §2-3 기준). 지오펜스 도착/출발 쌍, 배터리 부족, 채팅 다양화 추가.

**Step 5: 전체 JSON이 유효한 JSON인지 확인**

Run: `cat safetrip-mobile/assets/demo/scenario_s1.json | python3 -m json.tool > /dev/null && echo "Valid JSON"`
Expected: "Valid JSON"

**Step 6: 커밋**

```bash
git add safetrip-mobile/assets/demo/scenario_s1.json
git commit -m "feat(demo): enrich S1 scenario with geofences, full location tracks, expanded events"
```

---

### Task 6: S4 시나리오 JSON 데이터 보강

**Files:**
- Modify: `safetrip-mobile/assets/demo/scenario_s4.json`

**Step 1: geofences 필드 추가 (13개)**

```json
"geofences": [
  {"id": "gf_kansai", "name": "간사이공항", "lat": 34.4347, "lng": 135.2440, "radius_m": 500, "schedule_day": [1, 5]},
  {"id": "gf_hotel", "name": "난바 호텔", "lat": 34.6659, "lng": 135.5013, "radius_m": 200, "schedule_day": [1, 2, 3, 4, 5], "active_from": "18:00", "active_to": "09:00"},
  {"id": "gf_dotonbori", "name": "도톤보리", "lat": 34.6687, "lng": 135.5032, "radius_m": 350, "schedule_day": 1, "active_from": "15:00", "active_to": "20:00"},
  {"id": "gf_usj", "name": "USJ", "lat": 34.6654, "lng": 135.4323, "radius_m": 600, "schedule_day": 2, "active_from": "08:00", "active_to": "19:00"},
  {"id": "gf_castle", "name": "오사카성", "lat": 34.6873, "lng": 135.5262, "radius_m": 400, "schedule_day": 3, "active_from": "09:00", "active_to": "12:00"},
  {"id": "gf_kaiyukan", "name": "카이유칸 수족관", "lat": 34.6545, "lng": 135.4290, "radius_m": 300, "schedule_day": 3, "active_from": "14:00", "active_to": "17:00"},
  {"id": "gf_tempozan", "name": "텐포잔 대관람차", "lat": 34.6525, "lng": 135.4320, "radius_m": 250, "schedule_day": 3, "active_from": "17:00", "active_to": "19:00"},
  {"id": "gf_nara_park", "name": "나라공원", "lat": 34.6851, "lng": 135.8430, "radius_m": 500, "schedule_day": 4, "active_from": "09:00", "active_to": "14:00"},
  {"id": "gf_todaiji", "name": "도다이지", "lat": 34.6890, "lng": 135.8399, "radius_m": 300, "schedule_day": 4, "active_from": "14:00", "active_to": "16:00"},
  {"id": "gf_shinsaibashi", "name": "신사이바시", "lat": 34.6750, "lng": 135.5014, "radius_m": 400, "schedule_day": 5, "active_from": "09:00", "active_to": "13:00"},
  {"id": "gf_lunch_d1", "name": "타코야키 거리", "lat": 34.6693, "lng": 135.5025, "radius_m": 150, "schedule_day": 1, "active_from": "17:00", "active_to": "19:00"},
  {"id": "gf_lunch_d3", "name": "우동집", "lat": 34.6850, "lng": 135.5250, "radius_m": 150, "schedule_day": 3, "active_from": "12:00", "active_to": "13:30"},
  {"id": "gf_lunch_d4", "name": "나라 식당", "lat": 34.6820, "lng": 135.8300, "radius_m": 150, "schedule_day": 4, "active_from": "12:00", "active_to": "13:30"}
],
```

**Step 2: location_tracks 전원 확장 (4명 크루 + 2명 가디언 고정)**

기존 3명(m_captain, m_crew01, m_chief1)을 5일치로 확장 + m_crew02 추가:

**m_captain (아빠, 5일치):**

t=0~480 (Day1), t=480~960 (Day2), t=960~1440 (Day3), t=1440~1920 (Day4), t=1920~2400 (Day5)

각 일정 장소 좌표를 포인트로 연결, 장소 간 이동에 2~3개 중간 포인트 추가.

**m_chief1 (엄마, 5일치):**

captain과 유사하되 약간 뒤처지는 좌표 (±0.0002° 오프셋).

**m_crew01 (하준, 12세, 5일치):**

Day 1 도톤보리 이탈, Day 4 나라 사슴 이탈 포함. 이탈 구간에서 5~8개 포인트로 밀도 높게.

**m_crew02 (서아, 9세, 5일치):**

부모 경로와 유사하되, Day 3 수족관에서 분리 → SOS → 합류 경로 5개 포인트.

**g_guard01 (할머니):** 서울 좌표 단일 포인트
```json
"g_guard01": [{"t": 0, "lat": 37.5665, "lng": 126.9780}]
```

**g_guard02 (할아버지):** 부산 좌표 단일 포인트
```json
"g_guard02": [{"t": 0, "lat": 35.1796, "lng": 129.0756}]
```

**Step 3: simulation_events 확장**

기존 이벤트를 유지하면서 지오펜스 이벤트, 채팅, 배터리 알림을 추가하여 약 30개로 확장.

**Step 4: JSON 유효성 확인**

Run: `cat safetrip-mobile/assets/demo/scenario_s4.json | python3 -m json.tool > /dev/null && echo "Valid JSON"`
Expected: "Valid JSON"

**Step 5: 커밋**

```bash
git add safetrip-mobile/assets/demo/scenario_s4.json
git commit -m "feat(demo): enrich S4 scenario with geofences, full member tracks, expanded events"
```

---

### Task 7: S2, S3, S5 호환성 보장 (빈 geofences)

**Files:**
- No file changes needed (geofences 기본값이 `const []`)

**Step 1: 기존 시나리오 동작 확인**

S2, S3, S5 JSON에는 `geofences` 키가 없으므로 `DemoScenario.fromJson`에서 `json['geofences'] as List? ?? []`로 빈 리스트 반환 확인.

Run: `cd safetrip-mobile && flutter analyze`
Expected: No errors

**Step 2: 커밋 불필요**

기존 코드의 기본값 처리로 호환성 자동 보장.

---

### Task 8: 전체 빌드 및 수동 검증

**Files:**
- None (검증만)

**Step 1: 전체 빌드**

Run: `cd safetrip-mobile && flutter build apk --debug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

**Step 2: 수동 검증 항목 체크리스트**

앱 실행 후 확인:
1. 시나리오 선택 화면에서 S1, S4 선택 가능
2. S1 선택 → 지도에 33명 마커 표시 (그룹 오프셋 적용된 학생들)
3. S1 타임 슬라이더 이동 → 지오펜스 원형이 일정 장소에 표시
4. S1 Day 변경 → 해당 Day 지오펜스만 표시
5. S4 선택 → 6명 전원 마커 표시
6. S4 Day 3 시간에 SOS 이벤트 발생 시 수족관 지오펜스 표시
7. S2, S3, S5 → 기존과 동일 (지오펜스 없음)

**Step 3: 최종 커밋 없음 (검증만)**
