import 'dart:math' show Random;

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/json_parsers.dart';
import 'package:afterclose/core/utils/logger.dart';

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
  }) : _dio = dio ?? _createDio(),
       _token = token,
       _maxRetries = maxRetries,
       _baseDelay = baseDelay;

  static const String baseUrl = 'https://api.finmindtrade.com/api/v4/data';

  /// Token 最小有效長度
  static const int _minTokenLength = 20;

  /// Token 格式正規表達式（支援 JWT 格式：英數字、底線、連字號、句點）
  static final RegExp _tokenPattern = RegExp(r'^[a-zA-Z0-9_.\-]+$');

  final Dio _dio;
  final int _maxRetries;
  final Duration _baseDelay;
  final Random _random = Random();

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

  /// 通用請求處理器（含錯誤對應和重試邏輯）
  Future<List<Map<String, dynamic>>> _request(
    Map<String, dynamic> params,
  ) async {
    // 建立請求標籤供日誌使用
    final dataset = params['dataset']?.toString() ?? '';
    final stockId =
        params['data_id']?.toString() ?? params['stock_id']?.toString() ?? '';
    final label = stockId.isNotEmpty ? '$dataset($stockId)' : dataset;

    int attempt = 0;
    Object? lastError;

    while (attempt <= _maxRetries) {
      try {
        final response = await _dio.get(
          '',
          queryParameters: _buildParams(params),
        );

        if (response.statusCode == 200) {
          final data = response.data;

          // 檢查 API 錯誤回應
          if (data['status'] != null && data['status'] != 200) {
            final msg = data['msg'] ?? 'Unknown API error';

            // 流量限制檢查
            if (msg.toString().contains('limit') ||
                msg.toString().contains('quota')) {
              AppLogger.warning('FinMind', '$label: 流量限制');
              throw const RateLimitException();
            }

            AppLogger.warning('FinMind', '$label: ${msg.toString()}');
            throw ApiException(msg.toString(), data['status'] as int?);
          }

          // 回傳資料陣列
          final dataList = data['data'];
          if (dataList is List) {
            final result = dataList.cast<Map<String, dynamic>>();
            AppLogger.debug('FinMind', '$label: ${result.length} 筆');
            return result;
          }
          AppLogger.debug('FinMind', '$label: 0 筆');
          return [];
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

        // 轉換為適當的例外
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          AppLogger.warning('FinMind', '$label: 連線逾時 (重試 $attempt 次)');
          throw NetworkException(
            'Connection timeout after $attempt attempts',
            e,
          );
        }
        if (e.response?.statusCode == 429) {
          // 以較長退避時間重試流量限制錯誤（有限次數重試）
          AppLogger.warning('FinMind', '$label: 429 流量限制，等待重試');
          lastError = const RateLimitException();
          attempt++;
          if (attempt <= _maxRetries) {
            await _delay(attempt, isRateLimit: true);
            continue;
          }
          throw const RateLimitException();
        }
        AppLogger.warning('FinMind', '$label: ${e.message ?? "網路錯誤"}');
        throw NetworkException(e.message ?? 'Network error', e);
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
            return _FinMindInstitutionalRow.fromJson(json);
          } catch (e) {
            AppLogger.debug(
              'FinMindClient',
              '解析法人資料列失敗: ${json['stock_id']} ($e)',
            );
            return null;
          }
        })
        .whereType<_FinMindInstitutionalRow>()
        .toList();

    // 依日期分組並彙整
    final Map<String, List<_FinMindInstitutionalRow>> byDate = {};
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

// ============================================
// 資料模型（簡單類別，無程式碼產生）
// ============================================

/// FinMind 股票資訊
class FinMindStockInfo {
  const FinMindStockInfo({
    required this.stockId,
    required this.stockName,
    required this.industryCategory,
    required this.type,
  });

