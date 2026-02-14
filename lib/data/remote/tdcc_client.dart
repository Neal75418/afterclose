import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:afterclose/core/constants/api_endpoints.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/models/tdcc/tdcc_holding_level.dart';

export 'package:afterclose/data/models/tdcc/tdcc_holding_level.dart';

/// TDCC 集保中心 Open Data API 客戶端
///
/// 提供免費存取股權分散表（持股級距分布）資料。
/// 使用 TDCC 開放資料 JSON API，無需認證。
/// 資料每週更新（週五收盤後公布）。
///
/// API 來源: https://openapi.tdcc.com.tw/v1/opendata/1-5
class TdccClient {
  TdccClient({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
  }

  /// 取得全市場股權分散表資料
  ///
  /// TDCC API 一次回傳所有股票的持股分布。
  /// 回傳以證券代號為 key 的 Map，每檔股票包含各級距資料。
  ///
  /// 過濾掉 level 16（差異數調整）和 17（合計）。
  Future<Map<String, List<TdccHoldingLevel>>>
  getAllHoldingDistribution() async {
    try {
      final response = await _dio.get(ApiEndpoints.tdccHoldingDistribution);

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            AppLogger.warning('TDCC', '股權分散表: JSON 解析失敗');
            return {};
          }
        }

        if (data is! List) {
          AppLogger.warning('TDCC', '股權分散表: 非預期資料型別');
          return {};
        }

        final result = <String, List<TdccHoldingLevel>>{};
        var skipped = 0;

        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;

          final parsed = _parseItem(item);
          if (parsed == null) {
            skipped++;
            continue;
          }

          // 過濾掉 level 16（差異數調整）和 17（合計）
          if (parsed.level >= 16) continue;

          result.putIfAbsent(parsed.symbol, () => []).add(parsed);
        }

        AppLogger.info(
          'TDCC',
          '股權分散表: ${result.length} 檔股票'
              '${skipped > 0 ? "（略過 $skipped 筆）" : ""}',
        );
        return result;
      }

      throw ApiException(
        'TDCC API error: ${response.statusCode}',
        response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        AppLogger.warning('TDCC', '股權分散表: 連線逾時');
        throw NetworkException('TDCC connection timeout', e);
      }
      AppLogger.warning('TDCC', '股權分散表: ${e.message ?? "網路錯誤"}');
      throw NetworkException(e.message ?? 'TDCC network error', e);
    } catch (e, stack) {
      if (e is ApiException || e is NetworkException) rethrow;
      AppLogger.error('TDCC', '股權分散表: 非預期錯誤', e, stack);
      rethrow;
    }
  }

  /// 解析單筆 TDCC JSON 資料
  ///
  /// JSON 欄位：
  /// - `資料日期`: YYYYMMDD 格式
  /// - `證券代號`: 股票代碼
  /// - `持股分級`: 1-17
  /// - `人數`: 股東人數
  /// - `股數`: 持有股數
  /// - `占集保庫存數比例%`: 百分比
  TdccHoldingLevel? _parseItem(Map<String, dynamic> json) {
    try {
      // TDCC API 的 key 可能帶 BOM（\uFEFF），統一移除
      final clean = json.map((k, v) => MapEntry(k.replaceAll('\uFEFF', ''), v));
      final dateStr = clean['資料日期']?.toString() ?? '';
      if (dateStr.length != 8) return null;

      final year = int.tryParse(dateStr.substring(0, 4));
      final month = int.tryParse(dateStr.substring(4, 6));
      final day = int.tryParse(dateStr.substring(6, 8));
      if (year == null || month == null || day == null) return null;

      final symbol = clean['證券代號']?.toString().trim() ?? '';
      if (symbol.isEmpty) return null;

      final level = int.tryParse(clean['持股分級']?.toString() ?? '');
      if (level == null) return null;

      final shareholders =
          int.tryParse(clean['人數']?.toString().replaceAll(',', '') ?? '') ?? 0;
      final shares =
          double.tryParse(clean['股數']?.toString().replaceAll(',', '') ?? '') ??
          0;
      final percent =
          double.tryParse(
            clean['占集保庫存數比例%']?.toString().replaceAll(',', '') ?? '',
          ) ??
          0;

      return TdccHoldingLevel(
        date: DateTime(year, month, day),
        symbol: symbol,
        level: level,
        shareholders: shareholders,
        shares: shares,
        percent: percent,
      );
    } catch (e) {
      AppLogger.debug('TDCC', '解析持股分級失敗: $e');
      return null;
    }
  }

  /// 將 TDCC 持股分級代碼轉換為級距字串（張）
  ///
  /// 轉換後的格式與 [ShareholdingRepository._parseMinSharesFromLevel] 相容。
  /// 單位為「張」（1 張 = 1,000 股）。
  static String levelCodeToRangeString(int level) {
    return switch (level) {
      1 => '0-1',
      2 => '1-5',
      3 => '5-10',
      4 => '10-15',
      5 => '15-20',
      6 => '20-30',
      7 => '30-40',
      8 => '40-50',
      9 => '50-100',
      10 => '100-200',
      11 => '200-400',
      12 => '400-600',
      13 => '600-800',
      14 => '800-1000',
      15 => '1000以上',
      _ => '$level',
    };
  }
}
