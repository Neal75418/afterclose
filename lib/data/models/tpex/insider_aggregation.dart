/// 彙總董監持股用的 helper class
class InsiderAggregation {
  InsiderAggregation({
    required this.code,
    required this.name,
    required this.date,
  });

  final String code;
  final String name;
  final DateTime date;
  double totalShares = 0;
  double totalPledged = 0;

  // 追蹤已計入的持股人（避免同一人重複計算）
  final _seenHolders = <String>{};

  /// 只有新的持股人才加入統計（去重）
  void addHoldingIfNew(String holderName, double shares, double pledged) {
    if (holderName.isEmpty) return;
    if (_seenHolders.contains(holderName)) return;

    _seenHolders.add(holderName);
    totalShares += shares;
    totalPledged += pledged;
  }
}
