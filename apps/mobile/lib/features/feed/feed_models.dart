/// Impact level for a news item on an ETF.
enum ImpactLevel { high, medium, low }

/// Represents a single ETF impact entry within a news item.
class EtfImpact {
  final String etfTicker;
  final ImpactLevel level;

  const EtfImpact({required this.etfTicker, required this.level});
}

/// AI sentiment assessment for a news item.
enum NewsSentiment { positive, neutral, negative }

/// A single news item displayed in the feed.
class NewsItem {
  final String id;
  final String headline;
  final String impactReason;
  final String summary3line;
  final NewsSentiment sentiment;
  final String source;
  final String sourceUrl;
  final DateTime publishedAt;
  final List<EtfImpact> impacts;

  const NewsItem({
    required this.id,
    required this.headline,
    required this.impactReason,
    this.summary3line = '',
    this.sentiment = NewsSentiment.neutral,
    required this.source,
    required this.sourceUrl,
    required this.publishedAt,
    required this.impacts,
  });

  /// Highest impact level among all ETF impacts for sort ordering.
  ImpactLevel get highestImpact {
    if (impacts.any((i) => i.level == ImpactLevel.high)) return ImpactLevel.high;
    if (impacts.any((i) => i.level == ImpactLevel.medium)) return ImpactLevel.medium;
    return ImpactLevel.low;
  }
}

/// ETF change data used in briefings.
class EtfChange {
  final String ticker;
  final double changePercent;

  const EtfChange({required this.ticker, required this.changePercent});
}

/// Briefing type — morning or night.
enum BriefingType { morning, night }

/// Briefing data shown as a banner / detail screen.
class BriefingData {
  final BriefingType type;
  final String title;
  final String summary;
  final List<EtfChange> etfChanges;
  final List<String> checkpoints;

  const BriefingData({
    required this.type,
    required this.title,
    required this.summary,
    required this.etfChanges,
    required this.checkpoints,
  });
}
