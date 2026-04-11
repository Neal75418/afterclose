import 'package:drift/drift.dart';

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
/// **成功判定**（2026-04 Stage 2 改動）：per-period threshold 取代寬鬆的 `>0`
/// 基準，避免「勉強沒虧」被算成命中。Threshold 對照見 [_successThresholds]。
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

  /// 成功判定門檻（per-period，單位 %）— `returnRate` 必須 **≥** 對應值才算命中。
  ///
  /// - **1D / 3D**：無門檻（fallback 至 [_defaultSuccessThreshold]，
  ///   短線雜訊大、要求再嚴也測不出真訊號）
  /// - **5D**：3%（短線要吃到肉的最低標準）
  /// - **10D**：5%（中線合理目標）
  /// - **20D**：8%（中線強勁目標）
  /// - **60D**：12%（長線有明顯價值）
  ///
  /// 動機：舊版 `isSuccess = returnRate > 0` 會把漲 0.1% 也算命中，製造虛假
  /// 的高 hit_rate，污染 Stage 2/4 的 calibration 分數。新門檻讓「命中」對應
  /// 「真的有賺到值得下單的幅度」。
  static const Map<int, double> _successThresholds = {
    5: 3.0,
    10: 5.0,
    20: 8.0,
    60: 12.0,
  };

  /// 未明確設定 threshold 的 period 使用的 fallback（非負即算命中）
  static const double _defaultSuccessThreshold = 0.0;

  /// 判定 `returnRate`（%）是否達到 `period` 的命中門檻
  ///
  /// 使用 `>=`（含）而非 `>`（嚴格）— 邊界 case（例如 5D returnRate 剛好 3.0%）
  /// 算命中，對應「門檻就是及格線」的直覺。
  static bool _isSuccessFor(double returnRate, int period) {
    final threshold = _successThresholds[period] ?? _defaultSuccessThreshold;
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
    final recommendations = await (_db.select(
      _db.dailyRecommendation,
    )..where((t) => t.date.equals(normalizedDate))).get();

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
    final (entryRows, exitRows, reasonRows) = await (
      (_db.select(_db.dailyPrice)..where(
            (t) => t.date.equals(normalizedDate) & t.symbol.isIn(symbols),
          ))
          .get(),
      (_db.select(_db.dailyPrice)
            ..where(
              (t) =>
                  t.symbol.isIn(symbols) &
                  t.date.isBetweenValues(
                    exitDate.subtract(const Duration(days: 1)),
                    exitDate.add(const Duration(days: 1)),
                  ),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get(),
      (_db.select(_db.dailyReason)
            ..where(
              (t) => t.date.equals(normalizedDate) & t.symbol.isIn(symbols),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
          .get(),
    ).wait;

    // 3. 建立查找表
    final entryPriceMap = {for (final p in entryRows) p.symbol: p};
    final exitPriceMap = <String, DailyPriceEntry>{};
    for (final p in exitRows) {
      exitPriceMap.putIfAbsent(p.symbol, () => p); // 已按日期降冪，首筆即最新
    }
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

        // 取得該日推薦
        final recommendations = await (_db.select(
          _db.dailyRecommendation,
        )..where((t) => t.date.equals(date))).get();

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
              exitRows =
                  await (_db.select(_db.dailyPrice)
                        ..where(
                          (t) =>
                              t.symbol.isIn(symbols) &
                              t.date.isBetweenValues(
                                exitDate.subtract(const Duration(days: 1)),
                                exitDate.add(const Duration(days: 1)),
                              ),
                        )
                        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
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
                '失敗 ($errors/50)',
                e,
                stack,
              );
              if (errors > 50) {
                throw Exception(
                  '批次回填累計錯誤超過 50 筆，中止 '
                  '(已處理 ${i + 1}/$totalDates 日期)',
                );
              }
              continue;
            }

            final exitPriceMap = <String, DailyPriceEntry>{};
            for (final p in exitRows) {
              exitPriceMap.putIfAbsent(p.symbol, () => p);
            }

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
                  '失敗 ($errors/50)',
                  e,
                  stack,
                );
                if (errors > 50) {
                  throw Exception(
                    '批次回填累計錯誤超過 50 筆，中止 '
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
        } catch (e) {
          // 非 rate-limit/network 的頂層異常已在內層處理或需傳播
          if (e is Exception && e.toString().contains('批次回填累計錯誤超過 50 筆')) {
            rethrow;
          }
          // 其他未預期的頂層錯誤
          errors++;
          AppLogger.warning(
            _tag,
            '回填日期 ${_formatDate(date)} 非預期錯誤 ($errors/50)',
            e,
          );
          if (errors > 50) {
            throw Exception(
              '批次回填累計錯誤超過 50 筆，中止 '
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
  /// - Memory footprint：price lookup map 為 `O(symbols × dates)`，2 年 2000+ 檔可達
  ///   50–100MB。pre-launch 可接受；post-launch 若 syncer 累積歷史資料需評估 batch 化。
  /// - **Transaction lock hold time**：整個 accumulator loop 都在 `_db.transaction()`
  ///   內跑，大資料集會延長 SQLite write-lock 時間，可能阻塞 UI 的 read path。
  ///   Stage 5 batch 化時應將 compute-outside / write-inside 拆開。
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

    await _db.transaction(() async {
      // daily_reason 有資料才清舊統計並重算
      await _db.delete(_db.ruleAccuracy).go();

      // 建 price lookup：{symbol: {normalized_date: close}}
      final allSymbols = reasons.map((r) => r.symbol).toSet().toList();
      final priceRows = await (_db.select(
        _db.dailyPrice,
      )..where((t) => t.symbol.isIn(allSymbols))).get();

      final priceMap = <String, Map<DateTime, double>>{};
      for (final p in priceRows) {
        final close = p.close;
        if (close == null) continue;
        final normalized = DateContext.normalize(p.date);
        priceMap.putIfAbsent(p.symbol, () => {})[normalized] = close;
      }

      // 累加 per-(ruleId, period) 統計
      final ruleStats = <String, Map<int, _StatsAccumulator>>{};

      for (final reason in reasons) {
        final symbolPrices = priceMap[reason.symbol];
        if (symbolPrices == null) continue;

        final entryDate = DateContext.normalize(reason.date);
        final entryClose = symbolPrices[entryDate];
        if (entryClose == null) continue;

        for (final period in holdingPeriods) {
          final exitDate = DateContext.normalize(
            TaiwanCalendar.addTradingDays(entryDate, period),
          );
          final exitClose = symbolPrices[exitDate];
          if (exitClose == null) continue;

          final returnRate = ((exitClose - entryClose) / entryClose) * 100;
          final isSuccess = _isSuccessFor(returnRate, period);

          ruleStats
              .putIfAbsent(reason.reasonType, () => <int, _StatsAccumulator>{})
              .putIfAbsent(period, _StatsAccumulator.new)
              .add(returnRate, isSuccess);
        }
      }

      // Per-period 寫入
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

      // 彙總 'ALL' period — 跨所有 periods 合併同一 rule 的統計
      final allStats = <String, _StatsAccumulator>{};
      for (final ruleEntry in ruleStats.entries) {
        for (final acc in ruleEntry.value.values) {
          allStats.putIfAbsent(ruleEntry.key, _StatsAccumulator.new).merge(acc);
        }
      }
      for (final entry in allStats.entries) {
        await _db
            .into(_db.ruleAccuracy)
            .insertOnConflictUpdate(
              RuleAccuracyCompanion.insert(
                ruleId: entry.key,
                period: 'ALL',
                triggerCount: Value(entry.value.count),
                successCount: Value(entry.value.successCount),
                avgReturn: Value(entry.value.avgReturnPct),
              ),
            );
      }

      AppLogger.info(
        _tag,
        '_computeUnbiasedRuleStats: ${ruleStats.length} rules × '
        '${holdingPeriods.length} periods + ALL 聚合自 ${reasons.length} reasons',
      );
    });
  }

  /// 取得規則命中率
  ///
  /// [period] 持有天數週期，如 '5D'、'ALL'（預設 'ALL'）
  Future<RuleStats?> getRuleStats(String ruleId, {String? period}) async {
    final result =
        await (_db.select(_db.ruleAccuracy)..where(
              (t) => t.ruleId.equals(ruleId) & t.period.equals(period ?? 'ALL'),
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
  /// [period] 持有天數週期，如 '5D'、'ALL'（預設 'ALL'）
  Future<List<RuleStats>> getAllRuleStats({String? period}) async {
    final results = await (_db.select(
      _db.ruleAccuracy,
    )..where((t) => t.period.equals(period ?? 'ALL'))).get();

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
  /// [period] 持有天數週期，如 '5D'、'ALL'（預設 'ALL'）
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
  /// [period] 持有天數週期，如 '5D'、'ALL'（預設 'ALL'）
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

/// Per-(ruleId, period) 統計累加器
///
/// 用於 [RuleAccuracyService._computeUnbiasedRuleStats] 的 in-memory 聚合階段。
/// 支援兩種合併：
/// - [add]：單筆 (returnRate, isSuccess) 累加
/// - [merge]：兩個 accumulator 合併（用於跨 period 彙總至 ALL）
class _StatsAccumulator {
  int count = 0;
  int successCount = 0;
  double _sumReturn = 0.0;

  void add(double returnRate, bool success) {
    count++;
    if (success) successCount++;
    _sumReturn += returnRate;
  }

  void merge(_StatsAccumulator other) {
    count += other.count;
    successCount += other.successCount;
    _sumReturn += other._sumReturn;
  }

  double get avgReturnPct => count > 0 ? _sumReturn / count : 0.0;
}
