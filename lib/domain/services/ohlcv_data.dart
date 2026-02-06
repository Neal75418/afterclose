import 'package:afterclose/data/database/app_database.dart';

/// OHLCV 資料記錄
typedef OhlcvData = ({
  List<double> closes,
  List<double> highs,
  List<double> lows,
  List<double> volumes,
});

/// 從 [DailyPriceEntry] 列表提取有效 OHLCV 資料
extension PriceEntryOhlcv on List<DailyPriceEntry> {
  /// 過濾掉 close/high/low 為 null 的項目，回傳數值列表。
  /// volume 為 null 時預設為 0。
  OhlcvData extractOhlcv() {
    final closes = <double>[];
    final highs = <double>[];
    final lows = <double>[];
    final volumes = <double>[];

    for (final p in this) {
      if (p.close != null && p.high != null && p.low != null) {
        closes.add(p.close!);
        highs.add(p.high!);
        lows.add(p.low!);
        volumes.add(p.volume ?? 0);
      }
    }

    return (closes: closes, highs: highs, lows: lows, volumes: volumes);
  }
}
