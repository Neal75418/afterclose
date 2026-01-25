/// 規則引擎參數 v1
///
/// 這些是 v1 的固定值，v2 將可設定。
abstract final class RuleParams {
  /// 分析回溯天數（日曆日）
  ///
  /// 需足夠涵蓋 52 週（約 250 交易日）。
  /// 250 交易日 ÷ 0.71（扣除週末假日比例）≈ 352 日曆日。
  /// 使用 370 日曆日確保有足夠緩衝。
  static const int lookbackPrice = 370;

  /// 歷史資料緩衝天數（確保分析邊界情況有足夠資料）
  static const int historyBufferDays = 30;

  /// 所需歷史資料總天數（lookbackPrice + buffer）
  static const int historyRequiredDays = lookbackPrice + historyBufferDays;

  /// 法人資料回溯天數
  static const int institutionalLookbackDays = 10;

  /// 成交量均線天數
  static const int volMa = 20;

  /// 壓力/支撐偵測回溯天數
  static const int rangeLookback = 60;

  /// 候選股最低成交額（3000 萬台幣）
  ///
  /// 過濾低流動性股票，確保候選池品質。
  static const double minCandidateTurnover = 30000000;

  /// 候選股最低成交量（1000 張 = 1,000,000 股）
  static const double minCandidateVolumeShares = 1000000;

  /// Top N 推薦最低成交額（8000 萬台幣）
  ///
  /// 確保推薦的都是主流標的。
  static const double topNMinTurnover = 80000000;

  /// 當沖規則最低成交量（1000 張 = 1,000,000 股）
  ///
  /// 當沖需要有量才有意義，1000 張確保流動性。
  static const double minDayTradingVolumeShares = 1000000;

  /// 候選股快篩最低成交量（100 張 = 100,000 股）
  ///
  /// 過濾極低成交量冷門股，確保分析品質。
  static const double minQuickFilterVolumeShares = 100000;

  /// 波段高低點偵測視窗
  static const int swingWindow = 20;

  /// 價格異動門檻百分比
  static const double priceSpikePercent = 6.0;

  /// 成交量異動倍數（相對 20 日均量）
  ///
  /// 4.0 倍具高度選擇性，僅捕捉異常成交量。
  /// 同時需要價格變動（見 minPriceChangeForVolume）。
  static const double volumeSpikeMult = 4.0;

  /// 成交量異動訊號所需最低價格變動
  ///
  /// 過濾無實質價格變動的成交量異動，1.5% 確保量價配合。
  static const double minPriceChangeForVolume = 0.015;

  /// 突破緩衝容差（1% 以獲得更乾淨的訊號）
  static const double breakoutBuffer = 0.01;

  /// 跌破緩衝容差（1%）
  static const double breakdownBuffer = 0.01;

  /// 壓力/支撐有效最大距離
  ///
  /// 超過此距離的壓力/支撐將被忽略，8% 可偵測近期水位並過濾無關水位。
  static const double maxSupportResistanceDistance = 0.08;

  // ==========================================
  // 新聞規則關鍵字（可設定）
  // ==========================================

  /// 新聞情緒分析正面關鍵字
  static const List<String> newsPositiveKeywords = [
    // 營收相關
    '營收創新高',
    '營收成長',
    '業績亮眼',
    '獲利創高',
    '毛利率上升',
    // 訂單/產能
    '訂單',
    '大單',
    '擴產',
    '產能滿載',
    '拿下',
    '接獲',
    // 法人動態
    '法說會',
    '外資買超',
    '投信買超',
    // 市場動態
    '利多',
    '漲停',
    '調升',
    '目標價',
    '看好',
    '突破',
    // 產業趨勢
    'AI',
    '人工智慧',
    '電動車',
    '半導體',
  ];

  /// 新聞情緒分析負面關鍵字
  static const List<String> newsNegativeKeywords = [
    // 營收相關
    '營收衰退',
    '營收下滑',
    '獲利下滑',
    '虧損',
    '毛利率下降',
    // 訂單/產能
    '砍單',
    '減產',
    '庫存',
    '去化',
    // 市場動態
    '利空',
    '跌停',
    '調降',
    '下修',
    // 公司治理
    '減資',
    '違約',
    '掏空',
    '解任',
  ];

  /// 重複推薦冷卻天數
  static const int cooldownDays = 2;

  /// 冷卻分數倍數
  static const double cooldownMultiplier = 0.7;

  /// 每檔股票最多理由數
  static const int maxReasonsPerStock = 2;

