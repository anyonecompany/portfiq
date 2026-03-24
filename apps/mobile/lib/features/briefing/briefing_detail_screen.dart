import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import '../feed/feed_models.dart';
import 'share_service.dart';
import 'widgets/share_card.dart';

// ─── Design spec colors ───────────────────────────────────────
const _kCardBg = Color(0xFF1E1E2E);
const _kTextMain = Color(0xFFFFFFFF);
const _kTextSub = Color(0xFF9E9EA7);
const _kDivider = Color(0xFF2A2A3C);
const _kBullish = Color(0xFF4CAF50);
const _kBearish = Color(0xFFF44336);
const _kNeutral = Color(0xFF9E9E9E);

/// Derive overall sentiment from ETF changes.
enum _BriefingSentiment { bullish, bearish, neutral }

_BriefingSentiment _deriveSentiment(List<EtfChange> changes) {
  if (changes.isEmpty) return _BriefingSentiment.neutral;
  final up = changes.where((c) => c.changePercent > 0).length;
  final down = changes.where((c) => c.changePercent < 0).length;
  if (up > down) return _BriefingSentiment.bullish;
  if (down > up) return _BriefingSentiment.bearish;
  return _BriefingSentiment.neutral;
}

/// Full-screen briefing detail view — Toss Securities AI article style.
///
/// Information hierarchy:
///   L1 — Headline + Sentiment badge (instant comprehension)
///   L2 — Key metrics cards (ETF changes, color-coded)
///   L3 — Detail analysis (collapsed by default)
class BriefingDetailScreen extends StatefulWidget {
  final BriefingData data;

  const BriefingDetailScreen({super.key, required this.data});

  @override
  State<BriefingDetailScreen> createState() => _BriefingDetailScreenState();
}

class _BriefingDetailScreenState extends State<BriefingDetailScreen> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;
  bool _detailExpanded = false;

  @override
  void initState() {
    super.initState();
    EventTracker.instance.track('screen_viewed', properties: {'screen_name': 'briefing_detail'});
    EventTracker.instance.track('briefing_viewed', properties: {
      'type': widget.data.type.name,
    });
  }

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

    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: PortfiqTheme.primaryBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: PortfiqTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          data.title,
          style: PortfiqTypography.subtitle.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          _isSharing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PortfiqTheme.accent,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(LucideIcons.share2, size: 20, color: PortfiqTheme.textPrimary),
                  onPressed: _handleShare,
                ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mock banner
                  if (data.isMock) _buildMockBanner(),

                  // L1 — Headline + Sentiment
                  _BriefingHeadline(data: data),

                  const SizedBox(height: 20),

                  // L2 — Key Metrics
                  if (data.etfChanges.isNotEmpty) ...[
                    _buildSectionLabel('ETF 변동'),
                    const SizedBox(height: 12),
                    _KeyMetricsCard(changes: data.etfChanges),
                    const SizedBox(height: 20),
                  ],

                  // Checkpoints (morning: events, night: schedule)
                  if (data.checkpoints.isNotEmpty) ...[
                    _buildSectionLabel(
                      data.type == BriefingType.morning ? '주요 이벤트' : '오늘 밤 주요 일정',
                    ),
                    const SizedBox(height: 12),
                    ...data.checkpoints.asMap().entries.map((entry) {
                      return _CheckpointRow(index: entry.key + 1, text: entry.value);
                    }),
                  ],

                  const SizedBox(height: 8),
                  const Divider(color: _kDivider),
                  const SizedBox(height: 8),

                  // L3 — Detail Analysis (collapsible)
                  _DetailAnalysis(
                    summary: data.summary,
                    expanded: _detailExpanded,
                    onToggle: () => setState(() => _detailExpanded = !_detailExpanded),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            if (_isSharing)
              Positioned(
                left: -2000,
                top: 0,
                child: ShareCard(data: data, repaintKey: _shareCardKey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withAlpha(26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF59E0B).withAlpha(77)),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)),
            SizedBox(width: 6),
            Text(
              'AI 분석 준비 중 — 샘플 데이터입니다',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final isMorning = widget.data.type == BriefingType.morning;
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isMorning ? PortfiqTheme.accent : PortfiqTheme.warning,
      ),
    );
  }
}

// ─── L1: Headline + Sentiment Badge ────────────────────────────

class _BriefingHeadline extends StatelessWidget {
  final BriefingData data;
  const _BriefingHeadline({required this.data});

  @override
  Widget build(BuildContext context) {
    final sentiment = _deriveSentiment(data.etfChanges);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sentiment badge
        _SentimentBadge(sentiment: sentiment),
        const SizedBox(height: 12),

        // Main headline — summary is the most valuable text
        Text(
          data.summary.isNotEmpty ? data.summary : data.title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _kTextMain,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Sentiment Badge ──────────────────────────────────────────

class _SentimentBadge extends StatelessWidget {
  final _BriefingSentiment sentiment;
  const _SentimentBadge({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (sentiment) {
      _BriefingSentiment.bullish => ('Bullish', _kBullish, Icons.trending_up_rounded),
      _BriefingSentiment.bearish => ('Bearish', _kBearish, Icons.trending_down_rounded),
      _BriefingSentiment.neutral => ('Neutral', _kNeutral, Icons.trending_flat_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── L2: Key Metrics Card ─────────────────────────────────────

class _KeyMetricsCard extends StatelessWidget {
  final List<EtfChange> changes;
  const _KeyMetricsCard({required this.changes});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < changes.length; i++) ...[
            _EtfMetricRow(change: changes[i]),
            if (i < changes.length - 1)
              const Divider(color: _kDivider, height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _EtfMetricRow extends StatelessWidget {
  final EtfChange change;
  const _EtfMetricRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final isUp = change.changePercent > 0;
    final isDown = change.changePercent < 0;
    final changeColor = isUp ? _kBullish : (isDown ? _kBearish : _kNeutral);
    final sign = isUp ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Ticker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: changeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              change.ticker,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kTextMain,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Cause text
          Expanded(
            child: Text(
              change.cause.isNotEmpty ? change.cause : '시장 전반 흐름에 연동',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: _kTextSub,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Change percent
          Text(
            '$sign${change.changePercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: changeColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── L3: Detail Analysis (Collapsible) ────────────────────────

class _DetailAnalysis extends StatelessWidget {
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;

  const _DetailAnalysis({
    required this.summary,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle header
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(LucideIcons.fileText, size: 16, color: PortfiqTheme.accent),
                const SizedBox(width: 8),
                const Text(
                  '상세 분석 보기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PortfiqTheme.accent,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: PortfiqTheme.accent,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Collapsible content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                summary,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _kTextMain,
                  height: 1.6,
                ),
              ),
            ),
          ),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

// ─── Checkpoint Row ───────────────────────────────────────────

class _CheckpointRow extends StatelessWidget {
  final int index;
  final String text;
  const _CheckpointRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: PortfiqTheme.accent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: _kTextMain,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  color: Color(0xFFD1D5DB),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
