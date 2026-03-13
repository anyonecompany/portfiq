import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/services/api_client.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/glass_card.dart';
import '../my_etf/etf_models.dart';
import '../my_etf/my_etf_provider.dart';
import 'etf_holdings_changes_widget.dart';

/// ETF 상세 화면.
class EtfDetailScreen extends ConsumerStatefulWidget {
  final String ticker;

  const EtfDetailScreen({super.key, required this.ticker});

  @override
  ConsumerState<EtfDetailScreen> createState() => _EtfDetailScreenState();
}

class _EtfDetailScreenState extends ConsumerState<EtfDetailScreen> {
  // Holdings state
  List<EtfHolding> _holdings = [];
  String? _holdingsAsOf;
  bool _holdingsLoading = true;
  String? _holdingsError;

  // Analysis state
  bool _analysisLoading = true;
  String? _analysisError;
  Map<String, dynamic>? _analysisData;

  // Holdings changes state
  bool _holdingsChangesLoading = true;
  List<Map<String, dynamic>> _holdingsChanges = [];

  @override
  void initState() {
    super.initState();
    EventTracker.instance.track('screen_view', properties: {
      'screen': 'etf_detail',
      'ticker': widget.ticker,
    });
    EventTracker.instance.track('etf_detail_viewed', properties: {
      'ticker': widget.ticker,
    });
    _fetchHoldings();
    _fetchAnalysis();
    _fetchHoldingsChanges();
  }