  /// 從 JSON 解析（含驗證）
  ///
  /// 必要欄位缺失時拋出 [FormatException]
  factory FinMindStockInfo.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }

    return FinMindStockInfo(
      stockId: stockId.toString(),
      stockName: json['stock_name']?.toString() ?? '',
      industryCategory: json['industry_category']?.toString() ?? '',
      type: json['type']?.toString() ?? 'twse',
    );
  }

  /// 嘗試從 JSON 解析，失敗時回傳 null 並記錄日誌
  static FinMindStockInfo? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(json, FinMindStockInfo.fromJson, 'FinMindStockInfo');

  final String stockId;
  final String stockName;
  final String industryCategory;
  final String type; // "twse" 或 "tpex"

  /// 將 type 轉換為市場列舉字串
  String get market => type.toLowerCase() == 'twse' ? 'TWSE' : 'TPEx';
}

/// FinMind 每日價格資料
class FinMindDailyPrice {
  const FinMindDailyPrice({
    required this.stockId,
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// 從 JSON 解析（含驗證）
  ///
  /// 必要欄位缺失時拋出 [FormatException]
  factory FinMindDailyPrice.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    // 解析收盤價 - 分析的關鍵欄位
    final close = JsonParsers.parseDouble(json['close']);
    if (close == null) {
      throw FormatException('Missing or invalid close price', json);
    }

    return FinMindDailyPrice(
      stockId: stockId.toString(),
      date: date.toString(),
      open: JsonParsers.parseDouble(json['open']),
      high: JsonParsers.parseDouble(json['max']),
      low: JsonParsers.parseDouble(json['min']),
      close: close,
      volume: JsonParsers.parseDouble(json['Trading_Volume']),
    );
  }

  /// 嘗試從 JSON 解析，失敗時回傳 null 並記錄日誌
  static FinMindDailyPrice? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindDailyPrice.fromJson,
        'FinMindDailyPrice',
      );

  final String stockId;
  final String date; // YYYY-MM-DD
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
}

/// FinMind API 原始法人資料列
/// 註: API 每種法人類型回傳一列，需要彙整
class _FinMindInstitutionalRow {
  const _FinMindInstitutionalRow({
    required this.stockId,
    required this.date,
    required this.name,
    required this.buy,
    required this.sell,
  });

  factory _FinMindInstitutionalRow.fromJson(Map<String, dynamic> json) {
    return _FinMindInstitutionalRow(
      stockId: json['stock_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      buy: JsonParsers.parseDouble(json['buy']) ?? 0,
      sell: JsonParsers.parseDouble(json['sell']) ?? 0,
    );
  }

  final String stockId;
  final String date;
  final String name;
  final double buy;
  final double sell;
}

/// FinMind 彙整後的法人資料
class FinMindInstitutional {
  const FinMindInstitutional({
    required this.stockId,
    required this.date,
    required this.foreignBuy,
    required this.foreignSell,
    required this.investmentTrustBuy,
    required this.investmentTrustSell,
    required this.dealerBuy,
    required this.dealerSell,
  });

  /// 將多列（每種法人類型一列）彙整為單一記錄
  /// API 每個日期會為每種法人類型回傳獨立的列
  // ignore: library_private_types_in_public_api
  factory FinMindInstitutional.aggregate(List<_FinMindInstitutionalRow> rows) {
    if (rows.isEmpty) {
      throw const FormatException('Cannot aggregate empty row list');
    }

    double foreignBuy = 0, foreignSell = 0;
    double trustBuy = 0, trustSell = 0;
    double dealerBuy = 0, dealerSell = 0;

    for (final row in rows) {
      switch (row.name) {
        case 'Foreign_Investor':
        case 'Foreign_Dealer_Self':
          foreignBuy += row.buy;
          foreignSell += row.sell;
        case 'Investment_Trust':
          trustBuy += row.buy;
          trustSell += row.sell;
        case 'Dealer_self':
        case 'Dealer_Hedging':
          dealerBuy += row.buy;
          dealerSell += row.sell;
      }
    }

    return FinMindInstitutional(
      stockId: rows.first.stockId,
      date: rows.first.date,
      foreignBuy: foreignBuy,
      foreignSell: foreignSell,
      investmentTrustBuy: trustBuy,
      investmentTrustSell: trustSell,
      dealerBuy: dealerBuy,
      dealerSell: dealerSell,
    );
  }

