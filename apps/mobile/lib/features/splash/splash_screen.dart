import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade-in animation per MASTER.md: 600ms
    _fadeController = AnimationController(
      vsync: this,
      duration: PortfiqAnimations.splashFadeIn,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: PortfiqAnimations.defaultCurve,
    );
    _fadeController.forward();

    _navigate();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Check if onboarding completed
    final box = Hive.box('settings');
    final onboardingDone = box.get('onboarding_completed', defaultValue: false);

    if (onboardingDone) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: PortfiqGradients.splash,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo text with gradient shader
                ShaderMask(
                  shaderCallback: (bounds) =>
                      PortfiqGradients.indigo.createShader(bounds),
                  child: const Text(
                    'Portfiq',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.white, // required for ShaderMask
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: PortfiqSpacing.space12),
                // Subtitle
                Text(
                  '내 ETF 맞춤 브리핑',
                  style: PortfiqTypography.body.copyWith(
                    fontSize: 14,
                    color: PortfiqTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
