import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/calibration_thresholds.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 規則準確度追蹤服務
///
/// 負責回溯驗證過去的推薦，計算每條規則的命中率和平均報酬率。
/// 支援多持有天數 (1, 3, 5, 10, 20, 60 交易日)。
///
/// **成功判定**：per-period threshold 取代寬鬆的 `>0` 基準，避免「勉強沒虧」
/// 被算成命中。Threshold 來源為 [CalibrationThresholds.successThresholds]，
/// 與 `tool/replay_calibrator.dart` 跟 `tool/recalibrate.dart` 共用同一份
/// 常數，避免不同 writer 用不同門檻寫 rule_accuracy 表造成 calibration
/// 不可重現。
class RuleAccuracyService {
  RuleAccuracyService({
    required AppDatabase database,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _clock = clock;

  final AppDatabase _db;
  final AppClock _clock;

  static const String _tag = 'RuleAccuracyService';
  bool _isBackfilling = false;

  /// 預設驗證天數
  static const int defaultHoldingDays = 5;

  /// 支援的持有天數（1D/3D 短線 + 5D/10D/20D 中線 + 60D 長線）
  static const List<int> holdingPeriods = [1, 3, 5, 10, 20, 60];

  /// 暴露 canonical thresholds 供 test 對 calibration tool 的常數 drift
  /// guardrail 驗證（見 `test/core/constants/calibration_thresholds_test.dart`）。
  /// 不要在 production code 用 — 直接 import [CalibrationThresholds]。
  static const Map<int, double> successThresholds =
      CalibrationThresholds.successThresholds;

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

  /// 驗證所有持有天數的過去推薦
  ///
  /// 對每個持有天數，回溯驗證對應天前的推薦。
  /// 各期間獨立執行，單一期間失敗不影響其他期間。
  Future<List<ValidationResult>>
  validatePastRecommendationsMultiPeriod() async {
    // 讀取與計算並行；寫入統一收攏為一次 batch，避免並行 write lock 競爭
    final futures = holdingPeriods.map((period) async {
      try {
        return await _computeValidation(period);
      } catch (e, stack) {
        AppLogger.warning(_tag, '驗證 ${period}D 失敗，繼續處理其他天數', e, stack);
        return null;
      }
    });

    final settled = await Future.wait(futures);
    final computed = settled.whereType<_ValidationComputed>().toList();

    // 合併所有期間的 inserts，一次寫入
    final allInserts = [for (final c in computed) ...c.inserts];
    if (allInserts.isNotEmpty) {
      await _db.batch((batch) => _applyBatchInserts(batch, allInserts));
    }

    // 所有期間驗證完成後，統一更新一次統計
    await _updateRuleAccuracyStats();

    return computed.map((c) => c.result).toList();
  }

  /// 讀取 + 計算驗證資料，不寫入 DB
  Future<_ValidationComputed> _computeValidation(int daysAgo) async {
    final today = DateContext.normalize(_clock.now());
    final targetDate = TaiwanCalendar.subtractTradingDays(today, daysAgo);
    final normalizedDate = DateContext.normalize(targetDate);

    AppLogger.info(
      _tag,
      '開始驗證 ${_formatDate(targetDate)} 的推薦 (持有 $daysAgo 交易日)',
    );

    // 1. 取得目標日期的推薦
    //
    // Stage 5b 後 daily_recommendation 每天有 short + long 兩組（最多 40
    // rows），同 symbol 同日同 horizon 是 PK；recommendation_validation 表
    // PK 為 (date, symbol, holdingDays) 不含 horizon，若兩組都進來會 PK
    // 衝突 upsert 互蓋。recommendation_performance_screen 的 _periods 也
    // 只列 1D~20D（短線視角），長線推薦的績效另有 UI 規畫，目前不該混入。
    // 因此只取 short horizon 推薦做 validation。
    final recommendations =
        await (_db.select(_db.dailyRecommendation)..where(
              (t) =>
                  t.date.equals(normalizedDate) &
                  t.horizon.equals(Horizon.short.name),
            ))
            .get();

    if (recommendations.isEmpty) {
      AppLogger.debug(_tag, '${_formatDate(targetDate)} 無推薦資料');
      return _ValidationComputed(
        result: ValidationResult(
          date: targetDate,
          holdingDays: daysAgo,
          validated: 0,
          successful: 0,
          avgReturn: 0,
        ),
        inserts: [],
      );
    }

    final symbols = recommendations.map((r) => r.symbol).toList();
    final exitDate = TaiwanCalendar.addTradingDays(normalizedDate, daysAgo);

    // 2. 批次預載：3 次查詢取代 3N 次個別查詢
    //
    // exit price 用 exact-date 查 — `exitDate` 已是 `addTradingDays` 算出
    // 的交易日，多數情況有對應 daily_price 列。先前使用 `±1d window + DESC
    // + putIfAbsent` 會在 `exitDate+1d` 也是交易日時錯抓 T+1 收盤（DESC →
    // putIfAbsent 必先吃較晚日期），讓 1D hold 在計算上變 2D，整條
    // validation 路徑系統性灌水 returnRate。
    // 與 `_computeUnbiasedRuleStats` 的 exact lookup 對齊；exit price 缺資
    // 料的 recommendation 在 step 4 由 `continue` 跳過。
    final (entryRows, exitRows, reasonRows) = await (
      (_db.select(_db.dailyPrice)..where(
            (t) => t.date.equals(normalizedDate) & t.symbol.isIn(symbols),
          ))
          .get(),
      (_db.select(
        _db.dailyPrice,
      )..where((t) => t.symbol.isIn(symbols) & t.date.equals(exitDate))).get(),
      (_db.select(_db.dailyReason)
            ..where(
              (t) => t.date.equals(normalizedDate) & t.symbol.isIn(symbols),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
          .get(),
    ).wait;

    // 3. 建立查找表
    final entryPriceMap = {for (final p in entryRows) p.symbol: p};
    final exitPriceMap = {for (final p in exitRows) p.symbol: p};
    final primaryRuleMap = <String, String>{};
    for (final r in reasonRows) {
      primaryRuleMap.putIfAbsent(
        r.symbol,
        () => r.reasonType,
      ); // 已按 rank 升冪，首筆即主要
    }

    // 4. 計算結果（無 DB 呼叫）
    int validated = 0;
    int successful = 0;
    double totalReturn = 0;
    final pendingInserts = <RecommendationValidationCompanion>[];

    for (final rec in recommendations) {
      final entryPriceRow = entryPriceMap[rec.symbol];
      if (entryPriceRow?.close == null) continue;
      final exitPriceRow = exitPriceMap[rec.symbol];
      if (exitPriceRow?.close == null) continue;

      final entryPrice = entryPriceRow!.close!;
      final exitPrice = exitPriceRow!.close!;
      final returnRate = ((exitPrice - entryPrice) / entryPrice) * 100;
      final isSuccess = _isSuccessFor(returnRate, daysAgo);
      final primaryRule = primaryRuleMap[rec.symbol] ?? 'unknown';

      validated++;
      if (isSuccess) successful++;
      totalReturn += returnRate;

      pendingInserts.add(
        RecommendationValidationCompanion.insert(
          recommendationDate: normalizedDate,
          symbol: rec.symbol,
          primaryRuleId: primaryRule,
          entryPrice: entryPrice,
          exitPrice: Value(exitPrice),
          returnRate: Value(returnRate),
          isSuccess: Value(isSuccess),
          validationDate: Value(exitPriceRow.date),
          holdingDays: Value(daysAgo),
        ),
      );
    }

    final avgReturn = validated > 0 ? totalReturn / validated : 0.0;

    AppLogger.info(
      _tag,
      '驗證完成 (${daysAgo}D)：$validated 筆，成功 $successful 筆，'
      '平均報酬 ${avgReturn.toStringAsFixed(2)}%',
    );

    return _ValidationComputed(
      result: ValidationResult(
        date: targetDate,
        holdingDays: daysAgo,
        validated: validated,
        successful: successful,
        avgReturn: avgReturn,
      ),
      inserts: pendingInserts,
    );
  }

  /// 將 companions 套用至 Drift batch（upsert 語義）
  void _applyBatchInserts(
    Batch batch,
    List<RecommendationValidationCompanion> companions,
  ) {
    for (final companion in companions) {
      batch.insert(
        _db.recommendationValidation,
        companion,
        onConflict: DoUpdate(
          (old) => RecommendationValidationCompanion(
            primaryRuleId: companion.primaryRuleId,
            entryPrice: companion.entryPrice,
            exitPrice: companion.exitPrice,
            returnRate: companion.returnRate,
            isSuccess: companion.isSuccess,
            validationDate: companion.validationDate,
          ),
          target: [
            _db.recommendationValidation.recommendationDate,
            _db.recommendationValidation.symbol,
            _db.recommendationValidation.holdingDays,
          ],
        ),
      );
    }
  }

  /// 批次回填所有歷史推薦的驗證結果
  ///
  /// 遍歷 DailyRecommendation 表中所有歷史推薦日期，
  /// 針對每個持有天數驗證並寫入 RecommendationValidation。
  /// [onProgress] 回報進度 (current, total)。
  Future<BackfillResult> backfillAllHistoricalRecommendations({
    void Function(int current, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (_isBackfilling) {
      AppLogger.warning(_tag, '回填已在執行中，跳過重複請求');
      return const BackfillResult(validated: 0, skipped: 0, totalDates: 0);
    }

    _isBackfilling = true;
    AppLogger.info(_tag, '開始批次回填歷史推薦驗證');

    try {
      // 1. 取得所有不重複的推薦日期
      final dates = await _db.customSelect('''
        SELECT DISTINCT date FROM daily_recommendation ORDER BY date ASC
      ''').get();

      final totalDates = dates.length;
      var validated = 0;
      var skipped = 0;
      var errors = 0;

      // 按日期批次查詢，避免 N×M×5 round-trips
      for (var i = 0; i < totalDates; i++) {
        if (isCancelled?.call() == true) break;

        final date = dates[i].read<DateTime>('date');

        // 取得該日推薦（同 _computeValidation：只看 short horizon，避免 PK
        // 衝突 + 對齊 recommendation_performance_screen 的短線視角）
        final recommendations =
            await (_db.select(_db.dailyRecommendation)..where(
                  (t) =>
                      t.date.equals(date) &
                      t.horizon.equals(Horizon.short.name),
                ))
                .get();

        if (recommendations.isEmpty) {
          onProgress?.call(i + 1, totalDates);
          continue;
        }

        final symbols = recommendations.map((r) => r.symbol).toList();

        try {
          // 批次取得 entry prices 和 reasons（2 次查詢取代 2N 次）
          final (entryRows, reasonRows) = await (
            (_db.select(_db.dailyPrice)
                  ..where((t) => t.date.equals(date) & t.symbol.isIn(symbols)))
                .get(),
            (_db.select(_db.dailyReason)
                  ..where((t) => t.date.equals(date) & t.symbol.isIn(symbols))
                  ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
                .get(),
          ).wait;

          final entryPriceMap = {for (final p in entryRows) p.symbol: p};
          final primaryRuleMap = <String, String>{};
          for (final r in reasonRows) {
            primaryRuleMap.putIfAbsent(r.symbol, () => r.reasonType);
          }

          // 針對每個持有天數，批次取得 exit prices（每期 1 次查詢）
          for (final period in holdingPeriods) {
            final exitDate = TaiwanCalendar.addTradingDays(date, period);

            List<DailyPriceEntry> exitRows;
            try {
              // exact-date lookup（與 `_computeValidation` 對齊，見該方法
              // 的 step 2 註解；先前的 ±1d window 會錯抓 T+1 收盤）
              exitRows =
                  await (_db.select(_db.dailyPrice)..where(
                        (t) => t.symbol.isIn(symbols) & t.date.equals(exitDate),
                      ))
                      .get();
            } on RateLimitException {
              rethrow;
            } on NetworkException {
              rethrow;
            } catch (e, stack) {
              errors++;
              AppLogger.warning(
                _tag,
                '回填批次取得 exit prices (${_formatDate(date)}, ${period}D) '
                '失敗 ($errors/$_kBackfillErrorLimit)',
                e,
                stack,
              );
              if (errors > _kBackfillErrorLimit) {
                throw _BackfillAbortException(
                  '批次回填累計錯誤超過 $_kBackfillErrorLimit 筆，中止 '
                  '(已處理 ${i + 1}/$totalDates 日期)',
                );
              }
              continue;
            }

            final exitPriceMap = {for (final p in exitRows) p.symbol: p};

            // 從預載資料計算結果，無額外 DB 查詢
            final pendingInserts = <RecommendationValidationCompanion>[];
            for (final rec in recommendations) {
              try {
                final entryPriceRow = entryPriceMap[rec.symbol];
                if (entryPriceRow?.close == null) {
                  skipped++;
                  continue;
                }
                final exitPriceRow = exitPriceMap[rec.symbol];
                if (exitPriceRow?.close == null) {
                  skipped++;
                  continue;
                }

                final entryPrice = entryPriceRow!.close!;
                final exitPrice = exitPriceRow!.close!;
                final returnRate =
                    ((exitPrice - entryPrice) / entryPrice) * 100;
                final isSuccess = _isSuccessFor(returnRate, period);
                final primaryRule = primaryRuleMap[rec.symbol] ?? 'unknown';

                pendingInserts.add(
                  RecommendationValidationCompanion.insert(
                    recommendationDate: date,
                    symbol: rec.symbol,
                    primaryRuleId: primaryRule,
                    entryPrice: entryPrice,
                    exitPrice: Value(exitPrice),
                    returnRate: Value(returnRate),
                    isSuccess: Value(isSuccess),
                    validationDate: Value(exitPriceRow.date),
                    holdingDays: Value(period),
                  ),
                );
                validated++;
              } catch (e, stack) {
                errors++;
                AppLogger.warning(
                  _tag,
                  '回填驗證 ${rec.symbol} (${_formatDate(date)}, ${period}D) '
                  '失敗 ($errors/$_kBackfillErrorLimit)',
                  e,
                  stack,
                );
                if (errors > _kBackfillErrorLimit) {
                  throw _BackfillAbortException(
                    '批次回填累計錯誤超過 $_kBackfillErrorLimit 筆，中止 '
                    '(已處理 ${i + 1}/$totalDates 日期)',
                  );
                }
              }
            }

            // 批次寫入該期間的驗證結果
            if (pendingInserts.isNotEmpty) {
              await _db.batch(
                (batch) => _applyBatchInserts(batch, pendingInserts),
              );
            }
          }
        } on RateLimitException {
          rethrow;
        } on NetworkException {
          rethrow;
        } on _BackfillAbortException {
          // inner catch 拋出的 abort sentinel — 直接 rethrow，不要當未預期錯誤計
          rethrow;
        } catch (e) {
          // 其他未預期的頂層錯誤
          errors++;
          AppLogger.warning(
            _tag,
            '回填日期 ${_formatDate(date)} 非預期錯誤 ($errors/$_kBackfillErrorLimit)',
            e,
          );
          if (errors > _kBackfillErrorLimit) {
            throw _BackfillAbortException(
              '批次回填累計錯誤超過 $_kBackfillErrorLimit 筆，中止 '
              '(已處理 ${i + 1}/$totalDates 日期)',
            );
          }
        }

        onProgress?.call(i + 1, totalDates);
      }

      // 更新所有規則統計
      await _updateRuleAccuracyStats();

      AppLogger.info(_tag, '批次回填完成：驗證 $validated 筆，跳過 $skipped 筆，錯誤 $errors 筆');
      return BackfillResult(
        validated: validated,
        skipped: skipped,
        totalDates: totalDates,
        errors: errors,
      );
    } catch (e, stack) {
      AppLogger.error(_tag, '批次回填失敗', e, stack);
      rethrow;
    } finally {
      _isBackfilling = false;
    }
  }

  /// 更新規則準確度統計（per-period + 彙總）
  ///
  /// 2026-04 Stage 2 Commit 2：改用 [_computeUnbiasedRuleStats] 從 [daily_reason]
  /// 直接聚合，取代舊的 `primary_rule_id` from `recommendation_validation` 路徑。
  ///
  /// Public contract 保留此 method 名稱，`UpdateService` 的 post-update hook 與
  /// 其他 caller 不需改動。
  Future<void> _updateRuleAccuracyStats() async {
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

  /// 取得所有規則的準確度統計
  ///
  /// [period] 持有天數週期，如 '5D'、'60D'（預設 '5D'）。'ALL' 已移除。
  Future<List<RuleStats>> getAllRuleStats({String? period}) async {
    final results = await (_db.select(
      _db.ruleAccuracy,
    )..where((t) => t.period.equals(period ?? '5D'))).get();

    return results.map((r) {
      final hitRate = r.triggerCount > 0
          ? (r.successCount / r.triggerCount) * 100
          : 0.0;

      return RuleStats(
        ruleId: r.ruleId,
        hitRate: hitRate,
        avgReturn: r.avgReturn,
        triggerCount: r.triggerCount,
      );
    }).toList();
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

  /// 取得個股驗證記錄（用於 stock-centric UI）
  ///
  /// [period] 持有天數週期，如 '5D'、'ALL'（預設 'ALL'）。
  /// 此處的 'ALL' 走 [recommendation_validation] 表的 holdingDays 過濾
  /// （單一 threshold，不混算），與 rule_accuracy 表已移除的 'ALL' 是
  /// 不同 concept，保留有效。
  /// [limit] 最多回傳筆數（預設 200）
  Future<List<StockValidationRecord>> getStockValidationRecords({
    String? period,
    int limit = 200,
  }) async {
    final query = _db.select(_db.recommendationValidation)
      ..orderBy([
        (t) => OrderingTerm.desc(t.recommendationDate),
        (t) => OrderingTerm.desc(t.returnRate),
      ])
      ..limit(limit);

    // 依 period 過濾 holdingDays
    // ALL 模式使用預設 5D，避免同一支股票同一天出現 5 筆記錄
    final holdingDays = _parsePeriod(period) ?? defaultHoldingDays;
    query.where((t) => t.holdingDays.equals(holdingDays));

    final results = await query.get();

    // 批次查詢股票名稱
    final symbols = results.map((r) => r.symbol).toSet().toList();
    final stockMap = await _db.getStocksBatch(symbols);

    return results.map((r) {
      final stock = stockMap[r.symbol];
      return StockValidationRecord(
        symbol: r.symbol,
        stockName: stock?.name ?? r.symbol,
        recommendationDate: r.recommendationDate,
        validationDate: r.validationDate,
        primaryRuleId: r.primaryRuleId,
        entryPrice: r.entryPrice,
        exitPrice: r.exitPrice,
        returnRate: r.returnRate,
        isSuccess: r.isSuccess,
        holdingDays: r.holdingDays,
      );
    }).toList();
  }

  /// 取得整體績效統計（聚合查詢）
  ///
  /// [period] 持有天數週期，如 '5D'、'ALL'（預設 'ALL'）。
  /// 此處的 'ALL' 對 recommendation_validation 表全 holdingDays 聚合，
  /// 跟 rule_accuracy 表已移除的 'ALL' 是不同 concept。
  Future<OverallPerformanceStats> getOverallPerformanceStats({
    String? period,
  }) async {
    final holdingDays = _parsePeriod(period);
    final whereClause = holdingDays != null
        ? 'WHERE return_rate IS NOT NULL AND holding_days = ?'
        : 'WHERE return_rate IS NOT NULL';
    final variables = holdingDays != null
        ? [Variable.withInt(holdingDays)]
        : <Variable>[];

    final result = await _db.customSelect('''
      SELECT
        COUNT(*) AS total_count,
        COALESCE(SUM(CASE WHEN is_success = 1 THEN 1 ELSE 0 END), 0) AS success_count,
        COALESCE(AVG(return_rate), 0) AS avg_return
      FROM recommendation_validation
      $whereClause
    ''', variables: variables).getSingle();

    return OverallPerformanceStats(
      totalCount: result.read<int>('total_count'),
      successCount: result.read<int>('success_count'),
      avgReturn: result.read<double>('avg_return'),
    );
  }

  /// 解析 period 字串為 holdingDays（'5D' → 5, 'ALL' → null）
  static int? _parsePeriod(String? period) {
    if (period == null || period == 'ALL') return null;
    return int.tryParse(period.replaceAll('D', ''));
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

/// 驗證結果
class ValidationResult {
  const ValidationResult({
    required this.date,
    required this.holdingDays,
    required this.validated,
    required this.successful,
    required this.avgReturn,
  });

  final DateTime date;
  final int holdingDays;
  final int validated;
  final int successful;
  final double avgReturn;

  double get hitRate => validated > 0 ? (successful / validated) * 100 : 0;
}

/// 批次回填結果
class BackfillResult {
  const BackfillResult({
    required this.validated,
    required this.skipped,
    required this.totalDates,
    this.errors = 0,
  });

  final int validated;
  final int skipped;
  final int totalDates;
  final int errors;
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

/// 個股驗證記錄（用於 UI 顯示）
class StockValidationRecord {
  const StockValidationRecord({
    required this.symbol,
    required this.stockName,
    required this.recommendationDate,
    this.validationDate,
    required this.primaryRuleId,
    required this.entryPrice,
    this.exitPrice,
    this.returnRate,
    this.isSuccess,
    required this.holdingDays,
  });

  final String symbol;
  final String stockName;
  final DateTime recommendationDate;
  final DateTime? validationDate;
  final String primaryRuleId;
  final double entryPrice;
  final double? exitPrice;
  final double? returnRate;
  final bool? isSuccess;
  final int holdingDays;
}

/// 整體績效統計（聚合）
class OverallPerformanceStats {
  const OverallPerformanceStats({
    required this.totalCount,
    required this.successCount,
    required this.avgReturn,
  });

  final int totalCount;
  final int successCount;
  final double avgReturn;

  double get winRate => totalCount > 0 ? (successCount / totalCount) * 100 : 0;
}

/// 驗證計算結果（讀取 + 計算階段產出，尚未寫入 DB）
class _ValidationComputed {
  const _ValidationComputed({required this.result, required this.inserts});

  final ValidationResult result;
  final List<RecommendationValidationCompanion> inserts;
}

/// 回填累計錯誤超過上限後拋出的內部控制流例外
///
/// 用於 [RuleAccuracyService.backfillAllHistoricalRecommendations]：當錯誤累積
/// 超過 [_kBackfillErrorLimit] 時，inner catch 拋出此例外讓 outer catch 用
/// `on _BackfillAbortException` 直接 rethrow，不需要靠 `e.toString().contains`
/// 字串比對識別控制流意圖（脆弱、易與真實錯誤訊息巧合）。
class _BackfillAbortException implements Exception {
  const _BackfillAbortException(this.message);

  final String message;

  @override
  String toString() => '_BackfillAbortException: $message';
}

/// 回填過程中的累積錯誤上限。超過則中止整個 backfill 操作。
const int _kBackfillErrorLimit = 50;

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
