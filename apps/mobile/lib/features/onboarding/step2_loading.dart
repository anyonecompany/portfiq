import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Step 2: Analysis Loading — progress indicator + auto-navigate after 1.5s.
class Step2Loading extends StatefulWidget {
  const Step2Loading({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<Step2Loading> createState() => _Step2LoadingState();
}

class _Step2LoadingState extends State<Step2Loading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Auto-navigate after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        widget.onNext();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(PortfiqTheme.accent),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '내 ETF 기준으로\n뉴스를 분석하는 중...',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: PortfiqTheme.textPrimary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                '잠시만 기다려 주세요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PortfiqTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
