import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// A shimmer loading placeholder with animated gradient sweep.
///
/// Per MASTER.md:
/// - Base color: Color(0xFF16181F)
/// - Highlight: Color(0xFF1E2028)
/// - Linear gradient sweep, 1500ms, infinite
/// - Configurable width/height/borderRadius
class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PortfiqAnimations.shimmer,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: const [
                PortfiqTheme.secondaryBg, // #16181F
                PortfiqTheme.shimmerHighlight, // #252730 (brighter)
                PortfiqTheme.secondaryBg, // #16181F
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
