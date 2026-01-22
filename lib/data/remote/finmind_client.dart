import 'dart:math' show Random;

import 'package:dio/dio.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/json_parsers.dart';

/// FinMind API client for Taiwan stock market data
///
/// Rate limits:
/// - Anonymous: 300 requests/hour
/// - With token: 600 requests/hour
///
/// Each user should register and use their own token.
class FinMindClient {
  FinMindClient({
    Dio? dio,
    String? token,
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 500),
  }) : _dio = dio ?? _createDio(),
       _token = token,
       _maxRetries = maxRetries,
       _baseDelay = baseDelay;

  static const String baseUrl = 'https://api.finmindtrade.com/api/v4/data';

  /// Minimum valid token length
  static const int _minTokenLength = 20;

  /// Token format regex (alphanumeric with possible underscores/dashes)
  static final RegExp _tokenPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

  final Dio _dio;
  final int _maxRetries;
  final Duration _baseDelay;
  final Random _random = Random();

  /// User's FinMind API token (optional but recommended)
  String? _token;

  /// Get the current token
  String? get token => _token;

  /// Set the token with validation
  ///
  /// Throws [InvalidTokenException] if token format is invalid
  set token(String? value) {
    if (value != null && value.isNotEmpty) {
      _validateToken(value);
    }
    _token = value;
  }

  /// Validate token format
  ///
  /// Throws [InvalidTokenException] if validation fails
  static void _validateToken(String token) {
    if (token.length < _minTokenLength) {
      // Use hardcoded value to allow const constructor
      throw const InvalidTokenException(
        'Token too short (minimum 20 characters)',
      );
    }
    if (!_tokenPattern.hasMatch(token)) {
      throw const InvalidTokenException('Token contains invalid characters');
    }
  }

  /// Validate a token without setting it
  ///
  /// Returns true if valid, false if invalid
  static bool isValidTokenFormat(String? token) {
    if (token == null || token.isEmpty) return false;
    if (token.length < _minTokenLength) return false;
    return _tokenPattern.hasMatch(token);
  }

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// Build query parameters with optional token
  Map<String, dynamic> _buildParams(Map<String, dynamic> params) {
    final result = Map<String, dynamic>.from(params);
    if (_token != null && _token!.isNotEmpty) {
      result['token'] = _token;
    }
    return result;
  }

  /// Generic request handler with error mapping and retry logic
  Future<List<Map<String, dynamic>>> _request(
    Map<String, dynamic> params,
  ) async {
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

          // Check for API error response
          if (data['status'] != null && data['status'] != 200) {
            final msg = data['msg'] ?? 'Unknown API error';

            // Rate limit check
            if (msg.toString().contains('limit') ||
                msg.toString().contains('quota')) {
              throw const RateLimitException();
            }

            throw ApiException(msg.toString(), data['status'] as int?);
          }

          // Return data array
          final dataList = data['data'];
          if (dataList is List) {
            return dataList.cast<Map<String, dynamic>>();
          }
          return [];
        }

        // Server errors (5xx) are retryable
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

        // Check if this error is retryable
        if (_isRetryable(e)) {
          attempt++;
          if (attempt <= _maxRetries) {
            await _delay(attempt);
            continue;
          }
        }

        // Convert to appropriate exception
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          throw NetworkException(
            'Connection timeout after $attempt attempts',
            e,
          );
        }
        if (e.response?.statusCode == 429) {
          // Retry rate limit errors with longer backoff (limited retries)
          lastError = const RateLimitException();
          attempt++;
          if (attempt <= _maxRetries) {
            await _delay(attempt, isRateLimit: true);
            continue;
          }
          throw const RateLimitException();
        }
        throw NetworkException(e.message ?? 'Network error', e);
      } on RateLimitException {
        // Rate limit from nested call - still rethrow after max retries
        rethrow;
      } on ApiException catch (e) {
        // Don't retry client errors (except rate limit which is handled above)
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

    // All retries exhausted
    if (lastError is Exception) {
      throw lastError;
    }
    throw NetworkException('Request failed after $_maxRetries retries');
  }

  /// Check if a DioException is retryable
  bool _isRetryable(DioException e) {
    // Network-related errors are retryable
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        // Retry on server errors (5xx) but not client errors (4xx)
        final statusCode = e.response?.statusCode;
        if (statusCode != null && statusCode >= 500) {
          return true;
        }
        // Retry on 429 (rate limit) with backoff
        if (statusCode == 429) {
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  /// Calculate delay with exponential backoff and jitter
  ///
  /// When [isRateLimit] is true, uses 4x the base delay for longer backoff
  Future<void> _delay(int attempt, {bool isRateLimit = false}) async {
    // Use 4x base delay for rate limit errors (gives API more time to reset)
    final baseMs = isRateLimit
        ? _baseDelay.inMilliseconds * 4
        : _baseDelay.inMilliseconds;
    // Exponential backoff: baseDelay * 2^(attempt-1)
    final exponentialDelay = baseMs * (1 << (attempt - 1));
    // Add jitter: ±25% of the delay
    final jitter = (_random.nextDouble() - 0.5) * 0.5 * exponentialDelay;
    final totalDelay = Duration(
      milliseconds: (exponentialDelay + jitter).round(),
    );
    await Future.delayed(totalDelay);
  }

  /// Get Taiwan stock list
  ///
  /// Dataset: TaiwanStockInfo
  /// Note: Malformed records are silently skipped
  Future<List<FinMindStockInfo>> getStockList() async {
    final data = await _request({'dataset': 'TaiwanStockInfo'});

    // Use tryFromJson to skip malformed records
    return data
        .map((json) => FinMindStockInfo.tryFromJson(json))
        .whereType<FinMindStockInfo>()
        .toList();
  }

  /// Get daily stock prices
  ///
  /// Dataset: TaiwanStockPrice
  /// [stockId]: Stock symbol (e.g., "2330")
  /// [startDate]: Start date (YYYY-MM-DD)
  /// [endDate]: End date (optional)
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
    // Use tryFromJson to skip malformed records
    return data
        .map((json) => FinMindDailyPrice.tryFromJson(json))
        .whereType<FinMindDailyPrice>()
        .toList();
  }

  /// Get all stock prices for a date range (batch)
  ///
  /// Use this for efficient bulk fetching
  /// Note: Malformed records are silently skipped
  Future<List<FinMindDailyPrice>> getAllDailyPrices({
    required String startDate,
    String? endDate,
  }) async {
    final params = {'dataset': 'TaiwanStockPrice', 'start_date': startDate};

    if (endDate != null) {
      params['end_date'] = endDate;
    }

    final data = await _request(params);
    // Use tryFromJson to skip malformed records
    return data
        .map((json) => FinMindDailyPrice.tryFromJson(json))
        .whereType<FinMindDailyPrice>()
        .toList();
  }

  /// Get institutional investor trading data
  ///
  /// Dataset: TaiwanStockInstitutionalInvestorsBuySell
  /// Note: API returns one row per investor type, this method aggregates by date
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

    // Parse raw rows
    final rows = data
        .map((json) {
          try {
            return _FinMindInstitutionalRow.fromJson(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<_FinMindInstitutionalRow>()
        .toList();

    // Group by date and aggregate
    final Map<String, List<_FinMindInstitutionalRow>> byDate = {};
    for (final row in rows) {
      if (row.date.isEmpty) continue;
      byDate.putIfAbsent(row.date, () => []).add(row);
    }

    // Convert to aggregated records
    return byDate.entries
        .map((entry) {
          try {
            return FinMindInstitutional.aggregate(entry.value);
          } catch (_) {
            return null;
          }
        })
        .whereType<FinMindInstitutional>()
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get margin trading data (融資融券)
  ///
  /// Dataset: TaiwanStockMarginPurchaseShortSale
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
    // Use tryFromJson to skip malformed records
    return data
        .map((json) => FinMindMarginData.tryFromJson(json))
        .whereType<FinMindMarginData>()
        .toList();
  }

  /// Get monthly revenue data (月營收)
  ///
  /// Dataset: TaiwanStockMonthRevenue
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

  /// Get dividend data (股利)
  ///
  /// Dataset: TaiwanStockDividend
  Future<List<FinMindDividend>> getDividends({
    required String stockId,
    String? startDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockDividend',
      'data_id': stockId,
      // Default to 5 years ago if not specified
      'start_date': startDate ?? '${DateTime.now().year - 5}-01-01',
    };

    final data = await _request(params);
    return data
        .map((json) => FinMindDividend.tryFromJson(json))
        .whereType<FinMindDividend>()
        .toList();
  }

  /// Get PER/PBR data (本益比/股價淨值比)
  ///
  /// Dataset: TaiwanStockPER
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

  /// Check if token is configured
  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Check if token is configured and valid
  bool get hasValidToken => hasToken && isValidTokenFormat(_token);

  // ============================================
  // Phase 1: New API Methods (8 datasets)
  // ============================================

  /// Get foreign investor shareholding data (外資持股比例)
  ///
  /// Dataset: TaiwanStockShareholding
  /// Returns: Foreign investor shareholding percentage over time
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

  /// Get shareholding distribution data (股權分散表)
  ///
  /// Dataset: TaiwanStockHoldingSharesPer
  /// Returns: Distribution of shareholders by holding percentage
  ///
  /// NOTE: This API requires paid membership (backer/sponsor).
  /// Free users will receive 400 Bad Request error.
  Future<List<FinMindHoldingSharesPer>> getHoldingSharesPer({
    required String stockId,
    required String startDate,
    String? endDate,
  }) async {
    final params = {
      'dataset': 'TaiwanStockHoldingSharesPer',
      'stock_id': stockId, // This API uses stock_id, not data_id
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

  /// Get day trading data (當沖比例)
  ///
  /// Dataset: TaiwanStockDayTrading
  /// Returns: Day trading volume and percentage
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

  /// Get financial statements data (綜合損益表)
  ///
  /// Dataset: TaiwanStockFinancialStatements
  /// Returns: Income statement data by quarter
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

  /// Get balance sheet data (資產負債表)
  ///
  /// Dataset: TaiwanStockBalanceSheet
  /// Returns: Balance sheet data by quarter
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

  /// Get cash flow statement data (現金流量表)
  ///
  /// Dataset: TaiwanStockCashFlowsStatement
  /// Returns: Cash flow data by quarter
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

  /// Get adjusted stock prices (還原股價)
  ///
  /// Dataset: TaiwanStockPriceAdj
  /// Returns: Stock prices adjusted for dividends and splits
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

  /// Get weekly stock prices (週K線)
  ///
  /// Dataset: TaiwanStockWeekPrice
  /// Returns: Weekly OHLCV data
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
// Data Models (simple classes, no code-gen)
// ============================================

/// Stock information from FinMind
class FinMindStockInfo {
  const FinMindStockInfo({
    required this.stockId,
    required this.stockName,
    required this.industryCategory,
    required this.type,
  });

  /// Parse from JSON with validation
  ///
  /// Throws [FormatException] if required fields are missing
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

  /// Try to parse from JSON, returns null on failure
  static FinMindStockInfo? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindStockInfo.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String stockName;
  final String industryCategory;
  final String type; // "twse" or "tpex"

  /// Convert type to market enum string
  String get market => type.toLowerCase() == 'twse' ? 'TWSE' : 'TPEx';
}

/// Daily price data from FinMind
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

  /// Parse from JSON with validation
  ///
  /// Throws [FormatException] if required fields are missing
  factory FinMindDailyPrice.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    // Parse close price - this is critical for analysis
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

  /// Try to parse from JSON, returns null on failure
  static FinMindDailyPrice? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindDailyPrice.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date; // YYYY-MM-DD
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
}

/// Raw institutional investor row from FinMind API
/// Note: API returns one row per investor type, need to aggregate
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

/// Aggregated institutional investor data from FinMind
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

  /// Aggregate multiple rows (one per investor type) into single record
  /// The API returns separate rows for each investor type per date
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

  /// Try to parse from JSON (for backward compatibility - not recommended)
  static FinMindInstitutional? tryFromJson(Map<String, dynamic> json) {
    // This is a single row, create a one-item aggregate
    try {
      final row = _FinMindInstitutionalRow.fromJson(json);
      if (row.stockId.isEmpty || row.date.isEmpty) return null;
      return FinMindInstitutional.aggregate([row]);
    } catch (_) {
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

  /// Net foreign institutional trading
  double get foreignNet => foreignBuy - foreignSell;

  /// Net investment trust trading
  double get investmentTrustNet => investmentTrustBuy - investmentTrustSell;

  /// Net dealer trading
  double get dealerNet => dealerBuy - dealerSell;
}

/// Margin trading data (融資融券) from FinMind
class FinMindMarginData {
  const FinMindMarginData({
    required this.stockId,
    required this.date,
    required this.marginBuy,
    required this.marginSell,
    required this.marginCashRepay,
    required this.marginBalance,
    required this.marginBalanceChange,
    required this.marginUseRate,
    required this.shortBuy,
    required this.shortSell,
    required this.shortCashRepay,
    required this.shortBalance,
    required this.shortBalanceChange,
    required this.offsetMarginShort,
    required this.note,
  });

  /// Parse from JSON with validation
  ///
  /// Throws [FormatException] if required fields are missing
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
      marginBalanceChange: marginLimit,
      // 融資使用率 = 融資餘額 / 融資限額 * 100
      marginUseRate: marginLimit > 0 ? (marginBalance / marginLimit) * 100 : 0,
      shortBuy: JsonParsers.parseDouble(json['ShortSaleBuy']) ?? 0,
      shortSell: JsonParsers.parseDouble(json['ShortSaleSell']) ?? 0,
      shortCashRepay:
          JsonParsers.parseDouble(json['ShortSaleCashRepayment']) ?? 0,
      shortBalance: JsonParsers.parseDouble(json['ShortSaleTodayBalance']) ?? 0,
      shortBalanceChange: JsonParsers.parseDouble(json['ShortSaleLimit']) ?? 0,
      offsetMarginShort:
          JsonParsers.parseDouble(json['OffsetLoanAndShort']) ?? 0,
      note: json['Note']?.toString() ?? '',
    );
  }

  /// Try to parse from JSON, returns null on failure
  static FinMindMarginData? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindMarginData.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date;

  // 融資 (Margin Purchase)
  final double marginBuy; // 融資買進
  final double marginSell; // 融資賣出
  final double marginCashRepay; // 現金償還
  final double marginBalance; // 融資餘額
  final double marginBalanceChange; // 融資限額
  final double marginUseRate; // 融資使用率

  // 融券 (Short Sale)
  final double shortBuy; // 融券買進
  final double shortSell; // 融券賣出
  final double shortCashRepay; // 現券償還
  final double shortBalance; // 融券餘額
  final double shortBalanceChange; // 融券限額
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

/// Monthly revenue data (月營收) from FinMind
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

  static FinMindRevenue? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindRevenue.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Calculate MoM and YoY growth rates for a list of revenues
  /// Returns the same list with growth rates populated
  static List<FinMindRevenue> calculateGrowthRates(
    List<FinMindRevenue> revenues,
  ) {
    if (revenues.isEmpty) return revenues;

    // Sort by date (year/month)
    final sorted = List<FinMindRevenue>.from(revenues)
      ..sort((a, b) {
        final yearCompare = a.revenueYear.compareTo(b.revenueYear);
        if (yearCompare != 0) return yearCompare;
        return a.revenueMonth.compareTo(b.revenueMonth);
      });

    // Build lookup map for quick access
    final Map<String, FinMindRevenue> lookup = {};
    for (final rev in sorted) {
      lookup['${rev.revenueYear}-${rev.revenueMonth}'] = rev;
    }

    // Calculate growth rates
    for (final rev in sorted) {
      // MoM: Compare to previous month
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

      // YoY: Compare to same month last year
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

/// Dividend data (股利) from FinMind
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

  static FinMindDividend? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindDividend.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final int year;
  final double cashDividend; // 現金股利
  final double stockDividend; // 股票股利
  final String? exDividendDate; // 除息日
  final String? exRightsDate; // 除權日

  /// 總股利
  double get totalDividend => cashDividend + stockDividend;
}

/// PER/PBR data (本益比/股價淨值比) from FinMind
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

  static FinMindPER? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindPER.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date;
  final double per; // 本益比
  final double pbr; // 股價淨值比
  final double dividendYield; // 殖利率
}

// ============================================
// Phase 1: New Data Models (8 datasets)
// ============================================

/// Foreign investor shareholding data (外資持股比例) from FinMind
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

  static FinMindShareholding? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindShareholding.fromJson(json);
    } catch (_) {
      return null;
    }
  }

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

/// Shareholding distribution data (股權分散表) from FinMind
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

  static FinMindHoldingSharesPer? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindHoldingSharesPer.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date;
  final String holdingSharesLevel; // 持股分級 (e.g., "1-999", "1000-5000")
  final int people; // 股東人數
  final double percent; // 占集保庫存數比例(%)
  final double unit; // 股數
}

/// Day trading data (當沖比例) from FinMind
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

  static FinMindDayTrading? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindDayTrading.fromJson(json);
    } catch (_) {
      return null;
    }
  }

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

