import 'package:afterclose/core/constants/api_config.dart';

/// TWSE 每日價格資料
class TwseDailyPrice {
  const TwseDailyPrice({
    required this.date,
    required this.code,
    required this.name,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.change,
  });

  final DateTime date;
  final String code;
  final String name;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
  final double? change;

  /// 將 TWSE 民國日期（例如 "1150119"）轉換為 DateTime
  ///
  /// 回傳 UTC 午夜時間以確保跨時區一致性
  static DateTime parseRocDate(String rocDate) {
    if (rocDate.length != 7) {
      throw FormatException('Invalid ROC date format: $rocDate');
    }

    final rocYear = int.parse(rocDate.substring(0, 3));
    final month = int.parse(rocDate.substring(3, 5));
    final day = int.parse(rocDate.substring(5, 7));

    // 民國年 + ApiConfig.rocYearOffset = 西元年
    final adYear = rocYear + ApiConfig.rocYearOffset;

    return DateTime(adYear, month, day);
  }
}
