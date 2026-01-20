import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// Alert type enum
enum AlertType {
  above('ABOVE', '價格高於'),
  below('BELOW', '價格低於'),
  changePct('CHANGE_PCT', '漲跌幅達');

  const AlertType(this.value, this.label);
  final String value;
  final String label;

  static AlertType fromValue(String value) {
    return AlertType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AlertType.above,
    );
  }
}

/// Price alert state
class PriceAlertState {
  const PriceAlertState({
    this.alerts = const [],
    this.isLoading = false,
    this.error,
  });

  final List<PriceAlertEntry> alerts;
  final bool isLoading;
  final String? error;

  PriceAlertState copyWith({
    List<PriceAlertEntry>? alerts,
    bool? isLoading,
    String? error,
  }) {
    return PriceAlertState(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Price alert notifier
class PriceAlertNotifier extends StateNotifier<PriceAlertState> {
  PriceAlertNotifier(this._db) : super(const PriceAlertState());

  final AppDatabase _db;

  /// Load all active alerts
  Future<void> loadAlerts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final alerts = await _db.getActiveAlerts();
      state = state.copyWith(alerts: alerts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load alerts for a specific symbol
  Future<void> loadAlertsForSymbol(String symbol) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final alerts = await _db.getAlertsForSymbol(symbol);
      state = state.copyWith(alerts: alerts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new price alert
  Future<bool> createAlert({
    required String symbol,
    required AlertType alertType,
    required double targetValue,
    String? note,
  }) async {
    try {
      await _db.createPriceAlert(
        symbol: symbol,
        alertType: alertType.value,
        targetValue: targetValue,
        note: note,
      );
      await loadAlerts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Delete an alert
  Future<void> deleteAlert(int id) async {
    try {
      await _db.deletePriceAlert(id);
      await loadAlerts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Toggle alert active status
  Future<void> toggleAlert(int id, bool isActive) async {
    try {
      await _db.updatePriceAlert(
        id,
        PriceAlertCompanion(isActive: Value(isActive)),
      );
      await loadAlerts();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Check alerts against current prices
  Future<List<PriceAlertEntry>> checkAndTriggerAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges,
  ) async {
    try {
      final triggered = await _db.checkAlerts(currentPrices, priceChanges);

      // Mark triggered alerts
      for (final alert in triggered) {
        await _db.triggerAlert(alert.id);
      }

      // Reload alerts
      await loadAlerts();

      return triggered;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }
}

/// Price alert provider
final priceAlertProvider =
    StateNotifierProvider<PriceAlertNotifier, PriceAlertState>((ref) {
  final db = ref.watch(databaseProvider);
  return PriceAlertNotifier(db);
});

/// Get alerts for a specific symbol
final alertsForSymbolProvider =
    FutureProvider.family<List<PriceAlertEntry>, String>((ref, symbol) async {
  final db = ref.watch(databaseProvider);
  return db.getAlertsForSymbol(symbol);
});
