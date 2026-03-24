import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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

  /// Background tint color per sentiment (5% opacity overlay).
  Color _sentimentTint(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
        return PortfiqTheme.positive.withValues(alpha: 0.05);
      case NewsSentiment.negative:
        return PortfiqTheme.negative.withValues(alpha: 0.05);
      case NewsSentiment.neutral:
        return Colors.transparent;
    }
  }

  /// Headline font weight: bold for positive/negative, medium for neutral.
  FontWeight _headlineWeight(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
      case NewsSentiment.negative:
        return FontWeight.w700;
      case NewsSentiment.neutral:
        return FontWeight.w500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentiment = item.sentiment;

    return PressableCard(
      onTap: onTap,
      child: Stack(
        children: [
          // Sentiment background tint overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _sentimentTint(sentiment),
                borderRadius: BorderRadius.circular(PortfiqTheme.radiusCard),
              ),
            ),
          ),
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
                // Mock data banner
                if (item.isMock) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: Color(0xFFF59E0B)),
                        SizedBox(width: 4),
                        Text(
                          '샘플 뉴스 — 실시간 데이터 준비 중',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PortfiqSpacing.space8),
                ],

                // Row 0: Sentiment icon indicator
                _SentimentIcon(sentiment: sentiment),
                const SizedBox(height: PortfiqSpacing.space8),

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

                // Row 2: Headline (bold for positive/negative, medium for neutral)
                Text(
                  item.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PortfiqTypography.subtitle.copyWith(
                    color: PortfiqTheme.textPrimary,
                    fontWeight: _headlineWeight(sentiment),
                  ),
                ),

                const SizedBox(height: PortfiqSpacing.space8),

                // Row 3: Summary (prefer 3-line summary over impact reason)
                Text(
                  item.summary3line.isNotEmpty
                      ? item.summary3line.replaceAll('\n', ' ')
                      : item.impactReason,
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

          // Left accent bar — sentiment color (green=positive, red=negative, gray=neutral)
          Positioned(
            left: 0,
            top: PortfiqSpacing.space12,
            bottom: PortfiqSpacing.space12,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1.5),
                gradient: _sentimentGradient(sentiment),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _sentimentGradient(NewsSentiment sentiment) {
    switch (sentiment) {
      case NewsSentiment.positive:
        return PortfiqGradients.positiveAccent;
      case NewsSentiment.negative:
        return PortfiqGradients.highImpact;
      case NewsSentiment.neutral:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
        );
    }
  }
}

/// Small sentiment icon shown at the top of the card.
class _SentimentIcon extends StatelessWidget {
  final NewsSentiment sentiment;
  const _SentimentIcon({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (sentiment) {
      NewsSentiment.positive => (LucideIcons.trendingUp, PortfiqTheme.positive),
      NewsSentiment.negative => (LucideIcons.trendingDown, PortfiqTheme.negative),
      NewsSentiment.neutral => (LucideIcons.minus, PortfiqTheme.textTertiary),
    };

    return Icon(icon, size: 14, color: color);
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
