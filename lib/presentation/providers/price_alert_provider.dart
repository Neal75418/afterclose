import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// Alert type enum
enum AlertType {
  // 價格類警示
  above('ABOVE', AlertCategory.price),
  below('BELOW', AlertCategory.price),
  changePct('CHANGE_PCT', AlertCategory.price),

  // 成交量警示
  volumeSpike('VOLUME_SPIKE', AlertCategory.volume),
  volumeAbove('VOLUME_ABOVE', AlertCategory.volume),

  // RSI 警示
  rsiOverbought('RSI_OVERBOUGHT', AlertCategory.indicator),
  rsiOversold('RSI_OVERSOLD', AlertCategory.indicator),

  // KD 警示
  kdGoldenCross('KD_GOLDEN_CROSS', AlertCategory.indicator),
  kdDeathCross('KD_DEATH_CROSS', AlertCategory.indicator),

  // 支撐/壓力警示
  breakResistance('BREAK_RESISTANCE', AlertCategory.level),
  breakSupport('BREAK_SUPPORT', AlertCategory.level),

  // 52-week alerts
  week52High('WEEK_52_HIGH', AlertCategory.week52),
  week52Low('WEEK_52_LOW', AlertCategory.week52),

  // 均線警示
  crossAboveMa('CROSS_ABOVE_MA', AlertCategory.ma),
  crossBelowMa('CROSS_BELOW_MA', AlertCategory.ma),

  // 基本面警示
  revenueYoySurge('REVENUE_YOY_SURGE', AlertCategory.fundamental),
  highDividendYield('HIGH_DIVIDEND_YIELD', AlertCategory.fundamental),
  peUndervalued('PE_UNDERVALUED', AlertCategory.fundamental),

  // 交易警示
  tradingWarning('TRADING_WARNING', AlertCategory.warning),
  tradingDisposal('TRADING_DISPOSAL', AlertCategory.warning),

  // 內部人警示
  insiderSelling('INSIDER_SELLING', AlertCategory.insider),
  insiderBuying('INSIDER_BUYING', AlertCategory.insider),
  highPledgeRatio('HIGH_PLEDGE_RATIO', AlertCategory.insider);

  const AlertType(this.value, this.category);
  final String value;
  final AlertCategory category;

  /// 翻譯後的顯示標籤（i18n）
  String get label => 'alert.alertType.$name'.tr();

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
    // 以下類型不需明確目標值（自動觸發）
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

