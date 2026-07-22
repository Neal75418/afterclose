import 'dart:collection';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/logger.dart';

/// API 供應商列舉（per-vendor budget）。
enum ApiVendor { finMind, twse, tpex, tdcc }

/// 跨 syncer 共享的 API 配額追蹤器，process-local + sliding 1hr 視窗。
///
/// ## 動機
///
/// 過去各 syncer / repo 自己估配額消耗（[ApiConfig] 內常數 + per-syncer
/// circuit-breaker），且 `update_service` 平行跑 4 組 syncer 共用同一個
/// FinMind token — 2026-06 實測案例：HistoricalPriceSyncer 預算 300、
/// 實際各 syncer 加總打了 1125 calls，撞 hourly cap 整套 abort。
///
/// ## 設計選項（user 拍板）
///
/// - **per-vendor** 而非 per-endpoint：簡單，避免每個 method 都要查表
/// - **process-local** 而非寫 DB：重啟即歸零；對 ad-hoc 開 app 跑 update
///   足夠（背景跑 WorkManager 觸發新 isolate 也是新 tracker，等於 reset；
///   行為跟 backend rate-limit 跨重啟「不會繼承使用量」的常識一致）
/// - **sliding 1hr** 視窗：FinMind free tier 是 rolling 600/hr，固定時段
///   reset 會撞 thundering herd。Sliding 比較準。
///
/// ## 整合方式
///
/// 1. Client（[FinMindClient] 等）建構時注入 tracker，呼叫前 `checkBudget`
///    用完即拋 [RateLimitException]、呼叫後 `recordCall` 紀錄。
/// 2. 偵測到 429 response 時 `markRateLimited` 翻 cooldown 旗標，往後 1hr
///    內 checkBudget 直接拒。
///
/// 暫定先掛 FinMindClient（600/hr free tier，實際 bottleneck）；
/// TWSE/TPEx OpenAPI 無實質限額、TDCC 用量極低，留 follow-up 評估。
class ApiBudgetTracker {
  ApiBudgetTracker({
    Map<ApiVendor, int>? hourlyBudget,
    AppClock clock = const SystemClock(),
  }) : _budget = hourlyBudget ?? _defaultBudget,
       _clock = clock;

  final Map<ApiVendor, int> _budget;
  final AppClock _clock;

  /// 每個 vendor 的呼叫時間戳記隊列（FIFO，舊的會被踢出）
  final Map<ApiVendor, Queue<DateTime>> _callTimestamps = {};

  /// 因 429 翻起的 rate-limit cooldown 起點；null 代表未限流
  final Map<ApiVendor, DateTime?> _rateLimitedAt = {};

  /// FinMind free tier 600/hr 是實際 bottleneck；其餘 vendor 不會撞牆，
  /// 設大值僅作 safety net。
  static const Map<ApiVendor, int> _defaultBudget = {
    ApiVendor.finMind: 600,
    ApiVendor.twse: 10000,
    ApiVendor.tpex: 10000,
    ApiVendor.tdcc: 1000,
  };

  /// 取得指定 vendor 的 hourly budget。
  int budgetFor(ApiVendor vendor) =>
      _budget[vendor] ?? _defaultBudget[vendor] ?? 1000;

  /// 取得指定 vendor 過去 1hr 內已呼叫的次數（test/debug 用）。
  int callsInLastHourFor(ApiVendor vendor) {
    final queue = _callTimestamps[vendor];
    if (queue == null) return 0;
    _expireOldEntries(vendor);
    return queue.length;
  }

  /// 是否處於 cooldown（被 [markRateLimited] 翻起後 1hr 內）。
  bool isRateLimited(ApiVendor vendor) {
    final at = _rateLimitedAt[vendor];
    if (at == null) return false;
    if (_clock.now().difference(at) >= const Duration(hours: 1)) {
      _rateLimitedAt[vendor] = null;
      return false;
    }
    return true;
  }

  /// 在打 API 之前呼叫。被限流或預算用完拋 [RateLimitException]。
  void checkBudget(ApiVendor vendor) {
    if (isRateLimited(vendor)) {
      throw RateLimitException(
        '${vendor.name} API 已於 ${_rateLimitedAt[vendor]} 撞限流，1hr cooldown 中',
      );
    }

    _expireOldEntries(vendor);
    final used = _callTimestamps[vendor]?.length ?? 0;
    final budget = budgetFor(vendor);
    if (used >= budget) {
      throw RateLimitException(
        '${vendor.name} API hourly budget 已用完: $used/$budget calls',
      );
    }
  }

  /// 在 API call 發出後紀錄（成功或失敗都要記，否則 retry 也吃配額）。
  void recordCall(ApiVendor vendor) {
    final queue = _callTimestamps.putIfAbsent(vendor, () => Queue<DateTime>());
    queue.addLast(_clock.now());
  }

  /// 在收到 429 / 配額拒絕時呼叫，翻 cooldown 旗標、warning log。
  void markRateLimited(ApiVendor vendor) {
    _rateLimitedAt[vendor] = _clock.now();
    AppLogger.warning(
      'ApiBudgetTracker',
      '${vendor.name} 撞 rate limit，1hr cooldown 開始 '
          '(已用 ${callsInLastHourFor(vendor)}/${budgetFor(vendor)})',
    );
  }

  /// 清掉 vendor queue 內超過 1hr 的舊 timestamp。
  void _expireOldEntries(ApiVendor vendor) {
    final queue = _callTimestamps[vendor];
    if (queue == null || queue.isEmpty) return;
    final cutoff = _clock.now().subtract(const Duration(hours: 1));
    while (queue.isNotEmpty && queue.first.isBefore(cutoff)) {
      queue.removeFirst();
    }
  }
}
