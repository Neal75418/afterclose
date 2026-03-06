import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/services/rule_accuracy_service.dart';
import 'package:afterclose/presentation/providers/recommendation_performance_provider.dart';
import 'package:afterclose/presentation/screens/recommendation_performance/recommendation_performance_screen.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifier
// =============================================================================

class FakeRecPerfNotifier extends RecommendationPerformanceNotifier {
  RecommendationPerformanceState initialState =
      const RecommendationPerformanceState();

  @override
  RecommendationPerformanceState build() => initialState;

  @override
  Future<void> loadData() async {}

  @override
  Future<void> selectPeriod(String period) async {}

  @override
  Future<void> runBackfill() async {}
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget buildTestWidget({
    RecommendationPerformanceState? state,
    Brightness brightness = Brightness.light,
  }) {
    final s = state ?? const RecommendationPerformanceState();
    return buildProviderTestApp(
      const RecommendationPerformanceScreen(),
      overrides: [
        recommendationPerformanceProvider.overrideWith(() {
          final n = FakeRecPerfNotifier();
          n.initialState = s;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  StockValidationRecord createRecord({
    String symbol = '2330',
    String stockName = '台積電',
    DateTime? date,
    double entryPrice = 580.0,
    double? exitPrice = 598.0,
    double? returnRate = 3.1,
    bool? isSuccess = true,
    int holdingDays = 5,
    String primaryRuleId = 'REVERSAL_W2S',
  }) {
    return StockValidationRecord(
      symbol: symbol,
      stockName: stockName,
      recommendationDate: date ?? DateTime(2026, 3, 5),
      primaryRuleId: primaryRuleId,
      entryPrice: entryPrice,
      exitPrice: exitPrice,
      returnRate: returnRate,
      isSuccess: isSuccess,
      holdingDays: holdingDays,
    );
  }

  group('RecommendationPerformanceScreen', () {
    testWidgets('shows loading indicator when isLoading and no records', (
      tester,
    ) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          state: const RecommendationPerformanceState(isLoading: true),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows period selector', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(SegmentedButton<String>), findsOneWidget);
    });

    testWidgets('shows overall stats card', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          state: RecommendationPerformanceState(
            overallStats: const OverallPerformanceStats(
              totalCount: 50,
              successCount: 30,
              avgReturn: 2.5,
            ),
          ),
        ),
      );
      await tester.pump();

      // 勝率
      expect(find.textContaining('60.0%'), findsOneWidget);
      // 平均報酬
      expect(find.textContaining('+2.50%'), findsOneWidget);
      // 驗證筆數
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('shows backfill button when not backfilling', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('shows progress bar when backfilling', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          state: const RecommendationPerformanceState(
            isBackfilling: true,
            backfillProgress: 0.5,
            backfillCurrent: 25,
            backfillTotal: 50,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows stock validation records', (tester) async {
      widenViewport(tester);

      final records = [
        createRecord(symbol: '2330', stockName: '台積電', returnRate: 3.1),
        createRecord(
          symbol: '2454',
          stockName: '聯發科',
          returnRate: -1.5,
          isSuccess: false,
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(
          state: RecommendationPerformanceState(stockRecords: records),
        ),
      );
      await tester.pump();

      expect(find.textContaining('2330'), findsOneWidget);
      expect(find.textContaining('台積電'), findsOneWidget);
      expect(find.textContaining('2454'), findsOneWidget);
      expect(find.textContaining('聯發科'), findsOneWidget);
    });

    testWidgets('shows empty hint when no records', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.analytics_outlined), findsWidgets);
    });

    testWidgets('shows disclaimer', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('shows pending validation for records without result', (
      tester,
    ) async {
      widenViewport(tester);

      final record = createRecord(
        exitPrice: null,
        returnRate: null,
        isSuccess: null,
      );

      await tester.pumpWidget(
        buildTestWidget(
          state: RecommendationPerformanceState(stockRecords: [record]),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          state: RecommendationPerformanceState(stockRecords: [createRecord()]),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      expect(find.byType(RecommendationPerformanceScreen), findsOneWidget);
    });
  });
}
