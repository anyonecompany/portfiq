import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/services/api_client.dart';
import 'etf_models.dart';

/// My ETF 탭 상태.
class MyEtfState {
  final List<EtfInfo> registeredEtfs;
  final List<EtfInfo> searchResults;
  final bool isLoading;
  final bool isSearching;
  final bool isRefreshingPrices;
  final DateTime? lastPriceUpdate;
  final String? error;

  const MyEtfState({
    this.registeredEtfs = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.isSearching = false,
    this.isRefreshingPrices = false,
    this.lastPriceUpdate,
    this.error,
  });

  MyEtfState copyWith({
    List<EtfInfo>? registeredEtfs,
    List<EtfInfo>? searchResults,
    bool? isLoading,
    bool? isSearching,
    bool? isRefreshingPrices,
    DateTime? lastPriceUpdate,
    String? error,
  }) {
    return MyEtfState(
      registeredEtfs: registeredEtfs ?? this.registeredEtfs,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      isRefreshingPrices: isRefreshingPrices ?? this.isRefreshingPrices,
      lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
      error: error,
    );
  }
}

/// My ETF 상태 관리 노티파이어 — API first, mock fallback.
class MyEtfNotifier extends StateNotifier<MyEtfState> {
  MyEtfNotifier() : super(const MyEtfState(isLoading: true)) {
    loadRegisteredEtfs();
  }

  String get _deviceId =>
      Hive.box('settings').get('device_id', defaultValue: 'unknown') as String;

  /// 등록된 ETF 목록 로드.
  Future<void> loadRegisteredEtfs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 등록된 ETF 티커 목록은 로컬 Hive에서 관리
      final box = Hive.box('settings');
      final tickers = (box.get('registered_etfs') as List<dynamic>?)
              ?.cast<String>() ??
          ['QQQ', 'VOO', 'SCHD']; // 기본 3개

      // 1) ETF 상세 정보를 개별 조회
      final etfs = <EtfInfo>[];
      for (final ticker in tickers) {
        final etf = await _fetchEtfDetailOnly(ticker);
        if (etf != null) etfs.add(etf);
      }

      // 2) 가격을 batch API로 한 번에 조회
      final withPrices = await _applyBatchPrices(etfs);

