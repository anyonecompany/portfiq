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
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  late final AnimationController _subtitleController;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();

    // Logo: fade + scale, 600ms, easeOutCubic
    _logoController = AnimationController(
      vsync: this,
      duration: PortfiqAnimations.splash,
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: PortfiqAnimations.defaultCurve,
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: PortfiqAnimations.defaultCurve,
      ),
    );
    _logoController.forward();

    // Subtitle: 400ms delay + 400ms fade
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _subtitleFade = CurvedAnimation(
      parent: _subtitleController,
      curve: PortfiqAnimations.defaultCurve,
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _subtitleController.forward();
    });

    _navigate();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _subtitleController.dispose();
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo text with gradient shader + scale + fade
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: ShaderMask(
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
                ),
              ),
              const SizedBox(height: PortfiqSpacing.space12),
              // Subtitle with delayed fade
              FadeTransition(
                opacity: _subtitleFade,
                child: Text(
                  '내 ETF 맞춤 브리핑',
                  style: PortfiqTypography.body.copyWith(
                    fontSize: 14,
                    color: PortfiqTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
