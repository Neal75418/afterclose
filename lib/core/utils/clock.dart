/// 時間抽象層，用於測試中注入假時間
abstract class AppClock {
  /// 取得當前時間
  DateTime now();
}

/// 預設時鐘，使用系統時間
class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
