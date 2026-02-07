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

  /// 高當沖規則最低成交量（10,000 張 = 10,000,000 股）
  ///
  /// v0.1.3：從 1000 張調升至萬張，當沖需要有量才有意義。
  static const double minDayTradingVolumeShares = 10000000;

  /// 極高當沖規則最低成交量（30,000 張 = 30,000,000 股）
  ///
  /// v0.1.3：極高當沖需要 3 萬張以上量能，確保大型標的才觸發。
  static const double minDayTradingExtremeVolumeShares = 30000000;

  /// 候選股快篩最低成交量（100 張 = 100,000 股）
  ///
  /// 過濾極低成交量冷門股，確保分析品質。
  static const double minQuickFilterVolumeShares = 100000;

  /// 波段高低點偵測視窗
  static const int swingWindow = 20;

  /// 價格異動門檻百分比
  ///
  /// v0.1.3：從 6% 提高至 7%，提升精準度
  static const double priceSpikePercent = 7.0;

  /// 價格異動成交量確認倍數
  ///
  /// 成交量需達 20 日均量的此倍數以上，避免無量異動雜訊。
  static const double priceSpikeVolumeMult = 1.5;

  /// 成交量異動倍數（相對 20 日均量）
  ///
  /// 4.0 倍具高度選擇性，僅捕捉異常成交量。
  /// 同時需要價格變動（見 minPriceChangeForVolume）。
  static const double volumeSpikeMult = 4.0;

  /// 成交量異動訊號所需最低價格變動
  ///
  /// 過濾無實質價格變動的成交量異動，1.5% 確保量價配合。
  static const double minPriceChangeForVolume = 0.015;

  /// 突破緩衝容差（3% 以獲得更乾淨的訊號）
  ///
  /// 收緊門檻以過濾假突破，需明確突破壓力 3% 以上。
  static const double breakoutBuffer = 0.03;

  /// 跌破緩衝容差（3%）
  ///
  /// 收緊門檻以過濾假跌破，需明確跌破支撐 3% 以上。
  static const double breakdownBuffer = 0.03;

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

  /// 冷卻期固定扣分（取代乘數，避免高分股被腰斬）
  static const double cooldownPenalty = 15;

  /// 每檔股票最多理由數（資料庫儲存用，供篩選功能使用）
  /// 設為 50 確保所有規則都能被儲存（目前共 51 條規則）
  /// UI 顯示時會用 .take(2) 或 .take(3) 限制
  static const int maxReasonsPerStock = 50;

  /// 每日 Top N 推薦數量
  ///
  /// 上市+上櫃共約 1,770 檔股票，20 檔可提供足夠多樣性
  static const int dailyTopN = 20;

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
  ///
  /// v0.1.1：從 85 放寬至 80，解決 0 觸發問題。
  /// 標準超買區為 70，80 以上即為極度超買。
  static const double rsiExtremeOverbought = 80.0;

  /// RSI 極度超賣（潛在反彈區）
  ///
  /// v0.1.2：從 25 放寬至 30，解決 0 觸發問題。
  /// RSI 30 以下即為超賣區，提供更多篩選結果。
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
  /// v0.1.2：從 6 天放寬至 4 天，解決 0 觸發問題
  static const int institutionalStreakDays = 4;

  /// 法人每日最低淨買賣門檻（股）
  ///
  /// 每日淨買賣超須達此門檻才算有效交易日。
  /// v0.1.2：從 100 張放寬至 50 張
  static const int institutionalMinDailyNetShares = 50000;

  /// 法人每日顯著淨買賣門檻（股）
  ///
  /// 超過此門檻的交易日視為「顯著」交易日。
  /// v0.1.2：從 300 張放寬至 150 張
  static const int institutionalSignificantDailyNetShares = 150000;

  /// 法人連買總量門檻（股）
  ///
  /// 連續買超期間的總淨買超須達此門檻。
  /// v0.1.2：從 5000 張放寬至 2000 張
  static const int institutionalBuyTotalThresholdShares = 2000000;

  /// 法人連買日均門檻（股）
  ///
  /// 連續買超期間的日均淨買超須達此門檻。
  /// v0.1.2：從 700 張放寬至 300 張
  static const int institutionalBuyDailyAvgThresholdShares = 300000;

  /// 法人連賣總量門檻（股）
  ///
  /// 連續賣超期間的總淨賣超須達此門檻（負值）。
  /// v0.1.2：從 -5000 張放寬至 -2000 張
  static const int institutionalSellTotalThresholdShares = -2000000;

  /// 法人連賣日均門檻（股）
  ///
  /// 連續賣超期間的日均淨賣超須達此門檻（負值）。
  /// v0.1.2：從 -700 張放寬至 -300 張
  static const int institutionalSellDailyAvgThresholdShares = -300000;

  // ==========================================
  // 52 週高低點參數
  // ==========================================

  /// 一年交易日數（約 52 週 * 5 天）
  static const int week52Days = 250;

  /// 歷史資料完成度最低天數
  ///
  /// 股票需有此天數以上的價格資料，才視為「歷史資料完整」。
  /// 200 天約涵蓋 10 個月的交易日，可進行大部分技術分析。
  static const int historicalDataMinDays = 200;

  /// 接近 52 週新高緩衝百分比
  ///
  /// 收盤價在 52 週最高價的 1% 範圍內觸發。
  /// 維持嚴格門檻確保只有真正突破的股票才觸發。
  static const double week52HighThreshold = 0.01;

  /// 接近 52 週新低緩衝百分比
  ///
  /// 收盤價在 52 週最低價的 3% 範圍內觸發。
  /// 比新高稍寬鬆（3% vs 1%），因為：
  /// 1. 新低是逆勢操作，需要更多緩衝
  /// 2. 底部區域通常有支撐震盪
  /// 3. 避免 0 個新低的極端情況
  static const double week52LowThreshold = 0.03;

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
  // K 線型態參數
  // ==========================================

  /// 錘子線實體最小比例（5%）
  ///
  /// 實體須至少占振幅的 5%，過小視為十字線。
  static const double hammerBodyMinRatio = 0.05;

  /// 錘子線下影線倍數（2 倍實體）
  ///
  /// 下影線須至少為實體的 2 倍。
  static const double hammerLowerShadowMultiplier = 2.0;

  /// 錘子線上影線最大倍數（0.5 倍實體）
  ///
  /// 上影線不可超過實體的 0.5 倍。
  static const double hammerUpperShadowMaxRatio = 0.5;

  /// 三白兵/三黑鴉每根 K 線最小實體比例（1%）
  ///
  /// 每根 K 線的 |open - close| / close 須 >= 1%，
  /// 避免微小漲跌幅的 K 線誤觸發。
  static const double threeLineMinBodyRatio = 0.01;

  /// 十字線實體最大比例（10%）
  ///
  /// 實體小於振幅的 10% 視為十字線。
  static const double dojiBodyMaxRatio = 0.1;

  /// 跳空缺口最小比例（0.5%）
  ///
  /// 缺口須至少為前日收盤的 0.5%。
  static const double gapMinThreshold = 0.005;

  /// 星線小實體最大比例（0.5 倍第一根）
  ///
  /// 第二根 K 線實體不可超過第一根的 0.5 倍。
  static const double starSmallBodyMaxRatio = 0.5;

  /// 強勢 K 線跌幅門檻（1.0%）
  ///
  /// v0.1.2：從 1.5% 放寬至 1.0%，讓三黑鴉更容易觸發。
  static const double strongCandleDropThreshold = 0.01;

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
  /// v0.1.3：從 35% 調升至 50%，超過 50% 才算高當沖。
  static const double dayTradingHighThreshold = 50.0;

  /// 極高當沖比例門檻（%）
  ///
  /// v0.1.3：從 50% 調升至 70%，超過 70% 且量能 3 萬張以上才算極高當沖。
  static const double dayTradingExtremeThreshold = 70.0;

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
  /// v0.1.1：從 0.15 放寬至 0.25（底部 25%），解決 0 觸發問題
  static const double lowPositionThreshold = 0.25;

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

  // ==========================================
  // Killer Features 參數（注意/處置股、董監持股）
  // ==========================================

  /// 董監連續減持月數門檻
  ///
  /// 連續 3 個月以上減持視為強賣訊號。
  static const int insiderSellingStreakMonths = 3;

  /// 董監顯著增持門檻（%）
  ///
  /// 單月持股比例增加 5% 以上視為買進訊號。
  static const double insiderSignificantBuyingThreshold = 5.0;

  /// 高質押比例門檻（%）
  ///
  /// 質押比例超過 50% 視為風險警示。
  static const double highPledgeRatioThreshold = 50.0;

  /// 處置股結束日期寬限天數
  ///
  /// 判斷處置股是否仍生效時，在結束日期後加上此天數作為緩衝。
  /// 1 天確保結束當日仍視為生效狀態。
  static const int disposalEndDateGraceDays = 1;

  /// 外資持股集中度警示門檻（%）
  ///
  /// 外資持股超過 60% 且快速增加時觸發風險警示。
  static const double foreignConcentrationWarningThreshold = 60.0;

  /// 外資持股集中度危險門檻（%）
  ///
  /// 外資持股超過 70% 視為高度集中風險。
  static const double foreignConcentrationDangerThreshold = 70.0;

  /// 外資流出天數
  ///
  /// 追蹤連續 N 天的外資流出趨勢。
  static const int foreignExodusLookbackDays = 5;

  /// 外資流出門檻（%）
  ///
  /// N 天內外資持股減少超過此比例視為流出警示。
  static const double foreignExodusThreshold = -2.0;

  // ==========================================
  // EPS 規則參數
  // ==========================================

  /// EPS 年增暴增門檻（%）
  static const double epsYoYSurgeThreshold = 50.0;

  /// EPS 季增成長門檻（%）
  static const double epsGrowthThreshold = 10.0;

  /// EPS 連續成長最少季數
  static const int epsConsecutiveQuarters = 2;

  /// EPS 由負轉正最低門檻（元）
  static const double epsTurnaroundThreshold = 0.3;

  /// EPS 衰退警示門檻（%）
  static const double epsDeclineThreshold = 20.0;

  // ==========================================
  // ROE 規則參數
  // ==========================================

  /// ROE 優異門檻（%）
  static const double roeExcellentThreshold = 15.0;

  /// ROE 改善門檻（百分點）
  static const double roeImprovingThreshold = 5.0;

  /// ROE 衰退門檻（百分點）
  static const double roeDecliningThreshold = 5.0;

  /// ROE 趨勢最少季數
  static const int roeMinQuarters = 2;

  // ==========================================
  // 分析服務參數
  // ==========================================

  /// 波段點聚類閾值（2%）
  ///
  /// 將差距在此範圍內的波段點聚類為同一價格區域。
  static const double clusterThreshold = 0.02;

  /// 趨勢偵測上升閾值（每日 0.08%）
  ///
  /// 標準化斜率超過此值視為上升趨勢。
  /// 每日 0.08% = 20 天約 1.6%
  static const double trendUpThreshold = 0.08;

  /// 趨勢偵測下降閾值（每日 -0.08%）
  ///
  /// 標準化斜率低於此值視為下降趨勢。
  static const double trendDownThreshold = -0.08;

  /// 接近區間高點緩衝（2%）
  ///
  /// 當前價格在區間高點 2% 以內視為「接近高點」。
  static const double nearRangeHighBuffer = 0.98;

  /// 接近區間低點緩衝（2%）
  ///
  /// 當前價格在區間低點 2% 以內視為「接近低點」。
  static const double nearRangeLowBuffer = 1.02;

  /// 更高低點確認緩衝（7%）
  ///
  /// 近期低點需高於前期低點 7% 才確認為「更高低點」。
  /// 收緊門檻以大幅提升精準度，只保留明確反轉訊號。
  static const double higherLowBuffer = 1.07;

  /// 更低高點確認緩衝（5%）
  ///
  /// 近期高點需低於前期高點 5% 才確認為「更低高點」。
  /// v0.1.1：從 0.93（7%）放寬至 0.95（5%），解決 0 觸發問題。
  /// 頭部反轉不需要像底部反轉那樣嚴格。
  static const double lowerHighBuffer = 0.95;

  /// 反轉/突破訊號成交量確認門檻（多方）
  ///
  /// 近期成交量需達前期平均的此倍數以上。
  /// 用於弱轉強（底部反轉）訊號確認。
  /// v0.1.1：從 2.0 放寬至 1.5，但仍保留量能配合要求。
  static const double reversalVolumeConfirm = 1.5;

  /// 強轉弱成交量確認門檻
  ///
  /// 頭部反轉（強轉弱）的成交量要求較寬鬆。
  /// 頭部形成時往往是「量縮」而非「量增」，
  /// 因此只需要基本成交量即可。
  /// v0.1.1：新增獨立參數，解決強轉弱 0 觸發問題。
  static const double s2wVolumeConfirm = 0.8;

  // ==========================================
  // 流動性加權排序參數
  // ==========================================

  /// 成交金額單位（1 億台幣）
  ///
  /// 用於計算流動性加成時的基準單位。
  static const double liquidityTurnoverUnit = 100000000;

  /// 每單位成交金額的加成分數
  ///
  /// 每 1 億成交金額加 2 分。
  static const double liquidityBonusPerUnit = 2.0;

  /// 流動性加成上限
  ///
  /// 最多 20 分（即 10 億成交金額達上限）。
  static const double liquidityBonusMax = 20;

  // ==========================================
  // ATR 與支撐壓力搜尋參數
  // ==========================================

  /// ATR 計算週期
  ///
  /// 14 日為業界標準 ATR 週期。
  static const int atrPeriod = 14;

  /// ATR 距離乘數（支撐/壓力搜尋半徑）
  ///
  /// 使用 ATR × 此乘數 / 現價 作為動態搜尋距離。
  static const double atrDistanceMultiplier = 3.0;

  /// 支撐壓力距離衰減因子
  ///
  /// 用於計算 distanceFactor = 1 / (1 + (distance/price) * factor)。
  /// 數值越大，距離衰減越快（越近的關卡分數越高）。
  static const double distanceDecayFactor = 10.0;

  /// ATR 動態距離上限（比例）
  ///
  /// 限制 ATR-based 搜尋距離的最大值，避免高波動股過度搜尋。
  static const double maxAtrDistance = 0.20;

  /// 趨勢偵測最少資料點數
  ///
  /// 收盤價序列需達此數量才進行趨勢判斷。
  static const int minTrendDataPoints = 5;

  /// 高檔爆量成交量倍數
  ///
  /// 高檔爆量需達成交量變化門檻的此倍數。
  static const double highVolumeMultiplier = 1.5;

  // ==========================================
  // 法人動向規則參數
  // ==========================================

  /// 1 張 = 1000 股
  static const int sheetToShares = 1000;

  /// 法人分析最低成交量（1000 張 = 1,000,000 股）
  static const double institutionalMinVolume = 1000000;

  /// 法人數據有效最低成交量（2000 張 = 2,000,000 股）
  static const double institutionalValidVolume = 2000000;

  /// 法人佔總成交量顯著比例門檻
  static const double institutionalSignificantRatio = 0.35;

  /// 法人佔總成交量爆量比例門檻
  static const double institutionalExplosiveRatio = 0.50;

  /// 法人反轉訊號最低量（500 張 = 500,000 股）
  static const double institutionalReversalSheets = 500000;

  /// 法人小量方向判斷門檻（100 張 = 100,000 股）
  static const double institutionalSmallSheets = 100000;

  /// 法人大量訊號門檻（5000 張 = 5,000,000 股）
  static const double institutionalLargeSignalSheets = 5000000;

  /// 法人加速買賣倍數門檻
  static const double institutionalAccelerationMult = 2.0;

  /// 法人加速買賣最低量（1000 張 = 1,000,000 股）
  static const double institutionalAccelerationMinSheets = 1000000;

  /// 法人大量訊號價格變動確認門檻（1%）
  static const double institutionalSignificantPriceChange = 0.01;

  /// 法人方向計算取樣數
  static const int institutionalDirectionSampleSize = 5;

  /// 新聞回溯時間（小時）
  static const int newsLookbackHours = 120;

  // ==========================================
  // 掃描規則專用參數
  // ==========================================

  /// 掃描用殖利率最低門檻（%）
  ///
  /// 低於此值不觸發殖利率相關診斷日誌。
  static const double scanDividendYieldMin = 4.0;

  /// 異常殖利率過濾上限（%）
  ///
  /// 超過此值通常為資料錯誤或特殊情況。
  static const double scanDividendYieldMax = 20.0;

  /// PE 高估確認 RSI 門檻
  static const double scanRsiOverboughtThreshold = 75.0;

  /// 動能確認 RSI 門檻（EPS 轉機搭配 RSI 正向確認）
  static const double scanRsiMomentumThreshold = 50.0;

  /// EPS 年度回溯筆數（找去年同季需要的最少歷史資料）
  static const int epsYearLookback = 5;

  /// EPS 同期季度偏移（降序排列下去年同季的起始 index）
  static const int epsQuarterOffset = 4;

  // ==========================================
  // 價量背離規則參數
  // ==========================================

  /// 背離價格變動門檻（%）
  static const double divergencePriceThreshold = 1.0;

  /// 背離成交量變動門檻（%）
  static const double divergenceVolumeThreshold = 10.0;

  /// 低檔吸籌成交量比率門檻
  static const double lowAccumulationVolumeRatio = 0.6;
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

  // ==========================================
  // 多方訊號（正分）
  // ==========================================

  /// 弱轉強分數（強多頭訊號）
  static const int reversalW2S = 35;

  /// 向上突破分數
  static const int techBreakout = 25;

  /// 成交量爆增分數
  static const int volumeSpike = 22;

  /// 價格急漲分數
  static const int priceSpike = 15;

  /// 法人買賣轉向分數
  static const int institutionalShift = 18;

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

  // ==========================================
  // 空方訊號（負分）- 扣分以降低推薦機率
  // ==========================================

  /// 強轉弱分數（空方訊號，扣分）
  static const int reversalS2W = -25;

  /// 向下跌破分數（空方訊號，扣分）
  static const int techBreakdown = -20;

  /// KD 死亡交叉分數（空方訊號，扣分）
  static const int kdDeathCross = -12;

  /// 法人連續賣超分數（空方訊號，扣分）
  static const int institutionalSellStreak = -15;

  // ==========================================
  // K 線型態分數（多空分離）
  // ==========================================

  /// 十字線分數（中性，猶豫訊號）
  static const int patternDoji = 10;

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

  // ==========================================
  // 技術指標分數（第三階段）
  // ==========================================

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

  // ==========================================
  // 第四階段：延伸市場資料分數
  // ==========================================

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

  // ==========================================
  // 第五階段：價量背離分數
  // ==========================================

  /// 價漲量縮背離分數（警示訊號，小扣分）
  static const int priceVolumeBullishDivergence = -8;

  /// 價跌量增背離分數（恐慌訊號，扣分）
  static const int priceVolumeBearishDivergence = -15;

  /// 高檔爆量突破分數（強多頭）
  static const int highVolumeBreakout = 22;

  /// 低檔吸籌分數（潛在反轉，多方）
  static const int lowVolumeAccumulation = 16;

  // ==========================================
  // 第六階段：基本面分析分數
  // ==========================================

  /// 營收年增暴增分數（強基本面）
  static const int revenueYoySurge = 20;

  /// 營收年減衰退分數（空方，扣分）
  static const int revenueYoyDecline = -10;

  /// 營收月增持續成長分數（多方）
  static const int revenueMomGrowth = 15;

  /// 高殖利率分數（多方）
  static const int highDividendYield = 18;

  /// 本益比低估分數（多方）
  static const int peUndervalued = 15;

  /// 本益比高估分數（空方，扣分）
  static const int peOvervalued = -8;

  /// 股價淨值比低估分數（多方）
  static const int pbrUndervalued = 12;

  // ==========================================
  // Killer Features 分數（注意/處置股、董監持股）
  // ==========================================

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

  // ==========================================
  // EPS 規則分數
  // ==========================================

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

  // ==========================================
  // 向後相容（舊欄位名稱，標記為棄用）
  // ==========================================

  /// @deprecated 使用 patternEngulfingBullish 或 patternEngulfingBearish
  static const int patternEngulfing = 22;

  /// @deprecated 使用 patternHammerBullish 或 patternHammerBearish
  static const int patternHammer = 18;

  /// @deprecated 使用 patternGapUp 或 patternGapDown
  static const int patternGap = 20;

  /// @deprecated 使用 patternMorningStar 或 patternEveningStar
  static const int patternStar = 25;

  /// @deprecated 使用 patternThreeWhiteSoldiers 或 patternThreeBlackCrows
  static const int patternThreeSoldiers = 22;
}