  /// 嘗試從 JSON 解析（向後相容用，不建議使用）
  static FinMindInstitutional? tryFromJson(Map<String, dynamic> json) {
    // 這是單一列，建立只有一筆的彙整
    try {
      final row = _FinMindInstitutionalRow.fromJson(json);
      if (row.stockId.isEmpty || row.date.isEmpty) return null;
      return FinMindInstitutional.aggregate([row]);
    } catch (e) {
      AppLogger.debug('FinMindInstitutional', '解析失敗: ${json['stock_id']} ($e)');
      return null;
    }
  }

  final String stockId;
  final String date;
  final double foreignBuy;
  final double foreignSell;
  final double investmentTrustBuy;
  final double investmentTrustSell;
  final double dealerBuy;
  final double dealerSell;

  /// 外資淨買賣
  double get foreignNet => foreignBuy - foreignSell;

  /// 投信淨買賣
  double get investmentTrustNet => investmentTrustBuy - investmentTrustSell;

  /// 自營商淨買賣
  double get dealerNet => dealerBuy - dealerSell;
}

/// FinMind 融資融券資料
class FinMindMarginData {
  const FinMindMarginData({
    required this.stockId,
    required this.date,
    required this.marginBuy,
    required this.marginSell,
    required this.marginCashRepay,
    required this.marginBalance,
    required this.marginLimit,
    required this.marginUseRate,
    required this.shortBuy,
    required this.shortSell,
    required this.shortCashRepay,
    required this.shortBalance,
    required this.shortLimit,
    required this.offsetMarginShort,
    required this.note,
  });

  /// 從 JSON 解析（含驗證）
  ///
  /// 必要欄位缺失時拋出 [FormatException]
  factory FinMindMarginData.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    final marginBalance =
        JsonParsers.parseDouble(json['MarginPurchaseTodayBalance']) ?? 0;
    final marginLimit =
        JsonParsers.parseDouble(json['MarginPurchaseLimit']) ?? 0;

    return FinMindMarginData(
      stockId: stockId.toString(),
      date: date.toString(),
      marginBuy: JsonParsers.parseDouble(json['MarginPurchaseBuy']) ?? 0,
      marginSell: JsonParsers.parseDouble(json['MarginPurchaseSell']) ?? 0,
      marginCashRepay:
          JsonParsers.parseDouble(json['MarginPurchaseCashRepayment']) ?? 0,
      marginBalance: marginBalance,
      marginLimit: marginLimit,
      // 融資使用率 = 融資餘額 / 融資限額 * 100
      marginUseRate: marginLimit > 0 ? (marginBalance / marginLimit) * 100 : 0,
      shortBuy: JsonParsers.parseDouble(json['ShortSaleBuy']) ?? 0,
      shortSell: JsonParsers.parseDouble(json['ShortSaleSell']) ?? 0,
      shortCashRepay:
          JsonParsers.parseDouble(json['ShortSaleCashRepayment']) ?? 0,
      shortBalance: JsonParsers.parseDouble(json['ShortSaleTodayBalance']) ?? 0,
      shortLimit: JsonParsers.parseDouble(json['ShortSaleLimit']) ?? 0,
      offsetMarginShort:
          JsonParsers.parseDouble(json['OffsetLoanAndShort']) ?? 0,
      note: json['Note']?.toString() ?? '',
    );
  }

  /// 嘗試從 JSON 解析，失敗時回傳 null
  static FinMindMarginData? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindMarginData.fromJson,
        'FinMindMarginData',
      );

  final String stockId;
  final String date;

  // 融資 (Margin Purchase)
  final double marginBuy; // 融資買進
  final double marginSell; // 融資賣出
  final double marginCashRepay; // 現金償還
  final double marginBalance; // 融資餘額
  final double marginLimit; // 融資限額
  final double marginUseRate; // 融資使用率

  // 融券 (Short Sale)
  final double shortBuy; // 融券買進
  final double shortSell; // 融券賣出
  final double shortCashRepay; // 現券償還
  final double shortBalance; // 融券餘額
  final double shortLimit; // 融券限額
  final double offsetMarginShort; // 資券互抵

  final String note; // 備註

  /// 融資淨買超
  double get marginNet => marginBuy - marginSell - marginCashRepay;

  /// 融券淨賣超
  double get shortNet => shortSell - shortBuy - shortCashRepay;

  /// 券資比 (融券餘額 / 融資餘額 * 100)
  double get shortMarginRatio =>
      marginBalance > 0 ? (shortBalance / marginBalance) * 100 : 0;
}

