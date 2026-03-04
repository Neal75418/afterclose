/// 各推薦類型的分數
///
/// 分數層級反映訊號可靠性：
/// - 反轉訊號 (35)：最高 - 趨勢改變最具操作價值
/// - 技術訊號 (25)：中等 - 壓力/支撐突破
/// - 成交量異動 (22)：中等 - 現需 4 倍量 + 1.5% 價格變動
/// - 價格異動 (15)：較低 - 無量配合可能是雜訊
/// - 法人買超 (18)：台股重要指標 - 法人資金流入
/// - 法人賣超 (-12)：空方扣分 - 法人資金流出
/// - 新聞 (8)：輔助 - 僅提供背景資訊
///
/// ## 分數校準原則
///
/// | 層級 | 分數範圍 | 訊號類型 | 校準依據 |
/// |------|---------|---------|---------|
/// | S | 35 | 反轉訊號 (W2S) | 趨勢改變最具操作價值 |
/// | A | 20–28 | 突破/K線/法人連買/52週高 | 有明確方向且經量確認 |
/// | B | 15–18 | 法人轉向/KD/外資/殖利率 | 單一維度但可靠 |
/// | C | 8–12 | 新聞/十字線/當沖/52週低 | 輔助訊號或中性 |
/// | 扣分 | −5 ~ −50 | 空方/風險訊號 | 處置股最重(−50)，技術空方中等(−12~−25) |
///
/// 最高分數限制為 80，避免多訊號造成分數膨脹。
abstract final class RuleScores {
  /// 最高分數上限
  static const int maxScore = 80;

  // ==================================================
  // 多方訊號（正分）
  // ==================================================

  /// 弱轉強分數（強多頭訊號）
  static const int reversalW2S = 35;

  /// 向上突破分數
  static const int techBreakout = 25;

  /// 成交量爆增分數
  static const int volumeSpike = 22;

  /// 價格急漲分數
  static const int priceSpike = 15;

  /// 法人買超轉向分數
  static const int institutionalShift = 18;

  /// 法人賣超轉向分數（空方訊號，扣分）
  static const int institutionalShiftSell = -12;

  /// 新聞相關分數
  static const int newsRelated = 8;

  /// 加分：突破 + 成交量異動
  static const int breakoutVolumeBonus = 10;

  /// 加分：反轉 + 成交量異動
  static const int reversalVolumeBonus = 10;

  /// 加分：法人 + 突破/反轉組合
  static const int institutionalComboBonus = 15;

  /// 加分：K 線型態（吞噬/星線/三兵）+ 成交量異動
  static const int patternVolumeBonus = 5;

  /// KD 黃金交叉分數（多方）
  static const int kdGoldenCross = 18;

  /// 法人連續買超分數（多方）
  static const int institutionalBuyStreak = 20;

  // ==================================================
  // 空方訊號（負分）- 扣分以降低推薦機率
  // ==================================================

  /// 強轉弱分數（空方訊號，扣分）
  static const int reversalS2W = -25;

  /// 向下跌破分數（空方訊號，扣分）
  static const int techBreakdown = -20;

  /// KD 死亡交叉分數（空方訊號，扣分）
  static const int kdDeathCross = -12;

  /// 法人連續賣超分數（空方訊號，扣分）
  static const int institutionalSellStreak = -15;

  // ==================================================
  // K 線型態分數（多空分離）
  // ==================================================

  /// 十字線分數 — 低檔（RSI < 30，偏多反轉）
  static const int patternDoji = 10;

  /// 十字線分數 — 高檔（RSI > 70，偏空警告）
  static const int patternDojiBearish = -5;

  /// 多頭吞噬分數（多方）
  static const int patternEngulfingBullish = 22;

  /// 空頭吞噬分數（空方，扣分）
  static const int patternEngulfingBearish = -18;

  /// 錘子線分數（多方，底部反轉）
  static const int patternHammerBullish = 18;

  /// 吊人線分數（空方，扣分）
  static const int patternHammerBearish = -12;

  /// 跳空上漲分數（多方）
  static const int patternGapUp = 20;

  /// 跳空下跌分數（空方，扣分）
  static const int patternGapDown = -15;

  /// 晨星分數（多方，底部反轉）
  static const int patternMorningStar = 25;

  /// 暮星分數（空方，扣分）
  static const int patternEveningStar = -20;

  /// 三白兵分數（多方）
  static const int patternThreeWhiteSoldiers = 22;

