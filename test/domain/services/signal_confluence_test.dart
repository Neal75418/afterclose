import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/signal_confluence.dart';

import '../../helpers/analysis_data_generators.dart';

void main() {
  const detector = SignalConfluenceDetector();

  group('SignalConfluence.match', () {
    test('should match when all groups have at least one hit', () {
      const pattern = SignalConfluence(
        id: 'test',
        signalGroups: [
          {'A', 'B'},
          {'C', 'D'},
        ],
        summaryKey: 'test.key',
      );

      final result = pattern.match({'A', 'C', 'E'});
      expect(result, isNotNull);
      expect(result, containsAll(['A', 'C']));
    });

    test('should return null when a group has no match', () {
      const pattern = SignalConfluence(
        id: 'test',
        signalGroups: [
          {'A', 'B'},
          {'C', 'D'},
        ],
        summaryKey: 'test.key',
      );

      final result = pattern.match({'A', 'E'}); // 缺少 C or D
      expect(result, isNull);
    });

    test('should return all matched types from multiple groups', () {
      const pattern = SignalConfluence(
        id: 'test',
        signalGroups: [
          {'A', 'B'},
          {'C'},
        ],
        summaryKey: 'test.key',
      );

      // A 和 B 都在 activeTypes 中，C 也在
      final result = pattern.match({'A', 'B', 'C'});
      expect(result, isNotNull);
      expect(result, containsAll(['A', 'B', 'C']));
    });
  });

  group('SignalConfluenceDetector.detect bullish', () {
    test('should detect volume_price_breakout pattern', () {
      final reasons = [
        createTestReason(reasonType: 'TECH_BREAKOUT', ruleScore: 20),
        createTestReason(reasonType: 'VOLUME_SPIKE', rank: 2, ruleScore: 15),
      ];

      final result = detector.detect(reasons, bullish: true);

      expect(result.matchedCount, greaterThan(0));
      expect(result.consumedTypes, contains('TECH_BREAKOUT'));
      expect(result.consumedTypes, contains('VOLUME_SPIKE'));
      expect(result.summaryKeys, isNotEmpty);
    });

    test('should detect bottom_reversal pattern', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
      ];

      final result = detector.detect(reasons, bullish: true);

      expect(result.matchedCount, greaterThan(0));
      expect(result.consumedTypes, contains('REVERSAL_W2S'));
      expect(result.consumedTypes, contains('KD_GOLDEN_CROSS'));
    });

    test('should detect institutional_confirmation pattern', () {
      final reasons = [
        createTestReason(reasonType: 'INSTITUTIONAL_BUY', ruleScore: 10),
        createTestReason(reasonType: 'TECH_BREAKOUT', rank: 2, ruleScore: 20),
      ];

      final result = detector.detect(reasons, bullish: true);

      expect(result.matchedCount, greaterThan(0));
      expect(result.consumedTypes, contains('INSTITUTIONAL_BUY'));
    });

    test('should detect fundamental_technical pattern', () {
      final reasons = [
        createTestReason(reasonType: 'REVENUE_YOY_SURGE', ruleScore: 15),
        createTestReason(
          reasonType: 'MA_ALIGNMENT_BULLISH',
          rank: 2,
          ruleScore: 10,
        ),
      ];

      final result = detector.detect(reasons, bullish: true);

      expect(result.matchedCount, greaterThan(0));
      expect(result.consumedTypes, contains('REVENUE_YOY_SURGE'));
      expect(result.consumedTypes, contains('MA_ALIGNMENT_BULLISH'));
    });

    test('should return empty when no bullish confluence found', () {
      final reasons = [
        createTestReason(reasonType: 'VOLUME_SPIKE', ruleScore: 15),
        // 缺少 BREAKOUT 來組成 volume_price_breakout 模式
      ];

      final result = detector.detect(reasons, bullish: true);

      expect(result.matchedCount, 0);
      expect(result.consumedTypes, isEmpty);
      expect(result.summaryKeys, isEmpty);
    });

    test('should detect multiple confluences when signals are independent', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
        createTestReason(
          reasonType: 'REVENUE_YOY_SURGE',
          rank: 3,
          ruleScore: 15,
        ),
        createTestReason(
          reasonType: 'MA_ALIGNMENT_BULLISH',
          rank: 4,
          ruleScore: 10,
        ),
      ];

      final result = detector.detect(reasons, bullish: true);

      // bottom_reversal (W2S + KD) consumes W2S
      // fundamental_technical needs (REVENUE + W2S/BREAKOUT/MA_BULLISH)
      // → W2S already consumed, but MA_ALIGNMENT_BULLISH still available
      expect(result.matchedCount, greaterThanOrEqualTo(2));
    });

    test('should not double-count consumed signals across patterns', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
        createTestReason(
          reasonType: 'REVENUE_YOY_SURGE',
          rank: 3,
          ruleScore: 15,
        ),
        // No MA_ALIGNMENT_BULLISH or TECH_BREAKOUT → fundamental_technical
        // needs W2S (consumed by bottom_reversal) for its second group
      ];

      final result = detector.detect(reasons, bullish: true);

      // bottom_reversal matches (W2S + KD), consuming W2S
      // fundamental_technical needs REVENUE + (W2S/BREAKOUT/MA_BULLISH)
      // W2S is consumed → only 1 pattern should match
      expect(result.matchedCount, 1);
    });
  });

  group('SignalConfluenceDetector.detect bearish', () {
    test('should detect top_reversal pattern', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_S2W', ruleScore: -30),
        createTestReason(reasonType: 'KD_DEATH_CROSS', rank: 2, ruleScore: -10),
      ];

      final result = detector.detect(reasons, bullish: false);

      expect(result.matchedCount, greaterThan(0));
      expect(result.consumedTypes, contains('REVERSAL_S2W'));
      expect(result.consumedTypes, contains('KD_DEATH_CROSS'));
    });

    test('should detect bearish_breakdown pattern', () {
      final reasons = [
        createTestReason(reasonType: 'TECH_BREAKDOWN', ruleScore: -20),
        createTestReason(
          reasonType: 'MA_ALIGNMENT_BEARISH',
          rank: 2,
          ruleScore: -10,
        ),
      ];

      final result = detector.detect(reasons, bullish: false);

      expect(result.matchedCount, greaterThan(0));
      expect(result.consumedTypes, contains('TECH_BREAKDOWN'));
    });

    test('should detect value_trap pattern', () {
      final reasons = [
        createTestReason(reasonType: 'PE_UNDERVALUED', ruleScore: 10),
        createTestReason(reasonType: 'REVERSAL_S2W', rank: 2, ruleScore: -30),
      ];

      final result = detector.detect(reasons, bullish: false);

      expect(result.matchedCount, greaterThan(0));
      expect(result.consumedTypes, contains('PE_UNDERVALUED'));
      expect(result.consumedTypes, contains('REVERSAL_S2W'));
    });

    test('should not match bullish patterns when detecting bearish', () {
      final reasons = [
        createTestReason(reasonType: 'REVERSAL_W2S', ruleScore: 35),
        createTestReason(reasonType: 'KD_GOLDEN_CROSS', rank: 2, ruleScore: 10),
      ];

      final result = detector.detect(reasons, bullish: false);

      expect(result.matchedCount, 0);
    });
  });
}