/// 推薦理由類型
enum ReasonType {
  reversalW2S('REVERSAL_W2S'),
  reversalS2W('REVERSAL_S2W'),
  techBreakout('TECH_BREAKOUT'),
  techBreakdown('TECH_BREAKDOWN'),
  volumeSpike('VOLUME_SPIKE'),
  priceSpike('PRICE_SPIKE'),
  institutionalBuy('INSTITUTIONAL_BUY'),
  institutionalSell('INSTITUTIONAL_SELL'),
  newsRelated('NEWS_RELATED'),
  // 技術指標訊號
  kdGoldenCross('KD_GOLDEN_CROSS'),
  kdDeathCross('KD_DEATH_CROSS'),
  institutionalBuyStreak('INSTITUTIONAL_BUY_STREAK'),
  institutionalSellStreak('INSTITUTIONAL_SELL_STREAK'),
  // K 線型態訊號
  patternDoji('PATTERN_DOJI'),
  patternBullishEngulfing('PATTERN_BULLISH_ENGULFING'),
  patternBearishEngulfing('PATTERN_BEARISH_ENGULFING'),
  patternHammer('PATTERN_HAMMER'),
  patternHangingMan('PATTERN_HANGING_MAN'),
  patternGapUp('PATTERN_GAP_UP'),
  patternGapDown('PATTERN_GAP_DOWN'),
  patternMorningStar('PATTERN_MORNING_STAR'),
  patternEveningStar('PATTERN_EVENING_STAR'),
  patternThreeWhiteSoldiers('PATTERN_THREE_WHITE_SOLDIERS'),
  patternThreeBlackCrows('PATTERN_THREE_BLACK_CROWS'),
  // 第三階段：掃描/提醒訊號
  week52High('WEEK_52_HIGH'),
  week52Low('WEEK_52_LOW'),
  maAlignmentBullish('MA_ALIGNMENT_BULLISH'),
  maAlignmentBearish('MA_ALIGNMENT_BEARISH'),
  rsiExtremeOverbought('RSI_EXTREME_OVERBOUGHT'),
  rsiExtremeOversold('RSI_EXTREME_OVERSOLD'),
  // 第四階段：延伸市場資料訊號
  foreignShareholdingIncreasing('FOREIGN_SHAREHOLDING_INCREASING'),
  foreignShareholdingDecreasing('FOREIGN_SHAREHOLDING_DECREASING'),
  dayTradingHigh('DAY_TRADING_HIGH'),
  dayTradingExtreme('DAY_TRADING_EXTREME'),
  concentrationHigh('CONCENTRATION_HIGH'),
  // 第五階段：價量背離訊號
  priceVolumeBullishDivergence('PRICE_VOLUME_BULLISH_DIVERGENCE'),
  priceVolumeBearishDivergence('PRICE_VOLUME_BEARISH_DIVERGENCE'),
  highVolumeBreakout('HIGH_VOLUME_BREAKOUT'),
  lowVolumeAccumulation('LOW_VOLUME_ACCUMULATION'),
  // 第六階段：基本面分析訊號
  revenueYoySurge('REVENUE_YOY_SURGE'),
  revenueYoyDecline('REVENUE_YOY_DECLINE'),
  revenueMomGrowth('REVENUE_MOM_GROWTH'),
  highDividendYield('HIGH_DIVIDEND_YIELD'),
  peUndervalued('PE_UNDERVALUED'),
  peOvervalued('PE_OVERVALUED'),
  pbrUndervalued('PBR_UNDERVALUED'),
  // Killer Features 訊號
  tradingWarningAttention('TRADING_WARNING_ATTENTION'),
  tradingWarningDisposal('TRADING_WARNING_DISPOSAL'),
  insiderSellingStreak('INSIDER_SELLING_STREAK'),
  insiderSignificantBuying('INSIDER_SIGNIFICANT_BUYING'),
  highPledgeRatio('HIGH_PLEDGE_RATIO'),
  foreignConcentrationWarning('FOREIGN_CONCENTRATION_WARNING'),
  foreignExodus('FOREIGN_EXODUS'),
  // EPS 訊號
  epsYoYSurge('EPS_YOY_SURGE'),
  epsConsecutiveGrowth('EPS_CONSECUTIVE_GROWTH'),
  epsTurnaround('EPS_TURNAROUND'),
  epsDeclineWarning('EPS_DECLINE_WARNING'),

