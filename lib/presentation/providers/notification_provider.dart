import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/services/notification_service.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';

/// Notification state
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

/// Notification notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState());

  final _service = NotificationService.instance;

  @override
  void dispose() {
    // Fire-and-forget: singleton async dispose completes independently
    unawaited(_service.dispose());
    super.dispose();
  }

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      await _service.initialize();
      final hasPermission = await _service.requestPermissions();
      state = state.copyWith(isInitialized: true, hasPermission: hasPermission);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Request notification permissions
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

  /// Show price alert notification
  Future<void> showPriceAlertNotification(
    PriceAlertEntry alert, {
    double? currentPrice,
  }) async {
    if (!state.isInitialized || !state.hasPermission) return;

    final alertType = AlertType.fromValue(alert.alertType);
    final title = _getAlertTitle(alert.symbol, alertType);
    final body = _getAlertBody(alert, alertType, currentPrice);

    await _service.showPriceAlert(
      id: alert.id,
      symbol: alert.symbol,
      title: title,
      body: body,
      payload: alert.symbol,
    );
  }

  /// Show update complete notification
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
      AlertType.volumeSpike || AlertType.volumeAbove => '$symbol 成交量警報',
      AlertType.rsiOverbought => '$symbol RSI 超買',
      AlertType.rsiOversold => '$symbol RSI 超賣',
      AlertType.kdGoldenCross => '$symbol KD 黃金交叉',
      AlertType.kdDeathCross => '$symbol KD 死亡交叉',
      AlertType.breakResistance => '$symbol 突破壓力',
      AlertType.breakSupport => '$symbol 跌破支撐',
      AlertType.week52High => '$symbol 創52週新高',
      AlertType.week52Low => '$symbol 創52週新低',
      AlertType.crossAboveMa => '$symbol 站上均線',
      AlertType.crossBelowMa => '$symbol 跌破均線',
      AlertType.revenueYoySurge => '$symbol 營收年增暴增',
      AlertType.highDividendYield => '$symbol 高殖利率達標',
      AlertType.peUndervalued => '$symbol PE低估達標',
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
      AlertType.volumeSpike => '成交量達到均量的 ${alert.targetValue.toStringAsFixed(0)} 倍',
      AlertType.volumeAbove => '成交量超過 ${alert.targetValue.toStringAsFixed(0)} 張',
      AlertType.rsiOverbought => 'RSI 已達超買區域（≥${alert.targetValue.toStringAsFixed(0)}）',
      AlertType.rsiOversold => 'RSI 已達超賣區域（≤${alert.targetValue.toStringAsFixed(0)}）',
      AlertType.kdGoldenCross => 'KD 指標出現黃金交叉',
      AlertType.kdDeathCross => 'KD 指標出現死亡交叉',
      AlertType.breakResistance => '價格突破壓力位 ${alert.targetValue.toStringAsFixed(2)} 元',
      AlertType.breakSupport => '價格跌破支撐位 ${alert.targetValue.toStringAsFixed(2)} 元',
      AlertType.week52High => '價格創下52週新高',
      AlertType.week52Low => '價格創下52週新低',
      AlertType.crossAboveMa => '價格站上 ${alert.targetValue.toInt()} 日均線',
      AlertType.crossBelowMa => '價格跌破 ${alert.targetValue.toInt()} 日均線',
      AlertType.revenueYoySurge => '營收年增率達 ${alert.targetValue.toStringAsFixed(1)}%',
      AlertType.highDividendYield => '殖利率達 ${alert.targetValue.toStringAsFixed(1)}%',
      AlertType.peUndervalued => 'PE 低於 ${alert.targetValue.toStringAsFixed(1)} 倍',
    };

    return '$baseBody$priceText';
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    await _service.cancelNotification(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _service.cancelAllNotifications();
  }
}

/// Notification provider
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
      return NotificationNotifier();
    });
