/// TPEX 當沖交易資料
class TpexDayTrading {
  const TpexDayTrading({
    required this.date,
    required this.code,
    required this.name,
    required this.buyVolume,
    required this.sellVolume,
    required this.totalVolume,
  });

  final DateTime date;
  final String code;
  final String name;
  final double buyVolume; // 當沖買進成交股數
  final double sellVolume; // 當沖賣出成交股數
  final double totalVolume; // 當沖成交股數
}
