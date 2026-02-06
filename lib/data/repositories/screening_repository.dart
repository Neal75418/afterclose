import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/domain/repositories/screening_repository.dart';

/// IScreeningRepository 的 Drift 資料庫實作
class ScreeningRepository implements IScreeningRepository {
  const ScreeningRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  @override
  Future<({List<String> symbols, int totalScanned})> executeSqlFilter(
    List<ScreeningCondition> conditions,
    DateTime targetDate,
  ) async {
    final startOfDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // 建構動態 SQL
    final cteVars = <Object>[];
    final joinVars = <Object>[];
    final whereVars = <Object>[];
    final joins = StringBuffer();
    final wheres = StringBuffer();

    // 計算哪些表需要 JOIN
    final needsPrice = conditions.any(
      (c) =>
          c.field == ScreeningField.close ||
          c.field == ScreeningField.volume ||
          c.field == ScreeningField.priceChangePercent,
    );
    final needsValuation = conditions.any(
      (c) =>
          c.field == ScreeningField.pe ||
          c.field == ScreeningField.pbr ||
          c.field == ScreeningField.dividendYield,
    );
    final needsRevenue = conditions.any(
      (c) =>
          c.field == ScreeningField.revenueYoyGrowth ||
          c.field == ScreeningField.revenueMomGrowth,
    );

    // CTE（必須放在最前面）
    String ctePrefix = '';
    if (conditions.any((c) => c.field == ScreeningField.priceChangePercent)) {
      final prevDateMs =
          startOfDay
              .subtract(const Duration(days: 10))
              .millisecondsSinceEpoch ~/
          1000;
      ctePrefix = '''
        WITH prev_price AS (
          SELECT dp2.symbol, dp2.close as prev_close
          FROM daily_price dp2
          INNER JOIN (
            SELECT symbol, MAX(date) as prev_date
            FROM daily_price
            WHERE date < ? AND close IS NOT NULL
            GROUP BY symbol
          ) latest ON dp2.symbol = latest.symbol AND dp2.date = latest.prev_date
          WHERE dp2.date >= ?
        )
      ''';
      cteVars.addAll([startOfDay.millisecondsSinceEpoch ~/ 1000, prevDateMs]);

      joins.write('''
        LEFT JOIN prev_price pp ON pp.symbol = da.symbol
      ''');
    }

    if (needsPrice) {
      joins.write('''
        LEFT JOIN daily_price dp
          ON da.symbol = dp.symbol
          AND dp.date >= ? AND dp.date < ?
      ''');
      joinVars.addAll([
        startOfDay.millisecondsSinceEpoch ~/ 1000,
        endOfDay.millisecondsSinceEpoch ~/ 1000,
      ]);
    }

    if (needsValuation) {
      final valuationStart = startOfDay.subtract(const Duration(days: 7));
      joins.write('''
        LEFT JOIN stock_valuation sv
          ON sv.symbol = da.symbol
          AND sv.date = (
            SELECT MAX(sv2.date) FROM stock_valuation sv2
            WHERE sv2.symbol = da.symbol
            AND sv2.date >= ? AND sv2.date < ?
          )
      ''');
      joinVars.addAll([
        valuationStart.millisecondsSinceEpoch ~/ 1000,
        endOfDay.millisecondsSinceEpoch ~/ 1000,
      ]);
    }

    if (needsRevenue) {
      joins.write('''
        LEFT JOIN monthly_revenue mr
          ON mr.symbol = da.symbol
          AND mr.date = (
            SELECT MAX(mr2.date) FROM monthly_revenue mr2
            WHERE mr2.symbol = da.symbol
          )
      ''');
    }

    // 建構 WHERE 條件子句
    for (final c in conditions) {
      final clause = _buildWhereClause(c, whereVars);
      if (clause != null) {
        wheres.write(' AND $clause');
      }
    }

    // 先取總數（不含篩選條件）
    const countQuery = '''
      SELECT COUNT(*) as cnt
      FROM daily_analysis da
      WHERE da.date >= ? AND da.date < ? AND da.score > 0
    ''';
    final countResult = await _db
        .customSelect(
          countQuery,
          variables: [
            Variable<int>(startOfDay.millisecondsSinceEpoch ~/ 1000),
            Variable<int>(endOfDay.millisecondsSinceEpoch ~/ 1000),
          ],
        )
        .get();
    final totalScanned = countResult.firstOrNull?.read<int>('cnt') ?? 0;

    // 組合完整查詢
    final query =
        '''
      $ctePrefix
      SELECT DISTINCT da.symbol, da.score
      FROM daily_analysis da
      $joins
      WHERE da.date >= ? AND da.date < ? AND da.score > 0
      $wheres
      ORDER BY da.score DESC
    ''';

    // 按 SQL 佔位符順序組合所有參數
    final allVars = <Object>[
      ...cteVars,
      ...joinVars,
      startOfDay.millisecondsSinceEpoch ~/ 1000,
      endOfDay.millisecondsSinceEpoch ~/ 1000,
      ...whereVars,
    ];

    final driftVars = allVars.map((v) {
      if (v is int) return Variable<int>(v);
      if (v is double) return Variable<double>(v);
      if (v is String) return Variable<String>(v);
      return Variable<int>(v as int);
    }).toList();

    try {
      final rows = await _db.customSelect(query, variables: driftVars).get();
      final symbols = rows.map((r) => r.read<String>('symbol')).toList();
      return (symbols: symbols, totalScanned: totalScanned);
    } catch (e) {
      AppLogger.error('ScreeningRepo', 'SQL 篩選失敗', e);
      return (symbols: <String>[], totalScanned: totalScanned);
    }
  }

