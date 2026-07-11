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

import 'package:drift/drift.dart' show Value;

import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/clock.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
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
    this.interDayDelayMs = 5000,
    this.startDateOverride,
    this.endDateOverride,
    this.pricesViaFinMind = false,
    this.skipFundamentals = false,
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

  /// 每天 batch call 之間的延遲毫秒數
  ///
  /// 預設 5000ms（≈ 0.2 req/sec）避開 TWSE IP-based rate limit。
  /// 歷史經驗（已 stale）：500ms 在 70 calls 內被 ban、1500ms 給「充足
  /// 喘息」。但 2026-06 實測 1500ms 在 IP 已被部分標記時 6-22 calls 就被
  /// 擋，TWSE 之後可能收緊限額。5000ms 是經驗保守值，trade off ~3x
  /// wall-clock 換 retry-loop 失敗率近零。500 trading days × 5s ≈
  /// 42 分鐘 per market；如果仍被擋可進一步調到 8000-10000ms。
  ///
  /// 單元測試傳 0 跳過 delay。可用 env var `BACKFILL_INTER_DAY_DELAY_MS`
  /// 覆寫不必改 code。
  final int interDayDelayMs;

  /// 明確指定 backfill 起始日（覆寫 years-based 計算）。
  ///
  /// null = 用 `endDate - years*365`。用於精準回補特定區間（例如只補
  /// 2021-2023 而不重抓已存在的 2024-2026）。
  final DateTime? startDateOverride;

  /// 明確指定 backfill 結束日（覆寫 `DateTime.now()`）。null = now。
  final DateTime? endDateOverride;

  /// 價格回補改走 FinMind per-symbol（而非 TWSE STOCK_DAY_ALL batch）。
  ///
  /// 2026-06 起 TWSE STOCK_DAY_ALL 已不支援歷史 date 參數（一律回最新日），
  /// 故歷史回補（2021-2023 等）必須走 FinMind。預設 false 維持原 batch 行為。
  final bool pricesViaFinMind;

  /// 跳過 3 個基本面 phase（revenue / financial / valuation）。
  ///
  /// 基本面是 FinMind quota 最大宗（~3× 價格用量）。第一階段 walk-forward
  /// 只驗證價格類規則時可跳過，省下大量配額；基本面留作選配第二階段。
  final bool skipFundamentals;
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
    this.finMind,
  });

  final AppDatabase db;
  final IStockRepository stockRepo;
  final IPriceRepository priceRepo;
  final IInstitutionalRepository institutionalRepo;
  final IFundamentalRepository fundamentalRepo;

  /// FinMind client — 僅 `pricesViaFinMind` 模式需要（歷史價格 per-symbol 回補）。
  final FinMindClient? finMind;
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

    // 日期範圍 — 優先用明確的 start/end override，否則回退 years-based
    // 正規化到午夜：DateTime.now() 的時間分量若洩漏進 day-loop，
    // countPricesByDateAndMarket 的 TEXT 等值比對永遠 miss → skip-guard 全滅、
    // 每輪 retry 從頭重抓（2026-07-10 燒掉 26 輪的教訓之一）。
    final endDate = DateContext.normalize(
      config.endDateOverride ?? DateTime.now(),
    );
    final startDate = DateContext.normalize(
      config.startDateOverride ??
          endDate.subtract(Duration(days: config.years * 365)),
    );
    _log('📅 Date range: ${_formatDate(startDate)} → ${_formatDate(endDate)}');

    // Phase 1: prices — TWSE 上市 / TPEx 上櫃皆走 per-day batch
    //
    // TWSE 上市股票走 STOCK_DAY_ALL?date=...（一次回該日全部上市股票）。
    // TPEx 上櫃股票走 TPEx OpenAPI（一次回該日全部上櫃股票）。
    // 避開的問題：
    //   - 舊 TWSE 月度 per-symbol path 撐 5 分鐘就觸發 TWSE IP-based
    //     rate limit "Redirect loop detected"（1400 symbols × 24 months
    //     ≈ 33,000 calls 太集中）
    //   - 舊 FinMind per-symbol path 吃 600/day 免費額度
    // batch path 後兩個市場各約 500 calls / 2 年，永久脫離兩種 rate limit。
    if (config.pricesViaFinMind) {
      // 歷史回補：STOCK_DAY_ALL batch 已不支援歷史日期 → 走 FinMind per-symbol
      phases.add(
        await _backfillPricesViaFinMind(
          symbols: symbols,
          startDate: startDate,
          endDate: endDate,
        ),
      );
    } else {
      final partitioned = await _partitionSymbolsByMarket(symbols);
      if (partitioned.twse.isNotEmpty) {
        phases.add(
          await _backfillTwsePricesBatch(
            twseSymbols: partitioned.twse,
            startDate: startDate,
            endDate: endDate,
          ),
        );
      }
      if (partitioned.tpex.isNotEmpty) {
        phases.add(
          await _backfillTpexPricesBatch(
            tpexSymbols: partitioned.tpex,
            startDate: startDate,
            endDate: endDate,
          ),
        );
      }
    }
    // Phase 2: institutional — 改走 TWSE T86 + TPEx daily batch
    //
    // 與 prices:tpex 同 pattern：per-day 一次拿全市場兩個 source（TWSE
    // /rwd/zh/fund/T86 + TPEx OpenAPI），按 targetSymbols 過濾後寫入。
    // 取代舊的 per-symbol FinMind 路徑（吃 600/day 免費額度）。
    phases.add(
      await _backfillInstitutionalBatch(
        targetSymbols: symbols,
        startDate: startDate,
        endDate: endDate,
      ),
    );
    // 基本面 3 phase 是 FinMind quota 最大宗 — skipFundamentals 時跳過，
    // 只跑價格 + 法人（第一階段 walk-forward 只驗價格類規則）。
    if (!config.skipFundamentals) {
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
    } else {
      _log('⏭️  skipFundamentals — 跳過 revenue/financial/valuation phase');
    }

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

  /// 依市場別把 symbol 拆成 TWSE 上市 / TPEx 上櫃兩組
  ///
  /// stock_master 內找不到的 symbol 預設視為 TWSE（與 `PriceRepository.
  /// syncStockPrices` 內 `isOtc = stock?.market == MarketCode.tpex` 的
  /// 行為一致）。
  Future<_MarketPartition> _partitionSymbolsByMarket(
    List<String> symbols,
  ) async {
    final stockMap = await deps.db.getStocksBatch(symbols);
    final twse = <String>[];
    final tpex = <String>[];
    for (final symbol in symbols) {
      final market = stockMap[symbol]?.market;
      if (market == MarketCode.tpex) {
        tpex.add(symbol);
      } else {
        twse.add(symbol);
      }
    }
    return _MarketPartition(twse: twse, tpex: tpex);
  }

  /// 法人資料 batch backfill（TWSE T86 + TPEx OpenAPI 一起）
  ///
  /// 對日期範圍內每個交易日呼叫
  /// [IInstitutionalRepository.backfillInstitutionalByDate]，每天 1 次
  /// 兩個 source 並行拿全市場資料，過濾後寫入 DB。
  ///
  /// 跟 [_runPhase] 同樣的 rate limit / network exception abort 政策；
  /// 其他例外記入 `failedSymbols`（以日期字串標記）繼續。
  Future<PhaseResult> _backfillInstitutionalBatch({
    required List<String> targetSymbols,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _log('');
    _log(
      '▶️  Phase [institutional] — ${targetSymbols.length} symbols × per-day '
      'TWSE+TPEx batch',
    );
    final phaseStart = DateTime.now();
    final targetSet = targetSymbols.toSet();
    final failedDays = <String>[];
    var rowsInserted = 0;
    var daysProcessed = 0;
    var daysSucceeded = 0;
    var lastLogAt = DateTime.now();

    final totalCalendarDays = endDate.difference(startDate).inDays;

    var current = startDate;
    while (!current.isAfter(endDate)) {
      if (!TaiwanCalendar.isTradingDay(current)) {
        current = current.add(const Duration(days: 1));
        continue;
      }

      final dayStr = _formatDate(current);
      try {
        final count = await deps.institutionalRepo.backfillInstitutionalByDate(
          date: current,
          targetSymbols: targetSet,
        );
        rowsInserted += count;
        daysSucceeded++;
      } on RateLimitException catch (e) {
        _log('⛔ Phase [institutional] $dayStr 觸發 API rate limit — abort: $e');
        rethrow;
      } on NetworkException catch (e) {
        _log('⛔ Phase [institutional] $dayStr 網路錯誤 — abort: $e');
        rethrow;
      } catch (e) {
        failedDays.add(dayStr);
        _log('  ⚠️  $dayStr failed: $e');
      }
      daysProcessed++;

      final now = DateTime.now();
      if (now.difference(lastLogAt).inSeconds >= 10 ||
          current.isAtSameMomentAs(endDate)) {
        final daysCovered = current.difference(startDate).inDays;
        final pct = totalCalendarDays == 0
            ? '0.0'
            : (daysCovered / totalCalendarDays * 100).toStringAsFixed(1);
        final elapsed = now.difference(phaseStart);
        _log(
          '  📊 [institutional] $daysProcessed trading days '
          '(through $dayStr, $pct% of calendar), '
          'elapsed ${_formatDuration(elapsed)}, '
          'rows=$rowsInserted, failed=${failedDays.length}',
        );
        lastLogAt = now;
      }

      // 避開 TWSE IP-based rate limit（同樣端點上次跑 2.5 req/sec 就被 ban）
      if (config.interDayDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: config.interDayDelayMs));
      }
      current = current.add(const Duration(days: 1));
    }

    final duration = DateTime.now().difference(phaseStart);
    return PhaseResult(
      phase: 'institutional',
      // Per-day 模式：用 daysProcessed 填 symbolsProcessed（同
      // _backfillTpexPricesBatch 慣例）
      symbolsProcessed: daysProcessed,
      symbolsSucceeded: daysSucceeded,
      rowsInserted: rowsInserted,
      // failedSymbols 此處為失敗的日期字串
      failedSymbols: failedDays,
      duration: duration,
    );
  }

  /// 連續 N 個交易日 fetch 回 0 rows 即 abort 該 phase。
  ///
  /// 正常交易日全市場批次不可能連續多天 0 筆（假日已被 TaiwanCalendar
  /// 濾掉）——連續 0 的唯一合理解釋是端點失效（如 TWSE 2026-06 起
  /// STOCK_DAY_ALL 忽略 date 參數、repository 按請求日過濾後回 0）。
  /// fail-fast 免得每輪 retry 燒 3 小時 API 額度在死迴圈上。
  ///
  /// 注意：小 whitelist（少數冷門股）連續停牌數日可能誤觸發——phase 提早
  /// 結束但 per-symbol FinMind phase 仍會補該些候選股，影響有限。
  static const int _maxConsecutiveZeroDays = 3;

  /// TWSE 上市股票價格 batch backfill
  ///
  /// 對日期範圍內每個交易日呼叫 [IPriceRepository.backfillTwsePricesByDate]，
  /// 每天 1 次 TWSE STOCK_DAY_ALL?date=... 拿全市場上市股票價格，過濾後
  /// 寫入 DB。Pattern 與 [_backfillTpexPricesBatch] 對稱。
  Future<PhaseResult> _backfillTwsePricesBatch({
    required List<String> twseSymbols,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _log('');
    _log(
      '▶️  Phase [prices:twse] — ${twseSymbols.length} symbols × per-day batch',
    );
    final phaseStart = DateTime.now();
    final targetSet = twseSymbols.toSet();
    final failedDays = <String>[];
    var rowsInserted = 0;
    var daysProcessed = 0;
    var daysSucceeded = 0;
    var consecutiveZeroDays = 0;
    var lastLogAt = DateTime.now();

    final totalCalendarDays = endDate.difference(startDate).inDays;

    var current = startDate;
    while (!current.isAfter(endDate)) {
      if (!TaiwanCalendar.isTradingDay(current)) {
        current = current.add(const Duration(days: 1));
        continue;
      }

      final dayStr = _formatDate(current);

      // Resume：該日該市場已有足量 rows（≥80% target）→ 跳過、不打 API。
      // TWSE 限流窗口有限（每輪 ~30-40 分鐘），沒有 per-day skip 的話
      // retry 每輪都從頭重抓同一段、永遠推不到 abort 點之後。
      // 門檻 80%（而非 >0）是因為 FinMind per-symbol phase 也寫
      // daily_price：某日可能只有候選股子集的 rows，不能視為該市場已完成。
      final existing = await deps.db.countPricesByDateAndMarket(
        current,
        MarketCode.twse,
      );
      if (existing >= targetSet.length * 0.8) {
        daysSucceeded++;
        daysProcessed++;
        current = current.add(const Duration(days: 1));
        continue;
      }

      try {
        final count = await deps.priceRepo.backfillTwsePricesByDate(
          date: current,
          targetSymbols: targetSet,
        );
        rowsInserted += count;
        daysSucceeded++;
        if (count == 0) {
          consecutiveZeroDays++;
          if (consecutiveZeroDays >= _maxConsecutiveZeroDays) {
            _log(
              '⛔ Phase [prices:twse] 連續 $_maxConsecutiveZeroDays 個交易日 0 rows'
              '（最後: $dayStr）— abort phase。疑似端點失效 / date 參數被忽略'
              '（TWSE 2026-06 起 STOCK_DAY_ALL 已知不支援歷史查詢）',
            );
            failedDays.add('$dayStr(consecutive-zero-abort)');
            break;
          }
        } else {
          consecutiveZeroDays = 0;
        }
      } on RateLimitException catch (e) {
        _log('⛔ Phase [prices:twse] $dayStr 觸發 API rate limit — abort: $e');
        rethrow;
      } on NetworkException catch (e) {
        _log('⛔ Phase [prices:twse] $dayStr 網路錯誤 — abort: $e');
        rethrow;
      } catch (e) {
        failedDays.add(dayStr);
        _log('  ⚠️  $dayStr failed: $e');
      }
      daysProcessed++;

      final now = DateTime.now();
      if (now.difference(lastLogAt).inSeconds >= 10 ||
          current.isAtSameMomentAs(endDate)) {
        final daysCovered = current.difference(startDate).inDays;
        final pct = totalCalendarDays == 0
            ? '0.0'
            : (daysCovered / totalCalendarDays * 100).toStringAsFixed(1);
        final elapsed = now.difference(phaseStart);
        _log(
          '  📊 [prices:twse] $daysProcessed trading days '
          '(through $dayStr, $pct% of calendar), '
          'elapsed ${_formatDuration(elapsed)}, '
          'rows=$rowsInserted, failed=${failedDays.length}',
        );
        lastLogAt = now;
      }

      // 避開 TWSE IP-based rate limit（同樣端點上次跑 2.5 req/sec 就被 ban）
      if (config.interDayDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: config.interDayDelayMs));
      }
      current = current.add(const Duration(days: 1));
    }

    final duration = DateTime.now().difference(phaseStart);
    return PhaseResult(
      phase: 'prices:twse',
      // Per-day 模式：用 daysProcessed 填 symbolsProcessed
      symbolsProcessed: daysProcessed,
      symbolsSucceeded: daysSucceeded,
      rowsInserted: rowsInserted,
      // failedSymbols 此處為失敗的日期字串
      failedSymbols: failedDays,
      duration: duration,
    );
  }

  /// TPEx 上櫃股票價格 batch backfill
  ///
  /// 對日期範圍內每個交易日呼叫 [IPriceRepository.backfillTpexPricesByDate]，
  /// 每天 1 次 API call 拿全市場上櫃股票價格，過濾後寫入 DB。
  ///
  /// 跟 [_runPhase] 同樣的 rate limit / network exception abort 政策；
  /// 其他例外記入 `failedSymbols`（以日期字串標記）繼續。
  Future<PhaseResult> _backfillTpexPricesBatch({
    required List<String> tpexSymbols,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _log('');
    _log(
      '▶️  Phase [prices:tpex] — ${tpexSymbols.length} symbols × per-day batch',
    );
    final phaseStart = DateTime.now();
    final targetSet = tpexSymbols.toSet();
    final failedDays = <String>[];
    var rowsInserted = 0;
    var daysProcessed = 0;
    var daysSucceeded = 0;
    var consecutiveZeroDays = 0;
    var lastLogAt = DateTime.now();

    final totalCalendarDays = endDate.difference(startDate).inDays;

    var current = startDate;
    while (!current.isAfter(endDate)) {
      if (!TaiwanCalendar.isTradingDay(current)) {
        current = current.add(const Duration(days: 1));
        continue;
      }

      final dayStr = _formatDate(current);

      // Resume：與 prices:twse 對稱的 per-day skip（見該處說明）
      final existing = await deps.db.countPricesByDateAndMarket(
        current,
        MarketCode.tpex,
      );
      if (existing >= targetSet.length * 0.8) {
        daysSucceeded++;
        daysProcessed++;
        current = current.add(const Duration(days: 1));
        continue;
      }

      try {
        final count = await deps.priceRepo.backfillTpexPricesByDate(
          date: current,
          targetSymbols: targetSet,
        );
        rowsInserted += count;
        daysSucceeded++;
        if (count == 0) {
          consecutiveZeroDays++;
          if (consecutiveZeroDays >= _maxConsecutiveZeroDays) {
            _log(
              '⛔ Phase [prices:tpex] 連續 $_maxConsecutiveZeroDays 個交易日 0 rows'
              '（最後: $dayStr）— abort phase。疑似端點失效 / date 參數被忽略'
              '（TWSE 2026-06 起 STOCK_DAY_ALL 已知不支援歷史查詢）',
            );
            failedDays.add('$dayStr(consecutive-zero-abort)');
            break;
          }
        } else {
          consecutiveZeroDays = 0;
        }
      } on RateLimitException catch (e) {
        _log('⛔ Phase [prices:tpex] $dayStr 觸發 API rate limit — abort: $e');
        rethrow;
      } on NetworkException catch (e) {
        _log('⛔ Phase [prices:tpex] $dayStr 網路錯誤 — abort: $e');
        rethrow;
      } catch (e) {
        failedDays.add(dayStr);
        _log('  ⚠️  $dayStr failed: $e');
      }
      daysProcessed++;

      final now = DateTime.now();
      if (now.difference(lastLogAt).inSeconds >= 10 ||
          current.isAtSameMomentAs(endDate)) {
        final daysCovered = current.difference(startDate).inDays;
        final pct = totalCalendarDays == 0
            ? '0.0'
            : (daysCovered / totalCalendarDays * 100).toStringAsFixed(1);
        final elapsed = now.difference(phaseStart);
        _log(
          '  📊 [prices:tpex] $daysProcessed trading days '
          '(through $dayStr, $pct% of calendar), '
          'elapsed ${_formatDuration(elapsed)}, '
          'rows=$rowsInserted, failed=${failedDays.length}',
        );
        lastLogAt = now;
      }

      // 跟 prices:twse / institutional 對稱 — 避免任何 batch endpoint 觸發
      // IP-based rate limit。TPEx OpenAPI 較寬鬆但保持同步驟簡化推理。
      if (config.interDayDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: config.interDayDelayMs));
      }
      current = current.add(const Duration(days: 1));
    }

    final duration = DateTime.now().difference(phaseStart);
    return PhaseResult(
      phase: 'prices:tpex',
      // 這個 phase 是 per-day 模式：用 daysProcessed 填 symbolsProcessed
      // 讓 toString() 的失敗率計算對應「失敗的天數 / 處理過的天數」。
      symbolsProcessed: daysProcessed,
      symbolsSucceeded: daysSucceeded,
      rowsInserted: rowsInserted,
      // failedSymbols 此處實為失敗的日期字串 — 讀 log 看上下文容易理解
      failedSymbols: failedDays,
      duration: duration,
    );
  }

  /// 用 FinMind TaiwanStockPrice 逐檔回補歷史價格（上市 + 上櫃皆可）。
  ///
  /// 動機：TWSE STOCK_DAY_ALL batch 端點 2026-06 起不再支援歷史 date 參數
  /// （一律回最新交易日），舊的 TWSE per-symbol 月度端點則 rate-limit 嚴重。
  /// FinMind getDailyPrices 一個 call 帶整段 date range、per-symbol，是歷史
  /// 回補唯一可行來源。
  ///
  /// rate limit / network 政策同 [_runPhase]：立即 abort；其他例外記 failed
  /// 後續行。每檔之間沿用 [BackfillConfig.interDayDelayMs] delay 控 FinMind
  /// 600/hr 額度。
  Future<PhaseResult> _backfillPricesViaFinMind({
    required List<String> symbols,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final finMind = deps.finMind;
    _log('');
    _log(
      '▶️  Phase [prices:finmind] — ${symbols.length} symbols × FinMind range',
    );
    final phaseStart = DateTime.now();
    if (finMind == null) {
      _log('⚠️  [prices:finmind] 無 FinMindClient 注入 — 跳過');
      return PhaseResult(
        phase: 'prices:finmind',
        symbolsProcessed: 0,
        symbolsSucceeded: 0,
        rowsInserted: 0,
        failedSymbols: const [],
        duration: DateTime.now().difference(phaseStart),
      );
    }

    final startStr = _formatDate(startDate);
    final endStr = _formatDate(endDate);

    // Resumability：跳過已補過該區間的 symbol（前次 run 完成的）。閾值 > 100
    // 列以排除既有稀疏樣本（原 calibration.db 每股僅數列），只認「完整回補過」。
    // ISO date 字串可直接字典序比較（DB 存 ISO text）。
    final endExclusive = _formatDate(endDate.add(const Duration(days: 1)));
    final doneRows = await deps.db
        .customSelect(
          'SELECT symbol FROM daily_price '
          "WHERE date >= '$startStr' AND date < '$endExclusive' "
          'GROUP BY symbol HAVING COUNT(*) > 100',
        )
        .get();
    final doneSymbols = doneRows.map((r) => r.read<String>('symbol')).toSet();
    if (doneSymbols.isNotEmpty) {
      _log('  ↪️  resumability: 跳過 ${doneSymbols.length} 個已完成 symbol');
    }

    final failed = <String>[];
    var succeeded = 0;
    var rowsInserted = 0;
    var skipped = 0;
    var lastLogAt = DateTime.now();

    for (var i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];
      if (doneSymbols.contains(symbol)) {
        skipped++;
        succeeded++;
        continue;
      }
      try {
        final fps = await finMind.getDailyPrices(
          stockId: symbol,
          startDate: startStr,
          endDate: endStr,
        );
        final companions = <DailyPriceCompanion>[];
        for (final fp in fps) {
          final date = DateTime.tryParse(fp.date);
          if (date == null) continue;
          companions.add(
            DailyPriceCompanion.insert(
              symbol: symbol,
              date: date,
              open: Value(fp.open),
              high: Value(fp.high),
              low: Value(fp.low),
              close: Value(fp.close),
              volume: Value(fp.volume),
            ),
          );
        }
        if (companions.isNotEmpty) {
          await deps.db.insertPrices(companions);
          rowsInserted += companions.length;
        }
        succeeded++;
      } on RateLimitException catch (e) {
        _log('⛔ Phase [prices:finmind] $symbol 觸發 rate limit — abort: $e');
        rethrow;
      } on NetworkException catch (e) {
        _log('⛔ Phase [prices:finmind] $symbol 網路錯誤 — abort: $e');
        rethrow;
      } catch (e) {
        failed.add(symbol);
        _log('  ⚠️  $symbol failed: $e');
      }

      final now = DateTime.now();
      if (now.difference(lastLogAt).inSeconds >= 10 ||
          i == symbols.length - 1) {
        final pct = ((i + 1) / symbols.length * 100).toStringAsFixed(1);
        _log(
          '  📊 [prices:finmind] ${i + 1}/${symbols.length} ($pct%), '
          'rows=$rowsInserted, skipped=$skipped, failed=${failed.length}, '
          'elapsed ${_formatDuration(now.difference(phaseStart))}',
        );
        lastLogAt = now;
      }

      // FinMind 600/hr 額度 → 控速（與 batch 端點共用 delay 旋鈕）
      if (config.interDayDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: config.interDayDelayMs));
      }
    }

    return PhaseResult(
      phase: 'prices:finmind',
      symbolsProcessed: symbols.length,
      symbolsSucceeded: succeeded,
      rowsInserted: rowsInserted,
      failedSymbols: failed,
      duration: DateTime.now().difference(phaseStart),
    );
  }

  void _logDryRunPlan(List<String> symbols) {
    _log('');
    _log('DRY RUN PLAN:');
    _log('  DB path: ${config.dbPath}');
    _log('  Years: ${config.years}');
    _log('  Symbols: ${symbols.length}');
    _log(
      '  Phases: prices:twse, prices:tpex (per-day batch), '
      'institutional (per-day batch), revenue, financial, valuation',
    );
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
      finMind: finMind,
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
  DateTime? startDateOverride;
  DateTime? endDateOverride;
  var pricesViaFinMind = false;
  var skipFundamentals = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--db':
        if (i + 1 >= args.length) return null;
        dbPath = args[++i];
      case '--prices-via-finmind':
        // 歷史回補必用：STOCK_DAY_ALL batch 已不支援歷史日期
        pricesViaFinMind = true;
      case '--skip-fundamentals':
        skipFundamentals = true;
      case '--years':
        if (i + 1 >= args.length) return null;
        final parsed = int.tryParse(args[++i]);
        if (parsed == null || parsed < 1) {
          stderr.writeln('❌ Invalid --years: must be positive integer');
          return null;
        }
        years = parsed;
      case '--start-date':
        if (i + 1 >= args.length) return null;
        startDateOverride = DateTime.tryParse(args[++i]);
        if (startDateOverride == null) {
          stderr.writeln('❌ Invalid --start-date: expected YYYY-MM-DD');
          return null;
        }
      case '--end-date':
        if (i + 1 >= args.length) return null;
        endDateOverride = DateTime.tryParse(args[++i]);
        if (endDateOverride == null) {
          stderr.writeln('❌ Invalid --end-date: expected YYYY-MM-DD');
          return null;
        }
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

  // start/end override 健全性檢查
  if (startDateOverride != null &&
      endDateOverride != null &&
      !startDateOverride.isBefore(endDateOverride)) {
    stderr.writeln('❌ --start-date 必須早於 --end-date');
    return null;
  }

  // env var override 讓你在不改 code 下實驗 rate limit 容忍度
  final delayOverride = Platform.environment['BACKFILL_INTER_DAY_DELAY_MS'];
  final interDayDelayMs = delayOverride != null
      ? (int.tryParse(delayOverride) ?? 5000)
      : 5000;

  return BackfillConfig(
    dbPath: dbPath,
    years: years,
    finMindToken: finMindToken,
    symbolsWhitelist: symbolsWhitelist,
    dryRun: dryRun,
    interDayDelayMs: interDayDelayMs,
    startDateOverride: startDateOverride,
    endDateOverride: endDateOverride,
    pricesViaFinMind: pricesViaFinMind,
    skipFundamentals: skipFundamentals,
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
    '  --start-date <date>   Explicit start YYYY-MM-DD (overrides --years)',
  );
  sink.writeln(
    '  --end-date <date>     Explicit end YYYY-MM-DD (default: now)',
  );
  sink.writeln(
    '  --prices-via-finmind  Historical prices via FinMind per-symbol '
    '(required\n'
    '                        for history; STOCK_DAY_ALL batch no longer serves\n'
    '                        historical dates)',
  );
  sink.writeln(
    '  --finmind-token       FinMind API token (or set FINMIND_TOKEN env var)',
  );
  sink.writeln(
    '  --symbols <csv>       Whitelist symbols, e.g. "2330,2317,2454"',
  );
  sink.writeln('  --dry-run             Print plan without fetching');
  sink.writeln('  --help, -h            Show this help');
}

/// 依市場別分組的 symbol 子集
class _MarketPartition {
  const _MarketPartition({required this.twse, required this.tpex});
  final List<String> twse;
  final List<String> tpex;
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
