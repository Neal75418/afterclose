// IndustryRankingService — 族群排行（使用者選股法則 L1 的自動化）
//
// L1「族群決定 80%」：輪動前段＋法人買超。本服務由個股 20D 報酬聚合各
// 產業動能（中位數，與 computeIndustryMomentum 同口徑）、加上外資+投信
// 近 3 交易日合計淨買賣，輸出排行供今日頁族群 section 顯示。
// 純顯示/發現層，不進評分（sector tilt 已因全期 IC≈0 dormant，見
// SectorParams.tiltWeight doc——那是評分因子的結論，不影響資訊呈現）。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/analysis/industry_ranking_service.dart';

import '../../../helpers/price_data_generators.dart';

void main() {
  final service = IndustryRankingService();

  /// [ret20Pct]% 的 21 筆日線（首筆 100、尾筆 100*(1+ret/100)，中間持平首值）
  List<DailyPriceEntry> historyWithRet20(String symbol, double ret20Pct) {
    final start = DateTime(2026, 6, 1);
    return List.generate(21, (i) {
      final isLast = i == 20;
      return createTestPrice(
        symbol: symbol,
        date: start.add(Duration(days: i)),
        close: isLast ? 100 * (1 + ret20Pct / 100) : 100.0,
      );
    });
  }

  DailyInstitutionalEntry inst(
    String symbol,
    DateTime date, {
    double? foreign,
    double? trust,
  }) {
    return DailyInstitutionalEntry(
      symbol: symbol,
      date: date,
      foreignNet: foreign,
      investmentTrustNet: trust,
    );
  }

  group('IndustryRankingService.rank', () {
    test('依產業動能中位數 DESC 排序；成員 20D 報酬與名稱正確', () {
      final rankings = service.rank(
        priceHistories: {
          'A1': historyWithRet20('A1', 10),
          'A2': historyWithRet20('A2', 20),
          'A3': historyWithRet20('A3', 30),
          'B1': historyWithRet20('B1', 1),
          'B2': historyWithRet20('B2', 2),
          'B3': historyWithRet20('B3', 3),
        },
        industries: {
          'A1': '半導體業',
          'A2': '半導體業',
          'A3': '半導體業',
          'B1': '紡織業',
          'B2': '紡織業',
          'B3': '紡織業',
        },
        names: {
          'A1': '甲一',
          'A2': '甲二',
          'A3': '甲三',
          'B1': '乙一',
          'B2': '乙二',
          'B3': '乙三',
        },
        institutionalHistories: const {},
      );

      expect(rankings, hasLength(2));
      expect(rankings[0].industry, '半導體業');
      expect(rankings[0].momentumPct, closeTo(20.0, 1e-6)); // 中位數
      expect(rankings[0].memberCount, 3);
      expect(rankings[1].industry, '紡織業');
      expect(rankings[1].momentumPct, closeTo(2.0, 1e-6));
      // topMembers 依 20D 報酬 DESC
      expect(rankings[0].topMembers.map((m) => m.symbol).toList(), [
        'A3',
        'A2',
        'A1',
      ]);
      expect(rankings[0].topMembers.first.name, '甲三');
      expect(rankings[0].topMembers.first.ret20Pct, closeTo(30.0, 1e-6));
    });

    test('ETF 產業（含「ETF」字樣）與無產業股票不進排行', () {
      final rankings = service.rank(
        priceHistories: {
          'E1': historyWithRet20('E1', 50),
          'E2': historyWithRet20('E2', 50),
          'E3': historyWithRet20('E3', 50),
          'F1': historyWithRet20('F1', 50),
          'N1': historyWithRet20('N1', 50),
        },
        industries: {
          'E1': 'ETF',
          'E2': 'ETF',
          'E3': 'ETF',
          'F1': '上櫃ETF',
          'N1': null,
        },
        names: const {},
        institutionalHistories: const {},
      );

      expect(rankings, isEmpty);
    });

    test('成員不足 rankingMinMembers 的產業不進排行', () {
      final rankings = service.rank(
        priceHistories: {
          'A1': historyWithRet20('A1', 10),
          'A2': historyWithRet20('A2', 20),
        },
        industries: {'A1': '半導體業', 'A2': '半導體業'},
        names: const {},
        institutionalHistories: const {},
      );

      expect(SectorParams.rankingMinMembers, greaterThan(2));
      expect(rankings, isEmpty);
    });

    test('歷史不足 21 筆的成員不計入動能與成員數', () {
      final short = historyWithRet20('A3', 99).sublist(0, 10);
      final rankings = service.rank(
        priceHistories: {
          'A1': historyWithRet20('A1', 10),
          'A2': historyWithRet20('A2', 20),
          'A3': short,
          'A4': historyWithRet20('A4', 30),
        },
        industries: {'A1': '半導體業', 'A2': '半導體業', 'A3': '半導體業', 'A4': '半導體業'},
        names: const {},
        institutionalHistories: const {},
      );

      expect(rankings, hasLength(1));
      expect(rankings[0].memberCount, 3);
      expect(rankings[0].momentumPct, closeTo(20.0, 1e-6));
    });

    test('法人合計 = 外資+投信、只取近 rankingInstitutionalDays 個交易日', () {
      final d = DateTime(2026, 7, 20);
      final rankings = service.rank(
        priceHistories: {
          'A1': historyWithRet20('A1', 10),
          'A2': historyWithRet20('A2', 20),
          'A3': historyWithRet20('A3', 30),
        },
        industries: {'A1': '半導體業', 'A2': '半導體業', 'A3': '半導體業'},
        names: const {},
        institutionalHistories: {
          'A1': [
            // 第 4 個交易日（最舊）不得計入
            inst('A1', d.subtract(const Duration(days: 3)), foreign: 999999),
            inst('A1', d.subtract(const Duration(days: 2)), foreign: 1000),
            inst(
              'A1',
              d.subtract(const Duration(days: 1)),
              foreign: 2000,
              trust: 500,
            ),
            inst('A1', d, foreign: 3000),
          ],
          'A2': [
            inst('A2', d, foreign: null, trust: null), // null 視為 0
          ],
        },
      );

      expect(SectorParams.rankingInstitutionalDays, 3);
      expect(rankings.single.institutionalNetShares, closeTo(6500.0, 1e-6));
    });

    test('產業數超過 rankingTopN → 只取前 N', () {
      final priceHistories = <String, List<DailyPriceEntry>>{};
      final industries = <String, String?>{};
      for (var g = 0; g < SectorParams.rankingTopN + 2; g++) {
        for (var m = 0; m < SectorParams.rankingMinMembers; m++) {
          final symbol = 'G${g}M$m';
          priceHistories[symbol] = historyWithRet20(symbol, g.toDouble());
          industries[symbol] = '產業$g';
        }
      }
      final rankings = service.rank(
        priceHistories: priceHistories,
        industries: industries,
        names: const {},
        institutionalHistories: const {},
      );

      expect(rankings, hasLength(SectorParams.rankingTopN));
      expect(rankings.first.industry, '產業${SectorParams.rankingTopN + 1}');
    });

    test('topMembers 上限 rankingTopMembersCount', () {
      final priceHistories = <String, List<DailyPriceEntry>>{};
      final industries = <String, String?>{};
      for (var m = 0; m < SectorParams.rankingTopMembersCount + 3; m++) {
        final symbol = 'M$m';
        priceHistories[symbol] = historyWithRet20(symbol, m.toDouble());
        industries[symbol] = '半導體業';
      }
      final rankings = service.rank(
        priceHistories: priceHistories,
        industries: industries,
        names: const {},
        institutionalHistories: const {},
      );

      expect(
        rankings.single.topMembers,
        hasLength(SectorParams.rankingTopMembersCount),
      );
    });

    test('空輸入 → 空排行', () {
      expect(
        service.rank(
          priceHistories: const {},
          industries: const {},
          names: const {},
          institutionalHistories: const {},
        ),
        isEmpty,
      );
    });
  });
}
