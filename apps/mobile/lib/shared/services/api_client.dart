import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';

/// Singleton Dio-based API client.
///
/// Auto-adds `X-Device-ID` header, 15s connect / 30s receive timeout, JSON content-type.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  String? _deviceId;

  /// Must be called once at app startup after [AppConfig.initialize].
  void init({required String deviceId}) {
    _deviceId = deviceId;

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_deviceId != null) {
            options.headers['X-Device-ID'] = _deviceId;
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            print('[ApiClient] ERROR ${error.requestOptions.method} '
                '${error.requestOptions.path} → ${error.message}');
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// The current device ID.
  String? get deviceId => _deviceId;

  /// Direct access to the Dio instance for custom calls.
  Dio get dio => _dio;

  /// Convenience GET.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  /// Convenience POST.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.post<T>(path, data: data);
  }

  /// ETF 구성종목(holdings) 조회.
  Future<Map<String, dynamic>> getHoldings(String ticker) async {
    final response = await _dio.get('/api/v1/etf/$ticker/holdings');
    return response.data as Map<String, dynamic>;
  }

  /// 기업 티커로 해당 기업이 포함된 ETF 검색.
  Future<Map<String, dynamic>> searchByCompany(String companyTicker) async {
    final response = await _dio.get(
      '/api/v1/holdings/search',
      queryParameters: {'company': companyTicker},
    );
    return response.data as Map<String, dynamic>;
  }

  /// ETF 분석 데이터 조회 (섹터 집중도, 매크로 민감도, 비교 ETF 등).
  Future<Map<String, dynamic>> getEtfAnalysis(String ticker) async {
    final response = await _dio.get('/api/v1/etf/$ticker/analysis');
    return response.data as Map<String, dynamic>;
  }

  /// ETF 비교 데이터 조회.
  Future<Map<String, dynamic>> compareEtfs(List<String> tickers) async {
    final response = await _dio.get(
      '/api/v1/etf/compare',
      queryParameters: {'tickers': tickers.join(',')},
    );
    return response.data as Map<String, dynamic>;
  }

  /// ETF 구성종목 변화 조회 (주간 변동).
  Future<Map<String, dynamic>> getHoldingsChanges(String ticker) async {
    final response = await _dio.get('/api/v1/etf/$ticker/holdings-changes');
    return response.data as Map<String, dynamic>;
  }

  /// ETF 섹터 집중도 조회.
  Future<Map<String, dynamic>> getSectorConcentration(String ticker) async {
    final response =
        await _dio.get('/api/v1/etf/$ticker/sector-concentration');
    return response.data as Map<String, dynamic>;
  }

  /// ETF 거시 민감도 조회.
  Future<Map<String, dynamic>> getMacroSensitivity(String ticker) async {
    final response = await _dio.get('/api/v1/etf/$ticker/macro-sensitivity');
    return response.data as Map<String, dynamic>;
  }

  /// ETF 동일 테마 비교 조회.
  Future<Map<String, dynamic>> getComparison(String ticker) async {
    final response = await _dio.get('/api/v1/etf/$ticker/comparison');
    return response.data as Map<String, dynamic>;
  }
}
