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

      // Base score is 50
      expect(result.score, 50);
      expect(result.rating, ChipRating.neutral);
      expect(result.attitude, InstitutionalAttitude.neutral);
    });

    test('Institutional buy streak > 4 days adds large bonus', () {
      final history = List<DailyInstitutionalEntry>.generate(5, (i) => DailyInstitutionalEntry(
        symbol: '2330', // Dummy symbol
        date: DateTime(2023, 1, i + 1),
        foreignNet: 1000,
        investmentTrustNet: 0,
        dealerNet: 0,
      ));

      final result = service.compute(
        institutionalHistory: history,
        shareholdingHistory: [],
        marginHistory: [],
        dayTradingHistory: [],
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 50 + 20 (Large Bonus) = 70
      expect(result.score, 70);
      expect(result.attitude, InstitutionalAttitude.aggressiveBuy);
    });

    test('Margin increasing streak > 4 days penalizes score', () {
      final history = List<MarginTradingEntry>.generate(5, (i) => MarginTradingEntry(
        symbol: '2330', // Dummy symbol
        date: DateTime(2023, 1, i + 1),
        marginBalance: 1000.0 + (i * 100), // Increasing
        shortBalance: 0,
      ));

      final result = service.compute(
        institutionalHistory: [],
        shareholdingHistory: [],
        marginHistory: history,
        dayTradingHistory: [],
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 50 - 8 (Margin Increase Penalty) = 42
      expect(result.score, 42);
    });

    test('High day trading ratio penalties score', () {
      final history = <DayTradingEntry>[
        DayTradingEntry(
          symbol: '2330', // Dummy symbol
          date: DateTime(2023, 1, 1),
          dayTradingRatio: 40.0, // > 35%
        )
      ];

      final result = service.compute(
        institutionalHistory: [],
        shareholdingHistory: [],
        marginHistory: [],
        dayTradingHistory: history,
        holdingDistribution: [],
        insiderHistory: [],
      );

      // Base 50 - 5 (Day Trading Penalty) = 45
      expect(result.score, 45);
    });

  });
}
