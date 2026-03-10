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
import 'share_channel_sheet.dart';

/// Compact briefing banner card shown at the top of the feed.
///
/// Morning variant shows ETF gain/loss chips + summary.
/// Night variant shows checkpoint items.
/// Uses GlassCard with gradient border per MASTER.md spec.
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

    // Show channel selection bottom sheet
    final channel = await ShareChannelSheet.show(context);
    if (channel == null || !mounted) return;

    setState(() => _isSharing = true);

    EventTracker.instance.track('share_channel_selected', properties: {
      'channel': channel.name,
      'content_type': 'briefing',
    });

    await Future.delayed(const Duration(milliseconds: 100));

    final success = await ShareService.captureAndShare(
      _shareCardKey,
      widget.data.title,
    );

    if (mounted) {
      setState(() => _isSharing = false);

      if (success) {
        EventTracker.instance.track('share_card_shared', properties: {
          'content_type': 'briefing',
          'channel': channel.name,
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PressableCard(
          onTap: widget.onTap,
          child: GlassCard(
            enableBlur: true,
            borderGradient: borderGradient,
            padding: const EdgeInsets.all(PortfiqSpacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header + AI label + share button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        style: PortfiqTypography.subtitle.copyWith(
                          color: PortfiqTheme.textPrimary,
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
                const SizedBox(height: PortfiqSpacing.space12),

                if (isMorning) ...[
                  // ETF change chips
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
                  const SizedBox(height: PortfiqSpacing.space12),
                  // Summary
                  Text(
                    data.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PortfiqTypography.body.copyWith(
                      color: PortfiqTheme.textSecondary,
                      fontSize: 14,
                    ),
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
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 13,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              cp,
                              style: PortfiqTypography.body.copyWith(
                                fontSize: 14,
                                color: const Color(0xFFD1D5DB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: PortfiqSpacing.space8),
                // "자세히 보기" link
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

        // Offscreen share card for capture
        Positioned(
          left: -2000,
          top: 0,
          child: ShareCard(data: data, repaintKey: _shareCardKey),
        ),
      ],
    );
  }
}
