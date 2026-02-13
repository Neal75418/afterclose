import 'package:afterclose/core/utils/logger.dart';

/// Circuit Breaker 異常 - 當熔斷器開啟時拋出
class CircuitBreakerOpenException implements Exception {
  CircuitBreakerOpenException(this.message);

  final String message;

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}

/// Circuit Breaker（熔斷器）
///
/// 當 API 連續失敗達到閾值時，自動「熔斷」並快速失敗，
/// 避免無效的重試。經過冷卻期後自動重置。
///
/// 使用場景：
/// - API 服務暫時不可用
/// - 避免重複呼叫已知故障的服務
/// - 保護系統不被故障服務拖垮
///
/// 範例：
/// ```dart
/// final breaker = CircuitBreaker(name: 'FinMindAPI');
///
/// try {
///   final data = await breaker.call(() => _client.fetchData());
/// } on CircuitBreakerOpenException catch (e) {
///   // 熔斷器開啟，使用快取或顯示錯誤訊息
/// }
/// ```
class CircuitBreaker {
  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.resetTimeoutMs = 60000,
  });

  /// 熔斷器名稱（用於日誌）
  final String name;

  /// 失敗閾值（連續失敗幾次後開啟熔斷器）
  final int failureThreshold;

  /// 重置超時時間（毫秒）
  final int resetTimeoutMs;

  /// 當前失敗計數
  int _failureCount = 0;

  /// 最後一次失敗的時間
  DateTime? _lastFailureTime;

  /// 熔斷器狀態
  CircuitBreakerState get state {
    if (_failureCount >= failureThreshold) {
      final elapsed = DateTime.now()
          .difference(_lastFailureTime!)
          .inMilliseconds;
      if (elapsed < resetTimeoutMs) {
        return CircuitBreakerState.open;
      } else {
        return CircuitBreakerState.halfOpen;
      }
    }
    return CircuitBreakerState.closed;
  }

  /// 執行操作，並根據結果更新熔斷器狀態
  Future<T> call<T>(Future<T> Function() operation) async {
    final currentState = state;

    // 熔斷器開啟：快速失敗
    if (currentState == CircuitBreakerState.open) {
      final remainingMs =
          resetTimeoutMs -
          DateTime.now().difference(_lastFailureTime!).inMilliseconds;

      AppLogger.warning(
        'CircuitBreaker',
        '[$name] 熔斷器開啟，剩餘 ${remainingMs}ms 後重試',
      );

      throw CircuitBreakerOpenException(
        '[$name] Circuit breaker is open. Retry after ${remainingMs}ms',
      );
    }

    // 半開狀態：嘗試一次請求
    if (currentState == CircuitBreakerState.halfOpen) {
      AppLogger.info('CircuitBreaker', '[$name] 熔斷器半開，嘗試恢復');
    }

    try {
      final result = await operation();

      // 成功：重置計數器
      if (_failureCount > 0) {
        AppLogger.info(
          'CircuitBreaker',
          '[$name] 操作成功，重置失敗計數（之前 $_failureCount 次失敗）',
        );
        _failureCount = 0;
      }

      return result;
    } catch (e) {
      // 失敗：增加計數
      _failureCount++;
      _lastFailureTime = DateTime.now();

      if (_failureCount >= failureThreshold) {
        AppLogger.error(
          'CircuitBreaker',
          '[$name] 達到失敗閾值（$failureThreshold），開啟熔斷器',
          e,
        );
      } else {
        AppLogger.warning(
          'CircuitBreaker',
          '[$name] 操作失敗（$_failureCount/$failureThreshold）',
        );
      }

      rethrow;
    }
  }

  /// 手動重置熔斷器
  void reset() {
    _failureCount = 0;
    _lastFailureTime = null;
    AppLogger.info('CircuitBreaker', '[$name] 手動重置');
  }

  /// 取得統計資訊
  CircuitBreakerStats get stats => CircuitBreakerStats(
    name: name,
    state: state,
    failureCount: _failureCount,
    lastFailureTime: _lastFailureTime,
  );
}

/// 熔斷器狀態
enum CircuitBreakerState {
  /// 關閉：正常運作
  closed,

  /// 開啟：快速失敗，拒絕所有請求
  open,

  /// 半開：嘗試恢復，允許一個請求通過測試
  halfOpen,
}

/// 熔斷器統計資訊
class CircuitBreakerStats {
  const CircuitBreakerStats({
    required this.name,
    required this.state,
    required this.failureCount,
    this.lastFailureTime,
  });

  final String name;
  final CircuitBreakerState state;
  final int failureCount;
  final DateTime? lastFailureTime;

  @override
  String toString() {
    return 'CircuitBreaker[$name]: '
        'state=$state, '
        'failures=$failureCount, '
        'lastFailure=${lastFailureTime?.toIso8601String() ?? 'N/A'}';
  }
}
