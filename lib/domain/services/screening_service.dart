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
      final historyStart = startOfDay.subtract(
        const Duration(days: IndicatorParams.screeningIndicatorLookbackDays),
      );
      priceHistories = await _repo.getPriceHistoryBatch(
        candidates,
        startDate: historyStart,
        endDate: startOfDay.add(const Duration(days: 1)),
      );
    }

    if (needsSignals) {
      reasonsMap = await _repo.getReasonsBatch(candidates, startOfDay);
    }

    // 判斷哪些指標欄位被用到，只計算需要的指標
    final neededFields = conditions.map((c) => c.field).toSet();

    // 逐檔評估
    final result = <String>[];

    for (final symbol in candidates) {
      var passes = true;

      // 預先計算所有指標（每個 symbol 只計算一次）
      final cache = needsIndicators
          ? _buildIndicatorCache(
              priceHistories?[symbol] ?? [],
              neededFields,
              indicatorService,
            )
          : null;

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
            passes = _evaluateIndicatorCondition(condition, cache);
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

  /// 每個 symbol 預先計算所有需要的指標，避免每個條件重複計算
  _IndicatorCache? _buildIndicatorCache(
    List<DailyPriceEntry> prices,
    Set<ScreeningField> neededFields,
    TechnicalIndicatorService indicatorService,
  ) {
    if (prices.length < IndicatorParams.screeningIndicatorMinDataPoints) {
      return null;
    }
    final (:closes, :highs, :lows, :volumes) = prices.extractOhlcv();
    if (closes.length < IndicatorParams.screeningIndicatorMinDataPoints) {
      return null;
    }

    double? rsi, kdK, kdD, ma5, ma10, ma20, ma60, volumeRatioMa20;

    if (neededFields.contains(ScreeningField.rsi14)) {
      final v = indicatorService.calculateRSI(
        closes,
        period: IndicatorParams.rsiPeriod,
      );
      rsi = v.isNotEmpty ? v.last : null;
    }

    if (neededFields.contains(ScreeningField.kValue) ||
        neededFields.contains(ScreeningField.dValue)) {
      final kd = indicatorService.calculateKD(
        highs,
        lows,
        closes,
        kPeriod: IndicatorParams.kdPeriodK,
        dPeriod: IndicatorParams.kdPeriodD,
      );
      kdK = kd.k.isNotEmpty ? kd.k.last : null;
      kdD = kd.d.isNotEmpty ? kd.d.last : null;
    }

    if (neededFields.contains(ScreeningField.aboveMa5) && closes.length >= 5) {
      final v = indicatorService.calculateSMA(closes, 5);
      ma5 = v.isNotEmpty ? v.last : null;
    }
    if (neededFields.contains(ScreeningField.aboveMa10) &&
        closes.length >= 10) {
      final v = indicatorService.calculateSMA(closes, 10);
      ma10 = v.isNotEmpty ? v.last : null;
    }
    if (neededFields.contains(ScreeningField.aboveMa20)) {
      final v = indicatorService.calculateSMA(closes, 20);
      ma20 = v.isNotEmpty ? v.last : null;
    }
    if (neededFields.contains(ScreeningField.aboveMa60) &&
        closes.length >= 60) {
      final v = indicatorService.calculateSMA(closes, 60);
      ma60 = v.isNotEmpty ? v.last : null;
    }

    if (neededFields.contains(ScreeningField.volumeRatioMa20) &&
        volumes.length >= 20) {
      final volSma = indicatorService.calculateSMA(volumes, 20);
      final latestVolSma = volSma.isNotEmpty ? volSma.last : null;
      if (latestVolSma != null && latestVolSma > 0) {
        volumeRatioMa20 = volumes.last / latestVolSma;
      }
    }

    return _IndicatorCache(
      latestClose: closes.isNotEmpty ? closes.last : null,
      rsi: rsi,
      kdK: kdK,
      kdD: kdD,
      ma5: ma5,
      ma10: ma10,
      ma20: ma20,
      ma60: ma60,
      volumeRatioMa20: volumeRatioMa20,
    );
  }

  /// 評估技術指標條件（使用預計算快取）
  bool _evaluateIndicatorCondition(
    ScreeningCondition condition,
    _IndicatorCache? cache,
  ) {
    if (cache == null) return false;

    switch (condition.field) {
      case ScreeningField.rsi14:
        if (cache.rsi == null) return false;
        return _compareNumeric(condition.operator, cache.rsi!, condition);

      case ScreeningField.kValue:
        if (cache.kdK == null) return false;
        return _compareNumeric(condition.operator, cache.kdK!, condition);

      case ScreeningField.dValue:
        if (cache.kdD == null) return false;
        return _compareNumeric(condition.operator, cache.kdD!, condition);

      case ScreeningField.aboveMa5:
        if (cache.ma5 == null || cache.latestClose == null) return false;
        final isAbove = cache.latestClose! > cache.ma5!;
        return condition.operator == ScreeningOperator.isTrue
            ? isAbove
            : !isAbove;

      case ScreeningField.aboveMa10:
        if (cache.ma10 == null || cache.latestClose == null) return false;
        final isAbove = cache.latestClose! > cache.ma10!;
        return condition.operator == ScreeningOperator.isTrue
            ? isAbove
            : !isAbove;

      case ScreeningField.aboveMa20:
        if (cache.ma20 == null || cache.latestClose == null) return false;
        final isAbove = cache.latestClose! > cache.ma20!;
        return condition.operator == ScreeningOperator.isTrue
            ? isAbove
            : !isAbove;

      case ScreeningField.aboveMa60:
        if (cache.ma60 == null || cache.latestClose == null) return false;
        final isAbove = cache.latestClose! > cache.ma60!;
        return condition.operator == ScreeningOperator.isTrue
            ? isAbove
            : !isAbove;

      case ScreeningField.volumeRatioMa20:
        if (cache.volumeRatioMa20 == null) return false;
        return _compareNumeric(
          condition.operator,
          cache.volumeRatioMa20!,
          condition,
        );

      default:
        return true;
    }
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

/// 每個 symbol 預計算的技術指標快取
class _IndicatorCache {
  const _IndicatorCache({
    this.latestClose,
    this.rsi,
    this.kdK,
    this.kdD,
    this.ma5,
    this.ma10,
    this.ma20,
    this.ma60,
    this.volumeRatioMa20,
  });

  final double? latestClose;
  final double? rsi;
  final double? kdK;
  final double? kdD;
  final double? ma5;
  final double? ma10;
  final double? ma20;
  final double? ma60;
  final double? volumeRatioMa20;
}
