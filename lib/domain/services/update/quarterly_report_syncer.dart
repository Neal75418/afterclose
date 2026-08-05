import 'package:drift/drift.dart';

import 'package:afterclose/core/exceptions/app_exception.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';

/// 季報同步器(2026-08-06 最新一季財報總覽)。
///
/// 從 TWSE(t187ap06_L_*)與 TPEx(mopsfin_t187ap06_O_*)取得最新一季
/// 綜合損益表快照,寫入 QuarterlyReport 表。公布期(4~5 月/7~8 月/
/// 10~11 月/1~3 月)端點逐日填充,平時回傳最後完整季——每次更新都同步,
/// 總覽頁因此恆有資料:公布期看進度、平時看完整清單。
///
/// 契約鏡射 [InsiderTransferSyncer]:
/// - 雙源 per-source 隔離:單側故障記 warning、另一側照常;兩側都掛才拋
/// - RateLimitException 一律直接 rethrow(全域狀態)
/// - 僅寫入 StockMaster 已知股票(FK constraint)
class QuarterlyReportSyncer {
  const QuarterlyReportSyncer({
    required AppDatabase database,
    TwseClient? twseClient,
    TpexClient? tpexClient,
  }) : _db = database,
       _twse = twseClient,
       _tpex = tpexClient;

  final AppDatabase _db;

  /// 兩源可各自為 null(測試/降級 harness);生產接線恆為雙源。
  final TwseClient? _twse;
  final TpexClient? _tpex;

  /// 同步季報資料,回傳寫入筆數。
  Future<int> sync() async {
    final entries = <QuarterlyReportEntry>[];
    Object? firstError;
    final fetchers = <String, Future<List<QuarterlyReportEntry>> Function()>{
      if (_twse != null) '上市': _twse.getQuarterlyReports,
      if (_tpex != null) '上櫃': _tpex.getQuarterlyReports,
    };
    if (fetchers.length < 2) {
      AppLogger.debug(
        'QuarterlyReportSyncer',
        '僅 ${fetchers.keys.join()} 源可用(另一側未接線)',
      );
    }
    for (final entry in fetchers.entries) {
      try {
        entries.addAll(await entry.value());
      } on RateLimitException {
        rethrow;
      } catch (e) {
        AppLogger.warning('QuarterlyReportSyncer', '${entry.key}源失敗,另一側照常', e);
        firstError ??= e;
      }
    }
    if (entries.isEmpty) {
      if (firstError != null) throw firstError;
      AppLogger.debug('QuarterlyReportSyncer', 'API 回傳空資料');
      return 0;
    }

    // 僅寫入 DB 已知股票(FK constraint);興櫃/新掛牌落差直接丟棄
    final knownStocks = await _db.getAllActiveStocks();
    final knownSymbols = knownStocks.map((s) => s.symbol).toSet();

    final companions = <QuarterlyReportCompanion>[
      for (final e in entries)
        if (knownSymbols.contains(e.symbol))
          QuarterlyReportCompanion(
            symbol: Value(e.symbol),
            year: Value(e.year),
            quarter: Value(e.quarter),
            eps: Value(e.eps),
            netIncome: Value(e.netIncome),
            revenue: Value(e.revenue),
          ),
    ];

    if (companions.isEmpty) {
      AppLogger.debug('QuarterlyReportSyncer', '無可寫入的季報資料');
      return 0;
    }

    await _db.insertQuarterlyReports(companions);
    AppLogger.info(
      'QuarterlyReportSyncer',
      '季報同步完成: ${companions.length} 筆'
          '(來源 ${entries.length} 筆,過濾未知代號 '
          '${entries.length - companions.length})',
    );
    return companions.length;
  }
}
