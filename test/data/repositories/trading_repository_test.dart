import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/trading_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

void main() {
  late MockAppDatabase mockDb;
  late MockTwseClient mockTwse;
  late MockTpexClient mockTpex;
  late TradingRepository repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockTwse = MockTwseClient();
    mockTpex = MockTpexClient();
    repo = TradingRepository(
      database: mockDb,
      twseClient: mockTwse,
      tpexClient: mockTpex,
    );
  });

  // ==========================================
  // Delegation
  // ==========================================
  group('delegation', () {
    test('getLatestDayTrading delegates to db and returns result', () async {
      when(
        () => mockDb.getLatestDayTrading(any()),
      ).thenAnswer((_) async => null);

      final result = await repo.getLatestDayTrading('2330');

      expect(result, isNull);
      verify(() => mockDb.getLatestDayTrading('2330')).called(1);
    });

    test('getLatestMarginTrading delegates to db and returns result', () async {
      when(
        () => mockDb.getLatestMarginTrading(any()),
      ).thenAnswer((_) async => null);

      final result = await repo.getLatestMarginTrading('2330');

      expect(result, isNull);
      verify(() => mockDb.getLatestMarginTrading('2330')).called(1);
    });
  });
}
