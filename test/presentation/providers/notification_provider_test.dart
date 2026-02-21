import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/presentation/providers/notification_provider.dart';

void main() {
  group('NotificationState', () {
    test('default values', () {
      const state = NotificationState();
      expect(state.isInitialized, isFalse);
      expect(state.hasPermission, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith updates isInitialized', () {
      const state = NotificationState();
      final updated = state.copyWith(isInitialized: true);
      expect(updated.isInitialized, isTrue);
      expect(updated.hasPermission, isFalse);
      expect(updated.error, isNull);
    });

    test('copyWith updates hasPermission', () {
      const state = NotificationState();
      final updated = state.copyWith(hasPermission: true);
      expect(updated.isInitialized, isFalse);
      expect(updated.hasPermission, isTrue);
    });

    test('copyWith updates error', () {
      const state = NotificationState();
      final updated = state.copyWith(error: 'Permission denied');
      expect(updated.error, 'Permission denied');
    });

    test('copyWith clears error when not provided', () {
      final state = const NotificationState().copyWith(error: 'Some error');
      // copyWith without error resets it to null
      final cleared = state.copyWith(isInitialized: true);
      expect(cleared.error, isNull);
      expect(cleared.isInitialized, isTrue);
    });

    test('copyWith preserves other fields', () {
      final state = const NotificationState().copyWith(
        isInitialized: true,
        hasPermission: true,
      );
      final updated = state.copyWith(error: 'Test error');
      expect(updated.isInitialized, isTrue);
      expect(updated.hasPermission, isTrue);
      expect(updated.error, 'Test error');
    });

    test('multiple copyWith chains', () {
      final state = const NotificationState()
          .copyWith(isInitialized: true)
          .copyWith(hasPermission: true)
          .copyWith(error: 'Network error');
      expect(state.isInitialized, isTrue);
      expect(state.hasPermission, isTrue);
      expect(state.error, 'Network error');
    });
  });
}
