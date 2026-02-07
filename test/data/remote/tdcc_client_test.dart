import 'package:afterclose/data/remote/tdcc_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ==========================================
  // levelCodeToRangeString
  // ==========================================
  group('TdccClient.levelCodeToRangeString', () {
    test('converts level 1 to "0-1"', () {
      expect(TdccClient.levelCodeToRangeString(1), equals('0-1'));
    });

    test('converts level 2 to "1-5"', () {
      expect(TdccClient.levelCodeToRangeString(2), equals('1-5'));
    });

    test('converts level 12 to "400-600" (matches threshold)', () {
      expect(TdccClient.levelCodeToRangeString(12), equals('400-600'));
    });

    test('converts level 13 to "600-800"', () {
      expect(TdccClient.levelCodeToRangeString(13), equals('600-800'));
    });

    test('converts level 14 to "800-1000"', () {
      expect(TdccClient.levelCodeToRangeString(14), equals('800-1000'));
    });

    test('converts level 15 to "1000以上"', () {
      expect(TdccClient.levelCodeToRangeString(15), equals('1000以上'));
    });

    test('falls back to string representation for unknown levels', () {
      expect(TdccClient.levelCodeToRangeString(99), equals('99'));
    });

    test('all 15 levels produce non-empty strings', () {
      for (var i = 1; i <= 15; i++) {
        final result = TdccClient.levelCodeToRangeString(i);
        expect(result, isNotEmpty, reason: 'Level $i should produce non-empty');
        expect(
          result,
          isNot(equals('$i')),
          reason: 'Level $i should have a named range',
        );
      }
    });
  });

  // ==========================================
  // TdccHoldingLevel DTO
  // ==========================================
  group('TdccHoldingLevel', () {
    test('can be constructed with all fields', () {
      final level = TdccHoldingLevel(
        date: DateTime(2026, 1, 31),
        symbol: '2330',
        level: 12,
        shareholders: 1500,
        shares: 450000000,
        percent: 35.5,
      );

      expect(level.date, equals(DateTime(2026, 1, 31)));
      expect(level.symbol, equals('2330'));
      expect(level.level, equals(12));
      expect(level.shareholders, equals(1500));
      expect(level.shares, equals(450000000));
      expect(level.percent, equals(35.5));
    });
  });

  // ==========================================
  // Level range string compatibility with _parseMinSharesFromLevel
  // ==========================================
  group('Level range string compatibility', () {
    // Simulate _parseMinSharesFromLevel logic
    int parseMinSharesFromLevel(String level) {
      if (level.contains('以上') || level.toLowerCase().contains('over')) {
        final numStr = level.replaceAll(RegExp(r'[^\d]'), '');
        return int.tryParse(numStr) ?? 0;
      }
      final parts = level.split('-');
      if (parts.isNotEmpty) {
        final numStr = parts[0].replaceAll(RegExp(r'[^\d]'), '');
        return int.tryParse(numStr) ?? 0;
      }
      return 0;
    }

    test('levels 12-15 match threshold 400', () {
      const threshold = 400;
      for (var code = 12; code <= 15; code++) {
        final rangeStr = TdccClient.levelCodeToRangeString(code);
        final minShares = parseMinSharesFromLevel(rangeStr);
        expect(
          minShares >= threshold,
          isTrue,
          reason:
              'Level $code ("$rangeStr") min=$minShares should >= $threshold',
        );
      }
    });

    test('levels 1-11 do not match threshold 400', () {
      const threshold = 400;
      for (var code = 1; code <= 11; code++) {
        final rangeStr = TdccClient.levelCodeToRangeString(code);
        final minShares = parseMinSharesFromLevel(rangeStr);
        expect(
          minShares < threshold,
          isTrue,
          reason:
              'Level $code ("$rangeStr") min=$minShares should < $threshold',
        );
      }
    });
  });
}
