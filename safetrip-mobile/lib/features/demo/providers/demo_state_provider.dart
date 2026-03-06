import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/demo_scenario.dart';

class DemoState {
  const DemoState({
    this.isActive = false,
    this.currentScenario,
    this.currentRole = DemoRole.captain,
    this.currentGrade = DemoPrivacyGrade.standard,
    this.simStartTime,
    this.currentSimTime,
    this.isEventPlaying = false,
    this.currentEventIndex = 0,
    this.viewedCoachmarks = const {},
    this.isGuardianUpgraded = false,
  });

  final bool isActive;
  final DemoScenario? currentScenario;
  final DemoRole currentRole;
  final DemoPrivacyGrade currentGrade;
  final DateTime? simStartTime;
  final DateTime? currentSimTime;
  final bool isEventPlaying;
  final int currentEventIndex;
  final Set<String> viewedCoachmarks;
  final bool isGuardianUpgraded;

  DemoState copyWith({
    bool? isActive,
    DemoScenario? currentScenario,
    DemoRole? currentRole,
    DemoPrivacyGrade? currentGrade,
    DateTime? simStartTime,
    DateTime? currentSimTime,
    bool? isEventPlaying,
    int? currentEventIndex,
    Set<String>? viewedCoachmarks,
    bool? isGuardianUpgraded,
  }) {
    return DemoState(
      isActive: isActive ?? this.isActive,
      currentScenario: currentScenario ?? this.currentScenario,
      currentRole: currentRole ?? this.currentRole,
      currentGrade: currentGrade ?? this.currentGrade,
      simStartTime: simStartTime ?? this.simStartTime,
      currentSimTime: currentSimTime ?? this.currentSimTime,
      isEventPlaying: isEventPlaying ?? this.isEventPlaying,
      currentEventIndex: currentEventIndex ?? this.currentEventIndex,
      viewedCoachmarks: viewedCoachmarks ?? this.viewedCoachmarks,
      isGuardianUpgraded: isGuardianUpgraded ?? this.isGuardianUpgraded,
    );
  }

  /// Current role as string for SharedPreferences/TripProvider compatibility
  String get roleString {
    switch (currentRole) {
      case DemoRole.captain:
        return 'captain';
      case DemoRole.crewChief:
        return 'crew_chief';
      case DemoRole.crew:
        return 'crew';
      case DemoRole.guardian:
        return 'guardian';
    }
  }

  /// Current user (the first member matching the role)
  DemoMember? get currentUser {
    if (currentScenario == null) return null;
    return currentScenario!.members.firstWhere(
      (m) => m.role == roleString,
      orElse: () => currentScenario!.members.first,
    );
  }

  /// Check if a feature is accessible for current role (§3.4, §4)
  bool canAccess(String feature) {
    switch (feature) {
      case 'trip_settings':
      case 'guardian_billing':
      case 'privacy_grade_change':
        return currentRole == DemoRole.captain;
      case 'member_invite':
      case 'schedule_edit':
        return currentRole == DemoRole.captain ||
            currentRole == DemoRole.crewChief;
      case 'sos':
      case 'chat':
      case 'member_tab':
        return currentRole != DemoRole.guardian;
      case 'map_all_members':
        return currentRole != DemoRole.guardian;
      case 'map_linked_members':
        return currentRole == DemoRole.guardian;
      default:
        return true;
    }
  }
}

class DemoStateNotifier extends StateNotifier<DemoState> {
  DemoStateNotifier() : super(const DemoState());

  void startDemo(DemoScenario scenario) {
    final now = DateTime.now();
    state = DemoState(
      isActive: true,
      currentScenario: scenario,
      currentRole: DemoRole.captain,
      currentGrade: scenario.privacyGrade,
      simStartTime: now,
      currentSimTime: now,
    );
  }

  void switchRole(DemoRole role) {
    // §3.4: 역할 전환 시 데이터 유지, 뷰만 변경
    state = state.copyWith(
      currentRole: role,
      isEventPlaying: false,
    );
  }

  void switchGrade(DemoPrivacyGrade grade) {
    state = state.copyWith(currentGrade: grade);
  }

  void setSimTime(DateTime time) {
    state = state.copyWith(currentSimTime: time);
  }

  void toggleEventPlayback() {
    state = state.copyWith(isEventPlaying: !state.isEventPlaying);
  }

  void advanceEvent() {
    state = state.copyWith(currentEventIndex: state.currentEventIndex + 1);
  }

  void markCoachmarkViewed(String id) {
    state = state.copyWith(
      viewedCoachmarks: {...state.viewedCoachmarks, id},
    );
  }

  void toggleGuardianUpgrade() {
    state = state.copyWith(isGuardianUpgraded: !state.isGuardianUpgraded);
  }

  void endDemo() {
    state = const DemoState();
  }
}

final demoStateProvider =
    StateNotifierProvider<DemoStateNotifier, DemoState>((ref) {
  return DemoStateNotifier();
});

/// Convenience: is demo mode active?
final isDemoModeProvider = Provider<bool>((ref) {
  return ref.watch(demoStateProvider).isActive;
});
