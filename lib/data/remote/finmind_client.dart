import 'dart:math' show Random;

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/lru_cache.dart';
import 'package:afterclose/data/models/finmind/models.dart';
export 'package:afterclose/data/models/finmind/models.dart';

/// FinMind API 客戶端（台股市場資料）
///
/// 流量限制:
/// - 匿名: 300 次/小時
/// - 有 token: 600 次/小時
///
/// 每位使用者應自行註冊並使用個人 token。
class FinMindClient {
  FinMindClient({
    Dio? dio,
    String? token,
    int maxRetries = 3,
    Duration baseDelay = const Duration(
      milliseconds: ApiConfig.finmindBaseDelayMs,
    ),
    Duration cacheTtl = const Duration(minutes: 30),
  }) : _dio = dio ?? _createDio(),
       _token = token,
       _maxRetries = maxRetries,
       _baseDelay = baseDelay,
       _cacheTtl = cacheTtl;

  static const String baseUrl = 'https://api.finmindtrade.com/api/v4/data';

  /// Token 最小有效長度
  static const int _minTokenLength = 20;

  /// Token 格式正規表達式（支援 JWT 格式：英數字、底線、連字號、句點）
  static final RegExp _tokenPattern = RegExp(r'^[a-zA-Z0-9_.\-]+$');

  final Dio _dio;
  final int _maxRetries;
  final Duration _baseDelay;
  final Duration _cacheTtl;
  final Random _random = Random();

  /// API response 快取
  ///
  /// 盤後資料不常變動，快取可大幅減少 API 呼叫次數。
  /// TTL 由使用者設定決定（預設 30 分鐘）。
  late final LruCache<String, List<Map<String, dynamic>>> _responseCache =
      LruCache(maxSize: 200, ttl: _cacheTtl);

  /// 使用者的 FinMind API token（選用但建議設定）
  String? _token;

  /// 取得目前的 token
  String? get token => _token;

  /// 設定 token（含驗證）
  ///
  /// 若 token 格式無效則拋出 [InvalidTokenException]
  set token(String? value) {
    if (value != null && value.isNotEmpty) {
      _validateToken(value);
    }
    _token = value;
  }

  /// 驗證 token 格式
  ///
  /// 驗證失敗時拋出 [InvalidTokenException]
  static void _validateToken(String token) {
    if (token.length < _minTokenLength) {
      // 使用硬編碼值以允許 const 建構式
      throw const InvalidTokenException(
        'Token too short (minimum 20 characters)',
      );
    }
    if (!_tokenPattern.hasMatch(token)) {
      throw const InvalidTokenException('Token contains invalid characters');
    }
  }

  /// 驗證 token 格式但不設定
  ///
  /// 有效回傳 true，無效回傳 false
  static bool isValidTokenFormat(String? token) {
    if (token == null || token.isEmpty) return false;
    if (token.length < _minTokenLength) return false;
    return _tokenPattern.hasMatch(token);
  }

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(
          seconds: ApiConfig.finmindConnectTimeoutSec,
        ),
        receiveTimeout: const Duration(
          seconds: ApiConfig.finmindReceiveTimeoutSec,
        ),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// 建立查詢參數（含選用的 token）
  Map<String, dynamic> _buildParams(Map<String, dynamic> params) {
    final result = Map<String, dynamic>.from(params);
    if (_token?.isNotEmpty ?? false) {
      result['token'] = _token;
    }
    return result;
  }

