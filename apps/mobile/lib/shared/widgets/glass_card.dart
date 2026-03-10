import 'dart:ui';

import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Reusable glassmorphism card based on MASTER.md spec.
///
/// Uses a translucent background with optional backdrop blur and
/// a subtle border for the frosted glass effect.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Gradient? borderGradient;
  final bool enableBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = PortfiqTheme.radiusCard,
    this.borderColor,
    this.borderGradient,
    this.enableBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(PortfiqSpacing.space16),
      child: child,
    );

    // If a gradient border is requested, wrap with gradient container
    if (borderGradient != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: borderGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5), // gradient border width
          child: _buildInnerCard(content, borderRadius - 1.5),
        ),
      );
    }

    return _buildCard(content);
  }

  Widget _buildCard(Widget content) {
    final decoration = BoxDecoration(
      color: PortfiqTheme.surfaceCard.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? PortfiqTheme.divider.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: const [PortfiqShadows.glassCard],
    );

    if (enableBlur) {
      return Container(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: content,
          ),
        ),
      );
    }

    return Container(
      decoration: decoration,
      child: content,
    );
  }

  /// Inner card used when borderGradient is set (the gradient acts as border).
  Widget _buildInnerCard(Widget content, double innerRadius) {
    final decoration = BoxDecoration(
      color: PortfiqTheme.surfaceCard.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(innerRadius),
    );

    if (enableBlur) {
      return Container(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: content,
          ),
        ),
      );
    }

    return Container(
      decoration: decoration,
      child: content,
    );
  }
}
