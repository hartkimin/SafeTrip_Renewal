import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../router/auth_notifier.dart';
import '../../../../router/route_paths.dart';
import '../../../../services/api_service.dart';

/// A-06 Profile Setup Screen
class ScreenProfileSetup extends StatefulWidget {
  const ScreenProfileSetup({
    super.key,
    required this.userId,
    required this.role,
    required this.authNotifier,
  });

  final String userId;
  final String role;
  final AuthNotifier authNotifier;

  @override
  State<ScreenProfileSetup> createState() => _ScreenProfileSetupState();
}

class _ScreenProfileSetupState extends State<ScreenProfileSetup> {
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _apiService = ApiService();

  File? _selectedImage;
  bool _isLoading = false;
  DateTime? _selectedBirthDate;

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthDate ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _submit({bool skipProfile = false}) async {
    if (!skipProfile && !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final emergencyContact = _emergencyContactController.text.trim();
      
      if (!skipProfile) {
        await _apiService.updateUserProfile(
          widget.userId,
          name,
          birthDate: _birthDateController.text,
          emergencyContact: emergencyContact.isNotEmpty ? emergencyContact : null,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      if (name.isNotEmpty) await prefs.setString('user_name', name);
      await prefs.setString('user_role', widget.role);
      
      int age = 20;
      if (_selectedBirthDate != null) {
        age = _calculateAge(_selectedBirthDate!);
        await prefs.setBool('is_minor', age < 18);
      }

      await widget.authNotifier.completeOnboarding();
      if (!mounted) return;

      // 미성년자 처리 (간소화됨)
      if (age < 18) {
        // TODO: Minor consent screen if needed
      }

      final groupId = prefs.getString('group_id') ?? '';
      await widget.authNotifier.setAuthenticated(hasTrip: groupId.isNotEmpty);
      
      if (mounted) context.go(RoutePaths.main);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('프로필 설정')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      Text('프로필을 설정해주세요', style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.surfaceVariant,
                            backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                            child: _selectedImage == null ? const Icon(Icons.camera_alt, size: 30) : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: '이름', hintText: '이름을 입력하세요'),
                        validator: (v) => (v == null || v.isEmpty) ? '이름을 입력해주세요' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _birthDateController,
                        readOnly: true,
                        onTap: _selectBirthDate,
                        decoration: const InputDecoration(labelText: '생년월일', hintText: 'YYYY-MM-DD', suffixIcon: Icon(Icons.calendar_today)),
                        validator: (v) => (v == null || v.isEmpty) ? '생년월일을 선택해주세요' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _emergencyContactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: '비상 연락처', hintText: '010-0000-0000'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('완료'),
                    ),
                  ),
                  TextButton(onPressed: () => _submit(skipProfile: true), child: const Text('나중에 설정')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
