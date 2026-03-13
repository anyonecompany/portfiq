import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Wrapper that applies staggered slide+fade animation on first build.
///
/// Per MASTER.md:
/// - Duration: 300ms + 80ms * index
/// - Curve: easeOutBack (spring)
/// - Slide from right (20px) + fade in
class AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 80 * widget.index);
    _controller = AnimationController(
      vsync: this,
      duration: PortfiqAnimations.slow, // 300ms
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0), // ~20px from right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: PortfiqAnimations.springCurve,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: PortfiqAnimations.defaultCurve,
      ),
    );

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}
