// ThesisInvalidationRules 測試 — timeStop 單一失效條件（gate 定案範圍）
//
// 語意與 gate 的 simulateExit 一致（docs/plans/2026-07-12-exit-gate-report.md
// 砍掉 hardStop/trendBreak）：滿 40 交易日（價格列數計）且從未收高於
// referencePrice → 失效、觸發日 = 首個滿足日。
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/exit_params.dart';
import 'package:afterclose/domain/services/thesis/thesis_invalidation_rules.dart';

void main() {
  // closes[0] = 釘選日（t0）；序列可含 null（停牌列）
  group('ThesisInvalidationRules.evaluate — timeStop', () {
    test('40 列後從未收高於 ref → 觸發、觸發 offset = 40', () {
      final closes = List<double?>.filled(50, 100.0);
      final r = ThesisInvalidationRules.evaluate(
        referencePrice: 100.0,
        closesFromPinnedDate: closes,
      );
      expect(r, isNotNull);
      expect(r!.reason, ExitReason.timeStop);
      expect(r.triggerOffset, ExitParams.timeStopTradingDays);
    });

    test('中途曾收高於 ref → 永不觸發', () {
      final closes = List<double?>.filled(50, 100.0);
      closes[10] = 101.0;
      expect(
        ThesisInvalidationRules.evaluate(
          referencePrice: 100.0,
          closesFromPinnedDate: closes,
        ),
        isNull,
      );
    });

    test('未滿 40 列 → 未觸發（倒數中）', () {
      final closes = List<double?>.filled(39, 100.0);
      expect(
        ThesisInvalidationRules.evaluate(
          referencePrice: 100.0,
          closesFromPinnedDate: closes,
        ),
        isNull,
      );
    });

    test('邊界日恰收高於 ref → 論點實現、壓制觸發（everAbove 先更新）', () {
      final closes = List<double?>.filled(50, 100.0);
      closes[ExitParams.timeStopTradingDays] = 100.5; // 第 40 列本身收高
      expect(
        ThesisInvalidationRules.evaluate(
          referencePrice: 100.0,
          closesFromPinnedDate: closes,
        ),
        isNull,
      );
    });

    test('null 列（停牌）跳過判定但計入列數（與 gate 語意一致）', () {
      final closes = List<double?>.filled(50, 100.0);
      closes[40] = null; // 第 40 列停牌 → 觸發順延到第 41 列
      final r = ThesisInvalidationRules.evaluate(
        referencePrice: 100.0,
        closesFromPinnedDate: closes,
      );
      expect(r!.triggerOffset, 41);
    });
  });
}
