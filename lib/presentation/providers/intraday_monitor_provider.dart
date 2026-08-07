import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:daredevil/core/utils/logger.dart';
import 'package:daredevil/core/utils/taiwan_time.dart';
import 'package:daredevil/data/remote/intraday_quote_client.dart';
import 'package:daredevil/domain/services/alert/intraday_alert_monitor.dart';
import 'package:daredevil/domain/services/alert/intraday_poll_schedule.dart';
import 'package:daredevil/presentation/providers/notification_provider.dart';
import 'package:daredevil/presentation/providers/price_alert_provider.dart';
import 'package:daredevil/presentation/providers/providers.dart';

/// 盤中提醒輪詢(2026-08-08)。
///
/// **誠實的能力邊界**:這是 app 在前景時的計時器。iOS/macOS 不保證背景
/// 常駐執行,所以「app 關著也會提醒」做不到——要那個等級的守候,正確
/// 工具是券商的到價通知(毫秒級且能直接成交)。這裡的價值不是速度,是
/// **懂你的規則**(均線、守門價)並在觸價時把判讀材料一起端出來。
///
/// 節流:沒掛條件時完全不輪詢(見 [IntradayPollSchedule.nextInterval]),
/// 只在四個決策時刻各檢查一次。
class IntradayMonitorNotifier extends Notifier<DateTime?> {
  Timer? _timer;
  bool _running = false;

  /// 提升為欄位:原本每輪 new 一個(盤中 4.5 小時 ≈ 54 個),每個自帶
  /// keep-alive 連線池且永不關閉(2026-08-08 code review)。專案其他
  /// client 一律 provider 持有 + onDispose 關閉,這裡比照。
  IntradayQuoteClient? _client;

  @override
  DateTime? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _client?.close();
    });
    return null;
  }

  /// 啟動輪詢(app 進前景時呼叫)。冪等。
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    unawaited(_tick());
  }

  /// 停止(app 退背景時呼叫)——背景燒流量沒有意義,系統也可能隨時凍結
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_running) return; // 前一輪還沒跑完就跳過,不堆疊請求
    final now = TaiwanTime.now();
    if (!IntradayPollSchedule.isMarketHours(now)) return;

    // 🚨 armed 必須查 DB,不能讀 UI 快取(2026-08-08 code review):
    // priceAlertProvider.alerts 在 loadAlerts() 跑過之前是空的,而全 repo
    // 只有提醒頁會呼叫它——使用者開在「今日」分頁就 armed=0,5 分鐘節奏
    // 靜默退化成一天四次,通知遲到最多兩小時。
    final armed = (await ref.read(databaseProvider).getActiveAlerts())
        .where((a) => a.triggeredAt == null)
        .length;
    final interval = IntradayPollSchedule.nextInterval(armedCount: armed);
    // 沒掛條件時只在決策時刻檢查;有掛條件則依間隔節流
    final last = state;
    if (interval == null) {
      if (!IntradayPollSchedule.isCheckpoint(now)) return;
    } else if (last != null && now.difference(last) < interval) {
      return;
    }

    _running = true;
    try {
      // 🚨 通知必須先就緒才可以檢查(2026-08-08 code review HIGH-1)。
      // check() 會把觸價的提醒標成已觸發且停用——若之後才發現通知發不
      // 出去(provider 未 initialize / 無權限),提醒就被**靜默燒掉**:
      // 使用者沒收到通知,而收盤那條路徑也再也看不到它(已非 active)。
      // 因此順序必須是「先確認能通知 → 再檢查」,不能反過來。
      final notifier = ref.read(notificationProvider.notifier);
      await notifier.initialize();
      if (!ref.read(notificationProvider).hasPermission) {
        AppLogger.debug('IntradayMonitor', '無通知權限,本輪不檢查(避免燒掉提醒)');
        return;
      }

      final monitor = IntradayAlertMonitor(
        database: ref.read(databaseProvider),
        client: _client ??= IntradayQuoteClient(),
      );
      final fired = (await monitor.check(now: now)).fired;
      state = now;
      for (final f in fired) {
        await ref
            .read(notificationProvider.notifier)
            .showPriceAlertNotification(f.alert, currentPrice: f.quote.price);
      }
      if (fired.isNotEmpty) {
        await ref.read(priceAlertProvider.notifier).loadAlerts();
      }
    } catch (e) {
      AppLogger.warning('IntradayMonitor', '盤中輪詢失敗', e);
    } finally {
      _running = false;
    }
  }
}

final intradayMonitorProvider =
    NotifierProvider<IntradayMonitorNotifier, DateTime?>(
      IntradayMonitorNotifier.new,
    );
