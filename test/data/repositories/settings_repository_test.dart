import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/models/finmind/settings_keys.dart';
import 'package:afterclose/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late MockAppDatabase mockDb;
  late SettingsRepository repository;

  setUp(() {
    mockDb = MockAppDatabase();
    repository = SettingsRepository(database: mockDb);
  });

  // ==========================================
  // 最後更新時間
  // ==========================================
  group('getLastUpdateDate', () {
    test('returns parsed DateTime when valid ISO string', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.lastUpdateDate),
      ).thenAnswer((_) async => '2025-01-15T10:30:00.000');

      final result = await repository.getLastUpdateDate();

      expect(result, equals(DateTime(2025, 1, 15, 10, 30)));
    });

    test('returns null when setting not found', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.lastUpdateDate),
      ).thenAnswer((_) async => null);

      final result = await repository.getLastUpdateDate();

      expect(result, isNull);
    });

    test('returns null when value is not valid ISO string', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.lastUpdateDate),
      ).thenAnswer((_) async => 'not-a-date');

      final result = await repository.getLastUpdateDate();

      expect(result, isNull);
    });
  });

  group('setLastUpdateDate', () {
    test('stores date as ISO 8601 string', () async {
      when(() => mockDb.setSetting(any(), any())).thenAnswer((_) async {});

      final date = DateTime(2025, 1, 15, 10, 30);
      await repository.setLastUpdateDate(date);

      verify(
        () => mockDb.setSetting(
          SettingsKeys.lastUpdateDate,
          date.toIso8601String(),
        ),
      ).called(1);
    });
  });

  // ==========================================
  // 功能開關
  // ==========================================
  group('shouldFetchInstitutional', () {
    test('returns true when value is "true"', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.fetchInstitutional),
      ).thenAnswer((_) async => 'true');

      final result = await repository.shouldFetchInstitutional();

      expect(result, isTrue);
    });

    test('returns false when value is "false"', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.fetchInstitutional),
      ).thenAnswer((_) async => 'false');

      final result = await repository.shouldFetchInstitutional();

      expect(result, isFalse);
    });

    test('returns false when value is null (default off)', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.fetchInstitutional),
      ).thenAnswer((_) async => null);

      final result = await repository.shouldFetchInstitutional();

      expect(result, isFalse);
    });
  });

  group('setFetchInstitutional', () {
    test('stores boolean as string', () async {
      when(() => mockDb.setSetting(any(), any())).thenAnswer((_) async {});

      await repository.setFetchInstitutional(true);

      verify(
        () => mockDb.setSetting(SettingsKeys.fetchInstitutional, 'true'),
      ).called(1);
    });
  });

  group('shouldFetchNews', () {
    test('returns true when value is "true"', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.fetchNews),
      ).thenAnswer((_) async => 'true');

      final result = await repository.shouldFetchNews();

      expect(result, isTrue);
    });

    test('returns true when value is null (default on)', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.fetchNews),
      ).thenAnswer((_) async => null);

      final result = await repository.shouldFetchNews();

      // 預設為 true（與 fetchInstitutional 不同）
      expect(result, isTrue);
    });

    test('returns false only when value is "false"', () async {
      when(
        () => mockDb.getSetting(SettingsKeys.fetchNews),
      ).thenAnswer((_) async => 'false');

      final result = await repository.shouldFetchNews();

      expect(result, isFalse);
    });
  });

  group('setFetchNews', () {
    test('stores boolean as string', () async {
      when(() => mockDb.setSetting(any(), any())).thenAnswer((_) async {});

      await repository.setFetchNews(false);

      verify(
        () => mockDb.setSetting(SettingsKeys.fetchNews, 'false'),
      ).called(1);
    });
  });

  // ==========================================
  // 通用設定存取
  // ==========================================
  group('generic settings', () {
    test('getSetting delegates to database', () async {
      when(
        () => mockDb.getSetting('my_key'),
      ).thenAnswer((_) async => 'my_value');

      final result = await repository.getSetting('my_key');

      expect(result, equals('my_value'));
      verify(() => mockDb.getSetting('my_key')).called(1);
    });

    test('setSetting delegates to database', () async {
      when(() => mockDb.setSetting(any(), any())).thenAnswer((_) async {});

      await repository.setSetting('my_key', 'my_value');

      verify(() => mockDb.setSetting('my_key', 'my_value')).called(1);
    });

    test('deleteSetting delegates to database', () async {
      when(() => mockDb.deleteSetting(any())).thenAnswer((_) async {});

      await repository.deleteSetting('my_key');

      verify(() => mockDb.deleteSetting('my_key')).called(1);
    });
  });
}
