import 'dart:ui';

import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Reusable glassmorphism card based on MASTER.md spec.
///
/// Uses a translucent background with optional backdrop blur and
/// a subtle border for the frosted glass effect.
///
/// The [depth] parameter controls the elevation level (1-4) per
/// MASTER.md Depth/Elevation system. Level 2 is the default for cards.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Gradient? borderGradient;
  final bool enableBlur;

  /// Depth level (1-4). When set, overrides blur/opacity/border values
  /// using PortfiqDepth constants. Default is 2 (standard card).
  final int depth;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = PortfiqTheme.radiusCard,
    this.borderColor,
    this.borderGradient,
    this.enableBlur = false,
    this.depth = 2,
  });

  double get _blur => switch (depth) {
        1 => PortfiqDepth.blurLevel1,
        3 => PortfiqDepth.blurLevel3,
        4 => PortfiqDepth.blurLevel4,
        _ => PortfiqDepth.blurLevel2,
      };

  double get _surfaceOpacity => switch (depth) {
        1 => PortfiqDepth.opacityLevel1,
        3 => PortfiqDepth.opacityLevel3,
        4 => PortfiqDepth.opacityLevel4,
        _ => PortfiqDepth.opacityLevel2,
      };

  double get _borderOpacity => switch (depth) {
        1 => PortfiqDepth.borderOpacityLevel1,
        3 => PortfiqDepth.borderOpacityLevel3,
        4 => 0.20, // accent-colored border for Level 4
        _ => PortfiqDepth.borderOpacityLevel2,
      };

  BoxShadow get _shadow => switch (depth) {
        1 => PortfiqShadows.sm,
        3 => PortfiqShadows.lg,
        4 => PortfiqShadows.glow,
        _ => PortfiqShadows.glassCard,
      };

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
    final effectiveBorderColor = depth == 4
        ? PortfiqTheme.accent.withValues(alpha: _borderOpacity)
        : (borderColor ?? PortfiqTheme.divider.withValues(alpha: _borderOpacity));

    final decoration = BoxDecoration(
      color: PortfiqTheme.surfaceCard.withValues(alpha: _surfaceOpacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: effectiveBorderColor,
        width: 1,
      ),
      boxShadow: [
        _shadow,
        // Inner subtle shadow for glass depth
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 6,
          offset: const Offset(0, 1),
          blurStyle: BlurStyle.inner,
        ),
      ],
    );

    // Wrap with subtle gradient border overlay
    Widget card;

    if (enableBlur) {
      card = Container(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
            child: content,
          ),
        ),
      );
    } else {
      card = Container(
        decoration: decoration,
        child: content,
      );
    }

    // Subtle gradient border: white 10% at top-left → transparent
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x1AFFFFFF), // white 10%
            Color(0x00FFFFFF), // transparent
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1), // 1px gradient border width
        child: card,
      ),
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
