/// 股票代碼驗證模式
///
/// 集中管理股票代碼的驗證邏輯，確保全專案一致性。
abstract final class StockPatterns {
  /// 有效股票代碼模式（上市 + 上櫃）
  ///
  /// 允許：
  /// - 4 位數字（一般股票，如 2330、1101）
  /// - 00 開頭的 ETF（如 0050、00878、006208）
  ///
  /// 排除：
  /// - 6 位數權證（如 030001）
  /// - TDR（如 911608、912000）
  /// - 其他非標準代碼
  static final validCode = RegExp(r'^(\d{4}|00\d{3,4})$');

  /// 上櫃股票代碼模式
  ///
  /// 上櫃市場僅有 4 位數字的股票，不包含 00xxx ETF。
  /// 00xxx ETF 皆在上市市場（TWSE）交易。
  static final tpexCode = RegExp(r'^\d{4}$');

  /// 檢查是否為有效股票代碼
  static bool isValidCode(String code) => validCode.hasMatch(code);

  /// 檢查是否為上櫃股票代碼
  static bool isTpexCode(String code) => tpexCode.hasMatch(code);
}
