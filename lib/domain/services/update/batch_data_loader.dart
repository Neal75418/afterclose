import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/data/repositories/institutional_repository.dart';
import 'package:afterclose/data/repositories/news_repository.dart';
import 'package:afterclose/data/repositories/shareholding_repository.dart';
import 'package:afterclose/domain/models/scoring_batch_data.dart';
import 'package:afterclose/domain/services/update/batch_data_builder.dart';

/// 評分用批次資料載入器
///
/// 平行載入 14+ 個 DB 查詢，組裝為 [ScoringBatchData]
/// 供 Isolate 評分使用。從 UpdateService 提取以降低複雜度。
class BatchDataLoader {
  BatchDataLoader({
    required AppDatabase database,
    required NewsRepository newsRepository,
    InstitutionalRepository? institutionalRepository,
    ShareholdingRepository? shareholdingRepository,
    InsiderRepository? insiderRepository,
  }) : _db = database,
       _newsRepo = newsRepository,
       _institutionalRepo = institutionalRepository,
       _shareholdingRepo = shareholdingRepository,
       _insiderRepo = insiderRepository;

  final AppDatabase _db;
  final NewsRepository _newsRepo;
  final InstitutionalRepository? _institutionalRepo;
  final ShareholdingRepository? _shareholdingRepo;
  final InsiderRepository? _insiderRepo;

  /// 平行載入所有評分所需的批次資料
  ///
  /// 同時啟動 14+ 個 DB 查詢，使用 Dart 3 Record 解構等待，
  /// 再將原始資料轉換為 Isolate 可用的 Map 格式。
  Future<ScoringBatchData> loadBatchData(
    DateTime date,
    List<String> candidates,
  ) async {
    final startDate = date.subtract(
      const Duration(days: RuleParams.lookbackPrice + 10),
    );
    final instStartDate = date.subtract(
      const Duration(days: RuleParams.institutionalLookbackDays),
    );

    final instRepo = _institutionalRepo;

    // 同時啟動所有批次查詢（所有 Future 在建立時即開始並行執行）
    final pricesFuture = _db.getPriceHistoryBatch(
      candidates,
      startDate: startDate,
      endDate: date,
    );
    final newsFuture = _newsRepo.getNewsForStocksBatch(candidates, days: 2);
    final instFuture = instRepo != null
        ? _db.getInstitutionalHistoryBatch(
            candidates,
            startDate: instStartDate,
            endDate: date,
          )
        : Future.value(<String, List<DailyInstitutionalEntry>>{});
    final revenueFuture = _db.getLatestMonthlyRevenuesBatch(candidates);
    final valuationFuture = _db.getLatestValuationsBatch(candidates);
    final revenueHistoryFuture = _db.getRecentMonthlyRevenueBatch(
      candidates,
      months: 6,
    );
    final dayTradingFuture = _db.getDayTradingMapForDate(date);
    final shareholdingFuture = _db.getLatestShareholdingsBatch(candidates);
    final prevShareholdingFuture = _db.getShareholdingsBeforeDateBatch(
      candidates,
      beforeDate: date.subtract(
        const Duration(days: RuleParams.foreignShareholdingLookbackDays),
      ),
    );
    final warningFuture = _db.getActiveWarningsMapBatch(candidates);
    final insiderFuture = _db.getLatestInsiderHoldingsBatch(candidates);
    final epsFuture = _db.getEPSHistoryBatch(candidates);
    final roeFuture = _db.getROEHistoryBatch(candidates);
    final dividendFuture = _db.getDividendHistoryBatch(candidates);

    // 型別安全的並行等待（Dart 3 Record 解構）
    final (pricesMap, newsMap, institutionalMap) = await (
      pricesFuture,
      newsFuture,
      instFuture,
    ).wait;
    final (
      revenueMap,
      valuationMap,
      revenueHistoryMap,
      dayTradingMap,
      shareholdingEntries,
    ) = await (
      revenueFuture,
      valuationFuture,
      revenueHistoryFuture,
      dayTradingFuture,
      shareholdingFuture,
    ).wait;
    final (
      prevShareholdingEntries,
      warningEntries,
      insiderEntries,
      epsHistoryMap,
      roeHistoryMap,
      dividendHistoryMap,
    ) = await (
      prevShareholdingFuture,
      warningFuture,
      insiderFuture,
      epsFuture,
      roeFuture,
      dividendFuture,
    ).wait;

    // 批次載入籌碼集中度（TDCC 股權分散表）
    final concentrationMap = _shareholdingRepo != null
        ? await _shareholdingRepo.getConcentrationRatioBatch(candidates)
        : <String, double>{};

    // 轉換為 Isolate 可用的 Map 格式
    final shareholdingMap = BatchDataBuilder.buildShareholdingMap(
      shareholdingEntries,
      prevShareholdingEntries,
      concentrationMap,
    );

    final warningMap = warningEntries.map(
      (k, v) => MapEntry(k, {
        'warningType': v.warningType,
        'reasonDescription': v.reasonDescription,
        'disposalMeasures': v.disposalMeasures,
        'disposalEndDate': v.disposalEndDate?.toIso8601String(),
      }),
    );

    final insiderMap = await BatchDataBuilder.buildInsiderMap(
      insiderEntries,
      candidates,
      _insiderRepo,
    );

    return ScoringBatchData(
      pricesMap: pricesMap,
      newsMap: newsMap,
      institutionalMap: institutionalMap,
      revenueMap: revenueMap,
      valuationMap: valuationMap,
      revenueHistoryMap: revenueHistoryMap,
      epsHistoryMap: epsHistoryMap,
      roeHistoryMap: roeHistoryMap,
      dividendHistoryMap: dividendHistoryMap,
      dayTradingMap: dayTradingMap,
      shareholdingMap: shareholdingMap,
      warningMap: warningMap,
      insiderMap: insiderMap,
    );
  }
}
