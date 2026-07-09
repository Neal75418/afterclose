import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/core/constants/api_config.dart';
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
      dividendYear: rocYear + ApiConfig.rocYearOffset,
      // ⚠️ 現金/股票股利為「多組成欄加總」。舊 code 讀 '現金股利(元/股)'/
      // '股票股利(元/股)' 兩個在 ap45_L 不存在的 key → 全部 fallback 成 0（bug）。
      // 以下 key 已對 live API 核實。
      cashDividend: _sumDoubles(json, const [
        '股東配發-盈餘分配之現金股利(元/股)',
        '股東配發-法定盈餘公積發放之現金(元/股)',
        '股東配發-資本公積發放之現金(元/股)',
      ]),
      stockDividend: _sumDoubles(json, const [
        '股東配發-盈餘轉增資配股(元/股)',
        '股東配發-法定盈餘公積轉增資配股(元/股)',
        '股東配發-資本公積轉增資配股(元/股)',
      ]),
      // ap45_L 不提供除權息「交易日」（屬另一支 TWT49U 時程表）；舊 code 讀
      // '除息交易日'/'除權交易日' 兩個不存在的 key → 永遠 null。明確設 null。
      exDividendDate: null,
      exRightsDate: null,
      // '股東會日期' key 正確、保留（此欄原本就讀對）。
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

  /// 加總多個 key 的數值（缺失/null 視為 0）。
  /// 用於現金/股票股利的多組成欄（盈餘 + 法定盈餘公積 + 資本公積）。
  static double _sumDoubles(Map<String, dynamic> json, List<String> keys) {
    var sum = 0.0;
    for (final key in keys) {
      sum += TwParseUtils.parseFormattedDouble(json[key]) ?? 0.0;
    }
    return sum;
  }
}
