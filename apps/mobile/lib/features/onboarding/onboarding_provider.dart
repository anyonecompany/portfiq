import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the onboarding flow.
class OnboardingState {
  const OnboardingState({
    this.selectedEtfs = const [],
    this.currentStep = 0,
    this.isLoading = false,
    this.pushPermissionGranted,
  });

  final List<String> selectedEtfs;
  final int currentStep;
  final bool isLoading;
  final bool? pushPermissionGranted;

  OnboardingState copyWith({
    List<String>? selectedEtfs,
    int? currentStep,
    bool? isLoading,
    bool? pushPermissionGranted,
  }) {
    return OnboardingState(
      selectedEtfs: selectedEtfs ?? this.selectedEtfs,
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      pushPermissionGranted:
          pushPermissionGranted ?? this.pushPermissionGranted,
    );
  }
}

/// Notifier managing onboarding flow state.
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  static const List<String> popularEtfs = [
    'QQQ',
    'VOO',
    'SCHD',
    'TQQQ',
    'SOXL',
    'JEPI',
  ];

  /// Toggle an ETF ticker in the selection list.
  void toggleEtf(String ticker) {
    final current = List<String>.from(state.selectedEtfs);
    if (current.contains(ticker)) {
      current.remove(ticker);
    } else {
      current.add(ticker);
    }
    state = state.copyWith(selectedEtfs: current);
  }

  /// Whether at least 1 ETF is selected (CTA enabled condition).
  bool get canProceed => state.selectedEtfs.isNotEmpty;

  /// Move to the next onboarding step.
  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  /// Jump to a specific step.
  void goToStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  /// Set loading state (for step 2).
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Record push permission decision.
  void setPushPermission(bool granted) {
    state = state.copyWith(pushPermissionGranted: granted);
  }
}

/// Provider for onboarding state.
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
