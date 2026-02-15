import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 台灣時區工具
///
/// 確保交易日計算使用 Asia/Taipei (UTC+8) 時區，
/// 避免使用者設備在不同時區時導致交易日判斷錯誤。
///
/// 時區資料庫會在首次使用時自動初始化。
class TaiwanTime {
  TaiwanTime._();

  /// Asia/Taipei 時區（首次存取時自動初始化）
  static final tz.Location _location = _initLocation();

  static tz.Location _initLocation() {
    tz_data.initializeTimeZones();
    return tz.getLocation('Asia/Taipei');
  }

  /// 取得目前台灣時間
  ///
  /// 回傳一般 DateTime（非 TZDateTime），避免 TZDateTime 在
  /// Drift 等框架中傳播造成非預期行為。
  static DateTime now() {
    final tzNow = tz.TZDateTime.now(_location);
    return DateTime(
      tzNow.year,
      tzNow.month,
      tzNow.day,
      tzNow.hour,
      tzNow.minute,
      tzNow.second,
    );
  }

  /// 取得今日台灣日期（午夜）
  static DateTime today() {
    final tzNow = tz.TZDateTime.now(_location);
    return DateTime(tzNow.year, tzNow.month, tzNow.day);
  }
}
