import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../constants/app_tokens.dart';
import '../../../../services/api_service.dart';
import 'invite_code_management_modal.dart';

/// 멤버 추가 모달 — 초대코드 탭 + 직접 검색 탭
class AddMemberModal extends StatefulWidget {

  const AddMemberModal({super.key, required this.groupId});
  final String groupId;

  @override
  State<AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends State<AddMemberModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // 직접 검색 탭 상태
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _apiService.searchUsers(query.trim());
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(query);
    });
  }

  Future<void> _inviteUser(Map<String, dynamic> user) async {
    final userId = user['user_id'] as String?;
    if (userId == null) return;

    String selectedRole = 'crew';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius16),
          ),
          title: Text(
            '역할 선택',
            style: AppTokens.textStyle(
              fontSize: AppTokens.fontSize16,
              fontWeight: AppTokens.fontWeightBold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user['user_name'] ?? user['phone_number'] ?? '사용자'}를\n어떤 역할로 초대할까요?',
                style: AppTokens.textStyle(
                  fontSize: AppTokens.fontSize14,
                  color: AppTokens.text04,
                ),
              ),
              const SizedBox(height: AppTokens.spacing12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radius8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'crew_chief', child: Text('공동관리자')),
                  DropdownMenuItem(value: 'crew', child: Text('일반 멤버')),
                  DropdownMenuItem(value: 'guardian', child: Text('모니터링 전용')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                '취소',
                style: AppTokens.textStyle(color: AppTokens.text03),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.primaryTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius8),
                ),
              ),
              child: Text(
                '초대',
                style: AppTokens.textStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await _apiService.inviteUserToGroup(
      groupId: widget.groupId,
      targetUserId: userId,
      role: selectedRole,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result ? '초대되었습니다' : '초대에 실패했습니다')),
      );
      if (result) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spacing16,
              AppTokens.spacing16,
              AppTokens.spacing8,
              0,
            ),
            child: Row(
              children: [
                Text(
                  '멤버 추가',
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
          // 탭 바
          TabBar(
            controller: _tabController,
            labelColor: AppTokens.primaryTeal,
            unselectedLabelColor: AppTokens.text03,
            indicatorColor: AppTokens.primaryTeal,
            tabs: const [
              Tab(text: '초대코드'),
              Tab(text: '직접 검색'),
            ],
          ),
          // 탭 뷰
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInviteCodeTab(),
                _buildDirectSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeTab() {
    return InviteCodeManagementModal(
      groupId: widget.groupId,
      isEmbedded: true,
    );
  }

  Widget _buildDirectSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spacing16),
      child: Column(
        children: [
          // 검색 입력
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '이름 또는 전화번호로 검색',
              hintStyle: AppTokens.textStyle(color: AppTokens.text03),
              prefixIcon: const Icon(Icons.search, color: AppTokens.text03),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTokens.primaryTeal,
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: AppTokens.bgBasic03,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spacing16,
                vertical: AppTokens.spacing12,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: AppTokens.spacing12),
          // 검색 결과
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.length < 2
                          ? '2자 이상 입력하세요'
                          : '검색 결과가 없습니다',
                      style: AppTokens.textStyle(
                        fontSize: AppTokens.fontSize14,
                        color: AppTokens.text03,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppTokens.line03),
                    itemBuilder: (ctx, i) {
                      final user = _searchResults[i];
                      final name = user['user_name'] as String? ?? '';
                      final phone = user['phone_number'] as String? ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTokens.bgTeal03,
                          child: Text(
                            name.isNotEmpty ? name[0] : '?',
                            style: AppTokens.textStyle(
                              color: AppTokens.primaryTeal,
                              fontWeight: AppTokens.fontWeightBold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: AppTokens.textStyle(
                            fontWeight: AppTokens.fontWeightSemibold,
                          ),
                        ),
                        subtitle: Text(
                          phone,
                          style: AppTokens.textStyle(
                            fontSize: AppTokens.fontSize12,
                            color: AppTokens.text03,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _inviteUser(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTokens.primaryTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radius8,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(
                            '초대',
                            style: AppTokens.textStyle(
                              color: Colors.white,
                              fontSize: AppTokens.fontSize12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
