/// 帶有價格與位置索引的波段點
///
/// 用於支撐壓力計算中的波段高低點識別
class SwingPoint {
  const SwingPoint({required this.price, required this.index});

  /// 波段點的價格
  final double price;

  /// 波段點在價格歷史中的索引位置
  final int index;
}
