import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip_mobile/screens/main/bottom_sheets/modals/event_detail_modal.dart';

/// EventDetailModal 위젯 테스트 (17_T3 지도 원칙 §5.4 이벤트 마커 탭 검증)
///
/// 검증 항목:
/// - geofence_exit 타입: warning_amber_rounded 아이콘 + "지오펜스 이탈 경보" 타이틀
/// - attendance_check 타입: check_circle 아이콘 + "출석 체크 확인" 타이틀
/// - memberName, description, timestamp 표시
void main() {
  /// 테스트용 MaterialApp 래퍼
  Widget buildTestWidget({
    required String eventType,
    required String memberName,
    required String description,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
    String? geofenceName,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EventDetailModal(
          eventType: eventType,
          memberName: memberName,
          description: description,
          timestamp: timestamp,
          latitude: latitude,
          longitude: longitude,
          geofenceName: geofenceName,
        ),
      ),
    );
  }

  group('EventDetailModal — geofence_exit 타입', () {
    final testTimestamp = DateTime(2026, 3, 7, 14, 30);

    testWidgets('warning_amber_rounded 아이콘이 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '지정 구역을 이탈했습니다.',
        timestamp: testTimestamp,
      ));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('"지오펜스 이탈 경보" 타이틀이 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '지정 구역을 이탈했습니다.',
        timestamp: testTimestamp,
      ));

      expect(find.text('지오펜스 이탈 경보'), findsOneWidget);
    });
  });

  group('EventDetailModal — attendance_check 타입', () {
    final testTimestamp = DateTime(2026, 3, 7, 10, 0);

    testWidgets('check_circle 아이콘이 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'attendance_check',
        memberName: '김철수',
        description: '출석 체크가 완료되었습니다.',
        timestamp: testTimestamp,
      ));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('"출석 체크 확인" 타이틀이 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'attendance_check',
        memberName: '김철수',
        description: '출석 체크가 완료되었습니다.',
        timestamp: testTimestamp,
      ));

      expect(find.text('출석 체크 확인'), findsOneWidget);
    });
  });

  group('EventDetailModal — 기본(unknown) 타입', () {
    final testTimestamp = DateTime(2026, 3, 7, 16, 45);

    testWidgets('info 아이콘이 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'unknown_event',
        memberName: '이영희',
        description: '알 수 없는 이벤트입니다.',
        timestamp: testTimestamp,
      ));

      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('"이벤트 알림" 타이틀이 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'unknown_event',
        memberName: '이영희',
        description: '알 수 없는 이벤트입니다.',
        timestamp: testTimestamp,
      ));

      expect(find.text('이벤트 알림'), findsOneWidget);
    });
  });

  group('EventDetailModal — 멤버 정보 표시', () {
    final testTimestamp = DateTime(2026, 3, 7, 14, 30);

    testWidgets('memberName이 올바르게 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '지정 구역을 이탈했습니다.',
        timestamp: testTimestamp,
      ));

      expect(find.text('홍길동'), findsOneWidget);
    });

    testWidgets('memberName 첫 글자가 CircleAvatar에 표시되어야 한다',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '지정 구역을 이탈했습니다.',
        timestamp: testTimestamp,
      ));

      expect(find.byType(CircleAvatar), findsOneWidget);
      // CircleAvatar 안에 첫 글자 '홍' 확인
      expect(find.text('홍'), findsOneWidget);
    });

    testWidgets('description이 올바르게 표시되어야 한다', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'attendance_check',
        memberName: '김철수',
        description: '출석 체크가 완료되었습니다.',
        timestamp: testTimestamp,
      ));

      expect(find.text('출석 체크가 완료되었습니다.'), findsOneWidget);
    });
  });

  group('EventDetailModal — 타임스탬프 표시', () {
    testWidgets('날짜와 시간이 올바른 형식으로 표시되어야 한다', (tester) async {
      final testTimestamp = DateTime(2026, 3, 7, 14, 30);

      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '이탈 발생',
        timestamp: testTimestamp,
      ));

      // DateFormat('yyyy.MM.dd').format + ' ' + DateFormat('HH:mm').format
      expect(find.text('2026.03.07 14:30'), findsOneWidget);
    });

    testWidgets('자정 시간대도 올바르게 표시되어야 한다', (tester) async {
      final midnight = DateTime(2026, 1, 1, 0, 5);

      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '이탈 발생',
        timestamp: midnight,
      ));

      expect(find.text('2026.01.01 00:05'), findsOneWidget);
    });
  });

  group('EventDetailModal — 위치 정보 (선택적)', () {
    final testTimestamp = DateTime(2026, 3, 7, 14, 30);

    testWidgets('latitude/longitude가 제공되면 위치 텍스트가 표시되어야 한다',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '이탈 발생',
        timestamp: testTimestamp,
        latitude: 37.5665,
        longitude: 126.9780,
      ));

      expect(find.text('위치: 37.5665, 126.9780'), findsOneWidget);
    });

    testWidgets('latitude/longitude가 없으면 위치 텍스트가 표시되지 않아야 한다',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '이탈 발생',
        timestamp: testTimestamp,
      ));

      // "위치:" 로 시작하는 텍스트가 없어야 함
      expect(find.textContaining('위치:'), findsNothing);
    });
  });

  group('EventDetailModal — 닫기 버튼', () {
    testWidgets('닫기(close) 아이콘 버튼이 존재해야 한다', (tester) async {
      final testTimestamp = DateTime(2026, 3, 7, 14, 30);

      await tester.pumpWidget(buildTestWidget(
        eventType: 'geofence_exit',
        memberName: '홍길동',
        description: '이탈 발생',
        timestamp: testTimestamp,
      ));

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });
  });
}
