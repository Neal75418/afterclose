import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/core/constants/api_endpoints.dart';
import 'package:daredevil/data/models/twse/intraday_quote.dart';
import 'package:daredevil/data/remote/intraday_quote_client.dart';
import 'package:daredevil/domain/services/alert/alert_target_calculator.dart';
import 'package:daredevil/domain/services/technical_indicator_service.dart';

void main() {
  // 造 n 根波動不均的日線(讓 Wilder 平滑與 SMA 產生可觀察差異)
  List<Ohlc> bars(int n) {
    final out = <Ohlc>[];
    var close = 100.0;
    for (var i = 0; i < n; i++) {
      // 前半段窄幅、後半段放大 → SMA(近20) 與 Wilder(全序列) 必然分歧
      final range = i < n ~/ 2 ? 1.0 : 8.0;
      close += (i.isEven ? 1.0 : -0.5);
      out.add(
        Ohlc(high: close + range / 2, low: close - range / 2, close: close),
      );
    }
    return out;
  }

  test('A. ATR 口徑:AlertTargetCalculator._atr vs calculateATR', () {
    final b = bars(60);
    final t = AlertTargetCalculator.compute(b);
    final gate = t[AlertKind.stopGate]!;
    final atrFromCalculator = (b.last.close - gate.price) / 2.0;

    final svc = TechnicalIndicatorService();
    final wilder = svc.calculateATR(
      b.map((x) => x.high).toList(),
      b.map((x) => x.low).toList(),
      b.map((x) => x.close).toList(),
      period: 20,
    );
    // ignore: avoid_print
    print('calculator ATR (SMA of last 20 TR) = $atrFromCalculator');
    // ignore: avoid_print
    print('service    ATR (Wilder RMA)        = ${wilder.last}');
    // ignore: avoid_print
    print('gate=${gate.price}  close=${b.last.close}');
    // ignore: avoid_print
    print(
      'wilder-gate would be ${b.last.close - 2 * wilder.last!} '
      '(diff ${(gate.price - (b.last.close - 2 * wilder.last!)).abs()})',
    );
  });

  test('B. 恰好 20 根 → stopGate 靜默缺席', () {
    final t20 = AlertTargetCalculator.compute(bars(20));
    final t21 = AlertTargetCalculator.compute(bars(21));
    // ignore: avoid_print
    print('n=20 keys: ${t20.keys.map((k) => k.name).toList()}');
    // ignore: avoid_print
    print('n=21 keys: ${t21.keys.map((k) => k.name).toList()}');
    expect(t20.containsKey(AlertKind.breakBelowMa20), isTrue);
    expect(t20.containsKey(AlertKind.stopGate), isFalse);
    expect(t21.containsKey(AlertKind.stopGate), isTrue);
  });

  test('C+D. Dio URL 組合 + 分批數學', () async {
    final captured = <String>[];
    final uris = <String>[];
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.twseMisIntraday,
        responseType: ResponseType.json,
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          captured.add(o.queryParameters['ex_ch'] as String);
          uris.add(o.uri.toString());
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: '{"rtcode":"0000","msgArray":[]}',
            ),
          );
        },
      ),
    );

    final client = IntradayQuoteClient(dio: dio);
    final markets = <String, String>{
      for (var i = 0; i < 71; i++) '${1000 + i}': i.isEven ? 'TWSE' : 'TPEx',
    };
    await client.fetchQuotes(markets);

    // ignore: avoid_print
    print('batches=${captured.length}');
    // ignore: avoid_print
    print('sizes=${captured.map((c) => c.split('|').length).toList()}');
    // ignore: avoid_print
    print('uri[0]=${uris.first.substring(0, 90)}');
    final all = captured.expand((c) => c.split('|')).toList();
    expect(all.length, 71, reason: '不得漏送或重送');
    expect(all.toSet().length, 71);
    expect(all.first, 'tse_1000.tw');
    expect(all[1], 'otc_1001.tw');
    expect(uris.first.startsWith(ApiEndpoints.twseMisIntraday), isTrue);
    expect(uris.first.contains('getStockInfo.jspgetStockInfo'), isFalse);
  });

  test('E. parseResponse 邊界', () {
    Map<String, dynamic> resp(List<Map<String, String>> rows) => {
      'rtcode': '0000',
      'msgArray': rows,
    };

    // y=0（首日上市/無昨收）→ 整列丟棄
    final r1 = IntradayQuote.parseResponse(
      resp([
        {'c': '9999', 'n': 'IPO', 'y': '0.0000', 'z': '55.0000'},
      ]),
    );
    // ignore: avoid_print
    print('y=0 → ${r1.keys.toList()}');
    expect(r1, isEmpty);

    // z='-' → 退回 pz
    final r2 = IntradayQuote.parseResponse(
      resp([
        {'c': '2330', 'n': 'x', 'y': '100.0', 'z': '-', 'pz': '99.0'},
      ]),
    );
    // ignore: avoid_print
    print('z=- pz=99 → ${r2['2330']!.price}');
    expect(r2['2330']!.price, 99.0);

    // z/pz/o 全缺 → 退回昨收
    final r3 = IntradayQuote.parseResponse(
      resp([
        {'c': '2330', 'n': 'x', 'y': '100.0', 'z': '-', 'pz': '-', 'o': '-'},
      ]),
    );
    // ignore: avoid_print
    print('全缺 → ${r3['2330']!.price} (昨收 100)');
    expect(r3['2330']!.price, 100.0);

    // v='0' 保留為 0（int.tryParse 不走 _num）
    final r4 = IntradayQuote.parseResponse(
      resp([
        {'c': '2330', 'n': 'x', 'y': '100.0', 'z': '101.0', 'v': '0'},
      ]),
    );
    // ignore: avoid_print
    print('v=0 → ${r4['2330']!.volume}');

    // rtcode 非 0000
    expect(
      IntradayQuote.parseResponse({'rtcode': '5001', 'msgArray': []}),
      isEmpty,
    );
  });
}
