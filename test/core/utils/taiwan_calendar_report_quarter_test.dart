// TaiwanCalendar.expectedLatestReportQuarter — 台股財報發布行事曆
//
// 語意：給定當下時間，回傳「此刻應已發布的最新一季」的**季度起始日**。
// 依台股申報期限（Q1→5/15、Q2→8/14、Q3→11/14、年報→3/31）取保守月界：
// 1-3 月只能期待前一年 Q3（起始 7/1）、4 月起才期待前一年 Q4（10/1）。
// 與 financial_data 的季度截止日比較時使用
// 「latestDate 不早於季度起始日 → 已有該季」判斷。
//
// 背景：損益表原本用「距今 < 60 天」啟發式，但財報日期是季度截止日，
// 每季發布後僅 ~2-6 週「新鮮」，其餘時間每次更新都重抓全部候選股
// （2026-07-14 實測：54 檔 × ~112 筆/次）。資產負債表的行事曆感知檢查
// 無此問題，本 helper 即其邏輯的共用化。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/taiwan_calendar.dart';

void main() {
  group('expectedLatestReportQuarter — 月界矩陣', () {
    test('1-3 月：前一年 Q3 起始 7/1（年報 3/31 才截止，Q4 尚不可期待）', () {
      // ⚠️ 不是 10/1（Q4 起始）：Q3 截止日 9/30 < 10/1 會被判「缺最新季」，
      // 1-3 月每輪更新都重抓——與 60 天啟發式同型的死區（review 抓到的
      // 繼承 bug，原資產負債表路徑亦中）。
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 1, 15)),
        DateTime(2025, 7, 1),
      );
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 2, 28)),
        DateTime(2025, 7, 1),
      );
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 3, 31)),
        DateTime(2025, 7, 1),
      );
    });

    test('4 月：前一年 Q4（年報 3/31 已截止）', () {
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 4, 1)),
        DateTime(2025, 10, 1),
      );
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 4, 30)),
        DateTime(2025, 10, 1),
      );
    });

    test('5-7 月：當年 Q1', () {
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 5, 1)),
        DateTime(2026, 1, 1),
      );
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 7, 14)),
        DateTime(2026, 1, 1),
      );
    });

    test('8-10 月：當年 Q2', () {
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 8, 1)),
        DateTime(2026, 4, 1),
      );
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 10, 31)),
        DateTime(2026, 4, 1),
      );
    });

    test('11-12 月：當年 Q3', () {
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 11, 1)),
        DateTime(2026, 7, 1),
      );
      expect(
        TaiwanCalendar.expectedLatestReportQuarter(DateTime(2026, 12, 31)),
        DateTime(2026, 7, 1),
      );
    });
  });

  group('與季度截止日的判斷語意（isBefore 比較）', () {
    test('DB 有 Q1 截止日 3/31、預期 Q1 起始 1/1 → 不早於 → 已有該季', () {
      final expected = TaiwanCalendar.expectedLatestReportQuarter(
        DateTime(2026, 7, 14),
      );
      expect(DateTime(2026, 3, 31).isBefore(expected), isFalse);
    });

    test('DB 有 Q1 截止日 3/31、8 月預期 Q2 起始 4/1 → 早於 → 缺最新季', () {
      final expected = TaiwanCalendar.expectedLatestReportQuarter(
        DateTime(2026, 8, 20),
      );
      expect(DateTime(2026, 3, 31).isBefore(expected), isTrue);
    });

    test('DB 有 Q3 截止日 9/30、隔年 2 月 → 不早於 7/1 → 已有該季（不重抓）', () {
      final expected = TaiwanCalendar.expectedLatestReportQuarter(
        DateTime(2026, 2, 1),
      );
      expect(DateTime(2025, 9, 30).isBefore(expected), isFalse);
    });

    test('DB 只有 Q3 截止日 9/30、隔年 4 月（年報已截止）→ 早於 10/1 → 補抓', () {
      final expected = TaiwanCalendar.expectedLatestReportQuarter(
        DateTime(2026, 4, 15),
      );
      expect(DateTime(2025, 9, 30).isBefore(expected), isTrue);
    });

    test('DB 有 Q4 截止日 12/31、隔年 4 月 → 不早於 10/1 → 已有該季', () {
      final expected = TaiwanCalendar.expectedLatestReportQuarter(
        DateTime(2026, 4, 15),
      );
      expect(DateTime(2025, 12, 31).isBefore(expected), isFalse);
    });
  });
}
