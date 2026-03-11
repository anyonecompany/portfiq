import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/services/api_client.dart';

/// State for the ETF report screen — holds all four data sections.
class EtfReportState {
  final bool isLoading;
  final String? error;

  // Section 1: Holdings
  final List<Map<String, dynamic>> holdings;
  final String? holdingsAsOf;
  final List<Map<String, dynamic>> holdingsChanges;

  // Section 2: Sector concentration
  final List<Map<String, dynamic>> sectors;

  // Section 3: Macro sensitivity
  final Map<String, dynamic>? macroSensitivity;

  // Section 4: Comparison
  final List<Map<String, dynamic>> comparisons;
  final String? comparisonSummary;

  const EtfReportState({
    this.isLoading = true,
    this.error,
    this.holdings = const [],
    this.holdingsAsOf,
    this.holdingsChanges = const [],
    this.sectors = const [],
    this.macroSensitivity,
    this.comparisons = const [],
    this.comparisonSummary,
  });

  EtfReportState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? holdings,
    String? holdingsAsOf,
    List<Map<String, dynamic>>? holdingsChanges,
    List<Map<String, dynamic>>? sectors,
    Map<String, dynamic>? macroSensitivity,
    List<Map<String, dynamic>>? comparisons,
    String? comparisonSummary,
  }) {
    return EtfReportState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      holdings: holdings ?? this.holdings,
      holdingsAsOf: holdingsAsOf ?? this.holdingsAsOf,
      holdingsChanges: holdingsChanges ?? this.holdingsChanges,
      sectors: sectors ?? this.sectors,
      macroSensitivity: macroSensitivity ?? this.macroSensitivity,
      comparisons: comparisons ?? this.comparisons,
      comparisonSummary: comparisonSummary ?? this.comparisonSummary,
    );
  }
}

/// Notifier that fetches all ETF report data in parallel.
class EtfReportNotifier extends StateNotifier<EtfReportState> {
  final String ticker;

  EtfReportNotifier(this.ticker) : super(const EtfReportState()) {
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await Future.wait([
        _fetchHoldings(),
        _fetchHoldingsChanges(),
        _fetchSectorConcentration(),
        _fetchMacroSensitivity(),
        _fetchComparison(),
      ]);

      final holdingsResult = results[0];
      final changesResult = results[1];
      final sectorResult = results[2];
      final macroResult = results[3];
      final comparisonResult = results[4];

      state = state.copyWith(
        isLoading: false,
        holdings: (holdingsResult['holdings'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
        holdingsAsOf: holdingsResult['as_of'] as String?,
        holdingsChanges: (changesResult['changes'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
        sectors: (sectorResult['sectors'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
        macroSensitivity: macroResult,
        comparisons: (comparisonResult['comparisons'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
        comparisonSummary:
            comparisonResult['comparison_summary'] as String?,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '리포트 데이터를 불러올 수 없습니다',
      );
    }
  }

  /// Retry fetching all data.
  void retry() => _fetchAll();

  Future<Map<String, dynamic>> _fetchHoldings() async {
    try {
      return await ApiClient.instance.getHoldings(ticker);
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchHoldingsChanges() async {
    try {
      return await ApiClient.instance.getHoldingsChanges(ticker);
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchSectorConcentration() async {
    try {
      return await ApiClient.instance.getSectorConcentration(ticker);
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchMacroSensitivity() async {
    try {
      return await ApiClient.instance.getMacroSensitivity(ticker);
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchComparison() async {
    try {
      return await ApiClient.instance.getComparison(ticker);
    } catch (_) {
      return {};
    }
  }
}

/// Family provider keyed by ticker.
final etfReportProvider = StateNotifierProvider.family<EtfReportNotifier,
    EtfReportState, String>(
  (ref, ticker) => EtfReportNotifier(ticker),
);
