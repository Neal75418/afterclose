import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/utils/tw_parse_utils.dart';

/// TPEX 已宣告股利資料（來源：櫃買中心 ap39_O API）
///
/// 解析櫃買中心「已公告配股配息」資料，包含現金股利、股票股利、
/// 除息交易日與除權交易日。
class TpexDeclaredDividend {
  const TpexDeclaredDividend({
    required this.symbol,
    required this.companyName,
    required this.dividendYear,
    required this.cashDividend,
    required this.stockDividend,
    this.exDividendDate,
    this.exRightsDate,
  });

  factory TpexDeclaredDividend.fromJson(Map<String, dynamic> json) {
    final symbol = json['公司代號']?.toString().trim() ?? '';

    if (symbol.isEmpty || symbol.length < 4 || symbol.length > 6) {
      throw FormatException('無效的公司代號: "$symbol"', json);
    }

    final rocYearStr = json['股利年度']?.toString().trim() ?? '';
    final rocYear = int.tryParse(rocYearStr);
    if (rocYear == null) {
      throw FormatException('無效的股利年度: "$rocYearStr"', json);
    }

    return TpexDeclaredDividend(
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
    );
  }

  static TpexDeclaredDividend? tryFromJson(Map<String, dynamic> json) {
    try {
      return TpexDeclaredDividend.fromJson(json);
    } catch (e) {
      AppLogger.debug('TPEX', '解析 TpexDeclaredDividend 失敗: ${json['公司代號']}');
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
