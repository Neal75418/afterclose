// lib/domain/services/news/stock_name_matcher.dart
import 'package:daredevil/core/constants/news_heat_params.dart';
import 'package:daredevil/data/database/app_database.dart';

/// 從新聞標題匹配公司簡稱 → 股票代碼（純函數）
///
/// 規則（依語料實證設計，見 spec）：
/// - 名稱長度 ≥ 3：全部納入；長度 = 2：僅 [NewsHeatParams.twoCharNameWhitelist]
/// - 最長優先＋位置消耗：「長榮航」命中後佔用字元，「長榮」不重複計分
/// - 同篇多次出現計 1（回傳 Set）
///
/// ⚠️ 匹配結果僅供熱度分析與快照，**不得寫入 news_stock_map**（不進評分）。
class StockNameMatcher {
  StockNameMatcher._(this._entries);

  /// (名稱, 代碼)，已按名稱長度降冪排序
  final List<(String, String)> _entries;

  factory StockNameMatcher.fromStocks(List<StockMasterEntry> stocks) {
    // 別名覆蓋(2026-08-01):媒體通用簡稱與現行官方名稱不同字串時
    // (日月光→3711 日月光投控),別名指向本尊——殭屍同名代碼(2311)
    // 在冊期間不得吸走匹配,殭屍清理後裸名也不落空。目標不在宇宙時
    // 回退自然名,別名不得讓名稱憑空消失。
    final symbols = {for (final s in stocks) s.symbol};
    final activeAliases = {
      for (final e in NewsHeatParams.nameAliasToSymbol.entries)
        if (symbols.contains(e.value)) e.key: e.value,
    };

    final entries = <(String, String)>[];
    for (final s in stocks) {
      final name = s.name.trim();
      if (activeAliases.containsKey(name)) continue; // 別名蓋過同名自然入口
      if (name.length >= 3 ||
          (name.length == 2 &&
              NewsHeatParams.twoCharNameWhitelist.contains(name))) {
        entries.add((name, s.symbol));
      }
    }
    activeAliases.forEach((name, symbol) => entries.add((name, symbol)));
    entries.sort((a, b) {
      final lenCmp = b.$1.length.compareTo(a.$1.length);
      if (lenCmp != 0) return lenCmp;
      return a.$1.compareTo(b.$1); // tie-break by dictionary order ascending
    });
    return StockNameMatcher._(entries);
  }

  /// 回傳標題中提及的股票代碼集合
  Set<String> match(String title) {
    final claimed = List<bool>.filled(title.length, false);
    final result = <String>{};
    for (final (name, symbol) in _entries) {
      var from = 0;
      while (true) {
        final idx = title.indexOf(name, from);
        if (idx < 0) break;
        var free = true;
        for (var i = idx; i < idx + name.length; i++) {
          if (claimed[i]) {
            free = false;
            break;
          }
        }
        if (free) {
          for (var i = idx; i < idx + name.length; i++) {
            claimed[i] = true;
          }
          result.add(symbol);
        }
        from = idx + 1;
      }
    }
    return result;
  }
}
