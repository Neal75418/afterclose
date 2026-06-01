// Stage 4 Commit C2 — tool/replay_calibrator.dart unit tests
//
// 使用 in-memory Drift DB + synthetic price data + mocked RuleEngine 來驗證
// ReplayCalibrator 的核心行為：
// - 正確 iterate 歷史交易日
// - Forward return 計算正確（5D + 60D）
// - Hit rate / avg return 聚合正確
// - Unbiased sampling：不因 rule 觸發頻率低就被濾掉（因為沒有 Top 20 filter）
// - rule_accuracy table 寫入兩個 period row: '5D', '60D'（'ALL' 已於 2026-04 移除）
// - min-history cutoff 正確
// - forward-window cutoff 正確（不評估無法計算 60D forward return 的日子）
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/rule_enums.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/models.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';
import 'package:afterclose/domain/services/rules/stock_rules.dart';

import '../../tool/replay_calibrator.dart';

class _MockAnalysisService extends Mock implements AnalysisService {}

class _MockRuleEngine extends Mock implements RuleEngine {}

void main() {
  late AppDatabase db;
  late _MockAnalysisService mockAnalysis;
  late _MockRuleEngine mockRuleEngine;

  setUpAll(() {
    registerFallbackValue(const AnalysisContext(trendState: TrendState.up));
    registerFallbackValue(const StockData(symbol: '', prices: []));
    registerFallbackValue(
      const AnalysisResult(
        trendState: TrendState.up,
        reversalState: ReversalState.none,
        supportLevel: 0,
        resistanceLevel: 0,
      ),
    );
    registerFallbackValue(<DailyPriceEntry>[]);
  });

  setUp(() async {
    db = AppDatabase.forTesting();
    mockAnalysis = _MockAnalysisService();
    mockRuleEngine = _MockRuleEngine();

    // Default mocks — analysis always returns a valid result
    when(() => mockAnalysis.analyzeStock(any())).thenReturn(
      const AnalysisResult(
        trendState: TrendState.up,
        reversalState: ReversalState.none,
        supportLevel: 100,
        resistanceLevel: 120,
      ),
    );
    when(
      () => mockAnalysis.buildContext(
        any(),
        priceHistory: any(named: 'priceHistory'),
        marketData: any(named: 'marketData'),
        evaluationTime: any(named: 'evaluationTime'),
      ),
    ).thenReturn(const AnalysisContext(trendState: TrendState.up));
  });

  tearDown(() async {
    await db.close();
  });

  // ==========================================================================
  // Fixtures
  // ==========================================================================

  /// 插入一檔股票 + N 天的合成價格
  ///
  /// 價格以 linear growth 100 → 100 + days 上升（方便手算 forward return）
  Future<void> seedStock(
    String symbol, {
    required int priceDays,
    double startClose = 100.0,
    double growthPerDay = 1.0,
    DateTime? firstDate,
  }) async {
    await db.upsertStocks([
      StockMasterCompanion.insert(
        symbol: symbol,
        name: 'Test $symbol',
        market: 'TWSE',
      ),
    ]);

    final first = firstDate ?? DateTime(2024, 1, 1);
    final prices = <DailyPriceCompanion>[];
    for (var i = 0; i < priceDays; i++) {
      final date = first.add(Duration(days: i));
      final close = startClose + growthPerDay * i;
      prices.add(
        DailyPriceCompanion.insert(
          symbol: symbol,
          date: date,
          open: Value(close),
          high: Value(close * 1.01),
          low: Value(close * 0.99),
          close: Value(close),
          volume: const Value(1000000),
        ),
      );
    }
    await db.insertPrices(prices);
  }

  // ==========================================================================
  // Tests
  // ==========================================================================

  group('ReplayCalibrator — forward return math', () {
    test('linear growth 1%/day produces expected 5D + 60D returns', () async {
      // 100 days of linear growth + 5 days forward + 60 days forward = need
      // at least 80 days of price history for the first eligible day (min=20)
      // and another 60 for the final forward window. Use 200 days to be safe.
      await seedStock('TEST', priceDays: 200);

      // Mock rule engine to fire a specific rule on every day it's evaluated
      const testRuleType = ReasonType.techBreakout;
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(const [
        TriggeredReason(
          type: testRuleType,
          score: 25,
          description: 'test firing',
        ),
      ]);

      final calibrator = ReplayCalibrator(
        db: db,
        config: const ReplayConfig(dbPath: ':memory:', minHistoryDays: 20),
        analysisService: mockAnalysis,
        ruleEngine: mockRuleEngine,
        logger: (_) {},
      );
      final result = await calibrator.run();

      expect(result.rulesObserved, 1);
      final stats = result.ruleStats[testRuleType.code];
      expect(stats, isNotNull);

      // Eligible range: i from 20 to 199-60-1 = 139 (inclusive → 120 firings)
      expect(stats!.short.triggerCount, 120);
      expect(stats.long.triggerCount, 120);

      // Linear growth: entry=100+i*1, exit_5d=100+(i+5)*1, return=5/(100+i)
      // For i=20, return ≈ 5/120 = 4.17%; for i=139, return ≈ 5/239 = 2.09%
      // avg short return should be in that range
      expect(stats.short.avgReturn, inInclusiveRange(2.0, 4.5));
      // Long return: 60/(100+i) ≈ 60/120..60/239 = 25%..25%
      // Wait: for i=20, 60/120=50%; for i=139, 60/239≈25%
      expect(stats.long.avgReturn, inInclusiveRange(24.0, 51.0));

      // Short threshold 3% — high hit rate in the first half, low in the second
      expect(stats.short.hitRate, inInclusiveRange(0.3, 1.0));
      // Long threshold 12% — ALL samples hit (min long return ≈ 25%)
      expect(stats.long.hitRate, 1.0);
    });

    test(
      'successCount uses canonical thresholds from CalibrationThresholds',
      () async {
        // 用快速成長價格序列確保 5D / 60D return 都明顯**超過**canonical
        // 門檻（5D=3.0%, 60D=12.0%），驗 replay_calibrator 確實讀到 canonical
        // 常數做 isSuccess 判定。growthPerDay=5：
        //   5D return = 25/(100 + 5i) > 3% when 100+5i < 833 (i < 146) ✓ 所有 day
        //   60D return = 300/(100+5i) > 12% when 100+5i < 2500 (i < 480) ✓ 所有 day
        await seedStock('FAST', priceDays: 150, growthPerDay: 5.0);
        when(
          () => mockRuleEngine.evaluateStock(any(), any()),
        ).thenReturn(const [
          TriggeredReason(
            type: ReasonType.volumeSpike,
            score: 22,
            description: 'fast firing',
          ),
        ]);

        final calibrator = ReplayCalibrator(
          db: db,
          config: const ReplayConfig(dbPath: ':memory:', minHistoryDays: 20),
          analysisService: mockAnalysis,
          ruleEngine: mockRuleEngine,
          logger: (_) {},
        );
        final result = await calibrator.run();

        final stats = result.ruleStats[ReasonType.volumeSpike.code]!;
        // 兩個 horizon 的 hit rate 都應該幾乎 100%（returns 都遠超門檻）
        expect(stats.short.hitRate, greaterThan(0.9));
        expect(stats.long.hitRate, greaterThan(0.9));
      },
    );
  });

  group('ReplayCalibrator — unbiased sampling', () {
    test('records ALL firings without Top-20 filter', () async {
      // Two stocks, both trigger the SAME negative-signal rule
      // A real Top-20 filter would exclude both (negative total score)
      // ReplayCalibrator should count both firings.
      await seedStock('A', priceDays: 150);
      await seedStock('B', priceDays: 150, firstDate: DateTime(2024, 1, 1));

      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(const [
        TriggeredReason(
          type: ReasonType.techBreakdown,
          score: -20,
          description: 'negative signal',
        ),
      ]);

      final calibrator = ReplayCalibrator(
        db: db,
        config: const ReplayConfig(dbPath: ':memory:', minHistoryDays: 20),
        analysisService: mockAnalysis,
        ruleEngine: mockRuleEngine,
        logger: (_) {},
      );
      final result = await calibrator.run();

      final stats = result.ruleStats[ReasonType.techBreakdown.code]!;
      // 150 days, min=20, forward=60 → eligible = 150-20-60 = 70 per stock
      // 2 stocks × 70 = 140 firings
      expect(stats.short.triggerCount, 140);
      expect(stats.long.triggerCount, 140);
    });
  });

  group('ReplayCalibrator — history cutoff', () {
    test('skips days below min-history', () async {
      await seedStock('SHORT_HISTORY', priceDays: 85);
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(const [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'x',
        ),
      ]);

      final calibrator = ReplayCalibrator(
        db: db,
        config: const ReplayConfig(dbPath: ':memory:', minHistoryDays: 20),
        analysisService: mockAnalysis,
        ruleEngine: mockRuleEngine,
        logger: (_) {},
      );
      final result = await calibrator.run();

      // 85 days, min=20, forward=60 → eligible from i=20..85-60-1=24 → 5 firings
      final stats = result.ruleStats[ReasonType.techBreakout.code];
      expect(stats, isNotNull);
      expect(stats!.short.triggerCount, 5);
    });

    test(
      'stock with insufficient forward window produces zero firings',
      () async {
        // 70 days of price - cannot compute 60D forward (need 60 days after
        // the earliest eligible day = day 20, so need 20 + 60 + 1 = 81 days)
        await seedStock('NO_FORWARD', priceDays: 70);
        when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(
          const [
            TriggeredReason(
              type: ReasonType.techBreakout,
              score: 25,
              description: 'x',
            ),
          ],
        );

        final calibrator = ReplayCalibrator(
          db: db,
          config: const ReplayConfig(dbPath: ':memory:', minHistoryDays: 20),
          analysisService: mockAnalysis,
          ruleEngine: mockRuleEngine,
          logger: (_) {},
        );
        final result = await calibrator.run();

        expect(result.ruleStats, isEmpty);
        expect(result.totalFirings, 0);
      },
    );
  });

  group('ReplayCalibrator — rule_accuracy writes', () {
    test('writes 5D + 60D rows per rule (ALL removed 2026-04)', () async {
      await seedStock('WRITE_TEST', priceDays: 150);
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(const [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'x',
        ),
      ]);

      final calibrator = ReplayCalibrator(
        db: db,
        config: const ReplayConfig(dbPath: ':memory:', minHistoryDays: 20),
        analysisService: mockAnalysis,
        ruleEngine: mockRuleEngine,
        logger: (_) {},
      );
      await calibrator.run();

      final rows = await db.select(db.ruleAccuracy).get();
      // 1 rule × 2 periods = 2 rows. 'ALL' was removed 2026-04 (mixing
      // 1D / 60D thresholds produced a meaningless aggregate hit_rate).
      expect(rows.length, 2);
      expect(rows.map((r) => r.period).toSet(), {'5D', '60D'});
    });

    test('second run replaces previous rule_accuracy rows', () async {
      await seedStock('IDEM', priceDays: 150);
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(const [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'x',
        ),
      ]);

      final calibrator = ReplayCalibrator(
        db: db,
        config: const ReplayConfig(dbPath: ':memory:', minHistoryDays: 20),
        analysisService: mockAnalysis,
        ruleEngine: mockRuleEngine,
        logger: (_) {},
      );
      await calibrator.run();
      final firstCount = (await db.select(db.ruleAccuracy).get()).length;

      // Second run — switch to a different rule
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(const [
        TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'y',
        ),
      ]);
      await calibrator.run();
      final secondRows = await db.select(db.ruleAccuracy).get();

      // Second run should have purged first run's rows and written new ones
      expect(secondRows.length, firstCount); // still 2 rows (new rule)
      expect(secondRows.map((r) => r.ruleId).toSet(), {
        ReasonType.volumeSpike.code,
      });
    });
  });

  group('ReplayCalibrator — multi-rule aggregation', () {
    test('different rules get separate stats', () async {
      await seedStock('MULTI', priceDays: 150);
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(const [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'a',
        ),
        TriggeredReason(
          type: ReasonType.volumeSpike,
          score: 22,
          description: 'b',
        ),
        TriggeredReason(
          type: ReasonType.kdGoldenCross,
          score: 10,
          description: 'c',
        ),
      ]);

      final calibrator = ReplayCalibrator(
        db: db,
        config: const ReplayConfig(dbPath: ':memory:', minHistoryDays: 20),
        analysisService: mockAnalysis,
        ruleEngine: mockRuleEngine,
        logger: (_) {},
      );
      final result = await calibrator.run();

      expect(result.rulesObserved, 3);
      // All three rules have identical trigger count (same mock fires all
      // three on every eligible day)
      final counts = result.ruleStats.values
          .map((s) => s.short.triggerCount)
          .toSet();
      expect(counts.length, 1); // all equal
      expect(counts.first, 70); // 150-20-60 = 70
    });
  });

  group('ReplayCalibrator — dry run', () {
    test('does not write rule_accuracy and returns empty stats', () async {
      await seedStock('DRY', priceDays: 150);
      when(() => mockRuleEngine.evaluateStock(any(), any())).thenReturn(const [
        TriggeredReason(
          type: ReasonType.techBreakout,
          score: 25,
          description: 'x',
        ),
      ]);

      final calibrator = ReplayCalibrator(
        db: db,
        config: const ReplayConfig(
          dbPath: ':memory:',
          minHistoryDays: 20,
          dryRun: true,
        ),
        analysisService: mockAnalysis,
        ruleEngine: mockRuleEngine,
        logger: (_) {},
      );
      final result = await calibrator.run();

      expect(result.rulesObserved, 0);
      expect(result.totalFirings, 0);

      final rows = await db.select(db.ruleAccuracy).get();
      expect(rows, isEmpty);
      verifyNever(() => mockRuleEngine.evaluateStock(any(), any()));
    });
  });
}
