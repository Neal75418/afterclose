import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/api_endpoints.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/tw_parse_utils.dart';
import 'package:afterclose/data/models/twse/models.dart';

export 'package:afterclose/data/models/twse/models.dart';

/// 台灣證券交易所 (TWSE) API 客戶端
///
/// 提供免費存取台股市場資料。
/// 使用 TWSE 官方網站 JSON API 以取得更快的資料更新。
/// 無需認證。
///
/// API 來源:
/// - 每日股價: https://www.twse.com.tw/rwd/zh/afterTrading/STOCK_DAY_ALL
/// - 歷史資料: https://www.twse.com.tw/exchangeReport/STOCK_DAY
class TwseClient {
  TwseClient({Dio? dio}) : _dio = dio ?? _createDio();

  /// TWSE 官方網站基礎 URL（比 Open Data API 更新更快）
  static const String _baseUrl = ApiEndpoints.twseBaseUrl;

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
          // 加入 User-Agent 模擬瀏覽器請求
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
        // 確保 JSON 回應在所有平台正確解析
        responseType: ResponseType.json,
      ),
    );
  }

  /// 取得最新交易日所有股票價格
  ///
  /// 回傳所有上市股票的 OHLCV 資料。
  /// 使用 TWSE 官方網站 API，更新速度比 Open Data API 快。
  ///
  /// 端點: /rwd/zh/afterTrading/STOCK_DAY_ALL
  Future<List<TwseDailyPrice>> getAllDailyPrices() async {
    try {
      final response = await _dio.get(
        '/rwd/zh/afterTrading/STOCK_DAY_ALL',
        queryParameters: {'response': 'json'},
      );

      if (response.statusCode == 200) {
        // 處理 String 和 Map 兩種回應（iOS 可能回傳 String）
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TWSE', '全市場價格: JSON 解析失敗');
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TWSE', '全市場價格: 非預期資料型別');
          return [];
        }

        // 檢查回應狀態
        final stat = data['stat'];
        if (stat != 'OK' || data['data'] == null) {
          AppLogger.warning('TWSE', '全市場價格: 無資料 (stat=$stat)');
          return [];
        }

        // 從回應解析日期（格式: YYYYMMDD）
        final dateStr = data['date']?.toString() ?? '';
        final date = TwParseUtils.parseAdDate(dateStr);

        // 解析資料陣列（每列是 List 而非 Map）
        final List<dynamic> rows = data['data'];
        var failedCount = 0;
        final prices = <TwseDailyPrice>[];

        for (final row in rows) {
          final parsed = _parseDailyPriceRow(row as List<dynamic>, date);
          if (parsed != null) {
            prices.add(parsed);
          } else {
            failedCount++;
          }
        }

        // 統一輸出結果
        final dateFormatted = TwParseUtils.formatDateYmd(date);
        if (failedCount > 0) {
          AppLogger.info(
            'TWSE',
            '全市場價格: ${prices.length} 筆 ($dateFormatted, 略過 $failedCount 筆)',
          );
        } else {
          AppLogger.info('TWSE', '全市場價格: ${prices.length} 筆 ($dateFormatted)');
        }
        return prices;
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        AppLogger.warning('TWSE', '全市場價格: 連線逾時');
        throw NetworkException('TWSE connection timeout', e);
      }
      AppLogger.warning('TWSE', '全市場價格: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TWSE network error', e);
    } catch (e, stack) {
      AppLogger.error('TWSE', '全市場價格: 非預期錯誤', e, stack);
      rethrow;
    }
  }

  /// 解析每日價格資料列
  ///
  /// 列格式: [代號, 名稱, 成交股數, 成交金額, 開盤價, 最高價, 最低價, 收盤價, 漲跌價差, 成交筆數]
  TwseDailyPrice? _parseDailyPriceRow(List<dynamic> row, DateTime date) {
    try {
      if (row.length < 10) return null;

      final code = row[0]?.toString() ?? '';
      if (code.isEmpty) return null;

      return TwseDailyPrice(
        date: date,
        code: code,
        name: row[1]?.toString() ?? '',
        open: TwParseUtils.parseFormattedDouble(row[4]),
        high: TwParseUtils.parseFormattedDouble(row[5]),
        low: TwParseUtils.parseFormattedDouble(row[6]),
        close: TwParseUtils.parseFormattedDouble(row[7]),
        volume: TwParseUtils.parseFormattedDouble(row[2]),
        change: TwParseUtils.parseFormattedDouble(row[8]),
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得所有股票的法人買賣超資料
  ///
  /// 端點: /rwd/zh/fund/T86（三大法人買賣超日報）
  /// 注意：TWSE API 回傳的是「股數」，存入資料庫時需除以 1000 轉換為「張」
  Future<List<TwseInstitutional>> getAllInstitutionalData({
    DateTime? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'response': 'json',
        'selectType': 'ALLBUT0999',
      };

      if (date != null) {
        queryParams['date'] = TwParseUtils.formatDateCompact(date);
      }

      final response = await _dio.get(
        '/rwd/zh/fund/T86',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 檢查回應狀態
        if (data['stat'] != 'OK' || data['data'] == null) {
          return [];
        }

        // 從回應解析日期
        final dateStr = data['date']?.toString() ?? '';
        final date = TwParseUtils.parseAdDate(dateStr);

        // 解析資料陣列
        final List<dynamic> rows = data['data'];
        final results = rows
            .map((row) => _parseInstitutionalRow(row as List<dynamic>, date))
            .whereType<TwseInstitutional>()
            .toList();

        final dateFormatted = TwParseUtils.formatDateYmd(date);
        AppLogger.info('TWSE', '法人資料: ${results.length} 筆 ($dateFormatted)');
        return results;
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TWSE', '法人資料: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TWSE network error', e);
    }
  }

  /// 解析法人資料列
  ///
  /// 列格式: [代號, 名稱, 外資買, 外資賣, 外資淨買, 外資自營買, 外資自營賣, 外資自營淨買,
  ///         投信買, 投信賣, 投信淨買, 自營買, 自營賣, 自營淨買, 自營避險買, 自營避險賣, 自營避險淨買, 三大法人淨買]
  TwseInstitutional? _parseInstitutionalRow(List<dynamic> row, DateTime date) {
    try {
      if (row.length < 18) return null;

      final code = row[0]?.toString() ?? '';
      if (code.isEmpty) return null;

      return TwseInstitutional(
        date: date,
        code: code,
        name: row[1]?.toString() ?? '',
        foreignBuy: TwParseUtils.parseFormattedDouble(row[2]) ?? 0,
        foreignSell: TwParseUtils.parseFormattedDouble(row[3]) ?? 0,
        foreignNet: TwParseUtils.parseFormattedDouble(row[4]) ?? 0,
        investmentTrustBuy: TwParseUtils.parseFormattedDouble(row[8]) ?? 0,
        investmentTrustSell: TwParseUtils.parseFormattedDouble(row[9]) ?? 0,
        investmentTrustNet: TwParseUtils.parseFormattedDouble(row[10]) ?? 0,
        dealerBuy: TwParseUtils.parseFormattedDouble(row[11]) ?? 0,
        dealerSell: TwParseUtils.parseFormattedDouble(row[12]) ?? 0,
        dealerNet: TwParseUtils.parseFormattedDouble(row[13]) ?? 0,
        totalNet: TwParseUtils.parseFormattedDouble(row[17]) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得特定股票的歷史價格（每次一個月）
  ///
  /// [code] - 股票代碼（例如 "2330"）
  /// [year] - 西元年（例如 2026）
  /// [month] - 月份（1-12）
  ///
  /// 端點: /exchangeReport/STOCK_DAY
  ///
  /// 參數無效時拋出 [ArgumentError]
  Future<List<TwseDailyPrice>> getStockMonthlyPrices({
    required String code,
    required int year,
    required int month,
  }) async {
    // 驗證股票代碼（台股通常為 4-6 碼數字）
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

    // 驗證年份（TWSE 歷史資料的合理範圍）
    if (year < 1990 || year > 2100) {
      throw ArgumentError.value(
        year,
        'year',
        'Year must be between 1990 and 2100',
      );
    }

    // 驗證月份
    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        month,
        'month',
        'Month must be between 1 and 12',
      );
    }

    // 防止未來日期
    final now = DateTime.now();
    if (year > now.year || (year == now.year && month > now.month)) {
      throw ArgumentError('Cannot fetch data for future dates: $year/$month');
    }

    try {
      // 格式化日期為 YYYYMMDD（該月第一天）
      final dateStr = '$year${month.toString().padLeft(2, '0')}01';

      final response = await _dio.get(
        '${ApiEndpoints.twseBaseUrl}${ApiEndpoints.twseStockDay}',
        queryParameters: {'response': 'json', 'date': dateStr, 'stockNo': code},
      );

      if (response.statusCode == 200) {
        // 處理 iOS Dio 回傳 String 而非 Map 的情況
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['stat'] != 'OK' || data['data'] == null) {
          return [];
        }

        final List<dynamic> rows = data['data'];
        final results = rows
            .map((row) => _parseHistoricalRow(row as List<dynamic>, code))
            .whereType<TwseDailyPrice>()
            .toList();
        AppLogger.debug(
          'TWSE',
          '月價格($code): $year/$month -> ${results.length} 筆',
        );
        return results;
      }

      throw ApiException(
        'TWSE historical API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'TWSE historical API error', e);
    }
  }

  /// 解析 TWSE 歷史資料列
  TwseDailyPrice? _parseHistoricalRow(List<dynamic> row, String code) {
    try {
      // 列格式: [日期, 成交股數, 成交金額, 開盤價, 最高價, 最低價, 收盤價, 漲跌價差, 成交筆數, ...]
      if (row.length < 9) return null;

      final dateStr = row[0].toString(); // 格式: "115/01/02"
      final date = TwParseUtils.parseSlashRocDate(dateStr);
      if (date == null) return null;

      return TwseDailyPrice(
        date: date,
        code: code,
        name: '', // 歷史資料不含名稱
        open: TwParseUtils.parseFormattedDouble(row[3]),
        high: TwParseUtils.parseFormattedDouble(row[4]),
        low: TwParseUtils.parseFormattedDouble(row[5]),
        close: TwParseUtils.parseFormattedDouble(row[6]),
        volume: TwParseUtils.parseFormattedDouble(row[1]),
        change: TwParseUtils.parseFormattedDouble(row[7]),
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得多個月的歷史價格
  ///
  /// [code] - 股票代碼（4-6 碼數字）
  /// [months] - 要擷取的月數（預設: 6，最大: 60）
  /// [delayBetweenRequests] - API 呼叫間的延遲（預設: 300ms）
  ///
  /// 註: TWSE 可能會限制流量，因此在呼叫間加入延遲。
  ///
  /// 參數無效時拋出 [ArgumentError]
  Future<List<TwseDailyPrice>> getStockHistoricalPrices({
    required String code,
    int months = 6,
    Duration delayBetweenRequests = const Duration(milliseconds: 300),
  }) async {
    // 驗證股票代碼
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

    // 驗證月數（合理範圍以避免過多 API 呼叫）
    if (months < 1 || months > 60) {
      throw ArgumentError.value(
        months,
        'months',
        'Months must be between 1 and 60',
      );
    }

    // 驗證延遲（最少 100ms 以避免流量限制）
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
      } catch (e) {
        // 記錄錯誤但繼續處理其他月份
        AppLogger.debug(
          'TWSE',
          '歷史價格($code): ${targetDate.year}/${targetDate.month} 取得失敗: $e',
        );
      }

      // 流量限制延遲
      if (i < months - 1) {
        await Future.delayed(delayBetweenRequests);
      }
    }

    // 依日期升冪排序
    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  /// 取得所有股票的融資融券資料
  ///
  /// 端點: /rwd/zh/marginTrading/MI_MARGN（融資融券餘額）
  Future<List<TwseMarginTrading>> getAllMarginTradingData() async {
    try {
      final response = await _dio.get(
        '/rwd/zh/marginTrading/MI_MARGN',
        queryParameters: {'response': 'json', 'selectType': 'ALL'},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 檢查回應狀態
        if (data['stat'] != 'OK') {
          return [];
        }

        // 從回應解析日期
        final dateStr = data['date']?.toString() ?? '';
        final date = TwParseUtils.parseAdDate(dateStr);

        // 資料在 'tables' 陣列中，第二個表格含個股資料
        final tables = data['tables'] as List<dynamic>?;
        if (tables == null || tables.length < 2) {
          return [];
        }

        final stockTable = tables[1] as Map<String, dynamic>;
        final List<dynamic> rows = stockTable['data'] ?? [];

        final results = rows
            .map((row) => _parseMarginTradingRow(row as List<dynamic>, date))
            .whereType<TwseMarginTrading>()
            .toList();

        final dateFormatted = TwParseUtils.formatDateYmd(date);
        AppLogger.info('TWSE', '融資融券: ${results.length} 筆 ($dateFormatted)');
        return results;
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TWSE', '融資融券: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TWSE network error', e);
    }
  }

  /// 解析融資融券資料列
  ///
  /// 列格式: [代號, 名稱, 融資買進, 融資賣出, 融資現償, 融資前餘, 融資今餘, 融資限額,
  ///         融券買進, 融券賣出, 融券現償, 融券前餘, 融券今餘, 融券限額, 資券互抵, 備註]
  TwseMarginTrading? _parseMarginTradingRow(List<dynamic> row, DateTime date) {
    try {
      if (row.length < 14) return null;

      final code = row[0]?.toString() ?? '';
      if (code.isEmpty) return null;

      return TwseMarginTrading(
        date: date,
        code: code,
        name: row[1]?.toString() ?? '',
        marginBuy: TwParseUtils.parseFormattedDouble(row[2]) ?? 0,
        marginSell: TwParseUtils.parseFormattedDouble(row[3]) ?? 0,
        marginBalance: TwParseUtils.parseFormattedDouble(row[6]) ?? 0,
        shortBuy: TwParseUtils.parseFormattedDouble(row[8]) ?? 0,
        shortSell: TwParseUtils.parseFormattedDouble(row[9]) ?? 0,
        shortBalance: TwParseUtils.parseFormattedDouble(row[12]) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得所有股票的估值資料（本益比、股價淨值比、殖利率）
  ///
  /// 使用 TWSE Open Data API 取得可靠的結構化資料
  /// 端點: https://openapi.twse.com.tw/v1/exchangeReport/BWIBBU_ALL
  Future<List<TwseValuation>> getAllStockValuation({DateTime? date}) async {
    try {
      // 建立獨立的 Dio 以避免基礎 URL 衝突
      // Open Data 欄位: Code, Name, PEratio, DividendYield, PBratio
      final response = await Dio().get(
        ApiEndpoints.twseValuation,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = response.data;
        final resDate = DateTime.now(); // Open Data 總是回傳最新資料

        final results = list.map((item) {
          final map = item as Map<String, dynamic>;

          final code = map['Code']?.toString() ?? '';

          final peStr = map['PEratio']?.toString().replaceAll(',', '');
          final yieldStr = map['DividendYield']?.toString().replaceAll(',', '');
          final pbrStr = map['PBratio']?.toString().replaceAll(',', '');

          final pe = double.tryParse(peStr ?? '') ?? 0.0;
          final pbr = double.tryParse(pbrStr ?? '') ?? 0.0;
          final yieldVal = double.tryParse(yieldStr ?? '') ?? 0.0;

          return TwseValuation(
            code: code,
            date: resDate,
            per: pe,
            pbr: pbr,
            dividendYield: yieldVal,
          );
        }).toList();

        AppLogger.info('TWSE', '估值資料: ${results.length} 筆');
        return results;
      }

      return [];
    } catch (e) {
      AppLogger.warning('TWSE', '估值資料: 取得失敗');
      return [];
    }
  }

  /// 取得所有股票的月營收（最新月份）
  ///
  /// 來源: TWSE Open Data API (t187ap05_L)
  /// 端點: https://openapi.twse.com.tw/v1/opendata/t187ap05_L
  ///
  /// 此 API 回傳所有上市公司的最新營收資料。
  /// 比透過 FinMind 逐檔擷取快得多。
  Future<List<TwseMonthlyRevenue>> getAllMonthlyRevenue() async {
    try {
      // 使用完整 URL 以覆蓋基礎 URL (www.twse.com.tw)
      final response = await _dio.get(ApiEndpoints.twseMonthlyRevenue);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final results = data
            .map(
              (json) =>
                  TwseMonthlyRevenue.fromJson(json as Map<String, dynamic>),
            )
            .toList();
        AppLogger.info('TWSE', '月營收: ${results.length} 筆');
        return results;
      }
      return [];
    } catch (e) {
      AppLogger.warning('TWSE', '月營收: 取得失敗');
      return [];
    }
  }

  /// 取得所有股票的當沖資料
  ///
  /// 端點: /exchangeReport/TWTB4U（當日沖銷交易標的）
  /// 免費 API，無需 token。
  Future<List<TwseDayTrading>> getAllDayTradingData({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();

      final response = await _dio.get(
        '/exchangeReport/TWTB4U',
        queryParameters: {
          'response': 'json',
          'date': TwParseUtils.formatDateCompact(targetDate),
        },
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.data);
        if (data == null || data['stat'] != 'OK') {
          return [];
        }

        // TWTB4U 回傳多個表格。我們需要含詳細個股資料的那個。
        // 通常是第二個表格，但以防萬一用標題來找。
        List<dynamic> rows = [];

        if (data.containsKey('tables')) {
          final List<dynamic> tables = data['tables'];
          for (final table in tables) {
            final title = table['title']?.toString() ?? '';
            // 尋找「當日沖銷交易標的」
            if (title.contains('當日沖銷交易標的')) {
              rows = table['data'] ?? [];
              break;
            }
          }
          // 若以標題找不到，則嘗試從第二個表格（索引 1）載入作為備案
          if (rows.isEmpty && tables.length > 1) {
            rows = tables[1]['data'] ?? [];
          }
        } else {
          // 以防萬一的舊格式備案
          rows = data['data'] ?? [];
        }

        final result = <TwseDayTrading>[];

        for (final row in rows) {
          if (row is List) {
            if (row.length >= 6) {
              final parsed = _parseDayTradingRow(row, targetDate);
              if (parsed != null) {
                result.add(parsed);
              }
            }
          }
        }

        AppLogger.info('TWSE', '當沖資料: ${result.length} 筆');
        return result;
      }
      return [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        AppLogger.warning('TWSE', '當沖資料: 連線逾時');
        throw NetworkException('TWSE connection timeout', e);
      }
      AppLogger.warning('TWSE', '當沖資料: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TWSE network error', e);
    } catch (e, stack) {
      AppLogger.error('TWSE', '當沖資料: 非預期錯誤', e, stack);
      return [];
    }
  }

  /// 解析當沖資料列
  ///
  /// 列格式: [代號, 名稱, (空), 當沖成交股數, 當沖買進金額, 當沖賣出金額]
  /// 註: TWSE TWTB4U API 不提供比例，需另行計算
  TwseDayTrading? _parseDayTradingRow(List<dynamic> row, DateTime date) {
    try {
      final code = row[0]?.toString().trim() ?? '';
      if (code.isEmpty || code.length < 4) return null;

      final name = row[1]?.toString().trim() ?? '';
      // 欄位 3 是當沖成交股數
      final totalVolume = TwParseUtils.parseFormattedDouble(row[3]) ?? 0;
      // 欄位 4 是買進金額，欄位 5 是賣出金額
      final buyAmount = TwParseUtils.parseFormattedDouble(row[4]) ?? 0;
      final sellAmount = TwParseUtils.parseFormattedDouble(row[5]) ?? 0;

      return TwseDayTrading(
        date: date,
        code: code,
        name: name,
        buyVolume: buyAmount, // 暫時存金額
        sellVolume: sellAmount,
        totalVolume: totalVolume,
        ratio: 0, // 比例需要稍後計算
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // 大盤指數 API
  // ==========================================

  /// 取得大盤各類指數收盤行情
  ///
  /// 端點: /rwd/zh/afterTrading/MI_INDEX
  /// 回傳加權指數、電子類指數、金融保險類指數等
  ///
  /// [date] 可選，指定日期取歷史指數（格式 YYYYMMDD）。省略則取最新。
  Future<List<TwseMarketIndex>> getMarketIndices({DateTime? date}) async {
    try {
      final queryParams = <String, dynamic>{'response': 'json', 'type': 'IND'};
      if (date != null) {
        queryParams['date'] = TwParseUtils.formatDateCompact(date);
      }

      final response = await _dio.get(
        ApiEndpoints.twseMarketIndex,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TWSE', '大盤指數: JSON 解析失敗');
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TWSE', '大盤指數: 非預期資料型別');
          return [];
        }

        if (data['stat'] != 'OK') {
          AppLogger.warning('TWSE', '大盤指數: stat=${data['stat']}，可能為非交易日或盤中');
          return [];
        }

        final results = <TwseMarketIndex>[];

        // 解析日期
        final dateStr = data['date']?.toString() ?? '';
        final date = TwParseUtils.parseAdDate(dateStr);

        // MI_INDEX 回傳多個 tables，每個 table 包含不同類型的指數
        // 我們關注的重點指數通常在前幾個 tables 中
        final tables = data['tables'] as List<dynamic>?;
        if (tables == null || tables.isEmpty) {
          // 嘗試直接從 data 取得（舊格式）
          final rows = data['data'] as List<dynamic>?;
          if (rows != null) {
            for (final row in rows) {
              final parsed = _parseMarketIndexRow(row as List<dynamic>, date);
              if (parsed != null) results.add(parsed);
            }
          }
        } else {
          // 新格式：遍歷所有 tables
          for (var ti = 0; ti < tables.length; ti++) {
            final table = tables[ti] as Map<String, dynamic>;
            final title = table['title']?.toString() ?? '';
            final rows = table['data'] as List<dynamic>?;
            if (rows == null || rows.isEmpty) continue;
            var parsedInTable = 0;
            for (final row in rows) {
              final parsed = _parseMarketIndexRow(row as List<dynamic>, date);
              if (parsed != null) {
                results.add(parsed);
                parsedInTable++;
              }
            }
            if (parsedInTable == 0) {
              // 記錄第一筆資料以利診斷格式問題
              final sample = rows.first;
              AppLogger.debug(
                'TWSE',
                '大盤指數 table[$ti] "$title": ${rows.length} 行全部跳過，'
                    '樣本=${sample is List ? sample.take(3).toList() : sample}',
              );
            }
          }
        }

        if (results.isEmpty) {
          AppLogger.warning(
            'TWSE',
            '大盤指數: 解析後 0 筆 (tables=${tables?.length ?? 0})',
          );
        } else {
          AppLogger.debug('TWSE', '大盤指數 API 原始: ${results.length} 筆');
        }
        return results;
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TWSE', '大盤指數: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TWSE network error', e);
    } catch (e, stack) {
      AppLogger.error('TWSE', '大盤指數: 非預期錯誤', e, stack);
      rethrow;
    }
  }

  /// 解析大盤指數資料列
  ///
  /// 列格式: [指數名稱, 收盤指數, 漲跌(+/-), 漲跌點數, 漲跌百分比(%), 特殊處理欄位]
  ///
  /// 注意：TWSE API 的 row[3]（漲跌點數）和 row[4]（漲跌百分比）為絕對值，
  /// 漲跌方向由 row[2] 的符號（`+` 或 `-`）決定。
  TwseMarketIndex? _parseMarketIndexRow(List<dynamic> row, DateTime date) {
    try {
      if (row.length < 5) return null;

      final name = row[0]?.toString().trim() ?? '';
      if (name.isEmpty) return null;

      final close = TwParseUtils.parseFormattedDouble(row[1]);
      if (close == null) return null; // 沒有收盤值的跳過

      // row[2] 為漲跌方向符號：「+」或「-」或「X」/空值
      final dirSign = row[2]?.toString().trim() ?? '';
      final rawChange = TwParseUtils.parseFormattedDouble(row[3]) ?? 0;
      final rawChangePercent = TwParseUtils.parseFormattedDouble(row[4]) ?? 0;

      // 根據方向符號套用正負號；無明確符號時保留原值（通常為 0）
      final change = dirSign.contains('-')
          ? -rawChange.abs()
          : dirSign.contains('+')
          ? rawChange.abs()
          : rawChange;
      final changePercent = dirSign.contains('-')
          ? -rawChangePercent.abs()
          : dirSign.contains('+')
          ? rawChangePercent.abs()
          : rawChangePercent;

      return TwseMarketIndex(
        date: date,
        name: name,
        close: close,
        change: change,
        changePercent: changePercent,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // 三大法人買賣金額統計 API
  // ==========================================

  /// 取得三大法人買賣金額統計（市場總計）
  ///
  /// 端點: /rwd/zh/fund/BFI82U
  /// 回傳外資、投信、自營商的買賣金額（元），可用於大盤總覽顯示
  ///
  /// [date] 可選，指定日期。省略則取最新。
  Future<TwseInstitutionalAmounts?> getInstitutionalAmounts({
    DateTime? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{'response': 'json'};
      if (date != null) {
        queryParams['dayDate'] = TwParseUtils.formatDateCompact(date);
      }

      final response = await _dio.get(
        ApiEndpoints.twseInstitutionalAmounts,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TWSE', '法人金額統計: JSON 解析失敗');
            return null;
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TWSE', '法人金額統計: 非預期資料型別');
          return null;
        }

        if (data['stat'] != 'OK' || data['data'] == null) {
          AppLogger.warning('TWSE', '法人金額統計: 無資料');
          return null;
        }

        // 解析日期
        final dateStr = data['date']?.toString() ?? '';
        final parsedDate = TwParseUtils.parseAdDate(dateStr);

        // data 結構:
        // [["自營商(自行買賣)", "買進", "賣出", "買賣差額"],
        //  ["自營商(避險)", ...],
        //  ["投信", ...],
        //  ["外資及陸資(不含外資自營商)", ...],
        //  ["外資自營商", ...],
        //  ["合計", ...]]
        final rows = data['data'] as List<dynamic>;

        double foreignNet = 0;
        double trustNet = 0;
        double dealerNet = 0;
        double dealerHedgeNet = 0;

        for (final row in rows) {
          if (row is! List || row.length < 4) continue;
          final name = row[0]?.toString() ?? '';
          final netAmount = TwParseUtils.parseFormattedDouble(row[3]) ?? 0;

          if (name.contains('外資及陸資') && name.contains('不含')) {
            // 匹配「外資及陸資(不含外資自營商)」
            foreignNet = netAmount;
          } else if (name == '投信') {
            trustNet = netAmount;
          } else if (name == '自營商(自行買賣)') {
            dealerNet = netAmount;
          } else if (name == '自營商(避險)') {
            dealerHedgeNet = netAmount;
          }
        }

        return TwseInstitutionalAmounts(
          date: parsedDate,
          foreignNet: foreignNet,
          trustNet: trustNet,
          dealerNet: dealerNet + dealerHedgeNet, // 合併自營商
        );
      }
    } catch (e) {
      AppLogger.warning('TWSE', '法人金額統計: $e');
    }
    return null;
  }

  // ==========================================
  // Killer Features API (注意/處置股票)
  // ==========================================

  /// 取得上市注意股票清單
  ///
  /// 端點: /rwd/zh/announcement/notice
  ///
  /// 回傳交易量異常、價格異常波動的股票清單。
  /// 2025 年後端點變更，查詢參數改為 startDate/endDate。
  Future<List<TwseTradingWarning>> getTradingWarnings({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr = TwParseUtils.formatDateCompact(targetDate);

      final response = await _dio.get(
        ApiEndpoints.twseTradingWarning,
        queryParameters: {
          'response': 'json',
          'startDate': dateStr,
          'endDate': dateStr,
        },
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TWSE', '注意股票: JSON 解析失敗');
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TWSE', '注意股票: 非預期資料型別');
          return [];
        }

        if (data['stat'] != 'OK' || data['data'] == null) {
          AppLogger.warning('TWSE', '注意股票: 無資料');
          return [];
        }

        final List<dynamic> rows = data['data'];
        final results = <TwseTradingWarning>[];

        for (final row in rows) {
          // 新格式有 8 欄
          if (row is List && row.length >= 5) {
            final parsed = _parseTradingWarningRow(row, targetDate);
            if (parsed != null) {
              results.add(parsed);
            }
          }
        }

        AppLogger.info('TWSE', '注意股票: ${results.length} 筆');
        return results;
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TWSE', '注意股票: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TWSE network error', e);
    }
  }

  /// 解析注意股票資料列
  ///
  /// 2025 年後新格式:
  /// [編號, 證券代號, 證券名稱, 累計次數, 注意交易資訊, 日期, 收盤價, 本益比]
  TwseTradingWarning? _parseTradingWarningRow(
    List<dynamic> row,
    DateTime date,
  ) {
    try {
      // 新格式: index 1 是證券代號
      final code = row[1]?.toString().trim() ?? '';
      if (code.isEmpty || code.length < 4) return null;

      return TwseTradingWarning(
        date: date,
        code: code,
        name: row[2]?.toString().trim() ?? '',
        reasonDescription: row.length > 4 ? row[4]?.toString().trim() : null,
        warningType: 'ATTENTION',
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得上市處置股票清單
  ///
  /// 端點: /rwd/zh/announcement/punish
  ///
  /// 回傳交易受限制的股票清單。
  /// 2025 年後端點變更，回傳現行有效的處置股票清單（無需日期參數）。
  Future<List<TwseTradingWarning>> getDisposalInfo({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();

      final response = await _dio.get(
        ApiEndpoints.twseDisposal,
        queryParameters: {'response': 'json'},
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TWSE', '處置股票: JSON 解析失敗');
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning('TWSE', '處置股票: 非預期資料型別');
          return [];
        }

        if (data['stat'] != 'OK' || data['data'] == null) {
          AppLogger.warning('TWSE', '處置股票: 無資料');
          return [];
        }

        final List<dynamic> rows = data['data'];
        final results = <TwseTradingWarning>[];

        for (final row in rows) {
          // 新格式有 10 欄
          if (row is List && row.length >= 7) {
            final parsed = _parseDisposalRow(row, targetDate);
            if (parsed != null) {
              results.add(parsed);
            }
          }
        }

        AppLogger.info('TWSE', '處置股票: ${results.length} 筆');
        return results;
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TWSE', '處置股票: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TWSE network error', e);
    }
  }

  /// 解析處置股票資料列
  ///
  /// 2025 年後新格式:
  /// [編號, 公布日期, 證券代號, 證券名稱, 累計, 處置條件, 處置起迄時間, 處置措施, 處置內容, 備註]
  TwseTradingWarning? _parseDisposalRow(List<dynamic> row, DateTime date) {
    try {
      // 新格式: index 2 是證券代號
      final code = row[2]?.toString().trim() ?? '';
      if (code.isEmpty || code.length < 4) return null;

      // 解析處置期間（格式: "115/01/29～115/02/11"）
      DateTime? startDate;
      DateTime? endDate;
      final dateRange = row.length > 6 ? row[6]?.toString().trim() : null;
      if (dateRange != null && dateRange.contains('～')) {
        final parts = dateRange.split('～');
        if (parts.length == 2) {
          startDate = TwParseUtils.parseSlashRocDate(parts[0].trim());
          endDate = TwParseUtils.parseSlashRocDate(parts[1].trim());
        }
      }

      return TwseTradingWarning(
        date: date,
        code: code,
        name: row[3]?.toString().trim() ?? '',
        reasonDescription: row.length > 8 ? row[8]?.toString().trim() : null,
        disposalMeasures: row.length > 7 ? row[7]?.toString().trim() : null,
        disposalStartDate: startDate,
        disposalEndDate: endDate,
        warningType: 'DISPOSAL',
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得上市董監持股資料（彙總版）
  ///
  /// 使用 TWSE OpenData，免費無限制。
  /// 1. 從 t187ap03_L 取得已發行股數
  /// 2. 從 t187ap11_L 取得個別董監持股記錄
  /// 3. 彙總計算每家公司的董監持股比例和質押比例
  ///
  /// 回傳彙總後的董監事持股資料（每家公司一筆）。
  Future<List<TwseInsiderHolding>> getInsiderHoldings() async {
    try {
      // 1. 取得已發行股數
      final stockInfoResponse = await _dio.get(
        ApiEndpoints.twseStockInfo,
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
            final code = item['公司代號']?.toString().trim() ?? '';
            // TWSE OpenData API 欄位名稱：已發行普通股數或TDR原股發行股數
            final shares = item['已發行普通股數或TDR原股發行股數']?.toString().replaceAll(
              ',',
              '',
            );
            if (code.isNotEmpty && shares != null) {
              final sharesNum = double.tryParse(shares);
              if (sharesNum != null && sharesNum > 0) {
                issuedSharesMap[code] = sharesNum;
              }
            }
          }
        }
      }

      AppLogger.debug('TWSE', '已發行股數: ${issuedSharesMap.length} 家公司');

      // 2. 取得個別董監持股記錄
      final response = await _dio.get(
        ApiEndpoints.twseInsiderHolding,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TWSE', '董監持股: JSON 解析失敗');
            return [];
          }
        }

        if (data is! List) {
          AppLogger.warning('TWSE', '董監持股: 非預期資料型別');
          return [];
        }

        // 3. 彙總計算每家公司的董監持股
        final companyData = <String, TwseInsiderAggregation>{};

        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;

          final code = item['公司代號']?.toString().trim() ?? '';
          if (code.isEmpty || code.length < 4) continue;

          final companyName = item['公司名稱']?.toString().trim() ?? '';
          final position = item['職稱']?.toString() ?? '';
          final personName = item['姓名']?.toString().trim() ?? '';

          // 只計算董事和監察人的「本人」記錄
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

          // 彙總（使用姓名去重）
          companyData.putIfAbsent(
            code,
            () => TwseInsiderAggregation(
              code: code,
              name: companyName,
              date: date,
            ),
          );
          companyData[code]!.addHoldingIfNew(personName, shares, pledged);
        }

        // 4. 計算比例並建立結果
        final results = <TwseInsiderHolding>[];
        for (final agg in companyData.values) {
          final issuedShares = issuedSharesMap[agg.code];
          if (issuedShares == null || issuedShares <= 0) continue;

          final insiderRatio = (agg.totalShares / issuedShares) * 100;
          final pledgeRatio = agg.totalShares > 0
              ? (agg.totalPledged / agg.totalShares) * 100
              : 0.0;

          results.add(
            TwseInsiderHolding(
              date: agg.date,
              code: agg.code,
              name: agg.name,
              insiderRatio: insiderRatio,
              pledgeRatio: pledgeRatio,
              sharesIssued: issuedShares,
            ),
          );
        }

        AppLogger.info('TWSE', '董監持股彙總: ${results.length} 家公司');
        return results;
      }

      throw ApiException(
        'TWSE OpenData error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.warning('TWSE', '董監持股: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TWSE network error', e);
    }
  }
}
