import 'package:easy_localization/easy_localization.dart';

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
  trend;

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
      'UP' => WatchlistTrend.up,
      'DOWN' => WatchlistTrend.down,
      _ => WatchlistTrend.sideways,
    };
  }

  String get statusIcon => status.icon;
}
