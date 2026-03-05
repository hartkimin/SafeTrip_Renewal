import 'package:flutter/foundation.dart';

import 'app_cache.dart';

/// 보호자 필터링 유틸리티
///
/// 보호자 로그인인 경우 보호대상만 필터링하여 반환합니다.
class GuardianFilter {
  /// 보호자 필터링 (클라이언트 측 이중 체크)
  ///
  /// 보호자가 아닌 경우 모든 멤버를 반환하고,
  /// 보호자인 경우 보호대상만 필터링하여 반환합니다.
  ///
  /// [members] 멤버 리스트
  /// 
  /// Returns 필터링된 멤버 리스트
  static Future<List<Map<String, dynamic>>> filterMembersForGuardian(
    List<Map<String, dynamic>> members,
  ) async {
    try {
      final currentUserId = await AppCache.userId;

      // currentUserId가 없으면 모든 멤버 반환
      if (currentUserId == null) {
        return members;
      }

      // 현재 사용자가 보호자인지 확인
      final currentUserMember = members.firstWhere(
        (member) => member['user_id'] == currentUserId,
        orElse: () => <String, dynamic>{},
      );

      final isGuardian = currentUserMember['is_guardian'] == true ||
          currentUserMember['member_role'] == 'guardian';
      if (!isGuardian) {
        return members;
      }

      // 보호대상 ID 목록 가져오기
      final protectedTravelerIds = <String>[];
      for (final member in members) {
        if (member['user_id'] == currentUserId &&
            member['traveler_user_id'] != null) {
          protectedTravelerIds.add(member['traveler_user_id'] as String);
        }
      }

      if (protectedTravelerIds.isEmpty) {
        // 보호대상이 없으면 빈 리스트 반환
        debugPrint('[GuardianFilter] 보호대상이 없음');
        return [];
      }

      // 보호대상만 필터링 (보호자 자신은 제외)
      final filtered = members.where((member) {
        final memberUserId = member['user_id'] as String?;
        final memberIsGuardian = member['is_guardian'] == true ||
            member['member_role'] == 'guardian';

        // 현재 사용자 자신은 제외
        if (memberUserId == currentUserId) {
          return false;
        }

        // 보호자가 아닌 일반 멤버 중 보호대상인 경우
        if (!memberIsGuardian && memberUserId != null) {
          return protectedTravelerIds.contains(memberUserId);
        }

        // 보호자이지만 자신의 보호대상인 경우 (다른 보호자)
        if (memberIsGuardian && member['traveler_user_id'] != null) {
          return protectedTravelerIds.contains(member['traveler_user_id']);
        }

        return false;
      }).toList();

      debugPrint(
        '[GuardianFilter] 보호자 필터링: ${members.length}명 -> ${filtered.length}명',
      );
      return filtered;
    } catch (e) {
      debugPrint('[GuardianFilter] 보호자 필터링 실패: $e');
      // 오류 시 모든 멤버 반환 (안전장치)
      return members;
    }
  }

