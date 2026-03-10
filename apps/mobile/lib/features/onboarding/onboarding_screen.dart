import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import 'onboarding_provider.dart';
import 'step1_etf_select.dart';
import 'step2_loading.dart';
import 'step3_first_feed.dart';
import 'step4_push_permission.dart';

/// Main onboarding container with PageView for 4 steps.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  late final DateTime _onboardingStartTime;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _onboardingStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    ref.read(onboardingProvider.notifier).goToStep(step);
    _pageController.animateToPage(
      step,
      duration: PortfiqTheme.screenTransition,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Step1EtfSelect(onNext: () => _goToStep(1)),
            Step2Loading(onNext: () => _goToStep(2)),
            Step3FirstFeed(
              onShowPushSheet: () => _showPushPermissionSheet(context),
            ),
            // Step 4 is shown as a bottom sheet from step 3
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  void _showPushPermissionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Step4PushPermission(
        onGranted: () {
          ref.read(onboardingProvider.notifier).setPushPermission(true);
          Navigator.of(context).pop();
          _completeOnboarding();
        },
        onDenied: () {
          ref.read(onboardingProvider.notifier).setPushPermission(false);
          Navigator.of(context).pop();
          _completeOnboarding();
        },
      ),
    );
  }

  void _completeOnboarding() {
    if (mounted) {
      final state = ref.read(onboardingProvider);
      final durationSeconds =
          DateTime.now().difference(_onboardingStartTime).inSeconds;

      EventTracker.instance.track('onboarding_completed', properties: {
        'etf_count': state.selectedEtfs.length,
        'duration_seconds': durationSeconds,
        'push_enabled': state.pushPermissionGranted ?? false,
      });

      Hive.box('settings').put('onboarding_completed', true);
      context.go('/home');
    }
  }
}