/// FinMind 月營收資料
class FinMindRevenue {
  FinMindRevenue({
    required this.stockId,
    required this.date,
    required this.revenue,
    required this.revenueMonth,
    required this.revenueYear,
    this.momGrowth,
    this.yoyGrowth,
  });

  factory FinMindRevenue.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindRevenue(
      stockId: stockId.toString(),
      date: date.toString(),
      revenue: JsonParsers.parseDouble(json['revenue']) ?? 0,
      revenueMonth: JsonParsers.parseInt(json['revenue_month']) ?? 0,
      revenueYear: JsonParsers.parseInt(json['revenue_year']) ?? 0,
    );
  }

  static FinMindRevenue? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(json, FinMindRevenue.fromJson, 'FinMindRevenue');

  /// 計算營收清單的月增率及年增率
  /// 回傳已填入成長率的相同清單
  static List<FinMindRevenue> calculateGrowthRates(
    List<FinMindRevenue> revenues,
  ) {
    if (revenues.isEmpty) return revenues;

    // 依日期排序（年/月）
    final sorted = List<FinMindRevenue>.from(revenues)
      ..sort((a, b) {
        final yearCompare = a.revenueYear.compareTo(b.revenueYear);
        if (yearCompare != 0) return yearCompare;
        return a.revenueMonth.compareTo(b.revenueMonth);
      });

    // 建立查詢 Map 以快速存取
    final Map<String, FinMindRevenue> lookup = {};
    for (final rev in sorted) {
      lookup['${rev.revenueYear}-${rev.revenueMonth}'] = rev;
    }

    // 計算成長率
    for (final rev in sorted) {
      // 月增率: 與上月比較
      int prevMonth = rev.revenueMonth - 1;
      int prevYear = rev.revenueYear;
      if (prevMonth < 1) {
        prevMonth = 12;
        prevYear -= 1;
      }
      final prevMonthKey = '$prevYear-$prevMonth';
      final prevMonthRev = lookup[prevMonthKey];
      if (prevMonthRev != null && prevMonthRev.revenue > 0) {
        rev.momGrowth =
            ((rev.revenue - prevMonthRev.revenue) / prevMonthRev.revenue) * 100;
      }

      // 年增率: 與去年同月比較
      final yoyKey = '${rev.revenueYear - 1}-${rev.revenueMonth}';
      final yoyRev = lookup[yoyKey];
      if (yoyRev != null && yoyRev.revenue > 0) {
        rev.yoyGrowth = ((rev.revenue - yoyRev.revenue) / yoyRev.revenue) * 100;
      }
    }

    return sorted;
  }

  final String stockId;
  final String date;
  final double revenue; // 當月營收 (千元)
  final int revenueMonth; // 營收月份
  final int revenueYear; // 營收年份

  /// 月增率 (MoM %)
  double? momGrowth;

  /// 年增率 (YoY %)
  double? yoyGrowth;

  /// 營收 (億元)
  double get revenueInBillion => revenue / 100000;
}

/// FinMind 股利資料
class FinMindDividend {
  const FinMindDividend({
    required this.stockId,
    required this.year,
    required this.cashDividend,
    required this.stockDividend,
    this.exDividendDate,
    this.exRightsDate,
  });

  factory FinMindDividend.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }

    return FinMindDividend(
      stockId: stockId.toString(),
      year:
          JsonParsers.parseInt(json['year']) ??
          JsonParsers.parseInt(json['date']?.toString().substring(0, 4)) ??
          0,
      cashDividend:
          JsonParsers.parseDouble(json['CashEarningsDistribution']) ?? 0,
      stockDividend:
          JsonParsers.parseDouble(json['StockEarningsDistribution']) ?? 0,
      exDividendDate: json['CashExDividendTradingDate']?.toString(),
      exRightsDate: json['StockExDividendTradingDate']?.toString(),
    );
  }

  static FinMindDividend? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(json, FinMindDividend.fromJson, 'FinMindDividend');

  final String stockId;
  final int year;
  final double cashDividend; // 現金股利
  final double stockDividend; // 股票股利
  final String? exDividendDate; // 除息日
  final String? exRightsDate; // 除權日

  /// 總股利
  double get totalDividend => cashDividend + stockDividend;
}

