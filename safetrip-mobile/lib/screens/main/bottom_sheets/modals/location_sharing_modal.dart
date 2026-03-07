import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/api_service.dart';

/// 위치 공유 관리 모달 (§6 프라이버시 등급별 UI 분기)
///
/// - safety_first: 토글 비활성화, "항상 공유" 안내문
/// - standard: 마스터 ON/OFF 토글 + 개별 멤버별 공유 설정 토글
/// - privacy_first: 일정 연동 안내 + 버퍼 구간(±15분) 설명
class LocationSharingModal extends StatefulWidget {

  const LocationSharingModal({
    super.key,
    required this.groupId,
    required this.currentUserId,
    this.privacyLevel = 'standard',
  });
  final String groupId;
  final String currentUserId;
  /// 프라이버시 등급: 'safety_first' | 'standard' | 'privacy_first'
  final String privacyLevel;

  @override
  State<LocationSharingModal> createState() => _LocationSharingModalState();
}

class _LocationSharingModalState extends State<LocationSharingModal> {
  final ApiService _apiService = ApiService();

  bool _masterEnabled = true;
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];
  // 멤버별 공유 상태 (user_id → enabled)
  final Map<String, bool> _memberSharingStates = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final members = await _apiService.getGroupMembers(widget.groupId);
      if (mounted) {
        final activeMembers = members
            .where((m) =>
                m['status'] == 'active' &&
                m['user_id'] != widget.currentUserId)
            .toList();

        // 현재 유저의 위치 공유 설정 확인
        final currentMember = members.firstWhere(
          (m) => m['user_id'] == widget.currentUserId,
          orElse: () => <String, dynamic>{},
        );
        final masterState =
            currentMember['location_sharing_enabled'] as bool? ?? true;

        setState(() {
          _members = activeMembers;
          _masterEnabled = masterState;
          for (final m in activeMembers) {
            _memberSharingStates[m['user_id'] as String] = true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleMaster(bool value) async {
    setState(() => _masterEnabled = value);

    final success = await _apiService.updateLocationSharingStatus(
      userId: widget.currentUserId,
      enabled: value,
    );

    if (!success && mounted) {
      setState(() => _masterEnabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 공유 설정 변경에 실패했습니다')),
      );
    }
  }

  void _toggleMemberSharing(String userId, bool value) {
    setState(() {
      _memberSharingStates[userId] = value;
    });
    // TODO: 백엔드 API 연동 필요 (개별 멤버 위치 공유 토글)
    // TB_LOCATION_SHARING 테이블 활용
  }

  /// §6 프라이버시 등급별 콘텐츠 분기
  Widget _buildPrivacyContent() {
    switch (widget.privacyLevel) {
      case 'safety_first':
        return _buildSafetyFirstContent();
      case 'privacy_first':
        return _buildPrivacyFirstContent();
      default: // 'standard'
        return _buildStandardContent();
    }
  }

  /// safety_first: 토글 비활성화 + "항상 공유" 안내문 (§6)
  Widget _buildSafetyFirstContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 항상 공유 안내 배너
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTokens.spacing16),
          decoration: BoxDecoration(
            color: AppTokens.primaryTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTokens.radius12),
            border: Border.all(color: AppTokens.primaryTeal),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shield,
                color: AppTokens.primaryTeal,
                size: 24,
              ),
              const SizedBox(width: AppTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '안전 우선 모드',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        fontWeight: AppTokens.fontWeightSemibold,
                        color: AppTokens.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '이 여행은 안전 우선 모드로 설정되어\n위치가 항상 그룹 멤버에게 공유됩니다.',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize12,
                        color: AppTokens.text04,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spacing16),
        // 마스터 토글 (비활성화)
        _buildMasterToggle(disabled: true, alwaysOn: true),
        const SizedBox(height: AppTokens.spacing16),
        // 안내문
        Container(
          padding: const EdgeInsets.all(AppTokens.spacing16),
          decoration: BoxDecoration(
            color: AppTokens.bgBasic03,
            borderRadius: BorderRadius.circular(AppTokens.radius12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTokens.text03, size: 20),
              const SizedBox(width: AppTokens.spacing8),
              Expanded(
                child: Text(
                  '안전 우선 모드에서는 위치 공유를 끌 수 없습니다.\n여행 설정에서 프라이버시 등급을 변경할 수 있습니다.',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    color: AppTokens.text03,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// privacy_first: 일정 연동 안내 + 버퍼 구간(±15분) 설명 (§6)
  Widget _buildPrivacyFirstContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프라이버시 우선 안내 배너
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTokens.spacing16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(AppTokens.radius12),
            border: Border.all(color: const Color(0xFF9C27B0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock,
                color: Color(0xFF9C27B0),
                size: 24,
              ),
              const SizedBox(width: AppTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '프라이버시 우선 모드',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        fontWeight: AppTokens.fontWeightSemibold,
                        color: const Color(0xFF9C27B0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '일정이 등록된 시간대에만 위치가 공유됩니다.',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize12,
                        color: AppTokens.text04,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spacing16),
        // 마스터 토글
        _buildMasterToggle(),
        const SizedBox(height: AppTokens.spacing24),
        // 일정 연동 설명
        Text(
          '일정 기반 위치 공유',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            fontWeight: AppTokens.fontWeightSemibold,
          ),
        ),
        const SizedBox(height: AppTokens.spacing8),
        _buildInfoRow(
          Icons.schedule,
          '일정 시간대에만 위치 공유',
          '등록된 일정의 시작~종료 시간 동안만\n그룹 멤버에게 위치가 공유됩니다.',
        ),
        const SizedBox(height: AppTokens.spacing8),
        _buildInfoRow(
          Icons.timer,
          '버퍼 구간 ±15분',
          '일정 시작 15분 전부터 종료 15분 후까지\n위치가 공유되어 안전한 이동을 지원합니다.',
        ),
        const SizedBox(height: AppTokens.spacing8),
        _buildInfoRow(
          Icons.visibility_off,
          '일정 외 시간',
          '등록된 일정이 없는 시간에는\n위치가 공유되지 않습니다.',
        ),
        if (_masterEnabled) ...[
          const SizedBox(height: AppTokens.spacing24),
          Text(
            '멤버별 위치 공유 설정',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              fontWeight: AppTokens.fontWeightSemibold,
            ),
          ),
          const SizedBox(height: AppTokens.spacing4),
          Text(
            '일정 시간대에 위치를 공유할 멤버를 선택하세요',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize12,
              color: AppTokens.text03,
            ),
          ),
          const SizedBox(height: AppTokens.spacing12),
          ..._members.map(_buildMemberRow),
        ],
      ],
    );
  }

  /// standard: 기존 마스터 + 개별 토글 동작 유지 (§6)
  Widget _buildStandardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMasterToggle(),
        const SizedBox(height: AppTokens.spacing24),
        if (_masterEnabled) ...[
          Text(
            '멤버별 위치 공유 설정',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              fontWeight: AppTokens.fontWeightSemibold,
            ),
          ),
          const SizedBox(height: AppTokens.spacing4),
          Text(
            '각 멤버에게 내 위치를 공유할지 선택하세요',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize12,
              color: AppTokens.text03,
            ),
          ),
          const SizedBox(height: AppTokens.spacing12),
          ..._members.map(_buildMemberRow),
        ],
        if (!_masterEnabled) ...[
          const SizedBox(height: AppTokens.spacing16),
          Container(
            padding: const EdgeInsets.all(AppTokens.spacing16),
            decoration: BoxDecoration(
              color: AppTokens.bgBasic03,
              borderRadius: BorderRadius.circular(AppTokens.radius12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTokens.text03, size: 20),
                const SizedBox(width: AppTokens.spacing8),
                Expanded(
                  child: Text(
                    '위치 공유를 켜면 개별 멤버별로\n공유 범위를 설정할 수 있습니다.',
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize12,
                      color: AppTokens.text03,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 마스터 토글 위젯 (공통)
  Widget _buildMasterToggle({bool disabled = false, bool alwaysOn = false}) {
    final enabled = alwaysOn ? true : _masterEnabled;
    return Container(
      padding: const EdgeInsets.all(AppTokens.spacing16),
      decoration: BoxDecoration(
        color: enabled
            ? AppTokens.primaryTeal.withValues(alpha: 0.08)
            : AppTokens.bgBasic03,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(
          color: enabled ? AppTokens.primaryTeal : AppTokens.line03,
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.location_on : Icons.location_off,
            color: enabled ? AppTokens.primaryTeal : AppTokens.text03,
            size: 24,
          ),
          const SizedBox(width: AppTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내 위치 공유',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize14,
                    fontWeight: AppTokens.fontWeightSemibold,
                    color: enabled ? AppTokens.text06 : AppTokens.text04,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? '그룹 멤버에게 내 위치가 공유됩니다'
                      : '위치 공유가 꺼져 있습니다',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    color: AppTokens.text03,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: disabled ? null : _toggleMaster,
            activeThumbColor: AppTokens.primaryTeal,
          ),
        ],
      ),
    );
  }

  /// 멤버 행 위젯 (공통)
  Widget _buildMemberRow(Map<String, dynamic> member) {
    final userId = member['user_id'] as String;
    final isEnabled = _memberSharingStates[userId] ?? true;
    final role = member['member_role'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spacing12,
        vertical: AppTokens.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(color: AppTokens.line03),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTokens.bgTeal03,
            child: Text(
              (member['display_name'] as String? ?? '?').characters.first,
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize12,
                fontWeight: AppTokens.fontWeightBold,
                color: AppTokens.primaryTeal,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['display_name'] as String? ?? userId,
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize14,
                    fontWeight: AppTokens.fontWeightMedium,
                  ),
                ),
                Text(
                  _getRoleName(role),
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize11,
                    color: AppTokens.text03,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (v) => _toggleMemberSharing(userId, v),
            activeThumbColor: AppTokens.primaryTeal,
          ),
        ],
      ),
    );
  }

  /// 정보 행 위젯 (privacy_first 모드용)
  Widget _buildInfoRow(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spacing12),
      decoration: BoxDecoration(
        color: AppTokens.bgBasic02,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTokens.primaryTeal, size: 20),
          const SizedBox(width: AppTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize13,
                    fontWeight: AppTokens.fontWeightSemibold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    color: AppTokens.text03,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'captain':
        return '리더';
      case 'crew_chief':
        return '공동관리자';
      case 'guardian':
        return '모니터링 전용';
      default: // 'crew'
        return '일반 멤버';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTokens.radius20),
          topRight: Radius.circular(AppTokens.radius20),
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(AppTokens.spacing16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTokens.line03),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '위치 공유 관리',
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize20,
                    fontWeight: AppTokens.fontWeightBold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppTokens.text05,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 콘텐츠
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTokens.primaryTeal,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTokens.spacing16),
                    child: _buildPrivacyContent(),
                  ),
          ),
        ],
      ),
    );
  }
}
