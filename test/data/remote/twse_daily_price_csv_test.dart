import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/remote/twse_client.dart';

/// TWSE 於 2026-06 把 STOCK_DAY_ALL 回應從 JSON 改成 CSV（同端點、僅格式變）。
/// 驗證 CSV → 與 JSON 同 shape 的 Map 轉換，確保下游沿用的 parser 讀得到正確欄位。
void main() {
  group('TwseClient.parseDailyPriceCsvToMap', () {
    // 真實 STOCK_DAY_ALL CSV 格式：header 未加引號、資料每欄以雙引號包覆。
    // 欄位: 日期(民國),證券代號,證券名稱,成交股數,成交金額,開,高,低,收,漲跌,成交筆數
    const sampleCsv =
        '日期,證券代號,證券名稱,成交股數,成交金額,開盤價,最高價,最低價,收盤價,漲跌價差,成交筆數\n'
        '"1150624","2330","台積電","30000000","30000000000","1000.00","1010.00","990.00","995.00","-5.0000","50000"\n'
        '"1150624","00400A","主動國泰動能高息","99293429","1474754634","14.92","15.02","14.71","14.92","-0.2500","24755"\n';

    test('CSV → 與 JSON 同 shape 的 Map（stat / date / data）', () {
      final map = TwseClient.parseDailyPriceCsvToMap(sampleCsv);

      expect(map, isNotNull);
      expect(map!['stat'], 'OK');
      // 民國 115/06/24 → 西元 8 碼，供 parseAdDate 沿用
      expect(map['date'], '20260624');
      expect((map['data'] as List).length, 2);
    });

    test('剝掉日期欄後與 JSON row 佈局一致（_parseDailyPriceRow 讀得到正確欄位）', () {
      final map = TwseClient.parseDailyPriceCsvToMap(sampleCsv)!;
      final row = (map['data'] as List).first as List;

      // JSON row 佈局: [代號, 名稱, 成交股數, 成交金額, 開, 高, 低, 收, 漲跌, 筆數]
      expect(row.length, 10);
      expect(row[0], '2330'); // 證券代號
      expect(row[1], '台積電'); // 證券名稱
      expect(row[2], '30000000'); // 成交股數 (volume)
      expect(row[4], '1000.00'); // 開盤
      expect(row[5], '1010.00'); // 最高
      expect(row[6], '990.00'); // 最低
      expect(row[7], '995.00'); // 收盤
      expect(row[8], '-5.0000'); // 漲跌價差
    });

    test('欄位內含逗號（千分位）以引號邊界正確切分', () {
      const csvWithCommas =
          '日期,證券代號,證券名稱,成交股數,成交金額,開盤價,最高價,最低價,收盤價,漲跌價差,成交筆數\n'
          '"1150624","2330","台積電","30,000,000","30,000,000,000","1000.00","1010.00","990.00","995.00","-5.0000","50000"\n';
      final map = TwseClient.parseDailyPriceCsvToMap(csvWithCommas)!;
      final row = (map['data'] as List).first as List;

      expect(row.length, 10, reason: '千分位逗號不應使欄位被切碎');
      expect(row[0], '2330');
      expect(row[2], '30,000,000'); // 成交股數含千分位仍為單一欄
      expect(row[7], '995.00');
    });

    test('空字串 / 只有 header / 無有效列 → null', () {
      expect(TwseClient.parseDailyPriceCsvToMap(''), isNull);
      expect(
        TwseClient.parseDailyPriceCsvToMap('日期,證券代號,證券名稱\n'),
        isNull,
        reason: '只有 header、無資料列 → null',
      );
    });
  });
}
