import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../services/api_service.dart';
import '../../utils/app_cache.dart';
import '../../core/constants/avatar_constants.dart';
import '../../widgets/avatar_selector.dart';
import '../../widgets/guardian_badge.dart';

/// 프로필 편집 화면
///
/// 설정 메뉴 원칙 4.1에 따라 프로필 사진, 이름, 전화번호, 언어 설정을 관리한다.
/// - 프로필 사진: 카메라/갤러리에서 선택 (image_picker)
/// - 이름: 수정 가능, 서버에 저장
/// - 전화번호: 읽기 전용
/// - 언어 설정: P2 플레이스홀더
class ScreenProfileEdit extends StatefulWidget {
  const ScreenProfileEdit({super.key});

  @override
  State<ScreenProfileEdit> createState() => _ScreenProfileEditState();
}

class _ScreenProfileEditState extends State<ScreenProfileEdit> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  String _userId = '';
  String? _phoneNumber;
  String? _profileImageUrl;
  File? _selectedImageFile;

  String? _avatarId;
  String? _privacyLevel;
  String? _minorStatus;
  bool _isGuardian = false;
  bool _isPaidGuardian = false;
  List<Map<String, dynamic>> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data Loading
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id') ?? '';
      _phoneNumber = prefs.getString('phone_number');
      _profileImageUrl = prefs.getString('profile_image_url');
      _nameController.text = prefs.getString('user_name') ?? '';

      // Fetch latest data from server
      if (_userId.isNotEmpty) {
        final userData = await ApiService().getUserById(_userId);
        if (userData != null) {
          final serverName = userData['display_name'] as String? ??
              userData['user_name'] as String? ??
              '';
          if (serverName.isNotEmpty) {
            _nameController.text = serverName;
          }
          _profileImageUrl =
              userData['profile_image_url'] as String? ?? _profileImageUrl;
          _phoneNumber =
              userData['phone_number'] as String? ?? _phoneNumber;
          _avatarId = userData['avatar_id'] as String?;
          _privacyLevel = userData['privacy_level'] as String? ?? 'standard';
          _minorStatus = userData['minor_status'] as String?;
          _isGuardian = userData['user_role'] == 'guardian';
        }
      }
    } catch (e) {
      debugPrint('[ScreenProfileEdit] _loadUserData Error: $e');
    }

    // Load emergency contacts
    try {
      _emergencyContacts = await ApiService().getMyEmergencyContacts();
    } catch (e) {
      debugPrint('[ScreenProfileEdit] Emergency contacts load error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Image Picking
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onPickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('5MB 이하의 이미지를 선택해 주세요')),
            );
          }
          return;
        }
        setState(() {
          _selectedImageFile = file;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('프로필 사진은 현재 기기에만 저장됩니다.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ScreenProfileEdit] _onPickImage Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 선택할 수 없습니다.')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Save Profile
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ApiService().updateUserProfile(
        _userId,
        name,
        avatarId: _avatarId,
      );

      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);

      // Update AppCache
      await AppCache.setUserInfo(userName: name);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다.')),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[ScreenProfileEdit] _onSave Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 저장에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('프로필 편집'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _onSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '저장',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primaryTeal,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    // ── Profile Photo ────────────────────────────────
                    _buildProfilePhoto(),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Display Name ─────────────────────────────────
                    _buildSectionLabel('이름'),
                    _buildNameField(),

                    const SizedBox(height: AppSpacing.md),

                    // ── Phone Number (Read-only) ─────────────────────
                    _buildSectionLabel('전화번호'),
                    _buildPhoneField(),

                    const SizedBox(height: AppSpacing.md),

                    // ── Language Setting (P2 placeholder) ────────────
                    _buildSectionLabel('언어'),
                    _buildLanguageTile(),

                    const SizedBox(height: AppSpacing.md),

                    // ── Guardian Badge (if applicable) ───────────
                    if (_isGuardian) ...[
                      _buildSectionLabel('역할'),
                      Container(
                        color: AppColors.surface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPaddingH,
                          vertical: AppSpacing.inputPaddingV,
                        ),
                        child: Row(
                          children: [
                            GuardianBadge(isPaid: _isPaidGuardian),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── Avatar Selector ──────────────────────────
                    _buildSectionLabel('아바타'),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                      child: AvatarSelector(
                        selectedAvatarId: _avatarId,
                        onSelected: (id) {
                          setState(() => _avatarId = id);
                        },
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Emergency Contacts ───────────────────────
                    _buildSectionLabel('긴급 연락처'),
                    ..._emergencyContacts.map((contact) => Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPaddingH,
                        vertical: AppSpacing.inputPaddingV,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contact['contact_name'] ?? '',
                                  style: AppTypography.bodyLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  contact['phone_number'] ?? '',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: AppColors.textTertiary,
                            onPressed: () async {
                              final contactId = contact['contact_id'];
                              if (contactId != null) {
                                try {
                                  await ApiService().deleteEmergencyContact(contactId);
                                  setState(() {
                                    _emergencyContacts.removeWhere((c) => c['contact_id'] == contactId);
                                  });
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('긴급 연락처 삭제에 실패했습니다.')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    )),
                    if (_emergencyContacts.length < 2)
                      Container(
                        color: AppColors.surface,
                        child: ListTile(
                          leading: const Icon(Icons.add_circle_outline, color: AppColors.primaryTeal),
                          title: Text(
                            '긴급 연락처 추가',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.primaryTeal),
                          ),
                          onTap: () {
                            // TODO: show add emergency contact dialog
                          },
                        ),
                      ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Privacy Level (read-only) ────────────────
                    _buildSectionLabel('프라이버시 등급'),
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPaddingH,
                        vertical: AppSpacing.inputPaddingV,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _privacyLevel == 'safety_first' ? '안전최우선'
                                  : _privacyLevel == 'privacy_first' ? '프라이버시우선'
                                  : '표준',
                              style: AppTypography.bodyLarge,
                            ),
                          ),
                          Text(
                            '설정에서 변경',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Profile Photo
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfilePhoto() {
    return Center(
      child: GestureDetector(
        onTap: _onPickImage,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.outline,
              backgroundImage: _selectedImageFile != null
                  ? FileImage(_selectedImageFile!)
                  : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? NetworkImage(_profileImageUrl!) as ImageProvider
                      : const AssetImage('assets/images/avata_df.png')),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section Label
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
        AppSpacing.screenPaddingH,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Name Field
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNameField() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.xs,
      ),
      child: TextFormField(
        controller: _nameController,
        style: AppTypography.bodyLarge,
        decoration: InputDecoration(
          hintText: '이름을 입력하세요',
          hintStyle: AppTypography.bodyLarge.copyWith(
            color: AppColors.textDisabled,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSpacing.inputPaddingV,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '닉네임을 입력해주세요.';
          }
          if (value.trim().length < 2) {
            return '닉네임은 2자 이상 입력해 주세요';
          }
          if (value.trim().length > 20) {
            return '닉네임은 20자 이하로 입력해 주세요';
          }
          if (!RegExp(r'^[\w가-힣ㄱ-ㅎㅏ-ㅣ.]+$').hasMatch(value.trim())) {
            return '특수문자는 사용할 수 없습니다 (밑줄·점 제외)';
          }
          return null;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phone Field (Read-only)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPhoneField() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.inputPaddingV,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _phoneNumber ?? '-',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '변경 불가',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Language Tile (P2 placeholder)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLanguageTile() {
    return Container(
      color: AppColors.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
        ),
        title: const Text(
          '시스템 설정 따름',
          style: AppTypography.bodyLarge,
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: AppColors.outline,
        ),
        onTap: () {
          // P2: 언어 설정 화면 (미구현)
        },
      ),
    );
  }
}
