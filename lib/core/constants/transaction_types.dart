/// 交易類型字串常數（Domain / Data 層使用）
///
/// 與 presentation/providers/portfolio_provider.dart 的 TransactionType.value 同步。
/// Domain 層不應直接引用 presentation 層列舉，故在此集中管理字串值。
abstract final class TransactionTypes {
  static const String buy = 'BUY';
  static const String sell = 'SELL';
  static const String dividendCash = 'DIVIDEND_CASH';
  static const String dividendStock = 'DIVIDEND_STOCK';
}
