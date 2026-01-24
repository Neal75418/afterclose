import 'dart:convert';

import 'package:dio/dio.dart';

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
  static const String _baseUrl = 'https://www.twse.com.tw';

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
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
      AppLogger.info('TwseClient', 'Fetching all daily prices from TWSE...');

      final response = await _dio.get(
        '/rwd/zh/afterTrading/STOCK_DAY_ALL',
        queryParameters: {'response': 'json'},
      );

      AppLogger.info(
        'TwseClient',
        'TWSE response: statusCode=${response.statusCode}, '
            'dataType=${response.data?.runtimeType}',
      );

      if (response.statusCode == 200) {
        // 處理 String 和 Map 兩種回應（iOS 可能回傳 String）
        var data = response.data;
        if (data is String) {
          AppLogger.info('TwseClient', 'Response is String, parsing as JSON');
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.error('TwseClient', 'Failed to parse JSON response', e);
            return [];
          }
        }

        if (data is! Map<String, dynamic>) {
          AppLogger.warning(
            'TwseClient',
            'Unexpected data type: ${data.runtimeType}',
          );
          return [];
        }

        // 檢查回應狀態
        final stat = data['stat'];
        final hasData = data['data'] != null;
        AppLogger.info(
          'TwseClient',
          'TWSE response stat="$stat", hasData=$hasData',
        );

        if (stat != 'OK' || !hasData) {
          AppLogger.warning(
            'TwseClient',
            'TWSE returned no data: stat=$stat, keys=${data.keys.toList()}',
          );
          return [];
        }

        // 從回應解析日期（格式: YYYYMMDD）
        final dateStr = data['date']?.toString() ?? '';
        final date = _parseAdDate(dateStr);
        AppLogger.info('TwseClient', 'TWSE data date: $dateStr -> $date');

        // 解析資料陣列（每列是 List 而非 Map）
        final List<dynamic> rows = data['data'];
        AppLogger.info('TwseClient', 'TWSE returned ${rows.length} rows');

        final prices = rows
            .map((row) => _parseDailyPriceRow(row as List<dynamic>, date))
            .whereType<TwseDailyPrice>()
            .toList();

        AppLogger.info('TwseClient', 'Parsed ${prices.length} valid prices');
        return prices;
      }

      throw ApiException(
        'TWSE API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      AppLogger.error(
        'TwseClient',
        'DioException: type=${e.type}, message=${e.message}, '
            'response=${e.response?.statusCode}',
        e,
      );
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('TWSE connection timeout', e);
      }
      throw NetworkException(e.message ?? 'TWSE network error', e);
    } catch (e, stack) {
      AppLogger.error('TwseClient', 'Unexpected error', e, stack);
      rethrow;
    }
  }

  /// 解析 YYYYMMDD 格式的西元日期（例如 "20260121"）
  DateTime _parseAdDate(String dateStr) {
    if (dateStr.length != 8) {
      return DateTime.now();
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
        return rows
            .map((row) => _parseInstitutionalRow(row as List<dynamic>, date))
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
        'https://www.twse.com.tw/exchangeReport/STOCK_DAY',
        queryParameters: {'response': 'json', 'date': dateStr, 'stockNo': code},
      );

      if (response.statusCode == 200) {
        // 處理 iOS Dio 回傳 String 而非 Map 的情況
        var data = response.data;
        if (data is String) {
          AppLogger.debug(
            'TwseClient',
            'getStockMonthlyPrices: Response is String, parsing as JSON',
          );
          data = jsonDecode(data);
        }

        if (data['stat'] != 'OK' || data['data'] == null) {
          AppLogger.debug(
            'TwseClient',
            'getStockMonthlyPrices: No data for $code ($year/$month), stat=${data['stat']}',
          );
          return [];
        }

        final List<dynamic> rows = data['data'];
        AppLogger.debug(
          'TwseClient',
          'getStockMonthlyPrices: $code ($year/$month) -> ${rows.length} rows',
        );
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
      } catch (_) {
        // 若某月失敗則繼續處理其他月份
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

        return rows
            .map((row) => _parseMarginTradingRow(row as List<dynamic>, date))
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
        'https://openapi.twse.com.tw/v1/exchangeReport/BWIBBU_ALL',
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

        // 除錯日誌以驗證使用者裝置上的 Open Data 內容
        try {
          final highYieldCount = results
              .where((v) => (v.dividendYield ?? 0) >= 7.0)
              .length;
          AppLogger.info(
            'TwseClient',
            'Open Data Stats: Total=${results.length}, Yield>=7.0=$highYieldCount',
          );
        } catch (e) {
          // 忽略日誌錯誤
        }

        return results;
      }

      return [];
    } catch (e) {
      AppLogger.error(
        'TwseClient',
        'Failed to get valuation data (OpenData)',
        e,
      );
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
      final response = await _dio.get(
        'https://openapi.twse.com.tw/v1/opendata/t187ap05_L',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map(
              (json) =>
                  TwseMonthlyRevenue.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.warning('TwseClient', 'Failed to fetch Open Data revenue', e);
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
          AppLogger.debug(
            'TwseClient',
            'Day trading data not available for $dateStr',
          );
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

        AppLogger.info(
          'TwseClient',
          'Fetched ${result.length} day trading records',
        );
        return result;
      }
      return [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException('TWSE connection timeout', e);
      }
      throw NetworkException(e.message ?? 'TWSE network error', e);
    } catch (e, stack) {
      AppLogger.error(
        'TwseClient',
        'Failed to fetch day trading data',
        e,
        stack,
      );
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
    } catch (e) {
      return null;
    }
  }
}

// ============================================
// 資料模型
// ============================================

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
      year = (int.tryParse(yStr) ?? 0) + 1911;
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

  /// 將 TWSE 民國日期（例如 "1150119"）轉換為 DateTime
  static DateTime _parseRocDate(String rocDate) {
    if (rocDate.length != 7) {
      throw FormatException('Invalid ROC date format: $rocDate');
    }

    final rocYear = int.parse(rocDate.substring(0, 3));
    final month = int.parse(rocDate.substring(3, 5));
    final day = int.parse(rocDate.substring(5, 7));

    // 民國年 + 1911 = 西元年
    final adYear = rocYear + 1911;

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
    } catch (_) {
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
