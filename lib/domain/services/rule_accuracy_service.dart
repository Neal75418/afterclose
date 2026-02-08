import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 規則準確度追蹤服務
///
/// 負責回溯驗證過去的推薦，計算每條規則的命中率和平均報酬率。
class RuleAccuracyService {
  RuleAccuracyService({
    required AppDatabase database,
    AppClock clock = const SystemClock(),
  }) : _db = database,
       _clock = clock;

  final AppDatabase _db;
  final AppClock _clock;

  static const String _logTag = 'RuleAccuracy';

  /// 驗證天數（N 日後判定成功/失敗）
  static const int defaultHoldingDays = 5;

  /// 每日收盤後執行：回溯驗證 N 天前的推薦
  ///
  /// [daysAgo] 回溯多少天前的推薦（預設 5 天）
  Future<ValidationResult> validatePastRecommendations({
    int daysAgo = defaultHoldingDays,
  }) async {
    final today = _clock.now();
    final targetDate = DateTime(today.year, today.month, today.day - daysAgo);

    AppLogger.info(_logTag, '開始驗證 ${_formatDate(targetDate)} 的推薦');

    try {
      // 1. 取得目標日期的推薦
      final normalizedDate = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final recommendations = await (_db.select(
        _db.dailyRecommendation,
      )..where((t) => t.date.equals(normalizedDate))).get();

      if (recommendations.isEmpty) {
        AppLogger.debug(_logTag, '${_formatDate(targetDate)} 無推薦資料');
        return ValidationResult(
          date: targetDate,
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
      await _updateRuleAccuracyStats();

      final avgReturn = validated > 0 ? totalReturn / validated : 0.0;

      AppLogger.info(
        _logTag,
        '驗證完成：$validated 筆，成功 $successful 筆，'
        '平均報酬 ${avgReturn.toStringAsFixed(2)}%',
      );

      return ValidationResult(
        date: targetDate,
        validated: validated,
        successful: successful,
        avgReturn: avgReturn,
      );
    } catch (e, stack) {
      AppLogger.error(_logTag, '驗證失敗', e, stack);
      rethrow;
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

      // 取得 N 日後收盤價（允許 ±2 天的誤差以處理假日）
      final exitDate = recommendationDate.add(Duration(days: holdingDays));
      final exitPriceResult =
          await (_db.select(_db.dailyPrice)
                ..where(
                  (t) =>
                      t.symbol.equals(rec.symbol) &
                      t.date.isBetweenValues(
                        exitDate.subtract(const Duration(days: 2)),
                        exitDate.add(const Duration(days: 2)),
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
          .insertOnConflictUpdate(
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
          );

      return _ValidationData(returnRate: returnRate, isSuccess: isSuccess);
    } catch (e) {
      AppLogger.warning(_logTag, '驗證 ${rec.symbol} 失敗', e);
      return null;
    }
  }

  /// 更新規則準確度統計
  Future<void> _updateRuleAccuracyStats() async {
    // 從 RecommendationValidation 表計算每條規則的統計數據
    // 注意：使用 snake_case 欄位名稱以匹配資料庫 schema
    final stats = await _db.customSelect('''
      SELECT
        primary_rule_id AS rule_id,
        COUNT(*) AS trigger_count,
        SUM(CASE WHEN is_success = 1 THEN 1 ELSE 0 END) AS success_count,
        AVG(return_rate) AS avg_return
      FROM recommendation_validation
      WHERE return_rate IS NOT NULL
      GROUP BY primary_rule_id
    ''').get();

    for (final row in stats) {
      final ruleId = row.read<String>('rule_id');
      final triggerCount = row.read<int>('trigger_count');
      final successCount = row.read<int>('success_count');
      final avgReturn = row.read<double>('avg_return');

      // 更新或插入規則準確度記錄
      await _db
          .into(_db.ruleAccuracy)
          .insertOnConflictUpdate(
            RuleAccuracyCompanion.insert(
              ruleId: ruleId,
              period: 'ALL',
              triggerCount: Value(triggerCount),
              successCount: Value(successCount),
              avgReturn: Value(avgReturn),
            ),
          );
    }
  }

  /// 取得規則命中率
  ///
  /// 返回命中率（0-100%）、平均報酬、觸發次數
  Future<RuleStats?> getRuleStats(String ruleId) async {
    final result = await (_db.select(
      _db.ruleAccuracy,
    )..where((t) => t.ruleId.equals(ruleId))).getSingleOrNull();

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
  Future<List<RuleStats>> getAllRuleStats() async {
    final results = await _db.select(_db.ruleAccuracy).get();

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
  /// 例如：「過去 30 天命中率 65%，平均 5 日報酬 +2.3%」
  Future<String?> getRuleSummaryText(String ruleId) async {
    final stats = await getRuleStats(ruleId);
    if (stats == null || stats.triggerCount < 5) return null;

    final hitRateStr = stats.hitRate.toStringAsFixed(0);
    final returnSign = stats.avgReturn >= 0 ? '+' : '';
    final returnStr = '$returnSign${stats.avgReturn.toStringAsFixed(1)}%';

    return '命中率 $hitRateStr%，平均 $defaultHoldingDays 日報酬 $returnStr';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

/// 驗證結果
class ValidationResult {
  const ValidationResult({
    required this.date,
    required this.validated,
    required this.successful,
    required this.avgReturn,
  });

  final DateTime date;
  final int validated;
  final int successful;
  final double avgReturn;

  double get hitRate => validated > 0 ? (successful / validated) * 100 : 0;
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
