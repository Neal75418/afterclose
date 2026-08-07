// 基本面「最新值」查詢的 as-of 上界
//
// `batch_data_loader` 對估值 / 月營收 / 外資持股 / EPS / ROE 的查詢完全不帶
// 日期，而 DAO 內是全域 `MAX(date)` 無上界。對照組：`tool/replay_calibrator`
// 明確做 point-in-time 過濾（`!revenueVisibleDate(e.date).isAfter(currentDate)`），
// 證明專案知道正解，只是知識停在 tool 端沒擴散到 runtime。
//
// 今日無危害（實測正式 DB：四張基本面表**沒有任何一列**日期超前最新價格
// 日；且 production 呼叫端都不帶 forDate，`targetDate = forDate ?? now()`）。
// 但它是前置條件而非純防禦——若要把歷史重放進 `daily_reason`（`daily_reason`
// 現僅 8 天的解法），沒有 as-of 上界的重放會被超前資料整批污染，而那批列
// 正是 `rule_accuracy` 的輸入。
//
// 日期比較走 `Variable.withDateTime`（`storeDateTimeAsText: true`），與
// day_trading_dao / margin_trading_dao 既有的 raw SQL 區間比較同一慣例；
// 不可手動拼字串比較（帶時區偏移的 ISO 字串字典序不安全）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:daredevil/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  final past = DateTime(2026, 7, 10);
  final future = DateTime(2026, 7, 24);

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.upsertStocks([
      StockMasterCompanion.insert(symbol: '2330', name: '台積電', market: 'TWSE'),
    ]);
  });

  tearDown(() async => db.close());

  test('🚨 估值：asOf 之後的列不得被當成「最新」', () async {
    await db.insertValuationData([
      StockValuationCompanion.insert(
        symbol: '2330',
        date: past,
        per: const Value(10),
      ),
      StockValuationCompanion.insert(
        symbol: '2330',
        date: future,
        per: const Value(99),
      ),
    ]);

    final asOfPast = await db.getLatestValuationsBatch(['2330'], asOf: past);
    expect(asOfPast['2330']!.per, 10, reason: '評分 7/10 時不得看到 7/24 才有的估值');

    final unbounded = await db.getLatestValuationsBatch(['2330']);
    expect(unbounded['2330']!.per, 99, reason: '省略 asOf 維持原本的全域最新語意');
  });

  test('🚨 月營收：asOf 之後的列不得被當成「最新」', () async {
    await db.insertMonthlyRevenue([
      MonthlyRevenueCompanion.insert(
        symbol: '2330',
        date: past,
        revenueYear: 2026,
        revenueMonth: 6,
        revenue: 100,
      ),
      MonthlyRevenueCompanion.insert(
        symbol: '2330',
        date: future,
        revenueYear: 2026,
        revenueMonth: 7,
        revenue: 999,
      ),
    ]);

    final asOfPast = await db.getLatestMonthlyRevenuesBatch([
      '2330',
    ], asOf: past);
    expect(asOfPast['2330']!.revenue, 100);

    final unbounded = await db.getLatestMonthlyRevenuesBatch(['2330']);
    expect(unbounded['2330']!.revenue, 999);
  });

  test('🚨 外資持股：asOf 之後的列不得被當成「最新」', () async {
    await db.insertShareholdingData([
      ShareholdingCompanion.insert(
        symbol: '2330',
        date: past,
        foreignSharesRatio: const Value(30),
      ),
      ShareholdingCompanion.insert(
        symbol: '2330',
        date: future,
        foreignSharesRatio: const Value(70),
      ),
    ]);

    final asOfPast = await db.getLatestShareholdingsBatch(['2330'], asOf: past);
    expect(asOfPast['2330']!.foreignSharesRatio, 30);

    final unbounded = await db.getLatestShareholdingsBatch(['2330']);
    expect(unbounded['2330']!.foreignSharesRatio, 70);
  });

  test('asOf 等於資料日期時該列須被包含（邊界為閉區間）', () async {
    await db.insertValuationData([
      StockValuationCompanion.insert(
        symbol: '2330',
        date: past,
        per: const Value(10),
      ),
    ]);

    final onBoundary = await db.getLatestValuationsBatch(['2330'], asOf: past);
    expect(onBoundary['2330']!.per, 10, reason: 'date <= asOf，非 <');
  });

  test('🚨 董監持股：asOf 之後的列不得被當成「最新」(2026-08-01 同型補掃)', () async {
    // 2026-07-26 為估值/月營收/外資持股補 as-of 上界時漏掃的第四個同型
    // 「最新值」查詢——與其餘三個一樣直接餵 batch_data_loader 的評分路徑。
    await db.insertInsiderHoldingData([
      InsiderHoldingCompanion.insert(
        symbol: '2330',
        date: past,
        insiderRatio: const Value(20),
      ),
      InsiderHoldingCompanion.insert(
        symbol: '2330',
        date: future,
        insiderRatio: const Value(99),
      ),
    ]);

    final asOfPast = await db.getLatestInsiderHoldingsBatch([
      '2330',
    ], asOf: past);
    expect(
      asOfPast['2330']!.insiderRatio,
      20,
      reason: '評分 7/10 時不得看到 7/24 的持股',
    );

    final unbounded = await db.getLatestInsiderHoldingsBatch(['2330']);
    expect(unbounded['2330']!.insiderRatio, 99, reason: '省略 asOf 維持原語意');
  });
}
