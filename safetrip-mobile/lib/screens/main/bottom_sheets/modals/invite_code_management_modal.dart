import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/share_helper.dart';

/// 초대코드 관리 모달
/// 생성된 코드 목록 조회 / 비활성화 / 복사
class InviteCodeManagementModal extends StatefulWidget {

  const InviteCodeManagementModal({
    super.key,
    required this.tripId,
    this.isEmbedded = false,
  });
  final String tripId;
  final bool isEmbedded;

  @override
  State<InviteCodeManagementModal> createState() =>
      _InviteCodeManagementModalState();
}

class _InviteCodeManagementModalState extends State<InviteCodeManagementModal> {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _codes = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() => _isLoading = true);
    try {
      final codes = await _apiService.getInviteCodesByTrip(widget.tripId);
      if (mounted) {
        setState(() {
          _codes = codes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deactivateCode(String codeId, String code) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius16),
        ),
        title: Text(
          '코드 비활성화',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize16,
            fontWeight: AppTokens.fontWeightBold,
          ),
        ),
        content: Text(
          '초대코드 "$code"를 비활성화하시겠습니까?\n비활성화 후에는 이 코드로 가입할 수 없습니다.',
          style: AppTokens.textStyle(
            fontSize: AppTokens.fontSize14,
            color: AppTokens.text04,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: AppTokens.textStyle(color: AppTokens.text03),
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
              '비활성화',
              style: AppTokens.textStyle(
                fontWeight: AppTokens.fontWeightSemibold,
                color: AppTokens.text01,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await _apiService.deactivateInviteCode(
      tripId: widget.tripId,
      codeId: codeId,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초대코드가 비활성화되었습니다')),
        );
        _loadCodes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비활성화에 실패했습니다')),
        );
      }
    }
  }

  Future<void> _createCode({
    required String role,
    required int maxUses,
    int? expiresInDays,
  }) async {
    setState(() => _isCreating = true);
    try {
      final result = await _apiService.createInviteCode(
        tripId: widget.tripId,
        targetRole: role,
        maxUses: maxUses,
        expiresHours: expiresInDays != null ? expiresInDays * 24 : null,
      );
      if (mounted) {
        setState(() => _isCreating = false);
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('초대코드가 생성되었습니다')),
          );
          _loadCodes();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('초대코드 생성에 실패했습니다')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초대코드 생성 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Future<void> _showCreateCodeDialog() async {
    String selectedRole = 'crew';
    int maxUses = 5;
    int expiresInDays = 7;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius16),
          ),
          title: Text(
            '초대코드 생성',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize18,
              fontWeight: AppTokens.fontWeightBold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '역할',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize14,
                  fontWeight: AppTokens.fontWeightSemibold,
                ),
              ),
              const SizedBox(height: AppTokens.spacing8),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radius8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'crew_chief', child: Text('공동관리자')),
                  DropdownMenuItem(value: 'crew', child: Text('일반 멤버')),
                  DropdownMenuItem(
                      value: 'guardian', child: Text('모니터링 전용')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              ),
              const SizedBox(height: AppTokens.spacing12),
              Text(
                '최대 사용 횟수',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize14,
                  fontWeight: AppTokens.fontWeightSemibold,
                ),
              ),
              const SizedBox(height: AppTokens.spacing8),
              DropdownButtonFormField<int>(
                value: maxUses,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radius8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1회')),
                  DropdownMenuItem(value: 5, child: Text('5회')),
                  DropdownMenuItem(value: 10, child: Text('10회')),
                  DropdownMenuItem(value: 9999, child: Text('무제한')),
                ],
                onChanged: (v) => setDialogState(() => maxUses = v!),
              ),
              const SizedBox(height: AppTokens.spacing12),
              Text(
                '유효기간',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize14,
                  fontWeight: AppTokens.fontWeightSemibold,
                ),
              ),
              const SizedBox(height: AppTokens.spacing8),
              DropdownButtonFormField<int>(
                value: expiresInDays,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radius8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1일')),
                  DropdownMenuItem(value: 3, child: Text('3일')),
                  DropdownMenuItem(value: 7, child: Text('7일')),
                  DropdownMenuItem(value: 0, child: Text('무기한')),
                ],
                onChanged: (v) => setDialogState(() => expiresInDays = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                '취소',
                style: AppTokens.textStyle(color: AppTokens.text03),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _createCode(
                  role: selectedRole,
                  maxUses: maxUses,
                  expiresInDays: expiresInDays == 0 ? null : expiresInDays,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.primaryTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius8),
                ),
              ),
              child: Text(
                '생성',
                style: AppTokens.textStyle(
                  color: Colors.white,
                  fontWeight: AppTokens.fontWeightSemibold,
                ),
              ),
            ),
          ],
        ),
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

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'captain':
        return AppTokens.secondaryAmber;
      case 'crew_chief':
        return AppTokens.primaryTeal;
      case 'guardian':
        return AppTokens.secondaryAmber;
      default: // 'crew'
        return AppTokens.semanticSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildContent();
    }
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
    final activeCodes =
        _codes.where((c) => c['is_active'] == true).toList();
    final inactiveCodes =
        _codes.where((c) => c['is_active'] != true).toList();

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
                '초대코드 관리',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize20,
                  fontWeight: AppTokens.fontWeightBold,
                ),
              ),
              const Spacer(),
              if (_isCreating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTokens.primaryTeal,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTokens.primaryTeal,
                  tooltip: '새 코드 생성',
                  onPressed: _showCreateCodeDialog,
                ),
              const SizedBox(width: AppTokens.spacing4),
              if (!widget.isEmbedded)
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
              : _codes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.qr_code,
                            size: 48,
                            color: AppTokens.text03,
                          ),
                          const SizedBox(height: AppTokens.spacing12),
                          Text(
                            '생성된 초대코드가 없습니다',
                            style: AppTokens.textStyle(
                              fontSize: AppTokens.fontSize14,
                              color: AppTokens.text03,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCodes,
                      color: AppTokens.primaryTeal,
                      child: ListView(
                        padding:
                            const EdgeInsets.all(AppTokens.spacing16),
                        children: [
                          // 활성 코드
                          if (activeCodes.isNotEmpty) ...[
                            Text(
                              '활성 코드 (${activeCodes.length})',
                              style: AppTokens.textStyle(
                                fontSize: AppTokens.fontSize14,
                                fontWeight:
                                    AppTokens.fontWeightSemibold,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spacing8),
                            ...activeCodes
                                .map((c) => _buildCodeCard(c, true)),
                          ],

                          // 비활성 코드
                          if (inactiveCodes.isNotEmpty) ...[
                            if (activeCodes.isNotEmpty)
                              const SizedBox(
                                  height: AppTokens.spacing24),
                            Text(
                              '비활성 코드 (${inactiveCodes.length})',
                              style: AppTokens.textStyle(
                                fontSize: AppTokens.fontSize14,
                                fontWeight:
                                    AppTokens.fontWeightSemibold,
                                color: AppTokens.text03,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spacing8),
                            ...inactiveCodes
                                .map((c) => _buildCodeCard(c, false)),
                          ],
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCodeCard(Map<String, dynamic> codeData, bool isActive) {
    final code = codeData['code'] as String? ?? '';
    final codeId = codeData['invite_code_id'] as String? ?? '';
    final role = codeData['target_role'] as String?;
    final maxUses = codeData['max_uses'] as int? ?? 0;
    final usedCount = codeData['used_count'] as int? ?? 0;
    final isExpired = codeData['is_expired'] == true;
    final expiresAt = codeData['expires_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.spacing8),
      padding: const EdgeInsets.all(AppTokens.spacing12),
      decoration: BoxDecoration(
        color: isActive ? AppTokens.bgBasic01 : AppTokens.bgBasic03,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(
          color: isActive
              ? _getRoleColor(role).withValues(alpha: 0.4)
              : AppTokens.line03,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 코드
              Text(
                code,
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize16,
                  fontWeight: AppTokens.fontWeightBold,
                  color: isActive
                      ? AppTokens.primaryTeal
                      : AppTokens.text03,
                ),
              ),
              const SizedBox(width: AppTokens.spacing8),
              // 역할 배지
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spacing8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppTokens.radius4),
                ),
                child: Text(
                  _getRoleName(role),
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize11,
                    fontWeight: AppTokens.fontWeightMedium,
                    color: _getRoleColor(role),
                  ),
                ),
              ),
              const Spacer(),
              // 상태 배지
              if (!isActive || isExpired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spacing8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.semanticError
                        .withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTokens.radius4),
                  ),
                  child: Text(
                    isExpired ? '만료' : '비활성',
                    style: AppTokens.textStyle(
                      fontSize: AppTokens.fontSize11,
                      color: AppTokens.semanticError,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.spacing8),

          // 사용량 + 만료일
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 14,
                color: AppTokens.text03,
              ),
              const SizedBox(width: 4),
              Text(
                '$usedCount / $maxUses 사용',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize12,
                  color: AppTokens.text03,
                ),
              ),
              if (expiresAt != null) ...[
                const SizedBox(width: AppTokens.spacing12),
                const Icon(
                  Icons.schedule,
                  size: 14,
                  color: AppTokens.text03,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatExpiry(expiresAt),
                  style: AppTokens.textStyle(
                    fontSize: AppTokens.fontSize12,
                    color: isExpired
                        ? AppTokens.semanticError
                        : AppTokens.text03,
                  ),
                ),
              ],
            ],
          ),

          // 액션 버튼
          if (isActive && !isExpired) ...[
            const SizedBox(height: AppTokens.spacing8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    ShareHelper.copyToClipboardWithToast(context, code);
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('복사'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.primaryTeal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spacing8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    ShareHelper.share(
                      context: context,
                      text:
                          'SafeTrip 초대코드: $code\n역할: ${_getRoleName(role)}',
                    );
                  },
                  icon: const Icon(Icons.share, size: 14),
                  label: const Text('공유'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.primaryTeal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spacing8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _deactivateCode(codeId, code),
                  icon: const Icon(Icons.block, size: 14),
                  label: const Text('비활성화'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.semanticError,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spacing8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatExpiry(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = date.difference(now);
      if (diff.isNegative) return '만료됨';
      if (diff.inDays > 0) return '${diff.inDays}일 남음';
      if (diff.inHours > 0) return '${diff.inHours}시간 남음';
      return '곧 만료';
    } catch (_) {
      return dateStr;
    }
  }
}
