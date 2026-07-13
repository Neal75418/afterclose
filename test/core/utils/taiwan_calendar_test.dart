import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/taiwan_calendar.dart';

void main() {
  group('TaiwanCalendar.isTradingDay', () {
    test('平日交易日為 true、週末為 false', () {
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 7, 13)), isTrue); // 週一
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 7, 11)), isFalse); // 週六
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 7, 12)), isFalse); // 週日
    });

    test('2025 年新增國定假日休市（教師節/光復節補假、行憲紀念日）', () {
      // 漏掉這三天曾讓 HistoricalPriceSyncer phase 0 把它們當缺漏日
      // 反覆抓到空回應（TWSE 官方無資料）觸發斷路器
      expect(TaiwanCalendar.isTradingDay(DateTime(2025, 9, 29)), isFalse);
      expect(TaiwanCalendar.isTradingDay(DateTime(2025, 10, 24)), isFalse);
      expect(TaiwanCalendar.isTradingDay(DateTime(2025, 12, 25)), isFalse);
    });

    test('2026-07-10 颱風停市（TWSE 證實 20260710 無交易資料）', () {
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 7, 10)), isFalse);
    });

    test('2026 年版新增國定假日休市', () {
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 9, 28)), isFalse);
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 10, 26)), isFalse);
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 12, 25)), isFalse);
    });

    test('既有假日維持休市（迴歸）', () {
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 2, 16)), isFalse); // 春節
      expect(TaiwanCalendar.isTradingDay(DateTime(2026, 6, 19)), isFalse); // 端午
      expect(TaiwanCalendar.isTradingDay(DateTime(2025, 10, 6)), isFalse); // 中秋
    });
  });
}
