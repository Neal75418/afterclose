/// 族群排行資料模型（今日頁族群 section 顯示用）
library;

/// 排行的動能視窗：20日＝輪動主視角、5日＝轉折視角
///
/// 2026-07-22 使用者實機回饋：電子族群 20日修正墊底、反彈第一天完全
/// 進不了前八——5日視窗讓「20日弱但正在翻強」的轉折族群被看到。
enum RankingWindow { d20, d5 }

/// 產業內的領漲成員
class IndustryMember {
  const IndustryMember({
    required this.symbol,
    required this.name,
    required this.retPct,
  });

  final String symbol;

  /// 股票名稱；stock_master 查無時為空字串（UI 以 symbol 呈現）
  final String name;

  /// 選定視窗（[RankingWindow]）的報酬（%）
  final double retPct;
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

  /// 產業動能：成員**選定視窗**報酬的**中位數**（%）。20日視窗與
  /// computeIndustryMomentum 同口徑
  final double momentumPct;

  /// 有選定視窗報酬資料的成員數
  final int memberCount;

  /// 外資+投信近 [SectorParams.rankingInstitutionalDays] 交易日合計淨買賣（股）
  final double institutionalNetShares;

  /// 領漲成員（選定視窗報酬 DESC，上限 [SectorParams.rankingTopMembersCount]）
  final List<IndustryMember> topMembers;
}
