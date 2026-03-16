import 'package:afterclose/domain/services/rule_registry.dart';
import 'package:afterclose/domain/services/rules/rule_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleRegistry', () {
    test('defaultRules contains 60 rules', () {
      expect(RuleRegistry.totalCount, 60);
      expect(RuleRegistry.defaultRules.length, 60);
    });

    test('all rule IDs are unique', () {
      final ids = RuleRegistry.defaultRules.map((r) => r.id).toSet();
      expect(ids.length, RuleRegistry.totalCount);
    });

    test('all rules have non-empty id and name', () {
      for (final rule in RuleRegistry.defaultRules) {
        expect(rule.id, isNotEmpty, reason: '${rule.runtimeType} has empty id');
        expect(
          rule.name,
          isNotEmpty,
          reason: '${rule.runtimeType} has empty name',
        );
      }
    });

    test('categoryCounts covers all RuleCategory values', () {
      final counts = RuleRegistry.categoryCounts;
      for (final category in RuleCategory.values) {
        expect(
          counts.containsKey(category),
          isTrue,
          reason: '$category missing from categoryCounts',
        );
        expect(counts[category], greaterThan(0));
      }
    });

    test('categoryCounts sum equals totalCount', () {
      final counts = RuleRegistry.categoryCounts;
      final sum = counts.values.fold<int>(0, (a, b) => a + b);
      expect(sum, RuleRegistry.totalCount);
    });

    test('byCategory returns correct count per category', () {
      final counts = RuleRegistry.categoryCounts;
      for (final category in RuleCategory.values) {
        final rules = RuleRegistry.byCategory(category);
        expect(
          rules.length,
          counts[category],
          reason: 'byCategory($category) count mismatch',
        );
        for (final rule in rules) {
          expect(rule.category, category);
        }
      }
    });

    test('expected category distribution', () {
      final counts = RuleRegistry.categoryCounts;
      // 技術面最多（趨勢 + K線 + 指標 + 背離 + 成交量）
      expect(counts[RuleCategory.technical], 31);
      // 基本面（營收 + EPS + ROE + 估值 + 股利）
      expect(counts[RuleCategory.fundamental], 15);
      // 風險（注意處置 + 董監持股）
      expect(counts[RuleCategory.risk], 7);
      // 市場資料（外資持股 + 當沖 + 集中度）
      expect(counts[RuleCategory.market], 5);
      // 法人（連續買賣）
      expect(counts[RuleCategory.institutional], 2);
    });
  });
}