  // ROE 訊號
  roeExcellent('ROE_EXCELLENT'),
  roeImproving('ROE_IMPROVING'),
  roeDeclining('ROE_DECLINING');

  const ReasonType(this.code);

  final String code;

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
    // K 線型態（多空分離）
    ReasonType.patternDoji => RuleScores.patternDoji,
    ReasonType.patternBullishEngulfing => RuleScores.patternEngulfingBullish,
    ReasonType.patternBearishEngulfing => RuleScores.patternEngulfingBearish,
    ReasonType.patternHammer => RuleScores.patternHammerBullish,
    ReasonType.patternHangingMan => RuleScores.patternHammerBearish,
    ReasonType.patternGapUp => RuleScores.patternGapUp,
    ReasonType.patternGapDown => RuleScores.patternGapDown,
    ReasonType.patternMorningStar => RuleScores.patternMorningStar,
    ReasonType.patternEveningStar => RuleScores.patternEveningStar,
    ReasonType.patternThreeWhiteSoldiers =>
      RuleScores.patternThreeWhiteSoldiers,
    ReasonType.patternThreeBlackCrows => RuleScores.patternThreeBlackCrows,
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
    // Killer Features 訊號
    ReasonType.tradingWarningAttention => RuleScores.tradingWarningAttention,
    ReasonType.tradingWarningDisposal => RuleScores.tradingWarningDisposal,
    ReasonType.insiderSellingStreak => RuleScores.insiderSellingStreak,
    ReasonType.insiderSignificantBuying => RuleScores.insiderSignificantBuying,
    ReasonType.highPledgeRatio => RuleScores.highPledgeRatio,
    ReasonType.foreignConcentrationWarning =>
      RuleScores.foreignConcentrationWarning,
    ReasonType.foreignExodus => RuleScores.foreignExodus,
    // EPS 訊號
    ReasonType.epsYoYSurge => RuleScores.epsYoYSurge,
    ReasonType.epsConsecutiveGrowth => RuleScores.epsConsecutiveGrowth,
    ReasonType.epsTurnaround => RuleScores.epsTurnaround,
    ReasonType.epsDeclineWarning => RuleScores.epsDeclineWarning,
    ReasonType.roeExcellent => RuleScores.roeExcellent,
    ReasonType.roeImproving => RuleScores.roeImproving,
    ReasonType.roeDeclining => RuleScores.roeDeclining,
  };
}

/// 趨勢狀態
enum TrendState {
  up('UP'),
  down('DOWN'),
  range('RANGE');

  const TrendState(this.code);

  final String code;
}

/// 反轉狀態
enum ReversalState {
  none('NONE'),
  weakToStrong('W2S'),
  strongToWeak('S2W');

  const ReversalState(this.code);

  final String code;
}

/// 新聞分類
enum NewsCategory {
  earnings('EARNINGS'),
  policy('POLICY'),
  industry('INDUSTRY'),
  companyEvent('COMPANY_EVENT'),
  other('OTHER');

  const NewsCategory(this.code);

  final String code;
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
  twse('TWSE'),
  tpex('TPEx');

  const StockMarket(this.code);

  final String code;
}
