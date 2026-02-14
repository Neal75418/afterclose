import 'package:afterclose/data/database/app_database.dart';

/// 事件日曆儲存庫介面
///
/// 管理股票事件（除權息、自訂事件）的查詢與同步功能。
/// 支援測試時的 Mock 及不同實作。
abstract class IEventRepository {
  /// 取得日期範圍內的事件
  Future<List<StockEventEntry>> getEventsInRange(
    DateTime start,
    DateTime end, {
    List<String>? symbols,
  });

  /// 取得股票的所有事件
  Future<List<StockEventEntry>> getEventsForSymbol(String symbol);

  /// 新增自訂事件
  Future<int> addCustomEvent({
    String? symbol,
    required DateTime eventDate,
    required String title,
    String? description,
  });

  /// 刪除事件
  Future<void> deleteEvent(int id);

  /// 同步除權息事件
  Future<int> syncDividendEvents();
}
