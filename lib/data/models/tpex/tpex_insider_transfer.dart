import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/tw_parse_utils.dart';

/// TPEX 內部人轉讓持股資料（來源：櫃買中心 ap12_O API）
///
/// 解析櫃買中心「內部人持股轉讓申報」資料，包含董事、經理人、大股東
/// 的轉讓股數、轉讓方式及有效轉讓期間。
class TpexInsiderTransfer {
  const TpexInsiderTransfer({
    required this.symbol,
    required this.companyName,
    required this.reportDate,
    required this.identity,
    required this.name,
    required this.transferMethod,
    required this.transferShares,
    required this.currentHolding,
    this.validPeriodStart,
    this.validPeriodEnd,
  });

  factory TpexInsiderTransfer.fromJson(Map<String, dynamic> json) {
    final symbol = json['SecuritiesCompanyCode']?.toString().trim() ?? '';

    if (symbol.isEmpty || symbol.length < 4 || symbol.length > 6) {
      throw FormatException('無效的公司代號: "$symbol"', json);
    }

    final reportDateStr = json['Date']?.toString().trim() ?? '';
    final reportDate = TwParseUtils.parseCompactRocDate(reportDateStr);
    if (reportDate == null) {
      throw FormatException('無效的申報日期: "$reportDateStr"', json);
    }

    // 轉讓股數/持股數可能為空（尚未確定的申報），預設 0
    final transferSharesStr = json['轉讓股數']?.toString().trim() ?? '';
    final transferShares =
        int.tryParse(transferSharesStr.replaceAll(',', '')) ?? 0;

    final currentHoldingStr = json['目前持有股數']?.toString().trim() ?? '';
    final currentHolding =
        int.tryParse(currentHoldingStr.replaceAll(',', '')) ?? 0;

    final validPeriodStr = json['有效轉讓期間']?.toString().trim() ?? '';
    final (validPeriodStart, validPeriodEnd) = _parseValidPeriod(
      validPeriodStr,
    );

    return TpexInsiderTransfer(
      symbol: symbol,
      companyName: json['CompanyName']?.toString() ?? '',
      reportDate: reportDate,
      identity: json['申請人身分']?.toString() ?? '',
      name: json['姓名']?.toString() ?? '',
      transferMethod: json['轉讓方式']?.toString() ?? '',
      transferShares: transferShares,
      currentHolding: currentHolding,
      validPeriodStart: validPeriodStart,
      validPeriodEnd: validPeriodEnd,
    );
  }

  static TpexInsiderTransfer? tryFromJson(Map<String, dynamic> json) {
    try {
      return TpexInsiderTransfer.fromJson(json);
    } catch (e) {
      AppLogger.debug(
        'TPEX',
        '解析 TpexInsiderTransfer 失敗: ${json['SecuritiesCompanyCode']} ($e)',
      );
      return null;
    }
  }

  final String symbol; // 公司代號
  final String companyName; // 公司名稱
  final DateTime reportDate; // 申報日期
  final String identity; // 申請人身分 (董事、經理人、大股東)
  final String name; // 姓名
  final String transferMethod; // 轉讓方式
  final int transferShares; // 轉讓股數
  final int currentHolding; // 目前持有股數
  final DateTime? validPeriodStart; // 有效轉讓期間 - 起始日
  final DateTime? validPeriodEnd; // 有效轉讓期間 - 結束日

  /// 解析有效轉讓期間（格式: "1150317~1150416"）
  static (DateTime?, DateTime?) _parseValidPeriod(String period) {
    if (period.isEmpty || !period.contains('~')) {
      return (null, null);
    }

    final parts = period.split('~');
    if (parts.length != 2) {
      return (null, null);
    }

    final start = TwParseUtils.parseCompactRocDate(parts[0].trim());
    final end = TwParseUtils.parseCompactRocDate(parts[1].trim());

    return (start, end);
  }
}
