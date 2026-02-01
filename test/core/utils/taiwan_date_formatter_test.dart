import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/taiwan_date_formatter.dart';

void main() {
  group('TaiwanDateFormatter', () {
    test('toROCYear converts correctly', () {
      expect(TaiwanDateFormatter.toROCYear(2024), 113);
      expect(TaiwanDateFormatter.toROCYear(2025), 114);
      expect(TaiwanDateFormatter.toROCYear(1912), 1);
    });

    test('formatYear adds 年 suffix', () {
      expect(TaiwanDateFormatter.formatYear(2024), '113 年');
    });

    test('formatYearMonth pads month', () {
      expect(TaiwanDateFormatter.formatYearMonth(2024, 1), '113/01');
      expect(TaiwanDateFormatter.formatYearMonth(2024, 12), '113/12');
    });

    test('formatQuarter formats correctly', () {
      expect(TaiwanDateFormatter.formatQuarter(2024, 1), '113 Q1');
      expect(TaiwanDateFormatter.formatQuarter(2024, 4), '113 Q4');
    });

    test('formatDualYear shows both calendars', () {
      expect(TaiwanDateFormatter.formatDualYear(2024), '2024 (民113)');
      expect(TaiwanDateFormatter.formatDualYear(2025), '2025 (民114)');
    });
  });
}
