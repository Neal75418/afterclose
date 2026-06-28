export 'package:afterclose/core/constants/reason_type.dart';
export 'package:afterclose/core/constants/rule_enums.dart';
export 'package:afterclose/core/constants/rule_params_alert.dart';
export 'package:afterclose/core/constants/rule_params_fundamental.dart';
export 'package:afterclose/core/constants/rule_params_indicator.dart';
export 'package:afterclose/core/constants/rule_params_institutional.dart';
export 'package:afterclose/core/constants/rule_params_pattern.dart';
export 'package:afterclose/core/constants/rule_params_pullback.dart';
export 'package:afterclose/core/constants/rule_params_sector.dart';
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
/// - [PullbackParams] — 強股回檔進場（Mode C v2）
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

  /// 成交量均線最低有效交易日比例
  ///
  /// 計算 `volMa` 均量時要求至少此比例的窗口期內有有效成交量
  /// （`volume > 0`，過濾停牌日），避免復牌後因基期過低產生
  /// 假訊號。0.8 = 20 日中至少 16 日。
  static const double volMaMinValidDayRatio = 0.8;

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
  ///
  /// 每個詞須足夠具體以避免誤判。避免單字詞（如「訂單」「突破」）
  /// 因在中文語境中常出現在無關或相反的上下文中。
  static const List<String> newsPositiveKeywords = [
    // 營收相關
    '營收創新高',
    '營收成長',
    '業績亮眼',
    '獲利創高',
    '毛利率上升',
    // 訂單/產能（具體化，避免「訂單」「大單」「拿下」等單字詞）
    '接獲訂單',
    '拿下訂單',
    '接獲大單',
    '擴產',
    '產能滿載',
    // 法人動態
    '法說會',
    '外資買超',
    '投信買超',
    // 市場動態（具體化，避免「突破」「看好」等單字詞）
    '利多',
    '漲停',
    '調升目標價',
    '目標價調升',
    '前景看好',
  ];

  /// 新聞情緒分析負面關鍵字
  ///
  /// 「庫存」單獨出現容易誤判（如「庫存回補」是正面訊號），
  /// 改用更具體的組合。
  static const List<String> newsNegativeKeywords = [
    // 營收相關
    '營收衰退',
    '營收下滑',
    '獲利下滑',
    '虧損',
    '毛利率下降',
    // 訂單/產能（「庫存」改為具體化）
    '砍單',
    '減產',
    '庫存偏高',
    '庫存壓力',
    '去化壓力',
    // 市場動態
    '利空',
    '跌停',
    '調降目標價',
    '目標價下修',
    // 公司治理
    '減資',
    '違約',
    '掏空',
    '解任',
  ];

  // ==================================================
  // 評分與輸出
  // ==================================================

  /// 每檔股票最多理由數（資料庫儲存用，供篩選功能使用）
  /// 設為 64 確保所有規則都能被儲存（目前 64 條規則；單股每規則最多 1 理由 → 上限 64）
  /// UI 顯示時會用 .take(2) 或 .take(3) 限制
  static const int maxReasonsPerStock = 64;

  /// 每日 Top N 推薦數量
  ///
  /// 上市+上櫃共約 1,770 檔股票，20 檔可提供足夠多樣性
  static const int dailyTopN = 20;

  /// 最低評分門檻
  ///
  /// 過濾掉完全沒有真實 signal rule 的股票（如僅命中 CONCENTRATION_HIGH /
  /// REVENUE_NEW_HIGH 等 demote 為 0 分的 noise filter rule）。
  ///
  /// **2026-06-19 從 25 降至 12**（搭配 audit demote）：
  /// 之前 25 預期至少 1 個強訊號 (~22) 或 2 個中等訊號 (16+18=34)。但 audit
  /// 把 CONCENTRATION_HIGH 16 + REVENUE_NEW_HIGH 22 兩條最常觸發的 rule
  /// 降至 0，原本靠 16+22=38 過閾值的 ~17 檔股票全部被 skip 寫進
  /// daily_reason，導致 user 看到 top 20 只剩 2-3 檔。
  ///
  /// 新值 12 = 任 1 條真實 signal rule（PBR_UNDERVALUED 12 / PE_UNDERVALUED 15
  /// / EPS_TURNAROUND 15 / DAY_TRADING_HIGH 12 / 反轉類更高）通過。
  /// 12 是當前 hardcoded scores 中「最弱但仍 actionable」的單條訊號值。
  /// 只命中 noise rule（CONCENTRATION_HIGH / REVENUE_NEW_HIGH 等 0 分項）
  /// 的股票仍被正確過濾掉。
  static const int minScoreThreshold = 12;

  /// 觀察門檻：分數 ≥ 此值但 < [minScoreThreshold] = 「接近觸發」，進掃描頁
  /// 「觀察區」（早期預警：盯著看但訊號尚未成立）。8 ≈ 走到訊號門檻 12 的
  /// 2/3，算真的在接近；低於此值僅雜訊、不持久化。任一 horizon ≥ 此值即保留。
  static const int observationScoreThreshold = 8;

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
