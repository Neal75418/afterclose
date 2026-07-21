/// 月營收統計工具。
///
/// 使用者選股法則的基本面門檻採「年增取近 3 月均值，防單月雜訊」——
/// 本函式即該定義的實作，供詳情頁基本面分頁與其他顯示層共用。
library;

/// 一筆月營收的 (年, 月, 年增率%)。yoy 為 null 代表該月無法計算年增
/// （缺去年同月資料）。
typedef RevenueYoYPoint = ({int year, int month, double? yoy});

/// 近 3 月平均年增率（%）。
///
/// 規則語意「取近 3 月均值防單月雜訊」的嚴格版：
/// - 取**最新三個不同月份**（輸入順序無關；同月重複以後出現者覆寫）
/// - 不足三個月、或最新三月中任一月的 YoY 缺值 → 回傳 null（不硬湊，
///   缺值平均會靜默改變語意）
double? yoy3mAvg(Iterable<RevenueYoYPoint> points) {
  // 同月去重（後者覆寫），鍵 = year*100+month
  final byMonth = <int, double?>{};
  for (final p in points) {
    byMonth[p.year * 100 + p.month] = p.yoy;
  }
  if (byMonth.length < 3) return null;

  final keys = byMonth.keys.toList()..sort();
  final latest3 = keys.sublist(keys.length - 3);
  var sum = 0.0;
  for (final k in latest3) {
    final y = byMonth[k];
    if (y == null) return null;
    sum += y;
  }
  return sum / 3;
}
