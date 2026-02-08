import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/constants/stock_patterns.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 從市場資料快篩候選股（泛型版本）
///
/// 共用過濾邏輯：
/// - 跳過缺少關鍵資料的股票
/// - 過濾無效股票代碼（權證、TDR 等）
/// - 過濾極低成交量股票
/// - 依波動度排序
List<String> quickFilterPrices<T>(
  List<T> prices, {
  required String Function(T) getCode,
  required double? Function(T) getClose,
  required double? Function(T) getChange,
  required double? Function(T) getVolume,
}) {
  final candidates = <_QuickCandidate>[];

  for (final price in prices) {
    final code = getCode(price);
    final close = getClose(price);
    final change = getChange(price);
    final volume = getVolume(price);

    // 跳過缺少關鍵資料的股票
    if (close == null || close <= 0) continue;
    if (change == null) continue;

    // 過濾無效股票代碼（權證、TDR 等）
    if (!StockPatterns.isValidCode(code)) continue;

    // 計算漲跌幅
    final prevClose = close - change;
    if (prevClose <= 0) continue;

    // 過濾：跳過極低成交量股票（< 50 張）
    if ((volume ?? 0) < RuleParams.minQuickFilterVolumeShares) continue;

    // 全市場策略：納入所有活躍股票，不論漲跌幅
    final changePercent = (change / prevClose).abs() * 100;
    candidates.add(_QuickCandidate(symbol: code, score: changePercent));
  }

  // 依波動度排序
  candidates.sort((a, b) => b.score.compareTo(a.score));

  return candidates.map((c) => c.symbol).toList();
}

/// 從 Database 快篩候選股（當跳過 API 時使用）
///
/// 類似 [quickFilterPrices]，但從本地 Database 讀取，
/// 而非 API 回應。當已有今日資料時使用。
Future<List<String>> quickFilterCandidatesFromDb(
  AppDatabase db,
  DateTime date,
) async {
  final prices = await db.getPricesForDate(date);
  if (prices.isEmpty) return [];

  final symbols = <String>[];

  for (final price in prices) {
    final close = price.close;
    if (close == null || close <= 0) continue;
    if (!StockPatterns.isValidCode(price.symbol)) continue;
    if ((price.volume ?? 0) < RuleParams.minQuickFilterVolumeShares) continue;

    symbols.add(price.symbol);
  }

  return symbols;
}

class _QuickCandidate {
  const _QuickCandidate({required this.symbol, required this.score});
  final String symbol;
  final double score;
}