  Future<void> _fetchHoldings() async {
    try {
      final data = await ApiClient.instance.getHoldings(widget.ticker);
      final holdingsList = (data['holdings'] as List<dynamic>?) ?? [];
      final asOf = data['as_of'] as String?;
      if (mounted) {
        setState(() {
          _holdings = holdingsList
              .map((h) => EtfHolding(
                    name: (h['name'] as String?) ?? '',
                    ticker: (h['ticker'] as String?) ?? '',
                    weight: ((h['weight'] as num?) ?? 0).toDouble(),
                  ))
              .toList();
          _holdingsAsOf = asOf;
          _holdingsLoading = false;
        });
        if (_holdings.isNotEmpty) {
          EventTracker.instance.track('etf_holdings_expanded', properties: {
            'ticker': widget.ticker,
            'holdings_count': _holdings.length,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _holdingsLoading = false;
          _holdingsError = 'Holdings data unavailable';
        });
      }
    }
  }

  Future<void> _fetchAnalysis() async {
    try {
      final data = await ApiClient.instance.getEtfAnalysis(widget.ticker);
      if (mounted) {
        setState(() {
          _analysisData = data;
          _analysisLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisLoading = false;
          _analysisError = '분석 데이터를 불러올 수 없습니다';
        });
      }
    }
  }

  Future<void> _fetchHoldingsChanges() async {
    try {
      final data =
          await ApiClient.instance.getHoldingsChanges(widget.ticker);
      final changes =
          (data['changes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      if (mounted) {
        setState(() {
          _holdingsChanges = changes;
          _holdingsChangesLoading = false;
        });
        if (changes.isNotEmpty) {
          EventTracker.instance
              .track('etf_holdings_changes_viewed', properties: {
            'ticker': widget.ticker,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _holdingsChangesLoading = false;
        });
      }
    }
  }

  void _removeEtf() {
    EventTracker.instance.track('remove_etf', properties: {
      'ticker': widget.ticker,
    });
    EventTracker.instance.track('etf_removed', properties: {
      'ticker': widget.ticker,
      'source': 'etf_detail',
    });
    ref.read(myEtfProvider.notifier).removeEtf(widget.ticker);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.ticker}가 포트폴리오에서 제거되었습니다'),
        backgroundColor: PortfiqTheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(myEtfProvider.notifier);
    final etf = notifier.getEtfByTicker(widget.ticker);

    if (etf == null) {
      return Scaffold(
        backgroundColor: PortfiqTheme.primaryBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.ticker),
        ),
        body: Center(
          child: Text(
            'ETF 정보를 찾을 수 없습니다',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final isPositive = (etf.changePct ?? 0) >= 0;
    final changeColor =
        isPositive ? PortfiqTheme.positive : PortfiqTheme.negative;
    final sign = isPositive ? '+' : '';
    final isRegistered = notifier.isRegistered(widget.ticker);

    // Use API holdings if loaded, fallback to model holdings
    final displayHoldings =
        _holdingsLoading ? etf.topHoldings : _holdings;
    final maxWeight = displayHoldings.isNotEmpty
        ? displayHoldings
            .map((h) => h.weight)
            .reduce((a, b) => a > b ? a : b)
        : 1.0;

    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.ticker),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 섹션 1: 가격 헤더
          GlassCard(
            padding: const EdgeInsets.all(PortfiqSpacing.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etf.nameKr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${etf.currentPrice?.toStringAsFixed(2) ?? '-'}',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                if (etf.priceKrw != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '\u20a9${_formatKrw(etf.priceKrw!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (etf.changePct != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: changeColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(PortfiqTheme.radiusChip),
                        ),
                        child: Text(
                          '$sign${etf.changePct!.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (etf.changeAmount != null)
                      Text(
                        '$sign\$${etf.changeAmount!.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 섹션 2: 기본 정보
          GlassCard(
            padding: const EdgeInsets.all(PortfiqSpacing.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기본 정보',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // 2열 그리드
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        label: '카테고리',
                        value: etf.category,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoTile(
                        label: '보수율',
                        value: '${etf.expenseRatio.toStringAsFixed(2)}%',
                      ),
                    ),
                  ],
                ),
                if (etf.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: PortfiqTheme.divider),
                  const SizedBox(height: 12),
                  Text(
                    etf.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.6,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 섹션 3: 구성종목
          _buildHoldingsSection(context, displayHoldings, maxWeight),
          const SizedBox(height: 16),

          // 섹션 4: 관련 뉴스 (플레이스홀더)
          GlassCard(
            padding: const EdgeInsets.all(PortfiqSpacing.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '관련 뉴스',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '관련 뉴스가 없습니다',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ──── CTA: 해부 리포트 보기 ────
          _buildReportButton(context),
          const SizedBox(height: 16),

          // ──── NEW: Analysis sections (sector, macro, comparison) ────
          _buildAnalysisSections(context),

          // ──── NEW: Holdings changes ────
          _buildHoldingsChangesSection(),
          const SizedBox(height: 24),

          // 하단: 제거 버튼
          if (isRegistered)
            Center(
              child: TextButton(
                onPressed: _removeEtf,
                style: TextButton.styleFrom(
                  foregroundColor: PortfiqTheme.negative,
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('포트폴리오에서 제거'),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // CTA: Report button
  // ──────────────────────────────────────────────────────────────

  Widget _buildReportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          EventTracker.instance.track('etf_report_button_tapped', properties: {
            'ticker': widget.ticker,
            'source': 'etf_detail',
          });
          context.push('/etf/${widget.ticker}/report');
        },
        icon: const Icon(LucideIcons.fileBarChart, size: 18),
        label: const Text('해부 리포트 보기'),
        style: ElevatedButton.styleFrom(
          backgroundColor: PortfiqTheme.accent,
          foregroundColor: PortfiqTheme.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PortfiqTheme.radiusButton),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Existing: Holdings section
  // ──────────────────────────────────────────────────────────────

  Widget _buildHoldingsSection(
    BuildContext context,
    List<EtfHolding> holdings,
    double maxWeight,
  ) {
    if (_holdingsLoading) {
      return GlassCard(
        padding: const EdgeInsets.all(PortfiqSpacing.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '구성종목',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: PortfiqTheme.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_holdingsError != null && holdings.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(PortfiqSpacing.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '구성종목',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '구성종목 정보를 불러올 수 없습니다',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (holdings.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '구성종목 Top ${holdings.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_holdingsAsOf != null) ...[
            const SizedBox(height: 4),
            Text(
              '기준일: $_holdingsAsOf',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
          const SizedBox(height: 16),
          ...holdings.map(
            (holding) => _HoldingItem(
              holding: holding,
              maxWeight: maxWeight,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // NEW: Analysis sections (sector, macro, comparison)
  // ──────────────────────────────────────────────────────────────

  Widget _buildAnalysisSections(BuildContext context) {
    if (_analysisLoading) {
      return _buildAnalysisShimmer();
    }

    if (_analysisError != null || _analysisData == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildAnalysisError(context),
      );
    }

    return Column(
      children: [
        _buildSectorConcentrationSection(context),
        const SizedBox(height: 16),
        _buildMacroSensitivitySection(context),
        const SizedBox(height: 16),
        _buildComparisonSection(context),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAnalysisShimmer() {
    return Column(
      children: List.generate(3, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: EdgeInsets.all(PortfiqSpacing.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBar(width: 120, height: 16),
                SizedBox(height: 16),
                _ShimmerBar(width: double.infinity, height: 12),
                SizedBox(height: 8),
                _ShimmerBar(width: 200, height: 12),
                SizedBox(height: 8),
                _ShimmerBar(width: 160, height: 12),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAnalysisError(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: 32,
            color: PortfiqTheme.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            _analysisError ?? '분석 데이터를 불러올 수 없습니다',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _analysisLoading = true;
                  _analysisError = null;
                });
                _fetchAnalysis();
              },
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('다시 시도'),
              style: TextButton.styleFrom(
                foregroundColor: PortfiqTheme.accent,
                minimumSize: const Size(44, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sector Concentration Warning ─────────────────────────────

  Widget _buildSectorConcentrationSection(BuildContext context) {
    final sectors = (_analysisData?['sectors'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (sectors.isEmpty) return const SizedBox.shrink();

    // Find highest sector
    double highestPct = 0;
    String highestName = '';
    for (final sector in sectors) {
      final pct = ((sector['percentage'] as num?) ?? 0).toDouble();
      if (pct > highestPct) {
        highestPct = pct;
        highestName = (sector['name'] as String?) ?? '';
      }
    }

    final isConcentrated = highestPct > 60;

    EventTracker.instance.track('etf_sector_warning_viewed', properties: {
      'ticker': widget.ticker,
      'warning_text': isConcentrated ? '$highestName주 집중형' : 'none',
    });

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '섹터 분포',
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
                        '$highestName주 집중형',
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
          const SizedBox(height: 16),
          ...sectors.map((sector) {
            final name = (sector['name'] as String?) ?? '';
            final pct =
                ((sector['percentage'] as num?) ?? 0).toDouble();
            final isHighest = name == highestName;
            return _SectorBar(
              name: name,
              percentage: pct,
              isHighest: isHighest,
            );
          }),
        ],
      ),
    );
  }

  // ── Macro Sensitivity ────────────────────────────────────────

  Widget _buildMacroSensitivitySection(BuildContext context) {
    final macro =
        _analysisData?['macro_sensitivity'] as Map<String, dynamic>?;
    if (macro == null) return const SizedBox.shrink();

    EventTracker.instance
        .track('etf_macro_sensitivity_viewed', properties: {
      'ticker': widget.ticker,
    });

    final factors = <_MacroFactor>[
      _MacroFactor(
        label: '금리',
        icon: LucideIcons.percent,
        level: (macro['interest_rate'] as String?) ?? 'Low',
        explanation:
            (macro['interest_rate_explanation'] as String?) ?? '',
      ),
      _MacroFactor(
        label: '달러',
        icon: LucideIcons.dollarSign,
        level: (macro['dollar'] as String?) ?? 'Low',
        explanation: (macro['dollar_explanation'] as String?) ?? '',
      ),
      _MacroFactor(
        label: '유가',
        icon: LucideIcons.fuel,
        level: (macro['oil'] as String?) ?? 'Low',
        explanation: (macro['oil_explanation'] as String?) ?? '',
      ),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '매크로 민감도',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...factors.map((factor) => _MacroRow(
                factor: factor,
                ticker: widget.ticker,
              )),
        ],
      ),
    );
  }

  // ── ETF Comparison Card ──────────────────────────────────────

  Widget _buildComparisonSection(BuildContext context) {
    final comparisons = (_analysisData?['comparisons'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final summary =
        (_analysisData?['comparison_summary'] as String?) ?? '';

    if (comparisons.isEmpty) return const SizedBox.shrink();

    EventTracker.instance.track('etf_comparison_viewed', properties: {
      'ticker': widget.ticker,
      'compared_with': comparisons
          .map((c) => c['ticker'] as String? ?? '')
          .join(','),
    });

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AI 비교 분석',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: PortfiqTheme.accent,
                    ),
              ),
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.sparkles,
                size: 18,
                color: PortfiqTheme.accent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Horizontal scroll of comparison cards
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: comparisons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final comp = comparisons[index];
                return _ComparisonCard(
                  ticker: (comp['ticker'] as String?) ?? '',
                  expenseRatio:
                      ((comp['expense_ratio'] as num?) ?? 0).toDouble(),
                  keyDifference:
                      (comp['key_difference'] as String?) ?? '',
                );
              },
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: PortfiqTheme.divider),
            const SizedBox(height: 12),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.6,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ── Holdings Changes ─────────────────────────────────────────

  Widget _buildHoldingsChangesSection() {
    if (_holdingsChangesLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassCard(
          padding: const EdgeInsets.all(PortfiqSpacing.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '지난주 대비 변화',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: PortfiqTheme.accent,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_holdingsChanges.isEmpty) {
      return const SizedBox.shrink();
    }

    return EtfHoldingsChangesWidget(changes: _holdingsChanges);
  }
}

// ════════════════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════════════════

/// KRW 금액을 콤마 포맷으로 변환한다.
String _formatKrw(int amount) {
  final str = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
  }
  return buffer.toString();
}

// ════════════════════════════════════════════════════════════════
// Private sub-widgets
// ════════════════════════════════════════════════════════════════

/// 정보 타일 위젯.
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

/// 구성종목 아이템 위젯 (탭 가능).
class _HoldingItem extends StatelessWidget {
  final EtfHolding holding;
  final double maxWeight;

  const _HoldingItem({required this.holding, required this.maxWeight});

  @override
  Widget build(BuildContext context) {
    final hasTicker = holding.ticker.isNotEmpty;

    final content = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                holding.ticker,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFamily: 'Inter',
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  holding.name,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${holding.weight.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontFamily: 'Inter',
                      color: PortfiqTheme.textPrimary,
                    ),
              ),
              if (hasTicker) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: PortfiqTheme.textTertiary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // 비중 바
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth =
                      constraints.maxWidth * (holding.weight / maxWeight);
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
                          borderRadius: BorderRadius.circular(2),
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

    if (!hasTicker) {
      return content;
    }

    return InkWell(
      onTap: () {
        EventTracker.instance.track('holding_tap', properties: {
          'ticker': holding.ticker,
        });
        context.push('/company/${holding.ticker}');
      },
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

/// 섹터 분포 수평 바.
class _SectorBar extends StatelessWidget {
  final String name;
  final double percentage;
  final bool isHighest;

  const _SectorBar({
    required this.name,
    required this.percentage,
    required this.isHighest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isHighest
                          ? PortfiqTheme.textPrimary
                          : PortfiqTheme.textSecondary,
                      fontWeight:
                          isHighest ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isHighest
                      ? PortfiqTheme.textPrimary
                      : PortfiqTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 6,
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
                          color: isHighest
                              ? PortfiqTheme.accent
                              : PortfiqTheme.textTertiary
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
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

/// 매크로 민감도 데이터 모델.
class _MacroFactor {
  final String label;
  final IconData icon;
  final String level;
  final String explanation;

  const _MacroFactor({
    required this.label,
    required this.icon,
    required this.level,
    required this.explanation,
  });
}

/// 매크로 민감도 행.
class _MacroRow extends StatelessWidget {
  final _MacroFactor factor;
  final String ticker;

  const _MacroRow({required this.factor, required this.ticker});

  Color _levelColor() {
    switch (factor.level.toLowerCase()) {
      case 'high':
        return PortfiqTheme.negative; // #EF4444
      case 'medium':
        return PortfiqTheme.warning; // #F59E0B
      default:
        return PortfiqTheme.textTertiary; // #6B7280
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
                      Icon(factor.icon, size: 20, color: _levelColor()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${factor.label} 민감도',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 16),
                  Text(
                    factor.explanation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.6,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: factor.explanation.isNotEmpty
            ? () => _showExplanation(context)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Row(
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
        ),
      ),
    );
  }
}

/// ETF 비교 카드.
class _ComparisonCard extends StatelessWidget {
  final String ticker;
  final double expenseRatio;
  final String keyDifference;

  const _ComparisonCard({
    required this.ticker,
    required this.expenseRatio,
    required this.keyDifference,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
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
          Text(
            ticker,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            '보수 ${expenseRatio.toStringAsFixed(2)}%',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(
            keyDifference,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 로딩 시 shimmer placeholder 바.
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
