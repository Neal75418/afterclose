import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/calibration_thresholds.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 規則準確度追蹤服務
///
/// 從 `daily_reason` 直接聚合，計算每條規則的命中率和平均報酬率（unbiased
/// per-rule 統計），寫入 `rule_accuracy` 表供 stock-detail 規則命中率 UI 消費。
/// 支援多持有天數 (1, 3, 5, 10, 20, 60 交易日)。
///
/// **成功判定**：per-period threshold 取代寬鬆的 `>0` 基準，避免「勉強沒虧」
/// 被算成命中。Threshold 來源為 [CalibrationThresholds.successThresholds]，
/// 與 `tool/replay_calibrator.dart` 跟 `tool/recalibrate.dart` 共用同一份
/// 常數，避免不同 writer 用不同門檻寫 rule_accuracy 表造成 calibration
/// 不可重現。
class RuleAccuracyService {
  RuleAccuracyService({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  static const String _tag = 'RuleAccuracyService';

  /// 預設驗證天數
  static const int defaultHoldingDays = 5;

  /// 支援的持有天數（1D/3D 短線 + 5D/10D/20D 中線 + 60D 長線）
  static const List<int> holdingPeriods = [1, 3, 5, 10, 20, 60];

  /// 判定 `returnRate`（%）是否達到 `period` 的命中門檻
  ///
  /// 使用 `>=`（含）而非 `>`（嚴格）— 邊界 case（例如 5D returnRate 剛好 3.0%）
  /// 算命中，對應「門檻就是及格線」的直覺。
  static bool _isSuccessFor(double returnRate, int period) {
    final threshold =
        CalibrationThresholds.successThresholds[period] ??
        CalibrationThresholds.defaultSuccessThreshold;
    return returnRate >= threshold;
  }

  /// 更新規則準確度統計（per-period + 彙總）
  ///
  /// 2026-04 Stage 2 Commit 2：改用 [_computeUnbiasedRuleStats] 從 [daily_reason]
  /// 直接聚合，取代舊的 `primary_rule_id` from `recommendation_validation` 路徑。
  ///
  /// Public contract：`UpdateService` 的 post-update hook 在每次更新後呼叫此
  /// method 重算 `rule_accuracy`。
  Future<void> updateRuleAccuracyStats() async {
    await _computeUnbiasedRuleStats();
  }

  /// 從 `daily_reason` + `daily_price` 聚合 unbiased per-rule 統計寫入 `rule_accuracy`。
  ///
  /// ## 為什麼這樣做（修 Gap 1 primary_rule_id bias）
  ///
  /// 舊實作從 `recommendation_validation` 依 `primary_rule_id` 聚合，只統計每次推薦
  /// 的「最高分那條規則」。後果：常作為 rank 1 / rank 2 的規則（例如 `VOLUME_SPIKE`
  /// 一觸發通常被 `REVERSAL_W2S` 的 35 分壓過）**永遠拿不到樣本**，整個 calibration
  /// 管線變成「強者恆強」的同義複製。
  ///
  /// 新實作直接掃 `daily_reason` — 每個觸發事件都計入，不再受 rank 偏見影響。
  /// 因為 `scoring_service` 會把所有 score ≥ `minScoreThreshold` 股票的 triggered
  /// reasons 寫進 `daily_reason`，這邊的 universe 是「全部被分析到的股票」而非
  /// 「Top 20 推薦」，進一步消除 survivor bias。
  ///
  /// ## Algorithm
  ///
  /// 1. 撈所有 `daily_reason` rows
  /// 2. **Empty guard**：若為空 → warning log 後**不動 `rule_accuracy`** 直接 return
  ///    （防止誤清既有 valid stats — 詳見下方「Empty guard」段落）
  /// 3. 為相關 symbols 建 price lookup map `{symbol: {normalized_date: close}}`
  /// 4. 對每個 reason × 每個 holding period：
  ///    - 查 entry close / exit close（exit date 由 [TaiwanCalendar.addTradingDays] 算）
  ///    - 計算 returnRate + isSuccess（via [_isSuccessFor]）
  ///    - 累加至 `(ruleId, period)` 的 accumulator
  /// 5. 同時累加 `ALL` period（跨所有 periods 合併）
  /// 6. Transaction: 清空舊 `rule_accuracy` 行 → 寫入新統計
  ///
  /// ## Empty guard（2026-04 Stage 2 code review followup）
  ///
  /// 早期版本無論 `daily_reason` 是否為空都先 `delete rule_accuracy` 再檢查。
  /// 問題：若 `daily_reason` 因 syncer 異常暫時空了，會把累積過的 valid 統計
  /// 一併清掉。新版本改為**先 guard 再 delete**，empty 時保留既有 stats 並 log
  /// warning 以便 ops 觀察到資料流異常。
  ///
  /// ## 已知限制
  ///
  /// - Memory footprint：price lookup map 為 `O(symbols × window-of-dates)`。
  ///   window 由 reasons 的 entry-date 範圍 + 最長 holdingPeriod 決定，比早期版本
  ///   的全表掃緊得多。post-launch 累積數年資料時仍應再評估 chunked aggregation。
  /// - 嚴格 date match（無 ±1 日容忍）：trading calendar 精確計算，不需 legacy mitigation。
  Future<void> _computeUnbiasedRuleStats() async {
    final reasons = await _db.select(_db.dailyReason).get();

    // Empty guard: 若沒資料就不動 rule_accuracy，保留既有 valid stats
    if (reasons.isEmpty) {
      AppLogger.warning(
        _tag,
        '_computeUnbiasedRuleStats: daily_reason 為空，保留既有 rule_accuracy '
        '（可能原因：syncer 異常、scoring pipeline 未跑、或 DB 被手動清掉）',
      );
      return;
    }

    // === 在 transaction 之外做讀取與聚合（H3 + M2）===
    //
    // 早期版本把整個 read + accumulate loop 包進 `_db.transaction()` 內，會把
    // 寫鎖時間從毫秒級拉長到秒級，前景 reader 跑大型 query 期間會被 SQLITE_BUSY；
    // 同時 price 查詢無日期下界，會把 daily_price 全表（2000 symbols × N years）
    // 整個拉進 in-memory map，一年後就 OOM。
    //
    // 改寫策略：
    // 1. 從 reasons 算出實際需要的 [minEntryDate, maxExitDate] window
    // 2. 用 date bound 過濾 daily_price — 只撈這次計算實際會用到的行
    // 3. priceMap + ruleStats 都在 transaction 外完成
    // 4. transaction 只做 delete + batch insert（純寫入，秒級內結束）

    final normalizedEntryDates = reasons
        .map((r) => DateContext.normalize(r.date))
        .toList();
    var minEntry = normalizedEntryDates.first;
    var maxEntry = normalizedEntryDates.first;
    for (final d in normalizedEntryDates) {
      if (d.isBefore(minEntry)) minEntry = d;
      if (d.isAfter(maxEntry)) maxEntry = d;
    }
    // holdingPeriods 已知 const sorted ascending；最後一個是最長 holding window，
    // exit-date 邊界由它決定。若未來改成非排序則需 reduce(max)。
    final maxHoldingPeriod = holdingPeriods.last;
    // SQL 比較走 epoch seconds。daily_price.date 在不同 syncer / 測試 fixture
    // 之間可能來自 `DateTime.utc(...)`（UTC 午夜）或 local `DateTime(...)`
    // （Taipei 午夜），兩者在 epoch 上相差約 8h；`DateContext.normalize`
    // 固定回 local 午夜，與 stored UTC 午夜的邊界 row 直接比較會差 8h 而被
    // 誤排除。上下界各加 1 天 buffer 兜底（cover 任意 TZ ±14h 偏移）。
    // in-memory accumulator 仍走 exact-date lookup，buffer 只是多撈幾行，
    // 不會引入錯誤命中。
    const tzBuffer = Duration(days: 1);
    final queryLowerBound = minEntry.subtract(tzBuffer);
    final queryUpperBound = DateContext.normalize(
      TaiwanCalendar.addTradingDays(maxEntry, maxHoldingPeriod),
    ).add(tzBuffer);

    final allSymbols = reasons.map((r) => r.symbol).toSet().toList();
    final priceRows =
        await (_db.select(_db.dailyPrice)..where(
              (t) =>
                  t.symbol.isIn(allSymbols) &
                  t.date.isBiggerOrEqualValue(queryLowerBound) &
                  t.date.isSmallerOrEqualValue(queryUpperBound),
            ))
            .get();

    // 建 price lookup：{symbol: {normalized_date: close}}
    final priceMap = <String, Map<DateTime, double>>{};
    for (final p in priceRows) {
      final close = p.close;
      if (close == null) continue;
      final normalized = DateContext.normalize(p.date);
      priceMap.putIfAbsent(p.symbol, () => {})[normalized] = close;
    }

    // 累加 per-(ruleId, period) 統計
    //
    // ## Known biases（calibration 訓練資料的方法論注意事項）
    //
    // **(1) Lookahead bias**：entry 用當日 close，user 實際只能 T+1 open
    // 進場。TWII 大盤平均 open→close 漂移 ~0.3-0.5%，calibrated hit_rate
    // 系統性高估約這個量級。修法需 daily_price 加 open 欄位 + sync 改抓
    // open price（成本大），目前 docstring 揭露為主、待 Stage 4 處理。
    //
    // **(2) Survivorship bias**：missing exit close 靜默 continue。下市 /
    // 長停的股票永遠在 sample 外，winner 永遠有後續價格。下方 `_BiasCounters`
    // 累計 skippedNoExitPrice 揭露被 silently drop 的比例，calibration
    // reviewer 可用此判斷 hit_rate 是否被 bias inflated。
    //
    // **(3) Co-occurrence inflation**：同 (symbol, date) 多條規則同時觸發
    // 時，**同一個** forward return 被計入每條規則 → Calibrator 的
    // hit_rate × avg_return × √n 三項全被膨脹。`coOccurrenceEvents`
    // 累計多條同時觸發的事件數，metadata `co_occurrence_index =
    // total_reasons / unique_(symbol,date)` 揭露 entanglement 程度。
    final ruleStats = <String, Map<int, _StatsAccumulator>>{};
    final biasCounters = _BiasCounters();

    // 為 co-occurrence index 計算所需：去重 (symbol, date) 與總 reason 數
    final uniqueEntries = <String>{};
    for (final reason in reasons) {
      final entryDate = DateContext.normalize(reason.date);
      uniqueEntries.add('${reason.symbol}@${entryDate.toIso8601String()}');
    }
    biasCounters.totalReasons = reasons.length;
    biasCounters.uniqueEntries = uniqueEntries.length;

    for (final reason in reasons) {
      final symbolPrices = priceMap[reason.symbol];
      if (symbolPrices == null) {
        biasCounters.skippedNoSymbolPrices++;
        continue;
      }

      final entryDate = DateContext.normalize(reason.date);
      final entryClose = symbolPrices[entryDate];
      if (entryClose == null) {
        biasCounters.skippedNoEntryPrice++;
        continue;
      }

      for (final period in holdingPeriods) {
        final exitDate = DateContext.normalize(
          TaiwanCalendar.addTradingDays(entryDate, period),
        );
        final exitClose = symbolPrices[exitDate];
        if (exitClose == null) {
          biasCounters.skippedNoExitPrice++;
          continue;
        }

        final returnRate = ((exitClose - entryClose) / entryClose) * 100;
        final isSuccess = _isSuccessFor(returnRate, period);

        ruleStats
            .putIfAbsent(reason.reasonType, () => <int, _StatsAccumulator>{})
            .putIfAbsent(period, _StatsAccumulator.new)
            .add(returnRate, isSuccess);
      }
    }

    // 一次性 log bias counter 供 reviewer 與 ELK / debug 頁面消費。
    // Survivorship inflated hit_rate 的程度可用 skippedNoExitPrice 比例反推；
    // co_occurrence_index > 1 意味同事件多 rule entanglement，calibration
    // 報告應降權看待單一規則的 hit_rate。
    final coOccurrenceIndex = uniqueEntries.isEmpty
        ? 0.0
        : reasons.length / uniqueEntries.length;
    AppLogger.info(
      'RuleAccuracy',
      'bias_telemetry total_reasons=${biasCounters.totalReasons} '
          'unique_(symbol,date)=${biasCounters.uniqueEntries} '
          'co_occurrence_index=${coOccurrenceIndex.toStringAsFixed(2)} '
          'skipped_no_symbol_prices=${biasCounters.skippedNoSymbolPrices} '
          'skipped_no_entry_price=${biasCounters.skippedNoEntryPrice} '
          'skipped_no_exit_price=${biasCounters.skippedNoExitPrice}',
    );

    // === Transaction：只做 delete + per-row upsert ===
    //
    // 寫入仍走 `insertOnConflictUpdate` loop（如原本 Stage 2 寫法）— drift 的
    // `_db.batch` 嵌進 `_db.transaction` 後行為不對等（Batch 自己會嘗試開
    // transaction），會吞掉新行；改用 loop await 維持原語意。資料量小（< 100
    // rows = ~60 rules × ≤ 6 periods），lock 時間在毫秒級。
    await _db.transaction(() async {
      await _db.delete(_db.ruleAccuracy).go();
      for (final ruleEntry in ruleStats.entries) {
        final ruleId = ruleEntry.key;
        for (final periodEntry in ruleEntry.value.entries) {
          final period = periodEntry.key;
          final acc = periodEntry.value;
          await _db
              .into(_db.ruleAccuracy)
              .insertOnConflictUpdate(
                RuleAccuracyCompanion.insert(
                  ruleId: ruleId,
                  period: '${period}D',
                  triggerCount: Value(acc.count),
                  successCount: Value(acc.successCount),
                  avgReturn: Value(acc.avgReturnPct),
                ),
              );
        }
      }
    });

    // 'ALL' period 已於 2026-04 移除：跨 holdingPeriods 合併會把 1D（門檻
    // 0%）與 60D（門檻 12%）的 success_count 加總後除以總 trigger_count，
    // 得到一個沒有可解釋意義的 hit_rate（被低門檻樣本拉高）。dual-horizon
    // UI 已 ship，使用者直接查 5D / 60D 兩個 horizon 的命中率即可。
    AppLogger.info(
      _tag,
      '_computeUnbiasedRuleStats: ${ruleStats.length} rules × '
      '${holdingPeriods.length} periods 聚合自 ${reasons.length} reasons '
      '(price window: ${_formatDate(queryLowerBound)}~${_formatDate(queryUpperBound)})',
    );
  }

  /// 取得規則命中率
  ///
  /// [period] 持有天數週期，如 '5D'、'60D'（預設 '5D' — 對齊 short horizon 預設）。
  /// 'ALL' 已於 2026-04 移除（混 threshold 算 hit_rate 數學上沒意義）。
  Future<RuleStats?> getRuleStats(String ruleId, {String? period}) async {
    final result =
        await (_db.select(_db.ruleAccuracy)..where(
              (t) => t.ruleId.equals(ruleId) & t.period.equals(period ?? '5D'),
            ))
            .getSingleOrNull();

    if (result == null) return null;

    final hitRate = result.triggerCount > 0
        ? (result.successCount / result.triggerCount) * 100
        : 0.0;

    return RuleStats(
      ruleId: result.ruleId,
      hitRate: hitRate,
      avgReturn: result.avgReturn,
      triggerCount: result.triggerCount,
    );
  }

  /// 取得規則摘要文字（用於 UI 顯示）
  ///
  /// 例如：「命中率 65%，平均 5 日報酬 +2.3%」
  Future<String?> getRuleSummaryText(
    String ruleId, {
    int holdingDays = defaultHoldingDays,
  }) async {
    final stats = await getRuleStats(ruleId, period: '${holdingDays}D');
    if (stats == null || stats.triggerCount < 5) return null;

    final hitRateStr = stats.hitRate.toStringAsFixed(0);
    final returnSign = stats.avgReturn >= 0 ? '+' : '';
    final returnStr = '$returnSign${stats.avgReturn.toStringAsFixed(1)}%';

    return '命中率 $hitRateStr%，平均 $holdingDays 日報酬 $returnStr';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

/// 規則統計
class RuleStats {
  const RuleStats({
    required this.ruleId,
    required this.hitRate,
    required this.avgReturn,
    required this.triggerCount,
  });

  final String ruleId;
  final double hitRate;
  final double avgReturn;
  final int triggerCount;
}

/// Per-(ruleId, period) 統計累加器
///
/// 用於 [RuleAccuracyService._computeUnbiasedRuleStats] 的 in-memory 聚合階段。
/// [add] 單筆 (returnRate, isSuccess) 累加。
class _StatsAccumulator {
  int count = 0;
  int successCount = 0;
  double _sumReturn = 0.0;

  void add(double returnRate, bool success) {
    count++;
    if (success) successCount++;
    _sumReturn += returnRate;
  }

  double get avgReturnPct => count > 0 ? _sumReturn / count : 0.0;
}

/// Calibration bias telemetry — 累計 [RuleAccuracyService] 的 sampling
/// drop / co-occurrence 指標，供 reviewer 判斷 calibrated 結果的可信度。
///
/// 不影響 calibration 計算本身，純粹是 transparency layer：把以前 silently
/// `continue` 的 sample 漏失與多 rule 共現膨脹數值化出來，避免 hit_rate
/// 被解讀為「真實命中率」時忽略樣本選擇偏誤。
class _BiasCounters {
  /// 樣本來源規則總數（含 co-occurring）
  int totalReasons = 0;

  /// 去重後 (symbol, date) 數量
  ///
  /// `totalReasons / uniqueEntries = co_occurrence_index`，> 1 意味
  /// 同事件多規則 entanglement，per-rule hit_rate 會 share 同一 return。
  int uniqueEntries = 0;

  /// symbol 在 priceMap 中完全缺資料的 reason 數（多為極早期 / 下市股）
  int skippedNoSymbolPrices = 0;

  /// 觸發當日 close 缺資料的 reason 數（多為當日停牌）
  int skippedNoEntryPrice = 0;

  /// 出場日 close 缺資料的 (reason × period) 數
  ///
  /// **Survivorship bias 主要來源**：下市 / 長停股票後續沒價格 → 永遠被
  /// drop，winner 永遠有 exit price。這個計數揭露被靜默剔除的程度。
  int skippedNoExitPrice = 0;
}
