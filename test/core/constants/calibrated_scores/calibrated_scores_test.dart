import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_registry.dart';
import 'package:afterclose/core/constants/calibrated_scores/calibrated_scores_table.dart';
import 'package:afterclose/core/constants/calibrated_scores/horizon.dart';
import 'package:afterclose/core/constants/reason_type.dart';
import 'package:afterclose/core/constants/rule_scores.dart';

/// Helper: 建 happy-path JSON 字串
String _buildJson({
  int schemaVersion = 1,
  String? generatedAt = '2026-04-11T00:00:00.000Z',
  Map<String, Object?>? rules,
  Map<String, Object?> extraRootFields = const {},
}) {
  final buffer = StringBuffer('{');
  buffer.write('"schema_version": $schemaVersion');
  if (generatedAt != null) {
    buffer.write(', "generated_at": "$generatedAt"');
  }
  buffer.write(', "rules": ${_jsonEncode(rules ?? {})}');
  for (final entry in extraRootFields.entries) {
    buffer.write(', "${entry.key}": ${_jsonEncode(entry.value)}');
  }
  buffer.write('}');
  return buffer.toString();
}

String _jsonEncode(Object? value) {
  if (value == null) return 'null';
  if (value is String) return '"$value"';
  if (value is num || value is bool) return value.toString();
  if (value is List) {
    return '[${value.map(_jsonEncode).join(',')}]';
  }
  if (value is Map) {
    final entries = value.entries
        .map((e) => '"${e.key}": ${_jsonEncode(e.value)}')
        .join(', ');
    return '{$entries}';
  }
  throw ArgumentError('unsupported type: ${value.runtimeType}');
}

Map<String, Object?> _rule(
  int score, {
  double hitRate = 0.5,
  int samples = 100,
}) {
  return {'score': score, 'hit_rate': hitRate, 'samples': samples};
}

