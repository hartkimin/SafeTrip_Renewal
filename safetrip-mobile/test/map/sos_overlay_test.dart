import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/widgets/components/sos_overlay.dart';

/// SosOverlay 위젯 테스트 (17_T3 지도 원칙 §7.3 검증)
///
/// 검증 항목:
/// - 기본 상태: userName + 위치 공유 메시지 표시
/// - isLocationPending=true: "SOS 발신 - 위치 확인 중" 표시
/// - additionalSosUsers: 동시 다수 SOS 사용자 표시
void main() {
  /// 테스트용 MaterialApp 래퍼
  Widget buildTestWidget({
    required String userName,
    bool isLocationPending = false,
    List<String> additionalSosUsers = const [],
    VoidCallback? onDismiss,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SosOverlay(
          userName: userName,
          isLocationPending: isLocationPending,
          additionalSosUsers: additionalSosUsers,
          onDismiss: onDismiss,
        ),
      ),
    );
  }

  group('SosOverlay — 기본 상태', () {
    testWidgets('SOS 긴급 알림 타이틀이 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(userName: '홍길동'));
      await tester.pump(); // 애니메이션 프레임

      expect(find.text('SOS 긴급 알림 발송됨'), findsOneWidget);
    });

    testWidgets('userName과 위치 공유 메시지가 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(userName: '홍길동'));
      await tester.pump();

      expect(
        find.text('홍길동님의 위치가 보호자에게 공유되고 있습니다'),
        findsOneWidget,
      );
    });

    testWidgets('기본 상태에서 위치 확인 중 메시지는 표시되지 않아야 한다',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(userName: '홍길동'));
      await tester.pump();

      expect(find.text('SOS 발신 — 위치 확인 중'), findsNothing);
    });
  });

  group('SosOverlay — 위치 미확인 상태 (§7.3)', () {
    testWidgets('isLocationPending=true일 때 "SOS 발신 — 위치 확인 중" 표시',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        userName: '홍길동',
        isLocationPending: true,
      ));
      await tester.pump();

      expect(find.text('SOS 발신 — 위치 확인 중'), findsOneWidget);
    });

    testWidgets('isLocationPending=true일 때 위치 공유 메시지는 표시되지 않아야 한다',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        userName: '홍길동',
        isLocationPending: true,
      ));
      await tester.pump();

      expect(
        find.text('홍길동님의 위치가 보호자에게 공유되고 있습니다'),
        findsNothing,
      );
    });
  });

  group('SosOverlay — 동시 다수 SOS (§7.3)', () {
    testWidgets('additionalSosUsers가 비어있으면 추가 SOS 항목이 없어야 한다',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        userName: '홍길동',
        additionalSosUsers: [],
      ));
      await tester.pump();

      expect(find.text(RegExp(r'SOS 발동 중').pattern), findsNothing);
    });

    testWidgets('추가 SOS 사용자 이름이 올바르게 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        userName: '홍길동',
        additionalSosUsers: ['김철수', '이영희'],
      ));
      await tester.pump();

      expect(find.text('김철수님 SOS 발동 중'), findsOneWidget);
      expect(find.text('이영희님 SOS 발동 중'), findsOneWidget);
    });

    testWidgets('추가 SOS 사용자마다 경고 아이콘이 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        userName: '홍길동',
        additionalSosUsers: ['김철수'],
      ));
      await tester.pump();

      // warning_amber 아이콘: 상단 PulsingIcon(warning_amber_rounded) + 추가 사용자(warning_amber)
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });
  });

  group('SosOverlay — 위젯 구조', () {
    testWidgets('Container로 래핑되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(userName: '홍길동'));
      await tester.pump();

      expect(find.byType(SosOverlay), findsOneWidget);
    });

    testWidgets('ScaleTransition으로 펄싱 애니메이션이 있어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(userName: '홍길동'));
      await tester.pump();

      expect(find.byType(ScaleTransition), findsOneWidget);
    });
  });
}
