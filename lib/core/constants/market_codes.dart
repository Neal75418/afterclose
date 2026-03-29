/// 台灣股票市場代碼常數
///
/// 用於區分上市（TWSE）與上櫃（TPEx）股票。
/// 所有市場代碼比對應使用此常數，避免散落的魔術字串。
abstract final class MarketCode {
  /// 台灣證券交易所（上市）
  static const String twse = 'TWSE';

  /// 證券櫃檯買賣中心（上櫃）
  static const String tpex = 'TPEx';
}