/// FinMind 本益比/股價淨值比資料
class FinMindPER {
  const FinMindPER({
    required this.stockId,
    required this.date,
    required this.per,
    required this.pbr,
    required this.dividendYield,
  });

  factory FinMindPER.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindPER(
      stockId: stockId.toString(),
      date: date.toString(),
      per: JsonParsers.parseDouble(json['PER']) ?? 0,
      pbr: JsonParsers.parseDouble(json['PBR']) ?? 0,
      dividendYield: JsonParsers.parseDouble(json['dividend_yield']) ?? 0,
    );
  }

  static FinMindPER? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(json, FinMindPER.fromJson, 'FinMindPER');

  final String stockId;
  final String date;
  final double per; // 本益比
  final double pbr; // 股價淨值比
  final double dividendYield; // 殖利率
}

// ============================================
// 階段 1: 新增資料模型（8 個資料集）
// ============================================

/// FinMind 外資持股比例資料
class FinMindShareholding {
  const FinMindShareholding({
    required this.stockId,
    required this.date,
    required this.foreignInvestmentRemainingShares,
    required this.foreignInvestmentSharesRatio,
    required this.foreignInvestmentUpperLimitRatio,
    required this.chineseInvestmentUpperLimitRatio,
    required this.numberOfSharesIssued,
    required this.recentlyDeclareDate,
    required this.note,
  });

  factory FinMindShareholding.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindShareholding(
      stockId: stockId.toString(),
      date: date.toString(),
      foreignInvestmentRemainingShares:
          JsonParsers.parseDouble(json['ForeignInvestmentRemainingShares']) ??
          0,
      foreignInvestmentSharesRatio:
          JsonParsers.parseDouble(json['ForeignInvestmentSharesRatio']) ?? 0,
      foreignInvestmentUpperLimitRatio:
          JsonParsers.parseDouble(json['ForeignInvestmentUpperLimitRatio']) ??
          0,
      chineseInvestmentUpperLimitRatio:
          JsonParsers.parseDouble(json['ChineseInvestmentUpperLimitRatio']) ??
          0,
      numberOfSharesIssued:
          JsonParsers.parseDouble(json['NumberOfSharesIssued']) ?? 0,
      recentlyDeclareDate: json['RecentlyDeclareDate']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }

  static FinMindShareholding? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindShareholding.fromJson,
        'FinMindShareholding',
      );

  final String stockId;
  final String date;
  final double foreignInvestmentRemainingShares; // 外資持股餘額(股)
  final double foreignInvestmentSharesRatio; // 外資持股比例(%)
  final double foreignInvestmentUpperLimitRatio; // 外資持股上限比例(%)
  final double chineseInvestmentUpperLimitRatio; // 陸資持股上限比例(%)
  final double numberOfSharesIssued; // 已發行股數
  final String recentlyDeclareDate; // 最近申報日
  final String note; // 備註

  /// 外資可加碼空間 (上限 - 現有持股)
  double get foreignInvestmentRoom =>
      foreignInvestmentUpperLimitRatio - foreignInvestmentSharesRatio;
}

/// FinMind 股權分散表資料
class FinMindHoldingSharesPer {
  const FinMindHoldingSharesPer({
    required this.stockId,
    required this.date,
    required this.holdingSharesLevel,
    required this.people,
    required this.percent,
    required this.unit,
  });

