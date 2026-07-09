import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/domain/services/update/batch_data_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDb extends Mock implements AppDatabase {}

class _MockNewsRepo extends Mock implements NewsRepository {}

void main() {
  late _MockDb db;
  late _MockNewsRepo newsRepo;

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 7, 9));
  });

  setUp(() {
    db = _MockDb();
    newsRepo = _MockNewsRepo();

    when(
      () => db.getPriceHistoryBatch(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => newsRepo.getNewsForStocksBatch(any(), days: any(named: 'days')),
    ).thenAnswer((_) async => {});
    when(
      () => db.getLatestMonthlyRevenuesBatch(any()),
    ).thenAnswer((_) async => {});
    when(() => db.getLatestValuationsBatch(any())).thenAnswer((_) async => {});
    when(
      () =>
          db.getRecentMonthlyRevenueBatch(any(), months: any(named: 'months')),
    ).thenAnswer((_) async => {});
    when(() => db.getDayTradingMapForDate(any())).thenAnswer((_) async => {});
    when(
      () => db.getLatestShareholdingsBatch(any()),
    ).thenAnswer((_) async => {});
    when(
      () => db.getShareholdingsBeforeDateBatch(
        any(),
        beforeDate: any(named: 'beforeDate'),
      ),
    ).thenAnswer((_) async => {});
    when(() => db.getActiveWarningsMapBatch(any())).thenAnswer((_) async => {});
    when(
      () => db.getLatestInsiderHoldingsBatch(any()),
    ).thenAnswer((_) async => {});
    when(() => db.getEPSHistoryBatch(any())).thenAnswer((_) async => {});
    when(() => db.getROEHistoryBatch(any())).thenAnswer((_) async => {});
    when(() => db.getDividendHistoryBatch(any())).thenAnswer((_) async => {});
    when(() => db.getMaxRevenueBatch(any())).thenAnswer((_) async => {});
  });

  test('價格載入窗口必須與 syncer 充足性判斷窗（historyRequiredDays）同源', () async {
    // 回歸背景：loader 原用 lookbackPrice + 10（380 日曆日）、syncer 判斷
    // 「夠不夠」用 historyRequiredDays（400 日曆日）。2330 在 400 天窗有
    // 261 個交易日（syncer 判定夠、不回補），380 天窗只切出 247 個
    // → 52 週規則（需 250）對幾乎全市場長期「資料不足 (247/250)」。
    // 兩窗同源後此縫隙不再存在。
    final loader = BatchDataLoader(database: db, newsRepository: newsRepo);
    final date = DateTime(2026, 7, 9);

    await loader.loadBatchData(date, ['2330']);

    final captured = verify(
      () => db.getPriceHistoryBatch(
        any(),
        startDate: captureAny(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).captured;
    final startDate = captured.first as DateTime;

    expect(
      date.difference(startDate).inDays,
      RuleParams.historyRequiredDays,
      reason:
          '價格窗口與 historyRequiredDays 不同源，52 週規則會再次陷入'
          '「syncer 判定夠、規則拿不到」的縫隙',
    );
  });
}
