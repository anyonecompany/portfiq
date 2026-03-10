import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../features/feed/feed_models.dart';

/// Pill-shaped badge showing impact level (High / Medium / Low).
///
/// Per MASTER.md:
/// - High: gradient red bg
/// - Medium: gradient amber bg
/// - Low: subtle gray bg
/// - 11px label font weight 600
class ImpactBadge extends StatelessWidget {
  final ImpactLevel level;

  const ImpactBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (gradient, bgColor, textColor, label) = switch (level) {
      ImpactLevel.high => (
        PortfiqGradients.highImpact,
        null as Color?,
        PortfiqTheme.textPrimary,
        'High',
      ),
      ImpactLevel.medium => (
        PortfiqGradients.mediumImpact,
        null as Color?,
        PortfiqTheme.textPrimary,
        'Medium',
      ),
      ImpactLevel.low => (
        null as Gradient?,
        PortfiqTheme.divider,
        PortfiqTheme.textSecondary,
        'Low',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PortfiqSpacing.space8,
        vertical: PortfiqSpacing.space4,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? bgColor : null,
        borderRadius: BorderRadius.circular(PortfiqTheme.radiusPill),
      ),
      child: Text(
        label,
        style: PortfiqTypography.label.copyWith(
          color: textColor,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
