// 當沖 / 融資融券歷史回補所需的 client 能力
//
// 背景（2026-07-14）：當沖與融資融券只在「更新當下該日已發布」時才寫得進 DB，
// 錯過就永久缺漏（近 30 交易日：當沖缺 12 天、融資缺 10 天）。回補需要：
//   1. 當沖 client 對「回應日期 ≠ 請求日期」必須回空——repo 用**請求日期**
//      寫入（trading_repository.dart `date: targetDate`），端點若像
//      STOCK_DAY_ALL 一樣無視 date 參數，就會把最新資料寫成歷史日期。
//   2. TWSE 融資 client 必須支援 date 參數（原本只能取最新一天）。
// 端點行為 2026-07-14 活體驗證：兩者皆正確回應歷史日期。
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/remote/twse_client.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late TwseClient client;

  setUp(() {
    dio = MockDio();
    client = TwseClient(dio: dio);
  });

  Response<dynamic> okResponse(Map<String, dynamic> body, String path) =>
      Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: body,
      );

  void stub(String path, Map<String, dynamic> body) {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => okResponse(body, path));
  }

  /// TWTB4U 回應：以標題找個股明細表
  /// 列格式（6 欄）：[代號, 名稱, (空), 當沖成交股數, 當沖買進金額, 當沖賣出金額]
  Map<String, dynamic> dayTradingBody(String date) => {
    'stat': 'OK',
    'date': date,
    'tables': [
      {'title': '當日沖銷交易統計資訊', 'data': <dynamic>[]},
      {
        'title': '當日沖銷交易標的及成交量值',
        'data': [
          ['2330', '台積電', '', '1,000', '500,000', '600,000'],
        ],
      },
    ],
  };

  /// MI_MARGN 回應：tables[1] 為個股融資融券明細（16 欄）
  Map<String, dynamic> marginBody(String date) => {
    'stat': 'OK',
    'date': date,
    'tables': [
      {'title': '信用交易統計', 'data': <dynamic>[]},
      {
        'title': '融資融券彙總',
        'data': [
          [
            '2330', // 0 代號
            '台積電', // 1 名稱
            '100', // 2 融資買進
            '50', // 3 融資賣出
            '0', // 4 融資現償
            '900', // 5 融資前餘
            '950', // 6 融資今餘 → marginBalance
            '99999', // 7 融資限額
            '10', // 8 融券買進
            '20', // 9 融券賣出
            '0', // 10 融券現償
            '30', // 11 融券前餘
            '40', // 12 融券今餘 → shortBalance
            '99999', // 13 融券限額
            '0', // 14 資券互抵
            '', // 15 備註
          ],
        ],
      },
    ],
  };

  group('TwseClient.getAllDayTradingData — 回應日期守衛', () {
    test('回應日期 = 請求日期 → 正常回傳', () async {
      stub('/exchangeReport/TWTB4U', dayTradingBody('20260707'));

      final result = await client.getAllDayTradingData(
        date: DateTime(2026, 7, 7),
      );

      expect(result, hasLength(1));
      expect(result.single.code, '2330');
    });

    test('回應日期 ≠ 請求日期 → 回空（端點無視 date 參數的防護）', () async {
      // 端點回最新交易日（20260713）而非請求的 20260707。
      // repo 以請求日期寫入，若不擋就會把 7/13 的資料寫成 7/7。
      stub('/exchangeReport/TWTB4U', dayTradingBody('20260713'));

      final result = await client.getAllDayTradingData(
        date: DateTime(2026, 7, 7),
      );

      expect(result, isEmpty, reason: '日期不符必須整批丟棄，不得讓 repo 寫出錯誤日期的列');
    });

    test('未指定日期（每日路徑）→ 不套用守衛、照常回傳', () async {
      stub('/exchangeReport/TWTB4U', dayTradingBody('20260713'));

      final result = await client.getAllDayTradingData();

      expect(result, hasLength(1), reason: '每日同步取最新一天，行為不得改變');
    });

    test('回應無日期欄位 → 回空（fail closed：無從驗證的資料不可信）', () async {
      final noDate = Map<String, dynamic>.from(dayTradingBody('20260707'))
        ..remove('date');
      stub('/exchangeReport/TWTB4U', noDate);

      final result = await client.getAllDayTradingData(
        date: DateTime(2026, 7, 7),
      );

      expect(result, isEmpty);
    });
  });

  group('TwseClient.getAllMarginTradingData — 歷史日期支援', () {
    test('指定日期 → 帶入 date query 參數', () async {
      stub('/rwd/zh/marginTrading/MI_MARGN', marginBody('20260707'));

      await client.getAllMarginTradingData(date: DateTime(2026, 7, 7));

      final captured =
          verify(
                () => dio.get<dynamic>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(captured['date'], '20260707');
      expect(captured['selectType'], 'ALL');
    });

    test('未指定日期（每日路徑）→ 不帶 date 參數（取最新可用）', () async {
      stub('/rwd/zh/marginTrading/MI_MARGN', marginBody('20260713'));

      await client.getAllMarginTradingData();

      final captured =
          verify(
                () => dio.get<dynamic>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(
        captured.containsKey('date'),
        isFalse,
        reason: '每日路徑刻意省略 date（TPEx T+1 延遲，端點自動回最新可用日）',
      );
    });

    test('entries 帶回應自身日期（非請求日期）', () async {
      stub('/rwd/zh/marginTrading/MI_MARGN', marginBody('20260707'));

      final result = await client.getAllMarginTradingData(
        date: DateTime(2026, 7, 7),
      );

      expect(result, hasLength(1));
      expect(result.single.date, DateTime(2026, 7, 7));
      expect(result.single.marginBalance, 950);
      expect(result.single.shortBalance, 40);
    });

    test('不同日期分別快取（不得互相污染）', () async {
      stub('/rwd/zh/marginTrading/MI_MARGN', marginBody('20260707'));
      final first = await client.getAllMarginTradingData(
        date: DateTime(2026, 7, 7),
      );

      stub('/rwd/zh/marginTrading/MI_MARGN', marginBody('20260708'));
      final second = await client.getAllMarginTradingData(
        date: DateTime(2026, 7, 8),
      );

      expect(first.single.date, DateTime(2026, 7, 7));
      expect(
        second.single.date,
        DateTime(2026, 7, 8),
        reason: 'cache key 必須含日期，否則 7/8 會拿到 7/7 的快取',
      );
    });
  });
}
