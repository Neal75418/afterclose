import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 規則準確度追蹤服務
///
/// 負責回溯驗證過去的推薦，計算每條規則的命中率和平均報酬率。
/// 支援多持有天數 (1, 3, 5, 10, 20 交易日)。
class RuleAccuracyService {
  RuleAccuracyService({
    required AppDatabase database,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _clock = clock;

  final AppDatabase _db;
  final AppClock _clock;

  static const String _logTag = 'RuleAccuracy';
  bool _isBackfilling = false;

  /// 預設驗證天數
  static const int defaultHoldingDays = 5;

  /// 支援的持有天數
  static const List<int> holdingPeriods = [1, 3, 5, 10, 20];

  /// 驗證所有持有天數的過去推薦
  ///
  /// 對每個持有天數，回溯驗證對應天前的推薦。
  /// 各期間獨立執行，單一期間失敗不影響其他期間。
  Future<List<ValidationResult>>
  validatePastRecommendationsMultiPeriod() async {
    final results = <ValidationResult>[];
    for (final period in holdingPeriods) {
      try {
        final result = await validatePastRecommendations(
          daysAgo: period,
          updateStats: false,
        );
        results.add(result);
      } catch (e, stack) {
        AppLogger.warning(_logTag, '驗證 ${period}D 失敗，繼續處理其他天數', e, stack);
      }
    }

    // 所有期間驗證完成後，統一更新一次統計
    await _updateRuleAccuracyStats();

    return results;
  }

  /// 每日收盤後執行：回溯驗證 N 個交易日前的推薦
  ///
  /// [daysAgo] 回溯多少個交易日前的推薦（預設 5 個交易日）
  Future<ValidationResult> validatePastRecommendations({
    int daysAgo = defaultHoldingDays,
    bool updateStats = true,
  }) async {
    final today = DateContext.normalize(_clock.now());
    final targetDate = TaiwanCalendar.subtractTradingDays(today, daysAgo);

    AppLogger.info(
      _logTag,
      '開始驗證 ${_formatDate(targetDate)} 的推薦 (持有 $daysAgo 交易日)',
    );

    try {
      // 1. 取得目標日期的推薦
      final normalizedDate = DateContext.normalize(targetDate);
      final recommendations = await (_db.select(
        _db.dailyRecommendation,
      )..where((t) => t.date.equals(normalizedDate))).get();

      if (recommendations.isEmpty) {
        AppLogger.debug(_logTag, '${_formatDate(targetDate)} 無推薦資料');
        return ValidationResult(
          date: targetDate,
          holdingDays: daysAgo,
          validated: 0,
          successful: 0,
          avgReturn: 0,
        );
      }

      int validated = 0;
      int successful = 0;
      double totalReturn = 0;

      // 2. 逐一驗證每個推薦
      for (final rec in recommendations) {
        final result = await _validateSingleRecommendation(
          rec,
          normalizedDate,
          daysAgo,
        );

        if (result != null) {
          validated++;
          if (result.isSuccess) successful++;
          totalReturn += result.returnRate;
        }
      }

      // 3. 更新規則準確度統計
      if (updateStats) {
        await _updateRuleAccuracyStats();
      }

      final avgReturn = validated > 0 ? totalReturn / validated : 0.0;

      AppLogger.info(
        _logTag,
        '驗證完成 (${daysAgo}D)：$validated 筆，成功 $successful 筆，'
        '平均報酬 ${avgReturn.toStringAsFixed(2)}%',
      );

      return ValidationResult(
        date: targetDate,
        holdingDays: daysAgo,
        validated: validated,
        successful: successful,
        avgReturn: avgReturn,
      );
    } catch (e, stack) {
      AppLogger.error(_logTag, '驗證失敗', e, stack);
      rethrow;
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
      AppLogger.warning(_logTag, '回填已在執行中，跳過重複請求');
      return const BackfillResult(validated: 0, skipped: 0, totalDates: 0);
    }

    _isBackfilling = true;
    AppLogger.info(_logTag, '開始批次回填歷史推薦驗證');

    try {
      // 1. 取得所有不重複的推薦日期
      final dates = await _db.customSelect('''
        SELECT DISTINCT date FROM daily_recommendation ORDER BY date ASC
      ''').get();

      final totalDates = dates.length;
      var validated = 0;
      var skipped = 0;
      var errors = 0;

      for (var i = 0; i < totalDates; i++) {
        if (isCancelled?.call() == true) break;

        final date = dates[i].read<DateTime>('date');

        // 取得該日推薦
        final recommendations = await (_db.select(
          _db.dailyRecommendation,
        )..where((t) => t.date.equals(date))).get();

        // 針對每個持有天數驗證
        for (final period in holdingPeriods) {
          for (final rec in recommendations) {
            try {
              final result = await _validateSingleRecommendation(
                rec,
                date,
                period,
              );
              if (result != null) {
                validated++;
              } else {
                skipped++;
              }
            } catch (e, stack) {
              errors++;
              AppLogger.warning(
                _logTag,
                '回填驗證 ${rec.symbol} (${_formatDate(date)}, ${period}D) '
                '失敗 ($errors/50)',
                e,
                stack,
              );
              // 單筆驗證失敗不中斷整體回填，但累計過多則放棄
              if (errors > 50) {
                throw Exception(
                  '批次回填累計錯誤超過 50 筆，中止 '
                  '(已處理 ${i + 1}/$totalDates 日期)',
                );
              }
            }
          }
        }

        onProgress?.call(i + 1, totalDates);
      }

      // 更新所有規則統計
      await _updateRuleAccuracyStats();

      AppLogger.info(
        _logTag,
        '批次回填完成：驗證 $validated 筆，跳過 $skipped 筆，錯誤 $errors 筆',
      );
      return BackfillResult(
        validated: validated,
        skipped: skipped,
        totalDates: totalDates,
        errors: errors,
      );
    } catch (e, stack) {
      AppLogger.error(_logTag, '批次回填失敗', e, stack);
      rethrow;
    } finally {
      _isBackfilling = false;
    }
  }

  /// 驗證單一推薦
  Future<_ValidationData?> _validateSingleRecommendation(
    DailyRecommendationEntry rec,
    DateTime recommendationDate,
    int holdingDays,
  ) async {
    try {
      // 取得推薦日收盤價
      final entryPriceResult =
          await (_db.select(_db.dailyPrice)..where(
                (t) =>
                    t.symbol.equals(rec.symbol) &
                    t.date.equals(recommendationDate),
              ))
              .getSingleOrNull();
      if (entryPriceResult?.close == null) return null;
      final entryPrice = entryPriceResult!.close!;

      // 取得 N 個交易日後收盤價（使用交易日計算）
      final exitDate = TaiwanCalendar.addTradingDays(
        recommendationDate,
        holdingDays,
      );
      // 允許 ±1 天的誤差以處理邊界情況
      final exitPriceResult =
          await (_db.select(_db.dailyPrice)
                ..where(
                  (t) =>
                      t.symbol.equals(rec.symbol) &
                      t.date.isBetweenValues(
                        exitDate.subtract(const Duration(days: 1)),
                        exitDate.add(const Duration(days: 1)),
                      ),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.date)])
                ..limit(1))
              .getSingleOrNull();
      if (exitPriceResult?.close == null) return null;
      final exitPrice = exitPriceResult!.close!;

      // 計算報酬率
      final returnRate = ((exitPrice - entryPrice) / entryPrice) * 100;
      final isSuccess = returnRate > 0;

      // 取得主要觸發規則
      final reasonResult =
          await (_db.select(_db.dailyReason)
                ..where(
                  (t) =>
                      t.symbol.equals(rec.symbol) &
                      t.date.equals(recommendationDate),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.rank)])
                ..limit(1))
              .getSingleOrNull();
      final primaryRule = reasonResult?.reasonType ?? 'unknown';

