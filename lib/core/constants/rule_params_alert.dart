/// 警示系統參數（Alert System）
///
/// Used by: user_dao.dart (Alert checking methods)
abstract final class AlertParams {
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

  /// KD 指標 - K 值計算期數
  ///
  /// %K 使用過去 N 個交易日的高低價範圍計算。
  static const int kdKPeriod = 9;

  /// KD 指標 - D 值計算期數
  ///
  /// %D 是 %K 的 N 日簡單移動平均。
  static const int kdDPeriod = 3;

  /// 均線交叉 - 檢測視窗（最近 N 天內）
  ///
  /// 檢查最近 N 天內是否發生過均線交叉（而非只檢查當下是否正在交叉）。
  /// 使用 2 天視窗避免錯過前一日的交叉訊號。
  static const int maCrossoverDetectionWindow = 2;

  /// KD 交叉 - 檢測視窗（最近 N 天內）
  ///
  /// 檢查最近 N 天內是否發生過 KD 交叉（而非只檢查當下是否正在交叉）。
  /// 使用 2 天視窗避免錯過前一日的交叉訊號。
  static const int kdCrossoverDetectionWindow = 2;

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
}
