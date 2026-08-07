import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/domain/services/alert/alert_target_calculator.dart';

/// 提醒觸發價計算(2026-08-07)。
///
/// 契約:app 只負責「把價位算好」,使用者點哪個由他自己決定。
/// 守門價採 **2.0×ATR(20)**——2026-08-07 回測定案的 k 值(見 v3.3 §4.1):
/// 固定 % 的停損落在飆股單日噪音內,被洗率 55.9%;2.0×ATR 降到 18.9%。
void main() {
  /// 造 n 根日線:收盤等距上升,每日高低差固定 range
  List<Ohlc> bars(
    int n, {
    double start = 100,
    double step = 1,
    double range = 4,
  }) {
    return [
      for (var i = 0; i < n; i++)
        Ohlc(
          high: start + i * step + range / 2,
          low: start + i * step - range / 2,
          close: start + i * step,
        ),
    ];
  }

  group('均線類觸發價', () {
    test('跌破 5MA/10MA/20MA:價位=該均線,方向向下', () {
      final t = AlertTargetCalculator.compute(bars(30));
      // 收盤 100,101,...129;5MA=(125..129)/5=127
      expect(t[AlertKind.breakBelowMa5]!.price, closeTo(127, 1e-9));
      expect(t[AlertKind.breakBelowMa5]!.isUpward, isFalse);
      expect(t[AlertKind.breakBelowMa10]!.price, closeTo(124.5, 1e-9));
      expect(t[AlertKind.breakBelowMa20]!.price, closeTo(119.5, 1e-9));
      expect(t[AlertKind.breakBelowMa20]!.isUpward, isFalse);
    });

    test('突破月線:同樣是 20MA 但方向向上(回榜資格訊號)', () {
      final t = AlertTargetCalculator.compute(bars(30));
      expect(t[AlertKind.breakAboveMa20]!.price, closeTo(119.5, 1e-9));
      expect(t[AlertKind.breakAboveMa20]!.isUpward, isTrue);
    });
  });

  test('突破 20 日高=結構 C 觸發線,取近 20 根的最高價、向上', () {
    final t = AlertTargetCalculator.compute(bars(30));
    // 近 20 根(index 10..29)最高 = 129+2 = 131
    expect(t[AlertKind.breakAbove20DayHigh]!.price, closeTo(131, 1e-9));
    expect(t[AlertKind.breakAbove20DayHigh]!.isUpward, isTrue);
  });

  test('🚨 守門價 = 最新收盤 − 2.0×ATR(20),向下(v3.3 §4.1 的 k)', () {
    final b = bars(30, range: 4); // 每日 TR 固定 4(高低差)…含前收缺口後仍為 4~5
    final t = AlertTargetCalculator.compute(b);
    final gate = t[AlertKind.stopGate]!;
    expect(gate.isUpward, isFalse);
    // ATR 應落在 4~5 之間 → 守門價 = 129 − 2×ATR
    final atr = (129 - gate.price) / 2;
    expect(atr, greaterThan(3.5));
    expect(atr, lessThan(5.5));
    expect(gate.price, lessThan(129));
  });

  test('資料不足 20 根 → 只給算得出來的,不硬湊', () {
    final t = AlertTargetCalculator.compute(bars(8));
    expect(t.containsKey(AlertKind.breakBelowMa5), isTrue);
    expect(t.containsKey(AlertKind.breakBelowMa10), isFalse);
    expect(t.containsKey(AlertKind.breakBelowMa20), isFalse);
    expect(t.containsKey(AlertKind.stopGate), isFalse);
  });

  test('空資料 → 空 map,不拋例外', () {
    expect(AlertTargetCalculator.compute(const []), isEmpty);
  });

  test('方向對應既有警示系統的 alertType(不自建判定邏輯)', () {
    final t = AlertTargetCalculator.compute(bars(30));
    expect(t[AlertKind.breakBelowMa10]!.alertTypeValue, 'BELOW');
    expect(t[AlertKind.breakAboveMa20]!.alertTypeValue, 'ABOVE');
    expect(t[AlertKind.stopGate]!.alertTypeValue, 'BELOW');
  });
}
