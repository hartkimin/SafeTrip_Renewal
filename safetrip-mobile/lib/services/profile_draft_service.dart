import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 프로필 편집 오프라인 임시 저장 서비스 (DOC-T3-PRF-027 §12)
///
/// 오프라인 상태에서 프로필 편집 시 로컬에 draft로 저장하고,
/// 네트워크 복귀 시 동기화 팝업을 통해 서버와 동기화한다.
///
/// 허용 항목: 닉네임 변경, 긴급연락처 수정 (임시 저장)
/// 비허용 항목: 프로필 사진 업로드, 계정 삭제 (서버 필수)
class ProfileDraftService {
  static const _draftKey = 'profile_edit_draft';

  /// 변경 사항을 로컬에 임시 저장
  static Future<void> saveDraft(Map<String, dynamic> changes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode({
      ...changes,
      '_saved_at': DateTime.now().toIso8601String(),
    }));
  }

  /// 저장된 draft 불러오기
  static Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_draftKey);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// draft 삭제 (동기화 완료 후)
  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  /// draft 존재 여부 확인
  static Future<bool> hasDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_draftKey);
  }
}
