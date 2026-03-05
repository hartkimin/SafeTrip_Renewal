import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/share_helper.dart';

/// 초대 모달 (역할 기반 초대코드 생성 지원)
class InviteModal extends StatefulWidget {

  const InviteModal({
    super.key,
    this.groupId,
    this.inviteCode,
    this.inviteLink,
  });
  final String? groupId;
  final String? inviteCode;
  final String? inviteLink;

  @override
  State<InviteModal> createState() => _InviteModalState();
}

class _InviteModalState extends State<InviteModal> {
  final TextEditingController _phoneController = TextEditingController();
  final ApiService _apiService = ApiService();

  // 역할 기반 초대코드 상태
  String _selectedRole = 'crew';
  String? _generatedCode;
  bool _isGenerating = false;

  static const _roleOptions = [
    {'value': 'crew_chief', 'label': '공동관리자', 'desc': '일정/멤버 관리 가능'},
    {'value': 'crew', 'label': '일반 멤버', 'desc': '여행 참여'},
    {'value': 'guardian', 'label': '모니터링', 'desc': '안전 확인 전용'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _inviteByPhone() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호를 입력하세요')),
      );
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$phoneNumber로 초대 요청을 보냈습니다')),
      );
    }
  }

  Future<void> _generateInviteCode() async {
    if (widget.groupId == null) return;

    setState(() {
      _isGenerating = true;
      _generatedCode = null;
    });

    try {
      final result = await _apiService.createInviteCode(
        groupId: widget.groupId!,
        targetRole: _selectedRole,
      );

      if (result != null && mounted) {
        setState(() {
          _generatedCode = result['code'] as String?;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초대코드 생성에 실패했습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
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
                  '멤버 초대',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 역할 기반 초대코드 생성
                  if (widget.groupId != null) ...[
                    Text(
                      '역할별 초대코드 생성',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        fontWeight: AppTokens.fontWeightSemibold,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spacing8),
                    Text(
                      '초대받는 멤버의 역할을 선택하고 코드를 생성하세요',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize12,
                        color: AppTokens.text03,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spacing12),

                    // 역할 선택
                    ..._roleOptions.map((option) {
                      final isSelected = _selectedRole == option['value'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRole = option['value'] as String;
                            _generatedCode = null;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppTokens.spacing8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.spacing12,
                            vertical: AppTokens.spacing12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTokens.primaryTeal.withValues(alpha: 0.08)
                                : AppTokens.bgBasic01,
                            borderRadius: BorderRadius.circular(AppTokens.radius12),
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
                              const SizedBox(width: AppTokens.spacing8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option['label'] as String,
                                      style: AppTokens.textStyle(
                                        fontSize: AppTokens.fontSize14,
                                        fontWeight: AppTokens.fontWeightMedium,
                                        color: isSelected
                                            ? AppTokens.text06
                                            : AppTokens.text05,
                                      ),
                                    ),
                                    Text(
                                      option['desc'] as String,
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
                    }),

                    const SizedBox(height: AppTokens.spacing12),

                    // 코드 생성 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isGenerating ? null : _generateInviteCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.primaryTeal,
                          disabledBackgroundColor: AppTokens.bgBasic04,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.spacing14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radius12),
                          ),
                        ),
                        child: _isGenerating
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
                                '초대코드 생성',
                                style: AppTokens.textStyle(
                                  fontSize: AppTokens.fontSize14,
                                  fontWeight: AppTokens.fontWeightSemibold,
                                  color: AppTokens.text01,
                                ),
                              ),
                      ),
                    ),

                    // 생성된 코드 표시
                    if (_generatedCode != null) ...[
                      const SizedBox(height: AppTokens.spacing16),
                      Container(
                        padding: const EdgeInsets.all(AppTokens.spacing16),
                        decoration: BoxDecoration(
                          color: AppTokens.primaryTeal.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(AppTokens.radius12),
                          border: Border.all(
                            color: AppTokens.primaryTeal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '생성된 초대코드',
                              style: AppTokens.textStyle(
                                fontSize: AppTokens.fontSize12,
                                color: AppTokens.text04,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spacing8),
                            Text(
                              _generatedCode!,
                              style: AppTokens.textStyle(
                                fontSize: AppTokens.fontSize20,
                                fontWeight: AppTokens.fontWeightBold,
                                color: AppTokens.primaryTeal,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spacing4),
                            Text(
                              '역할: ${_roleOptions.firstWhere((o) => o['value'] == _selectedRole)['label']}',
                              style: AppTokens.textStyle(
                                fontSize: AppTokens.fontSize12,
                                color: AppTokens.text03,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spacing12),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    ShareHelper.copyToClipboardWithToast(
                                      context,
                                      _generatedCode!,
                                    );
                                  },
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('복사'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTokens.primaryTeal,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    final roleName = _roleOptions.firstWhere(
                                      (o) => o['value'] == _selectedRole,
                                    )['label'];
                                    ShareHelper.share(
                                      context: context,
                                      text:
                                          'SafeTrip 그룹 초대코드: $_generatedCode\n역할: $roleName',
                                    );
                                  },
                                  icon: const Icon(Icons.share, size: 16),
                                  label: const Text('공유'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTokens.primaryTeal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppTokens.spacing32),
                    const Divider(color: AppTokens.line03),
                    const SizedBox(height: AppTokens.spacing16),
                  ],

                  // 기존 레거시 초대코드 공유
                  if (widget.inviteCode != null || widget.inviteLink != null) ...[
                    Text(
                      '기존 초대 코드',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        fontWeight: AppTokens.fontWeightSemibold,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spacing12),
                    Container(
                      padding: const EdgeInsets.all(AppTokens.spacing16),
                      decoration: BoxDecoration(
                        color: AppTokens.bgBasic02,
                        borderRadius: BorderRadius.circular(AppTokens.radius12),
                        border: Border.all(color: AppTokens.line03),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.inviteCode != null)
                            Text(
                              widget.inviteCode!,
                              style: AppTokens.textStyle(
                                fontSize: AppTokens.fontSize16,
                                fontWeight: AppTokens.fontWeightSemibold,
                                color: AppTokens.text06,
                              ),
                            ),
                          if (widget.inviteLink != null) ...[
                            if (widget.inviteCode != null)
                              const SizedBox(height: AppTokens.spacing8),
                            Text(
                              widget.inviteLink!,
                              style: AppTokens.textStyle(
                                fontSize: AppTokens.fontSize12,
                                color: AppTokens.text04,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppTokens.spacing12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  final text =
                                      widget.inviteLink ?? widget.inviteCode ?? '';
                                  ShareHelper.copyToClipboardWithToast(context, text);
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('복사'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTokens.text06,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  ShareHelper.share(
                                    context: context,
                                    text: widget.inviteLink != null
                                        ? 'SafeTrip 그룹 초대: ${widget.inviteLink}'
                                        : 'SafeTrip 그룹 초대 코드: ${widget.inviteCode}',
                                  );
                                },
                                icon: const Icon(Icons.share, size: 16),
                                label: const Text('공유'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTokens.text06,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.spacing32),
                  ],

                  // 전화번호 입력
                  Text(
                    '전화번호로 초대',
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize14,
                      fontWeight: AppTokens.fontWeightSemibold,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spacing12),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      hintText: '전화번호 입력',
                      hintStyle: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        color: AppTokens.text03,
                      ),
                      filled: true,
                      fillColor: AppTokens.bgBasic02,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radius12),
                        borderSide: const BorderSide(color: AppTokens.line03),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spacing12,
                        vertical: AppTokens.spacing12,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    style: AppTokens.textStyle(fontSize: AppTokens.fontSize14),
                  ),
                  const SizedBox(height: AppTokens.spacing16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _inviteByPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.text06,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.spacing14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.radius12),
                        ),
                      ),
                      child: Text(
                        '초대하기',
                        style: AppTokens.textStyle(
                          fontSize: AppTokens.fontSize14,
                          fontWeight: AppTokens.fontWeightSemibold,
                          color: AppTokens.text01,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
