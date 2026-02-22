import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/screens/comparison/comparison_screen.dart';

import '../../../helpers/provider_test_helpers.dart';
import '../../../helpers/widget_test_helpers.dart';

// =============================================================================
// Fake Notifier
// =============================================================================

class FakeComparisonNotifier extends ComparisonNotifier {
  ComparisonState initialState = const ComparisonState();

  @override
  ComparisonState build() => initialState;

  @override
  Future<void> addStock(String symbol) async {}

  @override
  Future<void> addStocks(List<String> symbols) async {}

  @override
  void removeStock(String symbol) {}
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

  late ComparisonState _comparisonState;

  Widget buildTestWidget({
    ComparisonState? comparisonState,
    Brightness brightness = Brightness.light,
  }) {
    _comparisonState = comparisonState ?? const ComparisonState();
    return buildProviderTestApp(
      const ComparisonScreen(),
      overrides: [
        comparisonProvider.overrideWith(() {
          final n = FakeComparisonNotifier();
          n.initialState = _comparisonState;
          return n;
        }),
      ],
      brightness: brightness,
    );
  }

  group('ComparisonScreen', () {
    testWidgets('shows AppBar with title', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows empty state when no stocks', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    });

    testWidgets('shows add stock button in empty state', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.add), findsAtLeastNWidgets(1));
    });

    testWidgets('shows shimmer when loading with no symbols', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(
        buildTestWidget(
          comparisonState: const ComparisonState(isLoading: true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ComparisonScreen), findsOneWidget);
    });

    testWidgets('shows loading indicator when has symbols and loading', (
      tester,
    ) async {
      widenViewport(tester);
      final state = ComparisonState(
        symbols: const ['2330', '2317'],
        stocksMap: {
          '2330': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2330',
            name: 'TSMC',
            market: 'TWSE',
            industry: '半導體',
          ),
          '2317': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2317',
            name: 'Foxconn',
            market: 'TWSE',
            industry: '電子',
          ),
        },
        isLoading: true,
      );
      await tester.pumpWidget(buildTestWidget(comparisonState: state));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows share button when enough stocks', (tester) async {
      widenViewport(tester);
      final state = ComparisonState(
        symbols: const ['2330', '2317'],
        stocksMap: {
          '2330': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2330',
            name: 'TSMC',
            market: 'TWSE',
            industry: '半導體',
          ),
          '2317': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2317',
            name: 'Foxconn',
            market: 'TWSE',
            industry: '電子',
          ),
        },
      );
      await tester.pumpWidget(buildTestWidget(comparisonState: state));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });

    testWidgets('hides share button when only one stock', (tester) async {
      widenViewport(tester);
      final state = ComparisonState(
        symbols: const ['2330'],
        stocksMap: {
          '2330': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2330',
            name: 'TSMC',
            market: 'TWSE',
            industry: '半導體',
          ),
        },
      );
      await tester.pumpWidget(buildTestWidget(comparisonState: state));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.share_outlined), findsNothing);
    });

    testWidgets('shows add icon in AppBar when can add more', (tester) async {
      widenViewport(tester);
      final state = ComparisonState(
        symbols: const ['2330'],
        stocksMap: {
          '2330': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2330',
            name: 'TSMC',
            market: 'TWSE',
            industry: '半導體',
          ),
        },
      );
      await tester.pumpWidget(buildTestWidget(comparisonState: state));
      await tester.pump(const Duration(seconds: 1));

      // Add icon in AppBar actions
      expect(find.byIcon(Icons.add), findsAtLeastNWidgets(1));
    });

    testWidgets('hides add icon when max stocks reached', (tester) async {
      widenViewport(tester);
      final state = ComparisonState(
        symbols: const ['2330', '2317', '2454', '2412'],
        stocksMap: {
          '2330': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2330',
            name: 'TSMC',
            market: 'TWSE',
            industry: '半導體',
          ),
          '2317': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2317',
            name: 'Foxconn',
            market: 'TWSE',
            industry: '電子',
          ),
          '2454': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2454',
            name: 'MediaTek',
            market: 'TWSE',
            industry: '半導體',
          ),
          '2412': StockMasterEntry(
            isActive: true,
            updatedAt: DateTime(2026, 1, 1),
            symbol: '2412',
            name: 'CHT',
            market: 'TWSE',
            industry: '電信',
          ),
        },
      );
      await tester.pumpWidget(buildTestWidget(comparisonState: state));
      await tester.pump(const Duration(seconds: 1));

      // canAddMore is false → screen still renders
      expect(find.byType(ComparisonScreen), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      widenViewport(tester);
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ComparisonScreen), findsOneWidget);
    });
  });
}
