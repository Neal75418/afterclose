import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/utils/date_context.dart';

void main() {
  group('DateContext', () {
    group('factory constructors', () {
      test('DateContext.now() creates context with today at midnight', () {
        final ctx = DateContext.now();
        final now = DateTime.now();

        expect(ctx.today.year, equals(now.year));
        expect(ctx.today.month, equals(now.month));
        expect(ctx.today.day, equals(now.day));
        expect(ctx.today.hour, equals(0));
        expect(ctx.today.minute, equals(0));
        expect(ctx.today.second, equals(0));
      });

      test(
        'DateContext.now() creates historyStart 5 days before by default',
        () {
          final ctx = DateContext.now();

          final expectedHistoryStart = ctx.today.subtract(
            const Duration(days: 5),
          );
          expect(ctx.historyStart, equals(expectedHistoryStart));
        },
      );

      test('DateContext.now() accepts custom historyDays', () {
        final ctx = DateContext.now(historyDays: 10);

        final expectedHistoryStart = ctx.today.subtract(
          const Duration(days: 10),
        );
        expect(ctx.historyStart, equals(expectedHistoryStart));
      });

      test('DateContext.forDate() normalizes given date to midnight', () {
        final date = DateTime(2024, 6, 15, 14, 30, 45);
        final ctx = DateContext.forDate(date);

        expect(ctx.today, equals(DateTime(2024, 6, 15)));
        expect(ctx.today.hour, equals(0));
      });

      test('DateContext.forDate() sets historyStart correctly', () {
        final date = DateTime(2024, 6, 15);
        final ctx = DateContext.forDate(date, historyDays: 7);

        expect(ctx.historyStart, equals(DateTime(2024, 6, 8)));
      });

      test(
        'DateContext.withLookback() creates context with custom lookback',
        () {
          final ctx = DateContext.withLookback(30);

          final expectedHistoryStart = ctx.today.subtract(
            const Duration(days: 30),
          );
          expect(ctx.historyStart, equals(expectedHistoryStart));
        },
      );
    });

    group('normalize', () {
      test('normalizes datetime to midnight', () {
        final date = DateTime(2024, 3, 15, 10, 30, 45, 123, 456);
        final normalized = DateContext.normalize(date);

        expect(normalized.year, equals(2024));
        expect(normalized.month, equals(3));
        expect(normalized.day, equals(15));
        expect(normalized.hour, equals(0));
        expect(normalized.minute, equals(0));
        expect(normalized.second, equals(0));
        expect(normalized.millisecond, equals(0));
        expect(normalized.microsecond, equals(0));
      });

      test('normalizing already normalized date returns same value', () {
        final date = DateTime(2024, 3, 15);
        final normalized = DateContext.normalize(date);

        expect(normalized, equals(date));
      });
    });

    group('isSameDay', () {
      test('returns true for same day different times', () {
        final a = DateTime(2024, 3, 15, 10, 30);
        final b = DateTime(2024, 3, 15, 22, 45);

        expect(DateContext.isSameDay(a, b), isTrue);
      });

      test('returns false for different days', () {
        final a = DateTime(2024, 3, 15);
        final b = DateTime(2024, 3, 16);

        expect(DateContext.isSameDay(a, b), isFalse);
      });

      test('returns false for different months same day number', () {
        final a = DateTime(2024, 3, 15);
        final b = DateTime(2024, 4, 15);

        expect(DateContext.isSameDay(a, b), isFalse);
      });

      test('returns false for different years same month and day', () {
        final a = DateTime(2024, 3, 15);
        final b = DateTime(2025, 3, 15);

        expect(DateContext.isSameDay(a, b), isFalse);
      });
    });

    group('earlierOf', () {
      test('returns earlier date when both are non-null', () {
        final earlier = DateTime(2024, 3, 10);
        final later = DateTime(2024, 3, 15);

        final result = DateContext.earlierOf(earlier, later);
        expect(result, equals(DateContext.normalize(earlier)));

        final result2 = DateContext.earlierOf(later, earlier);
        expect(result2, equals(DateContext.normalize(earlier)));
      });

      test('returns normalized date when other is null', () {
        final date = DateTime(2024, 3, 15, 10, 30);

        expect(
          DateContext.earlierOf(date, null),
          equals(DateContext.normalize(date)),
        );
        expect(
          DateContext.earlierOf(null, date),
          equals(DateContext.normalize(date)),
        );
      });

      test('returns null when both are null', () {
        expect(DateContext.earlierOf(null, null), isNull);
      });
    });

    group('isBeforeOrEqual', () {
      test('returns true when a is before b', () {
        final a = DateTime(2024, 3, 10);
        final b = DateTime(2024, 3, 15);

        expect(DateContext.isBeforeOrEqual(a, b), isTrue);
      });

      test('returns true when a equals b (same day)', () {
        final a = DateTime(2024, 3, 15, 10, 30);
        final b = DateTime(2024, 3, 15, 22, 45);

        expect(DateContext.isBeforeOrEqual(a, b), isTrue);
      });

      test('returns false when a is after b', () {
        final a = DateTime(2024, 3, 20);
        final b = DateTime(2024, 3, 15);

        expect(DateContext.isBeforeOrEqual(a, b), isFalse);
      });
    });

    group('formatYmd', () {
      test('formats date as YYYY-MM-DD', () {
        final date = DateTime(2024, 3, 15);
        expect(DateContext.formatYmd(date), equals('2024-03-15'));
      });

      test('pads single digit month with zero', () {
        final date = DateTime(2024, 1, 15);
        expect(DateContext.formatYmd(date), equals('2024-01-15'));
      });

      test('pads single digit day with zero', () {
        final date = DateTime(2024, 12, 5);
        expect(DateContext.formatYmd(date), equals('2024-12-05'));
      });

      test('handles year with less than 4 digits', () {
        final date = DateTime(999, 1, 1);
        expect(DateContext.formatYmd(date), equals('999-01-01'));
      });
    });

    group('tryParseYmd', () {
      test('parses valid YYYY-MM-DD string', () {
        final result = DateContext.tryParseYmd('2024-03-15');

        expect(result, isNotNull);
        expect(result!.year, equals(2024));
        expect(result.month, equals(3));
        expect(result.day, equals(15));
      });

      test('returns null for invalid format', () {
        expect(DateContext.tryParseYmd('invalid'), isNull);
        expect(DateContext.tryParseYmd('2024/03/15'), isNull);
        expect(DateContext.tryParseYmd('15-03-2024'), isNull);
      });

      test('returns null for null input', () {
        expect(DateContext.tryParseYmd(null), isNull);
      });

      test('returns null for empty string', () {
        expect(DateContext.tryParseYmd(''), isNull);
      });

      test('parses ISO 8601 datetime string', () {
        final result = DateContext.tryParseYmd('2024-03-15T10:30:00');

        expect(result, isNotNull);
        expect(result!.year, equals(2024));
        expect(result.month, equals(3));
        expect(result.day, equals(15));
      });
    });

    group('parseYmdOr', () {
      test('parses valid string', () {
        final defaultValue = DateTime(2000, 1, 1);
        final result = DateContext.parseYmdOr('2024-03-15', defaultValue);

        expect(result.year, equals(2024));
        expect(result.month, equals(3));
        expect(result.day, equals(15));
      });

      test('returns default for invalid string', () {
        final defaultValue = DateTime(2000, 1, 1);
        final result = DateContext.parseYmdOr('invalid', defaultValue);

        expect(result, equals(defaultValue));
      });

      test('returns default for null', () {
        final defaultValue = DateTime(2000, 1, 1);
        final result = DateContext.parseYmdOr(null, defaultValue);

        expect(result, equals(defaultValue));
      });
    });
  });
}
