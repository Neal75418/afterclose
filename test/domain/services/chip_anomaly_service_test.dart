import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/chip_anomaly_service.dart';

void main() {
  late AppDatabase db;
  late ChipAnomalyService service;

  final today = DateTime.utc(2025, 6, 15);

  setUp(() {
    db = AppDatabase.forTesting();
    service = ChipAnomalyService(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTestStocks() async {
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '2317', name: '鴻海', market: 'TWSE'),
      StockMasterCompanion.insert(symbol: '6488', name: '環球晶', market: 'TPEx'),
    ]);
  }

  group('ChipAnomalyService', () {
    setUp(() async {
      await insertTestStocks();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 高質押率
    // ─────────────────────────────────────────────────────────────────────────

    group('高質押率偵測', () {
      test('pledge_ratio >= 70 應被偵測', () async {
        await db.insertInsiderHoldingData([
          InsiderHoldingCompanion.insert(
            symbol: '2330',
            date: today,
            pledgeRatio: const Value(75.5),
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any(
            (a) => a.type == ChipAnomalyType.highPledge && a.symbol == '2330',
          ),
          isTrue,
        );
      });

      test('pledge_ratio < 70 不應被偵測', () async {
        await db.insertInsiderHoldingData([
          InsiderHoldingCompanion.insert(
            symbol: '2330',
            date: today,
            pledgeRatio: const Value(45.0),
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any((a) => a.type == ChipAnomalyType.highPledge),
          isFalse,
        );
      });

      test('keyValue 格式化為百分比字串', () async {
        await db.insertInsiderHoldingData([
          InsiderHoldingCompanion.insert(
            symbol: '2330',
            date: today,
            pledgeRatio: const Value(75.5),
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.highPledge,
        );

        expect(anomaly.keyValue, '75.5%');
        expect(anomaly.severity, ChipSeverity.high);
      });

      test('使用最新一筆資料（MAX(date)）', () async {
        // 舊資料低於門檻，新資料超過門檻
        await db.insertInsiderHoldingData([
          InsiderHoldingCompanion.insert(
            symbol: '2330',
            date: today.subtract(const Duration(days: 30)),
            pledgeRatio: const Value(30.0),
          ),
          InsiderHoldingCompanion.insert(
            symbol: '2330',
            date: today,
            pledgeRatio: const Value(80.0),
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any((a) => a.type == ChipAnomalyType.highPledge),
          isTrue,
        );
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 內部人轉讓
    // ─────────────────────────────────────────────────────────────────────────

    group('內部人轉讓偵測', () {
      test('近 30 天內轉讓應被偵測', () async {
        await db.insertInsiderTransfers([
          InsiderTransferCompanion.insert(
            symbol: '2330',
            reportDate: today.subtract(const Duration(days: 10)),
            identity: '董事',
            name: '測試人',
            transferMethod: '一般',
            transferShares: 50000,
            currentHolding: 1000000,
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any(
            (a) =>
                a.type == ChipAnomalyType.insiderTransfer && a.symbol == '2330',
          ),
          isTrue,
        );
      });

      test('超過 30 天前的轉讓不應被偵測', () async {
        await db.insertInsiderTransfers([
          InsiderTransferCompanion.insert(
            symbol: '2330',
            reportDate: today.subtract(const Duration(days: 31)),
            identity: '董事',
            name: '測試人',
            transferMethod: '一般',
            transferShares: 50000,
            currentHolding: 1000000,
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any((a) => a.type == ChipAnomalyType.insiderTransfer),
          isFalse,
        );
      });

      test('transferShares = 0 回傳 kZeroInsiderTransfer（"0張"）', () async {
        await db.insertInsiderTransfers([
          InsiderTransferCompanion.insert(
            symbol: '2330',
            reportDate: today,
            identity: '董事',
            name: '測試人',
            transferMethod: '一般',
            transferShares: 0,
            currentHolding: 1000000,
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.insiderTransfer,
        );

        expect(anomaly.keyValue, kZeroInsiderTransfer);
      });

      test('transferShares 1–999 顯示 "<1張"（不四捨五入為零）', () async {
        await db.insertInsiderTransfers([
          InsiderTransferCompanion.insert(
            symbol: '2330',
            reportDate: today,
            identity: '董事',
            name: '測試人',
            transferMethod: '一般',
            transferShares: 500,
            currentHolding: 1000000,
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.insiderTransfer,
        );

        expect(anomaly.keyValue, '<1張');
      });

      test('transferShares >= 1000 以張數顯示（股 / 1000）', () async {
        await db.insertInsiderTransfers([
          InsiderTransferCompanion.insert(
            symbol: '2330',
            reportDate: today,
            identity: '董事',
            name: '測試人',
            transferMethod: '一般',
            transferShares: 5000, // 5 張
            currentHolding: 1000000,
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.insiderTransfer,
        );

        expect(anomaly.keyValue, '5張');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 外資逼近上限
    // ─────────────────────────────────────────────────────────────────────────

    group('外資逼近上限偵測', () {
      test('持股比 >= 上限 90% 應被偵測', () async {
        await db.insertShareholdingData([
          ShareholdingCompanion.insert(
            symbol: '2330',
            date: today,
            foreignSharesRatio: const Value(72.0), // 72/80 = 90%
            foreignUpperLimitRatio: const Value(80.0),
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any(
            (a) =>
                a.type == ChipAnomalyType.foreignNearLimit &&
                a.symbol == '2330',
          ),
          isTrue,
        );
      });

      test('持股比 < 上限 90% 不應被偵測', () async {
        await db.insertShareholdingData([
          ShareholdingCompanion.insert(
            symbol: '2330',
            date: today,
            foreignSharesRatio: const Value(60.0), // 60/80 = 75%
            foreignUpperLimitRatio: const Value(80.0),
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any(
            (a) => a.type == ChipAnomalyType.foreignNearLimit,
          ),
          isFalse,
        );
      });

      test('keyValue 顯示持股佔上限比例（百分比）', () async {
        await db.insertShareholdingData([
          ShareholdingCompanion.insert(
            symbol: '2330',
            date: today,
            foreignSharesRatio: const Value(76.0), // 76/80 = 95.0%
            foreignUpperLimitRatio: const Value(80.0),
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.foreignNearLimit,
        );

        expect(anomaly.keyValue, '95.0%');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 融券暴增
    // ─────────────────────────────────────────────────────────────────────────

    group('融券暴增偵測', () {
      /// 插入 5 天歷史 + 當日融券資料
      Future<void> insertShortSurgeData({
        required double todayShortSell,
        double historyShortSell = 100.0,
      }) async {
        final historyDays = List.generate(
          5,
          (i) => today.subtract(Duration(days: i + 1)),
        );
        await db.insertMarginTradingData([
          for (final d in historyDays)
            MarginTradingCompanion.insert(
              symbol: '2330',
              date: d,
              shortSell: Value(historyShortSell),
            ),
          MarginTradingCompanion.insert(
            symbol: '2330',
            date: today,
            shortSell: Value(todayShortSell),
          ),
        ]);
      }

      test('當日融券 > 5 日均量 × 3 應被偵測', () async {
        // avg5d = 100，today = 400 > 100 × 3 = 300 ✓
        await insertShortSurgeData(todayShortSell: 400.0);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any(
            (a) => a.type == ChipAnomalyType.shortSurge && a.symbol == '2330',
          ),
          isTrue,
        );
      });

      test('當日融券 <= 5 日均量 × 3 不應被偵測', () async {
        // avg5d = 100，today = 250 <= 100 × 3 = 300 ✗
        await insertShortSurgeData(todayShortSell: 250.0);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any((a) => a.type == ChipAnomalyType.shortSurge),
          isFalse,
        );
      });

      test('keyValue 格式為「N.N倍」', () async {
        // avg5d = 100，today = 400，ratio = 4.0
        await insertShortSurgeData(todayShortSell: 400.0);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.shortSurge,
        );

        expect(anomaly.keyValue, '4.0倍');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 法人集中買賣
    // ─────────────────────────────────────────────────────────────────────────

    group('法人集中買賣偵測', () {
      /// 插入法人資料：historyDays 天歷史 + 當日
      ///
      /// 偵測需 COUNT(*) >= 10（rn 2..31 至少 10 筆）
      Future<void> insertInstitutionalData({
        required double todayNet,
        double historyNet = 1000000.0,
        int historyDays = 11, // ≥ 10 才觸發 HAVING COUNT(*) >= 10
      }) async {
        for (var i = 1; i <= historyDays; i++) {
          await db.insertInstitutionalData([
            DailyInstitutionalCompanion.insert(
              symbol: '2330',
              date: today.subtract(Duration(days: i)),
              foreignNet: Value(historyNet),
              investmentTrustNet: const Value(0.0),
              dealerNet: const Value(0.0),
            ),
          ]);
        }
        await db.insertInstitutionalData([
          DailyInstitutionalCompanion.insert(
            symbol: '2330',
            date: today,
            foreignNet: Value(todayNet),
            investmentTrustNet: const Value(0.0),
            dealerNet: const Value(0.0),
          ),
        ]);
      }

      test('單日淨額 > 30 日均量 × 5 應被偵測', () async {
        // historyAvg = 1,000,000，today = 6,000,000 > 5,000,000 ✓
        await insertInstitutionalData(todayNet: 6000000.0);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any(
            (a) =>
                a.type == ChipAnomalyType.institutionalSurge &&
                a.symbol == '2330',
          ),
          isTrue,
        );
      });

      test('單日淨額 <= 30 日均量 × 5 不應被偵測', () async {
        // historyAvg = 1,000,000，today = 4,000,000 <= 5,000,000 ✗
        await insertInstitutionalData(todayNet: 4000000.0);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any(
            (a) => a.type == ChipAnomalyType.institutionalSurge,
          ),
          isFalse,
        );
      });

      test('大買顯示正號（+）', () async {
        await insertInstitutionalData(todayNet: 6000000.0);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.institutionalSurge,
        );

        expect(anomaly.keyValue, startsWith('+'));
      });

      test('大賣顯示負號（-）', () async {
        await insertInstitutionalData(todayNet: -6000000.0);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.institutionalSurge,
        );

        expect(anomaly.keyValue, startsWith('-'));
      });

      test('keyValue 以張為單位（÷ 1000），非以股為單位', () async {
        // 6,000,000 股 = 6,000 張，不應顯示 6000000
        await insertInstitutionalData(todayNet: 6000000.0);

        final result = await service.detectAnomaliesByMarket(today);
        final anomaly = result['TWSE']!.firstWhere(
          (a) => a.type == ChipAnomalyType.institutionalSurge,
        );

        expect(anomaly.keyValue, contains('6000張'));
        expect(anomaly.keyValue, isNot(contains('6000000')));
      });

      test('歷史筆數不足 10 筆時不觸發（HAVING COUNT(*) >= 10）', () async {
        // 9 天歷史 → COUNT = 9 < 10 → 不觸發
        await insertInstitutionalData(todayNet: 6000000.0, historyDays: 9);

        final result = await service.detectAnomaliesByMarket(today);

        expect(
          result['TWSE']!.any(
            (a) => a.type == ChipAnomalyType.institutionalSurge,
          ),
          isFalse,
        );
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 市場分組
    // ─────────────────────────────────────────────────────────────────────────

    group('市場分組', () {
      test('TWSE 與 TPEx 異動分別歸入各自市場', () async {
        await db.insertInsiderHoldingData([
          InsiderHoldingCompanion.insert(
            symbol: '2330', // TWSE
            date: today,
            pledgeRatio: const Value(80.0),
          ),
          InsiderHoldingCompanion.insert(
            symbol: '6488', // TPEx
            date: today,
            pledgeRatio: const Value(75.0),
          ),
        ]);

        final result = await service.detectAnomaliesByMarket(today);

        expect(result['TWSE']!.any((a) => a.symbol == '2330'), isTrue);
        expect(result['TPEx']!.any((a) => a.symbol == '6488'), isTrue);
        expect(result['TWSE']!.any((a) => a.symbol == '6488'), isFalse);
        expect(result['TPEx']!.any((a) => a.symbol == '2330'), isFalse);
      });

      test('無資料時回傳空列表', () async {
        final result = await service.detectAnomaliesByMarket(today);

        expect(result['TWSE'], isEmpty);
        expect(result['TPEx'], isEmpty);
      });
    });
  });
}
