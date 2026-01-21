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

  /// Parse AlertType from string value.
  ///
  /// Throws [ArgumentError] if the value is not a valid AlertType.
  static AlertType fromValue(String value) {
    return tryFromValue(value) ??
        (throw ArgumentError.value(
          value,
          'value',
          'Invalid AlertType value. Valid values: ${AlertType.values.map((e) => e.value).join(", ")}',
        ));
  }

  /// Try to parse AlertType from string value.
  ///
  /// Returns null if the value is not a valid AlertType.
  static AlertType? tryFromValue(String value) {
    for (final type in AlertType.values) {
      if (type.value == value) return type;
    }
    return null;
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

  /// Load all alerts (active and inactive)
  Future<void> loadAlerts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final alerts = await _db.getAllAlerts();
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
      final id = await _db.createPriceAlert(
        symbol: symbol,
        alertType: alertType.value,
        targetValue: targetValue,
        note: note,
      );

      // Incremental update: add new alert to state instead of full reload
      // Insert at beginning to maintain createdAt DESC order
      final newAlert = await _db.getAlertById(id);
      if (newAlert != null) {
        state = state.copyWith(
          alerts: [newAlert, ...state.alerts],
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Delete an alert
  Future<void> deleteAlert(int id) async {
    // Optimistic update: remove from state immediately
    final previousAlerts = state.alerts;
    state = state.copyWith(
      alerts: state.alerts.where((a) => a.id != id).toList(),
    );

    try {
      await _db.deletePriceAlert(id);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(alerts: previousAlerts, error: e.toString());
    }
  }

  /// Toggle alert active status
  Future<void> toggleAlert(int id, bool isActive) async {
    // Optimistic update: toggle in state immediately
    final previousAlerts = state.alerts;
    state = state.copyWith(
      alerts: state.alerts.map((a) {
        if (a.id == id) {
          return PriceAlertEntry(
            id: a.id,
            symbol: a.symbol,
            alertType: a.alertType,
            targetValue: a.targetValue,
            isActive: isActive,
            triggeredAt: a.triggeredAt,
            note: a.note,
            createdAt: a.createdAt,
          );
        }
        return a;
      }).toList(),
    );

    try {
      await _db.updatePriceAlert(
        id,
        PriceAlertCompanion(isActive: Value(isActive)),
      );
    } catch (e) {
      // Rollback on error
      state = state.copyWith(alerts: previousAlerts, error: e.toString());
    }
  }

  /// Check alerts against current prices
  Future<List<PriceAlertEntry>> checkAndTriggerAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges,
  ) async {
    try {
      final triggered = await _db.checkAlerts(currentPrices, priceChanges);
      final triggeredIds = <int>{};
      final now = DateTime.now();

      // Mark triggered alerts in database
      for (final alert in triggered) {
        await _db.triggerAlert(alert.id);
        triggeredIds.add(alert.id);
      }

      // Incremental update: update triggered alerts in state
      if (triggeredIds.isNotEmpty) {
        state = state.copyWith(
          alerts: state.alerts.map((a) {
            if (triggeredIds.contains(a.id)) {
              return PriceAlertEntry(
                id: a.id,
                symbol: a.symbol,
                alertType: a.alertType,
                targetValue: a.targetValue,
                isActive: false,
                triggeredAt: now,
                note: a.note,
                createdAt: a.createdAt,
              );
            }
            return a;
          }).toList(),
        );
      }

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
