// simulateExit 純函數測試 — 出場條件 replay gate 核心
// (docs/plans/2026-07-11-exit-validate-gate-plan.md Task 2)
//
// 合成序列手算對照：平坦 100 基底，指定位置覆寫製造觸發情境。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/exit_params.dart';

import '../../tool/exit_validate.dart';

/// 平坦 100 序列，指定位置覆寫
List<double?> flat(int len, {Map<int, double?> overrides = const {}}) => [
  for (var i = 0; i < len; i++) overrides.containsKey(i) ? overrides[i] : 100.0,
];

void main() {
  const all = {ExitReason.hardStop, ExitReason.trendBreak, ExitReason.timeStop};

  group('simulateExit — hardStop', () {
    test('T+3 收盤 91.9 (< 92) → hardStop 出場、報酬對 T+1 計算', () {
      // t0=70（前面 70 根供 MA60）、entry=closes[71]=100、d=73 跌到 91.9
      final closes = flat(140, overrides: {73: 91.9});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.reason, ExitReason.hardStop);
      expect(r.holdingDays, 2); // 71→73
      expect(r.exitReturnPct, closeTo(-8.1, 0.001)); // 91.9/100-1
      expect(r.holdReturnPct, closeTo(0.0, 0.001)); // 其餘平坦
    });

    test('恰等於 92（非 <）→ 不觸發 hardStop', () {
      final closes = flat(140, overrides: {73: 92.0});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.reason, isNot(ExitReason.hardStop));
    });
  });

  group('simulateExit — trendBreak', () {
    test('收盤跌破 60 日均線 → trendBreak', () {
      // 平坦 100，d=75 跌到 99（MA60≈99.98，99 < MA、但 > 92 不觸發 hardStop）
      final closes = flat(140, overrides: {75: 99.0});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.reason, ExitReason.trendBreak);
      expect(r.holdingDays, 4);
    });

    test('MA60 資料不足（t0 前不滿 60 根）→ trendBreak 不判定', () {
      // t0=30、只有 30 根歷史 → 該條件永不觸發，其餘平坦 → 無觸發跑滿
      final closes = flat(100, overrides: {35: 99.0});
      final r = simulateExit(
        closes: closes,
        t0Index: 30,
        enabled: {ExitReason.trendBreak},
      )!;
      expect(r.reason, isNull);
    });
  });

  group('simulateExit — timeStop', () {
    test('40 交易日從未收高於 ref → timeStop', () {
      final closes = flat(140); // 永遠 = ref，從未「高於」
      final r = simulateExit(
        closes: closes,
        t0Index: 70,
        enabled: {ExitReason.timeStop},
      )!;
      expect(r.reason, ExitReason.timeStop);
      // 首個 d-t0 ≥ 40 的日子 = t0+40 = 110 → 持有 110-71 = 39 日
      expect(r.holdingDays, 39);
    });

    test('中途曾收高於 ref → timeStop 不觸發', () {
      final closes = flat(140, overrides: {90: 101.0});
      final r = simulateExit(
        closes: closes,
        t0Index: 70,
        enabled: {ExitReason.timeStop},
      )!;
      expect(r.reason, isNull);
    });
  });

  group('simulateExit — tie-break 與邊界', () {
    test('同日 hardStop+trendBreak 皆真 → 取 hardStop（宣告序）', () {
      final closes = flat(140, overrides: {75: 80.0});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.reason, ExitReason.hardStop);
    });

    test('窗不足（t0+1+60 超界）→ null（survivorship 樣本）', () {
      expect(
        simulateExit(closes: flat(100), t0Index: 70, enabled: all),
        isNull,
      );
    });

    test('T+1 收盤 null（停牌）→ null', () {
      final closes = flat(140, overrides: {71: null});
      expect(simulateExit(closes: closes, t0Index: 70, enabled: all), isNull);
    });

    test('全程未觸發 → reason null、兩臂同報酬、holdingDays = horizon', () {
      final closes = flat(140, overrides: {131: 110.0}); // horizon 末端漲
      final r = simulateExit(
        closes: closes,
        t0Index: 70,
        enabled: {ExitReason.hardStop},
      )!;
      expect(r.reason, isNull);
      expect(r.exitReturnPct, r.holdReturnPct);
      expect(r.holdingDays, ExitParams.holdHorizonTradingDays);
    });

    test('MDD：出場版計到出場日、持有版計全窗', () {
      // d=75 跌 90（-10%）觸發 hardStop；d=100 再跌 80（持有版 MDD -20%）
      final closes = flat(140, overrides: {75: 90.0, 100: 80.0});
      final r = simulateExit(closes: closes, t0Index: 70, enabled: all)!;
      expect(r.exitMddPct, closeTo(-10.0, 0.01));
      expect(r.holdMddPct, closeTo(-20.0, 0.01));
    });
  });
}
