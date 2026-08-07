/// 盤中即時報價(TWSE MIS `getStockInfo.jsp`,2026-08-08)。
///
/// 這支 API 的欄位名極短且**無成交時價格欄是 `'-'`**——盤前、冷門股、
/// 剛開盤那幾秒都會遇到。價格取用順序 z(成交)→ pz(試撮)→ o(開盤)
/// → y(昨收),寧可回昨收也不要回 0(0 會讓所有「跌破」提醒瞬間觸發)。
class IntradayQuote {
  const IntradayQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.previousClose,
    this.open,
    this.high,
    this.low,
    this.volume,
    this.time,
  });

  final String symbol;
  final String name;

  /// 現價(見類別註解的退回順序)
  final double price;
  final double previousClose;
  final double? open;
  final double? high;
  final double? low;

  /// 累計成交量(張)
  final int? volume;

  /// 報價時刻(HH:mm:ss)
  final String? time;

  double get changePercent =>
      previousClose > 0 ? (price / previousClose - 1) * 100 : 0;

  /// 解析整份回應 → symbol 對報價。rtcode 非 0000 或格式異常一律回空
  /// ——**把失敗當成沒有報價,而不是當成某個價格**。
  static Map<String, IntradayQuote> parseResponse(Map<String, dynamic> json) {
    if (json['rtcode'] != '0000') return const {};
    final rows = json['msgArray'];
    if (rows is! List) return const {};

    final result = <String, IntradayQuote>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final symbol = row['c']?.toString().trim() ?? '';
      if (symbol.isEmpty) continue;

      final prevClose = _num(row['y']);
      if (prevClose == null || prevClose <= 0) continue;

      final price =
          _num(row['z']) ?? _num(row['pz']) ?? _num(row['o']) ?? prevClose;

      result[symbol] = IntradayQuote(
        symbol: symbol,
        name: row['n']?.toString() ?? '',
        price: price,
        previousClose: prevClose,
        open: _num(row['o']),
        high: _num(row['h']),
        low: _num(row['l']),
        volume: int.tryParse(row['v']?.toString() ?? ''),
        time: row['t']?.toString(),
      );
    }
    return result;
  }

  /// MIS 用 `'-'` 表示「無此值」,parse 失敗與非正數一律當缺值
  static double? _num(Object? v) {
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty || s == '-') return null;
    final d = double.tryParse(s);
    return (d != null && d > 0) ? d : null;
  }
}
