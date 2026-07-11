// tool/exit_validate.dart
//
// CLI tool — print 為預期輸出，關閉 avoid_print lint。
// ignore_for_file: avoid_print
//
// 出場條件 replay gate（評分改進 #3 Phase 1）。
//
// 驗證三個出場/失效條件（hardStop / trendBreak / timeStop）在歷史資料上
// 「觸發出場 vs 持有滿 60 交易日」是否有 edge，產出按 mode × 年切分的
// gate 報告供人工決定哪些條件上線。**沒 edge 的條件不進 app。**
//
// 設計：docs/plans/2026-07-11-exit-thesis-invalidation-design.md §2-§3
// 計畫：docs/plans/2026-07-11-exit-validate-gate-plan.md
//
// ## 關鍵原則
//
// - 進場模擬 = 訊號日**次一交易日收盤**（T+1）——盤後 app 買不到訊號日
//   收盤（與 calibration look-ahead 修正同一原則）。
// - 觸發判斷基準 = 訊號日收盤（T0 referencePrice）。兩者不可互換。
// - 出場後以 0% 報酬計（不含資金再部署效益）→ gate 系統性低估出場紀律
//   的實務價值；「沒 edge」= 單筆訊號品質無差異，不等於「紀律沒用」。

import 'package:afterclose/core/constants/exit_params.dart';
import 'package:afterclose/core/utils/price_limit.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis_service.dart';
import 'package:afterclose/domain/services/rule_engine.dart';

import 'replay_calibrator.dart';

// ============================================================================
// 純函數出場模擬（importable by tests）
// ============================================================================

/// 單一樣本的出場模擬結果
typedef ExitSimResult = ({
  double exitReturnPct, // 出場版總報酬（%），出場後 0
  double holdReturnPct, // 持有滿 horizon 總報酬（%）
  int holdingDays, // 出場版實際持有交易日數（未觸發 = horizon）
  ExitReason? reason, // null = 全程未觸發
  double exitMddPct, // 出場版最大回檔（%，負值）
  double holdMddPct, // 持有版最大回檔
});

/// 對單一樣本（訊號日 [t0Index]）模擬「條件出場 vs 持有」。
///
/// [closes]：該股收盤序列（升序、可含 null＝停牌日）。
/// [enabled]：本次模擬啟用的條件集（單條變體用）。
///
/// 回 null 的情況（caller 應計入 survivorship counter、不得靜默丟棄）：
/// - referencePrice（T0 收盤）為 null
/// - T+1 進場價不存在 / null / ≤ 0
/// - T+1 + horizon 超出序列（60 日窗不完整——下市/資料尾端）
ExitSimResult? simulateExit({
  required List<double?> closes,
  required int t0Index,
  required Set<ExitReason> enabled,
}) {
  final ref = closes[t0Index];
  final entryIndex = t0Index + 1;
  final endIndex = entryIndex + ExitParams.holdHorizonTradingDays;
  if (ref == null || ref <= 0 || endIndex >= closes.length) return null;
  final entry = closes[entryIndex];
  if (entry == null || entry <= 0) return null;

  // 該日往前（含該日）60 根非 null 收盤的平均；不足 60 根回 null（不判定）
  double? ma60At(int d) {
    var sum = 0.0;
    var n = 0;
    for (var k = d; k >= 0 && n < ExitParams.ma60Window; k--) {
      final c = closes[k];
      if (c != null) {
        sum += c;
        n++;
      }
    }
    return n < ExitParams.ma60Window ? null : sum / n;
  }

  var everAboveRef = false;
  ExitReason? reason;
  var exitIndex = endIndex; // 未觸發 = 持有到 horizon 末
  for (var d = entryIndex; d <= endIndex; d++) {
    final c = closes[d];
    if (c == null) continue; // 停牌日跳過（timeStop 以 index 差計數）
    if (c > ref) everAboveRef = true;

    // 同日 tie-break：照 ExitReason 宣告序（hardStop > trendBreak > timeStop）
    ExitReason? hit;
    if (enabled.contains(ExitReason.hardStop) &&
        c < ref * (1 - ExitParams.hardStopPct)) {
      hit = ExitReason.hardStop;
    } else if (enabled.contains(ExitReason.trendBreak)) {
      final ma = ma60At(d);
      if (ma != null && c < ma) hit = ExitReason.trendBreak;
    }
    if (hit == null &&
        enabled.contains(ExitReason.timeStop) &&
        d - t0Index >= ExitParams.timeStopTradingDays &&
        !everAboveRef) {
      hit = ExitReason.timeStop;
    }
    if (hit != null) {
      reason = hit;
      exitIndex = d;
      break;
    }
  }

  double retPct(int d) => (closes[d]! / entry - 1) * 100;

  // 出場日/窗末若為 null（停牌），往前找最近非 null 收盤當結算價
  int settleIndex(int from) {
    var d = from;
    while (d > entryIndex && closes[d] == null) {
      d--;
    }
    return d;
  }

  var exitMdd = 0.0;
  var holdMdd = 0.0;
  for (var d = entryIndex; d <= endIndex; d++) {
    if (closes[d] == null) continue;
    final r = retPct(d);
    if (d <= exitIndex && r < exitMdd) exitMdd = r;
    if (r < holdMdd) holdMdd = r;
  }

  return (
    exitReturnPct: retPct(settleIndex(exitIndex)),
    holdReturnPct: retPct(settleIndex(endIndex)),
    holdingDays: reason == null
        ? ExitParams.holdHorizonTradingDays
        : exitIndex - entryIndex,
    reason: reason,
    exitMddPct: exitMdd,
    holdMddPct: holdMdd,
  );
}

