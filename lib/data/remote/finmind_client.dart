import 'dart:math' show Random;

import 'package:dio/dio.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';

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
  })  : _dio = dio ?? _createDio(),
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
          throw NetworkException('Connection timeout after $attempt attempts', e);
        }
        if (e.response?.statusCode == 429) {
          throw const RateLimitException();
        }
        throw NetworkException(e.message ?? 'Network error', e);
      } on RateLimitException {
        rethrow; // Don't retry rate limit errors
      } on ApiException catch (e) {
        // Don't retry client errors (except rate limit which is handled above)
        if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
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
  Future<void> _delay(int attempt) async {
    // Exponential backoff: baseDelay * 2^(attempt-1)
    final exponentialDelay = _baseDelay.inMilliseconds * (1 << (attempt - 1));
    // Add jitter: ±25% of the delay
    final jitter = (_random.nextDouble() - 0.5) * 0.5 * exponentialDelay;
    final totalDelay = Duration(milliseconds: (exponentialDelay + jitter).round());
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
    // Use tryFromJson to skip malformed records
    return data
        .map((json) => FinMindInstitutional.tryFromJson(json))
        .whereType<FinMindInstitutional>()
        .toList();
  }

  /// Check if token is configured
  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Check if token is configured and valid
  bool get hasValidToken => hasToken && isValidTokenFormat(_token);
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
    final close = _parseDouble(json['close']);
    if (close == null) {
      throw FormatException('Missing or invalid close price', json);
    }

    return FinMindDailyPrice(
      stockId: stockId.toString(),
      date: date.toString(),
      open: _parseDouble(json['open']),
      high: _parseDouble(json['max']),
      low: _parseDouble(json['min']),
      close: close,
      volume: _parseDouble(json['Trading_Volume']),
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

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Institutional investor data from FinMind
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

  /// Parse from JSON with validation
  ///
  /// Throws [FormatException] if required fields are missing
  factory FinMindInstitutional.fromJson(Map<String, dynamic> json) {
    final stockId = json['stock_id'];
    final date = json['date'];

    if (stockId == null || stockId.toString().isEmpty) {
      throw FormatException('Missing required field: stock_id', json);
    }
    if (date == null || date.toString().isEmpty) {
      throw FormatException('Missing required field: date', json);
    }

    return FinMindInstitutional(
      stockId: stockId.toString(),
      date: date.toString(),
      foreignBuy: _parseDouble(json['Foreign_Investor_buy']) ?? 0,
      foreignSell: _parseDouble(json['Foreign_Investor_sell']) ?? 0,
      investmentTrustBuy: _parseDouble(json['Investment_Trust_buy']) ?? 0,
      investmentTrustSell: _parseDouble(json['Investment_Trust_sell']) ?? 0,
      dealerBuy: _parseDouble(json['Dealer_self_buy']) ?? 0,
      dealerSell: _parseDouble(json['Dealer_self_sell']) ?? 0,
    );
  }

  /// Try to parse from JSON, returns null on failure
  static FinMindInstitutional? tryFromJson(Map<String, dynamic> json) {
    try {
      return FinMindInstitutional.fromJson(json);
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

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
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
