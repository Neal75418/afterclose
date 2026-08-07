// 外資持股新鮮度閘門 — 過期資料不得產生訊號
//
// 2026-07-25 實測缺陷：`getLatestShareholdingsBatch` 取全域 MAX(date)、無上界，
// 而 `ShareholdingData` 不帶日期 → 規則無從判斷資料多舊。DB 實證 3479（TPEx，
// 因上櫃配額 20/269 未被覆蓋）連四天以同一筆 7/21 資料觸發
// FOREIGN_SHAREHOLDING_INCREASING（+18）：
//
//   7/21 ratio=7.63 change=0.84 | 7/22 ratio=7.63 change=1.23
//   7/23 ratio=7.63 change=1.22 | 7/24 ratio=7.63 change=1.22
//
// 沒有任何新資料進來，訊號強度卻隨 prev 端往回滾而變動——使用者會讀成
// 「外資連四天加碼、力道還在增強」，實際只有一個資料點。
//
// 門檻用**交易日**而非日曆天：週一評估用週五資料是 3 日曆天但只隔 1 交易日，
// 用日曆天會誤殺合法資料。
import 'package:daredevil/core/utils/taiwan_calendar.dart';
import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/domain/services/update/batch_data_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-07-24(五) 2026-07-23(四) 2026-07-22(三) 2026-07-21(二) 2026-07-20(一)
  // 2026-07-18~19 為週末
  final fri = DateTime(2026, 7, 24);
  final thu = DateTime(2026, 7, 23);
  final tue = DateTime(2026, 7, 21);
  final prevFri = DateTime(2026, 7, 17);
  final mon = DateTime(2026, 7, 20);

  ShareholdingEntry entry(String symbol, DateTime date, double ratio) =>
      ShareholdingEntry(
        symbol: symbol,
        date: date,
        foreignSharesRatio: ratio,
        foreignRemainingShares: null,
        foreignUpperLimitRatio: null,
        sharesIssued: null,
      );

  group('TaiwanCalendar.subtractTradingDays', () {
    test('週一往前 1 個交易日 = 上週五（跳過週末）', () {
      expect(TaiwanCalendar.subtractTradingDays(mon, 1), prevFri);
    });

    test('週五往前 3 個交易日 = 同週二', () {
      expect(TaiwanCalendar.subtractTradingDays(fri, 3), tue);
    });

    test('往前 0 個交易日為自身', () {
      expect(TaiwanCalendar.subtractTradingDays(fri, 0), fri);
    });
  });

  group('buildShareholdingMap 新鮮度閘門', () {
    test('當日資料保留 ratio 與 change', () {
      final map = BatchDataBuilder.buildShareholdingMap(
        {'2330': entry('2330', fri, 8.0)},
        {'2330': entry('2330', prevFri, 7.0)},
        const {},
        evaluationDate: fri,
      );

      expect(map['2330']!.foreignSharesRatio, 8.0);
      expect(map['2330']!.foreignSharesRatioChange, closeTo(1.0, 1e-9));
    });

    test('前一交易日資料仍在容忍範圍內', () {
      final map = BatchDataBuilder.buildShareholdingMap(
        {'2330': entry('2330', thu, 8.0)},
        {'2330': entry('2330', prevFri, 7.0)},
        const {},
        evaluationDate: fri,
      );

      expect(map['2330']!.foreignSharesRatio, 8.0);
    });

    test('⚠️ 過期資料（3 交易日前）不得產生 change（ratio 走寬門檻保留）', () {
      final map = BatchDataBuilder.buildShareholdingMap(
        {'3479': entry('3479', tue, 7.63)},
        {'3479': entry('3479', prevFri, 6.41)},
        const {},
        evaluationDate: fri,
      );

      expect(
        map['3479']!.foreignSharesRatioChange,
        isNull,
        reason: '3479 的實際病灶：連四天用同一筆 7/21 資料、change 卻自己變動',
      );
      expect(
        map['3479']!.foreignSharesRatio,
        7.63,
        reason: '水位是真實觀測值，走寬門檻（見 level/delta 分離測試）',
      );
    });

    test('過期時籌碼集中度不受波及（不同資料源）', () {
      final map = BatchDataBuilder.buildShareholdingMap(
        {'3479': entry('3479', tue, 7.63)},
        const {},
        {'3479': 42.0},
        evaluationDate: fri,
      );

      expect(map['3479']!.foreignSharesRatioChange, isNull);
      expect(map['3479']!.concentrationRatio, 42.0);
    });

    test('🚨 水位(level)與變化量(delta)須分別把關', () {
      // ratio 是**水位**：外資持股 78% 三天後仍約 78%，不會因隔幾天就腐壞。
      // 把它連同 change 一起關掉，等於隱藏 ForeignConcentrationWarningRule
      // (-8, 只讀 ratio ≥60% 不碰 change) 的真實風險 → fail-open。
      // change 則相反：stale 時 current 端凍結、prev 端隨日期滾動 → 捏造值。
      final map = BatchDataBuilder.buildShareholdingMap(
        {'2330': entry('2330', tue, 78.0)}, // 3 交易日前
        {'2330': entry('2330', prevFri, 70.0)},
        const {},
        evaluationDate: fri,
      );

      expect(
        map['2330']!.foreignSharesRatio,
        78.0,
        reason: '水位是真實觀測值，不該因幾天沒更新就消失（否則隱藏 -8 風險警示）',
      );
      expect(
        map['2330']!.foreignSharesRatioChange,
        isNull,
        reason: 'delta 在 stale 時是 prev 端滾動造出來的捏造值',
      );
    });

    test('水位超出寬鬆上界時仍須關閉', () {
      final map = BatchDataBuilder.buildShareholdingMap(
        {'2330': entry('2330', DateTime(2026, 3, 2), 78.0)}, // 遠超上界
        const {},
        const {},
        evaluationDate: fri,
      );

      expect(map['2330']!.foreignSharesRatio, isNull);
    });

    test('分市場新鮮度統計不影響閘門結果（純可觀測性）', () {
      final map = BatchDataBuilder.buildShareholdingMap(
        {'2330': entry('2330', fri, 8.0), '3479': entry('3479', tue, 7.63)},
        const {},
        const {},
        evaluationDate: fri,
        symbolMarkets: const {'2330': 'TWSE', '3479': 'TPEx'},
      );

      expect(map['2330']!.foreignSharesRatio, 8.0);
      expect(map['3479']!.foreignSharesRatioChange, isNull);
    });

    test('🚨 門檻邊界寫死：T-2 放行、T-3 攔截（改門檻必紅）', () {
      // mutation testing 兩度發現問題：
      // ① `expect(..., isA<int>())` 對 static const int 是編譯期恆真；
      // ② 拿常數本身去算預期值同樣恆真（兩邊一起變）。
      // 門檻數值是這個修復的全部價值，必須用**寫死的行為**釘住：
      // 目前 foreignShareholdingMaxStaleTradingDays = 2 →
      // cutoff = fri - 2 交易日 = 7/22，故 7/22 放行、7/21 攔截。
      // 門檻改 1 → 7/22 被攔 → 本測試紅；改 3 → 7/21 放行 → 本測試紅。
      final wed = DateTime(2026, 7, 22); // T-2
      final map = BatchDataBuilder.buildShareholdingMap(
        {'PASS': entry('PASS', wed, 8.0), 'BLOCK': entry('BLOCK', tue, 8.0)},
        {
          'PASS': entry('PASS', prevFri, 7.0),
          'BLOCK': entry('BLOCK', prevFri, 7.0),
        },
        const {},
        evaluationDate: fri,
      );

      expect(
        map['PASS']!.foreignSharesRatioChange,
        isNotNull,
        reason: 'T-2 必須放行；若變 null 代表門檻被收緊到 1',
      );
      expect(
        map['BLOCK']!.foreignSharesRatioChange,
        isNull,
        reason: 'T-3 必須攔截；若非 null 代表門檻被放寬到 3 以上',
      );
    });
  });
}
