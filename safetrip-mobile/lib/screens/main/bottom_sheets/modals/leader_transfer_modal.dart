import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/api_service.dart';

/// 리더 양도 모달
/// leader가 full 역할 멤버에게 리더십을 양도하는 UI
class LeaderTransferModal extends StatefulWidget {

  const LeaderTransferModal({
    super.key,
    required this.groupId,
    required this.currentUserId,
    this.isEmbedded = false,
  });
  final String groupId;
  final String currentUserId;
  final bool isEmbedded;

  @override
  State<LeaderTransferModal> createState() => _LeaderTransferModalState();
}

class _LeaderTransferModalState extends State<LeaderTransferModal> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _eligibleMembers = [];
  String? _selectedUserId;
  bool _isLoading = true;
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _apiService.getGroupMembers(widget.groupId);
      if (mounted) {
        setState(() {
          // crew_chief(공동관리자) 또는 crew(일반 멤버) 중 자신을 제외한 양도 가능 대상
          _eligibleMembers = members.where((m) {
            final role = m['member_role'] as String? ?? '';
            final userId = m['user_id'] as String? ?? '';
            return (role == 'crew_chief' || role == 'crew') &&
                userId != widget.currentUserId &&
                m['status'] == 'active';
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmTransfer() async {
    if (_selectedUserId == null) return;

    final selectedMember = _eligibleMembers.firstWhere(
      (m) => m['user_id'] == _selectedUserId,
    );
    final targetName = selectedMember['display_name'] ?? _selectedUserId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius16),
        ),
        title: Text(
          '리더 양도 확인',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize16,
            fontWeight: AppTokens.fontWeightBold,
          ),
        ),
        content: RichText(
          text: TextSpan(
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize14,
              color: AppTokens.text04,
            ),
            children: [
              TextSpan(
                text: '$targetName',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize14,
                  fontWeight: AppTokens.fontWeightBold,
                  color: AppTokens.text05,
                ),
              ),
              const TextSpan(text: '님에게 리더 권한을 양도하시겠습니까?\n\n'),
              const TextSpan(
                text: '양도 후 나의 역할은 공동관리자(full)로 변경됩니다.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize14,
                color: AppTokens.text03,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.semanticError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius8),
              ),
            ),
            child: Text(
              '양도하기',
              style: AppTokens.textStyle(
                fontSize: AppTokens.fontSize14,
                fontWeight: AppTokens.fontWeightSemibold,
                color: AppTokens.text01,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isTransferring = true);

    try {
      final result = await _apiService.transferLeadership(
        groupId: widget.groupId,
        toUserId: _selectedUserId!,
      );

      if (mounted) {
        if (result != null) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(content: Text('$targetName님에게 리더 권한을 양도했습니다')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('리더 양도에 실패했습니다')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildContent();
    }
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppTokens.bgBasic01,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTokens.radius20),
          topRight: Radius.circular(AppTokens.radius20),
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
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
                '리더 양도',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize20,
                  fontWeight: AppTokens.fontWeightBold,
                ),
              ),
              const Spacer(),
              if (!widget.isEmbedded)
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppTokens.text05,
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
        ),

        // 안내 텍스트
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spacing16,
            AppTokens.spacing16,
            AppTokens.spacing16,
            AppTokens.spacing8,
          ),
          child: Text(
            '리더 권한을 양도할 멤버를 선택하세요.\n양도 후 나의 역할은 공동관리자로 변경됩니다.',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize12,
              color: AppTokens.text03,
              height: 1.5,
            ),
          ),
        ),

        // 멤버 리스트
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTokens.primaryTeal,
                  ),
                )
              : _eligibleMembers.isEmpty
                  ? Center(
                      child: Text(
                        '양도 가능한 멤버가 없습니다',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize14,
                          color: AppTokens.text03,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spacing16,
                      ),
                      itemCount: _eligibleMembers.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTokens.spacing8),
                      itemBuilder: (context, index) {
                        final member = _eligibleMembers[index];
                        final userId = member['user_id'] as String;
                        final isSelected = _selectedUserId == userId;
                        final role = member['member_role'] as String? ?? '';
                        final roleName = role == 'crew_chief'
                            ? '공동관리자'
                            : role == 'crew'
                                ? '일반 멤버'
                                : role;

                        final memberName =
                            member['display_name'] as String? ?? '';
                        final initial = memberName.isNotEmpty
                            ? memberName.characters.first
                            : '?';

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedUserId = userId);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(AppTokens.spacing12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTokens.primaryTeal
                                      .withValues(alpha: 0.08)
                                  : AppTokens.bgBasic01,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radius12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTokens.primaryTeal
                                    : AppTokens.line03,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? AppTokens.primaryTeal
                                      : AppTokens.text03,
                                  size: 20,
                                ),
                                const SizedBox(width: AppTokens.spacing12),
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTokens.bgTeal03,
                                  child: Text(
                                    initial,
                                    style: AppTokens.textStyle(
                                      fontSize: AppTokens.fontSize14,
                                      fontWeight: AppTokens.fontWeightBold,
                                      color: AppTokens.primaryTeal,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTokens.spacing12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member['display_name'] as String? ??
                                            userId,
                                        style: AppTokens.textStyle(
                                          fontSize: AppTokens.fontSize14,
                                          fontWeight:
                                              AppTokens.fontWeightMedium,
                                          color: isSelected
                                              ? AppTokens.text06
                                              : AppTokens.text05,
                                        ),
                                      ),
                                      Text(
                                        roleName,
                                        style: AppTokens.textStyle(
                                          fontSize: AppTokens.fontSize12,
                                          color: AppTokens.text03,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // 양도 버튼
        Padding(
          padding: const EdgeInsets.all(AppTokens.spacing16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedUserId != null && !_isTransferring
                  ? _confirmTransfer
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.semanticError,
                disabledBackgroundColor: AppTokens.bgBasic04,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTokens.spacing14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius12),
                ),
              ),
              child: _isTransferring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTokens.bgBasic01,
                        ),
                      ),
                    )
                  : Text(
                      '리더 양도하기',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        fontWeight: AppTokens.fontWeightSemibold,
                        color: AppTokens.text01,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
