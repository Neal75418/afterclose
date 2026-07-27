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
    this.excessPct,
    this.institutionalVolumeRatio,
    required this.advancingRatio,
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

  /// 超額報酬（%）：[momentumPct] − 同視窗大盤報酬。缺大盤資料時為 null。
  ///
  /// 輪動要問的是「誰比大盤強」，不是「誰漲了」。2026-07-27 實測大盤 20 日
  /// 為 **-2.10%**，此時居家生活類的 +0.23% 讀起來像「幾乎沒動」，實際是
  /// **跑贏 2.34pp**；榜上 12 個族群其實全部跑贏大盤。
  ///
  /// **缺資料時為 null 不是 0**——0 等於宣稱「大盤沒漲跌」，把缺資料講成事實。
  final double? excessPct;

  /// 法人淨買賣佔該族群同期成交量的比例（0~1，可為負）。缺成交量資料時 null。
  ///
  /// [institutionalNetShares] 的絕對值主要反映**族群規模**而非法人態度。
  /// 2026-07-27 實測：依張數是「金融保險 +18.9萬 > 電腦週邊 +16.1萬 >
  /// 鋼鐵 +9.8萬」，依佔比則是「**鋼鐵 32.6% > 水泥 25.7% > 紡織 16.2% >
  /// 金融保險 12.4%**」——排序完全不同。法人吃掉鋼鐵三日成交量的三分之一，
  /// 那才是真正被主導的族群。
  final double? institutionalVolumeRatio;

  /// 族群內報酬為正的成員佔比（0~1）。
  ///
  /// 中位數不揭露廣度：2026-07-27 實測橡膠工業中位 +3.5%／上漲佔比 **73%**
  /// （整族在動），「其他」中位 +0.7%／上漲佔比 **52%**（一半漲一半跌，
  /// 中位數由少數成員撐）。同一個排序下訊號品質天差地遠。
  final double advancingRatio;
}
