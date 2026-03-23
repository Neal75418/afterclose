/// TPEX 注意/處置股票資料
class TpexTradingWarning {
  const TpexTradingWarning({
    required this.date,
    required this.code,
    required this.warningType,
    this.reasonCode,
    this.reasonDescription,
    this.disposalMeasures,
    this.disposalStartDate,
    this.disposalEndDate,
  });

  final DateTime date;
  final String code;
  final String warningType; // 'ATTENTION' | 'DISPOSAL'
  final String? reasonCode; // 列入原因代碼
  final String? reasonDescription; // 原因說明
  final String? disposalMeasures; // 處置措施（僅處置股）
  final DateTime? disposalStartDate; // 處置起始日
  final DateTime? disposalEndDate; // 處置結束日
}
