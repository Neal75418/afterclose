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

/// 52 週新高/新低的回看交易日數（一年約 252 個交易日）。
///
/// 用於 [getNewHighLowCountsByMarket]：以個股今日收盤對比 trailing-252
/// 日的最高/最低收盤，判定是否創 52 週新高（close ≥ 252 日內最高）或
/// 新低（close ≤ 252 日內最低），為廣度趨勢（market breadth trend）的
/// 經典指標。窗口固定 252，不受半套日影響（高低點本質上仍有效）。
const int kNewHighLowLookbackDays = 252;

/// AD 騰落線（Advance-Decline Line）累積所回看的完整覆蓋交易日數。
///
/// 騰落線為每日 (上漲 − 下跌) 家數的累積running sum，需足夠天數才能呈現
/// 有意義的廣度趨勢 / 背離訊號。實際取得天數受完整覆蓋日濾除影響（半套日
/// 會被 [getRecentAdvanceDeclineByMarket] 排除），故設 60 個交易日為窗口。
const int kAdLineLookbackDays = 60;
