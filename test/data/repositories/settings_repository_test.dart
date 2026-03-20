import 'package:afterclose/data/database/app_database.dart';
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
