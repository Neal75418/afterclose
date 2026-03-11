export 'package:afterclose/core/constants/reason_type.dart';
export 'package:afterclose/core/constants/rule_enums.dart';
export 'package:afterclose/core/constants/rule_params_alert.dart';
export 'package:afterclose/core/constants/rule_params_fundamental.dart';
export 'package:afterclose/core/constants/rule_params_indicator.dart';
export 'package:afterclose/core/constants/rule_params_institutional.dart';
export 'package:afterclose/core/constants/rule_params_pattern.dart';
export 'package:afterclose/core/constants/rule_params_trend.dart';
export 'package:afterclose/core/constants/rule_scores.dart';

/// 規則引擎通用參數
///
/// 跨類別的通用常數（回溯天數、候選篩選、評分輸出、新聞關鍵字等）。
/// 領域特定參數已拆至：
/// - [TrendParams] — 趨勢 / 反轉 / 支撐壓力 / 價量背離
/// - [IndicatorParams] — RSI / KD / 均線 / 52 週高低點
/// - [InstitutionalParams] — 法人動向 / 籌碼面
/// - [FundamentalParams] — 基本面 / EPS / ROE / 估值 / 董監持股
/// - [PatternParams] — K 線型態
/// - [AlertParams] — 警示系統
///
/// ### 數值慣例
/// - **比例值**（0.0~1.0）：用於乘法運算，如 `price * (1 + ratio)`
///   例：`breakoutBuffer = 0.03`（3%）、`maDeviationThreshold = 0.05`（5%）
/// - **百分比值**（0~100）：用於直接比較，如 `if (rsi >= threshold)`
///   例：`rsiOverbought = 75.0`、`dayTradingHighThreshold = 50.0`
/// - **倍數值**：用於量能比較，如 `volume >= avg * multiplier`
///   例：`volumeSpikeMult = 4.0`、`priceSpikeVolumeMult = 1.5`
abstract final class RuleParams {
  // ==================================================
  // 回溯與歷史資料
  // ==================================================

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

  /// 候選股篩選時提前載入的緩衝天數
  ///
  /// 確保技術指標計算時有足夠的歷史資料。
  /// 與 [historyBufferDays] 區分：此值用於候選篩選，後者用於分析邊界。
  static const int historyLoadBuffer = 20;

  /// 成交量均線天數
  static const int volMa = 20;

  /// 壓力/支撐偵測回溯天數
  static const int rangeLookback = 60;

  /// 波段高低點偵測視窗
  static const int swingWindow = 20;

  // ==================================================
  // 候選股篩選
  // ==================================================

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
  static const double minDayTradingVolumeShares = 10000000;

  /// 極高當沖規則最低成交量（30,000 張 = 30,000,000 股）
  static const double minDayTradingExtremeVolumeShares = 30000000;

  /// 候選股快篩最低成交量（100 張 = 100,000 股）
  ///
  /// 過濾極低成交量冷門股，確保分析品質。
  static const double minQuickFilterVolumeShares = 100000;

  // ==================================================
  // 新聞規則關鍵字
  // ==================================================

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

  // ==================================================
  // 評分與輸出
  // ==================================================

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

  // ==================================================
  // 流動性加權排序
  // ==================================================

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

  // ==================================================
  // 雜項
  // ==================================================

  /// 1 張 = 1000 股
  static const int sheetToShares = 1000;

  /// 新聞回溯時間（小時）
  static const int newsLookbackHours = 120;
}
