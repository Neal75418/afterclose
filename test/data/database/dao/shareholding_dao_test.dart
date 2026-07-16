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

  group('ShareholdingDao', () {
    setUp(() async {
      await insertTestStock();
    });

    group('getLatestShareholdingsBatch', () {
      test('.date 應還原本地曆日——不可讓 .day 讀到 UTC 曆日（落後一天迴歸測試）', () async {
        // 同型 bug：customSelect('SELECT s.*...') + DateTime.parse(row.read
        // <String>('date')) 繞過 drift 內建型別化轉換。對帶明確 UTC offset
        // 的字串（本地日期一律如此、正式環境實際格式）會回傳 isUtc=true，
        // 直接讀 .day/.month 會拿到 UTC 曆日、比本地曆日落後一天。
        //
        // 目前掃過的下游消費點（buildShareholdingMap 僅讀
        // foreignSharesRatio；market_data_updater 的新鮮度檢查用
        // .isBefore，屬絕對時刻比較、不受 isUtc 影響）都不會被此 bug
        // 觸發成可觀察的錯誤結果——這是「未爆彈」而非目前已知的功能性
        // 錯誤，但欄位本身回傳錯誤曆日仍是資料正確性缺陷，比照融資融券
        // 同型 bug 的修法一併修正，避免未來新增消費點時複製既有錯誤模式。
        //
        // 直接用 raw SQL 寫入字面 offset，不仰賴執行機器目前時區，確保本
        // 測試在任何時區的 CI runner 上都能穩定重現。
        const rawDateText = '2026-07-15T00:00:00.000 +08:00';
        await db.customStatement(
          'INSERT INTO shareholding '
          '(symbol, date, foreign_remaining_shares, foreign_shares_ratio, '
          'foreign_upper_limit_ratio, shares_issued) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          ['2330', rawDateText, 1000000.0, 25.5, 100.0, 5000000.0],
        );

        final result = await db.getLatestShareholdingsBatch(['2330']);
        final date = result['2330']?.date;

        expect(date, isNotNull);
        expect(
          date!.isUtc,
          isFalse,
          reason:
              '應如 QueryRow.read<DateTime>（drift 內建型別化路徑）一樣 '
              '.toLocal() 轉換，否則 .day 會讀到 UTC 曆日、比本地曆日落後一天',
        );
        expect(date, DateTime.parse(rawDateText).toLocal());
        // 數值欄位應正常帶出（確認修法沒有動到其他欄位）
        expect(result['2330']?.foreignSharesRatio, 25.5);
      });

      test('取得每檔股票各自最新一筆（依 symbol 分組）', () async {
        await db.upsertStocks([
          StockMasterCompanion.insert(
            symbol: '2317',
            name: '鴻海',
            market: 'TWSE',
          ),
        ]);
        await db.insertShareholdingData([
          ShareholdingCompanion.insert(
            symbol: '2330',
            date: DateTime(2026, 7, 14),
            foreignSharesRatio: const Value(10.0),
          ),
          ShareholdingCompanion.insert(
            symbol: '2330',
            date: DateTime(2026, 7, 15),
            foreignSharesRatio: const Value(20.0),
          ),
          ShareholdingCompanion.insert(
            symbol: '2317',
            date: DateTime(2026, 7, 15),
            foreignSharesRatio: const Value(30.0),
          ),
        ]);

        final result = await db.getLatestShareholdingsBatch(['2330', '2317']);

        expect(
          result['2330']?.foreignSharesRatio,
          20.0,
          reason: '應取最新一筆(7/15)而非7/14',
        );
        expect(result['2317']?.foreignSharesRatio, 30.0);
      });

      test('symbols 為空時回傳空 map', () async {
        final result = await db.getLatestShareholdingsBatch([]);
        expect(result, isEmpty);
      });
    });

    group('getShareholdingsBeforeDateBatch', () {
      test('.date 應還原本地曆日（與 getLatestShareholdingsBatch 同型修法）', () async {
        const rawDateText = '2026-07-15T00:00:00.000 +08:00';
        await db.customStatement(
          'INSERT INTO shareholding '
          '(symbol, date, foreign_remaining_shares, foreign_shares_ratio, '
          'foreign_upper_limit_ratio, shares_issued) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          ['2330', rawDateText, 1000000.0, 25.5, 100.0, 5000000.0],
        );

        final result = await db.getShareholdingsBeforeDateBatch([
          '2330',
        ], beforeDate: DateTime(2026, 7, 20));
        final date = result['2330']?.date;

        expect(date, isNotNull);
        expect(date!.isUtc, isFalse);
        expect(date, DateTime.parse(rawDateText).toLocal());
      });

      test('只取 beforeDate 之前最接近的一筆', () async {
        await db.insertShareholdingData([
          ShareholdingCompanion.insert(
            symbol: '2330',
            date: DateTime(2026, 7, 10),
            foreignSharesRatio: const Value(15.0),
          ),
          ShareholdingCompanion.insert(
            symbol: '2330',
            date: DateTime(2026, 7, 14),
            foreignSharesRatio: const Value(18.0),
          ),
          // beforeDate 當天或之後的資料不應被選入
          ShareholdingCompanion.insert(
            symbol: '2330',
            date: DateTime(2026, 7, 15),
            foreignSharesRatio: const Value(99.0),
          ),
        ]);

        final result = await db.getShareholdingsBeforeDateBatch([
          '2330',
        ], beforeDate: DateTime(2026, 7, 15));

        expect(result['2330']?.foreignSharesRatio, 18.0);
      });
    });
  });
}