void main() {
  group('CalibratedScoresTable.parseJson [Layer 1: pure parser]', () {
    // ==================================================
    // Happy path (6 cases)
    // ==================================================

    test('1. happy_path_both_horizons_full: 62 rules fully parsed', () {
      final rules = <String, Object?>{
        for (var i = 0; i < 62; i++) 'RULE_$i': _rule(10 + i % 30),
      };
      final json = _buildJson(rules: rules);

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 62);
      expect(table.schemaVersion, 1);
      expect(table.horizon, Horizon.short);
      expect(warnings, isEmpty);
      expect(table.lookup('RULE_0'), 10);
      expect(table.lookup('RULE_30'), 10);
    });

    test('2. empty_rules_returns_empty_table', () {
      final json = _buildJson(rules: {});

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 0);
      expect(table.schemaVersion, 1);
      expect(warnings, isEmpty);
      expect(table.lookup('ANY_RULE'), isNull);
    });

    test('3. partial_rules_returns_partial_table', () {
      final json = _buildJson(
        rules: {
          'REVERSAL_W2S': _rule(28),
          'TECH_BREAKOUT': _rule(22),
          'VOLUME_SPIKE': _rule(18),
        },
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.long,
      );

      expect(table.ruleCount, 3);
      expect(warnings, isEmpty);
      expect(table.lookup('REVERSAL_W2S'), 28);
      expect(table.lookup('TECH_BREAKOUT'), 22);
      expect(table.lookup('MISSING_RULE'), isNull);
    });

    test('4. schema_version_1_accepted', () {
      final json = _buildJson(schemaVersion: 1, rules: {});
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );
      expect(table.schemaVersion, 1);
      expect(warnings, isEmpty);
    });

    test('5. generatedAt_parsed_correctly', () {
      final json = _buildJson(
        generatedAt: '2026-04-11T12:34:56.789Z',
        rules: {},
      );
      final (:table, warnings: _) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );
      expect(table.generatedAt, isNotNull);
      expect(table.generatedAt!.year, 2026);
      expect(table.generatedAt!.month, 4);
      expect(table.generatedAt!.day, 11);
    });

    test('6. extra_unknown_top_level_fields_ignored', () {
      final json = _buildJson(
        rules: {'REVERSAL_W2S': _rule(28)},
        extraRootFields: {
          '_note': 'This is a placeholder stub',
          'backtest': {'window_days': 504, 'train_ratio': 0.7},
          'horizon': '5d',
        },
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.lookup('REVERSAL_W2S'), 28);
      expect(warnings, isEmpty);
    });

    // ==================================================
    // Structural errors (5 cases, scenarios 1-2d)
    // ==================================================

    test('7. malformed_json_returns_empty', () {
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        '{not valid json',
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 0);
      expect(table.schemaVersion, 0);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('malformed JSON'));
    });

    test('8. root_not_object_returns_empty', () {
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        '[1, 2, 3]',
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 0);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('root must be object'));
    });

    test('9. schema_version_missing_returns_empty', () {
      const json = '{"rules": {}}';
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 0);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('schema_version missing'));
    });

    test('10. schema_version_unsupported_returns_empty', () {
      final json = _buildJson(schemaVersion: 2, rules: {});
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 0);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('unsupported schema_version: 2'));
    });

    test('11. rules_field_missing_returns_empty', () {
      const json = '{"schema_version": 1}';
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 0);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('rules field missing'));
    });

    test('11b. rules_wrong_type_returns_empty', () {
      const json = '{"schema_version": 1, "rules": "not a map"}';
      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 0);
      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('rules must be object'));
    });

    // ==================================================
    // Per-rule content errors (7 cases, scenarios 5a-6b + 7)
    // ==================================================

    test('12. rule_entry_not_object_skipped', () {
      final json = _buildJson(
        rules: {
          'REVERSAL_W2S': 25, // raw int instead of object
          'TECH_BREAKOUT': _rule(22),
        },
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.lookup('REVERSAL_W2S'), isNull);
      expect(table.lookup('TECH_BREAKOUT'), 22);
      expect(warnings.length, 1);
      expect(warnings.first, contains('REVERSAL_W2S'));
      expect(warnings.first, contains('entry not object'));
    });

    test('13. rule_score_missing_skipped', () {
      final json = _buildJson(
        rules: {
          'REVERSAL_W2S': {'hit_rate': 0.5, 'samples': 100},
          'TECH_BREAKOUT': _rule(22),
        },
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.lookup('REVERSAL_W2S'), isNull);
      expect(table.lookup('TECH_BREAKOUT'), 22);
      expect(warnings.length, 1);
      expect(warnings.first, contains('score field missing'));
    });

    test('14. rule_score_not_numeric_skipped', () {
      final json = _buildJson(
        rules: {
          'REVERSAL_W2S': {'score': 'abc', 'hit_rate': 0.5},
          'TECH_BREAKOUT': _rule(22),
        },
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.lookup('REVERSAL_W2S'), isNull);
      expect(table.lookup('TECH_BREAKOUT'), 22);
      expect(warnings.length, 1);
      expect(warnings.first, contains('score not numeric'));
    });

    test('14b. rule_score_fractional_rounded_with_warning', () {
      // JSON `22.7` is parsed as double. Parser should round (not truncate)
      // to avoid the asymmetric `.toInt()` behavior for negatives.
      const json =
          '{"schema_version": 1, "rules": {'
          '"FRAC_POS": {"score": 22.7},'
          '"FRAC_NEG": {"score": -22.7},'
          '"INT_AS_DOUBLE": {"score": 25.0},'
          '"PURE_INT": {"score": 10}'
          '}}';

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      // Round-half-away-from-zero: 22.7 → 23, -22.7 → -23 (symmetric)
      expect(table.lookup('FRAC_POS'), 23);
      expect(table.lookup('FRAC_NEG'), -23);
      // 25.0 equals int 25 so no rounding warning
      expect(table.lookup('INT_AS_DOUBLE'), 25);
      expect(table.lookup('PURE_INT'), 10);

      // Only two fractional entries should produce warnings
      expect(warnings.length, 2);
      expect(warnings.any((w) => w.contains('FRAC_POS')), isTrue);
      expect(warnings.any((w) => w.contains('FRAC_NEG')), isTrue);
      expect(
        warnings.first,
        anyOf(contains('rounded to 23'), contains('rounded to -23')),
      );
    });

    test('15. rule_score_above_max_clamped_to_80', () {
      final json = _buildJson(rules: {'REVERSAL_W2S': _rule(999)});

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.lookup('REVERSAL_W2S'), RuleScores.maxScore);
      expect(warnings.length, 1);
      expect(warnings.first, contains('999'));
      expect(warnings.first, contains('clamped to 80'));
    });

    test('16. rule_score_below_min_clamped_to_-50', () {
      final json = _buildJson(rules: {'TRADING_WARNING_DISPOSAL': _rule(-999)});

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.long,
      );

      expect(table.lookup('TRADING_WARNING_DISPOSAL'), RuleScores.minScore);
      expect(warnings.length, 1);
      expect(warnings.first, contains('-999'));
      expect(warnings.first, contains('clamped to -50'));
    });

    test('17. rule_score_at_boundary_not_clamped', () {
      final json = _buildJson(
        rules: {
          'REVERSAL_W2S': _rule(RuleScores.maxScore), // 80
          'TRADING_WARNING_DISPOSAL': _rule(RuleScores.minScore), // -50
        },
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.lookup('REVERSAL_W2S'), 80);
      expect(table.lookup('TRADING_WARNING_DISPOSAL'), -50);
      expect(warnings, isEmpty);
    });

    test('18. unknown_rule_id_skipped_with_warning_when_whitelist_set', () {
      final json = _buildJson(
        rules: {'REVERSAL_W2S': _rule(28), 'FAKE_UNKNOWN_RULE': _rule(25)},
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
        knownRuleIds: {'REVERSAL_W2S', 'TECH_BREAKOUT'},
      );

      expect(table.lookup('REVERSAL_W2S'), 28);
      expect(table.lookup('FAKE_UNKNOWN_RULE'), isNull);
      expect(warnings.length, 1);
      expect(warnings.first, contains('FAKE_UNKNOWN_RULE'));
      expect(warnings.first, contains('unknown ReasonType code'));
    });

    test('18b. null_whitelist_accepts_any_rule_id', () {
      // When knownRuleIds is null (Stage 5a Commit 1 default), scenario 7
      // check is skipped and any rule_id is accepted.
      final json = _buildJson(rules: {'TOTALLY_FAKE_RULE': _rule(25)});

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.lookup('TOTALLY_FAKE_RULE'), 25);
      expect(warnings, isEmpty);
    });

    // ==================================================
    // Mixed scenarios (2 cases)
    // ==================================================

    test('19. mixed_valid_and_invalid_rules', () {
      final json = _buildJson(
        rules: {
          'VALID_1': _rule(20),
          'VALID_2': _rule(15),
          'VALID_3': _rule(30),
          'INVALID_NOT_OBJECT': 99,
          'INVALID_NO_SCORE': {'hit_rate': 0.5},
          'INVALID_SCORE_TYPE': {'score': 'xyz'},
        },
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 3);
      expect(table.lookup('VALID_1'), 20);
      expect(table.lookup('VALID_2'), 15);
      expect(table.lookup('VALID_3'), 30);
      expect(warnings.length, 3);
    });

    test('20. clamp_coexists_with_skip', () {
      final json = _buildJson(
        rules: {
          'VALID_IN_RANGE': _rule(25),
          'CLAMPED_HIGH': _rule(500),
          'CLAMPED_LOW': _rule(-500),
          'SKIPPED_NO_SCORE': {'hit_rate': 0.5},
        },
      );

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.lookup('VALID_IN_RANGE'), 25);
      expect(table.lookup('CLAMPED_HIGH'), RuleScores.maxScore);
      expect(table.lookup('CLAMPED_LOW'), RuleScores.minScore);
      expect(table.lookup('SKIPPED_NO_SCORE'), isNull);
      expect(warnings.length, 3); // 2 clamp + 1 skip
    });

    // ==================================================
    // Warning content assertions (2 cases)
    // ==================================================

    test('21. warning_messages_include_rule_id', () {
      final json = _buildJson(
        rules: {
          'MY_SPECIAL_RULE_A': {'hit_rate': 0.5}, // score missing
          'MY_SPECIAL_RULE_B': _rule(999), // clamped
          'MY_SPECIAL_RULE_C': 42, // not object
        },
      );

      final (table: _, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(warnings.length, 3);
      expect(
        warnings.where((w) => w.contains('MY_SPECIAL_RULE_A')),
        hasLength(1),
      );
      expect(
        warnings.where((w) => w.contains('MY_SPECIAL_RULE_B')),
        hasLength(1),
      );
      expect(
        warnings.where((w) => w.contains('MY_SPECIAL_RULE_C')),
        hasLength(1),
      );
    });

    test('22. warning_count_accumulates_correctly', () {
      final rules = <String, Object?>{};
      for (var i = 0; i < 20; i++) {
        rules['BAD_RULE_$i'] = {'hit_rate': 0.5}; // all missing score
      }
      final json = _buildJson(rules: rules);

      final (:table, :warnings) = CalibratedScoresTable.parseJson(
        json,
        horizon: Horizon.short,
      );

      expect(table.ruleCount, 0);
      expect(warnings.length, 20); // parser does NOT cap; registry does
    });
  });

  group('CalibratedScoresRegistry [Layer 2 + Layer 3]', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      CalibratedScoresRegistry.instance.resetForTesting();
    });

    // ==================================================
    // Layer 2: asset smoke tests (2 cases)
    // ==================================================

    test('23. loadFromAssets_short_placeholder_succeeds', () async {
      await CalibratedScoresRegistry.instance.loadFromAssets();

      // Placeholder has rules: {} so any lookup returns null → fallback path.
      final result = CalibratedScoresRegistry.instance.lookup(
        Horizon.short,
        'REVERSAL_W2S',
      );
      expect(result, isNull);
    });

    test('24. loadFromAssets_long_placeholder_succeeds', () async {
      await CalibratedScoresRegistry.instance.loadFromAssets();

      final result = CalibratedScoresRegistry.instance.lookup(
        Horizon.long,
        'REVERSAL_W2S',
      );
      expect(result, isNull);
    });

    // ==================================================
    // Layer 3: singleton lifecycle (3 cases)
    // ==================================================

    test('25. lookup_before_load_returns_null', () {
      // resetForTesting ran in tearDown of previous test, so registry is unloaded.
      final result = CalibratedScoresRegistry.instance.lookup(
        Horizon.short,
        'REVERSAL_W2S',
      );
      expect(result, isNull);
    });

    test('26. loadFromAssets_is_idempotent', () async {
      await CalibratedScoresRegistry.instance.loadFromAssets();
      // Second and third calls should be no-ops. We verify by checking that
      // bindForTesting state is not overwritten by a subsequent load.
      CalibratedScoresRegistry.instance.bindForTesting(
        short: const CalibratedScoresTable(
          horizon: Horizon.short,
          schemaVersion: 1,
          generatedAt: null,
          scores: {'FAKE_RULE': 42},
        ),
      );
      // bindForTesting sets _loaded = true. Subsequent loadFromAssets should
      // NOT reload from assets (which would wipe the fake table).
      await CalibratedScoresRegistry.instance.loadFromAssets();
      await CalibratedScoresRegistry.instance.loadFromAssets();

      final result = CalibratedScoresRegistry.instance.lookup(
        Horizon.short,
        'FAKE_RULE',
      );
      expect(
        result,
        42,
        reason: 'idempotent load must not overwrite bound state',
      );
    });

    test(
      '26b. bindForTesting_during_pending_load_is_not_overwritten',
      () async {
        // Race condition regression test:
        // If bindForTesting runs after loadFromAssets yields but before
        // it resolves, the fake table must survive the in-flight load.
        final pending = CalibratedScoresRegistry.instance.loadFromAssets();

        CalibratedScoresRegistry.instance.bindForTesting(
          short: const CalibratedScoresTable(
            horizon: Horizon.short,
            schemaVersion: 1,
            generatedAt: null,
            scores: {'FAKE_RACE': 99},
          ),
        );

        await pending;

        expect(
          CalibratedScoresRegistry.instance.lookup(Horizon.short, 'FAKE_RACE'),
          99,
          reason: 'bindForTesting must win over a pending loadFromAssets',
        );
      },
    );

    test('27. resetForTesting_clears_state', () async {
      CalibratedScoresRegistry.instance.bindForTesting(
        short: const CalibratedScoresTable(
          horizon: Horizon.short,
          schemaVersion: 1,
          generatedAt: null,
          scores: {'REVERSAL_W2S': 28},
        ),
      );
      expect(
        CalibratedScoresRegistry.instance.lookup(Horizon.short, 'REVERSAL_W2S'),
        28,
      );

      CalibratedScoresRegistry.instance.resetForTesting();

      expect(
        CalibratedScoresRegistry.instance.lookup(Horizon.short, 'REVERSAL_W2S'),
        isNull,
      );
    });

    // ==================================================
    // Layer 4: loadWithOverride (OTA C1) — DB cache takes priority
    // ==================================================

    test(
      '28. loadWithOverride_happy_path: both JSONs parse successfully',
      () async {
        final shortJson = _buildJson(rules: {'REVERSAL_W2S': _rule(28)});
        final longJson = _buildJson(rules: {'REVERSAL_W2S': _rule(32)});

        await CalibratedScoresRegistry.instance.loadWithOverride(
          shortJsonOverride: shortJson,
          longJsonOverride: longJson,
        );

        // Override values (not hardcoded RuleScores) should be returned
        expect(
          CalibratedScoresRegistry.instance.lookup(
            Horizon.short,
            'REVERSAL_W2S',
          ),
          28,
        );
        expect(
          CalibratedScoresRegistry.instance.lookup(
            Horizon.long,
            'REVERSAL_W2S',
          ),
          32,
        );
      },
    );

    test('29. loadWithOverride_both_null: falls back to bundled asset', () async {
      await CalibratedScoresRegistry.instance.loadWithOverride(
        shortJsonOverride: null,
        longJsonOverride: null,
      );

      // Placeholder assets have {} rules → lookup returns null → fallback
      // path. The key assertion is that no exception was thrown and
      // _loaded == true (proven by idempotent second call).
      final firstShort = CalibratedScoresRegistry.instance.lookup(
        Horizon.short,
        'REVERSAL_W2S',
      );
      expect(firstShort, isNull);

      // Second call should be no-op (idempotent)
      await CalibratedScoresRegistry.instance.loadWithOverride(
        shortJsonOverride:
            '{"schema_version": 1, "rules": {"X": {"score": 99}}}',
        longJsonOverride:
            '{"schema_version": 1, "rules": {"X": {"score": 99}}}',
      );
      // Should NOT have loaded the new override because _loaded is already true
      expect(
        CalibratedScoresRegistry.instance.lookup(Horizon.short, 'X'),
        isNull,
        reason: 'idempotent — second loadWithOverride must be no-op',
      );
    });

    test(
      '30. loadWithOverride_one_null: falls back to bundled asset',
      () async {
        await CalibratedScoresRegistry.instance.loadWithOverride(
          shortJsonOverride: _buildJson(rules: {'X': _rule(25)}),
          longJsonOverride: null,
        );

        // Because long override was missing, fallback path used assets
        // (which have empty rules). So X should NOT be found.
        expect(
          CalibratedScoresRegistry.instance.lookup(Horizon.short, 'X'),
          isNull,
          reason: 'atomic fallback — neither override should apply',
        );
      },
    );

    test(
      '31. loadWithOverride_malformed_short_json: falls back to assets',
      () async {
        await CalibratedScoresRegistry.instance.loadWithOverride(
          shortJsonOverride: 'not valid json {{{',
          longJsonOverride: _buildJson(rules: {'X': _rule(25)}),
        );

        // Short parse failed → empty table → fall through to asset fallback.
        // Long override was valid but atomic fallback applies to both.
        expect(
          CalibratedScoresRegistry.instance.lookup(Horizon.long, 'X'),
          isNull,
          reason: 'atomic fallback — partial override must not leak through',
        );
      },
    );

    test('32. loadWithOverride_empty_rules: falls back to assets', () async {
      // Valid schema but empty rules → ruleCount == 0 → fallback
      final emptyJson = _buildJson(rules: {});

      await CalibratedScoresRegistry.instance.loadWithOverride(
        shortJsonOverride: emptyJson,
        longJsonOverride: emptyJson,
      );

      // Empty override → fell through to bundled asset (also empty)
      expect(
        CalibratedScoresRegistry.instance.lookup(Horizon.short, 'REVERSAL_W2S'),
        isNull,
      );
    });

    test('33. loadWithOverride_idempotent: second call is no-op', () async {
      final json = _buildJson(rules: {'X': _rule(25)});

      await CalibratedScoresRegistry.instance.loadWithOverride(
        shortJsonOverride: json,
        longJsonOverride: json,
      );
      expect(CalibratedScoresRegistry.instance.lookup(Horizon.short, 'X'), 25);

      // Second call with different data should NOT overwrite
      await CalibratedScoresRegistry.instance.loadWithOverride(
        shortJsonOverride: _buildJson(rules: {'X': _rule(15)}),
        longJsonOverride: _buildJson(rules: {'X': _rule(15)}),
      );

      expect(
        CalibratedScoresRegistry.instance.lookup(Horizon.short, 'X'),
        25,
        reason: 'idempotent — second load must not overwrite',
      );
    });
  });

  group('Horizon enum metadata', () {
    test('short has 5 trading days and 3% threshold', () {
      expect(Horizon.short.tradingDays, 5);
      expect(Horizon.short.successThresholdPct, 3.0);
      expect(
        Horizon.short.assetPath,
        'assets/rule_scores_calibrated_short.json',
      );
    });

    test('long has 60 trading days and 12% threshold', () {
      expect(Horizon.long.tradingDays, 60);
      expect(Horizon.long.successThresholdPct, 12.0);
      expect(Horizon.long.assetPath, 'assets/rule_scores_calibrated_long.json');
    });

    test('exactly 2 values (invariant for Stage 5a/5b dual-horizon)', () {
      expect(Horizon.values.length, 2);
    });
  });

  group('ReasonType.scoreFor [Layer 3.5: end-to-end]', () {
    tearDown(() {
      CalibratedScoresRegistry.instance.resetForTesting();
    });

    test('28. scoreFor_without_registry_load_uses_hardcoded', () {
      // Registry is unloaded (tearDown ran). scoreFor should return the
      // hardcoded RuleScores value via fallback.
      expect(
        ReasonType.reversalW2S.scoreFor(Horizon.short),
        RuleScores.reversalW2S,
      );
      expect(
        ReasonType.techBreakout.scoreFor(Horizon.long),
        RuleScores.techBreakout,
      );
    });

    test('29. scoreFor_with_bindForTesting_uses_calibrated', () {
      // Inject a fake table for short horizon with overridden scores.
      CalibratedScoresRegistry.instance.bindForTesting(
        short: const CalibratedScoresTable(
          horizon: Horizon.short,
          schemaVersion: 1,
          generatedAt: null,
          scores: {
            'REVERSAL_W2S': 42, // override hardcoded 35
            'TECH_BREAKOUT': 18, // override hardcoded 25
          },
        ),
      );

      expect(ReasonType.reversalW2S.scoreFor(Horizon.short), 42);
      expect(ReasonType.techBreakout.scoreFor(Horizon.short), 18);

      // Long horizon was not bound → fallback to hardcoded
      expect(
        ReasonType.reversalW2S.scoreFor(Horizon.long),
        RuleScores.reversalW2S,
      );
    });

    test('30. scoreFor_unknown_rule_in_fake_table_falls_back', () {
      // Fake table only has REVERSAL_W2S. Querying a rule not in the table
      // should fall back to hardcoded.
      CalibratedScoresRegistry.instance.bindForTesting(
        short: const CalibratedScoresTable(
          horizon: Horizon.short,
          schemaVersion: 1,
          generatedAt: null,
          scores: {'REVERSAL_W2S': 42},
        ),
      );

      expect(ReasonType.reversalW2S.scoreFor(Horizon.short), 42);
      // TECH_BREAKOUT not in table → fallback
      expect(
        ReasonType.techBreakout.scoreFor(Horizon.short),
        RuleScores.techBreakout,
      );
    });
  });
}
