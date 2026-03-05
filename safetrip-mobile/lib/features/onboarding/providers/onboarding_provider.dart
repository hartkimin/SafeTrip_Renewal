import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/onboarding_type.dart';
import '../domain/onboarding_step.dart';
import '../domain/consent_model.dart';

class OnboardingState {
  final OnboardingType type;
  final OnboardingStep step;
  final ConsentModel consent;
  final String? pendingInviteCode;
  final String? pendingGuardianLinkId;
  final String? userId;
  final String? role;
  final bool isEuUser;

  const OnboardingState({
    this.type = OnboardingType.captain,
    this.step = OnboardingStep.splash,
    this.consent = const ConsentModel(),
    this.pendingInviteCode,
    this.pendingGuardianLinkId,
    this.userId,
    this.role,
    this.isEuUser = false,
  });

  OnboardingState copyWith({
    OnboardingType? type,
    OnboardingStep? step,
    ConsentModel? consent,
    String? pendingInviteCode,
    String? pendingGuardianLinkId,
    String? userId,
    String? role,
    bool? isEuUser,
  }) {
    return OnboardingState(
      type: type ?? this.type,
      step: step ?? this.step,
      consent: consent ?? this.consent,
      pendingInviteCode: pendingInviteCode ?? this.pendingInviteCode,
      pendingGuardianLinkId: pendingGuardianLinkId ?? this.pendingGuardianLinkId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      isEuUser: isEuUser ?? this.isEuUser,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void setType(OnboardingType type) =>
      state = state.copyWith(type: type);

  void setStep(OnboardingStep step) =>
      state = state.copyWith(step: step);

  void setInviteCode(String code) =>
      state = state.copyWith(
        pendingInviteCode: code,
        type: OnboardingType.inviteCode,
      );

  void setGuardianLink(String linkId) =>
      state = state.copyWith(
        pendingGuardianLinkId: linkId,
        type: OnboardingType.guardian,
      );

  void setUserId(String userId) =>
      state = state.copyWith(userId: userId);

  void setRole(String role) =>
      state = state.copyWith(role: role);

  void updateConsent(ConsentModel consent) =>
      state = state.copyWith(consent: consent);

  void setEuUser(bool isEu) =>
      state = state.copyWith(isEuUser: isEu);

  void reset() => state = const OnboardingState();
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
