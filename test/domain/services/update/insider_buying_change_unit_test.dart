// 董監增持幅度的單位不變量 — P1-5
//
// `InsiderSignificantBuyingRule` 拿 buyingChange 與
// `FundamentalParams.insiderSignificantBuyingThreshold = 5.0` 比較，
// 並格式化成「董監增持 X%」——這個值的單位是**百分點**，來自
// `insider_repository.dart` 的 `latestRatio - previousRatio`
// （insiderRatio 的欄位註解為「董監持股比例（%）」）。
//
// 但 buildInsiderMap 曾寫成 `status?.buyingChange ?? v.sharesChange`，
// 而 sharesChange 的欄位註解是「持股變動（股）」——完全不同的單位。
// 一旦回退生效，「增持一萬股」會被當成「增持 10000 個百分點」，
// 輕鬆越過 5.0 門檻並顯示「董監增持 10000.0%」。
//
// 目前這條回退實際上摸不到，因為閘門 hasSignificantBuying 在快照
// 少於 2 筆時恆為 false，而 DB 裡 shares_change 1965 筆全是 NULL。
// 正因為它「看起來像保險絲、其實雙重無效」，更該移除——留著只會讓
// 下一個讀 code 的人以為有保護。此測試釘住單位不得混用。
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/update/batch_data_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('🚨 無法計算增持幅度時必須是 null，不得回退成股數', () async {
    // 快照只有 1 筆 → 算不出與前期的比例差；此時 sharesChange 是「股」，
    // 借來當「百分點」用會製造假訊號。
    final entries = {
      'TEST': InsiderHoldingEntry(
        symbol: 'TEST',
        date: DateTime(2026, 7, 15),
        insiderRatio: 25.0, // %
        sharesChange: 50000, // 股 —— 絕不可被當成 50000 個百分點
      ),
    };

    // insiderRepo 為 null → status 全缺，正是「算不出來」的情境
    final result = await BatchDataBuilder.buildInsiderMap(entries, [
      'TEST',
    ], null);

    expect(
      result['TEST']!.buyingChange,
      isNull,
      reason: '算不出百分點就該誠實留 null；借股數頂替會讓「增持 5 萬股」變成「增持 50000%」',
    );
  });

  test('比例與質押率照常帶出，不受影響', () async {
    final entries = {
      'TEST': InsiderHoldingEntry(
        symbol: 'TEST',
        date: DateTime(2026, 7, 15),
        insiderRatio: 25.0,
        pledgeRatio: 3.5,
        sharesChange: 50000,
      ),
    };

    final result = await BatchDataBuilder.buildInsiderMap(entries, [
      'TEST',
    ], null);

    expect(result['TEST']!.insiderRatio, 25.0);
    expect(result['TEST']!.pledgeRatio, 3.5);
    expect(result['TEST']!.hasSignificantBuying, isFalse);
    expect(result['TEST']!.sellingStreakMonths, 0);
  });
}
