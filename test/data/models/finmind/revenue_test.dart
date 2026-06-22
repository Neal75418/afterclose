import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/models/finmind/revenue.dart';

void main() {
  group('FinMindRevenue.fromJson 單位轉換', () {
    test('FinMind revenue(元) → 千元(÷1000) 對齊欄位慣例', () {
      // 真實 FinMind 2330 2026-06 revenue=416,975,163,000 元 → 應存 416,975,163 千元
      // （與 TWSE t187ap05_L / RevenueNewHighRule 的千元慣例一致）
      final r = FinMindRevenue.fromJson(<String, dynamic>{
        'stock_id': '2330',
        'date': '2026-06-01',
        'revenue': 416975163000,
        'revenue_month': 6,
        'revenue_year': 2026,
      });

      expect(
        r.revenue,
        closeTo(416975163, 1e-6),
        reason: 'FinMind 元 ÷1000 = 千元（修前會存大 1000 倍）',
      );
    });

    test('成長率為營收比值、不受 ÷1000 縮放影響', () {
      final list = FinMindRevenue.calculateGrowthRates([
        FinMindRevenue.fromJson(<String, dynamic>{
          'stock_id': 'X',
          'date': '2026-05-01',
          'revenue': 100000000,
          'revenue_month': 5,
          'revenue_year': 2026,
        }),
        FinMindRevenue.fromJson(<String, dynamic>{
          'stock_id': 'X',
          'date': '2026-06-01',
          'revenue': 110000000,
          'revenue_month': 6,
          'revenue_year': 2026,
        }),
      ]);

      final june = list.firstWhere((r) => r.revenueMonth == 6);
      expect(
        june.momGrowth,
        closeTo(10.0, 1e-6),
        reason: 'MoM=(110-100)/100=10%，÷1000 在分子分母相消',
      );
    });
  });
}
