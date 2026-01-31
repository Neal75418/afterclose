import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/api_endpoints.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';

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
        final date = _parseAdDate(dateStr);

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
        final dateFormatted =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  /// 解析 YYYYMMDD 格式的西元日期（例如 "20260121"）
  ///
  /// 回傳本地時間午夜以匹配資料庫儲存格式
  DateTime _parseAdDate(String dateStr) {
    if (dateStr.length != 8) {
      // 預設為今日本地時間午夜
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));
    final day = int.parse(dateStr.substring(6, 8));
    return DateTime(year, month, day);
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
        open: _parseFormattedDouble(row[4]),
        high: _parseFormattedDouble(row[5]),
        low: _parseFormattedDouble(row[6]),
        close: _parseFormattedDouble(row[7]),
        volume: _parseFormattedDouble(row[2]),
        change: _parseFormattedDouble(row[8]),
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得所有股票的法人買賣超資料
  ///
  /// 端點: /rwd/zh/fund/T86（三大法人買賣超日報）
  Future<List<TwseInstitutional>> getAllInstitutionalData({
    DateTime? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'response': 'json',
        'selectType': 'ALLBUT0999',
      };

      if (date != null) {
        // 格式: YYYYMMDD
        final dateStr =
            '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        queryParams['date'] = dateStr;
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
        final date = _parseAdDate(dateStr);

        // 解析資料陣列
        final List<dynamic> rows = data['data'];
        final results = rows
            .map((row) => _parseInstitutionalRow(row as List<dynamic>, date))
            .whereType<TwseInstitutional>()
            .toList();

        final dateFormatted =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
        foreignBuy: _parseFormattedDouble(row[2]) ?? 0,
        foreignSell: _parseFormattedDouble(row[3]) ?? 0,
        foreignNet: _parseFormattedDouble(row[4]) ?? 0,
        investmentTrustBuy: _parseFormattedDouble(row[8]) ?? 0,
        investmentTrustSell: _parseFormattedDouble(row[9]) ?? 0,
        investmentTrustNet: _parseFormattedDouble(row[10]) ?? 0,
        dealerBuy: _parseFormattedDouble(row[11]) ?? 0,
        dealerSell: _parseFormattedDouble(row[12]) ?? 0,
        dealerNet: _parseFormattedDouble(row[13]) ?? 0,
        totalNet: _parseFormattedDouble(row[17]) ?? 0,
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
      final date = _parseSlashRocDate(dateStr);

      return TwseDailyPrice(
        date: date,
        code: code,
        name: '', // 歷史資料不含名稱
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

  /// 解析含斜線的民國日期（例如 "115/01/02"）
  ///
  /// 回傳本地時間午夜以匹配資料庫儲存格式
  DateTime _parseSlashRocDate(String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length != 3) {
      throw FormatException('Invalid ROC date: $dateStr');
    }

    final rocYear = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    return DateTime(rocYear + ApiConfig.rocYearOffset, month, day);
  }

  /// 解析含逗號的數字（例如 "1,234,567"）
  double? _parseFormattedDouble(dynamic value) {
    if (value == null) return null;
    final str = value.toString().replaceAll(',', '').trim();
    if (str.isEmpty || str == '--' || str == 'X') return null;
    return double.tryParse(str);
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
        final date = _parseAdDate(dateStr);

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

        final dateFormatted =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
        marginBuy: _parseFormattedDouble(row[2]) ?? 0,
        marginSell: _parseFormattedDouble(row[3]) ?? 0,
        marginBalance: _parseFormattedDouble(row[6]) ?? 0,
        shortBuy: _parseFormattedDouble(row[8]) ?? 0,
        shortSell: _parseFormattedDouble(row[9]) ?? 0,
        shortBalance: _parseFormattedDouble(row[12]) ?? 0,
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
      final dateStr =
          '${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}';

      final response = await _dio.get(
        '/exchangeReport/TWTB4U',
        queryParameters: {'response': 'json', 'date': dateStr},
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
      final totalVolume = _parseFormattedDouble(row[3]) ?? 0;
      // 欄位 4 是買進金額，欄位 5 是賣出金額
      final buyAmount = _parseFormattedDouble(row[4]) ?? 0;
      final sellAmount = _parseFormattedDouble(row[5]) ?? 0;

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
  Future<List<TwseMarketIndex>> getMarketIndices() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.twseMarketIndex,
        queryParameters: {'response': 'json', 'type': 'IND'},
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
        final date = _parseAdDate(dateStr);

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

      final close = _parseFormattedDouble(row[1]);
      if (close == null) return null; // 沒有收盤值的跳過

      // row[2] 為漲跌方向符號：「+」或「-」或「X」/空值
      final dirSign = row[2]?.toString().trim() ?? '';
      final rawChange = _parseFormattedDouble(row[3]) ?? 0;
      final rawChangePercent = _parseFormattedDouble(row[4]) ?? 0;

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
  // Killer Features API (注意/處置股票)
  // ==========================================

  /// 取得上市注意股票清單
  ///
  /// 端點: /rwd/zh/announcement/TWTAVU
  ///
  /// 回傳交易量異常、價格異常波動的股票清單。
  Future<List<TwseTradingWarning>> getTradingWarnings({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr =
          '${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}';

      final response = await _dio.get(
        ApiEndpoints.twseTradingWarning,
        queryParameters: {'response': 'json', 'date': dateStr},
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
          if (row is List && row.length >= 3) {
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
  /// 列格式: [代號, 名稱, 列入原因說明, ...]
  TwseTradingWarning? _parseTradingWarningRow(
    List<dynamic> row,
    DateTime date,
  ) {
    try {
      final code = row[0]?.toString().trim() ?? '';
      if (code.isEmpty || code.length < 4) return null;

      return TwseTradingWarning(
        date: date,
        code: code,
        name: row[1]?.toString().trim() ?? '',
        reasonDescription: row.length > 2 ? row[2]?.toString().trim() : null,
        warningType: 'ATTENTION',
      );
    } catch (_) {
      return null;
    }
  }

  /// 取得上市處置股票清單
  ///
  /// 端點: /rwd/zh/announcement/TWTAUU
  ///
  /// 回傳交易受限制的股票清單。
  Future<List<TwseTradingWarning>> getDisposalInfo({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr =
          '${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}';

      final response = await _dio.get(
        ApiEndpoints.twseDisposal,
        queryParameters: {'response': 'json', 'date': dateStr},
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
          if (row is List && row.length >= 3) {
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
  /// 列格式: [代號, 名稱, 列入原因, 處置措施, 處置起日, 處置迄日, ...]
  TwseTradingWarning? _parseDisposalRow(List<dynamic> row, DateTime date) {
    try {
      final code = row[0]?.toString().trim() ?? '';
      if (code.isEmpty || code.length < 4) return null;

      // 解析處置期間日期（格式可能是 "115/01/20" 或 "1150120"）
      DateTime? parseDate(String? dateStr) {
        if (dateStr == null || dateStr.isEmpty) return null;
        // 嘗試解析 "115/01/20" 格式
        if (dateStr.contains('/')) {
          return _parseSlashRocDate(dateStr);
        }
        // 嘗試解析 "1150120" 格式
        if (dateStr.length == 7) {
          final rocYear = int.tryParse(dateStr.substring(0, 3)) ?? 0;
          final month = int.tryParse(dateStr.substring(3, 5)) ?? 1;
          final day = int.tryParse(dateStr.substring(5, 7)) ?? 1;
          if (rocYear > 0) {
            return DateTime(rocYear + ApiConfig.rocYearOffset, month, day);
          }
        }
        return null;
      }

      return TwseTradingWarning(
        date: date,
        code: code,
        name: row[1]?.toString().trim() ?? '',
        reasonDescription: row.length > 2 ? row[2]?.toString().trim() : null,
        disposalMeasures: row.length > 3 ? row[3]?.toString().trim() : null,
        disposalStartDate: row.length > 4
            ? parseDate(row[4]?.toString())
            : null,
        disposalEndDate: row.length > 5 ? parseDate(row[5]?.toString()) : null,
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
        final companyData = <String, _TwseInsiderAggregation>{};

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
          final date = _parseCompactRocDate(dateStr);
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
            () => _TwseInsiderAggregation(
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

  /// 解析緊湊型民國日期（格式：1150120）
  DateTime? _parseCompactRocDate(String? dateStr) {
    if (dateStr == null || dateStr.length != 7) return null;
    final rocYear = int.tryParse(dateStr.substring(0, 3));
    final month = int.tryParse(dateStr.substring(3, 5));
    final day = int.tryParse(dateStr.substring(5, 7));
    if (rocYear == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(rocYear + ApiConfig.rocYearOffset, month, day);
  }
}

// ============================================
// Helper Classes
// ============================================

/// 彙總董監持股用的內部 helper class
class _TwseInsiderAggregation {
  _TwseInsiderAggregation({
    required this.code,
    required this.name,
    required this.date,
  });

  final String code;
  final String name;
  final DateTime date;
  double totalShares = 0;
  double totalPledged = 0;
  final _seenHolders = <String>{};

  void addHoldingIfNew(String holderName, double shares, double pledged) {
    if (holderName.isEmpty) return;
    if (_seenHolders.contains(holderName)) return;
    _seenHolders.add(holderName);
    totalShares += shares;
    totalPledged += pledged;
  }
}

// ============================================
// 資料模型
// ============================================

/// TWSE 董監持股資料（彙總後）
class TwseInsiderHolding {
  const TwseInsiderHolding({
    required this.date,
    required this.code,
    required this.name,
    this.insiderRatio,
    this.pledgeRatio,
    this.sharesIssued,
  });

  final DateTime date;
  final String code;
  final String name;
  final double? insiderRatio; // 董監持股比例 (%)
  final double? pledgeRatio; // 質押比例 (%)
  final double? sharesIssued; // 已發行股數
}

/// TWSE Open Data 月營收資料
class TwseMonthlyRevenue {
  const TwseMonthlyRevenue({
    required this.year,
    required this.month,
    required this.code,
    required this.name,
    required this.revenue,
    required this.momGrowth,
    required this.yoyGrowth,
  });

  factory TwseMonthlyRevenue.fromJson(Map<String, dynamic> json) {
    // 欄位: "資料年月"(11201), "公司代號", "公司名稱", "營業收入-當月營收",
    // "營業收入-上月比較增減(%)", "營業收入-去年同月增減(%)"

    final ym = json['資料年月']?.toString() ?? '';
    int year = 0;
    int month = 0;
    if (ym.length >= 5) {
      final yStr = ym.substring(0, ym.length - 2);
      final mStr = ym.substring(ym.length - 2);
      year = (int.tryParse(yStr) ?? 0) + ApiConfig.rocYearOffset;
      month = int.tryParse(mStr) ?? 0;
    }

    // 解析含逗號的數字字串（OpenData 通常沒有，但以防萬一）
    double parseVal(String? key) {
      if (key == null) return 0.0;
      final val = json[key]?.toString() ?? '';
      return double.tryParse(val.replaceAll(',', '')) ?? 0.0;
    }

    return TwseMonthlyRevenue(
      year: year,
      month: month,
      code: json['公司代號']?.toString() ?? '',
      name: json['公司名稱']?.toString() ?? '',
      revenue: parseVal('營業收入-當月營收'),
      momGrowth: parseVal('營業收入-上月比較增減(%)'),
      yoyGrowth: parseVal('營業收入-去年同月增減(%)'),
    );
  }

  final int year;
  final int month;
  final String code;
  final String name;
  final double revenue; // 千元（通常）
  final double momGrowth; // 月增率 %
  final double yoyGrowth; // 年增率 %
}

/// TWSE 每日價格資料
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

    // 將民國日期解析為 DateTime
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
    } catch (e) {
      AppLogger.debug('TWSE', '解析 TwseDailyPrice 失敗: ${json['Code']}');
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

  /// 將 TWSE 民國日期（例如 "1150119"）轉換為 DateTime
  ///
  /// 回傳 UTC 午夜時間以確保跨時區一致性
  static DateTime _parseRocDate(String rocDate) {
    if (rocDate.length != 7) {
      throw FormatException('Invalid ROC date format: $rocDate');
    }

    final rocYear = int.parse(rocDate.substring(0, 3));
    final month = int.parse(rocDate.substring(3, 5));
    final day = int.parse(rocDate.substring(5, 7));

    // 民國年 + ApiConfig.rocYearOffset = 西元年
    final adYear = rocYear + ApiConfig.rocYearOffset;

    return DateTime(adYear, month, day);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      // 移除數字中的逗號（例如 "1,234,567"）
      final cleaned = value.replaceAll(',', '').trim();
      if (cleaned.isEmpty || cleaned == '--') return null;
      return double.tryParse(cleaned);
    }
    return null;
  }
}

/// TWSE 法人買賣超資料
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
      date: dateStr != null
          ? TwseDailyPrice._parseRocDate(dateStr.toString())
          : DateTime.now(),
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
    } catch (e) {
      AppLogger.debug('TWSE', '解析 TwseInstitutional 失敗: ${json['Code']}');
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

/// TWSE 融資融券資料
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
      date: dateStr != null
          ? TwseDailyPrice._parseRocDate(dateStr.toString())
          : DateTime.now(),
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
    } catch (e) {
      AppLogger.debug('TWSE', '解析 TwseMarginTrading 失敗: ${json['Code']}');
      return null;
    }
  }

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

/// TWSE 估值資料（BWIBBU_d）
class TwseValuation {
  const TwseValuation({
    required this.date,
    required this.code,
    this.per,
    this.dividendYield,
    this.pbr,
  });

  final DateTime date;
  final String code;
  final double? per;
  final double? dividendYield;
  final double? pbr;
}

/// TWSE 當沖資料（TWTB4U）
///
/// **重要:** TWSE TWTB4U API 提供的是買賣金額（新台幣），
/// 而非成交量（股數）。欄位名稱維持 "volume" 以相容 FinMind 資料，
/// 但實際存放的是金額。
/// [ratio] 需另行從每日價格成交量資料計算。
class TwseDayTrading {
  const TwseDayTrading({
    required this.date,
    required this.code,
    required this.name,
    required this.buyVolume,
    required this.sellVolume,
    required this.totalVolume,
    required this.ratio,
  });

  final DateTime date;
  final String code;
  final String name;

  /// 當沖買進金額 (NT$) - Note: TWSE provides amounts, not volumes
  final double buyVolume;

  /// 當沖賣出金額 (NT$) - Note: TWSE provides amounts, not volumes
  final double sellVolume;

  /// 當沖成交股數 (shares)
  final double totalVolume;

  /// 當沖比例 (%) - calculated from daily price volume
  final double ratio;

  /// 是否為高當沖比例 (>= 30%)
  bool get isHighRatio => ratio >= 30.0;

  /// 是否為極高當沖比例 (>= 50%)
  bool get isExtremeRatio => ratio >= 50.0;
}

/// TWSE 大盤指數資料
class TwseMarketIndex {
  const TwseMarketIndex({
    required this.date,
    required this.name,
    required this.close,
    required this.change,
    required this.changePercent,
  });

  final DateTime date;

  /// 指數名稱（如「發行量加權股價指數」、「電子類指數」）
  final String name;

  /// 收盤指數
  final double close;

  /// 漲跌點數
  final double change;

  /// 漲跌百分比（%）
  final double changePercent;

  /// 是否上漲
  bool get isUp => change > 0;

  /// 是否下跌
  bool get isDown => change < 0;
}

/// TWSE 注意/處置股票資料
class TwseTradingWarning {
  const TwseTradingWarning({
    required this.date,
    required this.code,
    required this.name,
    required this.warningType,
    this.reasonCode,
    this.reasonDescription,
    this.disposalMeasures,
    this.disposalStartDate,
    this.disposalEndDate,
  });

  final DateTime date;
  final String code;
  final String name;
  final String warningType; // 'ATTENTION' | 'DISPOSAL'
  final String? reasonCode; // 列入原因代碼
  final String? reasonDescription; // 原因說明
  final String? disposalMeasures; // 處置措施（僅處置股）
  final DateTime? disposalStartDate; // 處置起始日
  final DateTime? disposalEndDate; // 處置結束日

  /// 是否為處置股
  bool get isDisposal => warningType == 'DISPOSAL';

  /// 處置是否目前生效
  bool get isActive {
    if (!isDisposal) return true; // 注意股票始終視為生效
    if (disposalEndDate == null) return true;
    return DateTime.now().isBefore(
      disposalEndDate!.add(const Duration(days: 1)),
    );
  }
}
