import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:afterclose/domain/services/chip_analysis_service.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ChipAnalysisService service;

  setUp(() {
    service = const ChipAnalysisService();
  });

  group('ChipAnalysisService Golden Master', () {
    test('compute returns expected score for neutral input', () {
      final result = service.compute(
        institutionalHistory: [],
        shareholdingHistory: [],
        marginHistory: [],
        dayTradingHistory: [],
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base score is 0 (no signals = no score)
      expect(result.score, 0);
      expect(result.rating, ChipRating.weak);
      expect(result.attitude, InstitutionalAttitude.neutral);
    });

    test('Institutional buy streak > 4 days adds large bonus', () {
      final history = List<DailyInstitutionalEntry>.generate(
        5,
        (i) => DailyInstitutionalEntry(
          symbol: '2330', // Dummy symbol
          date: DateTime(2023, 1, i + 1),
          foreignNet: 1000,
          investmentTrustNet: 0,
          dealerNet: 0,
        ),
      );

      final result = service.compute(
        institutionalHistory: history,
        shareholdingHistory: [],
        marginHistory: [],
        dayTradingHistory: [],
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 0 + 30 (Large Bonus) = 30
      expect(result.score, 30);
      expect(result.attitude, InstitutionalAttitude.aggressiveBuy);
    });

    test('Margin increasing streak > 4 days penalizes score', () {
      final history = List<MarginTradingEntry>.generate(
        5,
        (i) => MarginTradingEntry(
          symbol: '2330', // Dummy symbol
          date: DateTime(2023, 1, i + 1),
          marginBalance: 1000.0 + (i * 100), // Increasing
          shortBalance: 0,
        ),
      );

      final result = service.compute(
        institutionalHistory: [],
        shareholdingHistory: [],
        marginHistory: history,
        dayTradingHistory: [],
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 0 - 12 (Margin Increase Penalty) = 0 (clamped)
      expect(result.score, 0);
    });

    test('High day trading ratio penalizes score', () {
      final history = <DayTradingEntry>[
        DayTradingEntry(
          symbol: '2330', // Dummy symbol
          date: DateTime(2023, 1, 1),
          dayTradingRatio: 40.0, // > 35%
        ),
      ];

      final result = service.compute(
        institutionalHistory: [],
        shareholdingHistory: [],
        marginHistory: [],
        dayTradingHistory: history,
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 0 - 8 (Day Trading Penalty) = 0 (clamped)
      expect(result.score, 0);
    });

    test('Institutional buy streak == 2 days adds small bonus', () {
      final history = List<DailyInstitutionalEntry>.generate(
        2,
        (i) => DailyInstitutionalEntry(
          symbol: '2330',
          date: DateTime(2023, 1, i + 1),
          foreignNet: 1000,
          investmentTrustNet: 0,
          dealerNet: 0,
        ),
      );

      final result = service.compute(
        institutionalHistory: history,
        shareholdingHistory: [],
        marginHistory: [],
        dayTradingHistory: [],
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 0 + 15 (Small Bonus) = 15
      expect(result.score, 15);
    });

    test('Institutional sell streak == 2 days penalizes score', () {
      final history = List<DailyInstitutionalEntry>.generate(
        2,
        (i) => DailyInstitutionalEntry(
          symbol: '2330',
          date: DateTime(2023, 1, i + 1),
          foreignNet: -1000,
          investmentTrustNet: 0,
          dealerNet: 0,
        ),
      );

      final result = service.compute(
        institutionalHistory: history,
        shareholdingHistory: [],
        marginHistory: [],
        dayTradingHistory: [],
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 0 - 12 (Small Penalty) = 0 (clamped); 2 sell days → neutral attitude
      expect(result.score, 0);
      expect(result.attitude, InstitutionalAttitude.neutral);
    });

    test('Institutional sell streak >= 4 days adds large penalty', () {
      final history = List<DailyInstitutionalEntry>.generate(
        4,
        (i) => DailyInstitutionalEntry(
          symbol: '2330',
          date: DateTime(2023, 1, i + 1),
          foreignNet: -1000,
          investmentTrustNet: 0,
          dealerNet: 0,
        ),
      );

      final result = service.compute(
        institutionalHistory: history,
        shareholdingHistory: [],
        marginHistory: [],
        dayTradingHistory: [],
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 0 - 25 (Large Penalty) = 0 (clamped); attitude should be aggressiveSell
      expect(result.score, 0);
      expect(result.attitude, InstitutionalAttitude.aggressiveSell);
    });
  });
}
