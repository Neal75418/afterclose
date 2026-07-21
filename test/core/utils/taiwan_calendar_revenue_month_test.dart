import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/taiwan_calendar.dart';

void main() {
  group('expectedLatestRevenueMonth — 月營收發布行事曆', () {
    test('月中（10 日後）→ 上月營收應已公布', () {
      expect(
        TaiwanCalendar.expectedLatestRevenueMonth(DateTime(2026, 7, 15)),
        DateTime(2026, 6, 1),
      );
    });

    test('月初（10 日含以前）→ 上月尚未截止，只能期待上上月', () {
      expect(
        TaiwanCalendar.expectedLatestRevenueMonth(DateTime(2026, 7, 5)),
        DateTime(2026, 5, 1),
      );
      // 邊界：10 日當天視為未截止（保守，避免當天早上誤判缺資料）
      expect(
        TaiwanCalendar.expectedLatestRevenueMonth(DateTime(2026, 7, 10)),
        DateTime(2026, 5, 1),
      );
    });

    test('跨年：1 月中 → 去年 12 月；1 月初 → 去年 11 月', () {
      expect(
        TaiwanCalendar.expectedLatestRevenueMonth(DateTime(2026, 1, 15)),
        DateTime(2025, 12, 1),
      );
      expect(
        TaiwanCalendar.expectedLatestRevenueMonth(DateTime(2026, 1, 5)),
        DateTime(2025, 11, 1),
      );
    });

    test('2 月初 → 去年 12 月（上上月跨年）', () {
      expect(
        TaiwanCalendar.expectedLatestRevenueMonth(DateTime(2026, 2, 5)),
        DateTime(2025, 12, 1),
      );
    });
  });
}