      // 儲存驗證結果（upsert：同日同檔同持有天數覆寫舊結果）
      await _db
          .into(_db.recommendationValidation)
          .insert(
            RecommendationValidationCompanion.insert(
              recommendationDate: recommendationDate,
              symbol: rec.symbol,
              primaryRuleId: primaryRule,
              entryPrice: entryPrice,
              exitPrice: Value(exitPrice),
              returnRate: Value(returnRate),
              isSuccess: Value(isSuccess),
              validationDate: Value(exitPriceResult.date),
              holdingDays: Value(holdingDays),
            ),
            onConflict: DoUpdate(
              (old) => RecommendationValidationCompanion(
                primaryRuleId: Value(primaryRule),
                entryPrice: Value(entryPrice),
                exitPrice: Value(exitPrice),
                returnRate: Value(returnRate),
                isSuccess: Value(isSuccess),
                validationDate: Value(exitPriceResult.date),
              ),
              target: [
                _db.recommendationValidation.recommendationDate,
                _db.recommendationValidation.symbol,
                _db.recommendationValidation.holdingDays,
              ],
            ),
          );

      return _ValidationData(returnRate: returnRate, isSuccess: isSuccess);
    } on StateError catch (e) {
      // 預期的錯誤：查無資料（getSingleOrNull 回傳結構問題等）
      AppLogger.debug(_logTag, '驗證 ${rec.symbol} 資料不足: $e');
      return null;
    } catch (e, stack) {
      // 非預期錯誤：DB 異常、序列化失敗等，應傳播
      AppLogger.error(_logTag, '驗證 ${rec.symbol} 非預期錯誤', e, stack);
      rethrow;
    }
  }

  /// 更新規則準確度統計（per-period + 彙總）
  ///
  /// 使用 transaction 確保所有期間的統計一致寫入。
  Future<void> _updateRuleAccuracyStats() async {
    await _db.transaction(() async {
      // Per-period 統計
      for (final period in holdingPeriods) {
        final stats = await _db
            .customSelect(
              '''
          SELECT
            primary_rule_id AS rule_id,
            COUNT(*) AS trigger_count,
            SUM(CASE WHEN is_success = 1 THEN 1 ELSE 0 END) AS success_count,
            AVG(return_rate) AS avg_return
          FROM recommendation_validation
          WHERE return_rate IS NOT NULL AND holding_days = ?
          GROUP BY primary_rule_id
        ''',
              variables: [Variable.withInt(period)],
            )
            .get();

        for (final row in stats) {
          await _db
              .into(_db.ruleAccuracy)
              .insertOnConflictUpdate(
                RuleAccuracyCompanion.insert(
                  ruleId: row.read<String>('rule_id'),
                  period: '${period}D',
                  triggerCount: Value(row.read<int>('trigger_count')),
                  successCount: Value(row.read<int>('success_count')),
                  avgReturn: Value(row.read<double>('avg_return')),
                ),
              );
        }
      }

      // 彙總統計 (ALL)
      final overallStats = await _db.customSelect('''
        SELECT
          primary_rule_id AS rule_id,
          COUNT(*) AS trigger_count,
          SUM(CASE WHEN is_success = 1 THEN 1 ELSE 0 END) AS success_count,
          AVG(return_rate) AS avg_return
        FROM recommendation_validation
        WHERE return_rate IS NOT NULL
        GROUP BY primary_rule_id
      ''').get();

      for (final row in overallStats) {
        await _db
            .into(_db.ruleAccuracy)
            .insertOnConflictUpdate(
              RuleAccuracyCompanion.insert(
                ruleId: row.read<String>('rule_id'),
                period: 'ALL',
                triggerCount: Value(row.read<int>('trigger_count')),
                successCount: Value(row.read<int>('success_count')),
                avgReturn: Value(row.read<double>('avg_return')),
              ),
            );
      }
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

class _ValidationData {
  const _ValidationData({required this.returnRate, required this.isSuccess});

  final double returnRate;
  final bool isSuccess;
}
