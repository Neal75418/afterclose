import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/utils/error_display.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/alert_evaluation_service.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 警示類型列舉
enum AlertType {
  // 價格類警示
  above('ABOVE'),
  below('BELOW'),
  changePct('CHANGE_PCT'),

  // 成交量警示
  volumeSpike('VOLUME_SPIKE'),
  volumeAbove('VOLUME_ABOVE'),

  // RSI 警示
  rsiOverbought('RSI_OVERBOUGHT'),
  rsiOversold('RSI_OVERSOLD'),

  // KD 警示
  kdGoldenCross('KD_GOLDEN_CROSS'),
  kdDeathCross('KD_DEATH_CROSS'),

  // 支撐/壓力警示
  breakResistance('BREAK_RESISTANCE'),
  breakSupport('BREAK_SUPPORT'),

  // 52 週警示
  week52High('WEEK_52_HIGH'),
  week52Low('WEEK_52_LOW'),

  // 均線警示
  crossAboveMa('CROSS_ABOVE_MA'),
  crossBelowMa('CROSS_BELOW_MA'),

  // 基本面警示
  revenueYoySurge('REVENUE_YOY_SURGE'),
  highDividendYield('HIGH_DIVIDEND_YIELD'),
  peUndervalued('PE_UNDERVALUED'),

  // 交易警示
  tradingWarning('TRADING_WARNING'),
  tradingDisposal('TRADING_DISPOSAL'),

  // 內部人警示
  insiderSelling('INSIDER_SELLING'),
  insiderBuying('INSIDER_BUYING'),
  highPledgeRatio('HIGH_PLEDGE_RATIO');

  const AlertType(this.value);
  final String value;

  /// 翻譯後的顯示標籤（i18n）
  String get label => 'alert.alertType.$name'.tr();

  /// 檢查此警示類型是否需要目標值
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

  /// 取得目標值的單位標籤（i18n）
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

  /// 取得此警示類型的預設目標值
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

  /// 檢查此警示類型是否已實作觸發邏輯
  ///
  /// 僅已實作的類型可供使用者在 UI 中建立。
  /// 回傳 true 的警示類型在 user_dao.dart 中有觸發邏輯。
  // 已實作的 AlertType:
  // - above, below, changePct (基本價格)
  // - volumeSpike, volumeAbove (成交量)
  // - week52High, week52Low (52 週)
  // - rsiOverbought, rsiOversold, kdGoldenCross, kdDeathCross (技術指標)
  // - crossAboveMa, crossBelowMa, tradingWarning, tradingDisposal (均線/警示)
  bool get isImplemented => switch (this) {
    AlertType.above ||
    AlertType.below ||
    AlertType.changePct ||
    AlertType.volumeSpike ||
    AlertType.volumeAbove ||
    AlertType.week52High ||
    AlertType.week52Low ||
    AlertType.rsiOverbought ||
    AlertType.rsiOversold ||
    AlertType.kdGoldenCross ||
    AlertType.kdDeathCross ||
    AlertType.crossAboveMa ||
    AlertType.crossBelowMa ||
    AlertType.tradingWarning ||
    AlertType.tradingDisposal => true,
    _ => false,
  };

  /// 從字串值解析 AlertType。
  ///
  /// 若值不是有效的 AlertType，拋出 [ArgumentError]。
  static AlertType fromValue(String value) {
    return tryFromValue(value) ??
        (throw ArgumentError.value(
          value,
          'value',
          'Invalid AlertType value. Valid values: ${AlertType.values.map((e) => e.value).join(", ")}',
        ));
  }