  /// 보호자 필터링 (동기 버전, 메모리 캐시 사용)
  ///
  /// [members] 멤버 리스트
  /// [currentUserId] 현재 사용자 ID
  ///
  /// Returns 필터링된 멤버 리스트
  static List<Map<String, dynamic>> filterMembersForGuardianSync(
    List<Map<String, dynamic>> members,
    String? currentUserId,
  ) {
    try {
      debugPrint(
        '[GuardianFilter] 필터링 시작: members=${members.length}명, currentUserId=$currentUserId',
      );
      
      // currentUserId가 없으면 모든 멤버 반환
      if (currentUserId == null) {
        debugPrint(
          '[GuardianFilter] currentUserId가 없으므로 필터링 스킵',
        );
        return members;
      }

      // 현재 사용자가 보호자인지 확인
      final currentUserMember = members.firstWhere(
        (member) => member['user_id'] == currentUserId,
        orElse: () => <String, dynamic>{},
      );

      final isGuardian = currentUserMember['is_guardian'] == true ||
          currentUserMember['member_role'] == 'guardian';
      debugPrint(
        '[GuardianFilter] 현재 사용자 확인: isGuardian=$isGuardian, currentUserMember=${currentUserMember['user_id']}, is_guardian=${currentUserMember['is_guardian']}, member_role=${currentUserMember['member_role']}',
      );

      if (!isGuardian) {
        debugPrint('[GuardianFilter] 현재 사용자가 보호자가 아니므로 필터링 스킵');
        return members;
      }

      // 보호대상 ID 목록 가져오기
      final protectedTravelerIds = <String>[];
      for (final member in members) {
        final memberUserId = member['user_id'] as String?;
        final travelerUserId = member['traveler_user_id'] as String?;
        
        debugPrint(
          '[GuardianFilter] 멤버 확인: user_id=$memberUserId, is_guardian=${member['is_guardian']}, traveler_user_id=$travelerUserId',
        );
        
        if (memberUserId == currentUserId &&
            travelerUserId != null) {
          protectedTravelerIds.add(travelerUserId);
          debugPrint(
            '[GuardianFilter] 보호대상 ID 추가: $travelerUserId (보호자: $currentUserId)',
          );
        }
      }

      debugPrint(
        '[GuardianFilter] 보호대상 ID 목록: $protectedTravelerIds (${protectedTravelerIds.length}명)',
      );

      if (protectedTravelerIds.isEmpty) {
        // 보호대상이 없으면 빈 리스트 반환
        debugPrint('[GuardianFilter] 보호대상이 없음');
        return [];
      }

      // 보호대상만 필터링 (보호자 자신은 제외)
      final filtered = members.where((member) {
        final memberUserId = member['user_id'] as String?;
        final memberIsGuardian = member['is_guardian'] == true ||
            member['member_role'] == 'guardian';
        final travelerUserId = member['traveler_user_id'] as String?;

        debugPrint(
          '[GuardianFilter] 필터링 체크: user_id=$memberUserId, is_guardian=$memberIsGuardian, member_role=${member['member_role']}, traveler_user_id=$travelerUserId',
        );
        
        // 현재 사용자 자신은 제외
        if (memberUserId == currentUserId) {
          debugPrint('[GuardianFilter] 보호자 자신 제외: $memberUserId');
          return false;
        }
        
        // 보호자가 아닌 일반 멤버 중 보호대상인 경우
        if (!memberIsGuardian && memberUserId != null) {
          final isProtected = protectedTravelerIds.contains(memberUserId);
          debugPrint(
            '[GuardianFilter] 일반 멤버 체크: $memberUserId -> isProtected=$isProtected (protectedTravelerIds=$protectedTravelerIds)',
          );
          if (isProtected) {
            debugPrint('[GuardianFilter] ✅ 보호대상 포함: $memberUserId (일반 멤버)');
          }
          return isProtected;
        }
        
        // 보호자이지만 자신의 보호대상인 경우 (다른 보호자)
        if (memberIsGuardian && travelerUserId != null) {
          final isProtected = protectedTravelerIds.contains(travelerUserId);
          debugPrint(
            '[GuardianFilter] 보호자 멤버 체크: $memberUserId (traveler_user_id=$travelerUserId) -> isProtected=$isProtected',
          );
          if (isProtected) {
            debugPrint('[GuardianFilter] ✅ 보호대상 포함: $memberUserId (보호자, traveler_user_id=$travelerUserId)');
          }
          return isProtected;
        }
        
        debugPrint('[GuardianFilter] ❌ 제외: $memberUserId (조건 불일치)');
        return false;
      }).toList();

      debugPrint(
        '[GuardianFilter] 보호자 필터링 완료: ${members.length}명 -> ${filtered.length}명',
      );
      return filtered;
    } catch (e) {
      debugPrint('[GuardianFilter] 보호자 필터링 실패: $e');
      // 오류 시 모든 멤버 반환 (안전장치)
      return members;
    }
  }
}
