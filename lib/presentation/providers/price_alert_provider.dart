import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// Alert type enum
enum AlertType {
  // Price-based alerts
  above('ABOVE', '價格高於', AlertCategory.price),
  below('BELOW', '價格低於', AlertCategory.price),
  changePct('CHANGE_PCT', '漲跌幅達', AlertCategory.price),

  // Volume alerts
  volumeSpike('VOLUME_SPIKE', '成交量爆量', AlertCategory.volume),
  volumeAbove('VOLUME_ABOVE', '成交量高於', AlertCategory.volume),

  // RSI alerts
  rsiOverbought('RSI_OVERBOUGHT', 'RSI超買', AlertCategory.indicator),
  rsiOversold('RSI_OVERSOLD', 'RSI超賣', AlertCategory.indicator),

  // KD alerts
  kdGoldenCross('KD_GOLDEN_CROSS', 'KD黃金交叉', AlertCategory.indicator),
  kdDeathCross('KD_DEATH_CROSS', 'KD死亡交叉', AlertCategory.indicator),

  // Support/Resistance alerts
  breakResistance('BREAK_RESISTANCE', '突破壓力', AlertCategory.level),
  breakSupport('BREAK_SUPPORT', '跌破支撐', AlertCategory.level),

  // 52-week alerts
  week52High('WEEK_52_HIGH', '創52週新高', AlertCategory.week52),
  week52Low('WEEK_52_LOW', '創52週新低', AlertCategory.week52),

  // MA alerts
  crossAboveMa('CROSS_ABOVE_MA', '站上均線', AlertCategory.ma),
  crossBelowMa('CROSS_BELOW_MA', '跌破均線', AlertCategory.ma),

  // Fundamental alerts (基本面警報)
  revenueYoySurge('REVENUE_YOY_SURGE', '營收年增暴增', AlertCategory.fundamental),
  highDividendYield('HIGH_DIVIDEND_YIELD', '高殖利率', AlertCategory.fundamental),
  peUndervalued('PE_UNDERVALUED', 'PE低估', AlertCategory.fundamental),

  // Trading warning alerts (Killer Features：注意/處置股票警報)
  tradingWarning('TRADING_WARNING', '注意股票', AlertCategory.warning),
  tradingDisposal('TRADING_DISPOSAL', '處置股票', AlertCategory.warning),

  // Insider alerts (Killer Features：董監持股警報)
  insiderSelling('INSIDER_SELLING', '董監減持', AlertCategory.insider),
  insiderBuying('INSIDER_BUYING', '董監增持', AlertCategory.insider),
  highPledgeRatio('HIGH_PLEDGE_RATIO', '高質押比例', AlertCategory.insider);

  const AlertType(this.value, this.label, this.category);
  final String value;
  final String label;
  final AlertCategory category;

  /// Check if this alert type requires a target value
  bool get requiresTargetValue => switch (this) {
    AlertType.above ||
    AlertType.below ||
    AlertType.changePct ||
    AlertType.volumeAbove ||
    AlertType.rsiOverbought ||
    AlertType.rsiOversold ||
    AlertType.breakResistance ||
    AlertType.breakSupport ||
    AlertType.crossAboveMa ||
    AlertType.crossBelowMa ||
    AlertType.revenueYoySurge ||
    AlertType.highDividendYield ||
    AlertType.peUndervalued => true,
    // These don't require explicit target value (auto-triggered)
    AlertType.volumeSpike ||
    AlertType.kdGoldenCross ||
    AlertType.kdDeathCross ||
    AlertType.week52High ||
    AlertType.week52Low ||
    // Killer Features：自動觸發，無需目標值
    AlertType.tradingWarning ||
    AlertType.tradingDisposal ||
    AlertType.insiderSelling ||
    AlertType.insiderBuying ||
    AlertType.highPledgeRatio => false,
  };

  /// Get unit label for target value
  String get targetValueUnit => switch (this) {
    AlertType.above ||
    AlertType.below ||
    AlertType.breakResistance ||
    AlertType.breakSupport => '元',
    AlertType.changePct ||
    AlertType.revenueYoySurge ||
    AlertType.highDividendYield => '%',
    AlertType.volumeAbove => '張',
    AlertType.rsiOverbought || AlertType.rsiOversold => '',
    AlertType.crossAboveMa || AlertType.crossBelowMa => '日均線',
    AlertType.peUndervalued => '倍',
    _ => '',
  };

  /// Get default target value for this alert type
  double? get defaultTargetValue => switch (this) {
    AlertType.rsiOverbought => 70.0,
    AlertType.rsiOversold => 30.0,
    AlertType.crossAboveMa || AlertType.crossBelowMa => 20.0, // 20-day MA
    AlertType.volumeSpike => 2.0, // 2x average
    AlertType.revenueYoySurge => 30.0, // 30% YoY growth
    AlertType.highDividendYield => 5.0, // 5% yield
    AlertType.peUndervalued => 10.0, // PE < 10
    _ => null,
  };

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

/// Alert category for grouping in UI
enum AlertCategory {
  price('價格'),
  volume('成交量'),
  indicator('技術指標'),
  level('支撐壓力'),
  week52('新高新低'),
  ma('均線'),
  fundamental('基本面'),
  warning('警示'),
  insider('董監');

  const AlertCategory(this.label);
  final String label;

  /// Get all alert types in this category
  List<AlertType> get alertTypes =>
      AlertType.values.where((a) => a.category == this).toList();
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
        state = state.copyWith(alerts: [newAlert, ...state.alerts]);
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
