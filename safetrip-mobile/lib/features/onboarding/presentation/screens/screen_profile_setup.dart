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
  final _emergencyContactController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _apiService = ApiService();

  File? _selectedImage;
  bool _isLoading = false;
  String _privacyLevel = 'friends_only'; // §7.1 default: friends-only

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
      final prefs = await SharedPreferences.getInstance();

      // Birth date was saved by screen_birth_date.dart
      final birthDate = prefs.getString('date_of_birth');

      if (!skipProfile) {
        await _apiService.updateUserProfile(
          widget.userId,
          name,
          birthDate: birthDate,
          emergencyContact: emergencyContact.isNotEmpty ? emergencyContact : null,
          privacyLevel: _privacyLevel,
        );
      }

      if (name.isNotEmpty) await prefs.setString('user_name', name);
      await prefs.setString('user_role', widget.role);

      await widget.authNotifier.completeOnboarding();
      await widget.authNotifier.markProfileCompleted();

      // Check for pending invite code (Scenario B)
      final pendingCode = prefs.getString('pending_invite_code');
      if (pendingCode != null && pendingCode.isNotEmpty && mounted) {
        context.go(RoutePaths.onboardingInviteConfirm, extra: {
          'inviteCode': pendingCode,
        });
        return;
      }

      // Check for pending guardian code (Scenario C)
      final pendingGuardian = prefs.getString('pending_guardian_code');
      if (pendingGuardian != null && pendingGuardian.isNotEmpty && mounted) {
        context.go(RoutePaths.onboardingGuardianConfirm, extra: {
          'guardianCode': pendingGuardian,
        });
        return;
      }

      // Scenario A: captain — go to trip create
      if (widget.role == 'captain') {
        await widget.authNotifier.setAuthenticated(hasTrip: false);
        if (mounted) context.go(RoutePaths.tripCreate);
      } else {
        // Default: go to main or no-trip-home
        final groupId = prefs.getString('group_id') ?? '';
        await widget.authNotifier.setAuthenticated(hasTrip: groupId.isNotEmpty);
        if (mounted) {
          context.go(groupId.isNotEmpty ? RoutePaths.main : RoutePaths.noTripHome);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPrivacyOption(String value, String label, String description) {
    final isSelected = _privacyLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _privacyLevel = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? AppColors.primaryTeal : AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radius12),
          color: isSelected ? AppColors.primaryTeal.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primaryTeal : AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  Text(description, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
                        controller: _emergencyContactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: '비상 연락처', hintText: '010-0000-0000'),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // §7.1 Privacy level selection
                      Text('위치 공개 범위', style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),
                      _buildPrivacyOption('public', '공개', '모든 사용자에게 위치 공유'),
                      _buildPrivacyOption('friends_only', '친구만', '같은 여행 멤버에게만 공유'),
                      _buildPrivacyOption('private', '비공개', '위치를 공유하지 않음'),
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
