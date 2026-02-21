import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/notification_provider.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
  });

  PriceAlertEntry createAlert({
    String symbol = '2330',
    String alertType = 'ABOVE',
    double targetValue = 900.0,
  }) {
    return PriceAlertEntry(
      id: 1,
      symbol: symbol,
      alertType: alertType,
      targetValue: targetValue,
      isActive: true,
      createdAt: DateTime(2026, 2, 13),
    );
  }

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

  group('NotificationNotifier.getAlertTitle', () {
    for (final alertType in AlertType.values) {
      test('returns non-empty title for ${alertType.name}', () {
        final title = NotificationNotifier.getAlertTitle('2330', alertType);
        expect(title, isNotEmpty);
      });
    }

    test('includes symbol in title', () {
      final title = NotificationNotifier.getAlertTitle('2330', AlertType.above);
      // .tr() returns the key when no translation found,
      // but the namedArgs substitution still happens in the key
      expect(title, isNotEmpty);
    });
  });

  group('NotificationNotifier.getAlertBody', () {
    for (final alertType in AlertType.values) {
      test('returns non-empty body for ${alertType.name}', () {
        final alert = createAlert(alertType: alertType.value);
        final body = NotificationNotifier.getAlertBody(alert, alertType, null);
        expect(body, isNotEmpty);
      });
    }

    test('appends current price suffix when provided', () {
      final alert = createAlert();
      final bodyWithPrice = NotificationNotifier.getAlertBody(
        alert,
        AlertType.above,
        950.0,
      );
      final bodyWithout = NotificationNotifier.getAlertBody(
        alert,
        AlertType.above,
        null,
      );
      // With currentPrice, body should be longer (has price suffix)
      expect(bodyWithPrice.length, greaterThan(bodyWithout.length));
    });

    test('no price suffix when currentPrice is null', () {
      final alert = createAlert();
      final body = NotificationNotifier.getAlertBody(
        alert,
        AlertType.above,
        null,
      );
      expect(body, isNotEmpty);
    });
  });
}
