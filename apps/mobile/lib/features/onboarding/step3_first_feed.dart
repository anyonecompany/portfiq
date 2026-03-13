import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../shared/services/api_client.dart';
import '../feed/feed_models.dart';
import 'onboarding_provider.dart';

/// Step 3: Aha Moment — First Feed with real news from API.
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
  List<AnimationController> _cardControllers = [];
  List<Animation<double>> _cardAnimations = [];

  bool _isLoading = true;
  List<NewsItem> _newsItems = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final response = await ApiClient.instance.get(
        '/api/v1/feed/latest',
        queryParameters: {'offset': 0, 'limit': 4},
      );
      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;

      final newsItems = items.map((item) {
        final map = item as Map<String, dynamic>;
        final impacts = (map['impacts'] as List<dynamic>? ?? []).map((imp) {
          final impMap = imp as Map<String, dynamic>;
          return EtfImpact(
            etfTicker: impMap['etf_ticker'] as String? ?? '',
            level: _parseImpactLevel(impMap['level'] as String? ?? 'Low'),
          );
        }).toList();

        return NewsItem(
          id: map['id']?.toString() ?? '',
          headline: map['headline'] as String? ?? '',
          impactReason: map['impact_reason'] as String? ?? '',
          source: map['source'] as String? ?? '',
          sourceUrl: map['source_url'] as String? ?? '',
          publishedAt:
              DateTime.tryParse(map['published_at'] ?? '') ?? DateTime.now(),
          impacts: impacts,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _newsItems = newsItems;
        _isLoading = false;
      });
      _setupAnimations();
    } catch (e) {
      if (kDebugMode) print('[Step3FirstFeed] API 실패: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  ImpactLevel _parseImpactLevel(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return ImpactLevel.high;
      case 'medium':
        return ImpactLevel.medium;
      default:
        return ImpactLevel.low;
    }
  }

  void _setupAnimations() {
    for (final c in _cardControllers) {
      c.dispose();
    }
    _cardControllers = List.generate(
      _newsItems.length,
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
    if (!_sheetShown && _scrollController.offset > 120) {
      _sheetShown = true;
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

    // Filter to show items related to user's selected ETFs
    final relevant = _newsItems.where((item) {
      return item.impacts.any((imp) => selectedEtfs.contains(imp.etfTicker));
    }).toList();
    final items = relevant.isNotEmpty ? relevant : _newsItems;

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
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: PortfiqTheme.accent),
                      SizedBox(height: 16),
                      Text(
                        '뉴스를 불러오는 중...',
                        style: TextStyle(
                          color: PortfiqTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : items.isEmpty
                  ? const Center(
                      child: Text(
                        '뉴스를 불러오는 중...',
                        style: TextStyle(
                          color: PortfiqTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final animIndex = index < _cardAnimations.length
                            ? index
                            : _cardAnimations.length - 1;
                        if (animIndex < 0) return _NewsCard(item: item, selectedEtfs: selectedEtfs);
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

  final NewsItem item;
  final List<String> selectedEtfs;

  Color _impactColor() {
    switch (item.highestImpact) {
      case ImpactLevel.high:
        return PortfiqTheme.impactHigh;
      case ImpactLevel.medium:
        return PortfiqTheme.impactMedium;
      case ImpactLevel.low:
        return PortfiqTheme.impactLow;
    }
  }

  String _impactLabel() {
    switch (item.highestImpact) {
      case ImpactLevel.high:
        return '높음';
      case ImpactLevel.medium:
        return '보통';
      case ImpactLevel.low:
        return '낮음';
    }
  }

  String _timeAgo() {
    final diff = DateTime.now().difference(item.publishedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
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
                _timeAgo(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            item.headline,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),

          // Summary
          if (item.impactReason.isNotEmpty)
            Text(
              item.impactReason,
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
            children: item.impacts.map((impact) {
              final isUserEtf = selectedEtfs.contains(impact.etfTicker);
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
                  impact.etfTicker,
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
