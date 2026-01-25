/// 價量關係狀態
enum PriceVolumeState {
  /// 中性 - 無顯著背離
  neutral,

  /// 價漲量縮 - 上漲無力警訊
  bullishDivergence,

  /// 價跌量增 - 恐慌殺盤
  bearishDivergence,

  /// 高檔爆量 - 可能出貨
  highVolumeAtHigh,

  /// 低檔縮量 - 可能吸籌
  lowVolumeAtLow,

  /// 健康上漲 - 價漲量增
  healthyUptrend,
}

/// 價量分析結果
class PriceVolumeAnalysis {
  const PriceVolumeAnalysis({
    required this.state,
    this.priceChangePercent,
    this.volumeChangePercent,
    this.pricePosition,
  });

  final PriceVolumeState state;
  final double? priceChangePercent;
  final double? volumeChangePercent;
  final double? pricePosition;

  bool get hasDivergence =>
      state == PriceVolumeState.bullishDivergence ||
      state == PriceVolumeState.bearishDivergence;
}
