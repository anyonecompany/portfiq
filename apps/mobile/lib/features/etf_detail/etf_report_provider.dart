import 'package:flutter/foundation.dart';
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

  // Per-section failure tracking
  final Set<String> failedSections;

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
    this.failedSections = const {},
  });

  /// True when every section failed to load.
  bool get allSectionsFailed =>
      failedSections.length >= 5 && holdings.isEmpty && sectors.isEmpty;

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
    Set<String>? failedSections,
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
      failedSections: failedSections ?? this.failedSections,
    );
  }
}

/// Notifier that fetches all ETF report data in parallel.
///
/// Each section is fetched independently. If one fails the remaining
/// sections are still rendered.
class EtfReportNotifier extends StateNotifier<EtfReportState> {
  final String ticker;

  EtfReportNotifier(this.ticker) : super(const EtfReportState()) {
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    state = state.copyWith(isLoading: true, error: null);

    final failed = <String>{};

    final results = await Future.wait([
      _fetchHoldings(failed),
      _fetchHoldingsChanges(failed),
      _fetchSectorConcentration(failed),
      _fetchMacroSensitivity(failed),
      _fetchComparison(failed),
    ]);

    final holdingsResult = results[0];
    final changesResult = results[1];
    final sectorResult = results[2];
    final macroResult = results[3];
    final comparisonResult = results[4];

    final errorMsg = failed.length >= 5
        ? '리포트 데이터를 불러올 수 없습니다. 네트워크를 확인해주세요.'
        : null;

    state = state.copyWith(
      isLoading: false,
      error: errorMsg,
      failedSections: failed,
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
      macroSensitivity: macroResult.isNotEmpty ? macroResult : null,
      comparisons: (comparisonResult['comparisons'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [],
      comparisonSummary: comparisonResult['comparison_summary'] as String?,
    );
  }

  /// Retry fetching all data.
  void retry() => _fetchAll();

  Future<Map<String, dynamic>> _fetchHoldings(Set<String> failed) async {
    try {
      return await ApiClient.instance.getHoldings(ticker);
    } catch (e) {
      if (kDebugMode) print('[EtfReport] holdings 로드 실패: $e');
      failed.add('holdings');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchHoldingsChanges(Set<String> failed) async {
    try {
      return await ApiClient.instance.getHoldingsChanges(ticker);
    } catch (e) {
      if (kDebugMode) print('[EtfReport] holdings-changes 로드 실패: $e');
      failed.add('holdings_changes');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchSectorConcentration(Set<String> failed) async {
    try {
      return await ApiClient.instance.getSectorConcentration(ticker);
    } catch (e) {
      if (kDebugMode) print('[EtfReport] sector-concentration 로드 실패: $e');
      failed.add('sector');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchMacroSensitivity(Set<String> failed) async {
    try {
      return await ApiClient.instance.getMacroSensitivity(ticker);
    } catch (e) {
      if (kDebugMode) print('[EtfReport] macro-sensitivity 로드 실패: $e');
      failed.add('macro');
      return {};
    }
  }

  Future<Map<String, dynamic>> _fetchComparison(Set<String> failed) async {
    try {
      return await ApiClient.instance.getComparison(ticker);
    } catch (e) {
      if (kDebugMode) print('[EtfReport] comparison 로드 실패: $e');
      failed.add('comparison');
      return {};
    }
  }
}

/// Family provider keyed by ticker.
final etfReportProvider = StateNotifierProvider.family<EtfReportNotifier,
    EtfReportState, String>(
  (ref, ticker) => EtfReportNotifier(ticker),
);
