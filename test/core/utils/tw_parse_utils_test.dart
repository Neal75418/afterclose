import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/tw_parse_utils.dart';

void main() {
  group('TwParseUtils', () {
    group('parseFormattedDouble', () {
      test('parses integer string', () {
        expect(TwParseUtils.parseFormattedDouble('1234'), 1234.0);
      });

      test('parses decimal string', () {
        expect(TwParseUtils.parseFormattedDouble('123.45'), 123.45);
      });

      test('parses comma-formatted string', () {
        expect(TwParseUtils.parseFormattedDouble('1,234,567'), 1234567.0);
      });

      test('parses comma-formatted decimal', () {
        expect(TwParseUtils.parseFormattedDouble('1,234.56'), 1234.56);
      });

      test('parses negative number', () {
        expect(TwParseUtils.parseFormattedDouble('-100.5'), -100.5);
      });

      test('returns null for null', () {
        expect(TwParseUtils.parseFormattedDouble(null), isNull);
      });

      test('returns null for empty string', () {
        expect(TwParseUtils.parseFormattedDouble(''), isNull);
      });

      test('returns null for "--"', () {
        expect(TwParseUtils.parseFormattedDouble('--'), isNull);
      });

      test('returns null for "X"', () {
        expect(TwParseUtils.parseFormattedDouble('X'), isNull);
      });

      test('returns null for "---"', () {
        expect(TwParseUtils.parseFormattedDouble('---'), isNull);
      });

      test('handles whitespace', () {
        expect(TwParseUtils.parseFormattedDouble('  100  '), 100.0);
      });

      test('parses integer value directly', () {
        expect(TwParseUtils.parseFormattedDouble(42), 42.0);
      });

      test('parses double value directly', () {
        expect(TwParseUtils.parseFormattedDouble(3.14), 3.14);
      });
    });

    group('parseAdDate', () {
      test('parses valid YYYYMMDD date', () {
        final result = TwParseUtils.parseAdDate('20260121');

        expect(result.year, 2026);
        expect(result.month, 1);
        expect(result.day, 21);
      });

      test('parses end of month date', () {
        final result = TwParseUtils.parseAdDate('20251231');

        expect(result.year, 2025);
        expect(result.month, 12);
        expect(result.day, 31);
      });

      test('returns today for invalid length', () {
        final result = TwParseUtils.parseAdDate('2026');
        final now = DateTime.now();

        expect(result.year, now.year);
        expect(result.month, now.month);
        expect(result.day, now.day);
      });

      test('returns today for empty string', () {
        final result = TwParseUtils.parseAdDate('');
        final now = DateTime.now();

        expect(result.year, now.year);
      });
    });

    group('parseSlashRocDate', () {
      test('parses valid ROC date "114/01/24"', () {
        final result = TwParseUtils.parseSlashRocDate('114/01/24');

        expect(result, isNotNull);
        expect(result!.year, 2025);
        expect(result.month, 1);
        expect(result.day, 24);
      });

      test('parses ROC year 115', () {
        final result = TwParseUtils.parseSlashRocDate('115/06/15');

        expect(result, isNotNull);
        expect(result!.year, 2026);
        expect(result.month, 6);
        expect(result.day, 15);
      });

      test('returns null for invalid format', () {
        expect(TwParseUtils.parseSlashRocDate('2025-01-24'), isNull);
      });

      test('returns null for invalid month', () {
        expect(TwParseUtils.parseSlashRocDate('114/13/01'), isNull);
      });

      test('returns null for invalid day (Feb 30)', () {
        expect(TwParseUtils.parseSlashRocDate('114/02/30'), isNull);
      });

      test('returns null for zero month', () {
        expect(TwParseUtils.parseSlashRocDate('114/00/01'), isNull);
      });

      test('returns null for non-numeric parts', () {
        expect(TwParseUtils.parseSlashRocDate('abc/01/01'), isNull);
      });
    });

    group('parseCompactRocDate', () {
      test('parses valid compact ROC date "1140124"', () {
        final result = TwParseUtils.parseCompactRocDate('1140124');

        expect(result, isNotNull);
        expect(result!.year, 2025);
        expect(result.month, 1);
        expect(result.day, 24);
      });

      test('parses "1150615"', () {
        final result = TwParseUtils.parseCompactRocDate('1150615');

        expect(result, isNotNull);
        expect(result!.year, 2026);
        expect(result.month, 6);
        expect(result.day, 15);
      });

      test('returns null for null', () {
        expect(TwParseUtils.parseCompactRocDate(null), isNull);
      });

      test('returns null for too short string', () {
        expect(TwParseUtils.parseCompactRocDate('11401'), isNull);
      });

      test('returns null for invalid date (Feb 30)', () {
        expect(TwParseUtils.parseCompactRocDate('1140230'), isNull);
      });

      test('returns null for invalid month', () {
        expect(TwParseUtils.parseCompactRocDate('1141301'), isNull);
      });
    });

    group('toRocDateString', () {
      test('converts AD to ROC format', () {
        final result = TwParseUtils.toRocDateString(DateTime(2025, 1, 24));

        expect(result, '114/01/24');
      });

      test('converts year 2026', () {
        final result = TwParseUtils.toRocDateString(DateTime(2026, 12, 31));

        expect(result, '115/12/31');
      });

      test('pads single-digit month and day', () {
        final result = TwParseUtils.toRocDateString(DateTime(2025, 3, 5));

        expect(result, '114/03/05');
      });
    });

    group('formatDateYmd', () {
      test('formats date as YYYY-MM-DD', () {
        expect(TwParseUtils.formatDateYmd(DateTime(2025, 6, 15)), '2025-06-15');
      });

      test('pads single digits', () {
        expect(TwParseUtils.formatDateYmd(DateTime(2025, 1, 5)), '2025-01-05');
      });
    });

    group('formatDateCompact', () {
      test('formats date as YYYYMMDD', () {
        expect(
          TwParseUtils.formatDateCompact(DateTime(2025, 6, 15)),
          '20250615',
        );
      });

      test('pads single digits', () {
        expect(
          TwParseUtils.formatDateCompact(DateTime(2025, 1, 5)),
          '20250105',
        );
      });
    });

    group('round-trip conversions', () {
      test('parseSlashRocDate → toRocDateString preserves date', () {
        const rocStr = '114/06/15';
        final parsed = TwParseUtils.parseSlashRocDate(rocStr);
        final formatted = TwParseUtils.toRocDateString(parsed!);

        expect(formatted, rocStr);
      });

      test('parseAdDate → formatDateCompact preserves date', () {
        const adStr = '20250615';
        final parsed = TwParseUtils.parseAdDate(adStr);
        final formatted = TwParseUtils.formatDateCompact(parsed);

        expect(formatted, adStr);
      });
    });
  });
}
