import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 候選股票篩選服務
///
/// 從資料庫篩選有足夠歷史資料的股票，
/// 並依優先順序排列（自選 > 熱門 > 市場候選 > 其餘）。
/// 從 UpdateService 提取以降低複雜度。
class CandidateSelector {
  CandidateSelector({
    required AppDatabase database,
    required List<String> popularStocks,
  }) : _db = database,
       _popularStocks = popularStocks;

  final AppDatabase _db;
  final List<String> _popularStocks;

  /// 提前載入的緩衝天數（確保有足夠歷史資料用於技術指標計算）
  static const int _historyLoadBuffer = RuleParams.historyLoadBuffer;

  /// 篩選並排序候選股票
  ///
  /// 回傳依優先順序排列的股票代碼清單：
  /// 1. 自選清單
  /// 2. 熱門股
  /// 3. 市場候選股（當日價格篩選）
  /// 4. 其餘可分析股票
  Future<List<String>> filterCandidates({
    required DateTime date,
    required List<String> marketCandidates,
  }) async {
    final historyStartDate = date.subtract(
      const Duration(days: RuleParams.historyRequiredDays - _historyLoadBuffer),
    );
    final allAnalyzable = await _db.getSymbolsWithSufficientData(
      minDays: RuleParams.swingWindow,
      startDate: historyStartDate,
      endDate: date,
    );

    final watchlist = await _db.getWatchlist();
    final watchlistSymbols = watchlist.map((w) => w.symbol).toSet();

    // 流動性下限（評分改進 #4）：訊號必須可交易，薄流動性股的滑價會吃掉
    // edge。map 內沒有的 symbol = 資料不足無法判定 → permissive 放行。
    final medianTurnover = await _db.getMedianTurnoverBatch(
      endDate: date,
      windowDays: RuleParams.liquidityMedianWindowDays,
      minDataDays: RuleParams.liquidityMinDataDays,
    );
    bool isLiquid(String symbol) {
      final median = medianTurnover[symbol];
      return median == null ||
          median >= RuleParams.liquidityMinMedianTurnoverNtd;
    }

    final allAnalyzableSet = allAnalyzable.toSet();
    final orderedCandidates = <String>{};

    // 1. 自選清單優先（豁免流動性過濾 — 使用者主動追蹤）
    for (final symbol in watchlistSymbols) {
      if (allAnalyzableSet.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 2. 熱門股第二
    for (final symbol in _popularStocks) {
      if (allAnalyzableSet.contains(symbol) && isLiquid(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 3. 市場候選股第三
    for (final symbol in marketCandidates) {
      if (allAnalyzableSet.contains(symbol) && isLiquid(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 4. 其餘可分析股票（Set 成員性已保住前三類，含豁免的自選股）
    for (final symbol in allAnalyzableSet) {
      if (isLiquid(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    final dropped = allAnalyzableSet.length - orderedCandidates.length;
    AppLogger.info(
      'CandidateSelector',
      '篩選 ${orderedCandidates.length} 檔候選股'
          '（流動性下限濾除 ~$dropped 檔）',
    );
    return orderedCandidates.toList();
  }
}
