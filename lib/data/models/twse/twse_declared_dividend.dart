import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/tw_parse_utils.dart';

/// TWSE 已宣告股利資料（來源：證交所 ap45_L API）
///
/// 解析證交所「已公告配股配息」資料，包含現金股利、股票股利、
/// 除息交易日、除權交易日與股東會日期。
class TwseDeclaredDividend {
  const TwseDeclaredDividend({
    required this.symbol,
    required this.companyName,
    required this.dividendYear,
    required this.cashDividend,
    required this.stockDividend,
    this.exDividendDate,
    this.exRightsDate,
    this.shareholderMeetingDate,
  });

  factory TwseDeclaredDividend.fromJson(Map<String, dynamic> json) {
    final symbol = json['公司代號']?.toString().trim() ?? '';

    if (symbol.isEmpty || symbol.length < 4 || symbol.length > 6) {
      throw FormatException('無效的公司代號: "$symbol"', json);
    }

    final rocYearStr = json['股利年度']?.toString().trim() ?? '';
    final rocYear = int.tryParse(rocYearStr);
    if (rocYear == null) {
      throw FormatException('無效的股利年度: "$rocYearStr"', json);
    }

    return TwseDeclaredDividend(
      symbol: symbol,
      companyName: json['公司名稱']?.toString() ?? '',
      dividendYear: rocYear + 1911,
      cashDividend: _parseDouble(json['現金股利(元/股)']) ?? 0.0,
      stockDividend: _parseDouble(json['股票股利(元/股)']) ?? 0.0,
      exDividendDate: TwParseUtils.parseCompactRocDate(
        json['除息交易日']?.toString().trim(),
      ),
      exRightsDate: TwParseUtils.parseCompactRocDate(
        json['除權交易日']?.toString().trim(),
      ),
      shareholderMeetingDate: TwParseUtils.parseCompactRocDate(
        json['股東會日期']?.toString().trim(),
      ),
    );
  }

  static TwseDeclaredDividend? tryFromJson(Map<String, dynamic> json) {
    try {
      return TwseDeclaredDividend.fromJson(json);
    } catch (e) {
      AppLogger.debug('TWSE', '解析 TwseDeclaredDividend 失敗: ${json['公司代號']}');
      return null;
    }
  }

  final String symbol; // 公司代號
  final String companyName; // 公司名稱
  final int dividendYear; // 股利年度（西元）
  final double cashDividend; // 現金股利（元/股）
  final double stockDividend; // 股票股利（元/股）
  final DateTime? exDividendDate; // 除息交易日
  final DateTime? exRightsDate; // 除權交易日
  final DateTime? shareholderMeetingDate; // 股東會日期

  /// 總股利（現金 + 股票）
  double get totalDividend => cashDividend + stockDividend;

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '').trim();
      if (cleaned.isEmpty || cleaned == '--') return null;
      return double.tryParse(cleaned);
    }
    return null;
  }
}
