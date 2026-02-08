import 'package:afterclose/domain/services/scoring_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScoringIsolateInput date serialization', () {
    test('should round-trip date through toMap/fromMap', () {
      final date = DateTime(2025, 1, 15, 12, 30);
      final input = ScoringIsolateInput(
        candidates: ['2330'],
        pricesMap: {'2330': []},
        newsMap: {'2330': []},
        institutionalMap: {'2330': []},
        date: date,
      );

      final map = input.toMap();
      final restored = ScoringIsolateInput.fromMap(map);

      expect(restored.date, isNotNull);
      expect(
        restored.date!.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      );
    });

    test('should handle null date', () {
      const input = ScoringIsolateInput(
        candidates: ['2330'],
        pricesMap: {'2330': []},
        newsMap: {'2330': []},
        institutionalMap: {'2330': []},
      );

      final map = input.toMap();
      final restored = ScoringIsolateInput.fromMap(map);

      expect(restored.date, isNull);
    });

    test('should preserve date alongside other fields', () {
      final date = DateTime(2025, 6, 1);
      final input = ScoringIsolateInput(
        candidates: ['2330', '2317'],
        pricesMap: {
          '2330': [
            {'date': '2025-06-01', 'close': 600.0},
          ],
        },
        newsMap: {'2330': []},
        institutionalMap: {},
        date: date,
        recentlyRecommended: {'1234'},
      );

      final map = input.toMap();
      final restored = ScoringIsolateInput.fromMap(map);

      expect(restored.candidates, ['2330', '2317']);
      expect(restored.date, isNotNull);
      expect(restored.recentlyRecommended, {'1234'});
    });
  });
}
