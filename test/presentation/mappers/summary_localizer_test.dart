import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/mappers/summary_localizer.dart';

void main() {
  const localizer = SummaryLocalizer();

  /// Without full EasyLocalization widget context, `.tr()` returns the raw key.
  /// This is fine for verifying structural mapping and recursive resolution.
  /// Localization warnings are suppressed by flutter_test_config.dart.

  group('SummaryLocalizer.localize', () {
    test('should map all SummaryData fields to StockSummary', () {
      const data = SummaryData(
        overallParts: [LocalizableString('summary.noSignals')],
        keySignals: [LocalizableString('summary.netBuy')],
        riskFactors: [LocalizableString('summary.highPledge')],
        supportingData: [LocalizableString('summary.netNeutral')],
        sentiment: SummarySentiment.bullish,
        confidence: AnalysisConfidence.high,
        hasConflict: true,
        confluenceCount: 3,
      );

      final result = localizer.localize(data);

      expect(result.sentiment, SummarySentiment.bullish);
      expect(result.confidence, AnalysisConfidence.high);
      expect(result.hasConflict, isTrue);
      expect(result.confluenceCount, 3);
      expect(result.overallAssessment, isA<String>());
      expect(result.keySignals, hasLength(1));
      expect(result.riskFactors, hasLength(1));
      expect(result.supportingData, hasLength(1));
    });

    test('should join overallParts into a single string', () {
      const data = SummaryData(
        overallParts: [
          LocalizableString('partA'),
          LocalizableString('partB'),
          LocalizableString('partC'),
        ],
        sentiment: SummarySentiment.neutral,
      );

      final result = localizer.localize(data);

      // .tr() returns raw key without context → joined as "partApartBpartC"
      expect(result.overallAssessment, contains('partA'));
      expect(result.overallAssessment, contains('partB'));
      expect(result.overallAssessment, contains('partC'));
    });

    test('should handle empty lists gracefully', () {
      const data = SummaryData(
        overallParts: [LocalizableString('summary.noSignals')],
        keySignals: [],
        riskFactors: [],
        supportingData: [],
        sentiment: SummarySentiment.neutral,
      );

      final result = localizer.localize(data);

      expect(result.keySignals, isEmpty);
      expect(result.riskFactors, isEmpty);
      expect(result.supportingData, isEmpty);
      expect(result.hasSignals, isFalse);
      expect(result.hasRisks, isFalse);
      expect(result.hasSupportingData, isFalse);
    });

    test('should preserve default values', () {
      const data = SummaryData(
        overallParts: [LocalizableString('summary.noSignals')],
        sentiment: SummarySentiment.neutral,
      );

      final result = localizer.localize(data);

      expect(result.confidence, AnalysisConfidence.medium);
      expect(result.hasConflict, isFalse);
      expect(result.confluenceCount, 0);
    });
  });

  group('Recursive _resolve via nestedArgs', () {
    test('should resolve simple key without args', () {
      const data = SummaryData(
        overallParts: [LocalizableString('summary.noSignals')],
        keySignals: [LocalizableString('summary.noSignals')],
        sentiment: SummarySentiment.neutral,
      );

      final result = localizer.localize(data);

      // Without i18n context, .tr() returns key → "summary.noSignals"
      expect(result.keySignals.first, isNotEmpty);
    });

    test('should pass namedArgs to tr()', () {
      const data = SummaryData(
        overallParts: [
          LocalizableString('summary.overallUp', {
            'close': '120.5',
            'change': '3.5',
          }),
        ],
        sentiment: SummarySentiment.bullish,
      );

      final result = localizer.localize(data);

      // Key is resolved (even without actual translation, .tr() is called)
      expect(result.overallAssessment, isNotEmpty);
    });

    test('should resolve nestedArgs recursively before parent', () {
      // Simulates: institutionalFlow with nested foreign/trust keys
      const nested = LocalizableString('summary.institutionalFlow', {}, {
        'foreign': LocalizableString('summary.netBuy', {'lots': '5,000'}),
        'trust': LocalizableString('summary.netSell', {'lots': '2,000'}),
      });

      const data = SummaryData(
        overallParts: [LocalizableString('summary.noSignals')],
        supportingData: [nested],
        sentiment: SummarySentiment.neutral,
      );

      final result = localizer.localize(data);

      // The nested keys are resolved first, then injected as namedArgs
      // Verifies no crash and proper resolution chain
      expect(result.supportingData, hasLength(1));
      expect(result.supportingData.first, isA<String>());
      expect(result.supportingData.first, isNotEmpty);
    });

    test('should resolve deeply nested args (confluenceOverall)', () {
      // Simulates: confluenceOverall with nested confluence key
      const nested = LocalizableString(
        'summary.confluenceOverall',
        {'close': '105.0', 'change': '5.0'},
        {'confluence': LocalizableString('summary.confluenceVolumeBreakout')},
      );

      const data = SummaryData(
        overallParts: [nested],
        sentiment: SummarySentiment.bullish,
      );

      final result = localizer.localize(data);

      expect(result.overallAssessment, isNotEmpty);
    });

    test('should handle mixed namedArgs and nestedArgs', () {
      // Parent has both regular namedArgs and nestedArgs
      const nested = LocalizableString(
        'summary.confluenceOverall',
        {'close': '100.0', 'change': '-2.0'},
        {'confluence': LocalizableString('summary.confluenceTopReversal')},
      );

      const data = SummaryData(
        overallParts: [nested],
        sentiment: SummarySentiment.bearish,
      );

      final result = localizer.localize(data);

      // namedArgs {'close','change'} + nestedArgs {'confluence'} merged
      expect(result.overallAssessment, isNotEmpty);
    });
  });

  group('Multiple overallParts concatenation', () {
    test('should concatenate trend + supportResistance parts', () {
      const data = SummaryData(
        overallParts: [
          LocalizableString('summary.overallUp', {
            'close': '120.5',
            'change': '3.5',
          }),
          LocalizableString('summary.supportResistance', {
            'support': '115.0',
            'resistance': '125.0',
          }),
        ],
        sentiment: SummarySentiment.bullish,
      );

      final result = localizer.localize(data);

      // Both parts should be present in the joined string
      expect(result.overallAssessment, isA<String>());
      expect(
        result.overallAssessment.length,
        greaterThan('summary.overallUp'.length),
      );
    });

    test(
      'should concatenate confluenceOverall + scoreStrong + supportResistance',
      () {
        const data = SummaryData(
          overallParts: [
            LocalizableString(
              'summary.confluenceOverall',
              {'close': '105.0', 'change': '5.0'},
              {
                'confluence': LocalizableString(
                  'summary.confluenceBottomReversal',
                ),
              },
            ),
            LocalizableString('summary.scoreStrong', {'score': '75'}),
            LocalizableString('summary.supportResistance', {
              'support': '100.0',
              'resistance': '110.0',
            }),
          ],
          sentiment: SummarySentiment.bullish,
          confidence: AnalysisConfidence.high,
          confluenceCount: 2,
        );

        final result = localizer.localize(data);

        // Three parts joined
        expect(result.overallAssessment, isA<String>());
        expect(result.confidence, AnalysisConfidence.high);
        expect(result.confluenceCount, 2);
      },
    );
  });
}
