/// 族群排行資料模型（今日頁族群 section 顯示用）
library;

/// 產業內的領漲成員
class IndustryMember {
  const IndustryMember({
    required this.symbol,
    required this.name,
    required this.ret20Pct,
  });

  final String symbol;

  /// 股票名稱；stock_master 查無時為空字串（UI 以 symbol 呈現）
  final String name;

  /// 20 交易日報酬（%）
  final double ret20Pct;
}

/// 單一產業的排行項目
class IndustryRanking {
  const IndustryRanking({
    required this.industry,
    required this.momentumPct,
    required this.memberCount,
    required this.institutionalNetShares,
    required this.topMembers,
  });

  final String industry;

  /// 產業動能：成員 20D 報酬**中位數**（%），與 computeIndustryMomentum 同口徑
  final double momentumPct;

  /// 有 20D 報酬資料的成員數
  final int memberCount;

  /// 外資+投信近 [SectorParams.rankingInstitutionalDays] 交易日合計淨買賣（股）
  final double institutionalNetShares;

  /// 領漲成員（20D 報酬 DESC，上限 [SectorParams.rankingTopMembersCount]）
  final List<IndustryMember> topMembers;
}
