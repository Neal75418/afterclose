/// 趨勢 / 反轉 / 支撐壓力 / 價量背離參數
///
/// Used by: volume_rules.dart, breakout_rules.dart, technical_rules.dart,
/// technical_analysis_service.dart, divergence_rules.dart
abstract final class TrendParams {
  // ==================================================
  // 價格 / 成交量異動
  // ==================================================

  /// 價格異動門檻百分比（5%）
  ///
  /// 從 7% 降至 5%，原 7% 接近台股漲跌幅極值（10%），
  /// 導致 5-6% 的顯著異動被錯過。
  static const double priceSpikePercent = 5.0;

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

  // ==================================================
  // 突破 / 跌破 / 支撐壓力
  // ==================================================

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

  // ==================================================
  // 趨勢偵測 / 反轉確認
  // ==================================================

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
  /// 頭部反轉不需要像底部反轉那樣嚴格。
  static const double lowerHighBuffer = 0.95;

  /// 反轉/突破訊號成交量確認門檻（多方）
  ///
  /// 近期成交量需達前期平均的此倍數以上。
  /// 用於弱轉強（底部反轉）訊號確認。
  static const double reversalVolumeConfirm = 1.5;

  /// 強轉弱成交量確認門檻
  ///
  /// 頭部反轉（強轉弱）的成交量要求較寬鬆。
  /// 頭部形成時往往是「量縮」而非「量增」，
  /// 因此只需要基本成交量即可。
  static const double s2wVolumeConfirm = 0.8;

  // ==================================================
  // ATR 與支撐壓力搜尋
  // ==================================================

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

  // ==================================================
  // 價量背離
  // ==================================================

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
  /// 價格需在 60 日區間後 25% 才視為「低位」。
  static const double lowPositionThreshold = 0.25;

  /// 背離價格變動門檻（%）
  static const double divergencePriceThreshold = 1.0;

  /// 背離成交量變動門檻（%）
  static const double divergenceVolumeThreshold = 10.0;

  /// 低檔吸籌成交量比率門檻
  static const double lowAccumulationVolumeRatio = 0.6;
}
