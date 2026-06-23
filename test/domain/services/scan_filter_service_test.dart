import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/scan_models.dart';
import 'package:afterclose/domain/services/scan_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ScanFilterService();

  // Helper: create a DailyAnalysisEntry。[scoreLong] 省略時等於 [score]（短=長），
  // 需測 horizon 分歧時才顯式給不同值。
  DailyAnalysisEntry createAnalysis({
    required String symbol,
    double score = 50.0,
    double? scoreLong,
    String trendState = 'UP',
  }) {
    return DailyAnalysisEntry(
      symbol: symbol,
      date: DateTime(2025, 1, 15),
      trendState: trendState,
      reversalState: 'NONE',
      scoreShort: score,
      scoreLong: scoreLong ?? score,
      computedAt: DateTime(2025, 1, 15),
    );
  }

  // Helper: create a DailyReasonEntry
  DailyReasonEntry createReason({
    required String symbol,
    required String reasonType,
    int rank = 1,
  }) {
    return DailyReasonEntry(
      symbol: symbol,
      date: DateTime(2025, 1, 15),
      rank: rank,
      reasonType: reasonType,
      evidenceJson: '{}',
      ruleScoreShort: 10.0,
      ruleScoreLong: 10.0,
    );
  }

  // ==========================================
  // applyFilter
  // ==========================================
  group('applyFilter', () {
    test('returns all analyses when filter is ScanFilter.all', () {
      final analyses = [
        createAnalysis(symbol: 'A'),
        createAnalysis(symbol: 'B'),
      ];

      final result = service.applyFilter(
        allAnalyses: analyses,
        filter: ScanFilter.all,
        allReasons: {},
      );

      expect(result.length, equals(2));
    });

    test('filters by industry symbols', () {
      final analyses = [
        createAnalysis(symbol: 'A'),
        createAnalysis(symbol: 'B'),
        createAnalysis(symbol: 'C'),
      ];

      final result = service.applyFilter(
        allAnalyses: analyses,
        filter: ScanFilter.all,
        allReasons: {},
        industrySymbols: {'A', 'C'},
      );

      expect(result.length, equals(2));
      expect(result.map((a) => a.symbol), containsAll(['A', 'C']));
    });

    test('filters by reasonCode', () {
      final analyses = [
        createAnalysis(symbol: 'A'),
        createAnalysis(symbol: 'B'),
      ];
      final reasons = {
        'A': [createReason(symbol: 'A', reasonType: 'REVERSAL_W2S')],
        'B': [createReason(symbol: 'B', reasonType: 'TECH_BREAKOUT')],
      };

      final result = service.applyFilter(
        allAnalyses: analyses,
        filter: ScanFilter.reversalW2S,
        allReasons: reasons,
      );

      expect(result.length, equals(1));
      expect(result.first.symbol, equals('A'));
    });

    test('excludes entries with no reasons when filter has reasonCode', () {
      final analyses = [
        createAnalysis(symbol: 'A'),
        createAnalysis(symbol: 'B'),
      ];
      final reasons = <String, List<DailyReasonEntry>>{
        'A': [createReason(symbol: 'A', reasonType: 'REVERSAL_W2S')],
        // B has no reasons
      };

      final result = service.applyFilter(
        allAnalyses: analyses,
        filter: ScanFilter.reversalW2S,
        allReasons: reasons,
      );

      expect(result.length, equals(1));
      expect(result.first.symbol, equals('A'));
    });

    test('combines industry and reason filters', () {
      final analyses = [
        createAnalysis(symbol: 'A'),
        createAnalysis(symbol: 'B'),
        createAnalysis(symbol: 'C'),
      ];
      final reasons = {
        'A': [createReason(symbol: 'A', reasonType: 'REVERSAL_W2S')],
        'B': [createReason(symbol: 'B', reasonType: 'REVERSAL_W2S')],
        'C': [createReason(symbol: 'C', reasonType: 'TECH_BREAKOUT')],
      };

      final result = service.applyFilter(
        allAnalyses: analyses,
        filter: ScanFilter.reversalW2S,
        allReasons: reasons,
        industrySymbols: {'A', 'C'}, // B excluded by industry
      );

      expect(result.length, equals(1));
      expect(result.first.symbol, equals('A'));
    });

    test('returns copy, not reference to original list', () {
      final analyses = [createAnalysis(symbol: 'A')];

      final result = service.applyFilter(
        allAnalyses: analyses,
        filter: ScanFilter.all,
        allReasons: {},
      );

      expect(result, isNot(same(analyses)));
    });
  });

  // ==========================================
  // applySort
  // ==========================================
  group('applySort', () {
    test('sorts by score descending (default)', () {
      final analyses = [
        createAnalysis(symbol: 'A', score: 30),
        createAnalysis(symbol: 'B', score: 80),
        createAnalysis(symbol: 'C', score: 50),
      ];

      service.applySort(analyses, ScanSort.scoreDesc);

      expect(analyses[0].symbol, equals('B'));
      expect(analyses[1].symbol, equals('C'));
      expect(analyses[2].symbol, equals('A'));
    });

    test('sorts by score ascending', () {
      final analyses = [
        createAnalysis(symbol: 'A', score: 30),
        createAnalysis(symbol: 'B', score: 80),
        createAnalysis(symbol: 'C', score: 50),
      ];

      service.applySort(analyses, ScanSort.scoreAsc);

      expect(analyses[0].symbol, equals('A'));
      expect(analyses[1].symbol, equals('C'));
      expect(analyses[2].symbol, equals('B'));
    });

    test('stable sort preserves order for equal scores', () {
      final analyses = [
        createAnalysis(symbol: 'A', score: 50),
        createAnalysis(symbol: 'B', score: 50),
        createAnalysis(symbol: 'C', score: 50),
      ];

      service.applySort(analyses, ScanSort.scoreDesc);

      // Dart's sort is stable, so order should be preserved
      expect(analyses[0].symbol, equals('A'));
      expect(analyses[1].symbol, equals('B'));
      expect(analyses[2].symbol, equals('C'));
    });

    test('default horizon (short) 仍依 scoreShort 排序（回歸保護）', () {
      final analyses = [
        createAnalysis(symbol: 'A', score: 80, scoreLong: 10),
        createAnalysis(symbol: 'B', score: 10, scoreLong: 80),
      ];

      service.applySort(analyses, ScanSort.scoreDesc); // 不傳 horizon = short

      // 依 scoreShort 降冪：A(80) > B(10)
      expect(analyses[0].symbol, equals('A'));
      expect(analyses[1].symbol, equals('B'));
    });

    test('horizon=long 時依 scoreLong 排序（新行為）', () {
      final analyses = [
        createAnalysis(symbol: 'A', score: 80, scoreLong: 10),
        createAnalysis(symbol: 'B', score: 10, scoreLong: 80),
        createAnalysis(symbol: 'C', score: 50, scoreLong: 50),
      ];

      service.applySort(analyses, ScanSort.scoreDesc, horizon: Horizon.long);

      // 依 scoreLong 降冪：B(80) > C(50) > A(10)
      expect(analyses[0].symbol, equals('B'));
      expect(analyses[1].symbol, equals('C'));
      expect(analyses[2].symbol, equals('A'));
    });

    test('horizon=long + scoreAsc 依 scoreLong 升冪', () {
      final analyses = [
        createAnalysis(symbol: 'A', score: 80, scoreLong: 10),
        createAnalysis(symbol: 'B', score: 10, scoreLong: 80),
      ];

      service.applySort(analyses, ScanSort.scoreAsc, horizon: Horizon.long);

      // 依 scoreLong 升冪：A(10) < B(80)
      expect(analyses[0].symbol, equals('A'));
      expect(analyses[1].symbol, equals('B'));
    });
  });
}
