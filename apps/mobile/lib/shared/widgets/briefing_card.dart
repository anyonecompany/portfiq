import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../features/briefing/share_service.dart';
import '../../features/briefing/widgets/share_card.dart';
import '../../features/feed/feed_models.dart';
import '../../shared/tracking/event_tracker.dart';
import 'etf_chip.dart';
import 'glass_card.dart';
import 'pressable_card.dart';

// Design spec colors
const _kBullish = Color(0xFF4CAF50);
const _kBearish = Color(0xFFF44336);
const _kNeutral = Color(0xFF9E9E9E);

enum _CardSentiment { bullish, bearish, neutral }

_CardSentiment _derive(List<EtfChange> changes) {
  if (changes.isEmpty) return _CardSentiment.neutral;
  final up = changes.where((c) => c.changePercent > 0).length;
  final down = changes.where((c) => c.changePercent < 0).length;
  if (up > down) return _CardSentiment.bullish;
  if (down > up) return _CardSentiment.bearish;
  return _CardSentiment.neutral;
}

/// Compact briefing banner card shown at the top of the feed.
///
/// Toss Securities AI article style:
/// - Sentiment badge + headline preview for instant comprehension
/// - Color-coded ETF changes
/// - "자세히 보기 →" CTA
class BriefingCard extends StatefulWidget {
  final BriefingData data;
  final VoidCallback? onTap;

  const BriefingCard({super.key, required this.data, this.onTap});

  @override
  State<BriefingCard> createState() => _BriefingCardState();
}

class _BriefingCardState extends State<BriefingCard> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _handleShare() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    EventTracker.instance.track('share_initiated', properties: {
      'content_type': 'briefing',
    });

    await Future.delayed(const Duration(milliseconds: 100));
    await WidgetsBinding.instance.endOfFrame;

    final success = await ShareService.captureAndShare(
      _shareCardKey,
      widget.data.title,
    );

    if (mounted) {
      setState(() => _isSharing = false);

      if (success) {
        EventTracker.instance.track('share_card_shared', properties: {
          'content_type': 'briefing',
          'channel': 'system',
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isMorning = data.type == BriefingType.morning;
    final borderGradient =
        isMorning ? PortfiqGradients.morning : PortfiqGradients.night;
    final accentColor =
        isMorning ? PortfiqTheme.accent : PortfiqTheme.warning;
    final sentiment = _derive(data.etfChanges);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PressableCard(
          onTap: widget.onTap,
          child: GlassCard(
            enableBlur: true,
            depth: 3,
            borderGradient: borderGradient,
            padding: const EdgeInsets.all(PortfiqSpacing.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: title + AI label + share
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        style: PortfiqTypography.title.copyWith(
                          color: PortfiqTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: PortfiqSpacing.space8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AI 분석',
                          style: PortfiqTypography.caption.copyWith(
                            color: PortfiqTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: PortfiqSpacing.space8),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: _isSharing
                              ? const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: PortfiqTheme.textSecondary,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    LucideIcons.share2,
                                    size: 16,
                                    color: PortfiqTheme.textSecondary,
                                  ),
                                  onPressed: _handleShare,
                                  tooltip: '공유',
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Mock banner
                if (data.isMock) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: PortfiqTheme.warning.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PortfiqTheme.warning.withAlpha(77)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: PortfiqTheme.warning),
                        const SizedBox(width: 6),
                        Text(
                          'AI 분석 준비 중 — 샘플 데이터입니다',
                          style: PortfiqTypography.caption.copyWith(
                            color: PortfiqTheme.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Sentiment badge
                _CardSentimentBadge(sentiment: sentiment),
                const SizedBox(height: 10),

                // L1 Headline preview (summary, 2 lines)
                Text(
                  data.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF9FAFB),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                if (isMorning) ...[
                  // ETF change chips with color coding
                  Wrap(
                    spacing: PortfiqSpacing.space8,
                    runSpacing: PortfiqSpacing.space8,
                    children: data.etfChanges.map((change) {
                      return EtfChip(
                        ticker: change.ticker,
                        changePercent: change.changePercent,
                      );
                    }).toList(),
                  ),
                ] else ...[
                  // Night checkpoints
                  ...data.checkpoints.take(3).map((cp) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: PortfiqSpacing.space8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•  ',
                            style: TextStyle(color: accentColor, fontSize: 13),
                          ),
                          Expanded(
                            child: Text(
                              cp,
                              style: PortfiqTypography.body.copyWith(
                                fontSize: 14,
                                color: const Color(0xFFD1D5DB),
                                height: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: PortfiqSpacing.space8),
                // CTA
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '자세히 보기 →',
                    style: PortfiqTypography.caption.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_isSharing)
          Positioned(
            left: -2000,
            top: 0,
            child: ShareCard(data: data, repaintKey: _shareCardKey),
          ),
      ],
    );
  }
}

/// Compact sentiment badge for the briefing card preview.
class _CardSentimentBadge extends StatelessWidget {
  final _CardSentiment sentiment;
  const _CardSentimentBadge({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (sentiment) {
      _CardSentiment.bullish => ('Bullish', _kBullish, Icons.trending_up_rounded),
      _CardSentiment.bearish => ('Bearish', _kBearish, Icons.trending_down_rounded),
      _CardSentiment.neutral => ('Neutral', _kNeutral, Icons.trending_flat_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
