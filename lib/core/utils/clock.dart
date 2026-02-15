import 'package:afterclose/core/utils/taiwan_time.dart';

/// 時間抽象層，用於測試中注入假時間
abstract class AppClock {
  /// 取得當前時間
  DateTime now();
}

/// 預設時鐘，使用台灣時區 (Asia/Taipei, UTC+8)
///
/// 確保所有交易日計算一律使用台灣時間，
/// 避免使用者設備在其他時區時判斷錯誤。
class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime now() => TaiwanTime.now();
}
