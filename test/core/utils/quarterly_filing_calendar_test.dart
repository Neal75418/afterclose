import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/core/utils/quarterly_filing_calendar.dart';

/// 季報法定申報窗口(2026-08-06 季報總覽入口的顯示 gate)。
///
/// 期限依證期局規定(一般公司):Q1=5/15、Q2=8/14、Q3=11/14、
/// 年報(含 Q4)=3/31。窗口起點取季結束後申報潮實際開始的月初
/// (7/1、10/1、4/1、1/1)。窗口只決定入口文案模式(公布中 vs 總表),
/// 入口本身常駐——2026-08-06 定案,理由見 QuarterlyFilingEntrySection。
void main() {
  ({int year, int quarter})? at(int y, int m, int d) =>
      QuarterlyFilingCalendar.expectedFilingQuarter(DateTime(y, m, d));

  test('Q2 窗口:7/1~8/14 → 當年 Q2', () {
    expect(at(2026, 7, 1), (year: 2026, quarter: 2));
    expect(at(2026, 8, 6), (year: 2026, quarter: 2));
    expect(at(2026, 8, 14), (year: 2026, quarter: 2));
    expect(at(2026, 8, 15), isNull, reason: '期限翌日入口收起');
  });

  test('Q3 窗口:10/1~11/14 → 當年 Q3', () {
    expect(at(2026, 10, 1), (year: 2026, quarter: 3));
    expect(at(2026, 11, 14), (year: 2026, quarter: 3));
    expect(at(2026, 11, 15), isNull);
  });

  test('年報窗口:1/1~3/31 → 去年 Q4', () {
    expect(at(2026, 1, 1), (year: 2025, quarter: 4));
    expect(at(2026, 3, 31), (year: 2025, quarter: 4));
  });

  test('Q1 窗口:4/1~5/15 → 當年 Q1', () {
    expect(at(2026, 4, 1), (year: 2026, quarter: 1));
    expect(at(2026, 5, 15), (year: 2026, quarter: 1));
    expect(at(2026, 5, 16), isNull);
  });

  test('空窗月(6、9、12)→ null', () {
    expect(at(2026, 6, 15), isNull);
    expect(at(2026, 9, 1), isNull);
    expect(at(2026, 12, 31), isNull);
  });
}
