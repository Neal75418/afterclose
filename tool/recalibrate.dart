// tool/recalibrate.dart
//
// CLI tool — print 為預期輸出，關閉 avoid_print lint。
// ignore_for_file: avoid_print
//
// 從歷史 `rule_accuracy` 統計產出 candidate calibrated rule scores JSON 檔。
//
// Stage 2 LEAN Commit 3: pipeline build-only。此工具產出 `*_candidate.json`，
// 使用者 review 後手動 rename 成 production filename 才真正生效。Stage 5 的
// runtime loader 才會讀取 production filename。
//
// 使用方式：
//
//   dart run tool/recalibrate.dart                          # 兩個 horizon 都跑
//   dart run tool/recalibrate.dart --db <path>              # 自訂 DB 位置
//   dart run tool/recalibrate.dart --horizon short          # 只跑 5D
//   dart run tool/recalibrate.dart --horizon long           # 只跑 60D
//   dart run tool/recalibrate.dart --dry-run                # 印出但不寫檔
//
// 輸出：
//   assets/rule_scores_calibrated_short_candidate.json
//   assets/rule_scores_calibrated_long_candidate.json
//
// Review workflow：
//   1. 跑完這個工具 → 產出 `*_candidate.json`
//   2. `git diff assets/rule_scores_calibrated_*.json` 看分數變動
//   3. 決定 approve → 手動 rename：
//      mv assets/rule_scores_calibrated_short_candidate.json \
//         assets/rule_scores_calibrated_short.json
//   4. Commit + push
//
// 詳細設計見 docs/plans/2026-04-11-scoring-stage2-design.md 和 docs/CALIBRATION.md

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

// ============================================================================
// Public data models (importable by tests)
// ============================================================================

/// 單一規則的歷史統計輸入（從 `rule_accuracy` 表讀取）
class RuleStats {
  const RuleStats({
    required this.ruleId,
    required this.hitRate,
    required this.avgReturn,
    required this.triggerCount,
  });

  final String ruleId;

  /// 命中率 [0.0, 1.0]
  final double hitRate;

  /// 平均報酬率（%），如 2.5 表示 2.5%
  final double avgReturn;

  /// 總觸發次數
  final int triggerCount;
}

/// 單一規則的 calibration 結果
class CalibratedRule {
  const CalibratedRule({
    required this.score,
    required this.hitRate,
    required this.avgReturn,
    required this.samples,
    required this.tStat,
    required this.active,
    this.cutReason,
  });

  /// 校準後的分數；cut 規則為 0
  final int score;
  final double hitRate;
  final double avgReturn;
  final int samples;
  final double tStat;
  final bool active;
  final String? cutReason;

  factory CalibratedRule.activeRule({
    required RuleStats stats,
    required double tStat,
    required int score,
  }) {
    return CalibratedRule(
      score: score,
      hitRate: stats.hitRate,
      avgReturn: stats.avgReturn,
      samples: stats.triggerCount,
      tStat: tStat,
      active: true,
    );
  }

  factory CalibratedRule.cutRule({
    required RuleStats stats,
    required double tStat,
    required String reason,
  }) {
    return CalibratedRule(
      score: 0,
      hitRate: stats.hitRate,
      avgReturn: stats.avgReturn,
      samples: stats.triggerCount,
      tStat: tStat,
      active: false,
      cutReason: reason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'hit_rate': double.parse(hitRate.toStringAsFixed(4)),
      'avg_return': double.parse(avgReturn.toStringAsFixed(4)),
      'samples': samples,
      't_stat': double.parse(tStat.toStringAsFixed(4)),
      'active': active,
      if (cutReason != null) 'cut_reason': cutReason,
    };
  }
}

// ============================================================================
// Calibrator — linear_map_v1 公式 + cut thresholds
// ============================================================================

/// linear_map_v1 校準器
///
/// 流程：
/// 1. Compute z-stat 透過 proportion z-test: `(hit_rate - 0.5) / sqrt(p(1-p)/n)`
/// 2. Cut 過濾：`samples < 30` / `z_stat < 1.5` / `hit_rate < 0.55`
/// 3. 倖存者的 raw weight = `hit_rate × avg_return × sqrt(n)`
/// 4. Min-max normalize 到 [10, 35] 分數區間
abstract final class Calibrator {
  static const double tStatCutThreshold = 1.5;
  static const double hitRateCutThreshold = 0.55;
  static const int sampleSizeCutThreshold = 30;
  static const int minScore = 10;
  static const int maxScore = 35;

  /// Proportion z-test: `z = (p - 0.5) / sqrt(p(1-p)/n)`
  ///
  /// Degenerate case（n=0 或 hit_rate ∈ {0, 1}）回傳 0.0。這些 case 必定
  /// 被 [calibrate] 內的 cut 檢查擋掉（通常是 sample_too_small）。
  static double computeTStat(double hitRate, int n) {
    if (n <= 0) return 0.0;
    final variance = hitRate * (1 - hitRate);
    if (variance <= 0) return 0.0;
    final standardError = sqrt(variance / n);
    if (standardError == 0) return 0.0;
    return (hitRate - 0.5) / standardError;
  }

