import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../constants/asian_countries.dart';
import '../../services/api_service.dart';
import '../../widgets/country_search_bottom_sheet.dart';
import '../../router/route_paths.dart';

class ScreenTripCreate extends StatefulWidget {
  const ScreenTripCreate({super.key});

  @override
  State<ScreenTripCreate> createState() => _ScreenTripCreateState();
}

class _ScreenTripCreateState extends State<ScreenTripCreate> {
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
    
    setState(() => _isLoading = true);
    try {
      final trip = await _apiService.createTrip(
        title: _nameController.text.trim(),
        countryCode: _selectedCountryCode!,
        tripType: 'leisure',
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
      );

      if (trip != null && mounted) {
        // 성공 시 메인으로 이동 (실제로는 여기서 멤버 초대 화면 등으로 갈 수 있음)
        context.go(RoutePaths.main);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('여행 생성에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
