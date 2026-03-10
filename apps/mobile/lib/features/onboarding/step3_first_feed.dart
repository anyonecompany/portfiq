import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import 'onboarding_provider.dart';

/// Mock news item for the first feed experience.
class _MockNewsItem {
  const _MockNewsItem({
    required this.title,
    required this.summary,
    required this.impact,
    required this.relatedTickers,
    required this.timeAgo,
  });

  final String title;
  final String summary;
  final String impact; // 'high', 'medium', 'low'
  final List<String> relatedTickers;
  final String timeAgo;
}

/// Step 3: Aha Moment — First Feed with mock news cards.
class Step3FirstFeed extends ConsumerStatefulWidget {
  const Step3FirstFeed({super.key, required this.onShowPushSheet});

  final VoidCallback onShowPushSheet;

  @override
  ConsumerState<Step3FirstFeed> createState() => _Step3FirstFeedState();
}

class _Step3FirstFeedState extends ConsumerState<Step3FirstFeed>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _sheetShown = false;
  late List<AnimationController> _cardControllers;
  late List<Animation<double>> _cardAnimations;

  static const _mockData = [
    _MockNewsItem(
      title: 'Fed 금리 동결 시사 — 기술주 랠리 지속 전망',
      summary: '연준 의장이 당분간 금리를 동결할 수 있음을 시사했습니다. '
          'NASDAQ 선물은 장 후 1.2% 상승했습니다.',
      impact: 'high',
      relatedTickers: ['QQQ', 'TQQQ', 'VOO'],
      timeAgo: '2시간 전',
    ),
    _MockNewsItem(
      title: 'TSMC 실적 서프라이즈 — 반도체 섹터 급등',
      summary: 'TSMC가 시장 예상을 15% 상회하는 실적을 발표했습니다. '
          'AI 수요가 핵심 성장 동력으로 확인되었습니다.',
      impact: 'high',
      relatedTickers: ['SOXL', 'QQQ'],
      timeAgo: '3시간 전',
    ),
    _MockNewsItem(
      title: 'S&P 500 사상 최고치 경신',
      summary: 'S&P 500 지수가 사상 최고치를 경신하며 마감했습니다. '
          '기술/헬스케어 섹터가 강세를 이끌었습니다.',
      impact: 'medium',
      relatedTickers: ['VOO', 'SPY'],
      timeAgo: '5시간 전',
    ),
    _MockNewsItem(
      title: '배당 ETF 자금 유입 지속',
      summary: '고배당 ETF로의 자금 유입이 3주 연속 이어지고 있습니다. '
          '금리 인하 기대감이 반영된 것으로 분석됩니다.',
      impact: 'low',
      relatedTickers: ['SCHD', 'JEPI'],
      timeAgo: '6시간 전',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Staggered entrance animation (0.2s interval)
    _cardControllers = List.generate(
      _mockData.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _cardAnimations = _cardControllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    }).toList();

    _startStaggeredAnimation();
  }

  Future<void> _startStaggeredAnimation() async {
    for (var i = 0; i < _cardControllers.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _cardControllers[i].forward();
      }
    }
  }

  void _onScroll() {
    // Show push permission sheet after scrolling past 1-2 cards
    if (!_sheetShown && _scrollController.offset > 120) {
      _sheetShown = true;
      // Slight delay so the scroll feels natural
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          widget.onShowPushSheet();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedEtfs = ref.watch(onboardingProvider).selectedEtfs;

    // Filter mock data to show items related to user's selected ETFs (at least
    // one ticker overlap). If nothing matches, show all.
    final relevant = _mockData.where((item) {
      return item.relatedTickers.any((t) => selectedEtfs.contains(t));
    }).toList();
    final items = relevant.isNotEmpty ? relevant : _mockData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '오늘의 ETF 브리핑',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '내 ETF에 영향을 주는 뉴스만 모았어요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PortfiqTheme.textSecondary,
                ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final animIndex =
                  index < _cardAnimations.length ? index : _cardAnimations.length - 1;
              return FadeTransition(
                opacity: _cardAnimations[animIndex],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(_cardAnimations[animIndex]),
                  child: _NewsCard(
                    item: item,
                    selectedEtfs: selectedEtfs,
                  ),
                ),
              );
            },
          ),
        ),
        // CTA button to proceed
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onShowPushSheet,
              child: const Text('시작하기'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single news card for the first feed.
class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.selectedEtfs});

  final _MockNewsItem item;
  final List<String> selectedEtfs;

  Color _impactColor() {
    switch (item.impact) {
      case 'high':
        return PortfiqTheme.impactHigh;
      case 'medium':
        return PortfiqTheme.impactMedium;
      default:
        return PortfiqTheme.impactLow;
    }
  }

  String _impactLabel() {
    switch (item.impact) {
      case 'high':
        return '높음';
      case 'medium':
        return '보통';
      default:
        return '낮음';
    }
  }

  @override
  Widget build(BuildContext context) {
    final impactColor = _impactColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PortfiqTheme.secondaryBg,
        borderRadius: BorderRadius.circular(PortfiqTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Impact badge + time
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: impactColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '영향도 ${_impactLabel()}',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: impactColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                item.timeAgo,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),

          // Summary
          Text(
            item.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PortfiqTheme.textSecondary,
                ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Ticker badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: item.relatedTickers.map((ticker) {
              final isUserEtf = selectedEtfs.contains(ticker);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUserEtf
                      ? PortfiqTheme.accent.withAlpha(26)
                      : PortfiqTheme.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: isUserEtf
                      ? Border.all(
                          color: PortfiqTheme.accent.withAlpha(77),
                          width: 1,
                        )
                      : null,
                ),
                child: Text(
                  ticker,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isUserEtf
                        ? PortfiqTheme.accent
                        : PortfiqTheme.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