  /// 每日 Top N 推薦數量
  static const int dailyTopN = 10;

  /// 最低評分門檻
  ///
  /// 過濾僅有弱訊號或單一訊號的股票。
  /// 25 分代表至少一個強訊號（如反轉 35 分）或兩個中等訊號（如法人 18 + KD 18）。
  static const int minScoreThreshold = 25;

  /// 每個產業最多推薦股票數（v2）
  static const int maxPerIndustry = 3;

  // ==========================================
  // 技術指標參數
  // ==========================================

  /// RSI 週期（預設 14）
  static const int rsiPeriod = 14;

  /// RSI 超買門檻（RSI 高於此值避免買入）
  static const double rsiOverbought = 80.0;

  /// RSI 超賣門檻（RSI 低於此值避免賣出）
  static const double rsiOversold = 20.0;

  /// RSI 極度超買（高風險區）
  static const double rsiExtremeOverbought = 85.0;

  /// RSI 極度超賣（潛在反彈區）
  static const double rsiExtremeOversold = 30.0;

  /// KD %K 計算週期
  static const int kdPeriodK = 9;

  /// KD %D 平滑週期
  static const int kdPeriodD = 3;

  /// KD 超買門檻
  static const double kdOverbought = 80.0;

  /// KD 超賣門檻
  static const double kdOversold = 20.0;

  /// 法人連續買賣天數門檻
  ///
  /// 6 天連續買賣超代表較明確的法人動向。
  static const int institutionalStreakDays = 6;

  /// 法人每日最低淨買賣門檻（股）
  ///
  /// 每日淨買賣超須達此門檻才算有效交易日。
  /// 100張 = 100,000股
  static const int institutionalMinDailyNetShares = 100000;

  /// 法人每日顯著淨買賣門檻（股）
  ///
  /// 超過此門檻的交易日視為「顯著」交易日。
  /// 300張 = 300,000股
  static const int institutionalSignificantDailyNetShares = 300000;

  /// 法人連買總量門檻（股）
  ///
  /// 連續買超期間的總淨買超須達此門檻。
  /// 5000張 = 5,000,000股
  static const int institutionalBuyTotalThresholdShares = 5000000;

  /// 法人連買日均門檻（股）
  ///
  /// 連續買超期間的日均淨買超須達此門檻。
  /// 700張 = 700,000股
  static const int institutionalBuyDailyAvgThresholdShares = 700000;

  /// 法人連賣總量門檻（股）
  ///
  /// 連續賣超期間的總淨賣超須達此門檻（負值）。
  /// -15000張 = -15,000,000股
  static const int institutionalSellTotalThresholdShares = -15000000;

  /// 法人連賣日均門檻（股）
  ///
  /// 連續賣超期間的日均淨賣超須達此門檻（負值）。
  /// -2000張 = -2,000,000股
  static const int institutionalSellDailyAvgThresholdShares = -2000000;

  // ==========================================
  // 52 週高低點參數
  // ==========================================

  /// 一年交易日數（約 52 週 * 5 天）
  static const int week52Days = 250;

  /// 接近 52 週高低點緩衝百分比
  ///
  /// 在 52 週高低點 1% 範圍內觸發訊號。
  /// 較嚴格的門檻確保只有真正接近新高/新低的股票才會觸發。
  static const double week52NearThreshold = 0.01;

  // ==========================================
  // 均線排列參數
  // ==========================================

  /// 排列檢查用均線週期
  static const List<int> maAlignmentPeriods = [5, 10, 20, 60];

  /// 有效排列的均線最小間距（0.5%）
  static const double maMinSeparation = 0.005;

  /// 均線乖離率過濾門檻（5%）
  ///
  /// 收盤價離 MA 超過此距離時過濾，避免追高殺低
  static const double maDeviationThreshold = 0.05;

  /// 多頭排列成交量倍數門檻
  ///
  /// 成交量需達 20 日均量的此倍數。
  /// 1.3 倍（原設計 2.0 倍）考量台股常有量縮上漲現象。
  static const double maAlignmentVolumeMultiplier = 1.3;

  /// KD 黃金交叉有效區域（低檔區）
  ///
  /// K 值需低於此門檻才視為有效黃金交叉。
  static const double kdGoldenCrossZone = 30.0;

  /// KD 死亡交叉有效區域（高檔區）
  ///
  /// K 值需高於此門檻才視為有效死亡交叉。
  static const double kdDeathCrossZone = 70.0;

