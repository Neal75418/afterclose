import 'package:afterclose/core/utils/tw_parse_utils.dart';

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
  /// 回傳本地午夜時間（委派 TwParseUtils.parseCompactRocDate）
  static DateTime parseRocDate(String rocDate) {
    // 委派 canonical parser（含月日越界驗證——舊實作對 2/30 這類日期會被
    // DateTime 靜默正規化成 3/2，是髒資料入口）；解析失敗維持 throw 語意。
    final parsed = TwParseUtils.parseCompactRocDate(rocDate);
    if (parsed == null || rocDate.length != 7) {
      throw FormatException('Invalid ROC date format: $rocDate');
    }
    return parsed;
  }
}
