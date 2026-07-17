import 'package:afterclose/data/database/app_database.dart';

/// OHLCV 資料記錄
///
/// [gapBefore] 與 [closes]/[highs]/[lows]/[volumes] 等長對齊：
/// `gapBefore[i] == true` 表示 `closes[i]` 與 `closes[i-1]` 之間跨越了
/// 至少一列被過濾掉的無成交列（停牌/未開盤，close/high/low 皆為 null）。
/// 供 RSI/KD 等以「前一筆」為基礎的計算避免跨缺口誤判為單一交易日變動。
typedef OhlcvData = ({
  List<double> closes,
  List<double> highs,
  List<double> lows,
  List<double> volumes,
  List<bool> gapBefore,
});

/// 從 [DailyPriceEntry] 列表提取有效 OHLCV 資料
extension PriceEntryOhlcv on List<DailyPriceEntry> {
  /// 過濾掉 close/high/low 為 null 的項目，回傳數值列表。
  /// volume 為 null 時預設為 0。
  ///
  /// 同時計算 [OhlcvData.gapBefore]：TWSE/TPEx 無成交日會以
  /// close/high/low=null、volume=0.0 的列存在，此處統一以單一迴圈判斷
  /// 「哪些有效列的前一筆原始列其實是缺口」，讓所有消費端（RSI/KD 計算、
  /// 圖表）共用同一份缺口資訊，避免各自重複 filter 造成長度不一致或
  /// 誤把跨缺口的價差當成單一交易日變動。
  OhlcvData extractOhlcv() {
    final closes = <double>[];
    final highs = <double>[];
    final lows = <double>[];
    final volumes = <double>[];
    final gapBefore = <bool>[];

    for (int i = 0; i < length; i++) {
      final p = this[i];
      if (p.close == null || p.high == null || p.low == null) continue;

      final previousRowIsGap =
          i > 0 &&
          !(this[i - 1].close != null &&
              this[i - 1].high != null &&
              this[i - 1].low != null);
      gapBefore.add(closes.isNotEmpty && previousRowIsGap);

      closes.add(p.close!);
      highs.add(p.high!);
      lows.add(p.low!);
      volumes.add(p.volume ?? 0);
    }

    return (
      closes: closes,
      highs: highs,
      lows: lows,
      volumes: volumes,
      gapBefore: gapBefore,
    );
  }
}
