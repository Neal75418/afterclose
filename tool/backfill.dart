// tool/backfill.dart
//
// CLI tool — print 為預期輸出，關閉 avoid_print lint。
// ignore_for_file: avoid_print
//
// Stage 3: Historical data backfill CLI for calibration purposes.
//
// 把 2 年（可自訂）的台股歷史資料從 TWSE + FinMind 抓下來寫進獨立的
// calibration DB，供 Stage 4 `tool/replay_calibrator.dart` 消費產出
// `rule_accuracy` 表，再由 `tool/recalibrate.dart` 生成 calibrated
// rule scores JSON。詳細設計見
// docs/plans/2026-04-12-stage3-4-design.md。
//
// ## 使用方式
//
//   # 預設：2 年、tool/calibration.db、FINMIND_TOKEN env var
//   dart run tool/backfill.dart
//
//   # 自訂
//   dart run tool/backfill.dart \
//     --db tool/calibration.db \
//     --years 2 \
//     --finmind-token eyJ... \
//     --symbols 2330,2317,2454 \
//     --dry-run
//
// ## Backfill 資料源（5 個）
//
//   1. daily_price           via PriceRepository.syncStockPrices
//   2. daily_institutional   via InstitutionalRepository.syncInstitutionalData
//   3. monthly_revenue       via FundamentalRepository.syncMonthlyRevenue
//   4. financial_data (EPS)  via FundamentalRepository.syncFinancialStatements
//   5. stock_valuation (PER) via FundamentalRepository.syncValuationData
//
// `dividend_history` 暫不 backfill — 它只用於 52 週新高/新低的股息
// 調整，非 calibration 的必要輸入。
//
// ## Rate limit
//
// 每條 syncX() 內部的 client 已經有 300ms delay（TWSE）+ FinMind 內建
// retry。此 script 不額外加 delay，直接循序呼叫。FinMind 600/hr
// (with token) 是主要瓶頸。總預估時間約 6–9 小時。
//
// ## Resumability
//
// 所有 sync methods 都 idempotent — 已存在於 DB 的月份會被跳過（見
// `PriceRepository.syncStockPrices` 的 existing-months check）。script
// 中途被 kill 可以直接重跑。
//
// ## 錯誤處理
//
// - 單 symbol 失敗：log + continue，記錄到 failed symbols list
// - `RateLimitException`：立即 abort（超過 API 額度）
// - `NetworkException`：立即 abort（網路斷線）
// - 其他：log + continue

import 'dart:async';
import 'dart:io';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/fundamental_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/price_repository.dart';
import 'package:afterclose/data/repositories/stock_repository.dart';
import 'package:afterclose/domain/repositories/fundamental_repository.dart';
import 'package:afterclose/domain/repositories/institutional_repository.dart';
import 'package:afterclose/domain/repositories/price_repository.dart';
import 'package:afterclose/domain/repositories/stock_repository.dart';

// ============================================================================
// Public data models (importable by tests)
// ============================================================================

/// Backfill 執行配置
class BackfillConfig {
  const BackfillConfig({
    required this.dbPath,
    required this.years,
    required this.finMindToken,
    this.symbolsWhitelist,
    this.dryRun = false,
    this.skipStockListSync = false,
  });

  /// SQLite 檔案路徑
  final String dbPath;

  /// 回溯年數
  final int years;

  /// FinMind API token（env var 或 CLI flag）
  final String finMindToken;

  /// 限定 backfill 的 symbol list（null = 全市場）
  final List<String>? symbolsWhitelist;

  /// Dry-run 模式：印出計畫但不實際抓取
  final bool dryRun;

  /// 跳過 stock list 同步（測試用）
  final bool skipStockListSync;
}

/// 單一 phase 的執行結果
class PhaseResult {
  const PhaseResult({
    required this.phase,
    required this.symbolsProcessed,
    required this.symbolsSucceeded,
    required this.rowsInserted,
    required this.failedSymbols,
    required this.duration,
  });

