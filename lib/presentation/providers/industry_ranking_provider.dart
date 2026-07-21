import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/domain/models/industry_ranking.dart';
import 'package:afterclose/domain/services/analysis/industry_ranking_service.dart';
import 'package:afterclose/presentation/providers/data_update_epoch_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';

/// 族群排行（今日頁族群 section）
///
/// 全市場 20D 動能中位數 + 外資/投信近 3 交易日方向，動能 DESC 取前
/// [SectorParams.rankingTopN]。純 DB 讀取、無 API 呼叫；資料更新後由
/// [dataUpdateEpochProvider] 觸發重算。
final industryRankingProvider = FutureProvider<List<IndustryRanking>>((
  ref,
) async {
  ref.watch(dataUpdateEpochProvider);

  final db = ref.read(databaseProvider);
  final marketRepo = ref.read(marketDataRepositoryProvider);

  final latestDate = await marketRepo.getLatestDataDate();
  if (latestDate == null) return const [];
  final analysisDate = DateContext.normalize(latestDate);

  final priceHistories = await db.getAllPricesInRange(
    startDate: analysisDate.subtract(
      const Duration(days: SectorParams.rankingHistoryCalendarDays),
    ),
    endDate: analysisDate,
  );

  final stocks = await db.getAllActiveStocks();

  // 法人近 3 交易日：回看 10 日曆天（週末 + 連假 margin）
  final institutional = await db.getAllInstitutionalInRange(
    startDate: analysisDate.subtract(
      const Duration(days: SectorParams.rankingInstitutionalCalendarDays),
    ),
    endDate: analysisDate,
  );

  return IndustryRankingService().rank(
    priceHistories: priceHistories,
    industries: {for (final s in stocks) s.symbol: s.industry},
    names: {for (final s in stocks) s.symbol: s.name},
    institutionalHistories: institutional,
  );
});
