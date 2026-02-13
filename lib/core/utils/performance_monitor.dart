import 'package:afterclose/core/utils/logger.dart';

/// 效能監測系統（單例模式）
///
/// ⚠️ 注意：此類別使用靜態狀態儲存效能指標，適合在生產環境中使用。
/// 在測試環境中，每個測試完成後應呼叫 `PerformanceMonitor.reset()` 以清除狀態。
///
/// 監控關鍵操作的執行時間，用於：
/// - 識別效能瓶頸
/// - 追蹤效能趨勢
/// - 觸發效能警告
///
/// 使用範例：
/// ```dart
/// // 監測單一操作
/// final result = await PerformanceMonitor.measure(
///   'ScanService.evaluateAllStocks',
///   () => _scanService.evaluateAllStocks(date),
/// );
///
/// // 查看統計資訊
/// final stats = PerformanceMonitor.getStatistics();
/// print(stats);
///
/// // 測試中清除狀態
/// tearDown(() {
///   PerformanceMonitor.reset();
/// });
/// ```
class PerformanceMonitor {
  /// 效能指標儲存
  /// Key: 操作名稱
  /// Value: 執行時間清單（毫秒）
  static final Map<String, List<int>> _metrics = {};

  /// 操作計數器
  static final Map<String, int> _counts = {};

  /// 效能警告閾值（毫秒）
  static const int warningThresholdMs = 1000;

  /// 效能嚴重警告閾值（毫秒）
  static const int criticalThresholdMs = 3000;

  /// 最大記錄數量（每個操作）
  static const int maxRecordsPerOperation = 100;

  /// 監測非同步操作
  ///
  /// 回傳操作結果，並記錄執行時間
  static Future<T> measure<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      return await operation();
    } finally {
      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;

      _recordMetric(operationName, durationMs);
      _logPerformance(operationName, durationMs);
    }
  }

  /// 監測同步操作
  static T measureSync<T>(String operationName, T Function() operation) {
    final stopwatch = Stopwatch()..start();

    try {
      return operation();
    } finally {
      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;

      _recordMetric(operationName, durationMs);
      _logPerformance(operationName, durationMs);
    }
  }

  /// 記錄效能指標
  static void _recordMetric(String operationName, int durationMs) {
    // 初始化清單
    _metrics.putIfAbsent(operationName, () => []);
    _counts.putIfAbsent(operationName, () => 0);

    // 記錄執行時間
    final metrics = _metrics[operationName]!;
    metrics.add(durationMs);

    // 限制記錄數量（FIFO）
    if (metrics.length > maxRecordsPerOperation) {
      metrics.removeAt(0);
    }

    // 更新計數
    _counts[operationName] = _counts[operationName]! + 1;
  }

  /// 記錄效能日誌
  static void _logPerformance(String operationName, int durationMs) {
    if (durationMs >= criticalThresholdMs) {
      AppLogger.error(
        'Performance',
        '[$operationName] 執行時間過長: ${durationMs}ms (嚴重)',
      );
    } else if (durationMs >= warningThresholdMs) {
      AppLogger.warning(
        'Performance',
        '[$operationName] 執行時間過長: ${durationMs}ms',
      );
    } else {
      AppLogger.debug('Performance', '[$operationName] 執行完成: ${durationMs}ms');
    }
  }

  /// 取得所有操作的統計資訊
  static Map<String, OperationStats> getStatistics() {
    final stats = <String, OperationStats>{};

    for (final operation in _metrics.keys) {
      final durations = _metrics[operation]!;
      final count = _counts[operation]!;

      if (durations.isEmpty) continue;

      // 計算統計值
      final sorted = List<int>.from(durations)..sort();
      final avg = durations.reduce((a, b) => a + b) / durations.length;
      final min = sorted.first;
      final max = sorted.last;
      final p50 = sorted[(sorted.length * 0.5).floor()];
      final p95 = sorted[(sorted.length * 0.95).floor()];
      final p99 = sorted[(sorted.length * 0.99).floor()];

      stats[operation] = OperationStats(
        operationName: operation,
        totalCount: count,
        sampleCount: durations.length,
        averageMs: avg,
        minMs: min,
        maxMs: max,
        p50Ms: p50,
        p95Ms: p95,
        p99Ms: p99,
      );
    }

    return stats;
  }

  /// 取得單一操作的統計資訊
  static OperationStats? getOperationStats(String operationName) {
    return getStatistics()[operationName];
  }

  /// 列印所有統計資訊
  static void printStatistics() {
    final stats = getStatistics();

    if (stats.isEmpty) {
      AppLogger.info('Performance', '無效能統計資料');
      return;
    }

    AppLogger.info('Performance', '=== 效能統計 ===');

    // 按平均執行時間排序
    final sorted = stats.values.toList()
      ..sort((a, b) => b.averageMs.compareTo(a.averageMs));

    for (final stat in sorted) {
      AppLogger.info('Performance', stat.toString());
    }
  }

  /// 重置所有統計資料
  static void reset() {
    _metrics.clear();
    _counts.clear();
    AppLogger.info('Performance', '效能統計已重置');
  }

  /// 重置特定操作的統計資料
  static void resetOperation(String operationName) {
    _metrics.remove(operationName);
    _counts.remove(operationName);
    AppLogger.info('Performance', '[$operationName] 效能統計已重置');
  }
}

/// 操作統計資訊
class OperationStats {
  const OperationStats({
    required this.operationName,
    required this.totalCount,
    required this.sampleCount,
    required this.averageMs,
    required this.minMs,
    required this.maxMs,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
  });

  /// 操作名稱
  final String operationName;

  /// 總執行次數
  final int totalCount;

  /// 樣本數量
  final int sampleCount;

  /// 平均執行時間（毫秒）
  final double averageMs;

  /// 最小執行時間（毫秒）
  final int minMs;

  /// 最大執行時間（毫秒）
  final int maxMs;

  /// P50 執行時間（毫秒）
  final int p50Ms;

  /// P95 執行時間（毫秒）
  final int p95Ms;

  /// P99 執行時間（毫秒）
  final int p99Ms;

  @override
  String toString() {
    return '[$operationName] '
        'total=$totalCount, '
        'avg=${averageMs.toStringAsFixed(1)}ms, '
        'min=${minMs}ms, '
        'max=${maxMs}ms, '
        'p50=${p50Ms}ms, '
        'p95=${p95Ms}ms, '
        'p99=${p99Ms}ms';
  }

  /// 轉換為 JSON
  Map<String, dynamic> toJson() {
    return {
      'operationName': operationName,
      'totalCount': totalCount,
      'sampleCount': sampleCount,
      'averageMs': averageMs,
      'minMs': minMs,
      'maxMs': maxMs,
      'p50Ms': p50Ms,
      'p95Ms': p95Ms,
      'p99Ms': p99Ms,
    };
  }
}
