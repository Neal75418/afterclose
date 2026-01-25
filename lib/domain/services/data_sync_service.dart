import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 資料同步結果
typedef SyncedDataResult = ({
  DailyPriceEntry? latestPrice,
  List<DailyInstitutionalEntry> institutionalHistory,
  DateTime? dataDate,
  bool hasDataMismatch,
});

/// 確保多來源資料日期一致的服務
///
/// 價格資料和法人資料可能來自不同日期（例如假日後第一天）。
/// 此服務負責找出共同日期，確保顯示的資料是一致的。
class DataSyncService {
  const DataSyncService();

  /// 同步價格與法人資料到相同日期
  ///
  /// 邏輯：
  /// 1. 若任一資料為空，回傳另一個的日期
  /// 2. 若日期相同，直接回傳
  /// 3. 若日期不同，找出共同日期
  /// 4. 若無共同日期，使用較早的日期
  SyncedDataResult synchronizeDataDates(
    List<DailyPriceEntry> priceHistory,
    List<DailyInstitutionalEntry> instHistory,
  ) {
    // 價格資料為空
    if (priceHistory.isEmpty) {
      return (
        latestPrice: null,
        institutionalHistory: instHistory,
        dataDate: instHistory.isNotEmpty ? instHistory.last.date : null,
        hasDataMismatch: false,
      );
    }

    // 法人資料為空
    if (instHistory.isEmpty) {
      final latestPrice = priceHistory.last;
      return (
        latestPrice: latestPrice,
        institutionalHistory: instHistory,
        dataDate: latestPrice.date,
        hasDataMismatch: false,
      );
    }

    // 取得各資料來源的最新日期（正規化以便比較）
    final priceDay = DateContext.normalize(priceHistory.last.date);
    final instDay = DateContext.normalize(instHistory.last.date);

    // 日期相同，無需同步
    if (priceDay == instDay) {
      return (
        latestPrice: priceHistory.last,
        institutionalHistory: instHistory,
        dataDate: priceDay,
        hasDataMismatch: false,
      );
    }

    // 日期不同 - 尋找共同日期
    const hasDataMismatch = true;

    // 建立各資料來源的日期集合
    final priceDates = priceHistory
        .map((p) => DateContext.normalize(p.date))
        .toSet();
    final instDates = instHistory
        .map((i) => DateContext.normalize(i.date))
        .toSet();

    // 尋找共同日期
    final commonDates = priceDates.intersection(instDates);

    if (commonDates.isEmpty) {
      // 無共同日期 - 使用較早的日期
      final dataDate = priceDay.isBefore(instDay) ? priceDay : instDay;

      // 尋找該日期的價格
      final matchingPrice = priceHistory.lastWhere(
        (p) => DateContext.isBeforeOrEqual(p.date, dataDate),
        orElse: () => priceHistory.last,
      );

      return (
        latestPrice: matchingPrice,
        institutionalHistory: instHistory,
        dataDate: dataDate,
        hasDataMismatch: true,
      );
    }

    // 使用最新的共同日期
    final latestCommonDate = commonDates.reduce((a, b) => a.isAfter(b) ? a : b);

    // 尋找該日期的價格
    final matchingPrice = priceHistory.lastWhere(
      (p) => DateContext.normalize(p.date) == latestCommonDate,
      orElse: () => priceHistory.last,
    );

    // 過濾法人資料至該日期
    final syncedInstHistory = instHistory
        .where((i) => DateContext.isBeforeOrEqual(i.date, latestCommonDate))
        .toList();

    return (
      latestPrice: matchingPrice,
      institutionalHistory: syncedInstHistory,
      dataDate: latestCommonDate,
      hasDataMismatch: hasDataMismatch,
    );
  }

  /// 僅取得同步後的資料日期（用於 Scanner/Today 等只需日期的場景）
  ///
  /// 這是 [synchronizeDataDates] 的簡化版本，當你只需要日期而不需要完整資料時使用。
  DateTime? getSyncedDataDate(
    List<DailyPriceEntry> priceHistory,
    List<DailyInstitutionalEntry> instHistory,
  ) {
    return synchronizeDataDates(priceHistory, instHistory).dataDate;
  }

  /// 取得全域顯示用的資料日期
  ///
  /// 用於 Scanner/Today 等批量顯示場景，只有資料庫層級的日期資訊。
  /// 選擇較早的日期作為顯示日期，確保兩種資料都有效。
  ///
  /// 注意：這是簡化邏輯，不保證「共同日期」。
  /// 若需要精確同步，請使用 [synchronizeDataDates]。
  DateTime? getDisplayDataDate(DateTime? priceDate, DateTime? instDate) {
    if (priceDate == null && instDate == null) return null;
    if (priceDate == null) return instDate;
    if (instDate == null) return priceDate;

    // 正規化日期以便比較
    final normalizedPrice = DateContext.normalize(priceDate);
    final normalizedInst = DateContext.normalize(instDate);

    // 回傳較早的日期
    return normalizedPrice.isBefore(normalizedInst)
        ? normalizedPrice
        : normalizedInst;
  }
}
