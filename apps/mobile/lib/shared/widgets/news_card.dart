import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/extensions.dart';
import '../../features/feed/feed_models.dart';
import 'glass_card.dart';
import 'pressable_card.dart';

/// Card component for a single news item in the feed.
///
/// Shows sentiment badge (호재/중립/위험) + ETF ticker chips + headline + summary.
class NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback? onTap;
  final VoidCallback? onSourceTap;

  const NewsCard({
    super.key,
    required this.item,
    this.onTap,
    this.onSourceTap,
  });

  @override
  Widget build(BuildContext context) {
    final sentiment = item.sentiment;
    final accentColor = _sentimentColor(sentiment);

    return PressableCard(
      onTap: onTap,
      child: Stack(
        children: [
          GlassCard(
            enableBlur: true,
            padding: const EdgeInsets.fromLTRB(
              PortfiqSpacing.space16,
              PortfiqSpacing.space16,
              PortfiqSpacing.space16,
              PortfiqSpacing.space16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Sentiment badge + ETF tickers + time
                Row(
                  children: [
                    // Sentiment pill
                    _SentimentPill(sentiment: sentiment),
                    const SizedBox(width: 8),
                    // ETF ticker chips (max 3)
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: item.impacts.take(3).map((impact) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: PortfiqTheme.divider.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              impact.etfTicker,
                              style: PortfiqTypography.label.copyWith(
                                color: PortfiqTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Text(
                      item.publishedAt.toRelativeTime(),
                      style: PortfiqTypography.caption.copyWith(
                        color: PortfiqTheme.textTertiary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: PortfiqSpacing.space12),

                // Row 2: Headline
                Text(
                  item.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PortfiqTypography.subtitle.copyWith(
                    color: PortfiqTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: PortfiqSpacing.space8),

                // Row 3: Impact reason
                Text(
                  item.impactReason,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: PortfiqTypography.body.copyWith(
                    color: PortfiqTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: PortfiqSpacing.space12),

                // Separator
                Container(
                  height: 1,
                  color: PortfiqTheme.divider.withValues(alpha: 0.5),
                ),

                const SizedBox(height: PortfiqSpacing.space12),

                // Row 4: Source + 원문 보기
                Row(
                  children: [
                    Text(
                      item.source,
                      style: PortfiqTypography.caption.copyWith(
                        color: PortfiqTheme.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onSourceTap,
                      child: Text(
                        '원문 보기',
                        style: PortfiqTypography.caption.copyWith(
                          color: PortfiqTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Left accent bar based on sentiment
          if (sentiment != NewsSentiment.neutral)
            Positioned(
              left: 0,
              top: PortfiqSpacing.space12,
              bottom: PortfiqSpacing.space12,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1.5),
                  color: accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _sentimentColor(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
        return PortfiqTheme.positive;
      case NewsSentiment.negative:
        return PortfiqTheme.negative;
      case NewsSentiment.neutral:
        return const Color(0xFF9CA3AF);
    }
  }
}

/// Compact sentiment pill for news cards — 호재 / 중립 / 위험
class _SentimentPill extends StatelessWidget {
  final NewsSentiment sentiment;
  const _SentimentPill({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (sentiment) {
      NewsSentiment.positive => ('호재', PortfiqTheme.positive, Icons.trending_up_rounded),
      NewsSentiment.negative => ('위험', PortfiqTheme.negative, Icons.trending_down_rounded),
      NewsSentiment.neutral => ('중립', const Color(0xFF9CA3AF), Icons.trending_flat_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: PortfiqTypography.label.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
