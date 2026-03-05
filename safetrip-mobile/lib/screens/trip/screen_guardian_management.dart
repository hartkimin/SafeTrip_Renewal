import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';
import '../../utils/app_cache.dart';
import '../../widgets/avatar_widget.dart';

class ScreenGuardianManagement extends StatefulWidget {
  const ScreenGuardianManagement({super.key});

  @override
  State<ScreenGuardianManagement> createState() =>
      _ScreenGuardianManagementState();
}

class _ScreenGuardianManagementState extends State<ScreenGuardianManagement> {
  final _apiService = ApiService();
  bool _isLoading = true;
  String? _tripId;
  String? _userId;
  List<dynamic> _guardians = [];

  final int _freeLimit = 2;
  final int _maxLimit = 5;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      _tripId = await AppCache.tripId;

      if (_tripId != null && _userId != null) {
        final guardians = await _apiService.getMyGuardians(_tripId!);
        setState(() => _guardians = guardians);
      }
    } catch (e) {
      debugPrint('[GuardianScreen] 로드 에러: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onAddGuardianTapped() {
    if (_guardians.length >= _maxLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가디언은 최대 5명까지만 연결할 수 있습니다.')),
      );
      return;
    }

    if (_guardians.length >= _freeLimit) {
      _showPaywallModal();
    } else {
      _showAddGuardianDialog();
    }
  }

  void _showAddGuardianDialog() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가디언 추가'),
        content: TextField(
          controller: phoneController,
          decoration: const InputDecoration(
            hintText: '가디언 전화번호 입력',
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) return;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final result = await _apiService.addGuardian(_tripId!, phone);
                if (result != null) {
                  await _loadGuardians();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('가디언 추가에 실패했습니다.')),
                    );
                  }
                }
              } catch (e) {
                debugPrint('[GuardianScreen] 추가 에러: $e');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('요청'),
          ),
        ],
      ),
    );
  }

  void _showPaywallModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radius24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, color: AppColors.outline),
            const SizedBox(height: AppSpacing.lg),
            const Text('추가 가디언 연결', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '현재 무료 가디언 2명을 모두 사용 중입니다.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryTeal),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('추가 가디언 (유료)', style: AppTypography.titleMedium),
                      Text('1명', style: AppTypography.titleMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1,900원/여행',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    '결제 즉시 적용되며, 환불이 불가합니다.',
                    style: TextStyle(color: AppColors.sosDanger, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _processPayment();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                    ),
                    child: const Text(
                      '결제하고 연결',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _processPayment() async {
    setState(() => _isLoading = true);
    // Mock Payment Process
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('결제가 완료되었습니다.')));
      _showAddGuardianDialog(); // 결제 성공 후 추가 다이얼로그 표시
    }
  }

  void _showRemoveConfirmation(dynamic guardian) {
    final isPaid = guardian['is_paid'] == true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가디언 연결 해제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${guardian['display_name']}님과의 가디언 연결을 해제하시겠습니까?'),
            if (isPaid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sosDanger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: AppColors.sosDanger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '해제 후 환불되지 않습니다.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.sosDanger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeGuardian(guardian);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sosDanger),
            child: const Text('해제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeGuardian(dynamic guardian) async {
    setState(() => _isLoading = true);
    try {
      final linkId = guardian['link_id']?.toString() ?? '';
      final success = await _apiService.removeGuardianLink(_tripId!, linkId);
      if (success) {
        await _loadGuardians();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('가디언이 해제되었습니다.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('해제에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('[GuardianScreen] 해제 에러: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final freeGuardians = _guardians
        .where((g) => g['is_paid'] != true)
        .toList();
    final paidGuardians = _guardians
        .where((g) => g['is_paid'] == true)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('가디언 관리'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _buildSection(
                  '🆓 무료 슬롯 (${freeGuardians.length}/$_freeLimit 사용)',
                  freeGuardians,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (freeGuardians.length >= _freeLimit ||
                    paidGuardians.isNotEmpty)
                  _buildSection(
                    '💳 유료 슬롯 (${paidGuardians.length}/3 사용)  1,900원/여행',
                    paidGuardians,
                  ),

                const SizedBox(height: AppSpacing.xl),
                ElevatedButton.icon(
                  onPressed: _guardians.length >= _maxLimit
                      ? null
                      : _onAddGuardianTapped,
                  icon: const Icon(Icons.add),
                  label: Text(
                    _guardians.length >= _freeLimit ? '유료 가디언 추가' : '무료 가디언 추가',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('등록된 가디언이 없습니다.')),
          )
        else
          ...items.map((g) => _buildGuardianTile(g)),
      ],
    );
  }

  Widget _buildGuardianTile(dynamic guardian) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: AvatarWidget(
          userId: guardian['link_id'],
          userName: guardian['display_name'],
          radius: 20,
        ),
        title: Text(guardian['display_name'], style: AppTypography.titleMedium),
        subtitle: Row(
          children: [
            Text(guardian['phone_number'], style: AppTypography.bodySmall),
            const SizedBox(width: AppSpacing.sm),
            if (guardian['status'] == 'accepted')
              const Text(
                '✅ 연결됨',
                style: TextStyle(
                  color: AppColors.semanticSuccess,
                  fontSize: 12,
                ),
              )
            else
              const Text(
                '⏳ 대기 중',
                style: TextStyle(color: AppColors.secondaryAmber, fontSize: 12),
              ),
            if (guardian['is_paid'] == true)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  '결제 완료',
                  style: TextStyle(color: AppColors.primaryTeal, fontSize: 12),
                ),
              ),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _showRemoveConfirmation(guardian),
          child: const Text('해제', style: TextStyle(color: AppColors.sosDanger)),
        ),
      ),
    );
  }
}
