import 'package:flutter_test/flutter_test.dart';

import 'package:afterclose/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  group('Trading Warning Alerts', () {
    setUp(() async {
      // 插入股票主檔
      await db.upsertStocks([
        StockMasterCompanion.insert(
          symbol: '2330',
          name: '台積電',
          market: 'TWSE',
        ),
        StockMasterCompanion.insert(
          symbol: '2331',
          name: '測試股票',
          market: 'TWSE',
        ),
      ]);
    });

    test('TRADING_WARNING triggers when stock has active warnings', () async {
      // 插入警示資料
      await db.insertWarningData([
        TradingWarningCompanion.insert(
          symbol: '2330',
          date: DateTime.now().subtract(const Duration(days: 5)),
          warningType: 'ATTENTION',
        ),
      ]);

      final alertId = await db.createPriceAlert(
        symbol: '2330',
        alertType: 'TRADING_WARNING',
        targetValue: 0.0, // 這個值對 TRADING_WARNING 不重要
      );

      final triggered = await db.checkAlerts({'2330': 500.0}, {'2330': 0.0});

      expect(triggered.length, 1);
      expect(triggered.first.id, alertId);
    });

    test(
      'TRADING_WARNING doesn\'t trigger when stock has no warnings',
      () async {
        await db.createPriceAlert(
          symbol: '2331', // 無警示的股票
          alertType: 'TRADING_WARNING',
          targetValue: 0.0,
        );

        final triggered = await db.checkAlerts({'2331': 500.0}, {'2331': 0.0});

        expect(triggered, isEmpty);
      },
    );

    test('TRADING_WARNING doesn\'t trigger for disposal warnings', () async {
      // 插入處置警示
      await db.insertWarningData([
        TradingWarningCompanion.insert(
          symbol: '2330',
          date: DateTime.now().subtract(const Duration(days: 5)),
          warningType: 'DISPOSAL',
        ),
      ]);

      await db.createPriceAlert(
        symbol: '2330',
        alertType: 'TRADING_WARNING', // 只關注一般警示，不含處置
        targetValue: 0.0,
      );

      final triggered = await db.checkAlerts({'2330': 500.0}, {'2330': 0.0});

      // 應該不觸發，因為 TRADING_WARNING 不包含處置
      expect(triggered, isEmpty);
    });

    test(
      'TRADING_DISPOSAL triggers when stock has disposal warnings',
      () async {
        // 插入處置警示
        await db.insertWarningData([
          TradingWarningCompanion.insert(
            symbol: '2330',
            date: DateTime.now().subtract(const Duration(days: 5)),
            warningType: 'DISPOSAL',
          ),
        ]);

        final alertId = await db.createPriceAlert(
          symbol: '2330',
          alertType: 'TRADING_DISPOSAL',
          targetValue: 0.0,
        );

        final triggered = await db.checkAlerts({'2330': 500.0}, {'2330': 0.0});

        expect(triggered.length, 1);
        expect(triggered.first.id, alertId);
      },
    );

    test(
      'TRADING_DISPOSAL doesn\'t trigger when stock has no disposal',
      () async {
        // 插入一般警示（非處置）
        await db.insertWarningData([
          TradingWarningCompanion.insert(
            symbol: '2330',
            date: DateTime.now().subtract(const Duration(days: 5)),
            warningType: 'ATTENTION',
          ),
        ]);

        await db.createPriceAlert(
          symbol: '2330',
          alertType: 'TRADING_DISPOSAL', // 只關注處置
          targetValue: 0.0,
        );

        final triggered = await db.checkAlerts({'2330': 500.0}, {'2330': 0.0});

        // 應該不觸發，因為只有一般警示，沒有處置
        expect(triggered, isEmpty);
      },
    );

    test(
      'TRADING_DISPOSAL doesn\'t trigger when stock has no warnings',
      () async {
        await db.createPriceAlert(
          symbol: '2331', // 無警示的股票
          alertType: 'TRADING_DISPOSAL',
          targetValue: 0.0,
        );

        final triggered = await db.checkAlerts({'2331': 500.0}, {'2331': 0.0});

        expect(triggered, isEmpty);
      },
    );
  });
}
