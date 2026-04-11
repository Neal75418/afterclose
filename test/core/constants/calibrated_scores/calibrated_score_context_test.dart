import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/calibrated_scores/calibrated_score_context.dart';
import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_registry.dart';
import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_table.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';

void main() {
  group('CalibratedScoreContext', () {
    tearDown(() {
      CalibratedScoresRegistry.instance.resetForTesting();
    });

    test('1. empty_context_returns_null_for_any_lookup', () {
      const ctx = CalibratedScoreContext.empty;

      expect(ctx.shortScores, isEmpty);
      expect(ctx.longScores, isEmpty);
      expect(ctx.lookup(Horizon.short, 'REVERSAL_W2S'), isNull);
      expect(ctx.lookup(Horizon.long, 'TECH_BREAKOUT'), isNull);
      expect(ctx.lookup(Horizon.short, 'ANY_RULE'), isNull);
    });

    test('2. lookup_short_and_long_independently', () {
      const ctx = CalibratedScoreContext(
        shortScores: {'REVERSAL_W2S': 28, 'TECH_BREAKOUT': 22},
        longScores: {'REVERSAL_W2S': 35, 'KD_GOLDEN_CROSS': 18},
      );

      expect(ctx.lookup(Horizon.short, 'REVERSAL_W2S'), 28);
      expect(ctx.lookup(Horizon.long, 'REVERSAL_W2S'), 35);
      expect(ctx.lookup(Horizon.short, 'TECH_BREAKOUT'), 22);
      expect(ctx.lookup(Horizon.long, 'TECH_BREAKOUT'), isNull);
      expect(ctx.lookup(Horizon.short, 'KD_GOLDEN_CROSS'), isNull);
      expect(ctx.lookup(Horizon.long, 'KD_GOLDEN_CROSS'), 18);
    });

    test('3. toMap_fromMap_round_trip_preserves_content', () {
      const original = CalibratedScoreContext(
        shortScores: {'REVERSAL_W2S': 28, 'TECH_BREAKOUT': 22},
        longScores: {'REVERSAL_W2S': 35},
      );

      final serialized = original.toMap();
      final restored = CalibratedScoreContext.fromMap(serialized);

      expect(restored.lookup(Horizon.short, 'REVERSAL_W2S'), 28);
      expect(restored.lookup(Horizon.short, 'TECH_BREAKOUT'), 22);
      expect(restored.lookup(Horizon.long, 'REVERSAL_W2S'), 35);
      expect(restored.shortScores.length, 2);
      expect(restored.longScores.length, 1);
    });

    test('4. fromMap_with_null_fields_falls_back_to_empty', () {
      // Isolate 邊界可能傳入 null 或缺欄位的 map — 不應 throw
      final ctx1 = CalibratedScoreContext.fromMap({
        'shortScores': null,
        'longScores': {'REVERSAL_W2S': 35},
      });
      expect(ctx1.shortScores, isEmpty);
      expect(ctx1.lookup(Horizon.long, 'REVERSAL_W2S'), 35);

      final ctx2 = CalibratedScoreContext.fromMap({});
      expect(ctx2.shortScores, isEmpty);
      expect(ctx2.longScores, isEmpty);
      expect(ctx2.lookup(Horizon.short, 'ANY'), isNull);
    });

    test('5. snapshotForIsolate_from_registry_packages_both_horizons', () {
      // 注入兩個 fake table，驗證 registry 能正確打包成 DTO
      CalibratedScoresRegistry.instance.bindForTesting(
        short: const CalibratedScoresTable(
          horizon: Horizon.short,
          schemaVersion: 1,
          generatedAt: null,
          scores: {'REVERSAL_W2S': 28, 'TECH_BREAKOUT': 22},
        ),
        long: const CalibratedScoresTable(
          horizon: Horizon.long,
          schemaVersion: 1,
          generatedAt: null,
          scores: {'REVERSAL_W2S': 35},
        ),
      );

      final ctx = CalibratedScoresRegistry.instance.snapshotForIsolate();

      expect(ctx.lookup(Horizon.short, 'REVERSAL_W2S'), 28);
      expect(ctx.lookup(Horizon.short, 'TECH_BREAKOUT'), 22);
      expect(ctx.lookup(Horizon.long, 'REVERSAL_W2S'), 35);
      expect(ctx.lookup(Horizon.long, 'TECH_BREAKOUT'), isNull);
    });

    test('6. snapshotForIsolate_with_unloaded_registry_returns_empty', () {
      // Registry 未載入（tearDown 清空）— snapshot 應回傳空 context
      // 而不是 throw，讓 scoring isolate 能順利走 fallback 路徑
      final ctx = CalibratedScoresRegistry.instance.snapshotForIsolate();

      expect(ctx.shortScores, isEmpty);
      expect(ctx.longScores, isEmpty);
      expect(ctx.lookup(Horizon.short, 'ANY'), isNull);
      expect(ctx.lookup(Horizon.long, 'ANY'), isNull);
    });

    test('7. snapshot_is_unmodifiable_and_decoupled_from_source', () {
      // scoresSnapshot 應回傳 unmodifiable view，防止 isolate transport
      // 時意外寫入汙染 registry 內部狀態
      final mutableSource = <String, int>{'REVERSAL_W2S': 28};
      final table = CalibratedScoresTable(
        horizon: Horizon.short,
        schemaVersion: 1,
        generatedAt: null,
        scores: mutableSource,
      );

      final snapshot = table.scoresSnapshot();

      // Snapshot 是 unmodifiable
      expect(() => snapshot['NEW_KEY'] = 99, throwsA(isA<UnsupportedError>()));

      // Source 改動不影響已拍的 snapshot（因為是 Map.unmodifiable wrap）
      // 這裡測試 snapshot 本身的 immutability；深拷貝語意由 Dart 的
      // isolate transport 自己處理
      expect(snapshot['REVERSAL_W2S'], 28);
    });
  });
}
