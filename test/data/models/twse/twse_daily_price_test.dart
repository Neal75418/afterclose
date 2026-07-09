import 'package:afterclose/data/models/twse/twse_daily_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TwseDailyPrice.parseRocDate', () {
    test('合法民國日期正確轉西元', () {
      expect(TwseDailyPrice.parseRocDate('1150708'), DateTime(2026, 7, 8));
    });

    test('月日越界拒絕而非靜默正規化（2/30 舊實作會變 3/2）', () {
      expect(
        () => TwseDailyPrice.parseRocDate('1150230'),
        throwsFormatException,
      );
    });

    test('長度錯誤 throw FormatException', () {
      expect(
        () => TwseDailyPrice.parseRocDate('115070'),
        throwsFormatException,
      );
      expect(
        () => TwseDailyPrice.parseRocDate('11507081'),
        throwsFormatException,
      );
    });

    test('非數字 throw FormatException', () {
      expect(
        () => TwseDailyPrice.parseRocDate('11507AB'),
        throwsFormatException,
      );
    });
  });
}
