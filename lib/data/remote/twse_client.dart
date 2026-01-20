import 'package:dio/dio.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';

/// TWSE (Taiwan Stock Exchange) Open Data API Client
///
/// Provides free, unlimited access to Taiwan stock market data.
/// No authentication required.
///
/// API Documentation: https://openapi.twse.com.tw/
class TwseClient {
  TwseClient({Dio? dio}) : _dio = dio ?? _createDio();

  static const String _baseUrl = 'https://openapi.twse.com.tw/v1';

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Accept': 'application/json'},
      ),
    );
  }

  /// Get all stock prices for the latest trading day
  ///
  /// Returns OHLCV data for all TWSE listed stocks
  /// Endpoint: /exchangeReport/STOCK_DAY_ALL
  Future<List<TwseDailyPrice>> getAllDailyPrices() async {
    try {
      final response = await _dio.get('/exchangeReport/STOCK_DAY_ALL');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => TwseDailyPrice.tryFromJson(json as Map<String, dynamic>))
            .whereType<TwseDailyPrice>()
            .toList();
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('TWSE connection timeout', e);
      }
      throw NetworkException(e.message ?? 'TWSE network error', e);
    }
  }

  /// Get institutional investor trading data for all stocks
  ///
  /// Endpoint: /exchangeReport/TWT38U_ALL (三大法人買賣超日報)
  Future<List<TwseInstitutional>> getAllInstitutionalData() async {
    try {
      final response = await _dio.get('/exchangeReport/TWT38U_ALL');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => TwseInstitutional.tryFromJson(json as Map<String, dynamic>))
            .whereType<TwseInstitutional>()
            .toList();
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'TWSE network error', e);
    }
  }

  /// Get historical prices for a specific stock (one month at a time)
  ///
  /// [code] - Stock code (e.g., "2330")
  /// [year] - AD year (e.g., 2026)
  /// [month] - Month (1-12)
  ///
  /// Endpoint: /exchangeReport/STOCK_DAY
  ///
  /// Throws [ArgumentError] if parameters are invalid
  Future<List<TwseDailyPrice>> getStockMonthlyPrices({
    required String code,
    required int year,
    required int month,
  }) async {
    // Validate stock code (Taiwan stocks are typically 4-6 digits)
    if (code.isEmpty) {
      throw ArgumentError.value(code, 'code', 'Stock code cannot be empty');
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(code)) {
      throw ArgumentError.value(
        code,
        'code',
        'Stock code must be 4-6 digits (e.g., "2330")',
      );
    }

    // Validate year (reasonable range for TWSE historical data)
    if (year < 1990 || year > 2100) {
      throw ArgumentError.value(
        year,
        'year',
        'Year must be between 1990 and 2100',
      );
    }

    // Validate month
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Month must be between 1 and 12');
    }

    // Prevent future dates
    final now = DateTime.now();
    if (year > now.year || (year == now.year && month > now.month)) {
      throw ArgumentError('Cannot fetch data for future dates: $year/$month');
    }

    try {
      // Format date as YYYYMMDD (first day of month)
      final dateStr = '$year${month.toString().padLeft(2, '0')}01';

      final response = await _dio.get(
        'https://www.twse.com.tw/exchangeReport/STOCK_DAY',
        queryParameters: {
          'response': 'json',
          'date': dateStr,
          'stockNo': code,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['stat'] != 'OK' || data['data'] == null) {
          return [];
        }

        final List<dynamic> rows = data['data'];
        return rows
            .map((row) => _parseHistoricalRow(row as List<dynamic>, code))
            .whereType<TwseDailyPrice>()
            .toList();
      }

      throw ApiException(
        'TWSE historical API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'TWSE historical API error', e);
    }
  }

  /// Parse a row from TWSE historical data
  TwseDailyPrice? _parseHistoricalRow(List<dynamic> row, String code) {
    try {
      // Row format: [日期, 成交股數, 成交金額, 開盤價, 最高價, 最低價, 收盤價, 漲跌價差, 成交筆數, ...]
      if (row.length < 9) return null;

      final dateStr = row[0].toString(); // Format: "115/01/02"
      final date = _parseSlashRocDate(dateStr);

      return TwseDailyPrice(
        date: date,
        code: code,
        name: '', // Name not included in historical data
        open: _parseFormattedDouble(row[3]),
        high: _parseFormattedDouble(row[4]),
        low: _parseFormattedDouble(row[5]),
        close: _parseFormattedDouble(row[6]),
        volume: _parseFormattedDouble(row[1]),
        change: _parseFormattedDouble(row[7]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse ROC date with slashes (e.g., "115/01/02")
  DateTime _parseSlashRocDate(String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length != 3) {
      throw FormatException('Invalid ROC date: $dateStr');
    }

    final rocYear = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    return DateTime(rocYear + 1911, month, day);
  }

  /// Parse number with commas (e.g., "1,234,567")
  double? _parseFormattedDouble(dynamic value) {
    if (value == null) return null;
    final str = value.toString().replaceAll(',', '').trim();
    if (str.isEmpty || str == '--' || str == 'X') return null;
    return double.tryParse(str);
  }

  /// Get historical prices for multiple months
  ///
  /// [code] - Stock code (4-6 digits)
  /// [months] - Number of months to fetch (default: 6, max: 60)
  /// [delayBetweenRequests] - Delay between API calls (default: 300ms)
  ///
  /// Note: TWSE may rate limit requests, so we add delays between calls.
  ///
  /// Throws [ArgumentError] if parameters are invalid
  Future<List<TwseDailyPrice>> getStockHistoricalPrices({
    required String code,
    int months = 6,
    Duration delayBetweenRequests = const Duration(milliseconds: 300),
  }) async {
    // Validate stock code
    if (code.isEmpty) {
      throw ArgumentError.value(code, 'code', 'Stock code cannot be empty');
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(code)) {
      throw ArgumentError.value(
        code,
        'code',
        'Stock code must be 4-6 digits (e.g., "2330")',
      );
    }

    // Validate months (reasonable range to avoid excessive API calls)
    if (months < 1 || months > 60) {
      throw ArgumentError.value(
        months,
        'months',
        'Months must be between 1 and 60',
      );
    }

    // Validate delay (minimum 100ms to avoid rate limiting)
    if (delayBetweenRequests.inMilliseconds < 100) {
      throw ArgumentError.value(
        delayBetweenRequests,
        'delayBetweenRequests',
        'Delay must be at least 100ms to avoid rate limiting',
      );
    }

    final results = <TwseDailyPrice>[];
    final now = DateTime.now();

    for (var i = 0; i < months; i++) {
      final targetDate = DateTime(now.year, now.month - i, 1);

      try {
        final monthData = await getStockMonthlyPrices(
          code: code,
          year: targetDate.year,
          month: targetDate.month,
        );
        results.addAll(monthData);
      } catch (_) {
        // Continue with other months if one fails
      }

      // Rate limiting delay
      if (i < months - 1) {
        await Future.delayed(delayBetweenRequests);
      }
    }

    // Sort by date ascending
    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  /// Get margin trading data for all stocks
  ///
  /// Endpoint: /exchangeReport/TWT93U_ALL (融資融券餘額)
  Future<List<TwseMarginTrading>> getAllMarginTradingData() async {
    try {
      final response = await _dio.get('/exchangeReport/TWT93U_ALL');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => TwseMarginTrading.tryFromJson(json as Map<String, dynamic>))
            .whereType<TwseMarginTrading>()
            .toList();
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'TWSE network error', e);
    }
  }
}

// ============================================
// Data Models
// ============================================

/// Daily price data from TWSE
class TwseDailyPrice {
  const TwseDailyPrice({
    required this.date,
    required this.code,
    required this.name,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.change,
  });

  factory TwseDailyPrice.fromJson(Map<String, dynamic> json) {
    final code = json['Code'];
    final dateStr = json['Date'];

    if (code == null || code.toString().isEmpty) {
      throw FormatException('Missing Code', json);
    }
    if (dateStr == null || dateStr.toString().isEmpty) {
      throw FormatException('Missing Date', json);
    }

    // Parse ROC date (民國) to DateTime
    final date = _parseRocDate(dateStr.toString());

    return TwseDailyPrice(
      date: date,
      code: code.toString(),
      name: json['Name']?.toString() ?? '',
      open: _parseDouble(json['OpeningPrice']),
      high: _parseDouble(json['HighestPrice']),
      low: _parseDouble(json['LowestPrice']),
      close: _parseDouble(json['ClosingPrice']),
      volume: _parseDouble(json['TradeVolume']),
      change: _parseDouble(json['Change']),
    );
  }

  static TwseDailyPrice? tryFromJson(Map<String, dynamic> json) {
    try {
      return TwseDailyPrice.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final DateTime date;
  final String code;
  final String name;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
  final double? change;

  /// Convert TWSE ROC date (民國年月日, e.g., "1150119") to DateTime
  static DateTime _parseRocDate(String rocDate) {
    if (rocDate.length != 7) {
      throw FormatException('Invalid ROC date format: $rocDate');
    }

    final rocYear = int.parse(rocDate.substring(0, 3));
    final month = int.parse(rocDate.substring(3, 5));
    final day = int.parse(rocDate.substring(5, 7));

    // ROC year + 1911 = AD year
    final adYear = rocYear + 1911;

    return DateTime(adYear, month, day);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Remove commas from numbers like "1,234,567"
      final cleaned = value.replaceAll(',', '').trim();
      if (cleaned.isEmpty || cleaned == '--') return null;
      return double.tryParse(cleaned);
    }
    return null;
  }
}

/// Institutional investor data from TWSE
class TwseInstitutional {
  const TwseInstitutional({
    required this.date,
    required this.code,
    required this.name,
    required this.foreignBuy,
    required this.foreignSell,
    required this.foreignNet,
    required this.investmentTrustBuy,
    required this.investmentTrustSell,
    required this.investmentTrustNet,
    required this.dealerBuy,
    required this.dealerSell,
    required this.dealerNet,
    required this.totalNet,
  });

  factory TwseInstitutional.fromJson(Map<String, dynamic> json) {
    final code = json['Code'];
    final dateStr = json['Date'];

    if (code == null || code.toString().isEmpty) {
      throw FormatException('Missing Code', json);
    }

    return TwseInstitutional(
      date: dateStr != null ? TwseDailyPrice._parseRocDate(dateStr.toString()) : DateTime.now(),
      code: code.toString(),
      name: json['Name']?.toString() ?? '',
      foreignBuy: _parseDouble(json['ForeignInvestorsBuy']) ?? 0,
      foreignSell: _parseDouble(json['ForeignInvestorsSell']) ?? 0,
      foreignNet: _parseDouble(json['ForeignInvestorsNetBuySell']) ?? 0,
      investmentTrustBuy: _parseDouble(json['InvestmentTrustBuy']) ?? 0,
      investmentTrustSell: _parseDouble(json['InvestmentTrustSell']) ?? 0,
      investmentTrustNet: _parseDouble(json['InvestmentTrustNetBuySell']) ?? 0,
      dealerBuy: _parseDouble(json['DealerTotalBuy']) ?? 0,
      dealerSell: _parseDouble(json['DealerTotalSell']) ?? 0,
      dealerNet: _parseDouble(json['DealerTotalNetBuySell']) ?? 0,
      totalNet: _parseDouble(json['TotalNetBuySell']) ?? 0,
    );
  }

  static TwseInstitutional? tryFromJson(Map<String, dynamic> json) {
    try {
      return TwseInstitutional.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final DateTime date;
  final String code;
  final String name;
  final double foreignBuy;
  final double foreignSell;
  final double foreignNet;
  final double investmentTrustBuy;
  final double investmentTrustSell;
  final double investmentTrustNet;
  final double dealerBuy;
  final double dealerSell;
  final double dealerNet;
  final double totalNet;

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '').trim();
      if (cleaned.isEmpty || cleaned == '--') return null;
      return double.tryParse(cleaned);
    }
    return null;
  }
}

/// Margin trading data from TWSE
class TwseMarginTrading {
  const TwseMarginTrading({
    required this.date,
    required this.code,
    required this.name,
    required this.marginBuy,
    required this.marginSell,
    required this.marginBalance,
    required this.shortBuy,
    required this.shortSell,
    required this.shortBalance,
  });

  factory TwseMarginTrading.fromJson(Map<String, dynamic> json) {
    final code = json['Code'];
    final dateStr = json['Date'];

    if (code == null || code.toString().isEmpty) {
      throw FormatException('Missing Code', json);
    }

    return TwseMarginTrading(
      date: dateStr != null ? TwseDailyPrice._parseRocDate(dateStr.toString()) : DateTime.now(),
      code: code.toString(),
      name: json['Name']?.toString() ?? '',
      marginBuy: _parseDouble(json['MarginPurchase']) ?? 0,
      marginSell: _parseDouble(json['MarginSell']) ?? 0,
      marginBalance: _parseDouble(json['MarginBalance']) ?? 0,
      shortBuy: _parseDouble(json['ShortCovering']) ?? 0,
      shortSell: _parseDouble(json['ShortSale']) ?? 0,
      shortBalance: _parseDouble(json['ShortBalance']) ?? 0,
    );
  }

  static TwseMarginTrading? tryFromJson(Map<String, dynamic> json) {
    try {
      return TwseMarginTrading.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  final DateTime date;
  final String code;
  final String name;
  final double marginBuy;   // 融資買進
  final double marginSell;  // 融資賣出
  final double marginBalance; // 融資餘額
  final double shortBuy;    // 融券買進 (回補)
  final double shortSell;   // 融券賣出
  final double shortBalance; // 融券餘額

  /// Net margin change (融資增減)
  double get marginNet => marginBuy - marginSell;

  /// Net short change (融券增減)
  double get shortNet => shortSell - shortBuy;

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '').trim();
      if (cleaned.isEmpty || cleaned == '--') return null;
      return double.tryParse(cleaned);
    }
    return null;
  }
}
