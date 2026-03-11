import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/briefing_card.dart';
import '../../shared/widgets/news_card.dart';
import '../briefing/briefing_detail_screen.dart';
import 'feed_models.dart';
import 'feed_provider.dart';

/// Main feed screen — briefing banner + news card list.
///
/// Per MASTER.md:
/// - Staggered list item animation (SlideTransition + FadeTransition, 50ms delay per item)
/// - Pull-to-refresh indicator with Indigo color
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _staggerController;
  int _maxScrolledIndex = 0;

  @override
  void initState() {
    super.initState();
    EventTracker.instance.track('screen_viewed', properties: {'screen_name': 'feed'});
  }

  void _initStaggerAnimation(int itemCount) {
    _staggerController?.dispose();
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (itemCount * 50)),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    // Initialize stagger animation when data loads
    if (!feedState.isLoading && _staggerController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initStaggerAnimation(feedState.newsItems.length + 1);
        }
      });
    }

    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: PortfiqTheme.primaryBg,
        elevation: 0,
        title: Text(
          'Portfiq',
          style: PortfiqTypography.title.copyWith(
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: feedState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: PortfiqTheme.accent),
            )
          : RefreshIndicator(
              color: PortfiqTheme.accent,
              backgroundColor: PortfiqTheme.secondaryBg,
              onRefresh: () {
                EventTracker.instance.track('feed_pull_refresh', properties: {});
                EventTracker.instance.track('feed_refreshed', properties: {
                  'source': 'pull_to_refresh',
                });
                _staggerController?.dispose();
                _staggerController = null;
                return ref.read(feedProvider.notifier).refreshFeed().then((_) {
                  if (mounted) {
                    _initStaggerAnimation(
                      ref.read(feedProvider).newsItems.length + 1,
                    );
                  }
                });
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  PortfiqSpacing.space16,
                  PortfiqSpacing.space8,
                  PortfiqSpacing.space16,
                  PortfiqSpacing.space24,
                ),
                itemCount: feedState.newsItems.length + 1, // +1 for briefing
                itemBuilder: (context, index) {
                  // First item: Briefing card
                  if (index == 0) {
                    final briefing = feedState.briefing;
                    if (briefing == null) return const SizedBox.shrink();
                    return _buildStaggeredItem(
                      index: 0,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: PortfiqSpacing.space16,
                        ),
                        child: BriefingCard(
                          data: briefing,
                          onTap: () => _openBriefingDetail(context, briefing),
                        ),
                      ),
                    );
                  }

                  // News cards
                  final item = feedState.newsItems[index - 1];

                  // Track viewport entry for news cards
                  if (index > _maxScrolledIndex) {
                    _maxScrolledIndex = index;
                    EventTracker.instance.track('news_card_viewed', properties: {
                      'news_id': item.id,
                      'position': index - 1,
                    });
                    EventTracker.instance.track('feed_scrolled_depth', properties: {
                      'max_index': index - 1,
                      'total_items': feedState.newsItems.length,
                    });
                  }

                  return _buildStaggeredItem(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: PortfiqSpacing.space12,
                      ),
                      child: NewsCard(
                        item: item,
                        onTap: () => _showNewsDetail(context, item),
                        onSourceTap: () {
                          EventTracker.instance.track('news_source_tap', properties: {
                            'news_id': item.id,
                            'source': item.source,
                          });
                          _openUrl(item.sourceUrl);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  /// Wraps a list item with staggered slide + fade animation.
  Widget _buildStaggeredItem({required int index, required Widget child}) {
    final controller = _staggerController;
    if (controller == null) return child;

    final startInterval = (index * 0.05).clamp(0.0, 0.7);
    final endInterval = (startInterval + 0.3).clamp(0.0, 1.0);

    final curvedAnimation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        startInterval,
        endInterval,
        curve: PortfiqAnimations.defaultCurve,
      ),
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.05, 0), // ~20px from right
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curvedAnimation),
        child: child,
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openBriefingDetail(BuildContext context, BriefingData briefing) {
    EventTracker.instance.track('briefing_card_tap', properties: {
      'type': briefing.type.name,
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BriefingDetailScreen(data: briefing),
      ),
    );
  }

  void _showNewsDetail(BuildContext context, NewsItem item) {
    EventTracker.instance.track('news_card_tap', properties: {
      'news_id': item.id,
      'sentiment': item.sentiment.name,
    });
    showModalBottomSheet(
      context: context,
      backgroundColor: PortfiqTheme.secondaryBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PortfiqTheme.radiusCard),
        ),
      ),
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PortfiqSpacing.space20,
              PortfiqSpacing.space12,
              PortfiqSpacing.space20,
              PortfiqSpacing.space24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PortfiqTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: PortfiqSpacing.space16),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sentiment badge
                        _SentimentBadge(sentiment: item.sentiment),
                        const SizedBox(height: PortfiqSpacing.space12),

                        // Headline
                        Text(
                          item.headline,
                          style: PortfiqTypography.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: PortfiqSpacing.space16),

                        // 3-line summary card
                        if (item.summary3line.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(PortfiqSpacing.space16),
                            decoration: BoxDecoration(
                              color: PortfiqTheme.primaryBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _sentimentColor(item.sentiment).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: PortfiqTheme.accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI 3줄 요약',
                                      style: PortfiqTypography.caption.copyWith(
                                        color: PortfiqTheme.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: PortfiqSpacing.space12),
                                ...item.summary3line.split('\n').map(
                                  (line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      line,
                                      style: PortfiqTypography.body.copyWith(
                                        color: PortfiqTheme.textPrimary,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            item.impactReason,
                            style: PortfiqTypography.body.copyWith(
                              color: PortfiqTheme.textSecondary,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),

                        const SizedBox(height: PortfiqSpacing.space16),

                        // Impact badges
                        if (item.impacts.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: item.impacts.map((impact) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _impactColor(impact.level).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  impact.etfTicker,
                                  style: PortfiqTypography.caption.copyWith(
                                    color: _impactColor(impact.level),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        if (item.impacts.isNotEmpty)
                          const SizedBox(height: PortfiqSpacing.space16),

                        // Source + 전문 보러가기
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: PortfiqTheme.divider, width: 1),
                            ),
                          ),
                          padding: const EdgeInsets.only(top: PortfiqSpacing.space12),
                          child: Row(
                            children: [
                              Text(
                                item.source,
                                style: PortfiqTypography.caption.copyWith(
                                  color: PortfiqTheme.textTertiary,
                                ),
                              ),
                              const Spacer(),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    EventTracker.instance.track('news_source_tap', properties: {
                                      'news_id': item.id,
                                      'source': item.source,
                                    });
                                    _openUrl(item.sourceUrl);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: PortfiqTheme.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '전문 보러가기 →',
                                      style: PortfiqTypography.caption.copyWith(
                                        color: PortfiqTheme.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  Color _impactColor(ImpactLevel level) {
    switch (level) {
      case ImpactLevel.high:
        return PortfiqTheme.negative;
      case ImpactLevel.medium:
        return const Color(0xFFF59E0B);
      case ImpactLevel.low:
        return const Color(0xFF6B7280);
    }
  }
}

/// Visually prominent sentiment badge — 호재 / 중립 / 위험
class _SentimentBadge extends StatelessWidget {
  final NewsSentiment sentiment;
  const _SentimentBadge({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (sentiment) {
      NewsSentiment.positive => ('호재', PortfiqTheme.positive, Icons.trending_up_rounded),
      NewsSentiment.negative => ('위험', PortfiqTheme.negative, Icons.trending_down_rounded),
      NewsSentiment.neutral => ('중립', const Color(0xFF9CA3AF), Icons.trending_flat_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            'AI 평가: $label',
            style: PortfiqTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