      state = state.copyWith(
        registeredEtfs: withPrices,
        isLoading: false,
        lastPriceUpdate: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) print('[MyEtfProvider] 로드 실패, mock 사용: $e');
      state = state.copyWith(
        registeredEtfs: [_mockEtfMap['QQQ']!, _mockEtfMap['VOO']!, _mockEtfMap['SCHD']!],
        isLoading: false,
        lastPriceUpdate: DateTime.now(),
      );
    }
  }

  /// 가격만 새로고침 (전체 로드 없이 batch API로 가격만 갱신).
  Future<void> refreshPrices() async {
    if (state.registeredEtfs.isEmpty || state.isRefreshingPrices) return;

    state = state.copyWith(isRefreshingPrices: true);
    try {
      final updated = await _applyBatchPrices(state.registeredEtfs);
      state = state.copyWith(
        registeredEtfs: updated,
        isRefreshingPrices: false,
        lastPriceUpdate: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) print('[MyEtfProvider] 가격 새로고침 실패: $e');
      state = state.copyWith(isRefreshingPrices: false);
    }
  }

  /// Batch price API를 호출하여 ETF 리스트에 가격 정보를 적용한다.
  Future<List<EtfInfo>> _applyBatchPrices(List<EtfInfo> etfs) async {
    if (etfs.isEmpty) return etfs;

    try {
      final tickers = etfs.map((e) => e.ticker).toList();
      final response = await ApiClient.instance.post(
        '/api/v1/etf/batch-prices',
        data: {'tickers': tickers},
      );
      final data = response.data as Map<String, dynamic>;
      final prices = data['prices'] as Map<String, dynamic>? ?? {};

      return etfs.map((etf) {
        final priceData = prices[etf.ticker] as Map<String, dynamic>?;
        if (priceData == null) return etf;
        return EtfInfo(
          ticker: etf.ticker,
          name: etf.name,
          nameKr: etf.nameKr,
          category: etf.category,
          expenseRatio: etf.expenseRatio,
          description: etf.description,
          topHoldings: etf.topHoldings,
          currentPrice: (priceData['price'] as num?)?.toDouble(),
          changePct: (priceData['change_pct'] as num?)?.toDouble(),
          changeAmount: (priceData['change_amt'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('[MyEtfProvider] Batch 가격 조회 실패: $e');
      return etfs;
    }
  }

  /// ETF 상세 정보만 조회 (가격 제외 — batch로 별도 처리).
  Future<EtfInfo?> _fetchEtfDetailOnly(String ticker) async {
    try {
      final detailResp =
          await ApiClient.instance.get('/api/v1/etf/${ticker.toUpperCase()}/detail');
      final d = detailResp.data as Map<String, dynamic>;

      final holdings = _parseHoldings(d['top_holdings']);

      return EtfInfo(
        ticker: d['ticker'] as String? ?? ticker,
        name: d['name'] as String? ?? '',
        nameKr: d['name_kr'] as String? ?? d['name'] as String? ?? '',
        category: d['category'] as String? ?? '',
        expenseRatio: (d['expense_ratio'] as num?)?.toDouble() ?? 0.0,
        description: d['description'] as String? ?? '',
        topHoldings: holdings,
      );
    } catch (e) {
      if (kDebugMode) print('[MyEtfProvider] ETF 상세 조회 실패 ($ticker): $e');
      return _mockEtfMap[ticker.toUpperCase()];
    }
  }

  /// ETF 상세 + 가격 조회 (단일 — addEtf 등에서 사용).
  Future<EtfInfo?> _fetchEtfDetail(String ticker) async {
    try {
      final detailResp =
          await ApiClient.instance.get('/api/v1/etf/${ticker.toUpperCase()}/detail');
      final d = detailResp.data as Map<String, dynamic>;

      // 가격 조회
      double? price;
      double? changePct;
      double? changeAmt;
      try {
        final priceResp =
            await ApiClient.instance.get('/api/v1/etf/${ticker.toUpperCase()}/price');
        final p = priceResp.data as Map<String, dynamic>;
        price = (p['price'] as num?)?.toDouble();
        changePct = (p['change_pct'] as num?)?.toDouble();
        changeAmt = (p['change_amt'] as num?)?.toDouble();
      } catch (_) {
        // 가격 조회 실패 시 무시
      }

      // top_holdings 파싱 (list[str] 또는 list[dict])
      final holdings = _parseHoldings(d['top_holdings']);

      return EtfInfo(
        ticker: d['ticker'] as String? ?? ticker,
        name: d['name'] as String? ?? '',
        nameKr: d['name_kr'] as String? ?? d['name'] as String? ?? '',
        category: d['category'] as String? ?? '',
        expenseRatio: (d['expense_ratio'] as num?)?.toDouble() ?? 0.0,
        description: d['description'] as String? ?? '',
        topHoldings: holdings,
        currentPrice: price,
        changePct: changePct,
        changeAmount: changeAmt,
      );
    } catch (e) {
      if (kDebugMode) print('[MyEtfProvider] ETF 상세 조회 실패 ($ticker): $e');
      return _mockEtfMap[ticker.toUpperCase()];
    }
  }

  List<EtfHolding> _parseHoldings(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((h) {
        if (h is Map<String, dynamic>) {
          return EtfHolding(
            name: h['name'] as String? ?? '',
            ticker: h['ticker'] as String? ?? '',
            weight: (h['weight'] as num?)?.toDouble() ?? 0.0,
          );
        }
        // 단순 문자열 (e.g. "AAPL 8.9%")
        return EtfHolding(name: h.toString(), ticker: '', weight: 0.0);
      }).toList();
    }
    return [];
  }

  /// ETF 추가.
  Future<void> addEtf(String ticker) async {
    final upper = ticker.toUpperCase();
    if (state.registeredEtfs.any((e) => e.ticker == upper)) return;

    try {
      // 백엔드에 등록
      await ApiClient.instance.post('/api/v1/etf/register', data: {
        'device_id': _deviceId,
        'tickers': [upper],
      });
    } catch (e) {
      if (kDebugMode) print('[MyEtfProvider] 등록 API 실패: $e');
    }

    // ETF 상세 가져오기
    final etf = await _fetchEtfDetail(upper);
    if (etf == null) return;

    final updated = [...state.registeredEtfs, etf];
    state = state.copyWith(registeredEtfs: updated);

    // 로컬 저장
    final box = Hive.box('settings');
    await box.put('registered_etfs', updated.map((e) => e.ticker).toList());
  }

  /// ETF 제거.
  Future<void> removeEtf(String ticker) async {
    final updated =
        state.registeredEtfs.where((e) => e.ticker != ticker).toList();
    state = state.copyWith(registeredEtfs: updated);

    // 로컬 저장
    final box = Hive.box('settings');
    await box.put('registered_etfs', updated.map((e) => e.ticker).toList());
  }

  /// ETF 검색 — API 호출.
  Future<void> searchEtfs(String query) async {
    if (query.trim().isEmpty) {
      final popular = await _fetchPopular();
      state = state.copyWith(searchResults: popular, isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true);
    try {
      final response = await ApiClient.instance.get(
        '/api/v1/etf/search',
        queryParameters: {'q': query, 'limit': 20},
      );
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>).map((r) {
        final m = r as Map<String, dynamic>;
        return EtfInfo(
          ticker: m['ticker'] as String? ?? '',
          name: m['name'] as String? ?? '',
          nameKr: m['name_kr'] as String? ?? m['name'] as String? ?? '',
          category: m['category'] as String? ?? '',
          expenseRatio: 0.0,
        );
      }).toList();
      state = state.copyWith(searchResults: results, isSearching: false);
    } catch (e) {
      if (kDebugMode) print('[MyEtfProvider] 검색 실패, mock 사용: $e');
      final q = query.toUpperCase();
      final results = _allMockEtfs.where((e) {
        return e.ticker.contains(q) ||
            e.name.toUpperCase().contains(q) ||
            e.nameKr.contains(query);
      }).toList();
      state = state.copyWith(searchResults: results, isSearching: false);
    }
  }

  /// 인기 ETF 목록.
  Future<List<EtfInfo>> _fetchPopular() async {
    try {
      final response = await ApiClient.instance.get('/api/v1/etf/popular');
      final data = response.data as Map<String, dynamic>;
      return (data['etfs'] as List<dynamic>).map((r) {
        final m = r as Map<String, dynamic>;
        return EtfInfo(
          ticker: m['ticker'] as String? ?? '',
          name: m['name'] as String? ?? '',
          nameKr: m['name_kr'] as String? ?? m['name'] as String? ?? '',
          category: m['category'] as String? ?? '',
          expenseRatio: 0.0,
        );
      }).toList();
    } catch (_) {
      return _popularMock;
    }
  }

  /// 인기 ETF (동기, 캐시용).
  List<EtfInfo> get popularEtfs => _popularMock;

  /// 티커로 ETF 조회.
  EtfInfo? getEtfByTicker(String ticker) =>
      state.registeredEtfs.cast<EtfInfo?>().firstWhere(
            (e) => e?.ticker == ticker.toUpperCase(),
            orElse: () => _mockEtfMap[ticker.toUpperCase()],
          );

  /// 등록 여부 확인.
  bool isRegistered(String ticker) {
    return state.registeredEtfs.any((e) => e.ticker == ticker.toUpperCase());
  }
}

/// Provider.
final myEtfProvider = StateNotifierProvider<MyEtfNotifier, MyEtfState>((ref) {
  return MyEtfNotifier();
});

// ---------------------------------------------------------------------------
// Mock Data (fallback when API is unreachable)
// ---------------------------------------------------------------------------

const _qqq = EtfInfo(
  ticker: 'QQQ', name: 'Invesco QQQ Trust', nameKr: '인베스코 QQQ 트러스트',
  category: '대형 성장주', expenseRatio: 0.20,
  description: '나스닥 100 지수를 추종하는 대표적인 기술주 중심 ETF.',
  currentPrice: 487.52, changePct: 1.8, changeAmount: 8.62,
  topHoldings: [
    EtfHolding(name: 'Apple Inc.', ticker: 'AAPL', weight: 8.9),
    EtfHolding(name: 'Microsoft Corp.', ticker: 'MSFT', weight: 8.1),
    EtfHolding(name: 'NVIDIA Corp.', ticker: 'NVDA', weight: 7.8),
  ],
);

const _voo = EtfInfo(
  ticker: 'VOO', name: 'Vanguard S&P 500 ETF', nameKr: '뱅가드 S&P 500 ETF',
  category: '대형 혼합', expenseRatio: 0.03,
  description: 'S&P 500 지수를 추종하는 저비용 인덱스 ETF.',
  currentPrice: 523.18, changePct: 0.6, changeAmount: 3.12,
  topHoldings: [
    EtfHolding(name: 'Apple Inc.', ticker: 'AAPL', weight: 7.2),
    EtfHolding(name: 'Microsoft Corp.', ticker: 'MSFT', weight: 6.8),
    EtfHolding(name: 'NVIDIA Corp.', ticker: 'NVDA', weight: 6.1),
  ],
);

const _schd = EtfInfo(
  ticker: 'SCHD', name: 'Schwab U.S. Dividend Equity ETF', nameKr: '슈왑 미국 배당주 ETF',
  category: '배당 성장', expenseRatio: 0.06,
  description: '높은 배당 수익률과 배당 성장률을 가진 미국 대형주에 투자.',
  currentPrice: 82.45, changePct: -0.3, changeAmount: -0.25,
  topHoldings: [
    EtfHolding(name: 'Cisco Systems', ticker: 'CSCO', weight: 4.5),
    EtfHolding(name: 'Chevron Corp.', ticker: 'CVX', weight: 4.3),
    EtfHolding(name: 'Verizon Comm.', ticker: 'VZ', weight: 4.1),
  ],
);

const _tqqq = EtfInfo(
  ticker: 'TQQQ', name: 'ProShares UltraPro QQQ', nameKr: '프로셰어즈 울트라프로 QQQ',
  category: '레버리지 3x', expenseRatio: 0.86,
  description: '나스닥 100 지수의 일일 수익률을 3배로 추종.',
  currentPrice: 68.93, changePct: 5.4, changeAmount: 3.53,
);

const _soxl = EtfInfo(
  ticker: 'SOXL', name: 'Direxion Daily Semicond. Bull 3X', nameKr: '디렉시온 반도체 3배 ETF',
  category: '레버리지 3x', expenseRatio: 0.76,
  description: 'ICE 반도체 지수의 일일 수익률을 3배로 추종.',
  currentPrice: 32.17, changePct: -2.1, changeAmount: -0.69,
);

const _jepi = EtfInfo(
  ticker: 'JEPI', name: 'JPMorgan Equity Premium Income', nameKr: 'JP모건 프리미엄 인컴 ETF',
  category: '커버드콜', expenseRatio: 0.35,
  description: 'S&P 500 대형주에 투자하며 월배당을 추구하는 ETF.',
  currentPrice: 57.82, changePct: 0.2, changeAmount: 0.12,
);

// Additional mock ETFs for offline fallback search
const _spy = EtfInfo(
  ticker: 'SPY', name: 'SPDR S&P 500 ETF Trust', nameKr: 'S&P 500 추종 ETF (SPDR)',
  category: '대형주', expenseRatio: 0.09,
);
const _ivv = EtfInfo(
  ticker: 'IVV', name: 'iShares Core S&P 500 ETF', nameKr: 'S&P 500 추종 ETF (iShares)',
  category: '대형주', expenseRatio: 0.03,
);
const _vti = EtfInfo(
  ticker: 'VTI', name: 'Vanguard Total Stock Market ETF', nameKr: '미국 전체 주식시장 ETF',
  category: '대형주', expenseRatio: 0.03,
);
const _arkk = EtfInfo(
  ticker: 'ARKK', name: 'ARK Innovation ETF', nameKr: 'ARK 혁신 성장 ETF',
  category: '기술주', expenseRatio: 0.75,
);
const _tlt = EtfInfo(
  ticker: 'TLT', name: 'iShares 20+ Year Treasury Bond ETF', nameKr: '미국 장기국채 ETF',
  category: '채권', expenseRatio: 0.15,
);
const _gld = EtfInfo(
  ticker: 'GLD', name: 'SPDR Gold Shares', nameKr: '금 현물 ETF',
  category: '원자재', expenseRatio: 0.40,
);
const _xle = EtfInfo(
  ticker: 'XLE', name: 'Energy Select Sector SPDR Fund', nameKr: '에너지 섹터 ETF',
  category: '에너지', expenseRatio: 0.09,
);
const _soxx = EtfInfo(
  ticker: 'SOXX', name: 'iShares Semiconductor ETF', nameKr: '반도체 섹터 ETF',
  category: '반도체', expenseRatio: 0.35,
);
const _smh = EtfInfo(
  ticker: 'SMH', name: 'VanEck Semiconductor ETF', nameKr: '반도체 섹터 ETF (VanEck)',
  category: '반도체', expenseRatio: 0.35,
);
const _jepq = EtfInfo(
  ticker: 'JEPQ', name: 'JPMorgan Nasdaq Equity Premium Income', nameKr: '나스닥 커버드콜 ETF',
  category: '배당', expenseRatio: 0.35,
);
const _ibit = EtfInfo(
  ticker: 'IBIT', name: 'iShares Bitcoin Trust ETF', nameKr: '비트코인 현물 ETF',
  category: '암호화폐', expenseRatio: 0.25,
);
const _xlk = EtfInfo(
  ticker: 'XLK', name: 'Technology Select Sector SPDR Fund', nameKr: '기술 섹터 ETF',
  category: '기술주', expenseRatio: 0.09,
);
const _kweb = EtfInfo(
  ticker: 'KWEB', name: 'KraneShares CSI China Internet ETF', nameKr: '중국 인터넷 ETF',
  category: '중국', expenseRatio: 0.69,
);
const _dia = EtfInfo(
  ticker: 'DIA', name: 'SPDR Dow Jones Industrial Average ETF', nameKr: '다우존스 30 추종 ETF',
  category: '대형주', expenseRatio: 0.16,
);

final Map<String, EtfInfo> _mockEtfMap = {
  'QQQ': _qqq, 'VOO': _voo, 'SCHD': _schd,
  'TQQQ': _tqqq, 'SOXL': _soxl, 'JEPI': _jepi,
  'SPY': _spy, 'IVV': _ivv, 'VTI': _vti, 'ARKK': _arkk,
  'TLT': _tlt, 'GLD': _gld, 'XLE': _xle, 'SOXX': _soxx,
  'SMH': _smh, 'JEPQ': _jepq, 'IBIT': _ibit, 'XLK': _xlk,
  'KWEB': _kweb, 'DIA': _dia,
};

final List<EtfInfo> _allMockEtfs = _mockEtfMap.values.toList();

final List<EtfInfo> _popularMock = [_qqq, _voo, _schd, _tqqq, _soxl, _jepi, _spy, _soxx, _jepq, _ibit];
