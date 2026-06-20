import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/risk_warnings.dart';
import 'package:afterclose/presentation/providers/mode_recommendation_provider.dart';

/// [ModeRecommendation.topSeverity] 把 warningReasons 委派給
/// [RiskWarnings.topSeverity] — 守護 model ↔ 警訊徽章的 wiring。
void main() {
  ModeRecommendation make(List<ReasonType> warnings) => ModeRecommendation(
    symbol: '0000',
    rank: 1,
    modeScoreShort: 50,
    modeScoreLong: 50,
    reasons: const [],
    warningReasons: warnings,
  );

  test('預設無警訊 → warningReasons 空、topSeverity null', () {
    final rec = ModeRecommendation(
      symbol: '0000',
      rank: 1,
      modeScoreShort: 50,
      modeScoreLong: 50,
      reasons: const [],
    );
    expect(rec.warningReasons, isEmpty);
    expect(rec.topSeverity, isNull);
  });

  test('含 severe → topSeverity severe', () {
    final rec = make([
      ReasonType.dayTradingHigh,
      ReasonType.tradingWarningDisposal,
    ]);
    expect(rec.topSeverity, RiskSeverity.severe);
  });

  test('只有 moderate → topSeverity moderate', () {
    final rec = make([ReasonType.kdDeathCross]);
    expect(rec.topSeverity, RiskSeverity.moderate);
  });
}
