import 'package:afterclose/domain/services/rule_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleRegistry', () {
    test('defaultRules contains 60 rules', () {
      expect(RuleRegistry.defaultRules.length, 60);
    });

    test('all rule IDs are unique', () {
      final ids = RuleRegistry.defaultRules.map((r) => r.id).toSet();
      expect(ids.length, RuleRegistry.defaultRules.length);
    });

    test('all rules have non-empty id', () {
      for (final rule in RuleRegistry.defaultRules) {
        expect(rule.id, isNotEmpty, reason: '${rule.runtimeType} has empty id');
      }
    });
  });
}
