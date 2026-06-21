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

/// 判定「完整覆蓋交易日」的最低個股報價數門檻。
///
/// 本地資料庫部分日子僅同步候選子集（約半市場：TWSE ~531 / TPEx ~338），
/// 完整日為 TWSE ~1220 / TPEx ~876。市場 rolling 統計（成交額均量、情緒
/// 量能）若混入半套日會使均值嚴重失真（曾出現假性「5日均 +278%」），故
/// 須濾除半套日。門檻 700 介於半套（≤531）與完整（≥876）之間，可同時
/// 乾淨切開上市與上櫃兩市場。
const int kMinSymbolsForCompleteTradingDay = 700;