  factory FinMindHoldingSharesPer.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindHoldingSharesPer(
      stockId: stockId.toString(),
      date: date.toString(),
      holdingSharesLevel: json['HoldingSharesLevel']?.toString() ?? '',
      people: JsonParsers.parseInt(json['people']) ?? 0,
      percent: JsonParsers.parseDouble(json['percent']) ?? 0,
      unit: JsonParsers.parseDouble(json['unit']) ?? 0,
    );
  }

  static FinMindHoldingSharesPer? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindHoldingSharesPer.fromJson,
        'FinMindHoldingSharesPer',
      );

  final String stockId;
  final String date;
  final String holdingSharesLevel; // 持股分級 (e.g., "1-999", "1000-5000")
  final int people; // 股東人數
  final double percent; // 占集保庫存數比例(%)
  final double unit; // 股數
}

/// FinMind 當沖比例資料
class FinMindDayTrading {
  const FinMindDayTrading({
    required this.stockId,
    required this.date,
    required this.buyDayTradingVolume,
    required this.sellDayTradingVolume,
    required this.dayTradingVolume,
    required this.dayTradingRatio,
    required this.tradeVolume,
  });

  factory FinMindDayTrading.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    final buyVolume = JsonParsers.parseDouble(json['BuyDayTradingVolume']) ?? 0;
    final sellVolume =
        JsonParsers.parseDouble(json['SellDayTradingVolume']) ?? 0;
    final tradeVolume = JsonParsers.parseDouble(json['tradeVolume']) ?? 0;
    final dayTradingVolume = (buyVolume + sellVolume) / 2;

    return FinMindDayTrading(
      stockId: stockId.toString(),
      date: date.toString(),
      buyDayTradingVolume: buyVolume,
      sellDayTradingVolume: sellVolume,
      dayTradingVolume: dayTradingVolume,
      dayTradingRatio: tradeVolume > 0
          ? (dayTradingVolume / tradeVolume) * 100
          : 0,
      tradeVolume: tradeVolume,
    );
  }

  static FinMindDayTrading? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindDayTrading.fromJson,
        'FinMindDayTrading',
      );

  final String stockId;
  final String date;
  final double buyDayTradingVolume; // 當沖買進成交量
  final double sellDayTradingVolume; // 當沖賣出成交量
  final double dayTradingVolume; // 當沖量 (平均)
  final double dayTradingRatio; // 當沖比例(%)
  final double tradeVolume; // 總成交量

  /// 是否為高當沖比例 (>30%)
  bool get isHighDayTrading => dayTradingRatio > 30;

  /// 是否為極高當沖比例 (>40%)
  bool get isExtremelyHighDayTrading => dayTradingRatio > 40;
}

/// FinMind 綜合損益表資料
/// 註: 財務報表以 type/value 配對呈現，這是簡化版本
class FinMindFinancialStatement {
  const FinMindFinancialStatement({
    required this.stockId,
    required this.date,
    required this.type,
    required this.value,
    required this.origin,
  });

  factory FinMindFinancialStatement.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindFinancialStatement(
      stockId: stockId.toString(),
      date: date.toString(),
      type: json['type']?.toString() ?? '',
      value: JsonParsers.parseDouble(json['value']) ?? 0,
      origin: json['origin_name']?.toString() ?? '',
    );
  }

  static FinMindFinancialStatement? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindFinancialStatement.fromJson,
        'FinMindFinancialStatement',
      );

  final String stockId;
  final String date; // YYYY-QQ format (e.g., "2024-Q1")
  final String type; // 項目名稱 (e.g., "Revenue", "NetIncome")
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// 常用損益表項目類型
  static const String typeRevenue = 'Revenue';
  static const String typeGrossProfit = 'GrossProfit';
  static const String typeOperatingIncome = 'OperatingIncome';
  static const String typeNetIncome = 'NetIncome';
  static const String typeEPS = 'EPS';
}

/// FinMind 資產負債表資料
class FinMindBalanceSheet {
  const FinMindBalanceSheet({
    required this.stockId,
    required this.date,
    required this.type,
    required this.value,
    required this.origin,
  });

