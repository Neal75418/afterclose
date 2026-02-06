import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/domain/repositories/screening_repository.dart';
import 'package:afterclose/domain/services/ohlcv_data.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

/// 自訂選股篩選引擎
///
/// 混合 SQL 預篩 + 記憶體後篩的兩階段篩選。
/// SQL 查詢邏輯委託給 [IScreeningRepository]。
class ScreeningService {
  const ScreeningService({required IScreeningRepository repository})
    : _repo = repository;

  final IScreeningRepository _repo;

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
    final sqlResult = await _repo.executeSqlFilter(sqlConditions, targetDate);

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

    // 批次載入所需資料（透過 repository）
    Map<String, List<DailyPriceEntry>>? priceHistories;
    Map<String, List<DailyReasonEntry>>? reasonsMap;

    if (needsIndicators) {
      final historyStart = startOfDay.subtract(const Duration(days: 120));
      priceHistories = await _repo.getPriceHistoryBatch(
        candidates,
        startDate: historyStart,
        endDate: startOfDay.add(const Duration(days: 1)),
      );
    }

    if (needsSignals) {
      reasonsMap = await _repo.getReasonsBatch(candidates, startOfDay);
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

    final (:closes, :highs, :lows, :volumes) = prices.extractOhlcv();

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
