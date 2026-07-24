/// TWSE 停資停券預告（openapi BFI84U）單筆資料
///
/// 欄位鍵名為英文 Code/Name/StartDate/EndDate/Reason（2026-07-24 對
/// live 端點 curl 實證；openapi 各資料集鍵名不一、不可類推）。
/// 日期欄位為民國年字串（如 `1150730`），以 [rocDateToDateTime] 轉西元。
class TwseShortSuspension {
  const TwseShortSuspension({
    required this.code,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  factory TwseShortSuspension.fromJson(Map<String, dynamic> json) {
    return TwseShortSuspension(
      code: json['Code']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      startDate: json['StartDate']?.toString() ?? '',
      endDate: json['EndDate']?.toString() ?? '',
      reason: json['Reason']?.toString() ?? '',
    );
  }

  final String code;
  final String name;

  /// 停券起日（民國年 yyyMMdd）
  final String startDate;

  /// 停券迄日（民國年 yyyMMdd）
  final String endDate;

  /// 停券原因（股東會／除息／分配收益…）
  final String reason;
}

/// 民國年 `yyyMMdd` 字串 → 西元 [DateTime]；格式不符回 null。
DateTime? rocDateToDateTime(String roc) {
  if (roc.length < 6 || roc.length > 7) return null;
  final year = int.tryParse(roc.substring(0, roc.length - 4));
  final month = int.tryParse(roc.substring(roc.length - 4, roc.length - 2));
  final day = int.tryParse(roc.substring(roc.length - 2));
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final dt = DateTime(year + 1911, month, day);
  // Dart DateTime 對不存在的日期（2/30）會溢位進位而非丟例外，反驗防呆
  if (dt.month != month || dt.day != day) return null;
  return dt;
}
