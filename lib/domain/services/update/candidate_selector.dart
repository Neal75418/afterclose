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
  static const int _historyLoadBuffer = 20;

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

    final allAnalyzableSet = allAnalyzable.toSet();
    final orderedCandidates = <String>{};

    // 1. 自選清單優先
    for (final symbol in watchlistSymbols) {
      if (allAnalyzableSet.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 2. 熱門股第二
    for (final symbol in _popularStocks) {
      if (allAnalyzableSet.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 3. 市場候選股第三
    for (final symbol in marketCandidates) {
      if (allAnalyzableSet.contains(symbol)) {
        orderedCandidates.add(symbol);
      }
    }

    // 4. 其餘可分析股票
    for (final symbol in allAnalyzableSet) {
      orderedCandidates.add(symbol);
    }

    AppLogger.info('UpdateSvc', '步驟 6: 篩選 ${orderedCandidates.length} 檔');
    return orderedCandidates.toList();
  }
}