  /// KD 交叉價格動能門檻（1%）
  ///
  /// 黃金交叉需有至少此漲幅才算有效。
  static const double kdCrossPriceChangeThreshold = 0.01;

  // ==========================================
  // 第四階段：延伸市場資料參數
  // ==========================================

  /// 外資持股增加門檻（%）
  ///
  /// N 天內外資持股增加此百分比時觸發。
  static const double foreignShareholdingIncreaseThreshold = 0.5;

  /// 外資持股變化回溯天數
  static const int foreignShareholdingLookbackDays = 5;

  /// 高當沖比例門檻（%）
  ///
  /// 當沖比例高於此值視為「熱門」。45% 配合 1000 張成交量門檻。
  static const double dayTradingHighThreshold = 45.0;

  /// 極高當沖比例門檻（%）
  ///
  /// 極高當沖屬投機警示。60% 為極端情況。
  static const double dayTradingExtremeThreshold = 60.0;

  /// 大戶持股集中度門檻（%）
  ///
  /// 400 張以上大戶持有此比例的股票。
  static const double concentrationHighThreshold = 60.0;

  // ==========================================
  // 第五階段：價量背離參數
  // ==========================================

  /// 價量背離分析回溯天數
  static const int priceVolumeLookbackDays = 5;

  /// 背離偵測最低價格變動門檻（%）
  ///
  /// 價格變動需達此門檻，背離才有意義。
  static const double priceVolumePriceThreshold = 3.0;

  /// 背離偵測成交量變動門檻（%）
  static const double priceVolumeVolumeThreshold = 30.0;

  /// 「高檔爆量」訊號的高位門檻（百分位）
  ///
  /// 價格需在 60 日區間前 X% 才視為「高位」。
  static const double highPositionThreshold = 0.85;

  /// 「低檔吸籌」訊號的低位門檻（百分位）
  ///
  /// 價格需在 60 日區間後 X% 才視為「低位」。
  static const double lowPositionThreshold = 0.15;

  // ==========================================
  // 第六階段：基本面分析參數
  // ==========================================

  /// 營收年增率暴增門檻（%）
  ///
  /// 30% 在品質與數量間取得平衡。
  static const double revenueYoySurgeThreshold = 30.0;

  /// 營收年減率衰退門檻（%）
  static const double revenueYoyDeclineThreshold = 20.0;

  /// 營收月增連續成長月數
  ///
  /// 設為 1 以偵測單月暴增。
  static const int revenueMomConsecutiveMonths = 1;

  /// 營收月增率門檻（%）
  ///
  /// 10% 視為有意義的成長。
  static const double revenueMomGrowthThreshold = 10.0;

  /// 高殖利率門檻（%）
  ///
  /// 台股平均 4-6%，5.5% 可篩選出真正高殖利率股。
  static const double highDividendYieldThreshold = 5.5;

  /// 本益比低估門檻
  ///
  /// 本益比低於此值（且 > 0）視為低估。
  static const double peUndervaluedThreshold = 10.0;

  /// 本益比高估門檻
  ///
  /// 提高至 100 以聚焦泡沫區域。
  static const double peOvervaluedThreshold = 100.0;

  /// 股價淨值比低估門檻
  ///
  /// 股價淨值比低於 0.8 代表有意義的折價。
  static const double pbrUndervaluedThreshold = 0.8;

  /// 估值資料最大過期天數
  ///
  /// TWSE 並非每日更新所有股票的估值資料，超過此天數的資料視為過時。
  /// 7 天確保資料在合理時效內，避免用舊資料觸發規則。
  static const int valuationMaxStaleDays = 7;
}

/// 各推薦類型的分數
///
/// 分數層級反映訊號可靠性：
/// - 反轉訊號 (35)：最高 - 趨勢改變最具操作價值
/// - 技術訊號 (25)：中等 - 壓力/支撐突破
/// - 成交量異動 (22)：中等 - 現需 4 倍量 + 1.5% 價格變動
/// - 價格異動 (15)：較低 - 無量配合可能是雜訊
/// - 法人動向 (18)：台股重要指標 - 法人資金流向影響股價
/// - 新聞 (8)：輔助 - 僅提供背景資訊
///
/// 最高分數限制為 80，避免多訊號造成分數膨脹。
abstract final class RuleScores {
  /// 最高分數上限
  static const int maxScore = 80;
  static const int reversalW2S = 35;
  static const int reversalS2W = 35;
  static const int techBreakout = 25;
  static const int techBreakdown = 25;
  static const int volumeSpike = 22;
  static const int priceSpike = 15;
  static const int institutionalShift = 18;
  static const int newsRelated = 8;

