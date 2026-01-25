import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/api_endpoints.dart';
import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';

/// 台灣證券櫃檯買賣中心 (TPEX/OTC) API 客戶端
///
/// 提供免費存取上櫃股票市場資料。
/// 與 TwseClient 架構一致，用於取得上櫃股票的價格和法人資料。
/// 無需認證。
///
/// API 來源:
/// - 每日股價: https://www.tpex.org.tw/web/stock/aftertrading/otc_quotes_no1430/stk_wn1430_result.php
/// - 法人買賣: https://www.tpex.org.tw/web/stock/3insti/daily_trade/3itrade_hedge_result.php
class TpexClient {
  TpexClient({Dio? dio}) : _dio = dio ?? _createDio();

  /// TPEX 官方網站基礎 URL
  static const String _baseUrl = ApiEndpoints.tpexBaseUrl;

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(
          seconds: ApiConfig.twseConnectTimeoutSec,
        ),
        receiveTimeout: const Duration(
          seconds: ApiConfig.twseReceiveTimeoutSec,
        ),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
        responseType: ResponseType.json,
      ),
    );
  }

  /// 取得最新交易日所有上櫃股票價格
  ///
  /// 回傳所有上櫃股票的 OHLCV 資料。
  ///
  /// 端點: /web/stock/aftertrading/otc_quotes_no1430/stk_wn1430_result.php
  Future<List<TpexDailyPrice>> getAllDailyPrices({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final rocDateStr = _toRocDateString(targetDate);

      final response = await _dio.get(
        ApiEndpoints.tpexDailyPricesAll,
        queryParameters: {'l': 'zh-tw', 'd': rocDateStr, 'o': 'json'},
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '全市場價格: JSON 解析失敗');
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TPEX', '全市場價格: 非預期資料型別');
          return [];
        }

        // TPEX API 回傳格式: { tables: [{ data: [...] }] }
        final tables = data['tables'] as List<dynamic>?;
        if (tables == null || tables.isEmpty) {
          AppLogger.warning('TPEX', '全市場價格: 無 tables');
          return [];
        }

        final firstTable = tables[0] as Map<String, dynamic>?;
        if (firstTable == null) {
          AppLogger.warning('TPEX', '全市場價格: 無資料表');
          return [];
        }

        // 從回傳資料取得實際日期（格式: "115/01/23"）
        final dateStr = firstTable['date'] as String?;
        final actualDate = dateStr != null
            ? _parseRocDateString(dateStr)
            : targetDate;

        final List<dynamic>? rows = firstTable['data'] as List<dynamic>?;
        if (rows == null || rows.isEmpty) {
          AppLogger.warning('TPEX', '全市場價格: 無資料');
          return [];
        }

        // 解析資料陣列
        var failedCount = 0;
        final prices = <TpexDailyPrice>[];

        for (final row in rows) {
          final parsed = _parseDailyPriceRow(row as List<dynamic>, actualDate);
          if (parsed != null) {
            prices.add(parsed);
          } else {
            failedCount++;
          }
        }

        // 統一輸出結果
        final dateFormatted = _formatDate(targetDate);
        if (failedCount > 0) {
          AppLogger.info(
            'TPEX',
            '全市場價格: ${prices.length} 筆 ($dateFormatted, 略過 $failedCount 筆)',
          );
        } else {
          AppLogger.info('TPEX', '全市場價格: ${prices.length} 筆 ($dateFormatted)');
        }
        return prices;
      }

      throw ApiException(
        'TPEX API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        AppLogger.warning('TPEX', '全市場價格: 連線逾時');
        throw NetworkException('TPEX connection timeout', e);
      }
      AppLogger.warning('TPEX', '全市場價格: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TPEX network error', e);
    } catch (e, stack) {
      AppLogger.error('TPEX', '全市場價格: 非預期錯誤', e, stack);
      rethrow;
    }
  }

  /// 解析每日價格資料列
  ///
  /// 列格式: [代號, 名稱, 收盤, 漲跌, 開盤, 最高, 最低, 均價, 成交股數, 成交金額, 成交筆數, 最後買價, 最後賣價, 發行股數, 次日參考價, 次日漲停價, 次日跌停價]
  TpexDailyPrice? _parseDailyPriceRow(List<dynamic> row, DateTime date) {
    try {
      if (row.length < 11) return null;

      final code = row[0]?.toString().trim() ?? '';
      if (code.isEmpty) return null;

      // 過濾非股票代碼（上櫃股票為 4 碼數字）
      if (!StockPatterns.isTpexCode(code)) return null;

      return TpexDailyPrice(
        date: date,
        code: code,
        name: row[1]?.toString().trim() ?? '',
        close: _parseFormattedDouble(row[2]),
        change: _parseFormattedDouble(row[3]),
        open: _parseFormattedDouble(row[4]),
        high: _parseFormattedDouble(row[5]),
        low: _parseFormattedDouble(row[6]),
        volume: _parseFormattedDouble(row[8]),
        turnover: _parseFormattedDouble(row[9]),
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得所有上櫃股票的法人買賣超資料
  ///
  /// 端點: /web/stock/3insti/daily_trade/3itrade_hedge_result.php
  Future<List<TpexInstitutional>> getAllInstitutionalData({
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final rocDateStr = _toRocDateString(targetDate);

      final response = await _dio.get(
        ApiEndpoints.tpexInstitutional,
        queryParameters: {'l': 'zh-tw', 'd': rocDateStr, 't': 'D', 'o': 'json'},
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '法人資料: JSON 解析失敗');
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TPEX', '法人資料: 非預期資料型別');
          return [];
        }

        // TPEX API 回傳格式: { tables: [{ data: [...] }] }
        final tables = data['tables'] as List<dynamic>?;
        if (tables == null || tables.isEmpty) {
          AppLogger.warning('TPEX', '法人資料: 無 tables');
          return [];
        }

        final firstTable = tables[0] as Map<String, dynamic>?;
        if (firstTable == null) {
          AppLogger.warning('TPEX', '法人資料: 無資料表');
          return [];
        }

        // 從回傳資料取得實際日期
        final dateStr = firstTable['date'] as String?;
        final actualDate = dateStr != null
            ? _parseRocDateString(dateStr)
            : targetDate;

        final List<dynamic>? rows = firstTable['data'] as List<dynamic>?;
        if (rows == null || rows.isEmpty) {
          AppLogger.warning('TPEX', '法人資料: 無資料');
          return [];
        }

        // 解析資料陣列
        final results = rows
            .map(
              (row) => _parseInstitutionalRow(row as List<dynamic>, actualDate),
            )
            .whereType<TpexInstitutional>()
            .toList();

        final dateFormatted = _formatDate(targetDate);
        AppLogger.info('TPEX', '法人資料: ${results.length} 筆 ($dateFormatted)');
        return results;
      }

      throw ApiException(
        'TPEX API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TPEX', '法人資料: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TPEX network error', e);
    }
  }

  /// 解析法人資料列
  ///
  /// TPEX 欄位格式 (24 欄):
  /// [0] 代號, [1] 名稱
  /// [2-4] 外資及陸資(不含外資自營商) 買/賣/淨
  /// [5-7] 外資自營商 買/賣/淨
  /// [8-10] 外資及陸資(合計) 買/賣/淨
  /// [11-13] 投信 買/賣/淨
  /// [14-16] 自營商(自行) 買/賣/淨
  /// [17-19] 自營商(避險) 買/賣/淨
  /// [20-22] 自營商(合計) 買/賣/淨
  /// [23] 三大法人買賣超股數合計
  TpexInstitutional? _parseInstitutionalRow(List<dynamic> row, DateTime date) {
    try {
      if (row.length < 24) return null;

      final code = row[0]?.toString().trim() ?? '';
      if (code.isEmpty) return null;

      // 過濾非股票代碼（上櫃股票為 4 碼數字）
      if (!StockPatterns.isTpexCode(code)) return null;

      return TpexInstitutional(
        date: date,
        code: code,
        name: row[1]?.toString().trim() ?? '',
        // 外資及陸資(合計) - indices 8-10
        foreignBuy: _parseFormattedDouble(row[8]) ?? 0,
        foreignSell: _parseFormattedDouble(row[9]) ?? 0,
        foreignNet: _parseFormattedDouble(row[10]) ?? 0,
        // 投信 - indices 11-13
        investmentTrustBuy: _parseFormattedDouble(row[11]) ?? 0,
        investmentTrustSell: _parseFormattedDouble(row[12]) ?? 0,
        investmentTrustNet: _parseFormattedDouble(row[13]) ?? 0,
        // 自營商(合計) - indices 20-22
        dealerBuy: _parseFormattedDouble(row[20]) ?? 0,
        dealerSell: _parseFormattedDouble(row[21]) ?? 0,
        dealerNet: _parseFormattedDouble(row[22]) ?? 0,
        // 三大法人合計 - index 23
        totalNet: _parseFormattedDouble(row[23]) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 將 DateTime 轉為民國日期字串（格式: 114/01/24）
  String _toRocDateString(DateTime date) {
    final rocYear = date.year - ApiConfig.rocYearOffset;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$rocYear/$month/$day';
  }

  /// 將民國日期字串轉為 DateTime（格式: 114/01/24 或 115/01/23）
  DateTime _parseRocDateString(String rocDateStr) {
    try {
      final parts = rocDateStr.split('/');
      if (parts.length != 3) return DateTime.now();

      final rocYear = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      return DateTime(rocYear + ApiConfig.rocYearOffset, month, day);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// 格式化日期為顯示用字串
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 解析含逗號的數字（例如 "1,234,567"）
  double? _parseFormattedDouble(dynamic value) {
    if (value == null) return null;
    final str = value.toString().replaceAll(',', '').trim();
    if (str.isEmpty || str == '--' || str == 'X' || str == '---') return null;
    return double.tryParse(str);
  }

  /// 取得所有上櫃股票的融資融券資料
  ///
  /// 端點: /web/stock/margin_trading/margin_sbl/margin_sbl_result.php
  Future<List<TpexMarginTrading>> getAllMarginTradingData({
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final rocDateStr = _toRocDateString(targetDate);

      final response = await _dio.get(
        ApiEndpoints.tpexMarginTrading,
        queryParameters: {'l': 'zh-tw', 'd': rocDateStr, 'o': 'json'},
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '融資融券: JSON 解析失敗');
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TPEX', '融資融券: 非預期資料型別');
          return [];
        }

        // TPEX API 回傳格式: { tables: [{ data: [...] }] }
        final tables = data['tables'] as List<dynamic>?;
        if (tables == null || tables.isEmpty) {
          AppLogger.warning('TPEX', '融資融券: 無 tables');
          return [];
        }

        final firstTable = tables[0] as Map<String, dynamic>?;
        if (firstTable == null) {
          AppLogger.warning('TPEX', '融資融券: 無資料表');
          return [];
        }

        // 從回傳資料取得實際日期
        final dateStr = firstTable['date'] as String?;
        final actualDate = dateStr != null
            ? _parseRocDateString(dateStr)
            : targetDate;

        final List<dynamic>? rows = firstTable['data'] as List<dynamic>?;
        if (rows == null || rows.isEmpty) {
          AppLogger.warning('TPEX', '融資融券: 無資料');
          return [];
        }

        // 解析資料陣列
        final results = rows
            .map(
              (row) => _parseMarginTradingRow(row as List<dynamic>, actualDate),
            )
            .whereType<TpexMarginTrading>()
            .toList();

        final dateFormatted = _formatDate(targetDate);
        AppLogger.info('TPEX', '融資融券: ${results.length} 筆 ($dateFormatted)');
        return results;
      }

      throw ApiException(
        'TPEX API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TPEX', '融資融券: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TPEX network error', e);
    }
  }

  /// 解析融資融券資料列
  ///
  /// TPEX 欄位格式 (15 欄):
  /// [0] 代號, [1] 名稱
  /// [2] 融資前日餘額, [3] 融資賣出, [4] 融資買進, [5] 融資現券, [6] 融資當日餘額, [7] 融資限額
  /// [8] 融券前日餘額, [9] 融券賣出, [10] 融券還券, [11] 融券調整, [12] 融券當日餘額, [13] 融券限額
  /// [14] 備註
  TpexMarginTrading? _parseMarginTradingRow(List<dynamic> row, DateTime date) {
    try {
      if (row.length < 13) return null;

      final code = row[0]?.toString().trim() ?? '';
      if (code.isEmpty) return null;

      // 過濾非股票代碼（上櫃股票為 4 碼數字）
      if (!StockPatterns.isTpexCode(code)) return null;

      return TpexMarginTrading(
        date: date,
        code: code,
        name: row[1]?.toString().trim() ?? '',
        // 融資
        marginBuy: _parseFormattedDouble(row[4]) ?? 0,
        marginSell: _parseFormattedDouble(row[3]) ?? 0,
        marginBalance: _parseFormattedDouble(row[6]) ?? 0,
        // 融券
        shortBuy: _parseFormattedDouble(row[10]) ?? 0, // 還券
        shortSell: _parseFormattedDouble(row[9]) ?? 0, // 賣出
        shortBalance: _parseFormattedDouble(row[12]) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

// ============================================
// 資料模型
// ============================================

/// TPEX 每日價格資料
class TpexDailyPrice {
  const TpexDailyPrice({
    required this.date,
    required this.code,
    required this.name,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.change,
    this.turnover,
  });

  final DateTime date;
  final String code;
  final String name;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
  final double? change;
  final double? turnover;
}

/// TPEX 法人買賣超資料
class TpexInstitutional {
  const TpexInstitutional({
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
}

/// TPEX 融資融券資料
class TpexMarginTrading {
  const TpexMarginTrading({
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

  final DateTime date;
  final String code;
  final String name;
  final double marginBuy; // 融資買進
  final double marginSell; // 融資賣出
  final double marginBalance; // 融資餘額
  final double shortBuy; // 融券買進 (回補)
  final double shortSell; // 融券賣出
  final double shortBalance; // 融券餘額

  /// 融資增減
  double get marginNet => marginBuy - marginSell;

  /// 融券增減
  double get shortNet => shortSell - shortBuy;
}