  final String phase;
  final int symbolsProcessed;
  final int symbolsSucceeded;
  final int rowsInserted;
  final List<String> failedSymbols;
  final Duration duration;

  @override
  String toString() {
    final failRate = symbolsProcessed == 0
        ? 0
        : ((symbolsProcessed - symbolsSucceeded) / symbolsProcessed * 100)
              .toStringAsFixed(1);
    return '[$phase] $symbolsSucceeded/$symbolsProcessed succeeded '
        '($failRate% failed), $rowsInserted rows, '
        '${_formatDuration(duration)}';
  }
}

/// 整體 backfill 結果
class BackfillResult {
  const BackfillResult({required this.phases, required this.totalDuration});

  final List<PhaseResult> phases;
  final Duration totalDuration;

  int get totalRows => phases.fold(0, (sum, p) => sum + p.rowsInserted);

  bool get hasFailures => phases.any((p) => p.failedSymbols.isNotEmpty);
}

/// 依賴注入容器 — 便於測試 mock
class BackfillDeps {
  const BackfillDeps({
    required this.db,
    required this.stockRepo,
    required this.priceRepo,
    required this.institutionalRepo,
    required this.fundamentalRepo,
  });

  final AppDatabase db;
  final IStockRepository stockRepo;
  final IPriceRepository priceRepo;
  final IInstitutionalRepository institutionalRepo;
  final IFundamentalRepository fundamentalRepo;
}

// ============================================================================
// Core backfill logic (testable via dep injection)
// ============================================================================

/// Backfill 主體邏輯，可透過 [BackfillDeps] 注入 mock 進行測試
class Backfiller {
  Backfiller({
    required this.config,
    required this.deps,
    void Function(String)? logger,
  }) : _log = logger ?? print;

  final BackfillConfig config;
  final BackfillDeps deps;
  final void Function(String) _log;