  /// 加分：突破 + 成交量異動
  static const int breakoutVolumeBonus = 6;

  /// 加分：反轉 + 成交量異動
  static const int reversalVolumeBonus = 6;

  /// 加分：K 線型態（吞噬/星線/三兵）+ 成交量異動
  ///
  /// 強勢 K 線型態搭配成交量確認具高度意義。
  static const int patternVolumeBonus = 5;

  /// KD 黃金交叉分數
  static const int kdGoldenCross = 18;

  /// KD 死亡交叉分數
  static const int kdDeathCross = 18;

  /// 法人連續買超分數
  static const int institutionalBuyStreak = 20;

  /// 法人連續賣超分數
  static const int institutionalSellStreak = 20;

  // ==========================================
  // K 線型態分數
  // ==========================================

  /// 十字線分數（猶豫）
  static const int patternDoji = 10;

  /// 吞噬型態分數（強反轉）
  static const int patternEngulfing = 22;

  /// 錘子/吊人線分數
  static const int patternHammer = 18;

  /// 跳空型態分數
  static const int patternGap = 20;

  /// 晨星/暮星分數（三根 K 線反轉）
  static const int patternStar = 25;

  /// 三白兵/三黑鴉分數（強趨勢）
  static const int patternThreeSoldiers = 22;

  // ==========================================
  // 新訊號分數（第三階段）
  // ==========================================

  /// 52 週新高分數（強多頭）
  static const int week52High = 28;

  /// 52 週新低分數（潛在反轉或繼續下跌）
  ///
  /// 低於 52 週新高，因接刀風險較高。
  static const int week52Low = 22;

  /// 均線多頭排列分數（5>10>20>60）
  static const int maAlignmentBullish = 22;

  /// 均線空頭排列分數（5<10<20<60）
  static const int maAlignmentBearish = 22;

  /// RSI 極度超買分數（警示訊號）
  static const int rsiExtremeOverboughtSignal = 15;

  /// RSI 極度超賣分數（潛在反彈）
  static const int rsiExtremeOversoldSignal = 15;

  // ==========================================
  // 第四階段：延伸市場資料分數
  // ==========================================

  /// 外資持股增加分數
  static const int foreignShareholdingIncreasing = 18;

  /// 外資持股減少分數
  static const int foreignShareholdingDecreasing = 18;

  /// 高當沖比例分數（熱門股）
  static const int dayTradingHigh = 12;

  /// 極高當沖比例分數（投機）
  static const int dayTradingExtreme = 15;

  /// 高籌碼集中度分數
  static const int concentrationHigh = 16;

  // ==========================================
  // 第五階段：價量背離分數
  // ==========================================

  /// 價漲量縮背離分數（警示訊號）
  static const int priceVolumeBullishDivergence = 15;

  /// 價跌量增背離分數（恐慌訊號）
  static const int priceVolumeBearishDivergence = 18;

  /// 高檔爆量突破分數（強多頭）
  static const int highVolumeBreakout = 22;

  /// 低檔吸籌分數（潛在反轉）
  static const int lowVolumeAccumulation = 16;

  // ==========================================
  // 第六階段：基本面分析分數
  // ==========================================

  /// 營收年增暴增分數（強基本面）
  static const int revenueYoySurge = 20;

  /// 營收年減衰退分數（警示）
  static const int revenueYoyDecline = 15;

  /// 營收月增持續成長分數
  static const int revenueMomGrowth = 15;

  /// 高殖利率分數
  static const int highDividendYield = 18;

  /// 本益比低估分數
  static const int peUndervalued = 15;

  /// 本益比高估分數（警示）
  static const int peOvervalued = 10;

  /// 股價淨值比低估分數
  static const int pbrUndervalued = 12;
}

