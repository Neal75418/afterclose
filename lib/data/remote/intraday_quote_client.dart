import 'package:dio/dio.dart';

import 'package:daredevil/core/constants/api_endpoints.dart';
import 'package:daredevil/core/exceptions/app_exception.dart';
import 'package:daredevil/core/utils/logger.dart';
import 'package:daredevil/data/models/twse/intraday_quote.dart';
import 'package:daredevil/data/remote/market_client_mixin.dart';

/// 盤中即時報價 client(TWSE MIS,2026-08-08)。
///
/// **不快取**:這支的存在理由就是即時性,快取等於自我否定。
/// 分批送出(單次上限 [ApiEndpoints.misBatchSize] 檔),任何一批失敗
/// 不影響其他批——盤中提醒缺一檔比整批沒有好。
class IntradayQuoteClient {
  IntradayQuoteClient({Dio? dio})
    : _dio = dio ?? MarketClientMixin.createDio(ApiEndpoints.twseMisIntraday);

  static const String _tag = 'MIS';
  final Dio _dio;

  /// [markets] 為 symbol → 市場別(`TWSE`/`TPEx`),決定 `tse_`/`otc_` 前綴。
  /// 猜錯前綴會回不到報價(2026-08-07 實測:大量 3167 是上市不是上櫃)。
  Future<Map<String, IntradayQuote>> fetchQuotes(
    Map<String, String> markets,
  ) async {
    if (markets.isEmpty) return const {};
    final symbols = markets.keys.toList();
    final result = <String, IntradayQuote>{};

    for (var i = 0; i < symbols.length; i += ApiEndpoints.misBatchSize) {
      final batch = symbols.skip(i).take(ApiEndpoints.misBatchSize);
      final exCh = batch
          .map((s) => '${markets[s] == 'TWSE' ? 'tse' : 'otc'}_$s.tw')
          .join('|');
      try {
        final response = await _dio.get(
          ApiEndpoints.twseMisIntraday,
          queryParameters: {'ex_ch': exCh, 'json': 1, 'delay': 0},
        );
        if (response.statusCode != 200) {
          throw ApiException(
            '$_tag error: ${response.statusCode}',
            response.statusCode,
          );
        }
        final data = response.data;
        if (data is Map<String, dynamic>) {
          result.addAll(IntradayQuote.parseResponse(data));
        }
      } on RateLimitException {
        rethrow;
      } catch (e) {
        // 單批失敗不影響其他批:盤中缺一檔報價 > 整批沒有
        AppLogger.warning(_tag, '盤中報價批次失敗(${batch.length} 檔)', e);
      }
    }
    AppLogger.debug(_tag, '盤中報價: ${result.length}/${symbols.length} 檔');
    return result;
  }
}