/// Financial statement data (綜合損益表) from FinMind
/// Note: Financial statements come with type/value pairs, this is a simplified version
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

  static FinMindFinancialStatement? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindFinancialStatement.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date; // YYYY-QQ format (e.g., "2024-Q1")
  final String type; // 項目名稱 (e.g., "Revenue", "NetIncome")
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// Common financial statement types
  static const String typeRevenue = 'Revenue';
  static const String typeGrossProfit = 'GrossProfit';
  static const String typeOperatingIncome = 'OperatingIncome';
  static const String typeNetIncome = 'NetIncome';
  static const String typeEPS = 'EPS';
}

/// Balance sheet data (資產負債表) from FinMind
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

  static FinMindBalanceSheet? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindBalanceSheet.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date;
  final String type; // 項目名稱 (e.g., "TotalAssets", "TotalLiabilities")
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// Common balance sheet types
  static const String typeTotalAssets = 'TotalAssets';
  static const String typeTotalLiabilities = 'TotalLiabilities';
  static const String typeEquity = 'Equity';
  static const String typeCurrentAssets = 'CurrentAssets';
  static const String typeCurrentLiabilities = 'CurrentLiabilities';
  static const String typeCash = 'CashAndCashEquivalents';
}

/// Cash flow statement data (現金流量表) from FinMind
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

  static FinMindCashFlowStatement? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindCashFlowStatement.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date;
  final String type; // 項目名稱
  final double value; // 金額
  final String origin; // 中文項目名稱

  /// Common cash flow types
  static const String typeOperatingCashFlow =
      'CashFlowsFromOperatingActivities';
  static const String typeInvestingCashFlow =
      'CashFlowsFromInvestingActivities';
  static const String typeFinancingCashFlow =
      'CashFlowsFromFinancingActivities';
  static const String typeFreeCashFlow = 'FreeCashFlow';
}

/// Adjusted stock price data (還原股價) from FinMind
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

  static FinMindAdjustedPrice? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindAdjustedPrice.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date; // YYYY-MM-DD
  final double? open; // 還原開盤價
  final double? high; // 還原最高價
  final double? low; // 還原最低價
  final double? close; // 還原收盤價
  final double? volume; // 成交量
}

/// Weekly stock price data (週K線) from FinMind
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

  static FinMindWeeklyPrice? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindWeeklyPrice.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final String stockId;
  final String date; // 週結束日 YYYY-MM-DD
  final double? open; // 週開盤價
  final double? high; // 週最高價
  final double? low; // 週最低價
  final double? close; // 週收盤價
  final double? volume; // 週成交量
}

// ============================================
// Settings Keys for Token Storage
// ============================================

/// Keys for storing settings in database
abstract final class SettingsKeys {
  /// FinMind API token
  static const String finmindToken = 'finmind_token';

  /// Last successful update date
  static const String lastUpdateDate = 'last_update_date';

  /// Whether to fetch institutional data
  static const String fetchInstitutional = 'fetch_institutional';

  /// Whether to fetch news
  static const String fetchNews = 'fetch_news';
}
