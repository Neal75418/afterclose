import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 詳情頁「上一檔/下一檔」導航所需的鄰居資訊
typedef BrowsingNeighbors = ({
  String? prev,
  String? next,
  int position, // 1-based
  int total,
});

/// 由瀏覽脈絡推導目前 symbol 的鄰居
///
/// 回 null 代表不顯示導航列：symbol 不在脈絡中（搜尋/深連結/詳情頁內
/// 連結進入）、脈絡為空、或清單只有單檔（無可導航對象）。
BrowsingNeighbors? browsingNeighbors(List<String> symbols, String current) {
  if (symbols.length < 2) return null;
  final i = symbols.indexOf(current);
  if (i < 0) return null;
  return (
    prev: i > 0 ? symbols[i - 1] : null,
    next: i < symbols.length - 1 ? symbols[i + 1] : null,
    position: i + 1,
    total: symbols.length,
  );
}

/// 瀏覽脈絡：使用者從哪個清單點進詳情頁、該清單的有序 symbols
///
/// 清單頁（自選/今日/掃描/族群成員…共 13 個入口）在 push 詳情前呼叫
/// [StockBrowsingContext.set]；詳情頁底部導航列據此提供上一檔/下一檔
/// （`_swapTo` 原地換股、route 不動，返回鍵仍回到來源清單）。
///
/// 不需顯式 clear：脈絡只在「目前 symbol ∈ 清單」時生效
/// （[browsingNeighbors] 回 null 即隱藏），過期脈絡無害。
class StockBrowsingContext extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void set(List<String> symbols) => state = List.unmodifiable(symbols);
}

final stockBrowsingContextProvider =
    NotifierProvider<StockBrowsingContext, List<String>>(
      StockBrowsingContext.new,
    );
