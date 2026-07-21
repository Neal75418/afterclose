// 族群排行視窗常數 vs 台股行事曆的最壞情境驗證
//
// 「法人3日」的日曆天回看視窗必須在 CNY 連假（2026-02-12~20，9 日曆天）
// 收假首日仍涵蓋 ≥3 個交易日——否則收假當天查出來只有 1 個交易日、
// UI 標「法人3日」但實際只加總 1 日（靜默低估，審查發現）。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';

void main() {
  int tradingDaysInWindow(DateTime analysisDate, int calendarDays) {
    final start = analysisDate.subtract(Duration(days: calendarDays));
    var count = 0;
    for (
      var d = start;
      !d.isAfter(analysisDate);
      d = d.add(const Duration(days: 1))
    ) {
      if (TaiwanCalendar.isTradingDay(d)) count++;
    }
    return count;
  }

  group('SectorParams 排行視窗 vs 行事曆最壞情境', () {
    test('法人視窗在 2026 CNY 收假首日仍涵蓋 ≥3 個交易日', () {
      // 2026-02-23 = CNY 連假後第一個交易日（最壞情境）
      final reopening = DateTime(2026, 2, 23);
      expect(TaiwanCalendar.isTradingDay(reopening), isTrue);
      expect(
        tradingDaysInWindow(
          reopening,
          SectorParams.rankingInstitutionalCalendarDays,
        ),
        greaterThanOrEqualTo(3),
      );
    });

    test('價格視窗在 2026 CNY 收假首日仍涵蓋 ≥21 個交易日', () {
      final reopening = DateTime(2026, 2, 23);
      expect(
        tradingDaysInWindow(reopening, SectorParams.rankingHistoryCalendarDays),
        greaterThanOrEqualTo(21),
      );
    });
  });
}