  /// Get unit label for target value (i18n)
  String get targetValueUnit => switch (this) {
    AlertType.above ||
    AlertType.below ||
    AlertType.breakResistance ||
    AlertType.breakSupport => 'alert.currency'.tr(),
    AlertType.changePct ||
    AlertType.revenueYoySurge ||
    AlertType.highDividendYield => '%',
    AlertType.volumeAbove => 'stockDetail.unitShares'.tr(),
    AlertType.rsiOverbought || AlertType.rsiOversold => '',
    AlertType.crossAboveMa || AlertType.crossBelowMa => 'alert.unit.dayMa'.tr(),
    AlertType.peUndervalued => 'alert.unit.times'.tr(),
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
  price,
  volume,
  indicator,
  level,
  week52,
  ma,
  fundamental,
  warning,
  insider;

  /// 取得翻譯後的分類名稱
  String get label => 'alert.category.$name'.tr();

  /// Get all alert types in this category
  List<AlertType> get alertTypes =>
      AlertType.values.where((a) => a.category == this).toList();
}

/// 取得 AlertType 的 i18n 描述（用於 UI 顯示）
///
/// 共用函式，避免 alerts_screen.dart 和 alerts_tab.dart 各自重複維護。
String getAlertDescription(PriceAlertEntry alert, AlertType type) {
  return switch (type) {
    AlertType.above => 'alert.priceAbove'.tr(
      namedArgs: {'price': alert.targetValue.toStringAsFixed(2)},
    ),
    AlertType.below => 'alert.priceBelow'.tr(
      namedArgs: {'price': alert.targetValue.toStringAsFixed(2)},
    ),
    AlertType.changePct => 'alert.changeAbove'.tr(
      namedArgs: {'percent': alert.targetValue.toStringAsFixed(1)},
    ),
    AlertType.volumeSpike => 'alert.desc.volumeSpike'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(0)},
    ),
    AlertType.volumeAbove => 'alert.desc.volumeAbove'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(0)},
    ),
    AlertType.rsiOverbought => 'alert.desc.rsiOverbought'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(0)},
    ),
    AlertType.rsiOversold => 'alert.desc.rsiOversold'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(0)},
    ),
    AlertType.kdGoldenCross => 'alert.desc.kdGoldenCross'.tr(),
    AlertType.kdDeathCross => 'alert.desc.kdDeathCross'.tr(),
    AlertType.breakResistance => 'alert.desc.breakResistance'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(2)},
    ),
    AlertType.breakSupport => 'alert.desc.breakSupport'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(2)},
    ),
    AlertType.week52High => 'alert.desc.week52High'.tr(),
    AlertType.week52Low => 'alert.desc.week52Low'.tr(),
    AlertType.crossAboveMa => 'alert.desc.crossAboveMa'.tr(
      namedArgs: {'value': alert.targetValue.toInt().toString()},
    ),
    AlertType.crossBelowMa => 'alert.desc.crossBelowMa'.tr(
      namedArgs: {'value': alert.targetValue.toInt().toString()},
    ),
    AlertType.revenueYoySurge => 'alert.desc.revenueYoySurge'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(1)},
    ),
    AlertType.highDividendYield => 'alert.desc.highDividendYield'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(1)},
    ),
    AlertType.peUndervalued => 'alert.desc.peUndervalued'.tr(
      namedArgs: {'value': alert.targetValue.toStringAsFixed(1)},
    ),
    AlertType.tradingWarning => 'alert.desc.tradingWarning'.tr(),
    AlertType.tradingDisposal => 'alert.desc.tradingDisposal'.tr(),
    AlertType.insiderSelling => 'alert.desc.insiderSelling'.tr(),
    AlertType.insiderBuying => 'alert.desc.insiderBuying'.tr(),
    AlertType.highPledgeRatio => 'alert.desc.highPledgeRatio'.tr(),
  };
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
class PriceAlertNotifier extends Notifier<PriceAlertState> {
  late final AppDatabase _db;

  @override
  PriceAlertState build() {
    _db = ref.watch(databaseProvider);
    return const PriceAlertState();
  }

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

      // 增量更新：新增至 state 而非全量重載
      // 插入開頭以維持建立時間降冪
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
    // 樂觀更新：立即從 state 移除
    final previousAlerts = state.alerts;
    state = state.copyWith(
      alerts: state.alerts.where((a) => a.id != id).toList(),
    );

    try {
      await _db.deletePriceAlert(id);
    } catch (e) {
      // 錯誤時回滾
      state = state.copyWith(alerts: previousAlerts, error: e.toString());
    }
  }

  /// Toggle alert active status
  Future<void> toggleAlert(int id, bool isActive) async {
    // 樂觀更新：立即切換 state
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
      // 錯誤時回滾
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

      // 在資料庫標記已觸發的警示
      for (final alert in triggered) {
        await _db.triggerAlert(alert.id);
        triggeredIds.add(alert.id);
      }

      // 增量更新：更新 state 中已觸發的警示
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
    NotifierProvider<PriceAlertNotifier, PriceAlertState>(
      PriceAlertNotifier.new,
    );

/// Get alerts for a specific symbol
final alertsForSymbolProvider =
    FutureProvider.family<List<PriceAlertEntry>, String>((ref, symbol) async {
      final db = ref.watch(databaseProvider);
      return db.getAlertsForSymbol(symbol);
    });
