/// 警示系統參數（Alert System）
///
/// Used by: user_dao.dart (Alert checking methods)
abstract final class AlertParams {
  // --------------------------------------------------
  // 警示類型字串常數
  // 與 presentation/providers/price_alert_provider.dart 的 AlertType.value 同步
  // --------------------------------------------------
  static const String typeAbove = 'ABOVE';
  static const String typeBelow = 'BELOW';
  static const String typeChangePct = 'CHANGE_PCT';
  static const String typeVolumeSpike = 'VOLUME_SPIKE';
  static const String typeVolumeAbove = 'VOLUME_ABOVE';
  static const String typeWeek52High = 'WEEK_52_HIGH';
  static const String typeWeek52Low = 'WEEK_52_LOW';
  static const String typeRsiOverbought = 'RSI_OVERBOUGHT';
  static const String typeRsiOversold = 'RSI_OVERSOLD';
  static const String typeKdGoldenCross = 'KD_GOLDEN_CROSS';
  static const String typeKdDeathCross = 'KD_DEATH_CROSS';
  static const String typeCrossAboveMa = 'CROSS_ABOVE_MA';
  static const String typeCrossBelowMa = 'CROSS_BELOW_MA';
  static const String typeTradingWarning = 'TRADING_WARNING';
  static const String typeTradingDisposal = 'TRADING_DISPOSAL';
  static const String typeBreakResistance = 'BREAK_RESISTANCE';
  static const String typeBreakSupport = 'BREAK_SUPPORT';
  static const String typeRevenueYoySurge = 'REVENUE_YOY_SURGE';
  static const String typeHighDividendYield = 'HIGH_DIVIDEND_YIELD';
  static const String typePeUndervalued = 'PE_UNDERVALUED';
  static const String typeInsiderSelling = 'INSIDER_SELLING';
  static const String typeInsiderBuying = 'INSIDER_BUYING';
  static const String typeHighPledgeRatio = 'HIGH_PLEDGE_RATIO';

  /// 成交量警示 - 資料查詢天數（確保有 20 個交易日）
  ///
  /// 需足夠涵蓋 20 個交易日的成交量資料。
  /// 20 交易日 ÷ 0.71（扣除週末假日比例）≈ 28 日曆日，使用 30 日確保緩衝。
  static const int volumeDataLookbackDays = 30;

  /// 成交量警示 - 均量計算視窗（20 日均量）
  ///
  /// 計算平均成交量時使用的交易日數量。
  static const int volumeSmaWindow = 20;

  /// RSI 警示 - 最少資料點（14 期 + 1）
  ///
  /// RSI 計算需要至少 14 個交易日的資料，加上當前資料點。
  static const int rsiMinDataPoints = 15;

  /// KD 警示 - 最少資料點（9 期 + 2）
  ///
  /// KD 計算需要至少 9 個交易日（K 值週期）+ 2 個額外資料點（D 值平滑）。
  static const int kdMinDataPoints = 11;

  /// 指標資料查詢天數（RSI/KD 計算所需）
  ///
  /// 需足夠涵蓋 30 個交易日的指標計算資料（RSI 14 期 + KD 9 期 + 緩衝）。
  /// 30 交易日 ÷ 0.71（扣除週末假日比例）≈ 42 日曆日，使用 40 日確保足夠資料。
  static const int indicatorDataLookbackDays = 40;

  /// 52 週價格歷史查詢天數
  ///
  /// 需足夠涵蓋 52 週（約 250 交易日）。
  /// 250 交易日 ÷ 0.71（扣除週末假日比例）≈ 352 日曆日。
  /// 使用 370 日曆日確保有足夠緩衝（與 lookbackPrice 一致）。
  static const int week52LookbackDays = 370;

  // --------------------------------------------------
  // 新增警示時的預設目標值
  // --------------------------------------------------

  /// RSI 超買警示預設門檻（70）— Wilder 慣例的 RSI 警示線。
  ///
  /// 警示系統自有的 70，與 [IndicatorParams] 規則引擎的 RSI 帶
  /// （`rsiNeutralHigh=70` K 線過濾用、`rsiExtremeOversold=30` 反彈訊號用）**語意無關**，
  /// 僅數值恰好相同。刻意獨立宣告，避免有人調整規則引擎門檻時連帶移動使用者警示線。
  static const double defaultRsiOverbought = 70.0;

  /// RSI 超賣警示預設門檻（30）— Wilder 慣例的 RSI 警示線。見 [defaultRsiOverbought]。
  static const double defaultRsiOversold = 30.0;

  /// MA 交叉警示預設均線天數（20 日）
  static const double defaultMaCrossDays = 20.0;

  /// 爆量警示預設倍數（2 倍均量）
  static const double defaultVolumeSpikeMultiplier = 2.0;

  /// 營收 YoY 飆升警示預設門檻（+30%）
  static const double defaultRevenueYoySurgePct = 30.0;

  /// 高殖利率警示預設門檻（5%）
  static const double defaultHighDividendYieldPct = 5.0;

  /// 低本益比警示預設門檻（PE < 10）
  static const double defaultPeUndervalued = 10.0;
}
