import 'package:dio/dio.dart';

import 'package:daredevil/core/constants/api_endpoints.dart';
import 'package:daredevil/core/constants/market_codes.dart';
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
          .map((s) => '${markets[s] == MarketCode.twse ? 'tse' : 'otc'}_$s.tw')
          .join('|');
      try {
        final response = await _dio.get(
          ApiEndpoints.twseMisIntraday,
          queryParameters: {'ex_ch': exCh, 'json': 1, 'delay': 0},
          // 一律取原始字串自行解碼(2026-08-08 code review):讓 Dio 解析
          // 有兩個坑——①MIS 回應前綴帶空行,json 模式會解析失敗;②限流
          // 時回 HTML,若 Dio 先拋解析錯,就會被下面的 catch 吞成「這批
          // 失敗」而繼續猛打。交給 decodeResponseData 才看得出是限流。
          options: Options(responseType: ResponseType.plain),
        );
        if (response.statusCode != 200) {
          throw ApiException(
            '$_tag error: ${response.statusCode}',
            response.statusCode,
          );
        }
        // MIS 回應前面帶一串空行,Dio 的 responseType.json 因此解析失敗
        // 退回 String(2026-08-08 實測)——走專案既有的統一解碼 helper,
        // 它同時處理 String 情況與限流時的 HTML 回應。
        final data = MarketClientMixin.decodeResponseData(
          response.data,
          _tag,
          '盤中報價',
        );
        if (data != null) result.addAll(IntradayQuote.parseResponse(data));
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

  /// 釋放底層 HttpClient 連線池(專案其他 5 支 client 皆有,見
  /// providers.dart 的「避免每次設定變動都洩漏一個底層 socket」)
  void close() => _dio.close(force: true);
}
