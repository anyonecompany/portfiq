import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/etf_chip.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/share_channel_sheet.dart';
import '../feed/feed_models.dart';
import 'share_service.dart';
import 'widgets/share_card.dart';

/// Full-screen briefing detail view.
///
/// Morning: ETF-by-ETF gain/loss with cause + key overnight events.
/// Night: 3 checkpoint events with ETF impact mapping.
class BriefingDetailScreen extends StatefulWidget {
  final BriefingData data;

  const BriefingDetailScreen({super.key, required this.data});

  @override
  State<BriefingDetailScreen> createState() => _BriefingDetailScreenState();
}

class _BriefingDetailScreenState extends State<BriefingDetailScreen> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

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

    // Show channel selection bottom sheet
    final channel = await ShareChannelSheet.show(context);
    if (channel == null || !mounted) return;

    setState(() => _isSharing = true);

    EventTracker.instance.track('share_channel_selected', properties: {
      'channel': channel.name,
      'content_type': 'briefing',
    });

    // Wait for the share card to be laid out
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(PortfiqSpacing.space20),
            child: isMorning ? _buildMorningContent(data) : _buildNightContent(data),
          ),

          // Offscreen share card for capture
          Positioned(
            left: -2000,
            top: 0,
            child: ShareCard(data: data, repaintKey: _shareCardKey),
          ),
        ],
      ),
    );
  }

  Widget _buildMorningContent(BriefingData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        const Text(
          '오버나잇 요약',
          style: TextStyle(
            color: Color(0xFF6366F1),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.summary,
          style: const TextStyle(
            color: Color(0xFFD1D5DB),
            fontSize: 15,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF2D2F3A)),
        const SizedBox(height: 16),

        // ETF-by-ETF breakdown
        const Text(
          'ETF 변동',
          style: TextStyle(
            color: Color(0xFF6366F1),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        ...data.etfChanges.map((change) {
          return _EtfChangeRow(change: change);
        }),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF2D2F3A)),
        const SizedBox(height: 16),

        // Key overnight events
        const Text(
          '주요 이벤트',
          style: TextStyle(
            color: Color(0xFF6366F1),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _eventItem('NVIDIA 시간외 +8.2% — 데이터센터 매출 전년비 409% 증가'),
        _eventItem('FOMC 의사록 — 위원 다수 금리인하 신중론 유지'),
        _eventItem('미 10년물 국채금리 4.31%로 소폭 상승'),
      ],
    );
  }

  Widget _buildNightContent(BriefingData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘 밤 주요 일정',
          style: TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        ...data.checkpoints.asMap().entries.map((entry) {
          return _CheckpointRow(index: entry.key + 1, text: entry.value);
        }),

        const SizedBox(height: 24),
        const Divider(color: Color(0xFF2D2F3A)),
        const SizedBox(height: 16),

        // ETF impact mapping
        const Text(
          '예상 ETF 영향',
          style: TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        _impactMapRow('FOMC 의사록', ['QQQ', 'VOO']),
        const SizedBox(height: 8),
        _impactMapRow('NVIDIA 실적', ['QQQ']),
        const SizedBox(height: 8),
        _impactMapRow('실업수당 청구', ['VOO', 'SCHD']),
      ],
    );
  }

  Widget _eventItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Color(0xFF6366F1), fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactMapRow(String event, List<String> tickers) {
    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              event,
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          ...tickers.map((t) {
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2F3A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  t,
                  style: PortfiqTypography.label.copyWith(
                    color: PortfiqTheme.textSecondary,
                    letterSpacing: 0,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EtfChangeRow extends StatelessWidget {
  final EtfChange change;
  const _EtfChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final causeText = switch (change.ticker) {
      'QQQ' => 'NVIDIA 실적 호조 + 빅테크 전반 상승',
      'VOO' => 'S&P 500 소폭 상승, FOMC 영향 제한적',
      'SCHD' => '배당주 약세 — 채권금리 상승 영향',
      _ => '시장 전반 흐름에 연동',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: PortfiqSpacing.space16),
      child: GlassCard(
        padding: const EdgeInsets.all(PortfiqSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EtfChip(ticker: change.ticker, changePercent: change.changePercent),
            const SizedBox(height: PortfiqSpacing.space8),
            Text(
              causeText,
              style: PortfiqTypography.body.copyWith(
                color: PortfiqTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  final int index;
  final String text;
  const _CheckpointRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PortfiqSpacing.space12),
      child: GlassCard(
        padding: const EdgeInsets.all(PortfiqSpacing.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
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
                  color: Color(0xFFD1D5DB),
                  fontSize: 14,
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