/// 推薦理由類型
enum ReasonType {
  reversalW2S('REVERSAL_W2S', '弱轉強'),
  reversalS2W('REVERSAL_S2W', '強轉弱'),
  techBreakout('TECH_BREAKOUT', '技術突破'),
  techBreakdown('TECH_BREAKDOWN', '技術跌破'),
  volumeSpike('VOLUME_SPIKE', '放量異常'),
  priceSpike('PRICE_SPIKE', '價格異常'),
  institutionalBuy('INSTITUTIONAL_BUY', '法人買超'),
  institutionalSell('INSTITUTIONAL_SELL', '法人賣超'),
  newsRelated('NEWS_RELATED', '新聞關聯'),
  // 技術指標訊號
  kdGoldenCross('KD_GOLDEN_CROSS', 'KD黃金交叉'),
  kdDeathCross('KD_DEATH_CROSS', 'KD死亡交叉'),
  institutionalBuyStreak('INSTITUTIONAL_BUY_STREAK', '法人連買'),
  institutionalSellStreak('INSTITUTIONAL_SELL_STREAK', '法人連賣'),
  // K 線型態訊號
  patternDoji('PATTERN_DOJI', '十字線'),
  patternBullishEngulfing('PATTERN_BULLISH_ENGULFING', '多頭吞噬'),
  patternBearishEngulfing('PATTERN_BEARISH_ENGULFING', '空頭吞噬'),
  patternHammer('PATTERN_HAMMER', '錘子線'),
  patternHangingMan('PATTERN_HANGING_MAN', '吊人線'),
  patternGapUp('PATTERN_GAP_UP', '跳空上漲'),
  patternGapDown('PATTERN_GAP_DOWN', '跳空下跌'),
  patternMorningStar('PATTERN_MORNING_STAR', '晨星'),
  patternEveningStar('PATTERN_EVENING_STAR', '暮星'),
  patternThreeWhiteSoldiers('PATTERN_THREE_WHITE_SOLDIERS', '三白兵'),
  patternThreeBlackCrows('PATTERN_THREE_BLACK_CROWS', '三黑鴉'),
  // 第三階段：掃描/提醒訊號
  week52High('WEEK_52_HIGH', '52週新高'),
  week52Low('WEEK_52_LOW', '52週新低'),
  maAlignmentBullish('MA_ALIGNMENT_BULLISH', '多頭排列'),
  maAlignmentBearish('MA_ALIGNMENT_BEARISH', '空頭排列'),
  rsiExtremeOverbought('RSI_EXTREME_OVERBOUGHT', 'RSI極度超買'),
  rsiExtremeOversold('RSI_EXTREME_OVERSOLD', 'RSI極度超賣'),
  // 第四階段：延伸市場資料訊號
  foreignShareholdingIncreasing('FOREIGN_SHAREHOLDING_INCREASING', '外資持股增加'),
  foreignShareholdingDecreasing('FOREIGN_SHAREHOLDING_DECREASING', '外資持股減少'),
  dayTradingHigh('DAY_TRADING_HIGH', '高當沖比例'),
  dayTradingExtreme('DAY_TRADING_EXTREME', '極高當沖比例'),
  concentrationHigh('CONCENTRATION_HIGH', '籌碼集中'),
  // 第五階段：價量背離訊號
  priceVolumeBullishDivergence('PRICE_VOLUME_BULLISH_DIVERGENCE', '價漲量縮'),
  priceVolumeBearishDivergence('PRICE_VOLUME_BEARISH_DIVERGENCE', '價跌量增'),
  highVolumeBreakout('HIGH_VOLUME_BREAKOUT', '高檔爆量'),
  lowVolumeAccumulation('LOW_VOLUME_ACCUMULATION', '低檔吸籌'),
  // 第六階段：基本面分析訊號
  revenueYoySurge('REVENUE_YOY_SURGE', '營收年增暴增'),
  revenueYoyDecline('REVENUE_YOY_DECLINE', '營收年減衰退'),
  revenueMomGrowth('REVENUE_MOM_GROWTH', '營收月增持續'),
  highDividendYield('HIGH_DIVIDEND_YIELD', '高殖利率'),
  peUndervalued('PE_UNDERVALUED', 'PE低估'),
  peOvervalued('PE_OVERVALUED', 'PE高估'),
  pbrUndervalued('PBR_UNDERVALUED', '股價淨值比低');

  const ReasonType(this.code, this.label);

  final String code;
  final String label;

