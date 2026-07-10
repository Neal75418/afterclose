import 'package:afterclose/core/constants/reason_type.dart';

/// 基本面訊號的相關性分組與遞減計分
///
/// **2026-07-10 影響分析後採用**：訊號區 21% 的股票存在同組基本面訊號
/// 疊加（同一資訊重複計分）——例：南亞科同日 EPS 連增 +22、營收 YoY
/// +20、ROE 優異 +18、ROE 改善 +15，「基本面好」一件事計 75 分。
///
/// 線性加總隱含「訊號互相獨立」假設，但同族基本面訊號高度相關。
/// 遞減制編碼「同族的第 N 個證據仍有價值、但邊際遞減」：組內按
/// 設計分數排序，第 1 名全分、第 2 名 50%、第 3 名起 25%。
/// 只作用於**正分**訊號（負分警訊不分組、照常全額抵消）。
///
/// 分組原則：價值（估值便宜）/ 營收（top-line 動能）/ 獲利（bottom-line
/// 品質）——三者相關但非同一資訊，跨組不遞減。
abstract final class FundamentalDecayGroups {
  /// 價值組：估值便宜的三個角度
  static const Set<ReasonType> value = {
    ReasonType.highDividendYield,
    ReasonType.pbrUndervalued,
    ReasonType.peUndervalued,
  };

  /// 營收組：top-line 動能
  static const Set<ReasonType> revenue = {
    ReasonType.revenueYoySurge,
    ReasonType.revenueMomGrowth,
    ReasonType.revenueNewHigh,
  };

  /// 獲利組：bottom-line 品質與效率
  static const Set<ReasonType> earnings = {
    ReasonType.epsYoYSurge,
    ReasonType.epsConsecutiveGrowth,
    ReasonType.epsTurnaround,
    ReasonType.roeExcellent,
    ReasonType.roeImproving,
  };

  static const List<Set<ReasonType>> all = [value, revenue, earnings];

  /// 組內第 N 名的分數係數（超出長度者用最後一個值）
  static const List<double> decayFactors = [1.0, 0.5, 0.25];

  /// 取組內名次對應係數
  static double factorForRank(int rank) =>
      decayFactors[rank < decayFactors.length ? rank : decayFactors.length - 1];
}