// ============================================================================
// 樣本蒐集與 4 變體模擬 pipeline
// ============================================================================

/// mode 訊號日樣本（釘選模擬的近似：該日該 mode 規則分數加總過訊號門檻）
typedef ExitSample = ({String symbol, DateTime date, String mode});

/// 單一樣本在單一變體下的模擬結果
typedef ExitVariantRow = ({ExitSample sample, ExitSimResult sim});

/// gate 驗證總結果
class ExitValidationResult {
  const ExitValidationResult({
    required this.samples,
    required this.variantResults,
    required this.skippedNoWindow,
    required this.limitFlaggedT0,
  });

  /// 通過去重與窗檢查、實際進入模擬的樣本
  final List<ExitSample> samples;

  /// 變體名（all / hardStop / trendBreak / timeStop）→ 每樣本模擬結果
  final Map<String, List<ExitVariantRow>> variantResults;

  /// Survivorship counter：T+1+60 窗不完整（下市/資料尾端/停牌斷點）
  /// 而被排除的樣本數——報告必印、不得靜默（spec §3）。
  final int skippedNoWindow;

  /// T0 為漲/跌停的樣本數（v1 只觀察不特殊處理，spec §3）
  final int limitFlaggedT0;
}

/// 出場條件 gate 驗證器
///
/// pipeline：ReplayCalibrator（scoreSink 蒐樣本）→ 載入樣本股價格序列
/// → 對每樣本跑 4 個條件變體的 [simulateExit] → 聚合。
class ExitValidator {
  ExitValidator({
    required this.db,
    required this.replayConfig,
    AnalysisService? analysisService,
    RuleEngine? ruleEngine,
    void Function(String)? logger,
  }) : _analysisService = analysisService,
       _ruleEngine = ruleEngine,
       _log = logger ?? print;

  final AppDatabase db;
  final ReplayConfig replayConfig;
  final AnalysisService? _analysisService;
  final RuleEngine? _ruleEngine;
  final void Function(String) _log;

