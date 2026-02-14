import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:easy_localization/easy_localization.dart';

import 'package:afterclose/core/services/notification_service.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';

/// 通知狀態
class NotificationState {
  const NotificationState({
    this.isInitialized = false,
    this.hasPermission = false,
    this.error,
  });

  final bool isInitialized;
  final bool hasPermission;
  final String? error;

  NotificationState copyWith({
    bool? isInitialized,
    bool? hasPermission,
    String? error,
  }) {
    return NotificationState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasPermission: hasPermission ?? this.hasPermission,
      error: error,
    );
  }
}

/// 通知管理器
class NotificationNotifier extends Notifier<NotificationState> {
  final _service = NotificationService.instance;

  @override
  NotificationState build() {
    ref.onDispose(() {
      unawaited(_service.dispose());
    });
    return const NotificationState();
  }

  /// 初始化通知服務
  ///
  /// 注意：不會自動請求權限，權限會在使用者建立提醒時請求
  Future<void> initialize() async {
    try {
      await _service.initialize();
      // 只檢查權限狀態，不主動請求
      final hasPermission = await _service.hasPermission();
      state = state.copyWith(isInitialized: true, hasPermission: hasPermission);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 確保已取得通知權限
  ///
  /// 在建立提醒前呼叫，若尚未取得權限會請求使用者授權
  Future<bool> ensurePermission() async {
    if (state.hasPermission) return true;
    return requestPermissions();
  }

  /// 請求通知權限
  Future<bool> requestPermissions() async {
    try {
      final hasPermission = await _service.requestPermissions();
      state = state.copyWith(hasPermission: hasPermission);
      return hasPermission;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 顯示價格提醒通知
  Future<void> showPriceAlertNotification(
    PriceAlertEntry alert, {
    double? currentPrice,
  }) async {
    if (!state.isInitialized || !state.hasPermission) return;

    final alertType = AlertType.fromValue(alert.alertType);
    final title = _getAlertTitle(alert.symbol, alertType);
    final body = _getAlertBody(alert, alertType, currentPrice);

    // 處置股票使用緊急通知（Importance.max）
    if (alertType == AlertType.tradingDisposal) {
      await _service.showUrgentAlert(
        id: alert.id,
        symbol: alert.symbol,
        title: title,
        body: body,
        payload: alert.symbol,
      );
    } else {
      await _service.showPriceAlert(
        id: alert.id,
        symbol: alert.symbol,
        title: title,
        body: body,
        payload: alert.symbol,
      );
    }
  }

  /// 顯示更新完成通知
  Future<void> showUpdateCompleteNotification({
    required int recommendationCount,
    required int alertsTriggered,
  }) async {
    if (!state.isInitialized || !state.hasPermission) return;

    final String body;
    if (alertsTriggered > 0) {
      body = 'notification.updateWithAlerts'.tr(
        namedArgs: {
          'recommendations': recommendationCount.toString(),
          'alerts': alertsTriggered.toString(),
        },
      );
    } else {
      body = 'notification.updateNoAlerts'.tr(
        namedArgs: {'recommendations': recommendationCount.toString()},
      );
    }

    await _service.showNotification(
      id: 0,
      title: 'notification.updateComplete'.tr(),
      body: body,
    );
  }

  String _getAlertTitle(String symbol, AlertType alertType) {
    return switch (alertType) {
      AlertType.above => 'notification.priceAboveTarget'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.below => 'notification.priceBelowTarget'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.changePct => 'notification.priceChangeTarget'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.volumeSpike || AlertType.volumeAbove =>
        'notification.volumeAlertTitle'.tr(namedArgs: {'symbol': symbol}),
      AlertType.rsiOverbought => 'notification.rsiOverboughtTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.rsiOversold => 'notification.rsiOversoldTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.kdGoldenCross => 'notification.kdGoldenCrossTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.kdDeathCross => 'notification.kdDeathCrossTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.breakResistance => 'notification.breakResistanceTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.breakSupport => 'notification.breakSupportTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.week52High => 'notification.week52HighTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.week52Low => 'notification.week52LowTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.crossAboveMa => 'notification.crossAboveMaTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.crossBelowMa => 'notification.crossBelowMaTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.revenueYoySurge => 'notification.revenueYoySurgeTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.highDividendYield => 'notification.highDividendYieldTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.peUndervalued => 'notification.peUndervaluedTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.tradingWarning => 'notification.tradingWarningTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.tradingDisposal => 'notification.tradingDisposalTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.insiderSelling => 'notification.insiderSellingTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.insiderBuying => 'notification.insiderBuyingTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
      AlertType.highPledgeRatio => 'notification.highPledgeRatioTitle'.tr(
        namedArgs: {'symbol': symbol},
      ),
    };
  }

  String _getAlertBody(
    PriceAlertEntry alert,
    AlertType alertType,
    double? currentPrice,
  ) {
    final priceText = currentPrice != null
        ? 'notification.currentPriceSuffix'.tr(
            namedArgs: {'price': currentPrice.toStringAsFixed(2)},
          )
        : '';

    final baseBody = switch (alertType) {
      AlertType.above => 'notification.aboveBody'.tr(
        namedArgs: {'price': alert.targetValue.toStringAsFixed(2)},
      ),
      AlertType.below => 'notification.belowBody'.tr(
        namedArgs: {'price': alert.targetValue.toStringAsFixed(2)},
      ),
      AlertType.changePct => 'notification.changeBody'.tr(
        namedArgs: {'percent': alert.targetValue.toStringAsFixed(1)},
      ),
      AlertType.volumeSpike => 'notification.volumeSpikeBody'.tr(
        namedArgs: {'value': alert.targetValue.toStringAsFixed(0)},
      ),
      AlertType.volumeAbove => 'notification.volumeAboveBody'.tr(
        namedArgs: {'value': alert.targetValue.toStringAsFixed(0)},
      ),
      AlertType.rsiOverbought => 'notification.rsiOverboughtBody'.tr(
        namedArgs: {'value': alert.targetValue.toStringAsFixed(0)},
      ),
      AlertType.rsiOversold => 'notification.rsiOversoldBody'.tr(
        namedArgs: {'value': alert.targetValue.toStringAsFixed(0)},
      ),
      AlertType.kdGoldenCross => 'notification.kdGoldenCrossBody'.tr(),
      AlertType.kdDeathCross => 'notification.kdDeathCrossBody'.tr(),
      AlertType.breakResistance => 'notification.breakResistanceBody'.tr(
        namedArgs: {'price': alert.targetValue.toStringAsFixed(2)},
      ),
      AlertType.breakSupport => 'notification.breakSupportBody'.tr(
        namedArgs: {'price': alert.targetValue.toStringAsFixed(2)},
      ),
      AlertType.week52High => 'notification.week52HighBody'.tr(),
      AlertType.week52Low => 'notification.week52LowBody'.tr(),
      AlertType.crossAboveMa => 'notification.crossAboveMaBody'.tr(
        namedArgs: {'days': alert.targetValue.toInt().toString()},
      ),
      AlertType.crossBelowMa => 'notification.crossBelowMaBody'.tr(
        namedArgs: {'days': alert.targetValue.toInt().toString()},
      ),
      AlertType.revenueYoySurge => 'notification.revenueYoySurgeBody'.tr(
        namedArgs: {'percent': alert.targetValue.toStringAsFixed(1)},
      ),
      AlertType.highDividendYield => 'notification.highDividendYieldBody'.tr(
        namedArgs: {'percent': alert.targetValue.toStringAsFixed(1)},
      ),
      AlertType.peUndervalued => 'notification.peUndervaluedBody'.tr(
        namedArgs: {'value': alert.targetValue.toStringAsFixed(1)},
      ),
      AlertType.tradingWarning => 'notification.tradingWarningBody'.tr(),
      AlertType.tradingDisposal => 'notification.tradingDisposalBody'.tr(),
      AlertType.insiderSelling => 'notification.insiderSellingBody'.tr(),
      AlertType.insiderBuying => 'notification.insiderBuyingBody'.tr(),
      AlertType.highPledgeRatio => 'notification.highPledgeRatioBody'.tr(),
    };

    return '$baseBody$priceText';
  }

  /// 取消指定通知
  Future<void> cancelNotification(int id) async {
    await _service.cancelNotification(id);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _service.cancelAllNotifications();
  }
}

/// 通知 Provider
final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );
