/// 產業強弱評分服務
///
/// 將各產業的動能（20D 報酬）轉成**百分位排名 [0, 1]**，供選股排序的「產業領導」
/// 加分 factor（rank-blend）使用。1.0 = 最強族群、0.0 = 最弱、0.5 = 中位。
///
/// 用百分位（而非絕對報酬）以避免報酬尺度問題、讓不同市況下 tilt 權重一致。
class SectorStrengthService {
  /// 將「產業 → 動能指標」轉成「產業 → 百分位排名 [0, 1]」。
  ///
  /// - 空輸入 → 空 map
  /// - 單一產業 → 0.5（中性，無從相對排名）
  /// - 同值（tie）→ 給相同的平均位置百分位（避免 tie 隨機分高下）
  Map<String, double> rankByPercentile(Map<String, double> industryMomentum) {
    final n = industryMomentum.length;
    if (n == 0) return const <String, double>{};
    if (n == 1) return {industryMomentum.keys.first: 0.5};

    // 依動能升冪排序（最弱在前）
    final sorted = industryMomentum.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final result = <String, double>{};
    var i = 0;
    while (i < n) {
      // 找出與 sorted[i] 同值的連續區段 [i, j]
      var j = i;
      while (j + 1 < n && sorted[j + 1].value == sorted[i].value) {
        j++;
      }
      // 同值區段給相同的平均位置百分位
      final avgIndex = (i + j) / 2.0;
      final percentile = avgIndex / (n - 1);
      for (var k = i; k <= j; k++) {
        result[sorted[k].key] = percentile;
      }
      i = j + 1;
    }
    return result;
  }

  /// 對一組候選股做 rank-blend，回傳 symbol → finalScore（高 = 排前）。
  ///
  /// `finalScore = (1 − weight)·baseRank + weight·sectorRank`
  /// - **baseRank**：該股 base 排序值（mode 原排序鍵）在組內的百分位
  /// - **sectorRank**：該股所屬產業的強弱百分位（無產業 / 無資料 → 0.5 中性）
  ///
  /// 用 rank-blend（百分位加權）而非「分數 × (1+權重)」：base 排序鍵（如 60D
  /// 報酬）會出現負值，乘法在負值上行為錯亂；百分位皆 [0,1]、加權穩健。
  /// weight=0 時 finalScore == baseRank（純基本排序，零產業影響）。
  Map<String, double> sectorTiltedScores({
    required Map<String, double> baseKeyBySymbol,
    required Map<String, String?> industryBySymbol,
    required Map<String, double> industryStrength,
    required double weight,
  }) {
    final baseRank = rankByPercentile(baseKeyBySymbol);
    final result = <String, double>{};
    for (final symbol in baseKeyBySymbol.keys) {
      final br = baseRank[symbol] ?? 0.5;
      final industry = industryBySymbol[symbol];
      final sr = (industry != null ? industryStrength[industry] : null) ?? 0.5;
      result[symbol] = (1 - weight) * br + weight * sr;
    }
    return result;
  }
}
