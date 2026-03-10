import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Card wrapper with press-down animation feedback.
///
/// Applies scale and opacity animation on tap, per MASTER.md spec:
/// - Press: scale 0.98, opacity 0.85, 100ms
/// - Release: scale 1.0, opacity 1.0, 150ms
/// - Curve: easeOutCubic
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final double pressOpacity;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.pressScale = 0.98,
    this.pressOpacity = 0.85,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PortfiqAnimations.fast, // 100ms press
      reverseDuration: PortfiqAnimations.cardRelease, // 150ms release
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final curvedValue = PortfiqAnimations.defaultCurve
              .transform(_controller.value);
          return Transform.scale(
            scale: 1.0 - (curvedValue * (1.0 - widget.pressScale)),
            child: Opacity(
              opacity: 1.0 - (curvedValue * (1.0 - widget.pressOpacity)),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
