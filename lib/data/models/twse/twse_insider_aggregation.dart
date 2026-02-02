/// 彙總董監持股用的 helper class
class TwseInsiderAggregation {
  TwseInsiderAggregation({
    required this.code,
    required this.name,
    required this.date,
  });

  final String code;
  final String name;
  final DateTime date;
  double totalShares = 0;
  double totalPledged = 0;
  final _seenHolders = <String>{};

  void addHoldingIfNew(String holderName, double shares, double pledged) {
    if (holderName.isEmpty) return;
    if (_seenHolders.contains(holderName)) return;
    _seenHolders.add(holderName);
    totalShares += shares;
    totalPledged += pledged;
  }
}
