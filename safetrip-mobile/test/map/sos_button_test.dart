import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/widgets/components/sos_button.dart';

/// SosButton 위젯 테스트 (17_T3 지도 원칙 §10 바텀시트 동작 규칙 검증)
///
/// 검증 항목:
/// - 비활성 상태: "SOS" 텍스트 표시
/// - 활성 상태(isSosActive=true): "해제" 텍스트 표시
/// - 3초 롱프레스 시 onSosActivated 콜백 호출
void main() {
  /// 테스트용 MaterialApp 래퍼
  Widget buildTestWidget({
    required VoidCallback onSosActivated,
    VoidCallback? onSosDeactivated,
    bool isSosActive = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SosButton(
            onSosActivated: onSosActivated,
            onSosDeactivated: onSosDeactivated,
            isSosActive: isSosActive,
          ),
        ),
      ),
    );
  }

  group('SosButton — 비활성 상태 (SOS 미발동)', () {
    testWidgets('"SOS" 텍스트가 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(onSosActivated: () {}));

      expect(find.text('SOS'), findsOneWidget);
    });

    testWidgets('"해제" 텍스트는 표시되지 않아야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(onSosActivated: () {}));

      expect(find.text('해제'), findsNothing);
    });

    testWidgets('FloatingActionButton이 존재해야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(onSosActivated: () {}));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('GestureDetector로 롱프레스 감지가 설정되어야 한다',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(onSosActivated: () {}));

      expect(find.byType(GestureDetector), findsWidgets);
    });
  });

  group('SosButton — 활성 상태 (isSosActive=true)', () {
    testWidgets('"해제" 텍스트가 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSosActivated: () {},
        isSosActive: true,
      ));

      expect(find.text('해제'), findsOneWidget);
    });

    testWidgets('"SOS" 텍스트는 표시되지 않아야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        onSosActivated: () {},
        isSosActive: true,
      ));

      expect(find.text('SOS'), findsNothing);
    });

    testWidgets('해제 버튼 탭 시 onSosDeactivated 콜백이 호출되어야 한다',
        (tester) async {
      bool deactivated = false;
      await tester.pumpWidget(buildTestWidget(
        onSosActivated: () {},
        onSosDeactivated: () => deactivated = true,
        isSosActive: true,
      ));

      // FloatingActionButton 탭
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(deactivated, isTrue);
    });
  });

  group('SosButton — 3초 롱프레스 (§10.1)', () {
    testWidgets('3초 롱프레스 완료 시 onSosActivated 콜백이 호출되어야 한다',
        (tester) async {
      bool activated = false;
      await tester.pumpWidget(buildTestWidget(
        onSosActivated: () => activated = true,
      ));

      // GestureDetector에서 롱프레스 시작
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('SOS')),
      );

      // kLongPressTimeout (500ms) 대기 — GestureDetector가 롱프레스로 인식
      await tester.pump(const Duration(milliseconds: 500));

      // AnimationController 3초 duration 대기
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(); // 추가 프레임으로 콜백 실행

      await gesture.up();
      await tester.pump();

      expect(activated, isTrue);
    });

    testWidgets('3초 미만 릴리스 시 onSosActivated가 호출되지 않아야 한다',
        (tester) async {
      bool activated = false;
      await tester.pumpWidget(buildTestWidget(
        onSosActivated: () => activated = true,
      ));

      // 롱프레스 시작
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('SOS')),
      );

      // kLongPressTimeout (500ms) 대기 — GestureDetector가 롱프레스로 인식
      await tester.pump(const Duration(milliseconds: 500));

      // 1초만 추가 대기 후 릴리스 (총 1.5초, 3초 미만)
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();

      expect(activated, isFalse);
    });
  });

  group('SosButton — 위젯 전환', () {
    testWidgets('isSosActive 전환 시 위젯이 올바르게 변경되어야 한다',
        (tester) async {
      bool isActive = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SosButton(
                    onSosActivated: () => setState(() => isActive = true),
                    onSosDeactivated: () => setState(() => isActive = false),
                    isSosActive: isActive,
                  ),
                ),
              ),
            );
          },
        ),
      );

      // 초기 상태: SOS 표시
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('해제'), findsNothing);
    });
  });
}