  @override
  Future<Map<String, List<DailyPriceEntry>>> getPriceHistoryBatch(
    List<String> symbols, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _db.getPriceHistoryBatch(
      symbols,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<Map<String, List<DailyReasonEntry>>> getReasonsBatch(
    List<String> symbols,
    DateTime date,
  ) {
    return _db.getReasonsBatch(symbols, date);
  }

  // ==================================================
  // SQL 建構輔助方法
  // ==================================================

  String? _buildWhereClause(
    ScreeningCondition condition,
    List<Object> variables,
  ) {
    final column = _fieldToColumn(condition.field);
    if (column == null) return null;

    switch (condition.operator) {
      case ScreeningOperator.greaterThan:
        variables.add(condition.value!);
        return '$column > ?';
      case ScreeningOperator.greaterOrEqual:
        variables.add(condition.value!);
        return '$column >= ?';
      case ScreeningOperator.lessThan:
        variables.add(condition.value!);
        return '$column < ?';
      case ScreeningOperator.lessOrEqual:
        variables.add(condition.value!);
        return '$column <= ?';
      case ScreeningOperator.between:
        variables.addAll([condition.value!, condition.valueTo!]);
        return '$column BETWEEN ? AND ?';
      case ScreeningOperator.equals:
        variables.add(condition.value ?? condition.stringValue!);
        return '$column = ?';
      case ScreeningOperator.isTrue:
      case ScreeningOperator.isFalse:
        return null; // boolean 型不走 SQL
    }
  }

  String? _fieldToColumn(ScreeningField field) => switch (field) {
    ScreeningField.close => 'dp.close',
    ScreeningField.volume => 'dp.volume',
    ScreeningField.priceChangePercent =>
      '((dp.close - pp.prev_close) / pp.prev_close * 100)',
    ScreeningField.pe => 'sv.per',
    ScreeningField.pbr => 'sv.pbr',
    ScreeningField.dividendYield => 'sv.dividend_yield',
    ScreeningField.revenueYoyGrowth => 'mr.yoy_growth',
    ScreeningField.revenueMomGrowth => 'mr.mom_growth',
    ScreeningField.score => 'da.score',
    _ => null,
  };
}
