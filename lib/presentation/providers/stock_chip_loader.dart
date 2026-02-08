import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/data/remote/finmind_client.dart';
import 'package:afterclose/data/repositories/insider_repository.dart';
import 'package:afterclose/domain/models/chip_strength.dart';
import 'package:afterclose/domain/services/chip_analysis_service.dart';

/// 完整籌碼資料載入結果
typedef ChipDataResult = ({
  List<DayTradingEntry> dayTrading,
  List<ShareholdingEntry> shareholding,
  List<MarginTradingEntry> marginTrading,
  List<HoldingDistributionEntry> holdingDist,
  List<InsiderHoldingEntry> insider,
  ChipStrengthResult strength,
});

/// 籌碼資料載入器
///
/// 負責從 DB 和 FinMind API 載入法人進出、融資融券、當沖、
/// 持股分布、董監持股等籌碼資料。純資料取得邏輯，不管理 UI 狀態。
class StockChipLoader {
  StockChipLoader({
    required AppDatabase db,
    required FinMindClient finMind,
    required InsiderRepository insiderRepo,
  }) : _db = db,
       _finMind = finMind,
       _insiderRepo = insiderRepo;

  final AppDatabase _db;
  final FinMindClient _finMind;
  final InsiderRepository _insiderRepo;

  /// 從 FinMind API 載入融資融券資料
  ///
  /// 若 API 返回 402 錯誤，靜默跳過（API 不可用）。
  Future<List<FinMindMarginData>> loadMarginFromApi(String symbol) async {
    try {
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 20));

      return await _finMind.getMarginData(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(today),
      );
    } catch (e) {
      if (e.toString().contains('402')) {
        AppLogger.info('StockDetail', '融資融券 API 不可用 (402)，跳過');
      } else {
        AppLogger.warning('StockDetail', '載入融資融券資料失敗: $symbol', e);
      }
      return [];
    }
  }

  /// 從 DB 載入董監持股歷史資料
  Future<List<InsiderHoldingEntry>> loadInsiderFromDb(
    String symbol, {
    int months = 12,
  }) async {
    try {
      final history = await _insiderRepo.getInsiderHoldingHistory(
        symbol,
        months: months,
      );

      // 依日期降序排列（最新在前）
      history.sort((a, b) => b.date.compareTo(a.date));
      return history;
    } catch (e) {
      AppLogger.warning('StockDetail', '載入董監持股資料失敗: $symbol', e);
      return [];
    }
  }

  /// 載入完整籌碼分析資料並計算籌碼強度
  ///
  /// 包含當沖、持股比例、融資融券（DB）、持股集中度、董監持股。
  /// [existingInstitutional] — 已載入的法人歷史（用於籌碼強度計算）
  /// [existingInsider] — 已載入的董監持股（避免重複查詢）
  Future<ChipDataResult> loadAllChipData(
    String symbol, {
    required List<DailyInstitutionalEntry> existingInstitutional,
    List<InsiderHoldingEntry> existingInsider = const [],
  }) async {
    final today = DateTime.now();
    final startDate10d = today.subtract(const Duration(days: 15));
    final startDate60d = today.subtract(const Duration(days: 90));

    // 使用 Records 平行載入所有資料
    final (
      dayTrading,
      shareholding,
      marginTrading,
      holdingDist,
      insider,
    ) = await (
      _db.getDayTradingHistory(symbol, startDate: startDate10d),
      _db.getShareholdingHistory(symbol, startDate: startDate60d),
      _db.getMarginTradingHistory(symbol, startDate: startDate10d),
      _db.getLatestHoldingDistribution(symbol),
      existingInsider.isNotEmpty
          ? Future.value(existingInsider)
          : _db.getRecentInsiderHoldings(symbol, months: 6),
    ).wait;

    // 計算籌碼強度
    const service = ChipAnalysisService();
    final strength = service.compute(
      institutionalHistory: existingInstitutional,
      shareholdingHistory: shareholding,
      marginHistory: marginTrading,
      dayTradingHistory: dayTrading,
      holdingDistribution: holdingDist,
      insiderHistory: insider,
    );

    return (
      dayTrading: dayTrading,
      shareholding: shareholding,
      marginTrading: marginTrading,
      holdingDist: holdingDist,
      insider: insider,
      strength: strength,
    );
  }

  /// 直接從 FinMind API 取得法人資料
  ///
  /// 返回 record 包含資料與錯誤狀態，讓呼叫端能區分「API 失敗」與「真的沒資料」。
  Future<({List<DailyInstitutionalEntry> data, bool hasError})>
  fetchInstitutionalFromApi(String symbol) async {
    try {
      final today = DateTime.now();
      final startDate = today.subtract(const Duration(days: 20));

      final data = await _finMind.getInstitutionalData(
        stockId: symbol,
        startDate: DateContext.formatYmd(startDate),
        endDate: DateContext.formatYmd(today),
      );

      // 轉換為 DailyInstitutionalEntry 格式
      final entries = data.map((item) {
        return DailyInstitutionalEntry(
          symbol: item.stockId,
          date: DateTime.parse(item.date),
          foreignNet: item.foreignNet,
          investmentTrustNet: item.investmentTrustNet,
          dealerNet: item.dealerNet,
        );
      }).toList();

      return (data: entries, hasError: false);
    } catch (e) {
      AppLogger.warning('StockDetail', '取得法人資料失敗: $symbol', e);
      return (data: <DailyInstitutionalEntry>[], hasError: true);
    }
  }
}
