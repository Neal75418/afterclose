import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:daredevil/data/database/app_database.dart';
import 'package:daredevil/data/models/twse/intraday_quote.dart';
import 'package:daredevil/data/remote/intraday_quote_client.dart';
import 'package:daredevil/domain/services/alert/intraday_alert_monitor.dart';

class MockDb extends Mock implements AppDatabase {}

class MockClient extends Mock implements IntradayQuoteClient {}

/// 盤中提醒監控(2026-08-08)。
///
/// 觸價的語意是「**開始觀察**」不是下單,所以:
/// - 同一筆提醒只叫一次(標記已觸發後不再重複叫)
/// - 觸發後回報觸價快照供 UI/通知使用
/// - 停用中的提醒不參與
void main() {
  setUpAll(() => registerFallbackValue(<String, String>{}));

  late MockDb db;
  late MockClient client;
  late IntradayAlertMonitor monitor;

  PriceAlertEntry alert({
    int id = 1,
    String symbol = '3231',
    String type = 'BELOW',
    double target = 179.95,
    String? note = '跌破10MA',
  }) => PriceAlertEntry(
    id: id,
    symbol: symbol,
    alertType: type,
    targetValue: target,
    isActive: true,
    triggeredAt: null,
    note: note,
    createdAt: DateTime(2026, 8, 8),
  );

  StockMasterEntry stock(String s, String market) => StockMasterEntry(
    symbol: s,
    name: '測試$s',
    market: market,
    industry: 'x',
    isActive: true,
    updatedAt: DateTime(2026, 8, 8),
  );

  IntradayQuote quote(String s, double price, {double prev = 183.5}) =>
      IntradayQuote(symbol: s, name: '測試$s', price: price, previousClose: prev);

  setUp(() {
    db = MockDb();
    client = MockClient();
    monitor = IntradayAlertMonitor(database: db, client: client);
    when(
      () => db.triggerAlert(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
    when(
      () => db.getAllActiveStocks(),
    ).thenAnswer((_) async => [stock('3231', 'TWSE')]);
  });

  test('🚨 跌破目標 → 觸發、標記、回報快照', () async {
    when(() => db.getActiveAlerts()).thenAnswer((_) async => [alert()]);
    when(
      () => client.fetchQuotes(any()),
    ).thenAnswer((_) async => {'3231': quote('3231', 179.5)});

    final fired = await monitor.check();

    expect(fired.length, 1);
    expect(fired.single.alert.id, 1);
    expect(fired.single.quote.price, 179.5);
    verify(() => db.triggerAlert(1, now: any(named: 'now'))).called(1);
  });

  test('未達目標 → 不觸發、不寫 DB', () async {
    when(() => db.getActiveAlerts()).thenAnswer((_) async => [alert()]);
    when(
      () => client.fetchQuotes(any()),
    ).thenAnswer((_) async => {'3231': quote('3231', 181.0)});

    expect(await monitor.check(), isEmpty);
    verifyNever(() => db.triggerAlert(any(), now: any(named: 'now')));
  });

  test('🚨 向上型:突破才觸發', () async {
    when(
      () => db.getActiveAlerts(),
    ).thenAnswer((_) async => [alert(type: 'ABOVE', target: 202.5)]);
    when(
      () => client.fetchQuotes(any()),
    ).thenAnswer((_) async => {'3231': quote('3231', 203.0)});

    expect((await monitor.check()).length, 1);
  });

  test('🚨 已觸發過的不重複叫(語意是開始觀察,不是持續嗶)', () async {
    final done = PriceAlertEntry(
      id: 2,
      symbol: '3231',
      alertType: 'BELOW',
      targetValue: 179.95,
      isActive: true,
      triggeredAt: DateTime(2026, 8, 8, 10),
      note: null,
      createdAt: DateTime(2026, 8, 8),
    );
    when(() => db.getActiveAlerts()).thenAnswer((_) async => [done]);
    when(
      () => client.fetchQuotes(any()),
    ).thenAnswer((_) async => {'3231': quote('3231', 170.0)});

    expect(await monitor.check(), isEmpty);
    verifyNever(() => db.triggerAlert(any(), now: any(named: 'now')));
  });

  test('沒有待監控提醒 → 完全不打 API(省流量也省被限流)', () async {
    when(() => db.getActiveAlerts()).thenAnswer((_) async => []);

    expect(await monitor.check(), isEmpty);
    verifyNever(() => client.fetchQuotes(any()));
  });

  test('🚨 報價缺該檔(停牌/API 漏) → 略過,不當成觸發', () async {
    when(() => db.getActiveAlerts()).thenAnswer((_) async => [alert()]);
    when(() => client.fetchQuotes(any())).thenAnswer((_) async => const {});

    expect(await monitor.check(), isEmpty);
    verifyNever(() => db.triggerAlert(any(), now: any(named: 'now')));
  });

  test('市場別由 stock_master 決定,不從代號猜', () async {
    when(
      () => db.getActiveAlerts(),
    ).thenAnswer((_) async => [alert(symbol: '6538')]);
    when(
      () => db.getAllActiveStocks(),
    ).thenAnswer((_) async => [stock('6538', 'TPEx')]);
    when(() => client.fetchQuotes(any())).thenAnswer((_) async => const {});

    await monitor.check();

    final captured =
        verify(() => client.fetchQuotes(captureAny())).captured.single
            as Map<String, String>;
    expect(captured['6538'], 'TPEx');
  });
}
