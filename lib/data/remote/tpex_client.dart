import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/api_endpoints.dart';
import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/models/tpex/models.dart';
import 'package:afterclose/core/utils/tw_parse_utils.dart';
export 'package:afterclose/data/models/tpex/models.dart';

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
      final rocDateStr = TwParseUtils.toRocDateString(targetDate);

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
        final actualDate =
            (dateStr != null
                ? TwParseUtils.parseSlashRocDate(dateStr)
                : null) ??
            targetDate;

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
        final dateFormatted = TwParseUtils.formatDateYmd(actualDate);
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
        close: TwParseUtils.parseFormattedDouble(row[2]),
        change: TwParseUtils.parseFormattedDouble(row[3]),
        open: TwParseUtils.parseFormattedDouble(row[4]),
        high: TwParseUtils.parseFormattedDouble(row[5]),
        low: TwParseUtils.parseFormattedDouble(row[6]),
        volume: TwParseUtils.parseFormattedDouble(row[8]),
        turnover: TwParseUtils.parseFormattedDouble(row[9]),
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
      final rocDateStr = TwParseUtils.toRocDateString(targetDate);

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
        final actualDate =
            (dateStr != null
                ? TwParseUtils.parseSlashRocDate(dateStr)
                : null) ??
            targetDate;

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

        final dateFormatted = TwParseUtils.formatDateYmd(actualDate);
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
  ///
  /// 注意：TPEX API 回傳的是「股數」，存入資料庫時需除以 1000 轉換為「張」
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
        foreignBuy: TwParseUtils.parseFormattedDouble(row[8]) ?? 0,
        foreignSell: TwParseUtils.parseFormattedDouble(row[9]) ?? 0,
        foreignNet: TwParseUtils.parseFormattedDouble(row[10]) ?? 0,
        // 投信 - indices 11-13
        investmentTrustBuy: TwParseUtils.parseFormattedDouble(row[11]) ?? 0,
        investmentTrustSell: TwParseUtils.parseFormattedDouble(row[12]) ?? 0,
        investmentTrustNet: TwParseUtils.parseFormattedDouble(row[13]) ?? 0,
        // 自營商(合計) - indices 20-22
        dealerBuy: TwParseUtils.parseFormattedDouble(row[20]) ?? 0,
        dealerSell: TwParseUtils.parseFormattedDouble(row[21]) ?? 0,
        dealerNet: TwParseUtils.parseFormattedDouble(row[22]) ?? 0,
        // 三大法人合計 - index 23
        totalNet: TwParseUtils.parseFormattedDouble(row[23]) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得三大法人買賣金額統計（市場總計）
  ///
  /// 端點: /web/stock/3insti/3insti_summary/3itrdsum_result.php
  /// 回傳外資、投信、自營商的買賣金額（元），可用於大盤總覽顯示
  ///
  /// [date] 可選，指定日期。省略則取最新。
  Future<TpexInstitutionalAmounts?> getInstitutionalAmounts({
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final rocDateStr = TwParseUtils.toRocDateString(targetDate);

      final response = await _dio.get(
        ApiEndpoints.tpexInstitutionalAmounts,
        queryParameters: {'l': 'zh-tw', 'd': rocDateStr, 't': 'D', 'o': 'json'},
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '法人金額統計: JSON 解析失敗');
            return null;
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TPEX', '法人金額統計: 非預期資料型別');
          return null;
        }

        final tables = data['tables'] as List<dynamic>?;
        if (tables == null || tables.isEmpty) {
          AppLogger.warning('TPEX', '法人金額統計: 無 tables');
          return null;
        }

        final firstTable = tables[0] as Map<String, dynamic>?;
        if (firstTable == null) {
          AppLogger.warning('TPEX', '法人金額統計: 無資料表');
          return null;
        }

        // 從回傳資料取得實際日期
        final dateStr = firstTable['date'] as String?;
        final actualDate =
            (dateStr != null
                ? TwParseUtils.parseSlashRocDate(dateStr)
                : null) ??
            targetDate;

        final rows = firstTable['data'] as List<dynamic>?;
        if (rows == null || rows.isEmpty) {
          AppLogger.warning('TPEX', '法人金額統計: 無資料');
          return null;
        }

        // data 結構:
        // [["外資及陸資合計", "買進金額", "賣出金額", "買賣超"],
        //  ["　外資及陸資(不含自營商)", ...],
        //  ["　外資自營商", ...],
        //  ["投信", ...],
        //  ["自營商合計", ...], ...]
        double foreignNet = 0;
        double trustNet = 0;
        double dealerNet = 0;

        for (final row in rows) {
          if (row is! List || row.length < 4) continue;
          final name = row[0]?.toString().trim() ?? '';
          final netAmount = TwParseUtils.parseFormattedDouble(row[3]) ?? 0;

          // 使用「外資及陸資(不含自營商)」而非合計，與 TWSE 一致
          if (name.contains('外資及陸資') && name.contains('不含')) {
            foreignNet = netAmount;
          } else if (name == '投信') {
            trustNet = netAmount;
          } else if (name == '自營商合計') {
            dealerNet = netAmount;
          }
        }

        return TpexInstitutionalAmounts(
          date: actualDate,
          foreignNet: foreignNet,
          trustNet: trustNet,
          dealerNet: dealerNet,
        );
      }
    } catch (e) {
      AppLogger.warning('TPEX', '法人金額統計: $e');
    }
    return null;
  }

  /// 取得所有上櫃股票的估值資料（本益比、股價淨值比、殖利率）
  ///
  /// 使用 TPEX OpenAPI，免費無限制。
  /// 端點: /openapi/v1/tpex_mainboard_peratio_analysis
  ///
  /// 回傳所有上櫃股票的估值資料，一次 API 呼叫取得全市場。
  Future<List<TpexValuation>> getAllValuation({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();

      // TPEX OpenAPI 只回傳最新資料，不接受日期參數
      final response = await _dio.get(
        ApiEndpoints.tpexValuation,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '估值資料: JSON 解析失敗');
            return [];
          }
        }

        if (data is! List) {
          AppLogger.warning('TPEX', '估值資料: 非預期資料型別 (expected List)');
          return [];
        }

        // 解析 JSON 陣列
        final results = <TpexValuation>[];
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;

          final parsed = _parseValuationItem(item, targetDate);
          if (parsed != null) {
            results.add(parsed);
          }
        }

        // 估值 API 不回傳統一日期欄位，使用第一筆資料的日期或 targetDate
        final effectiveDate = results.isNotEmpty
            ? results.first.date
            : targetDate;
        final dateFormatted = TwParseUtils.formatDateYmd(effectiveDate);
        AppLogger.info('TPEX', '估值資料: ${results.length} 筆 ($dateFormatted)');
        return results;
      }

      throw ApiException(
        'TPEX OpenAPI error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TPEX', '估值資料: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TPEX network error', e);
    }
  }

  /// 解析估值資料項目
  ///
  /// JSON 格式:
  /// {
  ///   "Date": "1150126",           // 民國年月日 YYYMMDD
  ///   "SecuritiesCompanyCode": "1240",
  ///   "CompanyName": "茂達",
  ///   "PriceEarningRatio": "12.34",
  ///   "DividendPerShare": "2.50",
  ///   "YieldRatio": "3.45",
  ///   "PriceBookRatio": "1.23"
  /// }
  TpexValuation? _parseValuationItem(
    Map<String, dynamic> json,
    DateTime fallbackDate,
  ) {
    try {
      final code = json['SecuritiesCompanyCode']?.toString().trim() ?? '';
      if (code.isEmpty) return null;

      // 過濾非股票代碼（上櫃股票為 4 碼數字）
      if (!StockPatterns.isTpexCode(code)) return null;

      // 解析日期（使用共用驗證方法，無效時使用 fallback）
      final actualDate =
          TwParseUtils.parseCompactRocDate(json['Date']?.toString()) ??
          fallbackDate;

      // 解析數值（"N/A" 視為 null）
      double? parsePer(dynamic value) {
        if (value == null || value == 'N/A' || value == '') return null;
        return double.tryParse(value.toString());
      }

      return TpexValuation(
        date: actualDate,
        code: code,
        name: json['CompanyName']?.toString().trim() ?? '',
        per: parsePer(json['PriceEarningRatio']),
        pbr: parsePer(json['PriceBookRatio']),
        dividendYield: parsePer(json['YieldRatio']),
        dividendPerShare: parsePer(json['DividendPerShare']),
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得所有上櫃股票的當沖交易資料
  ///
  /// 使用 TPEX 官方 API，免費無需 token。
  /// 端點: /web/stock/aftertrading/daily_trading_info/st43_result.php
  ///
  /// 回傳所有上櫃股票的當沖資料，一次 API 呼叫取得全市場。
  /// 比透過 FinMind 逐檔同步快很多，且不消耗 FinMind 配額。
  ///
  /// **注意**: 此端點可能被 Cloudflare 保護，會回傳空清單。
  /// 當沖資料對規則分析非必要，不影響主要功能。
  Future<List<TpexDayTrading>> getAllDayTradingData({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final rocDateStr = TwParseUtils.toRocDateString(targetDate);

      final response = await _dio.get(
        ApiEndpoints.tpexDayTrading,
        queryParameters: {'l': 'zh-tw', 'd': rocDateStr, 'o': 'json'},
        options: Options(
          // 不跟隨重定向，以便偵測 Cloudflare 302 回應
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      // 偵測 302 重定向（通常是 Cloudflare 阻擋）
      if (response.statusCode == 302) {
        final location = response.headers.value('location') ?? '';
        if (location.contains('error')) {
          AppLogger.debug('TPEX', '當沖 API 被 Cloudflare 阻擋 (302 重定向)');
          return [];
        }
      }

      if (response.statusCode == 200) {
        var data = response.data;

        // 檢查是否為 HTML 錯誤頁面（而非 JSON）
        if (data is String) {
          // 偵測 HTML 錯誤頁面
          if (data.contains('<!DOCTYPE') ||
              data.contains('<html') ||
              data.contains('error')) {
            AppLogger.debug('TPEX', '當沖 API 回傳錯誤頁面 (可能被 Cloudflare 阻擋)');
            return [];
          }

          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.debug('TPEX', '當沖 API 回傳非 JSON 格式');
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.debug('TPEX', '當沖資料: 非預期資料型別');
          return [];
        }

        // TPEX API 回傳格式: { tables: [{ data: [...] }] }
        final tables = data['tables'] as List<dynamic>?;
        if (tables == null || tables.isEmpty) {
          AppLogger.debug('TPEX', '當沖資料: 無 tables (可能無該日資料)');
          return [];
        }

        final firstTable = tables[0] as Map<String, dynamic>?;
        if (firstTable == null) {
          AppLogger.debug('TPEX', '當沖資料: 無資料表');
          return [];
        }

        // 從回傳資料取得實際日期
        final dateStr = firstTable['date'] as String?;
        final actualDate =
            (dateStr != null
                ? TwParseUtils.parseSlashRocDate(dateStr)
                : null) ??
            targetDate;

        final List<dynamic>? rows = firstTable['data'] as List<dynamic>?;
        if (rows == null || rows.isEmpty) {
          AppLogger.debug('TPEX', '當沖資料: 無資料 (該日可能無交易)');
          return [];
        }

        // 解析資料陣列
        final results = rows
            .map((row) => _parseDayTradingRow(row as List<dynamic>, actualDate))
            .whereType<TpexDayTrading>()
            .toList();

        final dateFormatted = TwParseUtils.formatDateYmd(actualDate);
        AppLogger.info('TPEX', '當沖資料: ${results.length} 筆 ($dateFormatted)');
        return results;
      }

      throw ApiException(
        'TPEX API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      // 處理重定向相關錯誤
      if (e.response?.statusCode == 302) {
        AppLogger.debug('TPEX', '當沖 API 被阻擋 (302)');
        return [];
      }
      AppLogger.debug('TPEX', '當沖資料: ${e.message ?? "網路錯誤"}');
      // 當沖資料非必要，回傳空清單而非拋出例外
      return [];
    }
  }

  /// 解析當沖資料列
  ///
  /// TPEX 欄位格式 (9 欄):
  /// [0] 代號, [1] 名稱
  /// [2] 當沖買進成交股數, [3] 當沖買進成交金額(元)
  /// [4] 當沖賣出成交股數, [5] 當沖賣出成交金額(元)
  /// [6] 當沖現股買進成交股數, [7] 當沖現股賣出成交股數
  /// [8] 當沖成交股數
  TpexDayTrading? _parseDayTradingRow(List<dynamic> row, DateTime date) {
    try {
      if (row.length < 9) return null;

      final code = row[0]?.toString().trim() ?? '';
      if (code.isEmpty) return null;

      // 過濾非股票代碼（上櫃股票為 4 碼數字）
      if (!StockPatterns.isTpexCode(code)) return null;

      final buyVolume = TwParseUtils.parseFormattedDouble(row[2]) ?? 0;
      final sellVolume = TwParseUtils.parseFormattedDouble(row[4]) ?? 0;
      final totalVolume = TwParseUtils.parseFormattedDouble(row[8]) ?? 0;

      return TpexDayTrading(
        date: date,
        code: code,
        name: row[1]?.toString().trim() ?? '',
        buyVolume: buyVolume,
        sellVolume: sellVolume,
        totalVolume: totalVolume,
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得所有上櫃股票的融資融券資料
  ///
  /// 端點: /web/stock/margin_trading/margin_sbl/margin_sbl_result.php
  Future<List<TpexMarginTrading>> getAllMarginTradingData({
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final rocDateStr = TwParseUtils.toRocDateString(targetDate);

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
        final actualDate =
            (dateStr != null
                ? TwParseUtils.parseSlashRocDate(dateStr)
                : null) ??
            targetDate;

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

        final dateFormatted = TwParseUtils.formatDateYmd(actualDate);
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
        marginBuy: TwParseUtils.parseFormattedDouble(row[4]) ?? 0,
        marginSell: TwParseUtils.parseFormattedDouble(row[3]) ?? 0,
        marginBalance: TwParseUtils.parseFormattedDouble(row[6]) ?? 0,
        // 融券
        shortBuy: TwParseUtils.parseFormattedDouble(row[10]) ?? 0, // 還券
        shortSell: TwParseUtils.parseFormattedDouble(row[9]) ?? 0, // 賣出
        shortBalance: TwParseUtils.parseFormattedDouble(row[12]) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // Killer Features API (免費 OpenAPI)
  // ==========================================

  /// 取得上櫃注意股票清單
  ///
  /// 使用 TPEX OpenAPI，免費無限制。
  /// 端點: /openapi/v1/tpex_trading_warning_information
  ///
  /// 回傳交易量異常、價格異常波動的股票清單。
  Future<List<TpexTradingWarning>> getTradingWarnings() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.tpexTradingWarning,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '注意股票: JSON 解析失敗');
            return [];
          }
        }

        if (data is! List) {
          AppLogger.warning('TPEX', '注意股票: 非預期資料型別');
          return [];
        }

        final results = <TpexTradingWarning>[];
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          final parsed = _parseTradingWarningItem(item);
          if (parsed != null) {
            results.add(parsed);
          }
        }

        AppLogger.info('TPEX', '注意股票: ${results.length} 筆');
        return results;
      }

      throw ApiException(
        'TPEX OpenAPI error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TPEX', '注意股票: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TPEX network error', e);
    }
  }

  /// 解析注意股票項目
  ///
  /// 無效日期時回傳 null，避免污染資料庫。
  TpexTradingWarning? _parseTradingWarningItem(Map<String, dynamic> json) {
    try {
      final code = json['SecuritiesCompanyCode']?.toString().trim() ?? '';
      if (code.isEmpty) return null;

      // 解析公告日期（格式: "1150126" -> 民國 115 年 01 月 26 日）
      // TPEX OpenAPI 使用 "Date" 欄位
      final dateStr = json['Date']?.toString();
      final date = TwParseUtils.parseCompactRocDate(dateStr);
      if (date == null) {
        AppLogger.debug('TPEX', '注意股票日期解析失敗: code=$code, date=$dateStr');
        return null;
      }

      return TpexTradingWarning(
        date: date,
        code: code,
        name: json['CompanyName']?.toString().trim() ?? '',
        // TPEX OpenAPI 欄位: TradingInformation（交易資訊說明）
        reasonDescription: json['TradingInformation']?.toString().trim(),
        warningType: 'ATTENTION',
      );
    } catch (e) {
      AppLogger.debug('TPEX', '注意股票項目解析失敗: $e');
      return null;
    }
  }

  /// 取得上櫃處置股票清單
  ///
  /// 使用 TPEX OpenAPI，免費無限制。
  /// 端點: /openapi/v1/tpex_disposal_information
  ///
  /// 回傳交易受限制的股票清單。
  Future<List<TpexTradingWarning>> getDisposalInfo() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.tpexDisposal,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '處置股票: JSON 解析失敗');
            return [];
          }
        }

        if (data is! List) {
          AppLogger.warning('TPEX', '處置股票: 非預期資料型別');
          return [];
        }

        final results = <TpexTradingWarning>[];
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          final parsed = _parseDisposalItem(item);
          if (parsed != null) {
            results.add(parsed);
          }
        }

        AppLogger.info('TPEX', '處置股票: ${results.length} 筆');
        return results;
      }

      throw ApiException(
        'TPEX OpenAPI error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TPEX', '處置股票: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TPEX network error', e);
    }
  }

  /// 解析處置股票項目
  ///
  /// 無效日期時回傳 null，避免污染資料庫。
  TpexTradingWarning? _parseDisposalItem(Map<String, dynamic> json) {
    try {
      final code = json['SecuritiesCompanyCode']?.toString().trim() ?? '';
      if (code.isEmpty) return null;

      // 解析公告日期（必要欄位）
      // TPEX OpenAPI 使用 "Date" 欄位
      final dateStr = json['Date']?.toString();
      final date = TwParseUtils.parseCompactRocDate(dateStr);
      if (date == null) {
        AppLogger.debug('TPEX', '處置股票日期解析失敗: code=$code, date=$dateStr');
        return null;
      }

      // 解析處置起訖日期（從 DispositionPeriod 欄位，格式: "1150126~1150206"）
      DateTime? startDate;
      DateTime? endDate;
      final periodStr = json['DispositionPeriod']?.toString();
      if (periodStr != null && periodStr.contains('~')) {
        final parts = periodStr.split('~');
        if (parts.length == 2) {
          startDate = TwParseUtils.parseCompactRocDate(parts[0].trim());
          endDate = TwParseUtils.parseCompactRocDate(parts[1].trim());
        }
      }

      return TpexTradingWarning(
        date: date,
        code: code,
        name: json['CompanyName']?.toString().trim() ?? '',
        // TPEX OpenAPI 欄位: DispositionReasons（處置原因）
        reasonDescription: json['DispositionReasons']?.toString().trim(),
        // TPEX OpenAPI 欄位: DisposalCondition（處置措施說明）
        disposalMeasures: json['DisposalCondition']?.toString().trim(),
        disposalStartDate: startDate,
        disposalEndDate: endDate,
        warningType: 'DISPOSAL',
      );
    } catch (e) {
      AppLogger.debug('TPEX', '處置股票項目解析失敗: $e');
      return null;
    }
  }

  /// 取得上櫃董監持股資料（彙總版）
  ///
  /// 使用 TPEX OpenAPI，免費無限制。
  /// 1. 從 mopsfin_t187ap03_O 取得已發行股數
  /// 2. 從 mopsfin_t187ap11_O 取得個別董監持股記錄
  /// 3. 彙總計算每家公司的董監持股比例和質押比例
  ///
  /// 回傳彙總後的董監事持股資料（每家公司一筆）。
  Future<List<TpexInsiderHolding>> getInsiderHoldings() async {
    try {
      // 1. 取得已發行股數
      final stockInfoResponse = await _dio.get(
        ApiEndpoints.tpexStockInfo,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final issuedSharesMap = <String, double>{};
      if (stockInfoResponse.statusCode == 200) {
        var stockData = stockInfoResponse.data;
        if (stockData is String) {
          stockData = jsonDecode(stockData);
        }
        if (stockData is List) {
          for (final item in stockData) {
            if (item is! Map<String, dynamic>) continue;
            final code = item['SecuritiesCompanyCode']?.toString().trim() ?? '';
            final shares = item['IssueShares']?.toString().replaceAll(',', '');
            if (code.isNotEmpty && shares != null) {
              final sharesNum = double.tryParse(shares);
              if (sharesNum != null && sharesNum > 0) {
                issuedSharesMap[code] = sharesNum;
              }
            }
          }
        }
      }

      AppLogger.debug('TPEX', '已發行股數: ${issuedSharesMap.length} 家公司');

      // 2. 取得個別董監持股記錄
      final response = await _dio.get(
        ApiEndpoints.tpexInsiderHolding,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '董監持股: JSON 解析失敗');
            return [];
          }
        }

        if (data is! List) {
          AppLogger.warning('TPEX', '董監持股: 非預期資料型別');
          return [];
        }

        // 3. 彙總計算每家公司的董監持股
        // 使用 Map<公司代碼, Map<持股人姓名, 持股資料>> 來去重
        final companyData = <String, InsiderAggregation>{};

        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;

          final code = item['公司代號']?.toString().trim() ?? '';
          if (code.isEmpty || !StockPatterns.isTpexCode(code)) continue;

          final companyName = item['公司名稱']?.toString().trim() ?? '';
          final position = item['職稱']?.toString() ?? '';
          final personName = item['姓名']?.toString().trim() ?? '';

          // 只計算董事和監察人的「本人」記錄
          // 職稱格式：「董事長本人」「董事本人」「獨立董事本人」「監察人本人」
          // 排除「法人代表人」避免重複計算（法人的持股已在法人本人記錄中）
          // 排除：總經理、副總經理、經理、大股東、財務/會計主管
          final isDirectorOrSupervisor =
              (position.contains('董事') || position.contains('監察人')) &&
              position.endsWith('本人');
          if (!isDirectorOrSupervisor) continue;

          // 解析日期
          final dateStr = item['出表日期']?.toString();
          final date = TwParseUtils.parseCompactRocDate(dateStr);
          if (date == null) continue;

          // 解析持股和質押數
          final sharesStr = item['目前持股']?.toString().replaceAll(',', '') ?? '0';
          final pledgedStr =
              item['設質股數']?.toString().replaceAll(',', '') ?? '0';
          final shares = double.tryParse(sharesStr) ?? 0;
          final pledged = double.tryParse(pledgedStr) ?? 0;

          // 彙總（使用姓名去重，同一人可能有多個職稱但持股相同）
          companyData.putIfAbsent(
            code,
            () => InsiderAggregation(code: code, name: companyName, date: date),
          );
          // 只有新的持股人才加入統計
          companyData[code]!.addHoldingIfNew(personName, shares, pledged);
        }

        // 4. 計算比例並建立結果
        final results = <TpexInsiderHolding>[];
        for (final agg in companyData.values) {
          final issuedShares = issuedSharesMap[agg.code];
          if (issuedShares == null || issuedShares <= 0) continue;

          final insiderRatio = (agg.totalShares / issuedShares) * 100;
          final pledgeRatio = agg.totalShares > 0
              ? (agg.totalPledged / agg.totalShares) * 100
              : 0.0;

          results.add(
            TpexInsiderHolding(
              date: agg.date,
              code: agg.code,
              name: agg.name,
              insiderRatio: insiderRatio,
              pledgeRatio: pledgeRatio,
              sharesIssued: issuedShares,
            ),
          );
        }

        AppLogger.info('TPEX', '董監持股彙總: ${results.length} 家公司');
        return results;
      }

      throw ApiException(
        'TPEX OpenAPI error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TPEX', '董監持股: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TPEX network error', e);
    }
  }

  /// 取得上櫃公司每月營業收入彙總表
  ///
  /// 使用 TPEX OpenAPI，免費無限制。
  /// 端點: /openapi/v1/mopsfin_t187ap05_O
  ///
  /// 回傳所有上櫃公司的月營收資料，包含月增率和年增率。
  /// 一次 API 呼叫取得全市場資料，取代 FinMind 批次 API。
  Future<List<TpexMonthlyRevenue>> getAllMonthlyRevenue() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.tpexMonthlyRevenue,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TPEX', '月營收: JSON 解析失敗');
            return [];
          }
        }

        if (data is! List) {
          AppLogger.warning('TPEX', '月營收: 非預期資料型別');
          return [];
        }

        final results = <TpexMonthlyRevenue>[];
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          final parsed = _parseMonthlyRevenueItem(item);
          if (parsed != null) {
            results.add(parsed);
          }
        }

        AppLogger.info('TPEX', '月營收: ${results.length} 筆');
        return results;
      }

      throw ApiException(
        'TPEX OpenAPI error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TPEX', '月營收: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TPEX network error', e);
    }
  }

  /// 解析月營收項目
  ///
  /// JSON 格式:
  /// {
  ///   "出表日期": "1150117",
  ///   "資料年月": "11412",           // 民國年月 YYYMM
  ///   "公司代號": "1240",
  ///   "公司名稱": "茂生農經",
  ///   "營業收入-當月營收": "240962",  // 千元
  ///   "營業收入-上月比較增減(%)": "8.26",
  ///   "營業收入-去年同月增減(%)": "-7.42",
  ///   ...
  /// }
  TpexMonthlyRevenue? _parseMonthlyRevenueItem(Map<String, dynamic> json) {
    try {
      final code = json['公司代號']?.toString().trim() ?? '';
      if (code.isEmpty) return null;

      // 過濾非股票代碼
      if (!StockPatterns.isTpexCode(code)) return null;

      // 解析資料年月（格式: "11412" -> 民國 114 年 12 月）
      final dataYearMonth = json['資料年月']?.toString() ?? '';
      if (dataYearMonth.length < 5) return null;

      final rocYear = int.tryParse(dataYearMonth.substring(0, 3));
      final month = int.tryParse(dataYearMonth.substring(3));
      if (rocYear == null || month == null) return null;
      if (month < 1 || month > 12) return null;

      final year = rocYear + 1911; // 轉換為西元年
      final date = DateTime(year, month);

      // 解析數值
      double? parseValue(dynamic value) {
        if (value == null || value == '' || value == '-') return null;
        final str = value.toString().replaceAll(',', '').trim();
        if (str.isEmpty) return null;
        return double.tryParse(str);
      }

      return TpexMonthlyRevenue(
        date: date,
        code: code,
        name: json['公司名稱']?.toString().trim() ?? '',
        revenue: parseValue(json['營業收入-當月營收']) ?? 0,
        revenueYear: year,
        revenueMonth: month,
        momGrowth: parseValue(json['營業收入-上月比較增減(%)']),
        yoyGrowth: parseValue(json['營業收入-去年同月增減(%)']),
      );
    } catch (e) {
      AppLogger.debug('TPEX', '月營收項目解析失敗: $e');
      return null;
    }
  }
}
