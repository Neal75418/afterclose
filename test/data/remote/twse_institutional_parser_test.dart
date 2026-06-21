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

  Response<dynamic> okResponse(Map<String, dynamic> body) => Response<dynamic>(
    requestOptions: RequestOptions(path: '/rwd/zh/fund/T86'),
    statusCode: 200,
    data: body,
  );

  /// 代表性 19 欄 T86 row（selectType=ALLBUT0999），滿足算術不變式
  /// [11] 自營合計 = [14] 自行 + [17] 避險。
  ///
  /// 2330: 外陸資淨 [4]=500, 投信淨 [10]=100,
  /// 自營自行淨 [14]=30, 自營避險淨 [17]=-10, 自營合計淨 [11]=20 (=30+(-10)),
  /// 三大法人 [18]=620。
  /// 自行買 [12]=50 / 賣 [13]=20（淨 30）; 避險買 [15]=5 / 賣 [16]=15（淨 -10）。
  List<dynamic> row2330() => <dynamic>[
    '2330', // 0 代號
    '台積電', // 1 名稱
    '0', // 2 外陸資買進
    '0', // 3 外陸資賣出
    '500', // 4 外陸資買賣超 → foreignNet
    '0', // 5 外資自營買進
    '0', // 6 外資自營賣出
    '0', // 7 外資自營買賣超
    '200', // 8 投信買進
    '100', // 9 投信賣出
    '100', // 10 投信買賣超 → investmentTrustNet
    '20', // 11 自營商買賣超(合計) → dealerNet
    '50', // 12 自營(自行)買進
    '20', // 13 自營(自行)賣出
    '30', // 14 自營(自行)買賣超 → dealerSelfNet
    '5', // 15 自營(避險)買進
    '15', // 16 自營(避險)賣出
    '-10', // 17 自營(避險)買賣超
    '620', // 18 三大法人買賣超 → totalNet
  ];

  void stubT86(List<dynamic> dataRow) {
    when(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => okResponse({
        'stat': 'OK',
        'date': '20260613',
        'data': [dataRow],
      }),
    );
  }

  group('TwseClient._parseInstitutionalRow (19-col corrected mapping)', () {
    test('dealerNet=[11], dealerSelfNet=[14], totalNet=[18]', () async {
      stubT86(row2330());

      final result = await client.getAllInstitutionalData();

      expect(result, hasLength(1));
      final r = result.single;
      expect(r.code, '2330');
      // 修正後：合計來自 [11]，非舊版誤讀的 [13]（=自行賣出 20）
      expect(r.dealerNet, 20, reason: 'dealerNet 必須來自 [11] 自營合計');
      // 新欄位：自行買賣淨來自 [14]
      expect(r.dealerSelfNet, 30, reason: 'dealerSelfNet 必須來自 [14] 自營自行淨');
      // 修正後：三大法人來自 [18]，非舊版誤讀的 [17]（=避險淨 -10）
      expect(r.totalNet, 620, reason: 'totalNet 必須來自 [18] 三大法人');
    });

    test(
      'foreignNet[4] / investmentTrustNet[10] 維持不變（byte-identical）',
      () async {
        stubT86(row2330());

        final r = (await client.getAllInstitutionalData()).single;
        expect(r.foreignNet, 500, reason: 'foreignNet 仍取 [4]，不得改動');
        expect(
          r.investmentTrustNet,
          100,
          reason: 'investmentTrustNet 仍取 [10]，不得改動',
        );
      },
    );

    test('dealerBuy/Sell 取自行+避險合併口徑（[12]+[15] / [13]+[16]）', () async {
      stubT86(row2330());

      final r = (await client.getAllInstitutionalData()).single;
      // buy = 50 (自行) + 5 (避險) = 55；sell = 20 (自行) + 15 (避險) = 35
      expect(r.dealerBuy, 55);
      expect(r.dealerSell, 35);
    });

    test(
      'arithmetic invariant: dealerNet == dealerSelfNet + hedge[17]',
      () async {
        stubT86(row2330());

        final r = (await client.getAllInstitutionalData()).single;
        // 合計 [11]=20 應等於 自行 [14]=30 + 避險 [17]=-10
        const hedgeNet = -10.0;
        expect(r.dealerNet, r.dealerSelfNet + hedgeNet);
      },
    );

    test('rows shorter than 19 cols are skipped (minLength=19)', () async {
      // 18 欄（舊長度）→ 應被 safeParseRow 跳過，避免讀到錯位欄
      final shortRow = row2330().sublist(0, 18);
      stubT86(shortRow);

      final result = await client.getAllInstitutionalData();
      expect(result, isEmpty, reason: '少於 19 欄的 row 應被跳過');
    });
  });
}
