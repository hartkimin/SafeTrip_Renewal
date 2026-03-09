import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../constants/asian_countries.dart';
import '../../features/trip_card/providers/trip_card_provider.dart';
import '../../features/trip/providers/trip_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/country_search_bottom_sheet.dart';
import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';

class ScreenTripCreate extends ConsumerStatefulWidget {
  const ScreenTripCreate({super.key, required this.authNotifier});

  final AuthNotifier authNotifier;

  @override
  ConsumerState<ScreenTripCreate> createState() => _ScreenTripCreateState();
}

class _ScreenTripCreateState extends ConsumerState<ScreenTripCreate> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  
  String? _selectedCountryCode;
  String? _selectedCountryName;
  DateTime? _startDate;
  DateTime? _endDate;
  
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  bool get _canProceed =>
      _nameController.text.trim().length >= 2 &&
      _selectedCountryCode != null &&
      _startDate != null &&
      _endDate != null;

  Future<void> _onCreate() async {
    if (!_canProceed) return;

    // §08: 클라이언트 측 15일 초과 검증
    final duration = _endDate!.difference(_startDate!).inDays;
    if (duration > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행 기간은 최대 15일을 초과할 수 없습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Phase 1: 여행 생성 API 호출
    Map<String, dynamic>? trip;
    try {
      debugPrint('[TripCreate] Phase 1: createTrip API 호출...');
      debugPrint('[TripCreate]   title=${_nameController.text.trim()}, country=$_selectedCountryCode');
      debugPrint('[TripCreate]   dates=${DateFormat('yyyy-MM-dd').format(_startDate!)} ~ ${DateFormat('yyyy-MM-dd').format(_endDate!)}');

      trip = await _apiService.createTrip(
        title: _nameController.text.trim(),
        countryCode: _selectedCountryCode!,
        tripType: 'group',
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        countryName: _selectedCountryName,
      );

      if (trip == null) {
        debugPrint('[TripCreate] Phase 1 FAIL: createTrip returned null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('여행 생성에 실패했습니다. 다시 시도해주세요.')),
          );
        }
        return;
      }
      debugPrint('[TripCreate] Phase 1 OK: tripId=${trip['tripId']}, groupId=${trip['groupId']}');
    } catch (e) {
      debugPrint('[TripCreate] Phase 1 ERROR: $e');
      if (mounted) {
        final msg = e.toString().contains('DioException')
            ? '서버 연결에 실패했습니다. 네트워크를 확인해주세요.'
            : '여행 생성에 실패했습니다: ${e.toString().substring(0, (e.toString().length).clamp(0, 80))}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    } finally {
      if (trip == null && mounted) setState(() => _isLoading = false);
    }

    // Phase 2: 여행 생성 성공 후 상태 갱신 + 네비게이션
    // 이 단계에서 에러가 발생해도 여행은 이미 생성되었으므로 main으로 이동
    if (!mounted) return;
    try {
      final groupId = trip['groupId'] as String?;
      debugPrint('[TripCreate] Phase 2: setActiveTrip groupId=$groupId');
      if (groupId != null) {
        await widget.authNotifier.setActiveTrip(groupId);
      }

      debugPrint('[TripCreate] Phase 2: fetchCardView...');
      await ref.read(tripCardProvider.notifier).fetchCardView();

      debugPrint('[TripCreate] Phase 2: setCurrentTripDetails...');
      ref.read(tripProvider.notifier).setCurrentTripDetails(
        tripName: trip['tripName'] as String? ?? _nameController.text.trim(),
        tripStatus: trip['status'] as String? ?? 'planning',
        userRole: 'captain',
        tripStartDate: _startDate,
        tripEndDate: _endDate,
        countryCode: _selectedCountryCode,
        countryName: _selectedCountryName,
      );
    } catch (e) {
      // 여행은 이미 생성됨 — 상태 갱신 실패는 무시하고 main으로 이동
      debugPrint('[TripCreate] Phase 2 WARNING (trip already created): $e');
    }

    debugPrint('[TripCreate] Phase 3: context.go(main)');
    if (mounted) {
      setState(() => _isLoading = false);
      context.go(RoutePaths.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('여행 만들기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('여행 정보를\n입력해주세요', style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xl),

            _buildLabel('여행 이름 *'),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: '예: 도쿄 자유여행'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildLabel('국가 선택 *'),
            _buildCountryField(),
            const SizedBox(height: AppSpacing.md),

            _buildLabel('도시'),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(hintText: '예: 도쿄, 오사카'),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildLabel('여행 기간 *'),
            _buildDateRangeField(),
            if (_startDate != null && _endDate != null) ...[
              Builder(builder: (context) {
                final days = _endDate!.difference(_startDate!).inDays + 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    days >= 15
                        ? '여행 기간이 최대(15일)에 달했습니다'
                        : '$days일 여행',
                    style: TextStyle(
                      color: days >= 15 ? Colors.orange : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: AppSpacing.xxl),

            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: _canProceed && !_isLoading ? _onCreate : null,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('여행 생성하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: AppTypography.labelMedium),
    );
  }

  Widget _buildCountryField() {
    return GestureDetector(
      onTap: () async {
        final result = await CountrySearchBottomSheet.show(context, countries: kAsianCountries.map((e) => Map<String, dynamic>.from(e)).toList());
        if (result != null) {
          setState(() {
            _selectedCountryCode = result['country_code'] as String?;
            _selectedCountryName = (result['country_name_ko'] as String?) ?? (result['country_name'] as String?);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
        ),
        child: Row(
          children: [
            Expanded(child: Text(_selectedCountryName ?? '선택해주세요', style: TextStyle(color: _selectedCountryName != null ? AppColors.textPrimary : AppColors.textTertiary))),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showTripDurationLimitModal(DateTime startDate, int days) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('여행 기간은 최대 15일입니다'),
        content: Text(
          '$days일 여행을 계획 중이신가요?\n\n'
          '두 개의 여행으로 나누어 생성하세요.\n'
          '예: 1차 여행 (1~15일) + 2차 (16~$days일)',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _startDate = startDate;
                _endDate = startDate.add(const Duration(days: 14));
              });
            },
            child: const Text('15일로 조정'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 1차 여행: 15일로 설정 후, 사용자가 나중에 2차 여행을 생성
              setState(() {
                _startDate = startDate;
                _endDate = startDate.add(const Duration(days: 14));
              });
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('1차 여행(15일)이 설정되었습니다. 나머지 일정은 별도 여행으로 생성해주세요.')),
              );
            },
            child: const Text('나누기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeField() {
    final rangeText = (_startDate != null && _endDate != null)
        ? '${DateFormat('yyyy.MM.dd').format(_startDate!)} ~ ${DateFormat('yyyy.MM.dd').format(_endDate!)}'
        : '시작일 ~ 종료일';
    
    return GestureDetector(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          final duration = picked.end.difference(picked.start).inDays + 1; // inclusive
          if (duration > 15) {
            if (mounted) _showTripDurationLimitModal(picked.start, duration);
            return;
          }
          setState(() {
            _startDate = picked.start;
            _endDate = picked.end;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
        ),
        child: Row(
          children: [
            Expanded(child: Text(rangeText, style: TextStyle(color: _startDate != null ? AppColors.textPrimary : AppColors.textTertiary))),
            const Icon(Icons.calendar_today, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}
