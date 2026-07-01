import 'package:easy_localization/easy_localization.dart';

import 'package:afterclose/core/constants/rule_enums.dart';
import 'package:afterclose/presentation/widgets/warning_badge.dart';

// ==================================================
// 自選股排序選項
// ==================================================

/// 自選股排序選項
enum WatchlistSort {
  addedDesc,
  addedAsc,
  scoreDesc,
  scoreAsc,
  priceChangeDesc,
  priceChangeAsc,
  nameAsc;

  String get label =>
      'watchlist.sort${name[0].toUpperCase()}${name.substring(1)}'.tr();
}

// ==================================================
// 自選股分組選項
// ==================================================

/// 自選股分組選項
enum WatchlistGroup {
  none,
  status,
  trend,
  category;

  String get label =>
      'watchlist.group${name[0].toUpperCase()}${name.substring(1)}'.tr();
}

/// 狀態分類（用於分組）
enum WatchlistStatus {
  signal('🔥'),
  volatile('👀'),
  quiet('😴');

  const WatchlistStatus(this.icon);
  final String icon;

  String get label =>
      'watchlist.status${name[0].toUpperCase()}${name.substring(1)}'.tr();
}

/// 趨勢分類（用於分組）
enum WatchlistTrend {
  up('📈'),
  down('📉'),
  sideways('➡️');

  const WatchlistTrend(this.icon);
  final String icon;

  String get label =>
      'watchlist.trend${name[0].toUpperCase()}${name.substring(1)}'.tr();
}

// ==================================================
// 自選股項目資料
// ==================================================

/// 自選股項目資料
class WatchlistItemData {
  const WatchlistItemData({
    required this.symbol,
    this.stockName,
    this.market,
    this.latestClose,
    this.priceChange,
    this.trendState,
    this.score,
    this.hasSignal = false,
    this.addedAt,
    this.recentPrices = const [],
    this.reasons = const [],
    this.warningType,
    this.groupId,
    this.groupName,
  });

  final String symbol;
  final String? stockName;

  /// 市場：'TWSE'（上市）或 'TPEx'（上櫃）
  final String? market;
  final double? latestClose;
  final double? priceChange;
  final String? trendState;
  final double? score;
  final bool hasSignal;
  final DateTime? addedAt;
  final List<double> recentPrices;
  final List<String> reasons;

  /// 警示類型（處置 > 注意 > 高質押），用於顯示警示標記
  final WarningBadgeType? warningType;

  /// 所屬自訂分組 ID（null 代表未分組）
  final int? groupId;

  /// 所屬自訂分組名稱（null 代表未分組）
  final String? groupName;

  /// 取得狀態分類
  WatchlistStatus get status {
    if (hasSignal) return WatchlistStatus.signal;
    if ((priceChange?.abs() ?? 0) >= 3) {
      return WatchlistStatus.volatile;
    }
    return WatchlistStatus.quiet;
  }

  /// 取得趨勢分類
  WatchlistTrend get trend {
    return switch (trendState) {
      TrendState.upCode => WatchlistTrend.up,
      TrendState.downCode => WatchlistTrend.down,
      _ => WatchlistTrend.sideways,
    };
  }

  /// 複製並覆寫部分欄位（主要供分組指定 / 改名 / 刪除時就地更新）
  ///
  /// [clearGroup] 為 true 時把 groupId、groupName 一併設為 null（移出分組）；
  /// 因 groupId/groupName 本身可為 null，無法只靠 `?? this` 區分「不變」與
  /// 「設為 null」，故用此旗標明確表達「清空分組」。
  WatchlistItemData copyWith({
    int? groupId,
    String? groupName,
    bool clearGroup = false,
  }) {
    return WatchlistItemData(
      symbol: symbol,
      stockName: stockName,
      market: market,
      latestClose: latestClose,
      priceChange: priceChange,
      trendState: trendState,
      score: score,
      hasSignal: hasSignal,
      addedAt: addedAt,
      recentPrices: recentPrices,
      reasons: reasons,
      warningType: warningType,
      groupId: clearGroup ? null : (groupId ?? this.groupId),
      groupName: clearGroup ? null : (groupName ?? this.groupName),
    );
  }
}