  /// 嘗試從字串值解析 AlertType。
  ///
  /// 若值不是有效的 AlertType，回傳 null。
  static AlertType? tryFromValue(String value) {
    for (final type in AlertType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
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

/// 價格警示狀態
class PriceAlertState {
  const PriceAlertState({
    this.alerts = const [],
    this.isLoading = false,
    this.error,
  });

  final List<PriceAlertEntry> alerts;
  final bool isLoading;
  final String? error;

  static const _sentinel = Object();

  PriceAlertState copyWith({
    List<PriceAlertEntry>? alerts,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return PriceAlertState(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

/// 價格警示 Notifier
class PriceAlertNotifier extends Notifier<PriceAlertState> {
  late final AppDatabase _db;

  /// 同一 alert 的 in-flight toggle Future（序列化執行，last wins）
  Map<int, Future<void>> _pendingToggles = {};

  @override
  PriceAlertState build() {
    _db = ref.watch(databaseProvider);
    _pendingToggles = {};
    return const PriceAlertState();
  }

  /// 載入所有警示（啟用與停用）
  Future<void> loadAlerts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final alerts = await _db.getAllAlerts();
      state = state.copyWith(alerts: alerts, isLoading: false);
    } catch (e) {
      AppLogger.warning('PriceAlertNotifier', '載入警示失敗', e);
      state = state.copyWith(isLoading: false, error: ErrorDisplay.message(e));
    }
  }

  /// 清除錯誤狀態
  void clearError() => state = state.copyWith(error: null);

  /// 建立新的價格警示
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
      AppLogger.warning('PriceAlertNotifier', '建立警示失敗: $symbol', e);
      state = state.copyWith(error: ErrorDisplay.message(e));
      return false;
    }
  }

  /// 刪除警示
  Future<void> deleteAlert(int id) async {
    // 樂觀更新：立即從 state 移除，並清除先前錯誤
    final previousAlerts = state.alerts;
    state = state.copyWith(
      alerts: state.alerts.where((a) => a.id != id).toList(),
      error: null,
    );

    try {
      await _db.deletePriceAlert(id);
    } catch (e) {
      // 錯誤時回滾
      AppLogger.warning('PriceAlertNotifier', '刪除警示失敗: $id', e);
      state = state.copyWith(
        alerts: previousAlerts,
        error: ErrorDisplay.message(e),
      );
    }
  }

  /// 切換警示啟用狀態
  ///
  /// 序列化同一 alert 的操作：若前一次 toggle 仍在執行，會等它完成後
  /// 再執行本次操作，確保最後一次使用者意圖落庫（last wins）。
  Future<void> toggleAlert(int id, bool isActive) async {
    // 捕獲前一次 in-flight Future（若有）
    final pending = _pendingToggles[id];

    Future<void> doToggle() async {
      // 等待前一次完成後再執行，確保序列化
      // try-catch: 前一次的錯誤不應阻擋本次操作
      if (pending != null) {
        try {
          await pending;
        } catch (_) {
          // 前一次已自行處理錯誤（rollback + state.error），忽略即可
        }
      }
      await _doToggleAlert(id, isActive);
    }

    final future = doToggle();
    _pendingToggles[id] = future;
    try {
      await future;
    } finally {
      // 僅清除自己的 Future，避免移除後續排隊的操作
      if (_pendingToggles[id] == future) {
        _pendingToggles.remove(id);
      }
    }
  }

  Future<void> _doToggleAlert(int id, bool isActive) async {
    // 樂觀更新：立即切換 state，並清除先前錯誤
    final previousAlerts = state.alerts;
    state = state.copyWith(
      error: null,
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
      AppLogger.warning('PriceAlertNotifier', '切換警示狀態失敗: $id', e);
      state = state.copyWith(
        alerts: previousAlerts,
        error: ErrorDisplay.message(e),
      );
    }
  }

  /// 已實作的警示類型字串集合（與 evaluator switch 一致，用於偵測需停用的類型）
  static final _knownAlertTypes = AlertType.values
      .where((e) => e.isImplemented)
      .map((e) => e.value)
      .toSet();

  /// 根據當前價格檢查警示觸發條件
  Future<List<PriceAlertEntry>> checkAndTriggerAlerts(
    Map<String, double> currentPrices,
    Map<String, double> priceChanges,
  ) async {
    try {
      final triggered = await _db.checkAlerts(
        currentPrices,
        priceChanges,
        evaluationService: AlertEvaluationService(),
      );
      final triggeredIds = <int>{};
      final now = DateTime.now();

      // 在資料庫標記已觸發的警示
      for (final alert in triggered) {
        await _db.triggerAlert(alert.id);
        triggeredIds.add(alert.id);
      }

      // 增量更新：同步 triggered 與 DAO 自動停用的舊版 alert 至 state
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
          // DAO checkAlerts 已自動停用未實作類型，同步至 state
          if (a.isActive && !_knownAlertTypes.contains(a.alertType)) {
            return PriceAlertEntry(
              id: a.id,
              symbol: a.symbol,
              alertType: a.alertType,
              targetValue: a.targetValue,
              isActive: false,
              triggeredAt: a.triggeredAt,
              note: a.note,
              createdAt: a.createdAt,
            );
          }
          return a;
        }).toList(),
      );

      return triggered;
    } catch (e) {
      AppLogger.warning('PriceAlertNotifier', '檢查警示觸發失敗', e);
      state = state.copyWith(error: ErrorDisplay.message(e));
      return [];
    }
  }
}

/// 價格警示 Provider
final priceAlertProvider =
    NotifierProvider<PriceAlertNotifier, PriceAlertState>(
      PriceAlertNotifier.new,
    );
