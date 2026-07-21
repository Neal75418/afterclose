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
import 'package:afterclose/domain/models/industry_ranking.dart';
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
          'A2': historyWithRet20('A2', 15),
          'A3': historyWithRet20('A3', 20),
          'A4': historyWithRet20('A4', 25),
          'A5': historyWithRet20('A5', 30),
          'B1': historyWithRet20('B1', 1.0),
          'B2': historyWithRet20('B2', 1.5),
          'B3': historyWithRet20('B3', 2.0),
          'B4': historyWithRet20('B4', 2.5),
          'B5': historyWithRet20('B5', 3.0),
        },
        industries: {
          'A1': '半導體業',
          'A2': '半導體業',
          'A3': '半導體業',
          'A4': '半導體業',
          'A5': '半導體業',
          'B1': '紡織業',
          'B2': '紡織業',
          'B3': '紡織業',
          'B4': '紡織業',
          'B5': '紡織業',
        },
        names: {'A5': '甲五'},
        institutionalHistories: const {},
      );

      expect(rankings, hasLength(2));
      expect(rankings[0].industry, '半導體業');
      expect(rankings[0].momentumPct, closeTo(20.0, 1e-6)); // 中位數
      expect(rankings[0].memberCount, 5);
      expect(rankings[1].industry, '紡織業');
      expect(rankings[1].momentumPct, closeTo(2.0, 1e-6));
      // topMembers 依 20D 報酬 DESC
      expect(rankings[0].topMembers.map((m) => m.symbol).toList(), [
        'A5',
        'A4',
        'A3',
        'A2',
        'A1',
      ]);
      expect(rankings[0].topMembers.first.name, '甲五');
      expect(rankings[0].topMembers.first.retPct, closeTo(30.0, 1e-6));
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

    test('成員不足 rankingMinMembers 的產業不進排行（實例：農業科技業 4 檔小樣本）', () {
      // 比門檻少 1 檔——2026-07-22 實機看到 4 檔小樣本（兩漲兩跌拼出的
      // 中位數無代表性）後，門檻從 3 調到 5
      final memberCount = SectorParams.rankingMinMembers - 1;
      final rankings = service.rank(
        priceHistories: {
          for (var m = 0; m < memberCount; m++)
            'A$m': historyWithRet20('A$m', 10.0 * m),
        },
        industries: {for (var m = 0; m < memberCount; m++) 'A$m': '農業科技業'},
        names: const {},
        institutionalHistories: const {},
      );

      expect(rankings, isEmpty);
    });

    test('歷史不足 21 筆的成員不計入動能與成員數', () {
      final short = historyWithRet20('A6', 99).sublist(0, 10);
      final rankings = service.rank(
        priceHistories: {
          'A1': historyWithRet20('A1', 10),
          'A2': historyWithRet20('A2', 15),
          'A3': historyWithRet20('A3', 20),
          'A4': historyWithRet20('A4', 25),
          'A5': historyWithRet20('A5', 30),
          'A6': short,
        },
        industries: {
          'A1': '半導體業',
          'A2': '半導體業',
          'A3': '半導體業',
          'A4': '半導體業',
          'A5': '半導體業',
          'A6': '半導體業',
        },
        names: const {},
        institutionalHistories: const {},
      );

      expect(rankings, hasLength(1));
      expect(rankings[0].memberCount, 5);
      expect(rankings[0].momentumPct, closeTo(20.0, 1e-6));
    });

    test('法人合計 = 外資+投信、只取近 rankingInstitutionalDays 個交易日', () {
      final d = DateTime(2026, 7, 20);
      final rankings = service.rank(
        priceHistories: {
          'A1': historyWithRet20('A1', 10),
          'A2': historyWithRet20('A2', 15),
          'A3': historyWithRet20('A3', 20),
          'A4': historyWithRet20('A4', 25),
          'A5': historyWithRet20('A5', 30),
        },
        industries: {
          'A1': '半導體業',
          'A2': '半導體業',
          'A3': '半導體業',
          'A4': '半導體業',
          'A5': '半導體業',
        },
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

    test('window=d5 → 用 5 日報酬排序（轉折族群視角）', () {
      // 半導體：20日跌但近5日翻強；紡織：20日漲但近5日走平
      // 收盤序列（21 筆）：半導體 前 16 筆 100→尾 5 筆拉到 108（20日 +8%、
      // 5日 +8%）...直接構造兩組序列驗證兩種 window 排序互換。
      List<DailyPriceEntry> seq(String symbol, List<double> closes) {
        final start = DateTime(2026, 6, 1);
        return [
          for (var i = 0; i < closes.length; i++)
            createTestPrice(
              symbol: symbol,
              date: start.add(Duration(days: i)),
              close: closes[i],
            ),
        ];
      }

      // 電子型：起點 120 一路跌到 100、最後 5 根反彈到 110
      // → 20日 = (110-120)/120 = -8.3%、5日 = (110-100)/100 = +10%
      final bounce = [
        120.0,
        ...List.filled(14, 105.0),
        100.0,
        102.0,
        104.0,
        106.0,
        108.0,
        110.0,
      ];
      // 防守型：起點 100 緩漲到 105、近 5 日持平
      // → 20日 = +5%、5日 = 0%
      final steady = [
        100.0,
        ...List.filled(14, 103.0),
        105.0,
        105.0,
        105.0,
        105.0,
        105.0,
        105.0,
      ];

      final priceHistories = {
        for (var m = 0; m < 5; m++) 'E$m': seq('E$m', bounce),
        for (var m = 0; m < 5; m++) 'F$m': seq('F$m', steady),
      };
      final industries = {
        for (var m = 0; m < 5; m++) 'E$m': '半導體業',
        for (var m = 0; m < 5; m++) 'F$m': '金融保險業',
      };

      final by20 = service.rank(
        priceHistories: priceHistories,
        industries: industries,
        names: const {},
        institutionalHistories: const {},
      );
      final by5 = service.rank(
        priceHistories: priceHistories,
        industries: industries,
        names: const {},
        institutionalHistories: const {},
        window: RankingWindow.d5,
      );

      // 20日視角：金融在前（半導體仍為負）
      expect(by20.first.industry, '金融保險業');
      expect(by20.last.industry, '半導體業');
      expect(by20.last.momentumPct, lessThan(0));
      // 5日視角：半導體反彈居首
      expect(by5.first.industry, '半導體業');
      expect(by5.first.momentumPct, closeTo(10.0, 1e-6));
      expect(by5.first.topMembers.first.retPct, closeTo(10.0, 1e-6));
      expect(by5.last.momentumPct, closeTo(0.0, 1e-6));
    });
  });
}
