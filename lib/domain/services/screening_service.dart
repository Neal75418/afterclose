import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

/// 自訂選股篩選引擎
///
/// 混合 SQL 預篩 + 記憶體後篩的兩階段篩選。
class ScreeningService {
  const ScreeningService({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  /// 執行篩選
  ///
  /// 回傳符合所有條件的股票代碼列表（按 score 降序）。
  Future<ScreeningResult> execute({
    required List<ScreeningCondition> conditions,
    required DateTime targetDate,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (conditions.isEmpty) {
      return ScreeningResult(
        symbols: [],
        matchCount: 0,
        totalScanned: 0,
        dataDate: targetDate,
      );
    }

    // 分離 SQL 可篩選條件和記憶體篩選條件
    final sqlConditions = <ScreeningCondition>[];
    final memoryConditions = <ScreeningCondition>[];

    for (final c in conditions) {
      if (c.field.isSqlFilterable) {
        sqlConditions.add(c);
      } else {
        memoryConditions.add(c);
      }
    }

    // Phase A: SQL 預篩
    final sqlResult = await _executeSqlFilter(sqlConditions, targetDate);

    final totalScanned = sqlResult.totalScanned;
    var candidates = sqlResult.symbols;

    // Phase B: 記憶體後篩（技術指標 + 訊號）
    if (memoryConditions.isNotEmpty && candidates.isNotEmpty) {
      candidates = await _executeMemoryFilter(
        candidates,
        memoryConditions,
        targetDate,
      );
    }

    stopwatch.stop();

    return ScreeningResult(
      symbols: candidates,
      matchCount: candidates.length,
      totalScanned: totalScanned,
      dataDate: targetDate,
      executionTime: stopwatch.elapsed,
    );
  }

  // ==================================================
  // Phase A: SQL 預篩
  // ==================================================

  Future<({List<String> symbols, int totalScanned})> _executeSqlFilter(
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
    // 使用分區變數列表確保參數順序與 SQL 佔位符一致：
    // CTE params → JOIN params → WHERE(date) params → WHERE(conditions) params
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
      cteVars.addAll([
        startOfDay.millisecondsSinceEpoch ~/ 1000,
        prevDateMs,
      ]);

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
    final query = '''
      $ctePrefix
      SELECT DISTINCT da.symbol, da.score
      FROM daily_analysis da
      $joins
      WHERE da.date >= ? AND da.date < ? AND da.score > 0
      $wheres
      ORDER BY da.score DESC
    ''';

    // 按 SQL 佔位符順序組合所有參數：
    // CTE → JOIN → WHERE(date) → WHERE(conditions)
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
      AppLogger.error('ScreeningService', 'SQL 篩選失敗', e);
      return (symbols: <String>[], totalScanned: totalScanned);
    }
  }

  /// 將單一條件轉為 SQL WHERE 子句
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

  /// 欄位對應到 SQL 欄位名稱
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

  // ==================================================
  // Phase B: 記憶體後篩
  // ==================================================

  Future<List<String>> _executeMemoryFilter(
    List<String> candidates,
    List<ScreeningCondition> conditions,
    DateTime targetDate,
  ) async {
    final indicatorService = TechnicalIndicatorService();
    final startOfDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    // 判斷需要哪些資料
    final needsIndicators = conditions.any(
      (c) =>
          c.field == ScreeningField.rsi14 ||
          c.field == ScreeningField.kValue ||
          c.field == ScreeningField.dValue ||
          c.field == ScreeningField.aboveMa5 ||
          c.field == ScreeningField.aboveMa10 ||
          c.field == ScreeningField.aboveMa20 ||
          c.field == ScreeningField.aboveMa60 ||
          c.field == ScreeningField.volumeRatioMa20,
    );
    final needsSignals = conditions.any(
      (c) => c.field == ScreeningField.hasSignal,
    );

    // 批次載入所需資料
    Map<String, List<DailyPriceEntry>>? priceHistories;
    Map<String, List<DailyReasonEntry>>? reasonsMap;

    if (needsIndicators) {
      final historyStart = startOfDay.subtract(const Duration(days: 120));
      priceHistories = await _db.getPriceHistoryBatch(
        candidates,
        startDate: historyStart,
        endDate: startOfDay.add(const Duration(days: 1)),
      );
    }

    if (needsSignals) {
      reasonsMap = await _db.getReasonsBatch(candidates, startOfDay);
    }

    // 逐檔評估
    final result = <String>[];

    for (final symbol in candidates) {
      var passes = true;

      for (final condition in conditions) {
        if (!passes) break;

        switch (condition.field) {
          case ScreeningField.rsi14:
          case ScreeningField.kValue:
          case ScreeningField.dValue:
          case ScreeningField.aboveMa5:
          case ScreeningField.aboveMa10:
          case ScreeningField.aboveMa20:
          case ScreeningField.aboveMa60:
          case ScreeningField.volumeRatioMa20:
            passes = _evaluateIndicatorCondition(
              condition,
              priceHistories?[symbol] ?? [],
              indicatorService,
            );
          case ScreeningField.hasSignal:
            passes = _evaluateSignalCondition(
              condition,
              reasonsMap?[symbol] ?? [],
            );
          default:
            break; // SQL 欄位已在 Phase A 處理
        }
      }

      if (passes) {
        result.add(symbol);
      }
    }

    return result;
  }

  /// 評估技術指標條件
  bool _evaluateIndicatorCondition(
    ScreeningCondition condition,
    List<DailyPriceEntry> prices,
    TechnicalIndicatorService indicatorService,
  ) {
    if (prices.length < 20) return false;

    final closes = <double>[];
    final highs = <double>[];
    final lows = <double>[];
    final volumes = <double>[];

    for (final p in prices) {
      if (p.close != null && p.high != null && p.low != null) {
        closes.add(p.close!);
        highs.add(p.high!);
        lows.add(p.low!);
        volumes.add(p.volume ?? 0);
      }
    }

    if (closes.length < 20) return false;

    double? fieldValue;

    switch (condition.field) {
      case ScreeningField.rsi14:
        final rsiValues = indicatorService.calculateRSI(
          closes,
          period: RuleParams.rsiPeriod,
        );
        fieldValue = rsiValues.isNotEmpty ? rsiValues.last : null;

      case ScreeningField.kValue:
      case ScreeningField.dValue:
        final kd = indicatorService.calculateKD(
          highs,
          lows,
          closes,
          kPeriod: RuleParams.kdPeriodK,
          dPeriod: RuleParams.kdPeriodD,
        );
        if (condition.field == ScreeningField.kValue) {
          fieldValue = kd.k.isNotEmpty ? kd.k.last : null;
        } else {
          fieldValue = kd.d.isNotEmpty ? kd.d.last : null;
        }

      case ScreeningField.aboveMa5:
      case ScreeningField.aboveMa10:
      case ScreeningField.aboveMa20:
      case ScreeningField.aboveMa60:
        final period = switch (condition.field) {
          ScreeningField.aboveMa5 => 5,
          ScreeningField.aboveMa10 => 10,
          ScreeningField.aboveMa20 => 20,
          ScreeningField.aboveMa60 => 60,
          _ => 20,
        };
        if (closes.length < period) return false;
        final sma = indicatorService.calculateSMA(closes, period);
        final latestSma = sma.isNotEmpty ? sma.last : null;
        final latestClose = closes.last;
        if (latestSma == null) return false;
        final isAbove = latestClose > latestSma;
        return condition.operator == ScreeningOperator.isTrue
            ? isAbove
            : !isAbove;

      case ScreeningField.volumeRatioMa20:
        if (volumes.length < 20) return false;
        final volSma = indicatorService.calculateSMA(volumes, 20);
        final latestVolSma = volSma.isNotEmpty ? volSma.last : null;
        if (latestVolSma == null || latestVolSma == 0) return false;
        fieldValue = volumes.last / latestVolSma;

      default:
        return true;
    }

    if (fieldValue == null) return false;
    return _compareNumeric(condition.operator, fieldValue, condition);
  }

  /// 評估訊號條件
  bool _evaluateSignalCondition(
    ScreeningCondition condition,
    List<DailyReasonEntry> reasons,
  ) {
    if (condition.stringValue == null) return false;
    return reasons.any((r) => r.reasonType == condition.stringValue);
  }

  /// 數值比較
  bool _compareNumeric(
    ScreeningOperator op,
    double value,
    ScreeningCondition condition,
  ) => switch (op) {
    ScreeningOperator.greaterThan => value > condition.value!,
    ScreeningOperator.greaterOrEqual => value >= condition.value!,
    ScreeningOperator.lessThan => value < condition.value!,
    ScreeningOperator.lessOrEqual => value <= condition.value!,
    ScreeningOperator.between =>
      value >= condition.value! && value <= condition.valueTo!,
    _ => true,
  };
}
