import 'dart:convert';
import 'dart:io';

import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// 真實 API response fixture 解析測試
///
/// Fixture 錄自 2026-07-08 的實際 API 回應（`test/fixtures/remote/`），
/// 非從 parser 反推——上游格式變更（如 TWSE 2026-06 STOCK_DAY_ALL
/// JSON→CSV）是本 App 最常見的故障模式，這組測試固定「當前真實格式
/// 可被正確解析」作為 regression baseline。
class MockDio extends Mock implements Dio {}

String _fixture(String name) =>
    File('test/fixtures/remote/$name').readAsStringSync();

Response<dynamic> _response(dynamic data) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: ''),
);

void main() {
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
  });

  void stubGet(dynamic data) {
    when(
      () => mockDio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => _response(data));
  }

  group('TwseClient 真實 fixture 解析', () {
    test('STOCK_DAY_ALL CSV 格式（2026-06 起）解析為每日價格', () async {
      stubGet(_fixture('twse_stock_day_all.csv'));
      final client = TwseClient(dio: mockDio);

      final prices = await client.getAllDailyPrices();

      // fixture 含 24 筆資料列（25 行 - 表頭）
      expect(prices, hasLength(24));
      final first = prices.first;
      expect(first.code, '00400A');
      expect(first.name, '主動國泰動能高息');
      expect(first.close, 14.29);
      expect(first.open, 14.41);
      expect(first.volume, 68952570);
      expect(first.change, -0.06);
      // 民國 1150708 → 2026-07-08
      expect(first.date, DateTime(2026, 7, 8));
    });

    test('T86 三大法人 JSON 解析', () async {
      stubGet(jsonDecode(_fixture('twse_t86_institutional.json')));
      final client = TwseClient(dio: mockDio);

      final rows = await client.getAllInstitutionalData(
        date: DateTime(2026, 7, 8),
      );

      expect(rows, hasLength(15));
      final first = rows.first;
      expect(first.code, '2618');
      // T86 的名稱欄位帶 TWSE 原始尾隨空白，parser 保留原樣
      expect(first.name.trim(), '長榮航');
      // 外陸資買進 75,301,046 / 賣出 13,442,621 / 買賣超 61,858,425
      expect(first.foreignBuy, 75301046);
      expect(first.foreignSell, 13442621);
      expect(first.foreignNet, 61858425);
    });
  });

  group('TpexClient 真實 fixture 解析', () {
    test('上櫃全市場日價 tables JSON 解析', () async {
      stubGet(jsonDecode(_fixture('tpex_daily_close_quotes.json')));
      final client = TpexClient(dio: mockDio);

      final prices = await client.getAllDailyPrices(date: DateTime(2026, 7, 8));

      // fixture 含 5 筆 ETF（006xxx，isTpexCode 過濾掉）+ 10 筆一般個股
      expect(prices, hasLength(10));
      final first = prices.first;
      expect(first.code, '1240');
      expect(first.name, '茂生農經');
      expect(first.close, 57.80);
      expect(first.change, -0.10);
      expect(first.open, 58.40);
    });
  });

  group('FinMindClient 真實 fixture 解析', () {
    test('TaiwanStockPrice JSON 解析', () async {
      stubGet(jsonDecode(_fixture('finmind_taiwan_stock_price.json')));
      final client = FinMindClient(dio: mockDio);

      final prices = await client.getDailyPrices(
        stockId: '2330',
        startDate: '2026-07-06',
        endDate: '2026-07-08',
      );

      expect(prices, hasLength(3));
      final first = prices.first;
      expect(first.stockId, '2330');
      expect(first.date, '2026-07-06');
      expect(first.close, 2460.0);
      expect(first.open, 2465.0);
      expect(first.volume, 21041918);
    });
  });
}
