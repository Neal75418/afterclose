// 法人「當日無進出」缺列補零 — P1-6 子問題 B
//
// 交易所對「當日無法人進出」的股票**根本不發列**（實測 DB：foreign/trust/
// dealer 全零的列 0 筆），每個交易日約有 100~168 檔股票有價格列卻無法人列。
// 那些日子的法人淨額就是 0，連續買賣超規則要求每日 > 50,000 股，本來就該
// 中斷 streak；但規則的迴圈只走陣列、不比對日期，於是把缺列直接跳過，
// 將不相鄰的兩天接成「連續」。
//
// 修法選擇在資料層補零而非在規則迴圈加日期檢查，理由是後者無法區分
// 「中間的缺口」（該斷）與「窗的邊界」（該標 truncated）——要區分就得把
// 交易日曆塞進純函數規則，而台股有臨時休市（颱風假），日曆猜錯會把所有
// 跨越該日的 streak 全部誤斷。補零從源頭消滅這個歧義。
//
// 關鍵判準：**市場當日是否有任何股票有法人列**。
//   有 → 同步涵蓋該日，該股缺列 = 當日無進出 → 補 0
//   無 → 該日在資料窗外，我們一無所知 → 不得捏造
import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/domain/services/update/batch_data_builder.dart';
import 'package:flutter_test/flutter_test.dart';

DailyInstitutionalEntry _inst(String symbol, DateTime date, double foreign) =>
    DailyInstitutionalEntry(
      symbol: symbol,
      date: date,
      foreignNet: foreign,
      investmentTrustNet: 0,
      dealerNet: 0,
    );

DailyPriceEntry _price(String symbol, DateTime date) => DailyPriceEntry(
  symbol: symbol,
  date: date,
  open: 50,
  high: 50,
  low: 50,
  close: 50,
  volume: 1000000,
);

final _d1 = DateTime(2026, 7, 20);
final _d2 = DateTime(2026, 7, 21);
final _d3 = DateTime(2026, 7, 22);

void main() {
  group('fillNoActivityDays', () {
    test('🚨 內部缺口補 0 — 該股有價格、市場當日有法人資料、該股無列', () {
      // A 缺 7/21；B 在 7/21 有列 → 證明同步涵蓋 7/21
      final inst = {
        'A': [_inst('A', _d1, 600000), _inst('A', _d3, 600000)],
        'B': [_inst('B', _d2, 100000)],
      };
      final prices = {
        'A': [_price('A', _d1), _price('A', _d2), _price('A', _d3)],
        'B': [_price('B', _d2)],
      };

      final filled = BatchDataBuilder.fillNoActivityDays(inst, prices);

      expect(filled['A']!.length, 3);
      final gap = filled['A']!.firstWhere((e) => e.date == _d2);
      expect(gap.foreignNet, 0);
      expect(gap.investmentTrustNet, 0);
      expect(gap.dealerNet, 0);
    });

    test('🚨 停牌不補 — 無價格列代表沒有交易時段，不是「無進出」', () {
      final inst = {
        'A': [_inst('A', _d1, 600000), _inst('A', _d3, 600000)],
        'B': [_inst('B', _d2, 100000)],
      };
      // A 在 7/21 沒有價格列 = 停牌
      final prices = {
        'A': [_price('A', _d1), _price('A', _d3)],
        'B': [_price('B', _d2)],
      };

      final filled = BatchDataBuilder.fillNoActivityDays(inst, prices);

      expect(filled['A']!.length, 2, reason: '停牌日不得補零值列');
      expect(filled['A']!.any((e) => e.date == _d2), isFalse);
    });

    test('🚨 資料窗外不得捏造 — 市場當日無任何法人列', () {
      // 全市場在 7/21 都沒有法人資料（同步未涵蓋）
      final inst = {
        'A': [_inst('A', _d1, 600000), _inst('A', _d3, 600000)],
      };
      final prices = {
        'A': [_price('A', _d1), _price('A', _d2), _price('A', _d3)],
      };

      final filled = BatchDataBuilder.fillNoActivityDays(inst, prices);

      expect(
        filled['A']!.length,
        2,
        reason: '該日全市場無資料 → 我們一無所知，補 0 等於捏造「法人沒動作」',
      );
    });

    test('最新交易日缺列同樣補 0 — history.last 才不會拿舊日當今天', () {
      // A 最後一筆停在 7/21，但市場 7/22 有資料（B 有列）
      final inst = {
        'A': [_inst('A', _d1, 600000), _inst('A', _d2, 600000)],
        'B': [_inst('B', _d3, 100000)],
      };
      final prices = {
        'A': [_price('A', _d1), _price('A', _d2), _price('A', _d3)],
        'B': [_price('B', _d3)],
      };

      final filled = BatchDataBuilder.fillNoActivityDays(inst, prices);

      expect(filled['A']!.last.date, _d3);
      expect(filled['A']!.last.foreignNet, 0);
    });

    test('該股窗內完全無法人列 → 維持「無資料」語意，不補', () {
      final inst = {
        'B': [_inst('B', _d2, 100000)],
      };
      final prices = {
        'A': [_price('A', _d1), _price('A', _d2)],
        'B': [_price('B', _d2)],
      };

      final filled = BatchDataBuilder.fillNoActivityDays(inst, prices);

      expect(
        filled.containsKey('A'),
        isFalse,
        reason: '無任何法人列 ≠ 法人都沒動作；規則靠 isEmpty 判「無資料」',
      );
    });

    test('補完必須維持日期升序 — 規則用 history.last 當今日', () {
      final inst = {
        'A': [_inst('A', _d1, 600000), _inst('A', _d3, 600000)],
        'B': [_inst('B', _d2, 100000)],
      };
      final prices = {
        'A': [_price('A', _d1), _price('A', _d2), _price('A', _d3)],
        'B': [_price('B', _d2)],
      };

      final dates = BatchDataBuilder.fillNoActivityDays(
        inst,
        prices,
      )['A']!.map((e) => e.date).toList();

      expect(dates, [_d1, _d2, _d3]);
    });

    test('無缺口時原樣返回，不動既有資料', () {
      final inst = {
        'A': [_inst('A', _d1, 600000), _inst('A', _d2, 700000)],
      };
      final prices = {
        'A': [_price('A', _d1), _price('A', _d2)],
      };

      final filled = BatchDataBuilder.fillNoActivityDays(inst, prices);

      expect(filled['A']!.length, 2);
      expect(filled['A']!.map((e) => e.foreignNet), [600000, 700000]);
    });
  });
}
