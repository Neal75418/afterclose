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
  static final _validCode = RegExp(r'^(\d{4}|00\d{3,4})$');

  /// 上櫃股票代碼模式
  ///
  /// 上櫃市場僅有 4 位數字的股票，不包含 00xxx ETF 代碼。
  ///
  /// 00xxxx ETF **並非**全在上市——上櫃另有「上櫃ETF」（stock_master
  /// 實測 14 檔，如 006201 元大富櫃50），價格宇宙判定用
  /// [isTpexPriceCode]（2026-07-23 稽核修復：每日與歷史回補 parser
  /// 行為統一）。
  static final _tpexCode = RegExp(r'^\d{4}$');

  /// 上櫃 ETF：00 開頭 5-6 碼**純數字**（stock_master 14 檔實測全符合）。
  ///
  /// 刻意不含字母尾碼債券 ETF（00679B 等）——不在 stock_master 宇宙，
  /// 放行也會被 repo 端 targetSymbols 過濾，維持排除以免權證類誤入。
  static final _tpexEtfCode = RegExp(r'^00\d{3,4}$');

  /// 檢查是否為有效股票代碼
  static bool isValidCode(String code) => _validCode.hasMatch(code);

  /// 檢查是否為上櫃股票代碼
  static bool isTpexCode(String code) => _tpexCode.hasMatch(code);

  /// 上櫃 ETF 代碼（00 開頭 5-6 碼純數字）
  static bool isTpexEtfCode(String code) => _tpexEtfCode.hasMatch(code);

  /// 上櫃「價格宇宙」判定：一般個股（4 碼）或上櫃 ETF。
  ///
  /// 每日價格 parser 專用——與歷史回補的宇宙一致，避免「歷史有、
  /// 每日無」的資料洞讓缺漏偵測反覆嘗試回補。
  static bool isTpexPriceCode(String code) =>
      isTpexCode(code) || isTpexEtfCode(code);

  /// 檢查是否為 ETF/ETN 代碼（00 開頭，如 0050、00878、006208）
  ///
  /// 用途：回檔類規則排除 ETF（走勢平滑、淺回檔幾乎天天成立 = 雜訊，
  /// 與 mode tab 的 ETF 過濾同一判斷）、財報同步跳過（ETF 無財報）。
  static bool isEtfCode(String code) => code.startsWith('00');
}
