import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTestStock() async {
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
  }

  group('DayTradingDao', () {
    setUp(() async {
      await insertTestStock();
    });

    group('getDayTradingMapForDate fallback path', () {
      test('回退查詢應取回真正最新一天的資料——不可讓 .day 讀到 UTC 曆日（落後一天迴歸測試）', () async {
        // Bug: getDayTradingMapForDate 在指定日期無資料時，回退查詢
        // 「lookback 視窗內最新一天」。舊實作用 DateTime.parse(latestDateStr)
        // 讀 MAX(date) 的原始文字，未接 .toLocal()，對帶明確 UTC offset 的
        // 本地日期字串（正式環境實際格式）會回傳 isUtc=true 的 DateTime。
        // DateContext.normalize 對此值取 .year/.month/.day 會拿到 UTC 曆日
        // （比本地曆日落後一天），導致後續查詢範圍位移一天——
        // 不是查無資料，而是**靜默查到錯誤（更舊）一天的資料**、當作「最新」
        // 回傳給呼叫端（餵評分用的 Isolate 資料）。
        //
        // 直接用 raw SQL 寫入帶明確 UTC offset 的 ISO-8601 文字，不仰賴執行
        // 機器目前時區，確保本測試在任何時區的 CI runner 上都能穩定重現
        // （GitHub Actions ubuntu-latest 預設 UTC，offset=0 時此 bug 不會
        // 現形）。
        Future<void> insertRaw(String dateText, double ratio) {
          return db.customStatement(
            'INSERT INTO day_trading '
            '(symbol, date, day_trading_ratio) '
            'VALUES (?, ?, ?)',
            ['2330', dateText, ratio],
          );
        }

        // 決策層（7/14）：若 bug 仍在，回退查詢會誤取這天的資料
        await insertRaw('2026-07-14T00:00:00.000 +08:00', 20.0);
        // 真正最新一天（7/15）：正確答案
        await insertRaw('2026-07-15T00:00:00.000 +08:00', 30.0);
        // 更早的裝飾資料，確認不會被誤選
        await insertRaw('2026-07-13T00:00:00.000 +08:00', 10.0);

        // 查詢日（7/16）本身無資料 → 觸發回退路徑
        // （dayTradingFallbackDays=5，回溯視窗涵蓋 7/11~7/17，三筆裝飾資料皆在窗內）
        final result = await db.getDayTradingMapForDate(DateTime(2026, 7, 16));

        expect(
          result['2330'],
          30.0,
          reason:
              '回退查詢應取回真正最新一天（7/15=30.0）的資料，'
              '而非因 UTC 曆日誤讀而拿到落後一天（7/14=20.0）的資料',
        );
      });

      test('指定日期本身有資料時不觸發回退，直接回傳當日資料', () async {
        await db.insertDayTradingData([
          DayTradingCompanion.insert(
            symbol: '2330',
            date: DateTime(2026, 7, 16),
            dayTradingRatio: const Value(99.0),
          ),
        ]);

        final result = await db.getDayTradingMapForDate(DateTime(2026, 7, 16));

        expect(result['2330'], 99.0);
      });

      test('回溯視窗外無資料時回傳空 map', () async {
        final result = await db.getDayTradingMapForDate(DateTime(2026, 7, 16));

        expect(result, isEmpty);
      });
    });
  });
}
