import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'loading_shimmer.dart';

/// News card skeleton — title line + subtitle + 3 body lines.
///
/// Per MASTER.md: Matches actual news card layout for seamless transition.
class ShimmerNewsCard extends StatelessWidget {
  const ShimmerNewsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PortfiqSpacing.space16),
      decoration: BoxDecoration(
        color: PortfiqTheme.surfaceCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(PortfiqTheme.radiusCard),
        border: Border.all(
          color: PortfiqTheme.divider.withValues(alpha: 0.3),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title line (100% width)
          LoadingShimmer(width: double.infinity, height: 16, borderRadius: 4),
          SizedBox(height: 10),
          // Subtitle (80% width)
          LoadingShimmer(width: 250, height: 14, borderRadius: 4),
          SizedBox(height: 14),
          // Body lines
          LoadingShimmer(width: double.infinity, height: 12, borderRadius: 4),
          SizedBox(height: 8),
          LoadingShimmer(width: double.infinity, height: 12, borderRadius: 4),
          SizedBox(height: 8),
          LoadingShimmer(width: 200, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Briefing skeleton with gradient border placeholder.
///
/// Per MASTER.md: Gradient border + title + pill shapes + body lines.
class ShimmerBriefingCard extends StatelessWidget {
  const ShimmerBriefingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PortfiqTheme.radiusCard),
        gradient: PortfiqGradients.indigo,
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Container(
          padding: const EdgeInsets.all(PortfiqSpacing.space16),
          decoration: BoxDecoration(
            color: PortfiqTheme.surfaceCard.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14.5),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title (60% width)
              LoadingShimmer(width: 180, height: 18, borderRadius: 4),
              SizedBox(height: 14),
              // Pill chips
              Row(
                children: [
                  LoadingShimmer(width: 80, height: 28, borderRadius: 8),
                  SizedBox(width: 8),
                  LoadingShimmer(width: 80, height: 28, borderRadius: 8),
                ],
              ),
              SizedBox(height: 14),
              // Body lines
              LoadingShimmer(width: double.infinity, height: 12, borderRadius: 4),
              SizedBox(height: 8),
              LoadingShimmer(width: 240, height: 12, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// ETF list row skeleton — circle + 2 lines + right pill.
///
/// Per MASTER.md: Matches ETF row layout.
class ShimmerETFRow extends StatelessWidget {
  const ShimmerETFRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Circle avatar
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: PortfiqTheme.surfaceCard,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Two lines
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingShimmer(width: 100, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                LoadingShimmer(width: 60, height: 12, borderRadius: 4),
              ],
            ),
          ),
          // Right pill
          const LoadingShimmer(width: 64, height: 28, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Chart area placeholder.
///
/// Per MASTER.md: Full-width rectangle with subtle gradient.
class ShimmerChart extends StatelessWidget {
  const ShimmerChart({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoadingShimmer(
      width: double.infinity,
      height: 200,
      borderRadius: 12,
    );
  }
}