  /// 4 個條件變體（報告各自 vs 持有）
  static const Map<String, Set<ExitReason>> variants = {
    'all': {ExitReason.hardStop, ExitReason.trendBreak, ExitReason.timeStop},
    'hardStop': {ExitReason.hardStop},
    'trendBreak': {ExitReason.trendBreak},
    'timeStop': {ExitReason.timeStop},
  };

  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<ExitValidationResult> run() async {
    // 1. Replay + sink 蒐集 raw 樣本（mode 分數加總 ≥ 訊號門檻）
    _log('▶️  Replay 蒐集 mode 訊號日樣本...');
    final raw = <ExitSample>[];
    void sink(ScoreSample s) {
      if (s.modeMomentum >= ExitParams.modeSignalScoreThreshold) {
        raw.add((symbol: s.symbol, date: s.date, mode: 'momentum'));
      }
      if (s.modeStrength >= ExitParams.modeSignalScoreThreshold) {
        raw.add((symbol: s.symbol, date: s.date, mode: 'strength'));
      }
      if (s.modePullback >= ExitParams.modeSignalScoreThreshold) {
        raw.add((symbol: s.symbol, date: s.date, mode: 'pullback'));
      }
    }

    await ReplayCalibrator(
      db: db,
      config: replayConfig,
      analysisService: _analysisService,
      ruleEngine: _ruleEngine,
      scoreSink: sink,
      logger: (_) {},
    ).run();
    _log('✅ raw 樣本 ${raw.length} 筆');

    // 2. 載入樣本股價格序列（升序）+ date→index 對照
    final symbols = raw.map((s) => s.symbol).toSet();
    final closesBySymbol = <String, List<double?>>{};
    final indexBySymbol = <String, Map<DateTime, int>>{};
    for (final symbol in symbols) {
      final prices = await db.getPriceHistory(
        symbol,
        startDate: DateTime(2000),
        endDate: DateTime(2100),
      );
      prices.sort((a, b) => a.date.compareTo(b.date));
      closesBySymbol[symbol] = [for (final p in prices) p.close];
      indexBySymbol[symbol] = {
        for (var i = 0; i < prices.length; i++) _dateKey(prices[i].date): i,
      };
    }

    // 3. 去重（同 symbol×mode 不重疊窗）+ 窗檢查 + 4 變體模擬
    //    非重疊：下一筆 T0 必須 > 前一筆的窗末 index（T0+1+horizon）。
    //    simulateExit 回 null 的判準與 enabled 無關 → survivorship 只數一次。
    raw.sort((a, b) {
      final s = a.symbol.compareTo(b.symbol);
      if (s != 0) return s;
      final m = a.mode.compareTo(b.mode);
      if (m != 0) return m;
      return a.date.compareTo(b.date);
    });

    final samples = <ExitSample>[];
    final variantResults = <String, List<ExitVariantRow>>{
      for (final name in variants.keys) name: [],
    };
    var skippedNoWindow = 0;
    var limitFlaggedT0 = 0;
    final lastWindowEnd = <String, int>{}; // '$symbol|$mode' → 窗末 index

    for (final sample in raw) {
      final closes = closesBySymbol[sample.symbol];
      final t0 = indexBySymbol[sample.symbol]?[_dateKey(sample.date)];
      if (closes == null || t0 == null) {
        skippedNoWindow++;
        continue;
      }

      final key = '${sample.symbol}|${sample.mode}';
      final prevEnd = lastWindowEnd[key];
      if (prevEnd != null && t0 <= prevEnd) continue; // 重疊窗、非 survivorship

      final allSim = simulateExit(
        closes: closes,
        t0Index: t0,
        enabled: variants['all']!,
      );
      if (allSim == null) {
        skippedNoWindow++;
        continue;
      }

      lastWindowEnd[key] = t0 + 1 + ExitParams.holdHorizonTradingDays;
      samples.add(sample);
      variantResults['all']!.add((sample: sample, sim: allSim));
      for (final name in variants.keys) {
        if (name == 'all') continue;
        final sim = simulateExit(
          closes: closes,
          t0Index: t0,
          enabled: variants[name]!,
        );
        // null 判準與 enabled 無關，all 已過 → 此處必非 null
        variantResults[name]!.add((sample: sample, sim: sim!));
      }

      // T0 漲跌停 flag（v1 只觀察）：以前一日收盤推漲跌幅
      final prev = t0 > 0 ? closes[t0 - 1] : null;
      final cur = closes[t0];
      if (prev != null && prev > 0 && cur != null) {
        final changePct = (cur / prev - 1) * 100;
        if (PriceLimit.isLimitUp(changePct) ||
            PriceLimit.isLimitDown(changePct)) {
          limitFlaggedT0++;
        }
      }
    }

    _log(
      '✅ 樣本 ${samples.length} 筆（去重後）、'
      'survivorship 排除 $skippedNoWindow、T0 漲跌停 $limitFlaggedT0',
    );

    return ExitValidationResult(
      samples: samples,
      variantResults: variantResults,
      skippedNoWindow: skippedNoWindow,
      limitFlaggedT0: limitFlaggedT0,
    );
  }
}