  /// 執行完整的 backfill pipeline
  ///
  /// 五個 phase 順序執行。遇到 rate limit / network exception 時立即
  /// 向上拋出 — 呼叫端負責決定要 retry 或 abort。
  Future<BackfillResult> run() async {
    final overallStart = DateTime.now();
    final phases = <PhaseResult>[];

    // Phase 0: 確保 stock_master 表有內容
    if (!config.skipStockListSync) {
      await _syncStockList();
    }

    // 決定 symbol 範圍
    final symbols = await _resolveSymbols();
    _log('📋 Target symbols: ${symbols.length}');

    if (config.dryRun) {
      _log('🔍 Dry run — 不實際執行 backfill');
      _logDryRunPlan(symbols);
      return BackfillResult(
        phases: const [],
        totalDuration: DateTime.now().difference(overallStart),
      );
    }

    // 日期範圍
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: config.years * 365));
    _log('📅 Date range: ${_formatDate(startDate)} → ${_formatDate(endDate)}');

    // Phase 1-5: 資料 backfill
    phases.add(
      await _runPhase(
        name: 'prices',
        symbols: symbols,
        syncOne: (symbol) => deps.priceRepo.syncStockPrices(
          symbol,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
    phases.add(
      await _runPhase(
        name: 'institutional',
        symbols: symbols,
        syncOne: (symbol) => deps.institutionalRepo.syncInstitutionalData(
          symbol,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
    phases.add(
      await _runPhase(
        name: 'revenue',
        symbols: symbols,
        syncOne: (symbol) => deps.fundamentalRepo.syncMonthlyRevenue(
          symbol: symbol,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
    phases.add(
      await _runPhase(
        name: 'financial',
        symbols: symbols,
        syncOne: (symbol) => deps.fundamentalRepo.syncFinancialStatements(
          symbol: symbol,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
    phases.add(
      await _runPhase(
        name: 'valuation',
        symbols: symbols,
        syncOne: (symbol) => deps.fundamentalRepo.syncValuationData(
          symbol: symbol,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );

    final totalDuration = DateTime.now().difference(overallStart);
    final result = BackfillResult(phases: phases, totalDuration: totalDuration);
    _logSummary(result);
    return result;
  }

  /// 執行單一 phase — 對所有 symbol 呼叫 [syncOne]
  ///
  /// 錯誤處理政策：
  /// - [RateLimitException] / [NetworkException]：rethrow（立即 abort）
  /// - 其他 exception：log + 記入 failedSymbols，繼續下個 symbol
  Future<PhaseResult> _runPhase({
    required String name,
    required List<String> symbols,
    required Future<int> Function(String symbol) syncOne,
  }) async {
    _log('');
    _log('▶️  Phase [$name] — ${symbols.length} symbols');
    final start = DateTime.now();
    final failedSymbols = <String>[];
    var succeeded = 0;
    var rowsInserted = 0;
    var lastLogAt = DateTime.now();

    for (var i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];
      try {
        final rows = await syncOne(symbol);
        rowsInserted += rows;
        succeeded++;
      } on RateLimitException catch (e) {
        _log('⛔ Phase [$name] 觸發 API rate limit — 中止 backfill: $e');
        rethrow;
      } on NetworkException catch (e) {
        _log('⛔ Phase [$name] 網路錯誤 — 中止 backfill: $e');
        rethrow;
      } catch (e) {
        failedSymbols.add(symbol);
        _log('  ⚠️  $symbol failed: $e');
      }

      // 每 10 秒印一次進度
      final now = DateTime.now();
      if (now.difference(lastLogAt).inSeconds >= 10 ||
          i == symbols.length - 1) {
        final pct = ((i + 1) / symbols.length * 100).toStringAsFixed(1);
        final elapsed = now.difference(start);
        _log(
          '  📊 [$name] ${i + 1}/${symbols.length} ($pct%), '
          'elapsed ${_formatDuration(elapsed)}, '
          'rows=$rowsInserted, failed=${failedSymbols.length}',
        );
        lastLogAt = now;
      }
    }

    final duration = DateTime.now().difference(start);
    return PhaseResult(
      phase: name,
      symbolsProcessed: symbols.length,
      symbolsSucceeded: succeeded,
      rowsInserted: rowsInserted,
      failedSymbols: failedSymbols,
      duration: duration,
    );
  }

  /// 同步 stock list 至 stock_master
  Future<void> _syncStockList() async {
    _log('▶️  Phase [stock_list] — 從 FinMind 同步股票清單');
    final start = DateTime.now();
    try {
      final count = await deps.stockRepo.syncStockList();
      final duration = DateTime.now().difference(start);
      _log(
        '✅ [stock_list] synced $count stocks in ${_formatDuration(duration)}',
      );
    } on RateLimitException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      _log('⚠️  [stock_list] 同步失敗，嘗試使用既有資料: $e');
    }
  }

  /// 決定要 backfill 的 symbol 列表
  ///
  /// 優先順序：CLI whitelist > stock_master 中所有 active stocks
  Future<List<String>> _resolveSymbols() async {
    if (config.symbolsWhitelist != null &&
        config.symbolsWhitelist!.isNotEmpty) {
      return config.symbolsWhitelist!;
    }
    final stocks = await deps.stockRepo.getAllStocks();
    return stocks.map((s) => s.symbol).toList();
  }

  void _logDryRunPlan(List<String> symbols) {
    _log('');
    _log('DRY RUN PLAN:');
    _log('  DB path: ${config.dbPath}');
    _log('  Years: ${config.years}');
    _log('  Symbols: ${symbols.length}');
    _log('  Phases: prices, institutional, revenue, financial, valuation');
    _log('  Estimated API calls:');
    _log(
      '    - Prices:        ${symbols.length} × ${config.years * 12} months '
      '= ${symbols.length * config.years * 12}',
    );
    _log(
      '    - Institutional: ${symbols.length} × 1 (FinMind range) '
      '= ${symbols.length}',
    );
    _log('    - Revenue:       ${symbols.length}');
    _log('    - Financial:     ${symbols.length}');
    _log('    - Valuation:     ${symbols.length}');
    final totalFinMind = symbols.length * 4;
    final eta = Duration(seconds: (totalFinMind * 3600 / 600).round());
    _log(
      '  FinMind calls total: $totalFinMind (~${_formatDuration(eta)} at '
      '600/hr limit)',
    );
  }

  void _logSummary(BackfillResult result) {
    _log('');
    _log('=' * 60);
    _log('✅ BACKFILL COMPLETE');
    _log('=' * 60);
    _log('Total duration: ${_formatDuration(result.totalDuration)}');
    _log('Total rows: ${result.totalRows}');
    _log('');
    _log('Per-phase:');
    for (final p in result.phases) {
      _log('  $p');
    }
    if (result.hasFailures) {
      _log('');
      _log('⚠️  Failed symbols per phase:');
      for (final p in result.phases) {
        if (p.failedSymbols.isNotEmpty) {
          _log(
            '  [${p.phase}]: ${p.failedSymbols.take(10).join(', ')}'
            '${p.failedSymbols.length > 10 ? " ..." : ""}',
          );
        }
      }
    }
  }
}

// ============================================================================
// CLI entry point
// ============================================================================

/// Dart CLI main — 只是 [runBackfillCli] 的 thin wrapper，負責把 int
/// exit code 送回 shell。
///
/// 可以透過兩種方式執行：
/// - `dart run tool/backfill.dart ...` — 純 Dart runtime，會因
///   `drift_flutter` import `dart:ui` 而 compile 失敗
/// - `flutter test test/tool/run_backfill.dart` — 推薦；見 scripts/calibrate.sh
Future<void> main(List<String> args) async {
  final code = await runBackfillCli(args);
  exit(code);
}

/// 不呼叫 [exit] 的 backfill 入口函式。供 test wrapper 使用。
///
/// 返回 exit code：
///   0 — 成功
///   1 — 無效 CLI 參數
///   3 — 完成但有 symbol 失敗（partial success）
///   4 — rate limit 觸發
///   5 — network error
Future<int> runBackfillCli(List<String> args) async {
  final config = _parseArgs(args);
  if (config == null) {
    _printUsage(stderr);
    return 1;
  }

  // 若 --years 過大提醒使用者
  if (config.years > 5) {
    stderr.writeln('⚠️  --years ${config.years} 很大，FinMind 可能回傳不完整歷史且耗時數天');
  }

  // 建立 DB（自動建立 schema via fingerprint 機制）
  final dbFile = File(config.dbPath);
  final isNewDb = !dbFile.existsSync();
  if (isNewDb) {
    print('📦 建立新的 calibration DB: ${config.dbPath}');
  } else {
    print('📦 開啟既有 calibration DB: ${config.dbPath}');
  }

  final db = AppDatabase.forToolFile(config.dbPath);

  try {
    // 初始化 clients
    final finMind = FinMindClient()..token = config.finMindToken;
    final twse = TwseClient();
    final tpex = TpexClient();
    const clock = SystemClock();

    // 初始化 repositories
    final stockRepo = StockRepository(database: db, finMindClient: finMind);
    final priceRepo = PriceRepository(
      database: db,
      finMindClient: finMind,
      twseClient: twse,
      tpexClient: tpex,
      clock: clock,
    );
    final institutionalRepo = InstitutionalRepository(
      database: db,
      finMindClient: finMind,
      twseClient: twse,
      tpexClient: tpex,
      clock: clock,
    );
    final fundamentalRepo = FundamentalRepository(
      db: db,
      finMind: finMind,
      twse: twse,
      tpex: tpex,
      clock: clock,
    );

    final deps = BackfillDeps(
      db: db,
      stockRepo: stockRepo,
      priceRepo: priceRepo,
      institutionalRepo: institutionalRepo,
      fundamentalRepo: fundamentalRepo,
    );

    final backfiller = Backfiller(config: config, deps: deps);
    final result = await backfiller.run();

    if (result.hasFailures) {
      print('');
      print('⚠️  Backfill 完成但有 symbol 失敗，請檢查上方 log');
      return 3;
    }
    return 0;
  } on RateLimitException catch (e) {
    stderr.writeln('');
    stderr.writeln('❌ API rate limit exceeded: $e');
    stderr.writeln('💡 請等一段時間後再重跑 — resumability 會自動跳過已完成的部分');
    return 4;
  } on NetworkException catch (e) {
    stderr.writeln('');
    stderr.writeln('❌ Network error: $e');
    stderr.writeln('💡 檢查網路連線後重跑');
    return 5;
  } finally {
    await db.close();
  }
}

// ============================================================================
// CLI arg parsing
// ============================================================================

BackfillConfig? _parseArgs(List<String> args) {
  String dbPath = 'tool/calibration.db';
  int years = 2;
  String? finMindToken;
  List<String>? symbolsWhitelist;
  var dryRun = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--db':
        if (i + 1 >= args.length) return null;
        dbPath = args[++i];
      case '--years':
        if (i + 1 >= args.length) return null;
        final parsed = int.tryParse(args[++i]);
        if (parsed == null || parsed < 1) {
          stderr.writeln('❌ Invalid --years: must be positive integer');
          return null;
        }
        years = parsed;
      case '--finmind-token':
        if (i + 1 >= args.length) return null;
        finMindToken = args[++i];
      case '--symbols':
        if (i + 1 >= args.length) return null;
        symbolsWhitelist = args[++i]
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (symbolsWhitelist.isEmpty) symbolsWhitelist = null;
      case '--dry-run':
        dryRun = true;
      case '--help' || '-h':
        return null;
      default:
        stderr.writeln('❌ Unknown arg: $arg');
        return null;
    }
  }

  // Token 優先順序：CLI flag > env var
  finMindToken ??= Platform.environment['FINMIND_TOKEN'];
  if (finMindToken == null || finMindToken.isEmpty) {
    stderr.writeln(
      '❌ FinMind token required. Use --finmind-token <token> or set '
      'FINMIND_TOKEN env var.',
    );
    return null;
  }

  return BackfillConfig(
    dbPath: dbPath,
    years: years,
    finMindToken: finMindToken,
    symbolsWhitelist: symbolsWhitelist,
    dryRun: dryRun,
  );
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run tool/backfill.dart '
    '[--db <path>] [--years <N>] [--finmind-token <token>] '
    '[--symbols <csv>] [--dry-run]',
  );
  sink.writeln('');
  sink.writeln('Historical data backfill for Stage 4 calibration.');
  sink.writeln('');
  sink.writeln('Options:');
  sink.writeln(
    '  --db <path>           SQLite file path (default: tool/calibration.db)',
  );
  sink.writeln('  --years <N>           Lookback years (default: 2)');
  sink.writeln(
    '  --finmind-token       FinMind API token (or set FINMIND_TOKEN env var)',
  );
  sink.writeln(
    '  --symbols <csv>       Whitelist symbols, e.g. "2330,2317,2454"',
  );
  sink.writeln('  --dry-run             Print plan without fetching');
  sink.writeln('  --help, -h            Show this help');
}

// ============================================================================
// Formatting helpers
// ============================================================================

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h${d.inMinutes.remainder(60)}m';
  } else if (d.inMinutes > 0) {
    return '${d.inMinutes}m${d.inSeconds.remainder(60)}s';
  } else {
    return '${d.inSeconds}s';
  }
}
