import 'package:afterclose/core/utils/tw_parse_utils.dart';
import 'package:afterclose/data/models/tpex/insider_aggregation.dart';

/// 董監持股比例的共用中間結果（各 client 自行 map 回自家 model）
typedef InsiderHoldingRatios = ({
  DateTime date,
  String code,
  double insiderRatio,
  double pledgeRatio,
  double sharesIssued,
});

/// TWSE / TPEx 董監持股彙總共用邏輯
///
/// 兩市場的上游是同一份政府 OpenData schema（t187ap11 系列），
/// 「誰算董監」「怎麼算比例」是業務規則——過去兩個 client 各持一份
/// 逐字複製，改一邊忘另一邊會造成上市/上櫃董監持股口徑靜默分歧
/// （這是質押警示的資料源頭）。集中一處，差異只留 code filter。
abstract final class InsiderHoldingAggregator {
  /// 從 stock info payload 解析 code → 已發行股數
  ///
  /// 兩市場欄位名不同（TWSE 中文 / TPEx 英文），由 caller 指定 key。
  static Map<String, double> parseIssuedShares(
    dynamic data, {
    required String codeKey,
    required String sharesKey,
  }) {
    final issuedSharesMap = <String, double>{};
    if (data is! List) return issuedSharesMap;
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final code = item[codeKey]?.toString().trim() ?? '';
      final shares = item[sharesKey]?.toString().replaceAll(',', '');
      if (code.isNotEmpty && shares != null) {
        final sharesNum = double.tryParse(shares);
        if (sharesNum != null && sharesNum > 0) {
          issuedSharesMap[code] = sharesNum;
        }
      }
    }
    return issuedSharesMap;
  }

  /// 彙總個別董監持股記錄為 per-company 統計
  ///
  /// 業務規則（兩市場共用）：
  /// - 只計「董事/監察人」且職稱以「本人」結尾的記錄——排除
  ///   「法人代表人」（法人持股已在法人本人記錄中，重複計算會灌水）、
  ///   總經理/副總/財務會計主管等非董監職稱
  /// - 以姓名去重（同一人可能有多個職稱但持股相同）
  static Map<String, InsiderAggregation> aggregateRecords(
    List<dynamic> data, {
    required bool Function(String code) codeFilter,
  }) {
    final companyData = <String, InsiderAggregation>{};

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;

      final code = item['公司代號']?.toString().trim() ?? '';
      if (code.isEmpty || !codeFilter(code)) continue;

      final companyName = item['公司名稱']?.toString().trim() ?? '';
      final position = item['職稱']?.toString() ?? '';
      final personName = item['姓名']?.toString().trim() ?? '';

      final isDirectorOrSupervisor =
          (position.contains('董事') || position.contains('監察人')) &&
          position.endsWith('本人');
      if (!isDirectorOrSupervisor) continue;

      final dateStr = item['出表日期']?.toString();
      final date = TwParseUtils.parseCompactRocDate(dateStr);
      if (date == null) continue;

      final shares = TwParseUtils.parseFormattedDouble(item['目前持股']) ?? 0;
      final pledged = TwParseUtils.parseFormattedDouble(item['設質股數']) ?? 0;

      companyData.putIfAbsent(
        code,
        () => InsiderAggregation(code: code, name: companyName, date: date),
      );
      companyData[code]!.addHoldingIfNew(personName, shares, pledged);
    }

    return companyData;
  }

  /// 計算董監持股比例與質押比例
  static List<InsiderHoldingRatios> buildRatios(
    Map<String, InsiderAggregation> companyData,
    Map<String, double> issuedSharesMap,
  ) {
    final results = <InsiderHoldingRatios>[];
    for (final agg in companyData.values) {
      final issuedShares = issuedSharesMap[agg.code];
      if (issuedShares == null || issuedShares <= 0) continue;

      final insiderRatio = (agg.totalShares / issuedShares) * 100;
      final pledgeRatio = agg.totalShares > 0
          ? (agg.totalPledged / agg.totalShares) * 100
          : 0.0;

      results.add((
        date: agg.date,
        code: agg.code,
        insiderRatio: insiderRatio,
        pledgeRatio: pledgeRatio,
        sharesIssued: issuedShares,
      ));
    }
    return results;
  }
}