  /// 產生快取鍵（依參數鍵排序以確保一致性）
  String _cacheKey(Map<String, dynamic> params) {
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => '${e.key}=${e.value}').join('&');
  }

  // 建立請求標籤供日誌使用
  String _buildRequestLabel(Map<String, dynamic> params) {
    final dataset = params['dataset']?.toString() ?? '';
    final stockId =
        params['data_id']?.toString() ?? params['stock_id']?.toString() ?? '';
    return stockId.isNotEmpty ? '$dataset($stockId)' : dataset;
  }

  // 快取查詢（回傳複本，避免呼叫端修改快取內容）
  List<Map<String, dynamic>>? _checkCache(
    Map<String, dynamic> params,
    String label,
  ) {
    final cacheKey = _cacheKey(params);
    final cached = _responseCache.get(cacheKey);
    if (cached != null) {
      AppLogger.debug('FinMind', '$label: cache hit (${cached.length} 筆)');
      return List<Map<String, dynamic>>.from(cached);
    }
    return null;
  }

  /// 處理 HTTP 200 回應：檢查 API 錯誤、快取結果、回傳資料
  List<Map<String, dynamic>> _handleSuccessResponse(
    Response<dynamic> response,
    Map<String, dynamic> params,
    String label,
  ) {
    final data = response.data;

    // 檢查 API 錯誤回應
    if (data['status'] != null && data['status'] != 200) {
      final msg = data['msg'] ?? 'Unknown API error';
      final msgStr = msg.toString();

      // 流量限制檢查
      if (msgStr.contains('limit') || msgStr.contains('quota')) {
        AppLogger.warning('FinMind', '$label: 流量限制');
        throw const RateLimitException();
      }

      // 付費功能檢查 (批次 API 需要贊助者)
      if (msgStr.contains('level is free') || msgStr.contains('Sponsor')) {
        AppLogger.debug('FinMind', '$label: 此功能需要付費會員 (贊助者)');
        throw const ApiException('批次 API 需要付費會員資格', 400);
      }

      AppLogger.warning('FinMind', '$label: $msgStr');
      throw ApiException(msgStr, data['status'] as int?);
    }

    // 回傳資料陣列
    final cacheKey = _cacheKey(params);
    final dataList = data['data'];
    if (dataList is List) {
      final result = dataList.cast<Map<String, dynamic>>();
      _responseCache.put(cacheKey, List.unmodifiable(result));
      AppLogger.debug('FinMind', '$label: ${result.length} 筆');
      return result;
    }
    // 空結果也快取，避免重複對同一參數請求 API
    _responseCache.put(cacheKey, const []);
    AppLogger.debug('FinMind', '$label: 0 筆');
    return [];
  }

  /// 將 DioException 轉換為適當的應用例外（總是拋出，不回傳）
  Never _handleDioException(DioException e, String label, int attempt) {
    // 轉換為適當的例外
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      AppLogger.warning('FinMind', '$label: 連線逾時 (重試 $attempt 次)');
      throw NetworkException('Connection timeout after $attempt attempts', e);
    }
    if (e.response?.statusCode == 429) {
      // 以較長退避時間重試流量限制錯誤（有限次數重試）
      AppLogger.warning('FinMind', '$label: 429 流量限制，等待重試');
      throw const RateLimitException();
    }
    if (e.response?.statusCode == 402) {
      // 402 Payment Required = API 額度耗盡，不重試直接拋出
      AppLogger.warning('FinMind', '$label: 402 API 額度耗盡');
      throw const RateLimitException('API 額度已用完，請稍後再試');
    }
    AppLogger.warning('FinMind', '$label: ${e.message ?? "網路錯誤"}');
    throw NetworkException(e.message ?? 'Network error', e);
  }

  /// 通用請求處理器（含錯誤對應和重試邏輯）
  Future<List<Map<String, dynamic>>> _request(
    Map<String, dynamic> params,
  ) async {
    final label = _buildRequestLabel(params);

    final cached = _checkCache(params, label);
    if (cached != null) return cached;

    int attempt = 0;
    Object? lastError;

    while (attempt <= _maxRetries) {
      try {
        final response = await _dio.get(
          '',
          queryParameters: _buildParams(params),
        );

        if (response.statusCode == 200) {
          return _handleSuccessResponse(response, params, label);
        }

        // 伺服器錯誤 (5xx) 可重試
        if (response.statusCode != null && response.statusCode! >= 500) {
          lastError = ApiException(
            'Server error: ${response.statusCode}',
            response.statusCode,
          );
          attempt++;
          if (attempt <= _maxRetries) {
            await _delay(attempt);
            continue;
          }
        }

        throw ApiException(
          'Request failed with status: ${response.statusCode}',
          response.statusCode,
        );
      } on DioException catch (e) {
        lastError = e;

        // 檢查此錯誤是否可重試
        if (_isRetryable(e)) {
          attempt++;
          if (attempt <= _maxRetries) {
            await _delay(attempt);
            continue;
          }
        }

        _handleDioException(e, label, attempt);
      } on RateLimitException {
        // 巢狀呼叫的流量限制 - 達到最大重試次數後仍重新拋出
        rethrow;
      } on ApiException catch (e) {
        // 不重試客戶端錯誤（流量限制除外，已在上方處理）
        if (e.statusCode != null &&
            e.statusCode! >= 400 &&
            e.statusCode! < 500) {
          rethrow;
        }
        lastError = e;
        attempt++;
        if (attempt <= _maxRetries) {
          await _delay(attempt);
          continue;
        }
        rethrow;
      }
    }

    // 所有重試次數已用盡
    if (lastError is Exception) {
      throw lastError;
    }
    throw NetworkException('Request failed after $_maxRetries retries');
  }

  /// 檢查 DioException 是否可重試
  bool _isRetryable(DioException e) {
    // 網路相關錯誤可重試
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        // 伺服器錯誤 (5xx) 重試，客戶端錯誤 (4xx) 不重試
        final statusCode = e.response?.statusCode;
        if (statusCode != null && statusCode >= 500) {
          return true;
        }
        // 429 (流量限制) 以退避方式重試
        if (statusCode == 429) {
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  /// 計算指數退避延遲（含抖動）
  ///
  /// 當 [isRateLimit] 為 true 時，使用 4 倍基礎延遲
  Future<void> _delay(int attempt, {bool isRateLimit = false}) async {
    // 流量限制錯誤使用 4 倍基礎延遲（給 API 更多重置時間）
    final baseMs = isRateLimit
        ? _baseDelay.inMilliseconds * 4
        : _baseDelay.inMilliseconds;
    // 指數退避: baseDelay * 2^(attempt-1)
    final exponentialDelay = baseMs * (1 << (attempt - 1));
    // 加入抖動: ±25% 延遲
    final jitter = (_random.nextDouble() - 0.5) * 0.5 * exponentialDelay;
    final totalDelay = Duration(
      milliseconds: (exponentialDelay + jitter).round(),
    );
    await Future.delayed(totalDelay);
  }

  /// 取得台股股票清單
  ///
  /// 資料集: TaiwanStockInfo
  /// 註: 格式錯誤的記錄會被靜默跳過
  Future<List<FinMindStockInfo>> getStockList() async {
    final data = await _request({'dataset': 'TaiwanStockInfo'});

    // 使用 tryFromJson 跳過格式錯誤的記錄
    return data
        .map((json) => FinMindStockInfo.tryFromJson(json))
        .whereType<FinMindStockInfo>()
        .toList();
  }

  /// 取得每日股價
  ///
  /// 資料集: TaiwanStockPrice
  /// [stockId]: 股票代碼（例如 "2330"）
  /// [startDate]: 起始日期（YYYY-MM-DD）
  /// [endDate]: 結束日期（選用）
  Future<List<FinMindDailyPrice>> getDailyPrices({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockPrice',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    // 使用 tryFromJson 跳過格式錯誤的記錄
    return data
        .map((json) => FinMindDailyPrice.tryFromJson(json))
        .whereType<FinMindDailyPrice>()
        .toList();
  }

  /// 取得日期範圍內所有股票價格（批次）
  ///
  /// 用於高效批量擷取
  /// 註: 格式錯誤的記錄會被靜默跳過
  Future<List<FinMindDailyPrice>> getAllDailyPrices({
    required String startDate,
    String? endDate,
  }) async {
    final params = {'dataset': 'TaiwanStockPrice', 'start_date': startDate};

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    // 使用 tryFromJson 跳過格式錯誤的記錄
    return data
        .map((json) => FinMindDailyPrice.tryFromJson(json))
        .whereType<FinMindDailyPrice>()
        .toList();
  }

  /// 取得三大法人買賣超資料
  ///
  /// 資料集: TaiwanStockInstitutionalInvestorsBuySell
  /// 註: API 每種法人類型回傳一列，此方法依日期彙整
  Future<List<FinMindInstitutional>> getInstitutionalData({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockInstitutionalInvestorsBuySell',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);

    // 解析原始資料列
    final rows = data
        .map((json) {
          try {
            return FinMindInstitutionalRow.fromJson(json);
          } catch (e) {
            AppLogger.debug(
              'FinMindClient',
              '解析法人資料列失敗: ${json['stock_id']} ($e)',
            );
            return null;
          }
        })
        .whereType<FinMindInstitutionalRow>()
        .toList();

    // 依日期分組並彙整
    final Map<String, List<FinMindInstitutionalRow>> byDate = {};
    for (final row in rows) {
      if (row.date.isEmpty) continue;
      byDate.putIfAbsent(row.date, () => []).add(row);
    }

    // 轉換為彙整記錄
    return byDate.entries
        .map((entry) {
          try {
            return FinMindInstitutional.aggregate(entry.value);
          } catch (e) {
            AppLogger.debug('FinMindClient', '彙整法人資料失敗: ${entry.key} ($e)');
            return null;
          }
        })
        .whereType<FinMindInstitutional>()
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// 取得融資融券資料
  ///
  /// 資料集: TaiwanStockMarginPurchaseShortSale
  Future<List<FinMindMarginData>> getMarginData({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockMarginPurchaseShortSale',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    // 使用 tryFromJson 跳過格式錯誤的記錄
    return data
        .map((json) => FinMindMarginData.tryFromJson(json))
        .whereType<FinMindMarginData>()
        .toList();
  }

  /// 取得月營收資料
  ///
  /// 資料集: TaiwanStockMonthRevenue
  Future<List<FinMindRevenue>> getMonthlyRevenue({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockMonthRevenue',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindRevenue.tryFromJson(json))
        .whereType<FinMindRevenue>()
        .toList();
  }

  /// 取得日期範圍內所有股票月營收（批次）
  ///
  /// 用於高效批量擷取，省略 data_id 取得全市場資料。
  /// 一次 API 呼叫可取得所有股票的營收資料。
  Future<List<FinMindRevenue>> getAllMonthlyRevenue({
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockMonthRevenue',
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindRevenue.tryFromJson(json))
        .whereType<FinMindRevenue>()
        .toList();
  }

  /// 取得股利資料
  ///
  /// 資料集: TaiwanStockDividend
  Future<List<FinMindDividend>> getDividends({
    required String stockId,
    String? startDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockDividend',
      'data_id': stockId,
      // 未指定時預設為 5 年前
      'start_date': startDate ?? '${DateTime.now().year - 5}-01-01',
    };

    final data = await _request(params);
    return data
        .map((json) => FinMindDividend.tryFromJson(json))
        .whereType<FinMindDividend>()
        .toList();
  }

  /// 取得本益比/股價淨值比資料
  ///
  /// 資料集: TaiwanStockPER
  Future<List<FinMindPER>> getPERData({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockPER',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindPER.tryFromJson(json))
        .whereType<FinMindPER>()
        .toList();
  }

  /// 檢查是否已設定 token
  bool get hasToken => _token?.isNotEmpty ?? false;

  /// 檢查 token 是否已設定且有效
  bool get hasValidToken => hasToken && isValidTokenFormat(_token);

  // ============================================
  // 階段 1: 新增 API 方法（8 個資料集）
  // ============================================

  /// 取得外資持股比例資料
  ///
  /// 資料集: TaiwanStockShareholding
  /// 回傳: 外資持股比例歷史資料
  Future<List<FinMindShareholding>> getShareholding({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockShareholding',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindShareholding.tryFromJson(json))
        .whereType<FinMindShareholding>()
        .toList();
  }

  /// 取得股權分散表資料
  ///
  /// 資料集: TaiwanStockHoldingSharesPer
  /// 回傳: 依持股比例分布的股東資料
  ///
  /// 注意: 此 API 需要付費會員（贊助者）。
  /// 免費使用者會收到 400 Bad Request 錯誤。
  Future<List<FinMindHoldingSharesPer>> getHoldingSharesPer({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockHoldingSharesPer',
      'stock_id': stockId, // 此 API 使用 stock_id 而非 data_id
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindHoldingSharesPer.tryFromJson(json))
        .whereType<FinMindHoldingSharesPer>()
        .toList();
  }

  /// 取得當沖比例資料
  ///
  /// 資料集: TaiwanStockDayTrading
  /// 回傳: 當沖量及當沖比例
  Future<List<FinMindDayTrading>> getDayTrading({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockDayTrading',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindDayTrading.tryFromJson(json))
        .whereType<FinMindDayTrading>()
        .toList();
  }

  /// 取得綜合損益表資料
  ///
  /// 資料集: TaiwanStockFinancialStatements
  /// 回傳: 按季度的損益表資料
  Future<List<FinMindFinancialStatement>> getFinancialStatements({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockFinancialStatements',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindFinancialStatement.tryFromJson(json))
        .whereType<FinMindFinancialStatement>()
        .toList();
  }

  /// 取得資產負債表資料
  ///
  /// 資料集: TaiwanStockBalanceSheet
  /// 回傳: 按季度的資產負債表資料
  Future<List<FinMindBalanceSheet>> getBalanceSheet({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockBalanceSheet',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindBalanceSheet.tryFromJson(json))
        .whereType<FinMindBalanceSheet>()
        .toList();
  }

  /// 取得現金流量表資料
  ///
  /// 資料集: TaiwanStockCashFlowsStatement
  /// 回傳: 按季度的現金流量資料
  Future<List<FinMindCashFlowStatement>> getCashFlowsStatement({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockCashFlowsStatement',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindCashFlowStatement.tryFromJson(json))
        .whereType<FinMindCashFlowStatement>()
        .toList();
  }

  /// 取得還原股價資料
  ///
  /// 資料集: TaiwanStockPriceAdj
  /// 回傳: 經除權息調整的股價
  Future<List<FinMindAdjustedPrice>> getAdjustedPrices({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockPriceAdj',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindAdjustedPrice.tryFromJson(json))
        .whereType<FinMindAdjustedPrice>()
        .toList();
  }

  /// 取得週 K 線資料
  ///
  /// 資料集: TaiwanStockWeekPrice
  /// 回傳: 週 OHLCV 資料
  Future<List<FinMindWeeklyPrice>> getWeeklyPrices({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockWeekPrice',
      'data_id': stockId,
      'start_date': startDate,
    };

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    return data
        .map((json) => FinMindWeeklyPrice.tryFromJson(json))
        .whereType<FinMindWeeklyPrice>()
        .toList();
  }
}