  /// 三黑鴉分數（空方，扣分）
  static const int patternThreeBlackCrows = -18;

  // ==================================================
  // 技術指標分數（第三階段）
  // ==================================================

  /// 52 週新高分數（強多頭）
  static const int week52High = 28;

  /// 52 週新低分數（逆勢買入機會，小正分）
  ///
  /// 搭配反轉訊號可能是底部，但單獨出現風險高。
  static const int week52Low = 8;

  /// 均線多頭排列分數（5>10>20>60）
  static const int maAlignmentBullish = 22;

  /// 均線空頭排列分數（空方，扣分）
  static const int maAlignmentBearish = -15;

  /// RSI 極度超買分數（警示訊號，小扣分）
  static const int rsiExtremeOverboughtSignal = -8;

  /// RSI 極度超賣分數（逆勢反彈機會，小正分）
  static const int rsiExtremeOversoldSignal = 10;

  // ==================================================
  // 第四階段：延伸市場資料分數
  // ==================================================

  /// 外資持股增加分數（多方）
  static const int foreignShareholdingIncreasing = 18;

  /// 外資持股減少分數（空方，扣分）
  static const int foreignShareholdingDecreasing = -12;

  /// 高當沖比例分數（熱門股，中性偏多）
  static const int dayTradingHigh = 12;

  /// 極高當沖比例分數（投機警示，小扣分）
  static const int dayTradingExtreme = -5;

  /// 高籌碼集中度分數（多方）
  static const int concentrationHigh = 16;

  // ==================================================
  // 第五階段：價量背離分數
  // ==================================================

  /// 價漲量縮背離分數（警示訊號，小扣分）
  static const int priceVolumeBullishDivergence = -8;

  /// 價跌量增背離分數（恐慌訊號，扣分）
  static const int priceVolumeBearishDivergence = -15;

  /// 高檔爆量突破分數（強多頭）
  static const int highVolumeBreakout = 22;

  /// 低檔吸籌分數（潛在反轉，多方）
  static const int lowVolumeAccumulation = 12;

  // ==================================================
  // 第六階段：基本面分析分數
  // ==================================================

  /// 營收年增暴增分數（強基本面）
  static const int revenueYoySurge = 20;

  /// 營收年減衰退分數（空方，扣分）
  static const int revenueYoyDecline = -10;

  /// 營收月增持續成長分數（多方）
  static const int revenueMomGrowth = 15;

  /// 營收創歷史新高分數（強基本面）
  static const int revenueNewHigh = 22;

  /// 高殖利率分數（多方）
  static const int highDividendYield = 18;

  /// 本益比低估分數（多方）
  static const int peUndervalued = 15;

  /// 本益比高估分數（空方，扣分）
  static const int peOvervalued = -8;

  /// 股價淨值比低估分數（多方）
  static const int pbrUndervalued = 12;

  // ==================================================
  // Killer Features 分數（注意/處置股、董監持股）
  // ==================================================

  /// 注意股票分數（警示訊號，扣分）
  static const int tradingWarningAttention = -15;

  /// 處置股票分數（高風險，大幅扣分）
  static const int tradingWarningDisposal = -50;

  /// 董監連續減持分數（強賣訊號，大幅扣分）
  static const int insiderSellingStreak = -25;

  /// 董監顯著增持分數（買進訊號）
  static const int insiderSignificantBuying = 20;

  /// 高質押比例分數（風險警示，扣分）
  static const int highPledgeRatio = -18;

  /// 外資持股高度集中分數（風險警示，小扣分）
  static const int foreignConcentrationWarning = -8;

  /// 外資加速流出分數（強賣訊號，扣分）
  static const int foreignExodus = -20;

  // ==================================================
  // EPS 規則分數
  // ==================================================

  /// EPS 年增暴增分數（強基本面）
  static const int epsYoYSurge = 22;

  /// EPS 連續成長分數（持續成長訊號）
  static const int epsConsecutiveGrowth = 18;

  /// EPS 由負轉正分數（轉機訊號）
  static const int epsTurnaround = 15;

  /// EPS 衰退警示分數（扣分）
  static const int epsDeclineWarning = -12;

  // ROE 規則分數
  /// ROE 優異（多方）
  static const int roeExcellent = 18;

  /// ROE 持續改善（多方）
  static const int roeImproving = 15;

  /// ROE 衰退（空方）
  static const int roeDeclining = -10;
}