  factory FinMindBalanceSheet.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindBalanceSheet(
      stockId: stockId.toString(),
      date: date.toString(),
      type: json['type']?.toString() ?? '',
      value: JsonParsers.parseDouble(json['value']) ?? 0,
      origin: json['origin_name']?.toString() ?? '',
    );
  }

  static FinMindBalanceSheet? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindBalanceSheet.fromJson,
        'FinMindBalanceSheet',
      );

  final String stockId;
  final String date;
  final String type; // 項目名稱 (e.g., "TotalAssets", "TotalLiabilities")
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// 常用資產負債表項目類型
  static const String typeTotalAssets = 'TotalAssets';
  static const String typeTotalLiabilities = 'TotalLiabilities';
  static const String typeEquity = 'Equity';
  static const String typeCurrentAssets = 'CurrentAssets';
  static const String typeCurrentLiabilities = 'CurrentLiabilities';
  static const String typeCash = 'CashAndCashEquivalents';
}

/// FinMind 現金流量表資料
class FinMindCashFlowStatement {
  const FinMindCashFlowStatement({
    required this.stockId,
    required this.date,
    required this.type,
    required this.value,
    required this.origin,
  });

  factory FinMindCashFlowStatement.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindCashFlowStatement(
      stockId: stockId.toString(),
      date: date.toString(),
      type: json['type']?.toString() ?? '',
      value: JsonParsers.parseDouble(json['value']) ?? 0,
      origin: json['origin_name']?.toString() ?? '',
    );
  }

  static FinMindCashFlowStatement? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindCashFlowStatement.fromJson,
        'FinMindCashFlowStatement',
      );

  final String stockId;
  final String date;
  final String type; // 項目名稱
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// 常用現金流量項目類型
  static const String typeOperatingCashFlow =
      'CashFlowsFromOperatingActivities';
  static const String typeInvestingCashFlow =
      'CashFlowsFromInvestingActivities';
  static const String typeFinancingCashFlow =
      'CashFlowsFromFinancingActivities';
  static const String typeFreeCashFlow = 'FreeCashFlow';
}

/// FinMind 還原股價資料
class FinMindAdjustedPrice {
  const FinMindAdjustedPrice({
    required this.stockId,
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory FinMindAdjustedPrice.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindAdjustedPrice(
      stockId: stockId.toString(),
      date: date.toString(),
      open: JsonParsers.parseDouble(json['open']),
      high: JsonParsers.parseDouble(json['max']),
      low: JsonParsers.parseDouble(json['min']),
      close: JsonParsers.parseDouble(json['close']),
      volume: JsonParsers.parseDouble(json['Trading_Volume']),
    );
  }

  static FinMindAdjustedPrice? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindAdjustedPrice.fromJson,
        'FinMindAdjustedPrice',
      );

  final String stockId;
  final String date; // YYYY-MM-DD
  final double? open; // 還原開盤價
  final double? high; // 還原最高價
  final double? low; // 還原最低價
  final double? close; // 還原收盤價
  final double? volume; // 成交量
}

/// FinMind 週 K 線資料
class FinMindWeeklyPrice {
  const FinMindWeeklyPrice({
    required this.stockId,
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory FinMindWeeklyPrice.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindWeeklyPrice(
      stockId: stockId.toString(),
      date: date.toString(),
      open: JsonParsers.parseDouble(json['open']),
      high: JsonParsers.parseDouble(json['max']),
      low: JsonParsers.parseDouble(json['min']),
      close: JsonParsers.parseDouble(json['close']),
      volume: JsonParsers.parseDouble(json['Trading_Volume']),
    );
  }

  static FinMindWeeklyPrice? tryFromJson(Map<String, dynamic> json) =>
      JsonParsers.tryParse(
        json,
        FinMindWeeklyPrice.fromJson,
        'FinMindWeeklyPrice',
      );

  final String stockId;
  final String date; // 週結束日 YYYY-MM-DD
  final double? open; // 週開盤價
  final double? high; // 週最高價
  final double? low; // 週最低價
  final double? close; // 週收盤價
  final double? volume; // 週成交量
}

// ============================================
// Token 儲存用的設定鍵
// ============================================

/// Database 設定儲存鍵
abstract final class SettingsKeys {
  /// FinMind API token
  static const String finmindToken = 'finmind_token';

  /// 上次成功更新日期
  static const String lastUpdateDate = 'last_update_date';

  /// 是否擷取法人資料
  static const String fetchInstitutional = 'fetch_institutional';

  /// 是否擷取新聞
  static const String fetchNews = 'fetch_news';
}
