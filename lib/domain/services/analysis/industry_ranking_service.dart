import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/price_calculator.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/industry_ranking.dart';

/// 族群排行服務（使用者選股法則 L1 的自動化）
///
/// 由個股 20D 報酬聚合各產業動能（成員**中位數**，抗離群、與
/// `computeIndustryMomentum` 同口徑），加上外資+投信近
/// [SectorParams.rankingInstitutionalDays] 交易日合計淨買賣，輸出動能 DESC
/// 排行。純顯示/發現層、不進評分——sector tilt 因全期 IC≈0 dormant
/// （[SectorParams.tiltWeight] doc），那是評分因子的結論，不影響資訊呈現。
class IndustryRankingService {
  /// [industries] 為 null／空字串或含「ETF」字樣（`ETF`＋`上櫃ETF` 兩種標記
  /// 並存）的股票不進排行；歷史不足 21 筆的成員不計入。成員數少於
  /// [SectorParams.rankingMinMembers] 的產業整組略過。
  List<IndustryRanking> rank({
    required Map<String, List<DailyPriceEntry>> priceHistories,
    required Map<String, String?> industries,
    required Map<String, String> names,
    required Map<String, List<DailyInstitutionalEntry>> institutionalHistories,
  }) {
    // 產業 → 成員 (symbol, ret20)
    final membersByIndustry = <String, List<IndustryMember>>{};
    for (final entry in priceHistories.entries) {
      final industry = industries[entry.key];
      if (industry == null || industry.isEmpty) continue;
      if (industry.contains('ETF')) continue;
      final ret = PriceCalculator.ret20d(entry.value);
      if (ret == null) continue;
      membersByIndustry
          .putIfAbsent(industry, () => [])
          .add(
            IndustryMember(
              symbol: entry.key,
              name: names[entry.key] ?? '',
              ret20Pct: ret,
            ),
          );
    }

    // symbol → 外資+投信近 N 交易日合計
    final netBySymbol = <String, double>{};
    for (final entry in institutionalHistories.entries) {
      final sorted = List<DailyInstitutionalEntry>.from(entry.value)
        ..sort((a, b) => b.date.compareTo(a.date));
      var sum = 0.0;
      for (final e in sorted.take(SectorParams.rankingInstitutionalDays)) {
        sum += (e.foreignNet ?? 0) + (e.investmentTrustNet ?? 0);
      }
      netBySymbol[entry.key] = sum;
    }

    final rankings = <IndustryRanking>[];
    for (final entry in membersByIndustry.entries) {
      final members = entry.value;
      if (members.length < SectorParams.rankingMinMembers) continue;

      final rets = members.map((m) => m.ret20Pct).toList()..sort();
      final mid = rets.length ~/ 2;
      final median = rets.length.isOdd
          ? rets[mid]
          : (rets[mid - 1] + rets[mid]) / 2;

      var net = 0.0;
      for (final m in members) {
        net += netBySymbol[m.symbol] ?? 0;
      }

      members.sort((a, b) {
        final byRet = b.ret20Pct.compareTo(a.ret20Pct);
        if (byRet != 0) return byRet;
        return a.symbol.compareTo(b.symbol);
      });

      rankings.add(
        IndustryRanking(
          industry: entry.key,
          momentumPct: median,
          memberCount: members.length,
          institutionalNetShares: net,
          topMembers: members
              .take(SectorParams.rankingTopMembersCount)
              .toList(),
        ),
      );
    }

    rankings.sort((a, b) {
      final byMomentum = b.momentumPct.compareTo(a.momentumPct);
      if (byMomentum != 0) return byMomentum;
      return a.industry.compareTo(b.industry);
    });
    return rankings.take(SectorParams.rankingTopN).toList();
  }
}
