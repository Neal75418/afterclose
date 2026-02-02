/// TWSE 注意/處置股票資料
class TwseTradingWarning {
  const TwseTradingWarning({
    required this.date,
    required this.code,
    required this.name,
    required this.warningType,
    this.reasonCode,
    this.reasonDescription,
    this.disposalMeasures,
    this.disposalStartDate,
    this.disposalEndDate,
  });

  final DateTime date;
  final String code;
  final String name;
  final String warningType; // 'ATTENTION' | 'DISPOSAL'
  final String? reasonCode; // 列入原因代碼
  final String? reasonDescription; // 原因說明
  final String? disposalMeasures; // 處置措施（僅處置股）
  final DateTime? disposalStartDate; // 處置起始日
  final DateTime? disposalEndDate; // 處置結束日

  /// 是否為處置股
  bool get isDisposal => warningType == 'DISPOSAL';

  /// 處置是否目前生效
  bool get isActive {
    if (!isDisposal) return true; // 注意股票始終視為生效
    if (disposalEndDate == null) return true;
    return DateTime.now().isBefore(
      disposalEndDate!.add(const Duration(days: 1)),
    );
  }
}
