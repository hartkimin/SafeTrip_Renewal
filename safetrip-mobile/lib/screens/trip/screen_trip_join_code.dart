import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/l10n/welcome_strings.dart';
import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';

class ScreenTripJoinCode extends StatefulWidget {
  const ScreenTripJoinCode({super.key, this.authNotifier});

  /// Optional AuthNotifier for deep link auto-fill (DOC-T3-WLC-029 §3.2)
  final AuthNotifier? authNotifier;

  @override
  State<ScreenTripJoinCode> createState() => _ScreenTripJoinCodeState();
}

class _ScreenTripJoinCodeState extends State<ScreenTripJoinCode> {
  final List<TextEditingController> _controllers = List.generate(
    7,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(7, (_) => FocusNode());

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // DOC-T3-WLC-029 §3.2: Auto-fill invite code from deep link
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authNotifier = widget.authNotifier;
      if (authNotifier == null) return;
      final pendingCode = authNotifier.pendingInviteCode;
      authNotifier.clearPendingInviteCode();
      if (pendingCode != null && pendingCode.isNotEmpty) {
        // Fill each character into the 6-digit code controllers
        final code = pendingCode.toUpperCase();
        for (int i = 0; i < code.length && i < _controllers.length; i++) {
          _controllers[i].text = code[i];
        }
        setState(() {});
        // Auto-submit if code is complete (§03.1: 7-char codes)
        if (code.length == 7) {
          _onJoin();
        } else {
          // DOC-T3-WLC-029 §6.1: Deep link code incomplete — show manual input hint
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(WelcomeStrings.inviteCodeManualHint)),
            );
          }
        }
      } else if (pendingCode != null) {
        // DOC-T3-WLC-029 §6.1: Deep link parameter was present but empty/corrupted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(WelcomeStrings.inviteCodeManualHint)),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _fullCode => _controllers.map((c) => c.text).join().toUpperCase();
  bool get _isComplete => _fullCode.length == 7;

  Future<void> _onJoin() async {
    if (!_isComplete) return;

    setState(() => _isLoading = true);
    try {
      final repo = OnboardingRepository();
      final info = await repo.previewInviteCode(_fullCode);
      if (info == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유효하지 않은 초대코드입니다. 캡틴에게 확인해주세요.')),
          );
        }
        return;
      }

      // Store the code for later use after auth flow
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_invite_code', _fullCode);

      if (mounted) {
        final userId = prefs.getString('user_id');
        if (userId == null || userId.isEmpty) {
          // Not authenticated yet — go through auth flow
          context.push(RoutePaths.authPhone, extra: {'role': 'crew'});
        } else {
          // Already authenticated — go directly to invite confirm
          context.go(RoutePaths.onboardingInviteConfirm, extra: {
            'inviteCode': _fullCode,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참여에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('여행 참여')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    const Icon(
                      Icons.group_add_outlined,
                      size: 80,
                      color: AppColors.primaryTeal,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '초대코드를 입력하세요',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '캡틴에게 받은 7자리\n코드를 입력해주세요',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        return SizedBox(
                          width:
                              (MediaQuery.of(context).size.width - 48 - 36) / 7,
                          height: 56,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(1),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Z0-9]'),
                              ),
                            ],
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.primaryTeal,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              fillColor: AppColors.surfaceVariant,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                if (index < 6) {
                                  _focusNodes[index + 1].requestFocus();
                                } else {
                                  _focusNodes[index].unfocus();
                                  _onJoin();
                                }
                              } else {
                                if (index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              }
                              setState(() {});
                            },
                          ),
                        );
                      }),
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
                  onPressed: _isComplete && !_isLoading ? _onJoin : null,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('참여하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
