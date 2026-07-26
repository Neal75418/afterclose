import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/ai_summary_card.dart';

import '../../../../helpers/provider_test_helpers.dart';
import '../../../../helpers/widget_test_helpers.dart';

// ==========================================
// Fake Notifier
// ==========================================

class FakeStockDetailNotifier extends StockDetailNotifier {
  FakeStockDetailNotifier(super.symbol);

  StockDetailState initialState = const StockDetailState();

  @override
  StockDetailState build() => initialState;

  @override
  Future<void> loadInsiderData() async {}

  @override
  Future<void> loadData() async {}
}

// ==========================================
// Tests
// ==========================================

void main() {
  setUpAll(() async {
    await setupTestLocalization();
  });

  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(5000, 8000);
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  late StockDetailState testState;

  Widget buildTestWidget(
    StockDetailState state, {
    Brightness brightness = Brightness.light,
  }) {
    testState = state;
    return buildProviderTestApp(
      const AiSummaryCard(symbol: '2330'),
      overrides: [
        stockDetailProvider.overrideWith2((symbol) {
          final n = FakeStockDetailNotifier(symbol);
          n.initialState = testState;
          return n;
        }),
        primaryRuleAccuracySummaryProvider.overrideWith(
          (ref, symbol) async => null,
        ),
      ],
      brightness: brightness,
    );
  }

  const bullishSummary = StockSummary(
    overallAssessment: 'Strong bullish trend detected',
    keySignals: ['Volume breakout', 'Golden cross'],
    riskFactors: ['High valuation'],
    supportingData: ['Foreign net buy 5 days'],
    sentiment: SummarySentiment.bullish,
    confidence: AnalysisConfidence.high,
    confluenceCount: 3,
  );

  const bearishSummary = StockSummary(
    overallAssessment: 'Bearish reversal expected',
    sentiment: SummarySentiment.bearish,
    confidence: AnalysisConfidence.low,
  );

  const neutralSummary = StockSummary(
    overallAssessment: 'Sideways consolidation',
    sentiment: SummarySentiment.neutral,
    confidence: AnalysisConfidence.medium,
    hasConflict: true,
  );

  group('AiSummaryCard', () {
    testWidgets('shows shimmer skeleton when aiSummary is null', (
      tester,
    ) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(const StockDetailState()));
      await tester.pump();

      // Shimmer containers should be present
      expect(find.byType(AiSummaryCard), findsOneWidget);
      // No overall assessment text
      expect(find.text('Strong bullish trend detected'), findsNothing);
    });

    testWidgets('shows overall assessment text', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Strong bullish trend detected'), findsOneWidget);
    });

    testWidgets('shows key signals section', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Volume breakout'), findsOneWidget);
      expect(find.text('Golden cross'), findsOneWidget);
    });

    testWidgets('shows risk factors section', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('High valuation'), findsOneWidget);
    });

    testWidgets('shows supporting data section', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Foreign net buy 5 days'), findsOneWidget);
    });

    testWidgets('hides sections when summary has no signals/risks', (
      tester,
    ) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bearishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Bearish reversal expected'), findsOneWidget);
      // No bullet items for signals or risks
      expect(find.text('Volume breakout'), findsNothing);
    });

    testWidgets('shows auto_awesome icon', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    // 訊號強度條已移除（2026-07-26）。四個獨立理由：
    //
    // 1. 與 confidence 徽章同軸重複——_calculateStrength 的五個加項中，
    //    hasSignals／hasSupportingData 幾乎恆真、hasConflict 罕見、
    //    confluenceCount 在 156 檔中有 149 檔為 0，於是 95.5% 的股票條長
    //    就是 confBase + 0.20，是三級徽章的算術改寫。
    // 2. 假精度——實際只有 5 種可達值 {20,30,44,60,70}，90.4% 擠在兩格，
    //    卻渲染成連續進度條並標出精確百分比。
    // 3. 九成塗警示色——_getStrengthColor 的 [0.4,0.7) 區間是 warningColor，
    //    44 與 60 都落在裡面。對每檔股票都出現的警示會訓練使用者忽略警示
    //    （與 missing_domains_test 記錄的假「資料缺漏」是同一個病）。
    // 4. 挪用股價專屬色——≥0.7 走 AppTheme.upColor，而台股紅＝漲。一檔
    //    偏空但佐證充足的股票會拿到紅色條。CLAUDE.md 的「紅綠專屬股價」
    //    在此被違反，且 semantic_colors_test 守的是色值與對比、不守用途。
    //
    // 移除不損失資訊：條長唯一獨立於徽章的輸入是匯流，而有匯流時
    // summary.confluenceOverall 已經取代整句開場白（analysis_summary_service
    // :214-227），匯流本來就是內文的頭條。
    testWidgets('🚨 不再渲染訊號強度條（與 confidence 徽章同軸且色彩誤導）', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.byIcon(Icons.signal_cellular_alt), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows action chips', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    });

    testWidgets('bearish sentiment renders correctly', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bearishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Bearish reversal expected'), findsOneWidget);
    });

    testWidgets('neutral sentiment renders correctly', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: neutralSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      expect(find.text('Sideways consolidation'), findsOneWidget);
    });

    testWidgets('collapse toggle hides content', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(buildTestWidget(state));
      await tester.pump();

      // Content is visible initially
      expect(find.text('Strong bullish trend detected'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pumpAndSettle();

      // Arrow should change to down
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      final state = const StockDetailState().copyWith(
        aiSummary: bullishSummary,
      );
      await tester.pumpWidget(
        buildTestWidget(state, brightness: Brightness.dark),
      );
      await tester.pump();

      expect(find.text('Strong bullish trend detected'), findsOneWidget);
    });
  });
}
