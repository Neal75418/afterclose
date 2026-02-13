import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/models/finmind/institutional.dart';
import 'package:afterclose/data/models/twse/twse_market_index.dart';
import 'package:drift/drift.dart';

/// FinMind 法人資料轉換 Extension
///
/// 將 FinMind API 回應轉換為資料庫 Companion 物件
extension FinMindInstitutionalExt on FinMindInstitutional {
  /// 轉換為資料庫 Companion 物件
  ///
  /// [date] 正規化的日期（已去除時間部分）
  DailyInstitutionalCompanion toDatabaseCompanion(DateTime date) {
    return DailyInstitutionalCompanion.insert(
      symbol: stockId,
      date: date,
      foreignNet: Value(foreignNet),
      investmentTrustNet: Value(investmentTrustNet),
      dealerNet: Value(dealerNet),
    );
  }
}

/// TWSE 市場指數轉換 Extension
///
/// 將 TWSE API 回應轉換為資料庫 Companion 物件
extension TwseMarketIndexExt on TwseMarketIndex {
  /// 轉換為資料庫 Companion 物件
  MarketIndexCompanion toDatabaseCompanion() {
    return MarketIndexCompanion(
      date: Value(date),
      name: Value(name),
      close: Value(close),
      change: Value(change),
      changePercent: Value(changePercent),
    );
  }
}
