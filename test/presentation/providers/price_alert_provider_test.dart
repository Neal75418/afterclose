import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockAppDatabase extends Mock implements AppDatabase {}

// =============================================================================
// Test Helpers
// =============================================================================

final _now = DateTime(2026, 2, 13);

PriceAlertEntry createAlert({
  int id = 1,
  String symbol = '2330',
  String alertType = 'ABOVE',
  double targetValue = 600.0,
  bool isActive = true,
  DateTime? triggeredAt,
  String? note,
  DateTime? createdAt,
}) {
  return PriceAlertEntry(
    id: id,
    symbol: symbol,
    alertType: alertType,
    targetValue: targetValue,
    isActive: isActive,
    triggeredAt: triggeredAt,
    note: note,
    createdAt: createdAt ?? _now,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockAppDatabase mockDb;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(PriceAlertCompanion());
  });

  setUp(() {
    mockDb = MockAppDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(mockDb)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // ===========================================================================
  // AlertType
  // ===========================================================================

  group('AlertType', () {
    test('fromValue parses valid value', () {
      expect(AlertType.fromValue('ABOVE'), AlertType.above);
      expect(AlertType.fromValue('BELOW'), AlertType.below);
      expect(AlertType.fromValue('CHANGE_PCT'), AlertType.changePct);
    });

    test('fromValue throws for invalid value', () {
      expect(
        () => AlertType.fromValue('INVALID'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tryFromValue returns null for invalid value', () {
      expect(AlertType.tryFromValue('INVALID'), isNull);
    });

    test('tryFromValue returns AlertType for valid value', () {
      expect(AlertType.tryFromValue('ABOVE'), AlertType.above);
    });

    test('requiresTargetValue is correct for price types', () {
      expect(AlertType.above.requiresTargetValue, isTrue);
      expect(AlertType.below.requiresTargetValue, isTrue);
      expect(AlertType.changePct.requiresTargetValue, isTrue);
    });

    test('requiresTargetValue is false for auto-trigger types', () {
      expect(AlertType.volumeSpike.requiresTargetValue, isFalse);
      expect(AlertType.kdGoldenCross.requiresTargetValue, isFalse);
      expect(AlertType.week52High.requiresTargetValue, isFalse);
      expect(AlertType.tradingWarning.requiresTargetValue, isFalse);
      expect(AlertType.insiderSelling.requiresTargetValue, isFalse);
    });

    test('defaultTargetValue returns expected values', () {
      expect(AlertType.rsiOverbought.defaultTargetValue, 70.0);
      expect(AlertType.rsiOversold.defaultTargetValue, 30.0);
      expect(AlertType.crossAboveMa.defaultTargetValue, 20.0);
      expect(AlertType.above.defaultTargetValue, isNull);
    });

    test('category groups types correctly', () {
      expect(AlertType.above.category, AlertCategory.price);
      expect(AlertType.volumeSpike.category, AlertCategory.volume);
      expect(AlertType.rsiOverbought.category, AlertCategory.indicator);
      expect(AlertType.breakResistance.category, AlertCategory.level);
      expect(AlertType.week52High.category, AlertCategory.week52);
      expect(AlertType.crossAboveMa.category, AlertCategory.ma);
      expect(AlertType.revenueYoySurge.category, AlertCategory.fundamental);
      expect(AlertType.tradingWarning.category, AlertCategory.warning);
      expect(AlertType.insiderSelling.category, AlertCategory.insider);
    });
  });

  // ===========================================================================
  // AlertCategory
  // ===========================================================================

  group('AlertCategory', () {
    test('alertTypes returns correct types per category', () {
      final priceTypes = AlertCategory.price.alertTypes;
      expect(priceTypes, contains(AlertType.above));
      expect(priceTypes, contains(AlertType.below));
      expect(priceTypes, contains(AlertType.changePct));
      expect(priceTypes, hasLength(3));
    });

    test('alertTypes returns non-empty for all categories', () {
      for (final category in AlertCategory.values) {
        expect(
          category.alertTypes,
          isNotEmpty,
          reason: '$category should have alert types',
        );
      }
    });
  });

  // ===========================================================================
  // PriceAlertState
  // ===========================================================================

  group('PriceAlertState', () {
    test('has correct default values', () {
      const state = PriceAlertState();

      expect(state.alerts, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith preserves unset values', () {
      final state = PriceAlertState(alerts: [createAlert()], isLoading: true);

      final copied = state.copyWith();
      expect(copied.alerts, hasLength(1));
      expect(copied.isLoading, isTrue);
      // Note: error is always set to null when not passed (no sentinel)
      expect(copied.error, isNull);
    });

    test('copyWith updates individual fields', () {
      const state = PriceAlertState();
      final updated = state.copyWith(isLoading: true, error: 'some error');
      expect(updated.isLoading, isTrue);
      expect(updated.error, 'some error');
    });
  });

  // ===========================================================================
  // PriceAlertNotifier.loadAlerts
  // ===========================================================================

  group('PriceAlertNotifier.loadAlerts', () {
    test('loads all alerts from DB', () async {
      final alerts = [
        createAlert(id: 1, symbol: '2330'),
        createAlert(id: 2, symbol: '2317'),
      ];
      when(() => mockDb.getAllAlerts()).thenAnswer((_) async => alerts);

      final notifier = container.read(priceAlertProvider.notifier);
      await notifier.loadAlerts();

      final state = container.read(priceAlertProvider);
      expect(state.alerts, hasLength(2));
      expect(state.isLoading, isFalse);
    });

    test('handles error gracefully', () async {
      when(() => mockDb.getAllAlerts()).thenThrow(Exception('DB error'));

      final notifier = container.read(priceAlertProvider.notifier);
      await notifier.loadAlerts();

      final state = container.read(priceAlertProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });
  });

  // ===========================================================================
  // PriceAlertNotifier.loadAlertsForSymbol
  // ===========================================================================

  group('PriceAlertNotifier.loadAlertsForSymbol', () {
    test('loads alerts for specific symbol', () async {
      final alerts = [createAlert(id: 1, symbol: '2330')];
      when(
        () => mockDb.getAlertsForSymbol('2330'),
      ).thenAnswer((_) async => alerts);

      final notifier = container.read(priceAlertProvider.notifier);
      await notifier.loadAlertsForSymbol('2330');

      final state = container.read(priceAlertProvider);
      expect(state.alerts, hasLength(1));
      expect(state.alerts.first.symbol, '2330');
    });

    test('handles error gracefully', () async {
      when(
        () => mockDb.getAlertsForSymbol(any()),
      ).thenThrow(Exception('DB error'));

      final notifier = container.read(priceAlertProvider.notifier);
      await notifier.loadAlertsForSymbol('2330');

      final state = container.read(priceAlertProvider);
      expect(state.error, isNotNull);
    });
  });

  // ===========================================================================
  // PriceAlertNotifier.createAlert
  // ===========================================================================

  group('PriceAlertNotifier.createAlert', () {
    test('creates alert and adds to state', () async {
      final newAlert = createAlert(id: 99);
      when(
        () => mockDb.createPriceAlert(
          symbol: any(named: 'symbol'),
          alertType: any(named: 'alertType'),
          targetValue: any(named: 'targetValue'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => 99);
      when(() => mockDb.getAlertById(99)).thenAnswer((_) async => newAlert);

      final notifier = container.read(priceAlertProvider.notifier);
      final result = await notifier.createAlert(
        symbol: '2330',
        alertType: AlertType.above,
        targetValue: 600.0,
      );

      expect(result, isTrue);
      final state = container.read(priceAlertProvider);
      expect(state.alerts, hasLength(1));
      expect(state.alerts.first.id, 99);
    });

    test('returns false on error', () async {
      when(
        () => mockDb.createPriceAlert(
          symbol: any(named: 'symbol'),
          alertType: any(named: 'alertType'),
          targetValue: any(named: 'targetValue'),
          note: any(named: 'note'),
        ),
      ).thenThrow(Exception('DB error'));

      final notifier = container.read(priceAlertProvider.notifier);
      final result = await notifier.createAlert(
        symbol: '2330',
        alertType: AlertType.above,
        targetValue: 600.0,
      );

      expect(result, isFalse);
      final state = container.read(priceAlertProvider);
      expect(state.error, isNotNull);
    });
  });

  // ===========================================================================
  // PriceAlertNotifier.deleteAlert
  // ===========================================================================

  group('PriceAlertNotifier.deleteAlert', () {
    test('removes alert from state optimistically', () async {
      final alerts = [createAlert(id: 1), createAlert(id: 2)];
      when(() => mockDb.getAllAlerts()).thenAnswer((_) async => alerts);
      when(() => mockDb.deletePriceAlert(1)).thenAnswer((_) async {});

      final notifier = container.read(priceAlertProvider.notifier);
      await notifier.loadAlerts();
      await notifier.deleteAlert(1);

      final state = container.read(priceAlertProvider);
      expect(state.alerts, hasLength(1));
      expect(state.alerts.first.id, 2);
    });

    test('rolls back on error', () async {
      final alerts = [createAlert(id: 1)];
      when(() => mockDb.getAllAlerts()).thenAnswer((_) async => alerts);
      when(() => mockDb.deletePriceAlert(1)).thenThrow(Exception('DB error'));

      final notifier = container.read(priceAlertProvider.notifier);
      await notifier.loadAlerts();
      await notifier.deleteAlert(1);

      final state = container.read(priceAlertProvider);
      // Should roll back
      expect(state.alerts, hasLength(1));
      expect(state.error, isNotNull);
    });
  });

  // ===========================================================================
  // PriceAlertNotifier.toggleAlert
  // ===========================================================================

  group('PriceAlertNotifier.toggleAlert', () {
    test('toggles isActive optimistically', () async {
      final alerts = [createAlert(id: 1, isActive: true)];
      when(() => mockDb.getAllAlerts()).thenAnswer((_) async => alerts);
      when(
        () => mockDb.updatePriceAlert(any(), any()),
      ).thenAnswer((_) async => 1);

      final notifier = container.read(priceAlertProvider.notifier);
      await notifier.loadAlerts();
      await notifier.toggleAlert(1, false);

      final state = container.read(priceAlertProvider);
      expect(state.alerts.first.isActive, isFalse);
    });

    test('rolls back on error', () async {
      final alerts = [createAlert(id: 1, isActive: true)];
      when(() => mockDb.getAllAlerts()).thenAnswer((_) async => alerts);
      when(
        () => mockDb.updatePriceAlert(any(), any()),
      ).thenThrow(Exception('DB error'));

      final notifier = container.read(priceAlertProvider.notifier);
      await notifier.loadAlerts();
      await notifier.toggleAlert(1, false);

      final state = container.read(priceAlertProvider);
      // Should roll back to original
      expect(state.alerts.first.isActive, isTrue);
      expect(state.error, isNotNull);
    });
  });

  // ===========================================================================
  // Provider declaration
  // ===========================================================================

  group('priceAlertProvider', () {
    test('provides initial state', () {
      final state = container.read(priceAlertProvider);
      expect(state, isA<PriceAlertState>());
      expect(state.alerts, isEmpty);
    });

    test('notifier is accessible', () {
      final notifier = container.read(priceAlertProvider.notifier);
      expect(notifier, isA<PriceAlertNotifier>());
    });
  });
}
