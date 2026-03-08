import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safetrip_mobile/features/demo/presentation/widgets/demo_badge.dart';
import 'package:safetrip_mobile/features/demo/presentation/widgets/demo_mode_wrapper.dart';
import 'package:safetrip_mobile/router/route_paths.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────
  // Group 1: 시나리오 선택 화면 (5 tests)
  // ─────────────────────────────────────────────────────
  group('Group 1: 시나리오 선택 화면', () {
    testWidgets('1-1: AppBar에 "데모 체험" 타이틀 표시', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('데모 체험'), findsOneWidget);
    });

    testWidgets('1-2: 3개 시나리오 카드 렌더링', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('학생 단체 여행'), findsOneWidget);
      expect(find.text('친구들과 해외여행'), findsOneWidget);
      expect(find.text('해외 출장/패키지 투어'), findsOneWidget);
    });

    testWidgets('1-3: S1 카드에 33명, 3일, 안전최우선 표시', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('33명'), findsOneWidget);
      expect(find.text('3일'), findsOneWidget);
      expect(find.text('안전최우선'), findsOneWidget);
    });

    testWidgets('1-4: DemoBadge 표시', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.byType(DemoBadge), findsOneWidget);
    });

    testWidgets('1-5: 뒤로가기 버튼 존재', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────
  // Group 2: 시나리오 로딩 → 데모 메인 (2 tests)
  // ─────────────────────────────────────────────────────
  group('Group 2: 시나리오 로딩 → 데모 메인', () {
    testWidgets('2-1: S1 카드 탭 → 데모 메인 진입', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(DemoModeWrapper), findsOneWidget);
    });

    testWidgets('2-2: SharedPreferences에 데모 키 설정됨', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_demo_mode'), isTrue);
      expect(prefs.getString('demo_user_role'), equals('captain'));
      expect(prefs.getString('demo_group_id'), equals('demo_s1'));
    });
  });

  // ─────────────────────────────────────────────────────
  // Group 3: 데모 메인 UI 레이어 (6 tests)
  // ─────────────────────────────────────────────────────
  group('Group 3: 데모 메인 UI 레이어', () {
    Future<void> navigateToDemoMain(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('3-1: DemoBadge "데모 모드" 표시', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('데모 모드'), findsOneWidget);
    });

    testWidgets('3-2: DemoRolePanel "캡틴" 표시', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('캡틴'), findsOneWidget);
    });

    testWidgets('3-3: DemoTimeSlider with Slider 위젯', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('D-7'), findsOneWidget);
      expect(find.text('여행 중'), findsOneWidget);
    });

    testWidgets('3-4: ExitFab "실제 앱으로 전환"', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('실제 앱으로 전환'), findsOneWidget);
    });

    testWidgets('3-5: 가디언 비교 버튼', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('가디언 비교'), findsOneWidget);
    });

    testWidgets('3-6: 등급 비교 버튼', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('등급 비교'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────
  // Group 4: 역할 전환 (4 tests)
  // ─────────────────────────────────────────────────────
  group('Group 4: 역할 전환', () {
    Future<void> navigateToDemoMain(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('4-1: 초기 역할 캡틴', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('캡틴'), findsOneWidget);
    });

    testWidgets('4-2: 패널 탭 → 4개 역할 표시', (tester) async {
      await navigateToDemoMain(tester);
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      expect(find.text('캡틴'), findsWidgets);
      expect(find.text('크루장'), findsOneWidget);
      expect(find.text('크루'), findsOneWidget);
      expect(find.text('가디언'), findsOneWidget);
    });

    testWidgets('4-3: 크루 선택 → SharedPreferences 업데이트', (tester) async {
      await navigateToDemoMain(tester);
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('demo_user_role'), equals('crew'));
    });

    testWidgets('4-4: 크루에서 가디언 비교 잠금 (lock icon)', (tester) async {
      await navigateToDemoMain(tester);
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('크루'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────
  // Group 5: 타임 슬라이더 (3 tests)
  // ─────────────────────────────────────────────────────
  group('Group 5: 타임 슬라이더', () {
    Future<void> navigateToDemoMain(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('5-1: "D-7"과 "여행 중" 라벨', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.text('D-7'), findsOneWidget);
      expect(find.text('여행 중'), findsOneWidget);
    });

    testWidgets('5-2: Slider 위젯 존재', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('5-3: "D-Day" 포맷 현재 위치 표시', (tester) async {
      await navigateToDemoMain(tester);
      expect(find.textContaining('D-Day'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────
  // Group 6: 전환 모달 (3 tests)
  // ─────────────────────────────────────────────────────
  group('Group 6: 전환 모달', () {
    Future<void> navigateToDemoMain(WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('학생 단체 여행'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }

    testWidgets('6-1: ExitFab 탭 → 모달 표시', (tester) async {
      await navigateToDemoMain(tester);
      await tester.tap(find.text('실제 앱으로 전환'));
      await tester.pumpAndSettle();
      expect(find.text('SafeTrip 체험 완료!'), findsOneWidget);
    });

    testWidgets('6-2: 모달에 3개 CTA', (tester) async {
      await navigateToDemoMain(tester);
      await tester.tap(find.text('실제 앱으로 전환'));
      await tester.pumpAndSettle();
      expect(find.text('여행 만들기'), findsOneWidget);
      expect(find.text('초대코드로 참여'), findsOneWidget);
      expect(find.text('나중에 할게요'), findsOneWidget);
    });

    testWidgets('6-3: "나중에 할게요" → 데모 클리어', (tester) async {
      await navigateToDemoMain(tester);
      await tester.tap(find.text('실제 앱으로 전환'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('나중에 할게요'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_demo_mode'), isNull);
      expect(prefs.getString('demo_user_role'), isNull);
    });
  });

  // ─────────────────────────────────────────────────────
  // Group 7: 완료 화면 (5 tests)
  // ─────────────────────────────────────────────────────
  group('Group 7: 완료 화면', () {
    testWidgets('7-1: 완료 메시지', (tester) async {
      await tester.pumpWidget(
          buildTestApp(initialRoute: RoutePaths.demoComplete));
      await tester.pumpAndSettle();
      expect(find.text('데모 체험을 완료했습니다!'), findsOneWidget);
    });

    testWidgets('7-2: 체크 아이콘', (tester) async {
      await tester.pumpWidget(
          buildTestApp(initialRoute: RoutePaths.demoComplete));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('7-3: 3개 CTA 버튼 타입', (tester) async {
      await tester.pumpWidget(
          buildTestApp(initialRoute: RoutePaths.demoComplete));
      await tester.pumpAndSettle();
      expect(
          find.widgetWithText(ElevatedButton, '여행 만들기'), findsOneWidget);
      expect(
          find.widgetWithText(OutlinedButton, '초대코드로 참여'), findsOneWidget);
      expect(
          find.widgetWithText(TextButton, '나중에 할게요'), findsOneWidget);
    });

    testWidgets('7-4: DemoBadge 표시', (tester) async {
      await tester.pumpWidget(
          buildTestApp(initialRoute: RoutePaths.demoComplete));
      await tester.pumpAndSettle();
      expect(find.byType(DemoBadge), findsOneWidget);
    });

    testWidgets('7-5: "나중에 할게요" → 데모 상태 클리어', (tester) async {
      SharedPreferences.setMockInitialValues({
        'is_demo_mode': true,
        'demo_user_id': 'm_captain',
        'demo_user_name': '김선생',
        'demo_group_id': 'demo_s1',
        'demo_user_role': 'captain',
      });
      await tester.pumpWidget(
          buildTestApp(initialRoute: RoutePaths.demoComplete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('나중에 할게요'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_demo_mode'), isNull);
      expect(prefs.getString('demo_user_id'), isNull);
      expect(prefs.getString('demo_user_name'), isNull);
      expect(prefs.getString('demo_group_id'), isNull);
      expect(prefs.getString('demo_user_role'), isNull);
    });
  });
}
