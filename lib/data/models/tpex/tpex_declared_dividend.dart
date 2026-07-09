import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/constants/api_config.dart';
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
      dividendYear: rocYear + ApiConfig.rocYearOffset,
      // ⚠️ 同 TWSE：現金/股票股利為「多組成欄加總」，舊 code 讀 ap39_O 不存在的
      // '現金股利(元/股)'/'股票股利(元/股)' → 全 0（bug）。key 已對 live API 核實。
      // （TPEx 把法定盈餘公積、資本公積合併成一欄，故各加總 2 欄。）
      cashDividend: _sumDoubles(json, const [
        '股東配發內容-盈餘分配之現金股利(元/股)',
        '股東配發內容-法定盈餘公積、資本公積發放之現金(元/股)',
      ]),
      stockDividend: _sumDoubles(json, const [
        '股東配發內容-盈餘轉增資配股(元/股)',
        '股東配發內容-法定盈餘公積、資本公積轉增資配股(元/股)',
      ]),
      // ap39_O 不提供除權息「交易日」；舊 code 讀不存在的 key → 永遠 null。
      exDividendDate: null,
      exRightsDate: null,
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

  /// 加總多個 key 的數值（缺失/null 視為 0）。用於現金/股票股利的多組成欄。
  static double _sumDoubles(Map<String, dynamic> json, List<String> keys) {
    var sum = 0.0;
    for (final key in keys) {
      sum += TwParseUtils.parseFormattedDouble(json[key]) ?? 0.0;
    }
    return sum;
  }
}
