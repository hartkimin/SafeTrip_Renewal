import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/api_service.dart';

/// 위치 공유 관리 모달
/// 마스터 ON/OFF 토글 + 개별 멤버별 공유 설정 토글
class LocationSharingModal extends StatefulWidget {

  const LocationSharingModal({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });
  final String groupId;
  final String currentUserId;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 마스터 토글
                        Container(
                          padding: const EdgeInsets.all(AppTokens.spacing16),
                          decoration: BoxDecoration(
                            color: _masterEnabled
                                ? AppTokens.primaryTeal
                                    .withValues(alpha: 0.08)
                                : AppTokens.bgBasic03,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radius12),
                            border: Border.all(
                              color: _masterEnabled
                                  ? AppTokens.primaryTeal
                                  : AppTokens.line03,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _masterEnabled
                                    ? Icons.location_on
                                    : Icons.location_off,
                                color: _masterEnabled
                                    ? AppTokens.primaryTeal
                                    : AppTokens.text03,
                                size: 24,
                              ),
                              const SizedBox(width: AppTokens.spacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '내 위치 공유',
                                      style: AppTokens.textStyle(
                                        fontSize: AppTokens.fontSize14,
                                        fontWeight:
                                            AppTokens.fontWeightSemibold,
                                        color: _masterEnabled
                                            ? AppTokens.text06
                                            : AppTokens.text04,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _masterEnabled
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
                                value: _masterEnabled,
                                onChanged: _toggleMaster,
                                activeThumbColor: AppTokens.primaryTeal,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppTokens.spacing24),

                        // 개별 멤버 토글
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
                          ..._members.map((member) {
                            final userId = member['user_id'] as String;
                            final isEnabled =
                                _memberSharingStates[userId] ?? true;
                            final role =
                                member['member_role'] as String? ?? '';

                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: AppTokens.spacing8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTokens.spacing12,
                                vertical: AppTokens.spacing8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTokens.bgBasic01,
                                borderRadius: BorderRadius.circular(
                                    AppTokens.radius12),
                                border:
                                    Border.all(color: AppTokens.line03),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTokens.bgTeal03,
                                    child: Text(
                                      (member['display_name']
                                                  as String? ??
                                              '?')
                                          .characters
                                          .first,
                                      style: AppTokens.textStyle(
                                        fontSize: AppTokens.fontSize12,
                                        fontWeight:
                                            AppTokens.fontWeightBold,
                                        color: AppTokens.primaryTeal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                      width: AppTokens.spacing12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member['display_name']
                                                  as String? ??
                                              userId,
                                          style: AppTokens.textStyle(
                                            fontSize:
                                                AppTokens.fontSize14,
                                            fontWeight: AppTokens
                                                .fontWeightMedium,
                                          ),
                                        ),
                                        Text(
                                          _getRoleName(role),
                                          style: AppTokens.textStyle(
                                            fontSize:
                                                AppTokens.fontSize11,
                                            color: AppTokens.text03,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isEnabled,
                                    onChanged: (v) =>
                                        _toggleMemberSharing(
                                            userId, v),
                                    activeThumbColor: AppTokens.primaryTeal,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        // 마스터 OFF 시 안내
                        if (!_masterEnabled) ...[
                          const SizedBox(height: AppTokens.spacing16),
                          Container(
                            padding:
                                const EdgeInsets.all(AppTokens.spacing16),
                            decoration: BoxDecoration(
                              color: AppTokens.bgBasic03,
                              borderRadius: BorderRadius.circular(
                                  AppTokens.radius12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppTokens.text03,
                                  size: 20,
                                ),
                                const SizedBox(
                                    width: AppTokens.spacing8),
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
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
