import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safetrip_mobile/services/profile_draft_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveDraft and loadDraft round-trips data', () async {
    await ProfileDraftService.saveDraft({'display_name': 'NewNick'});
    final draft = await ProfileDraftService.loadDraft();
    expect(draft?['display_name'], 'NewNick');
    expect(draft?['_saved_at'], isNotNull);
  });

  test('loadDraft returns null when no draft saved', () async {
    final draft = await ProfileDraftService.loadDraft();
    expect(draft, isNull);
  });

  test('clearDraft removes saved data', () async {
    await ProfileDraftService.saveDraft({'display_name': 'Test'});
    await ProfileDraftService.clearDraft();
    expect(await ProfileDraftService.hasDraft(), isFalse);
  });

  test('hasDraft returns true when draft exists', () async {
    expect(await ProfileDraftService.hasDraft(), isFalse);
    await ProfileDraftService.saveDraft({'display_name': 'Test'});
    expect(await ProfileDraftService.hasDraft(), isTrue);
  });
}
