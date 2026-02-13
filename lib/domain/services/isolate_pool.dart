import 'dart:async';
import 'dart:isolate';

import 'package:afterclose/core/utils/logger.dart';

/// Isolate 池管理器
///
/// 重用 Isolate 而非每次都創建新的，減少啟動開銷和記憶體佔用。
///
/// 適用場景：
/// - 批次評分計算
/// - 大量資料處理
/// - CPU 密集型任務
///
/// 使用範例：
/// ```dart
/// final pool = IsolatePool(workerCount: 4);
/// await pool.initialize(workerFunction);
///
/// // 提交任務
/// final result = await pool.execute(taskData);
///
/// // 關閉池
/// await pool.dispose();
/// ```
class IsolatePool<T, R> {
  IsolatePool({required this.workerCount, required this.workerFunction}) {
    _workers = List.filled(workerCount, null);
    _workerBusy = List.filled(workerCount, false);
  }

  /// Worker 數量
  final int workerCount;

  /// Worker 函式（Isolate 入口點）
  final void Function(SendPort) workerFunction;

  /// Worker 列表
  late List<_IsolateWorker?> _workers;

  /// Worker 忙碌狀態
  late List<bool> _workerBusy;

  /// 是否已初始化
  bool _initialized = false;

  /// 當前的 round-robin 索引
  int _nextWorkerIndex = 0;

  /// 初始化 Isolate 池
  Future<void> initialize() async {
    if (_initialized) {
      AppLogger.warning('IsolatePool', '已經初始化，跳過');
      return;
    }

    AppLogger.info('IsolatePool', '初始化 $workerCount 個 Worker');

    // 建立所有 Worker
    for (var i = 0; i < workerCount; i++) {
      _workers[i] = await _createWorker(i);
    }

    _initialized = true;
    AppLogger.info('IsolatePool', 'Isolate 池初始化完成');
  }

  /// 建立單一 Worker
  Future<_IsolateWorker> _createWorker(int workerId) async {
    // 創建一次性 ReceivePort 用於接收 SendPort
    final handshakePort = ReceivePort();

    // 啟動 Isolate
    final isolate = await Isolate.spawn(
      workerFunction,
      handshakePort.sendPort,
      debugName: 'Worker-$workerId',
    );

    // 等待 Worker 發送 SendPort
    final sendPort = await handshakePort.first as SendPort;

    // 關閉一次性 port
    handshakePort.close();

    AppLogger.debug('IsolatePool', 'Worker-$workerId 已啟動');

    return _IsolateWorker(id: workerId, isolate: isolate, sendPort: sendPort);
  }

  /// 執行任務
  ///
  /// 使用 Round-Robin 策略分配任務給空閒的 Worker
  Future<R> execute(T data) async {
    if (!_initialized) {
      throw StateError(
        'Isolate pool not initialized. Call initialize() first.',
      );
    }

    // 找到空閒的 Worker
    final workerIndex = await _getAvailableWorker();
    final worker = _workers[workerIndex]!;

    // 標記為忙碌
    _workerBusy[workerIndex] = true;

    try {
      // 建立回應接收器
      final responsePort = ReceivePort();

      // 發送任務
      worker.sendPort.send({
        'data': data,
        'responsePort': responsePort.sendPort,
      });

      // 等待結果
      final result = await responsePort.first as R;
      responsePort.close();

      return result;
    } finally {
      // 標記為空閒
      _workerBusy[workerIndex] = false;
    }
  }

  /// 取得可用的 Worker 索引
  ///
  /// 使用 Round-Robin + 等待策略（最多等待 30 秒）
  Future<int> _getAvailableWorker({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // 先嘗試找空閒的 Worker
    for (var i = 0; i < workerCount; i++) {
      final index = (_nextWorkerIndex + i) % workerCount;
      if (!_workerBusy[index]) {
        _nextWorkerIndex = (index + 1) % workerCount;
        return index;
      }
    }

    // 所有 Worker 都忙碌，等待第一個完成
    AppLogger.debug('IsolatePool', '所有 Worker 忙碌，等待...');

    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 10));

      for (var i = 0; i < workerCount; i++) {
        if (!_workerBusy[i]) {
          _nextWorkerIndex = (i + 1) % workerCount;
          return i;
        }
      }
    }

    // Timeout - 拋出異常
    throw TimeoutException(
      'No worker available after ${timeout.inSeconds}s',
      timeout,
    );
  }

  /// 取得池狀態
  IsolatePoolStats get stats => IsolatePoolStats(
    workerCount: workerCount,
    busyWorkers: _workerBusy.where((busy) => busy).length,
    idleWorkers: _workerBusy.where((busy) => !busy).length,
  );

  /// 關閉 Isolate 池
  Future<void> dispose() async {
    if (!_initialized) return;

    AppLogger.info('IsolatePool', '關閉 Isolate 池');

    for (var i = 0; i < workerCount; i++) {
      final worker = _workers[i];
      if (worker != null) {
        worker.isolate.kill(priority: Isolate.immediate);
        AppLogger.debug('IsolatePool', 'Worker-${worker.id} 已關閉');
      }
    }

    _initialized = false;
    AppLogger.info('IsolatePool', 'Isolate 池已關閉');
  }
}

/// Isolate Worker
class _IsolateWorker {
  const _IsolateWorker({
    required this.id,
    required this.isolate,
    required this.sendPort,
  });

  final int id;
  final Isolate isolate;
  final SendPort sendPort;
}

/// Isolate 池統計資訊
class IsolatePoolStats {
  const IsolatePoolStats({
    required this.workerCount,
    required this.busyWorkers,
    required this.idleWorkers,
  });

  final int workerCount;
  final int busyWorkers;
  final int idleWorkers;

  double get utilizationRate =>
      workerCount > 0 ? busyWorkers / workerCount : 0.0;

  @override
  String toString() {
    return 'IsolatePoolStats('
        'total: $workerCount, '
        'busy: $busyWorkers, '
        'idle: $idleWorkers, '
        'utilization: ${(utilizationRate * 100).toStringAsFixed(1)}%'
        ')';
  }
}