  int get score => switch (this) {
    ReasonType.reversalW2S => RuleScores.reversalW2S,
    ReasonType.reversalS2W => RuleScores.reversalS2W,
    ReasonType.techBreakout => RuleScores.techBreakout,
    ReasonType.techBreakdown => RuleScores.techBreakdown,
    ReasonType.volumeSpike => RuleScores.volumeSpike,
    ReasonType.priceSpike => RuleScores.priceSpike,

    ReasonType.institutionalBuy => RuleScores.institutionalShift,
    ReasonType.institutionalSell => RuleScores.institutionalShift,
    ReasonType.newsRelated => RuleScores.newsRelated,
    ReasonType.kdGoldenCross => RuleScores.kdGoldenCross,
    ReasonType.kdDeathCross => RuleScores.kdDeathCross,
    ReasonType.institutionalBuyStreak => RuleScores.institutionalBuyStreak,
    ReasonType.institutionalSellStreak => RuleScores.institutionalSellStreak,
    // K 線型態
    ReasonType.patternDoji => RuleScores.patternDoji,
    ReasonType.patternBullishEngulfing => RuleScores.patternEngulfing,
    ReasonType.patternBearishEngulfing => RuleScores.patternEngulfing,
    ReasonType.patternHammer => RuleScores.patternHammer,
    ReasonType.patternHangingMan => RuleScores.patternHammer,
    ReasonType.patternGapUp => RuleScores.patternGap,
    ReasonType.patternGapDown => RuleScores.patternGap,
    ReasonType.patternMorningStar => RuleScores.patternStar,
    ReasonType.patternEveningStar => RuleScores.patternStar,
    ReasonType.patternThreeWhiteSoldiers => RuleScores.patternThreeSoldiers,
    ReasonType.patternThreeBlackCrows => RuleScores.patternThreeSoldiers,
    // 第三階段訊號
    ReasonType.week52High => RuleScores.week52High,
    ReasonType.week52Low => RuleScores.week52Low,
    ReasonType.maAlignmentBullish => RuleScores.maAlignmentBullish,
    ReasonType.maAlignmentBearish => RuleScores.maAlignmentBearish,
    ReasonType.rsiExtremeOverbought => RuleScores.rsiExtremeOverboughtSignal,
    ReasonType.rsiExtremeOversold => RuleScores.rsiExtremeOversoldSignal,
    // 第四階段訊號
    ReasonType.foreignShareholdingIncreasing =>
      RuleScores.foreignShareholdingIncreasing,
    ReasonType.foreignShareholdingDecreasing =>
      RuleScores.foreignShareholdingDecreasing,
    ReasonType.dayTradingHigh => RuleScores.dayTradingHigh,
    ReasonType.dayTradingExtreme => RuleScores.dayTradingExtreme,
    ReasonType.concentrationHigh => RuleScores.concentrationHigh,
    // 第五階段訊號
    ReasonType.priceVolumeBullishDivergence =>
      RuleScores.priceVolumeBullishDivergence,
    ReasonType.priceVolumeBearishDivergence =>
      RuleScores.priceVolumeBearishDivergence,
    ReasonType.highVolumeBreakout => RuleScores.highVolumeBreakout,
    ReasonType.lowVolumeAccumulation => RuleScores.lowVolumeAccumulation,
    // 第六階段訊號
    ReasonType.revenueYoySurge => RuleScores.revenueYoySurge,
    ReasonType.revenueYoyDecline => RuleScores.revenueYoyDecline,
    ReasonType.revenueMomGrowth => RuleScores.revenueMomGrowth,
    ReasonType.highDividendYield => RuleScores.highDividendYield,
    ReasonType.peUndervalued => RuleScores.peUndervalued,
    ReasonType.peOvervalued => RuleScores.peOvervalued,
    ReasonType.pbrUndervalued => RuleScores.pbrUndervalued,
  };
}

/// 趨勢狀態
enum TrendState {
  up('UP', '上升'),
  down('DOWN', '下跌'),
  range('RANGE', '盤整');

  const TrendState(this.code, this.label);

  final String code;
  final String label;
}

/// 反轉狀態
enum ReversalState {
  none('NONE', '無'),
  weakToStrong('W2S', '弱轉強'),
  strongToWeak('S2W', '強轉弱');

  const ReversalState(this.code, this.label);

  final String code;
  final String label;
}

/// 新聞分類
enum NewsCategory {
  earnings('EARNINGS', '財報'),
  policy('POLICY', '政策'),
  industry('INDUSTRY', '產業'),
  companyEvent('COMPANY_EVENT', '公司事件'),
  other('OTHER', '其他');

  const NewsCategory(this.code, this.label);

  final String code;
  final String label;
}

/// 更新執行狀態
enum UpdateStatus {
  success('SUCCESS'),
  failed('FAILED'),
  partial('PARTIAL');

  const UpdateStatus(this.code);

  final String code;
}

/// 股票市場類型
enum StockMarket {
  twse('TWSE', '上市'),
  tpex('TPEx', '上櫃');

  const StockMarket(this.code, this.label);

  final String code;
  final String label;
}
