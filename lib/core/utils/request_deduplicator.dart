/// Request Deduplication 機制
///
/// 防止同一時間對相同資源發起多個重複請求，
/// 適用於多個 Provider 同時請求相同資料的場景。
///
/// 範例：
/// ```dart
/// final dedup = RequestDeduplicator<List<StockMasterEntry>>();
/// final stocks = await dedup.call('stock_list', () => _repo.getStockList());
/// ```
class RequestDeduplicator<T> {
  /// 儲存進行中的請求
  ///
  /// Key: 請求的唯一識別碼
  /// Value: 進行中的 Future
  final Map<String, Future<T>> _pending = {};

  /// 執行請求，若相同 key 的請求正在進行中則等待該請求完成
  ///
  /// [key] 請求的唯一識別碼（例如：'stock_list', 'price_2024-01-01', 'analysis_2330'）
  /// [fetch] 實際執行請求的函式
  ///
  /// 回傳值：
  /// - 若該 key 的請求正在進行中，回傳現有 Future 的結果
  /// - 否則執行新請求並快取 Future
  Future<T> call(String key, Future<T> Function() fetch) async {
    // 檢查是否已有進行中的請求
    final existing = _pending[key];
    if (existing != null) {
      return existing;
    }

    // 執行新請求
    final future = fetch();
    _pending[key] = future;

    try {
      return await future;
    } finally {
      // 請求完成後清除快取，允許後續請求重新執行
      _pending.remove(key);
    }
  }
}