  /// Linear map v1 raw weight before normalization
  static double rawWeight(RuleStats stats) {
    return stats.hitRate * stats.avgReturn * sqrt(stats.triggerCount);
  }

  /// Min-max normalize `raw` into `[minScore, maxScore]` integer.
  ///
  /// 當 `maxRaw == minRaw`（所有 active 規則 raw 相同）時回傳中點避免 division by 0。
  static int linearMapScore(double raw, double minRaw, double maxRaw) {
    if (maxRaw <= minRaw) return (minScore + maxScore) ~/ 2;
    final normalized = (raw - minRaw) / (maxRaw - minRaw);
    final clamped = normalized.clamp(0.0, 1.0);
    return (minScore + clamped * (maxScore - minScore)).round();
  }

  /// Calibrate 單一規則。需要傳入 `minRaw` / `maxRaw`（應從所有 active 規則算出）
  /// 作為 normalization context。
  ///
  /// Cut order (first match wins)：
  /// 1. `sample_too_small` — triggerCount < 30
  /// 2. `t_stat_below_threshold` — z-stat < 1.5
  /// 3. `hit_rate_below_threshold` — hit_rate < 0.55
  static CalibratedRule calibrate(
    RuleStats stats, {
    required double minRaw,
    required double maxRaw,
  }) {
    final tStat = computeTStat(stats.hitRate, stats.triggerCount);

    if (stats.triggerCount < sampleSizeCutThreshold) {
      return CalibratedRule.cutRule(
        stats: stats,
        tStat: tStat,
        reason: 'sample_too_small',
      );
    }
    if (tStat < tStatCutThreshold) {
      return CalibratedRule.cutRule(
        stats: stats,
        tStat: tStat,
        reason: 't_stat_below_threshold',
      );
    }
    if (stats.hitRate < hitRateCutThreshold) {
      return CalibratedRule.cutRule(
        stats: stats,
        tStat: tStat,
        reason: 'hit_rate_below_threshold',
      );
    }

    final raw = rawWeight(stats);
    final score = linearMapScore(raw, minRaw, maxRaw);
    return CalibratedRule.activeRule(stats: stats, tStat: tStat, score: score);
  }

  /// Calibrate 整組規則。normalization range 只用**倖存者**（未被 cut 的規則）算
  /// minRaw/maxRaw，避免 cut 規則（通常是 outlier 小樣本）扭曲 active 規則的
  /// 分數分布。
  static Map<String, CalibratedRule> calibrateAll(List<RuleStats> allStats) {
    if (allStats.isEmpty) return {};

    // Pass 1: 找出倖存者
    final survivors = <RuleStats>[];
    for (final stats in allStats) {
      if (stats.triggerCount < sampleSizeCutThreshold) continue;
      if (stats.hitRate < hitRateCutThreshold) continue;
      final tStat = computeTStat(stats.hitRate, stats.triggerCount);
      if (tStat < tStatCutThreshold) continue;
      survivors.add(stats);
    }

    // 計算 normalization range
    double minRaw = 0.0;
    double maxRaw = 1.0;
    if (survivors.isNotEmpty) {
      final rawWeights = survivors.map(rawWeight).toList();
      minRaw = rawWeights.reduce(min);
      maxRaw = rawWeights.reduce(max);
    }

    // Pass 2: Calibrate 每一條（包含被 cut 的，要存 cut_reason 到 JSON）
    final result = <String, CalibratedRule>{};
    for (final stats in allStats) {
      result[stats.ruleId] = calibrate(stats, minRaw: minRaw, maxRaw: maxRaw);
    }
    return result;
  }
}

// ============================================================================
// CLI main
// ============================================================================

const _horizonShort = 'short';
const _horizonLong = 'long';
const _horizonBoth = 'both';

const _periodShort = '5D';
const _periodLong = '60D';

// 對齊 rule_accuracy_service.dart 的 _successThresholds
const _thresholdShort = 3.0;
const _thresholdLong = 12.0;

const _windowDays = 504; // 2 trading years
const _trainRatio = 0.7;
const _formulaVersion = 'linear_map_v1';

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);
  if (config == null) {
    _printUsage(stderr);
    exit(1);
  }

  final dbPath = config.dbPath ?? _autoDetectDb();
  if (dbPath == null) {
    stderr.writeln('❌ DB file 找不到。用 --db <path> 手動指定。');
    stderr.writeln('');
    stderr.writeln('💡 找 DB 指令：');
    stderr.writeln('   find ~/Library -name "afterclose*.sqlite" 2>/dev/null');
    exit(1);
  }
  if (!File(dbPath).existsSync()) {
    stderr.writeln('❌ DB 檔案不存在: $dbPath');
    exit(1);
  }

  // 驗證 repo root 的 assets/ 存在（避免寫錯位置）
  if (!config.dryRun && !Directory('assets').existsSync()) {
    stderr.writeln('❌ assets/ 目錄不存在 — 請從 repo root 執行。');
    exit(1);
  }

  print('📂 DB: $dbPath');
  if (config.dryRun) {
    print('🔍 DRY RUN — 只印不寫');
  }

  final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  try {
    for (final horizon in _horizonsToProcess(config.horizon)) {
      print('');
      print('═══ Horizon: $horizon ═══');
      _processHorizon(db, horizon: horizon, dryRun: config.dryRun);
    }
  } finally {
    db.dispose(); // ignore: deprecated_member_use
  }

  print('');
  print('✅ 完成');
  if (!config.dryRun) {
    print('');
    print('👉 Review 流程：');
    print('   1. git diff assets/rule_scores_calibrated_*_candidate.json');
    print('   2. 判斷分數變動是否合理');
    print('   3. Approve: mv *_candidate.json → production filename');
    print('   4. Commit + push');
  }
}

