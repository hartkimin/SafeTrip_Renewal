import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../router/route_paths.dart';

class ScreenBirthDate extends StatefulWidget {
  const ScreenBirthDate({super.key, required this.role});
  final String role;

  @override
  State<ScreenBirthDate> createState() => _ScreenBirthDateState();
}

class _ScreenBirthDateState extends State<ScreenBirthDate> {
  DateTime _selectedDate = DateTime(2000, 1, 1);
  bool _hasSelected = false;

  int get _age {
    final now = DateTime.now();
    int age = now.year - _selectedDate.year;
    if (now.month < _selectedDate.month ||
        (now.month == _selectedDate.month && now.day < _selectedDate.day)) {
      age--;
    }
    return age;
  }

  String? get _ageWarning {
    if (!_hasSelected) return null;
    if (_age < 14) return '만 14세 미만은 법정대리인의 동의가 필요합니다. (Phase 2 구현 예정)';
    if (_age < 18) return '만 18세 미만은 보호자 동의가 필요할 수 있습니다. (Phase 2 구현 예정)';
    return null;
  }

  Future<void> _onNext() async {
    if (!_hasSelected) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_minor', _age < 18);
    await prefs.setString('date_of_birth',
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}');

    if (mounted) {
      context.push(RoutePaths.authProfile, extra: {
        'userId': prefs.getString('user_id') ?? '',
        'role': widget.role,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('생년월일')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Text('생년월일을 입력해주세요',
                        style: AppTypography.titleLarge
                            .copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('서비스 이용 연령 확인을 위해 필요합니다',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.xxl),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _selectedDate,
                        minimumDate: DateTime(1920),
                        maximumDate: DateTime.now(),
                        onDateTimeChanged: (date) {
                          setState(() {
                            _selectedDate = date;
                            _hasSelected = true;
                          });
                        },
                      ),
                    ),
                    if (_ageWarning != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        margin: const EdgeInsets.only(top: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(_ageWarning!,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: Colors.orange.shade800)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: _hasSelected ? _onNext : null,
                  child: const Text('다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
