// 當沖寫入的 delete window 邊界（真 in-memory DB）
//
// syncAllDayTradingFromTwse 寫入前會先刪除目標日附近的舊列（清理歷史上
// UTC/本地時間不一致造成的同日變體時間戳）。這個窗**絕不能碰到鄰日的
// 本地午夜**：2026-07-14 實戰事故——AfterHours 誤設 36 使窗涵蓋 X+1 00:00，
// 回補歷史日 X 時把 X+1 整天刪光；缺漏日因此沿日曆往前遷移、永不收斂。
// 每日路徑只寫「今天」（隔天必為空），所以此 bug 潛伏期間無症狀，
// 直到回補開始寫歷史日才引爆。mock DB 的 repo 測試擋不住這類刪除副作用，
// 故本檔用 AppDatabase.forTesting() 直接驗 DB 終態。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/tpex_client.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/data/repositories/trading_repository.dart';

class MockTwseClient extends Mock implements TwseClient {}

class MockTpexClient extends Mock implements TpexClient {}

void main() {
  late AppDatabase db;
  late MockTwseClient mockTwse;
  late TradingRepository repo;

  final dayX = DateTime(2026, 7, 7); // 回補目標日
  final dayBefore = DateTime(2026, 7, 6); // X−1（既有完整資料）
  final dayAfter = DateTime(2026, 7, 8); // X+1（既有完整資料）

  DayTradingCompanion entry(String symbol, DateTime date) =>
      DayTradingCompanion.insert(
        symbol: symbol,
        date: date,
        buyVolume: const Value(1000),
        sellVolume: const Value(800),
        dayTradingRatio: const Value(25.0),
        tradeVolume: const Value(5000),
      );

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
    ]);

    mockTwse = MockTwseClient();
    when(
      () => mockTwse.getAllDayTradingData(date: any(named: 'date')),
    ).thenAnswer(
      (_) async => [
        TwseDayTrading(
          date: dayX,
          code: '2330',
          name: '台積電',
          buyVolume: 100000,
          sellVolume: 90000,
          totalVolume: 3000,
          ratio: 0,
        ),
      ],
    );

    repo = TradingRepository(
      database: db,
      twseClient: mockTwse,
      tpexClient: MockTpexClient(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('回補日 X 的寫入不得刪除 X+1 / X−1 的既有當沖資料', () async {
    await db.insertDayTradingData([
      entry('2330', dayBefore),
      entry('2317', dayBefore),
      entry('2330', dayAfter),
      entry('2317', dayAfter),
    ]);

    final written = await repo.syncAllDayTradingFromTwse(
      date: dayX,
      force: true,
    );

    expect(written, 1);
    expect(await db.getDayTradingCountForDate(dayX), 1);
    expect(
      await db.getDayTradingCountForDate(dayAfter),
      2,
      reason:
          'delete window 若涵蓋 X+1 的本地午夜，回補歷史日會把隔天整天刪光'
          '（缺漏日沿日曆往前遷移、永不收斂）',
    );
    expect(
      await db.getDayTradingCountForDate(dayBefore),
      2,
      reason: 'delete window 同樣不得涵蓋 X−1 的本地午夜',
    );
  });

  test('同日內的變體時間戳仍被 dedup 清除（保留原設計意圖）', () async {
    // 歷史 UTC 誤存變體：同一天但時間戳不在午夜
    await db.insertDayTradingData([
      entry('2317', dayX.add(const Duration(hours: 8))),
    ]);

    await repo.syncAllDayTradingFromTwse(date: dayX, force: true);

    // 變體被清、只剩本次寫入的一筆（2330）
    expect(await db.getDayTradingCountForDate(dayX), 1);
    final history = await db.getDayTradingHistory('2317', startDate: dayBefore);
    expect(history, isEmpty, reason: '2317 的同日變體時間戳應被 dedup 刪除');
  });
}