void _processHorizon(
  Database db, {
  required String horizon,
  required bool dryRun,
}) {
  final period = horizon == _horizonShort ? _periodShort : _periodLong;
  final threshold = horizon == _horizonShort ? _thresholdShort : _thresholdLong;

  final rows = db.select(
    'SELECT rule_id, trigger_count, success_count, avg_return '
    'FROM rule_accuracy WHERE period = ?',
    [period],
  );

  if (rows.isEmpty) {
    print('  ⚠️  rule_accuracy 沒有 $period 的統計資料 — skip');
    print('     (可能原因：app 還沒跑過歷史資料驗證，或 daily_reason 沒資料)');
    return;
  }

  final allStats = <RuleStats>[];
  for (final row in rows) {
    final triggerCount = row['trigger_count'] as int;
    final successCount = row['success_count'] as int;
    final avgReturn = (row['avg_return'] as num).toDouble();
    final hitRate = triggerCount > 0 ? successCount / triggerCount : 0.0;
    allStats.add(
      RuleStats(
        ruleId: row['rule_id'] as String,
        hitRate: hitRate,
        avgReturn: avgReturn,
        triggerCount: triggerCount,
      ),
    );
  }

  final calibrated = Calibrator.calibrateAll(allStats);

  final activeCount = calibrated.values.where((r) => r.active).length;
  final cutCount = calibrated.values.where((r) => !r.active).length;
  print('  ${calibrated.length} 條規則：$activeCount active，$cutCount cut');

  final payload = <String, dynamic>{
    'schema_version': 1,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'horizon': horizon == _horizonShort ? '5d' : '60d',
    'backtest': {
      'window_days': _windowDays,
      'train_ratio': _trainRatio,
      'success_threshold_pct': threshold,
      'formula': _formulaVersion,
    },
    'rules': {
      for (final entry in calibrated.entries) entry.key: entry.value.toJson(),
    },
  };

  final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

  if (dryRun) {
    print('  --dry-run: candidate JSON 預覽：');
    print(jsonStr);
    return;
  }

  final filename = horizon == _horizonShort
      ? 'assets/rule_scores_calibrated_short_candidate.json'
      : 'assets/rule_scores_calibrated_long_candidate.json';

  // Atomic write: temp → rename
  final tempFile = File('$filename.tmp');
  tempFile.writeAsStringSync(jsonStr);
  tempFile.renameSync(filename);
  print('  ✅ Wrote $filename (${jsonStr.length} bytes)');
}

class _Config {
  const _Config({
    required this.dbPath,
    required this.horizon,
    required this.dryRun,
  });

  final String? dbPath;
  final String horizon;
  final bool dryRun;
}

_Config? _parseArgs(List<String> args) {
  String? dbPath;
  var horizon = _horizonBoth;
  var dryRun = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--db':
        if (i + 1 >= args.length) return null;
        dbPath = args[++i];
      case '--horizon':
        if (i + 1 >= args.length) return null;
        horizon = args[++i];
        if (horizon != _horizonShort &&
            horizon != _horizonLong &&
            horizon != _horizonBoth) {
          stderr.writeln('❌ Invalid --horizon: $horizon (use short|long|both)');
          return null;
        }
      case '--dry-run':
        dryRun = true;
      case '--help' || '-h':
        return null;
      default:
        stderr.writeln('❌ Unknown arg: $arg');
        return null;
    }
  }

  return _Config(dbPath: dbPath, horizon: horizon, dryRun: dryRun);
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/recalibrate.dart '
    '[--db <path>] [--horizon <short|long|both>] [--dry-run]',
  );
  sink.writeln('');
  sink.writeln('Generates candidate calibrated rule scores JSON files');
  sink.writeln('from the rule_accuracy DB table using linear_map_v1 formula.');
}

List<String> _horizonsToProcess(String horizon) {
  switch (horizon) {
    case _horizonShort:
      return [_horizonShort];
    case _horizonLong:
      return [_horizonLong];
    case _horizonBoth:
      return [_horizonShort, _horizonLong];
    default:
      throw StateError('unreachable');
  }
}

String? _autoDetectDb() {
  final home = Platform.environment['HOME'];
  if (home == null) return null;
  // 已知 macOS Flutter container 位置（check_db_range.dart Stage 0 findings）
  final candidate = File(
    '$home/Library/Containers/com.neo.afterclose/Data/Documents/afterclose.sqlite',
  );
  if (candidate.existsSync()) return candidate.path;
  return null;
}
