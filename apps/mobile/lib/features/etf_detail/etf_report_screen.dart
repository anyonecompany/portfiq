import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/glass_card.dart';
import 'etf_report_provider.dart';

/// ETF 해부 리포트 전체 화면.
///
/// 4개 섹션으로 구성:
/// 1. 구성종목 분석 (Top 10 + 주간 변화)
/// 2. 섹터 집중도 (수평 바 차트 + 경고 배지)
/// 3. 거시 민감도 (5개 매크로 변수)
/// 4. 동일 테마 비교 (수평 스크롤 카드 + AI 요약)
class EtfReportScreen extends ConsumerStatefulWidget {
  final String ticker;

  const EtfReportScreen({super.key, required this.ticker});

  @override
  ConsumerState<EtfReportScreen> createState() => _EtfReportScreenState();
}

class _EtfReportScreenState extends ConsumerState<EtfReportScreen> {
  @override
  void initState() {
    super.initState();
    EventTracker.instance.track('screen_view', properties: {
      'screen': 'etf_report',
      'ticker': widget.ticker,
    });
    EventTracker.instance.track('etf_report_viewed', properties: {
      'ticker': widget.ticker,
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(etfReportProvider(widget.ticker));

    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${widget.ticker} 해부 리포트'),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, EtfReportState state) {
    if (state.isLoading) {
      return _buildLoadingState();
    }

    if (state.error != null) {
      return _buildErrorState(context, state.error!);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section 1: Holdings Analysis
        _HoldingsAnalysisSection(
          ticker: widget.ticker,
          holdings: state.holdings,
          holdingsAsOf: state.holdingsAsOf,
          holdingsChanges: state.holdingsChanges,
        ),
        const SizedBox(height: 16),

        // Section 2: Sector Concentration
        _SectorConcentrationSection(
          ticker: widget.ticker,
          sectors: state.sectors,
        ),
        const SizedBox(height: 16),

        // Section 3: Macro Sensitivity
        _MacroSensitivitySection(
          ticker: widget.ticker,
          macroData: state.macroSensitivity,
        ),
        const SizedBox(height: 16),

        // Section 4: Theme Comparison
        _ThemeComparisonSection(
          ticker: widget.ticker,
          comparisons: state.comparisons,
          summary: state.comparisonSummary,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(4, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: EdgeInsets.all(PortfiqSpacing.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBar(width: 140, height: 18),
                SizedBox(height: 20),
                _ShimmerBar(width: double.infinity, height: 14),
                SizedBox(height: 10),
                _ShimmerBar(width: 220, height: 14),
                SizedBox(height: 10),
                _ShimmerBar(width: 180, height: 14),
                SizedBox(height: 10),
                _ShimmerBar(width: 250, height: 14),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.alertCircle,
              size: 48,
              color: PortfiqTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref
                      .read(etfReportProvider(widget.ticker).notifier)
                      .retry();
                },
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('다시 시도'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Section 1: Holdings Analysis
// ════════════════════════════════════════════════════════════════════

class _HoldingsAnalysisSection extends StatefulWidget {
  final String ticker;
  final List<Map<String, dynamic>> holdings;
  final String? holdingsAsOf;
  final List<Map<String, dynamic>> holdingsChanges;

  const _HoldingsAnalysisSection({
    required this.ticker,
    required this.holdings,
    this.holdingsAsOf,
    required this.holdingsChanges,
  });

  @override
  State<_HoldingsAnalysisSection> createState() =>
      _HoldingsAnalysisSectionState();
}

class _HoldingsAnalysisSectionState extends State<_HoldingsAnalysisSection> {
  bool _tracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tracked) {
      _tracked = true;
      EventTracker.instance.track('etf_report_section_viewed', properties: {
        'ticker': widget.ticker,
        'section': 'holdings_analysis',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.holdings.isEmpty && widget.holdingsChanges.isEmpty) {
      return _buildEmptySection(context, '구성종목 분석', '구성종목 데이터가 없습니다');
    }

    final maxWeight = widget.holdings.isNotEmpty
        ? widget.holdings
            .map((h) => ((h['weight'] as num?) ?? 0).toDouble())
            .reduce((a, b) => a > b ? a : b)
        : 1.0;

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(LucideIcons.pieChart, size: 18, color: PortfiqTheme.accent),
              const SizedBox(width: 8),
              Text(
                '구성종목 분석',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          if (widget.holdingsAsOf != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '기준일: ${widget.holdingsAsOf}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Top 10 Holdings
          if (widget.holdings.isNotEmpty) ...[
            Text(
              'Top ${widget.holdings.length > 10 ? 10 : widget.holdings.length}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            ...widget.holdings.take(10).map((h) {
              final name = (h['name'] as String?) ?? '';
              final ticker = (h['ticker'] as String?) ?? '';
              final weight = ((h['weight'] as num?) ?? 0).toDouble();

              // Find matching change
              Map<String, dynamic>? changeData;
              for (final c in widget.holdingsChanges) {
                if ((c['ticker'] as String?) == ticker) {
                  changeData = c;
                  break;
                }
              }
              final oldWeight = changeData != null
                  ? ((changeData['old_weight'] as num?) ?? 0).toDouble()
                  : null;
              final diff = oldWeight != null ? weight - oldWeight : null;

              return _HoldingRow(
                ticker: ticker,
                name: name,
                weight: weight,
                maxWeight: maxWeight,
                weightDiff: diff,
              );
            }),
          ],

          // Holdings changes section
          if (widget.holdingsChanges.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: PortfiqTheme.divider),
            const SizedBox(height: 16),
            Text(
              '주간 비중 변화',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            ...widget.holdingsChanges.map((change) {
              final name = (change['name'] as String?) ?? '';
              final ticker = (change['ticker'] as String?) ?? '';
              final oldWeight =
                  ((change['old_weight'] as num?) ?? 0).toDouble();
              final newWeight =
                  ((change['new_weight'] as num?) ?? 0).toDouble();
              final diff = newWeight - oldWeight;

              return _ChangeRow(
                ticker: ticker,
                name: name,
                oldWeight: oldWeight,
                newWeight: newWeight,
                diff: diff,
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Single holding row with weight bar and optional week-over-week change.
class _HoldingRow extends StatelessWidget {
  final String ticker;
  final String name;
  final double weight;
  final double maxWeight;
  final double? weightDiff;

  const _HoldingRow({
    required this.ticker,
    required this.name,
    required this.weight,
    required this.maxWeight,
    this.weightDiff,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ticker,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFamily: 'Inter',
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${weight.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontFamily: 'Inter',
                      color: PortfiqTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (weightDiff != null) ...[
                const SizedBox(width: 6),
                _WeightDiffBadge(diff: weightDiff!),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Weight bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth =
                      constraints.maxWidth * (weight / maxWeight);
                  return Stack(
                    children: [
                      Container(
                        width: constraints.maxWidth,
                        color: PortfiqTheme.surface,
                      ),
                      Container(
                        width: barWidth,
                        decoration: BoxDecoration(
                          color: PortfiqTheme.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small badge showing weight change with arrow.
class _WeightDiffBadge extends StatelessWidget {
  final double diff;

  const _WeightDiffBadge({required this.diff});

  @override
  Widget build(BuildContext context) {
    if (diff.abs() < 0.01) return const SizedBox.shrink();

    final isPositive = diff > 0;
    final color = isPositive ? PortfiqTheme.positive : PortfiqTheme.negative;
    final arrow = isPositive ? '\u2191' : '\u2193'; // ↑ ↓
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PortfiqTheme.radiusChip),
      ),
      child: Text(
        '$arrow $sign${diff.toStringAsFixed(1)}%',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

/// Holdings change row with old → new weight.
class _ChangeRow extends StatelessWidget {
  final String ticker;
  final String name;
  final double oldWeight;
  final double newWeight;
  final double diff;

  const _ChangeRow({
    required this.ticker,
    required this.name,
    required this.oldWeight,
    required this.newWeight,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    final absDiff = diff.abs();
    final isSignificant = absDiff > 1.0;
    final Color changeColor;
    final IconData arrowIcon;

    if (diff > 0) {
      changeColor =
          isSignificant ? PortfiqTheme.positive : PortfiqTheme.textSecondary;
      arrowIcon = LucideIcons.trendingUp;
    } else if (diff < 0) {
      changeColor =
          isSignificant ? PortfiqTheme.negative : PortfiqTheme.textSecondary;
      arrowIcon = LucideIcons.trendingDown;
    } else {
      changeColor = PortfiqTheme.textSecondary;
      arrowIcon = LucideIcons.minus;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticker,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFamily: 'Inter',
                      ),
                ),
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            '${oldWeight.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: PortfiqTheme.textSecondary,
                ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              LucideIcons.arrowRight,
              size: 14,
              color: PortfiqTheme.textTertiary,
            ),
          ),
          Text(
            '${newWeight.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: changeColor,
                  fontWeight: isSignificant ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
          const SizedBox(width: 6),
          Icon(arrowIcon, size: 16, color: changeColor),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Section 2: Sector Concentration
// ════════════════════════════════════════════════════════════════════

class _SectorConcentrationSection extends StatefulWidget {
  final String ticker;
  final List<Map<String, dynamic>> sectors;

  const _SectorConcentrationSection({
    required this.ticker,
    required this.sectors,
  });

  @override
  State<_SectorConcentrationSection> createState() =>
      _SectorConcentrationSectionState();
}

class _SectorConcentrationSectionState
    extends State<_SectorConcentrationSection> {
  bool _tracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tracked) {
      _tracked = true;
      EventTracker.instance.track('etf_report_section_viewed', properties: {
        'ticker': widget.ticker,
        'section': 'sector_concentration',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sectors.isEmpty) {
      return _buildEmptySection(context, '섹터 집중도', '섹터 데이터가 없습니다');
    }

    // Find highest sector
    double highestPct = 0;
    String highestName = '';
    for (final sector in widget.sectors) {
      final pct = ((sector['percentage'] as num?) ?? 0).toDouble();
      if (pct > highestPct) {
        highestPct = pct;
        highestName = (sector['name'] as String?) ?? '';
      }
    }
    final isConcentrated = highestPct > 60;

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(LucideIcons.barChart2, size: 18, color: PortfiqTheme.accent),
              const SizedBox(width: 8),
              Text(
                '섹터 집중도',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (isConcentrated)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PortfiqTheme.warning.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(PortfiqTheme.radiusChip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.alertTriangle,
                        size: 14,
                        color: PortfiqTheme.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$highestName 섹터 집중 위험',
                        style: const TextStyle(
                          color: PortfiqTheme.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Sector bars
          ...widget.sectors.map((sector) {
            final name = (sector['name'] as String?) ?? '';
            final pct = ((sector['percentage'] as num?) ?? 0).toDouble();
            final isHighest = name == highestName;
            return _SectorBar(
              name: name,
              percentage: pct,
              isHighest: isHighest,
              isConcentrated: isHighest && isConcentrated,
            );
          }),
        ],
      ),
    );
  }
}

/// Horizontal bar for sector distribution.
class _SectorBar extends StatelessWidget {
  final String name;
  final double percentage;
  final bool isHighest;
  final bool isConcentrated;

  const _SectorBar({
    required this.name,
    required this.percentage,
    required this.isHighest,
    this.isConcentrated = false,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = isConcentrated
        ? PortfiqTheme.warning
        : isHighest
            ? PortfiqTheme.accent
            : PortfiqTheme.textTertiary.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isHighest
                            ? PortfiqTheme.textPrimary
                            : PortfiqTheme.textSecondary,
                        fontWeight:
                            isHighest ? FontWeight.w600 : FontWeight.w400,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isHighest
                      ? PortfiqTheme.textPrimary
                      : PortfiqTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 8,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth *
                      (percentage / 100).clamp(0.0, 1.0);
                  return Stack(
                    children: [
                      Container(
                        width: constraints.maxWidth,
                        color: PortfiqTheme.surface,
                      ),
                      Container(
                        width: barWidth,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Section 3: Macro Sensitivity
// ════════════════════════════════════════════════════════════════════

class _MacroSensitivitySection extends StatefulWidget {
  final String ticker;
  final Map<String, dynamic>? macroData;

  const _MacroSensitivitySection({
    required this.ticker,
    this.macroData,
  });

  @override
  State<_MacroSensitivitySection> createState() =>
      _MacroSensitivitySectionState();
}

class _MacroSensitivitySectionState extends State<_MacroSensitivitySection> {
  bool _tracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tracked) {
      _tracked = true;
      EventTracker.instance.track('etf_report_section_viewed', properties: {
        'ticker': widget.ticker,
        'section': 'macro_sensitivity',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final macro = widget.macroData;
    if (macro == null || macro.isEmpty) {
      return _buildEmptySection(context, '거시 민감도', '매크로 데이터가 없습니다');
    }

    final factors = <_MacroFactorData>[
      _MacroFactorData(
        label: '금리',
        icon: LucideIcons.percent,
        level: (macro['interest_rate'] as String?) ?? 'Low',
        explanation: (macro['interest_rate_explanation'] as String?) ?? '',
      ),
      _MacroFactorData(
        label: '인플레이션',
        icon: LucideIcons.trendingUp,
        level: (macro['inflation'] as String?) ?? 'Low',
        explanation: (macro['inflation_explanation'] as String?) ?? '',
      ),
      _MacroFactorData(
        label: '달러',
        icon: LucideIcons.dollarSign,
        level: (macro['dollar'] as String?) ?? 'Low',
        explanation: (macro['dollar_explanation'] as String?) ?? '',
      ),
      _MacroFactorData(
        label: '유가',
        icon: LucideIcons.fuel,
        level: (macro['oil'] as String?) ?? 'Low',
        explanation: (macro['oil_explanation'] as String?) ?? '',
      ),
      _MacroFactorData(
        label: '고용',
        icon: LucideIcons.users,
        level: (macro['employment'] as String?) ?? 'Low',
        explanation: (macro['employment_explanation'] as String?) ?? '',
      ),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 18, color: PortfiqTheme.accent),
              const SizedBox(width: 8),
              Text(
                '거시 민감도',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '탭하면 상세 설명을 볼 수 있습니다',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 20),
          ...factors.map((factor) => _MacroFactorRow(
                factor: factor,
                ticker: widget.ticker,
              )),
        ],
      ),
    );
  }
}

/// Internal data holder for a macro factor.
class _MacroFactorData {
  final String label;
  final IconData icon;
  final String level;
  final String explanation;

  const _MacroFactorData({
    required this.label,
    required this.icon,
    required this.level,
    required this.explanation,
  });
}

/// Macro factor row with level badge, color-coded bar, and tappable explanation.
class _MacroFactorRow extends StatelessWidget {
  final _MacroFactorData factor;
  final String ticker;

  const _MacroFactorRow({required this.factor, required this.ticker});

  Color _levelColor() {
    switch (factor.level.toLowerCase()) {
      case 'high':
        return PortfiqTheme.negative;
      case 'medium':
        return PortfiqTheme.warning;
      default:
        return PortfiqTheme.textTertiary;
    }
  }

  String _levelLabel() {
    switch (factor.level.toLowerCase()) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  double _levelValue() {
    switch (factor.level.toLowerCase()) {
      case 'high':
        return 1.0;
      case 'medium':
        return 0.6;
      default:
        return 0.25;
    }
  }

  void _showExplanation(BuildContext context) {
    if (factor.explanation.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: PortfiqTheme.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PortfiqSpacing.space24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(factor.icon, size: 22, color: _levelColor()),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${factor.label} 민감도',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _levelColor().withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(PortfiqTheme.radiusChip),
                        ),
                        child: Text(
                          _levelLabel(),
                          style: TextStyle(
                            color: _levelColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    factor.explanation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.7,
                        ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: factor.explanation.isNotEmpty
            ? () => _showExplanation(context)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(factor.icon,
                      size: 18, color: PortfiqTheme.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    factor.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(PortfiqTheme.radiusChip),
                    ),
                    child: Text(
                      _levelLabel(),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  if (factor.explanation.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: PortfiqTheme.textTertiary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Color-coded sensitivity bar
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth =
                            constraints.maxWidth * _levelValue();
                        return Stack(
                          children: [
                            Container(
                              width: constraints.maxWidth,
                              color: PortfiqTheme.surface,
                            ),
                            Container(
                              width: barWidth,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Section 4: Theme Comparison
// ════════════════════════════════════════════════════════════════════

class _ThemeComparisonSection extends StatefulWidget {
  final String ticker;
  final List<Map<String, dynamic>> comparisons;
  final String? summary;

  const _ThemeComparisonSection({
    required this.ticker,
    required this.comparisons,
    this.summary,
  });

  @override
  State<_ThemeComparisonSection> createState() =>
      _ThemeComparisonSectionState();
}

class _ThemeComparisonSectionState extends State<_ThemeComparisonSection> {
  bool _tracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tracked) {
      _tracked = true;
      EventTracker.instance.track('etf_report_section_viewed', properties: {
        'ticker': widget.ticker,
        'section': 'theme_comparison',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.comparisons.isEmpty) {
      return _buildEmptySection(context, '동일 테마 비교', '비교 데이터가 없습니다');
    }

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI sparkles
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 18, color: PortfiqTheme.accent),
              const SizedBox(width: 8),
              Text(
                '동일 테마 비교',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: PortfiqTheme.accent,
                    ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: PortfiqTheme.accent.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(PortfiqTheme.radiusChip),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: PortfiqTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal scroll comparison cards
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.comparisons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final comp = widget.comparisons[index];
                return _ComparisonCard(
                  ticker: (comp['ticker'] as String?) ?? '',
                  name: (comp['name'] as String?) ?? '',
                  expenseRatio:
                      ((comp['expense_ratio'] as num?) ?? 0).toDouble(),
                  keyDifference:
                      (comp['key_difference'] as String?) ?? '',
                );
              },
            ),
          ),

          // AI Summary
          if (widget.summary != null && widget.summary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: PortfiqTheme.divider),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  size: 14,
                  color: PortfiqTheme.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.summary!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.7,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Comparison ETF card for horizontal scroll.
class _ComparisonCard extends StatelessWidget {
  final String ticker;
  final String name;
  final double expenseRatio;
  final String keyDifference;

  const _ComparisonCard({
    required this.ticker,
    required this.name,
    required this.expenseRatio,
    required this.keyDifference,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(PortfiqSpacing.space16),
      decoration: BoxDecoration(
        color: PortfiqTheme.surface,
        borderRadius: BorderRadius.circular(PortfiqTheme.radiusCard),
        border: Border.all(
          color: PortfiqTheme.divider.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Ticker
          Text(
            ticker,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
          ),
          // Name
          if (name.isNotEmpty)
            Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          // Expense ratio
          Text(
            '보수 ${expenseRatio.toStringAsFixed(2)}%',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          // Key difference
          Text(
            keyDifference,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Shared Utility Widgets
// ════════════════════════════════════════════════════════════════════

/// Empty section placeholder.
Widget _buildEmptySection(BuildContext context, String title, String message) {
  return GlassCard(
    padding: const EdgeInsets.all(PortfiqSpacing.space20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shimmer placeholder bar for loading state.
class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;

  const _ShimmerBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PortfiqTheme.surface,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
