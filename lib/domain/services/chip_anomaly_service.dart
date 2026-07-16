import 'package:drift/drift.dart';

import 'package:afterclose/core/constants/chip_scoring_params.dart';
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 籌碼異動類型
enum ChipAnomalyType {
  /// 質押率飆升（>= 70%）
  highPledge,

  /// 內部人轉讓申報
  insiderTransfer,

  /// 外資逼近持股上限（> 上限 × 90%）
  foreignNearLimit,

  /// 融券暴增（當日融券賣出 > 5日均量 × 3，且當日量 ≥ 50 張、均量 ≥ 10 張下限）
  shortSurge,

  /// 法人集中大買/賣（單日淨額 > 30日平均絕對值 × 5）
  institutionalSurge,
}

/// 嚴重度
enum ChipSeverity { high, medium }

/// 單筆籌碼異動
class ChipAnomaly {
  const ChipAnomaly({
    required this.type,
    required this.severity,
    required this.symbol,
    required this.stockName,
    required this.market,
    this.keyValue,
  });

  final ChipAnomalyType type;
  final ChipSeverity severity;
  final String symbol;
  final String stockName;
  final String market;

  /// 關鍵數值（如質押率、張數等）
  final String? keyValue;
}

/// 籌碼異動偵測服務
///
/// 掃描當日市場數據，偵測重大籌碼異動事件。
/// 使用 custom SQL 批次查詢，避免逐檔 N+1 問題。
class ChipAnomalyService {
  ChipAnomalyService({required AppDatabase database}) : _db = database;

  final AppDatabase _db;
  static const String _tag = 'ChipAnomalyService';

  /// 偵測當日籌碼異動，依市場分組回傳
  ///
  /// 每種異動最多回傳 5 筆（避免大量結果淹沒 dashboard）。
  Future<Map<String, List<ChipAnomaly>>> detectAnomaliesByMarket(
    DateTime date,
  ) async {
    final result = <String, List<ChipAnomaly>>{
      MarketCode.twse: [],
      MarketCode.tpex: [],
    };

    try {
      final anomalies = await Future.wait([
        _detectHighPledge(),
        _detectInsiderTransfers(date),
        _detectForeignNearLimit(),
        _detectShortSurge(date),
        _detectInstitutionalSurge(date),
      ]);

      for (final list in anomalies) {
        for (final anomaly in list) {
          result[anomaly.market]?.add(anomaly);
        }
      }

      // 依嚴重度排序：high 在前
      for (final market in result.keys) {
        result[market]!.sort((a, b) {
          final sevCmp = a.severity.index.compareTo(b.severity.index);
          if (sevCmp != 0) return sevCmp;
          return a.type.index.compareTo(b.type.index);
        });
      }
    } catch (e) {
      AppLogger.warning(_tag, '偵測籌碼異動失敗', e);
    }

    return result;
  }

  /// 質押率「變動觸發」：僅在**新**發生時計入，避免持續高於門檻的股票天天
  /// 佔用「今日偵測到 N 項異常」名額（警示疲勞）。
  ///
  /// 「新」定義（兩者擇一，皆須最新質押率 >=
  /// [FundamentalParams.highPledgeRatioThreshold]）：
  /// - 跨門檻：前次快照 < 門檻、最新快照 >= 門檻
  /// - 持續惡化：兩次快照皆 >= 門檻，但漲幅 >=
  ///   [FundamentalParams.kPledgeAlertDeltaPp]
  ///
  /// 該股無前次快照（僅 1 筆歷史）一律不計入（避免首次同步大量歷史資料時
  /// 洗版）。個股層級的持續性顯示（風險徽章、自選清單警示、股票詳情頁）
  /// 不受影響，見 [FundamentalParams.kPledgeAlertDeltaPp] 文件。
  Future<List<ChipAnomaly>> _detectHighPledge() async {
    try {
      const query =
          '''
        WITH ranked AS (
          SELECT ih.symbol, ih.pledge_ratio,
                 ROW_NUMBER() OVER (PARTITION BY ih.symbol ORDER BY ih.date DESC) AS rn
          FROM insider_holding ih
          WHERE ih.pledge_ratio IS NOT NULL
        ),
        latest AS (
          SELECT symbol, pledge_ratio AS latest_ratio FROM ranked WHERE rn = 1
        ),
        previous AS (
          SELECT symbol, pledge_ratio AS prev_ratio FROM ranked WHERE rn = 2
        )
        SELECT l.symbol, l.latest_ratio, s.name, s.market
        FROM latest l
        INNER JOIN previous p ON l.symbol = p.symbol
        INNER JOIN stock_master s ON l.symbol = s.symbol
        WHERE l.latest_ratio >= ?
          AND (p.prev_ratio < ? OR (l.latest_ratio - p.prev_ratio) >= ?)
        ORDER BY l.latest_ratio DESC
        LIMIT ${ChipAnomalyParams.maxResultsPerType}
      ''';

      final rows = await _db
          .customSelect(
            query,
            variables: [
              const Variable<double>(
                FundamentalParams.highPledgeRatioThreshold,
              ),
              const Variable<double>(
                FundamentalParams.highPledgeRatioThreshold,
              ),
              const Variable<double>(FundamentalParams.kPledgeAlertDeltaPp),
            ],
          )
          .get();

      return rows.map((row) {
        final ratio = row.read<double>('latest_ratio');
        final ratioStr = ratio.toStringAsFixed(1);
        return ChipAnomaly(
          type: ChipAnomalyType.highPledge,
          severity: ChipSeverity.high,
          symbol: row.read<String>('symbol'),
          stockName: row.read<String>('name'),
          market: row.read<String>('market'),
          keyValue: '$ratioStr%',
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(_tag, '偵測高質押失敗', e);
      return [];
    }
  }

  /// 內部人轉讓：近 [ChipAnomalyParams.insiderTransferLookbackDays] 天內有申報轉讓記錄
  Future<List<ChipAnomaly>> _detectInsiderTransfers(DateTime date) async {
    try {
      final since = date.subtract(
        const Duration(days: ChipAnomalyParams.insiderTransferLookbackDays),
      );

      const query =
          '''
        WITH ranked AS (
          SELECT it.symbol, it.identity, it.transfer_shares, it.report_date,
                 s.name, s.market,
                 ROW_NUMBER() OVER (PARTITION BY it.symbol ORDER BY it.transfer_shares DESC) AS rn
          FROM insider_transfer it
          INNER JOIN stock_master s ON it.symbol = s.symbol
          WHERE it.report_date >= ?
        )
        SELECT symbol, identity, transfer_shares, report_date, name, market
        FROM ranked WHERE rn = 1
        ORDER BY transfer_shares DESC
        LIMIT ${ChipAnomalyParams.maxResultsPerType}
      ''';

      final rows = await _db
          .customSelect(query, variables: [Variable.withDateTime(since)])
          .get();

      return rows.map((row) {
        final shares = row.read<int>('transfer_shares');
        return ChipAnomaly(
          type: ChipAnomalyType.insiderTransfer,
          severity: ChipSeverity.medium,
          symbol: row.read<String>('symbol'),
          stockName: row.read<String>('name'),
          market: row.read<String>('market'),
          keyValue: _formatInsiderShares(shares),
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(_tag, '偵測內部人轉讓失敗', e);
      return [];
    }
  }

  /// 外資逼近持股上限：持股比 > 上限 × 90%
  Future<List<ChipAnomaly>> _detectForeignNearLimit() async {
    try {
      const query =
          '''
        SELECT sh.symbol, sh.foreign_shares_ratio, sh.foreign_upper_limit_ratio,
               s.name, s.market
        FROM shareholding sh
        INNER JOIN (
          SELECT symbol, MAX(date) as max_date
          FROM shareholding
          GROUP BY symbol
        ) latest ON sh.symbol = latest.symbol AND sh.date = latest.max_date
        INNER JOIN stock_master s ON sh.symbol = s.symbol
        WHERE sh.foreign_upper_limit_ratio IS NOT NULL
          AND sh.foreign_shares_ratio IS NOT NULL
          AND sh.foreign_upper_limit_ratio > 0
          AND sh.foreign_shares_ratio >= sh.foreign_upper_limit_ratio * 0.9
        ORDER BY (sh.foreign_shares_ratio / sh.foreign_upper_limit_ratio) DESC
        LIMIT ${ChipAnomalyParams.maxResultsPerType}
      ''';

      final rows = await _db.customSelect(query).get();

      return rows.map((row) {
        final ratio = row.read<double>('foreign_shares_ratio');
        final limit = row.read<double>('foreign_upper_limit_ratio');
        final pct = (ratio / limit * 100).toStringAsFixed(1);
        return ChipAnomaly(
          type: ChipAnomalyType.foreignNearLimit,
          severity: ChipSeverity.medium,
          symbol: row.read<String>('symbol'),
          stockName: row.read<String>('name'),
          market: row.read<String>('market'),
          keyValue: '$pct%',
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(_tag, '偵測外資逼近上限失敗', e);
      return [];
    }
  }

  /// 融券暴增：當日融券賣出 > 近 5 日均融券賣出 × [ChipAnomalyParams.shortSurgeMultiplier]
  ///
  /// 絕對量下限採雙路徑避免近零基期假訊號、同時救回冷基期突發建空：
  /// - 標準路徑：當日量 ≥ [ChipAnomalyParams.shortSurgeMinTodayLots] 張
  ///   且 5 日均量 ≥ [ChipAnomalyParams.shortSurgeMinAvgLots] 張
  /// - 高量豁免：當日量 ≥ [ChipAnomalyParams.shortSurgeHighVolTodayLots] 張時，
  ///   均量地板放寬到 [ChipAnomalyParams.shortSurgeHighVolMinAvgLots] 張
  /// avg5d 一律先以最低均量地板（HighVolMinAvgLots=3 張）HAVING 預過濾，排除近零
  /// 基期爆值（如 3528 均 0.333 張的 687 倍噪音）。
  Future<List<ChipAnomaly>> _detectShortSurge(DateTime date) async {
    try {
      final dateLowerBound = date.subtract(
        const Duration(days: ChipAnomalyParams.shortSurgeLookbackDays),
      );
      final disposalLookback = date.subtract(
        const Duration(days: ChipAnomalyParams.disposalExclusionLookbackDays),
      );

      const query =
          '''
        WITH recent AS (
          SELECT mt.symbol, mt.date, mt.short_sell,
                 s.name, s.market,
                 ROW_NUMBER() OVER (PARTITION BY mt.symbol ORDER BY mt.date DESC) AS rn
          FROM margin_trading mt
          INNER JOIN stock_master s ON mt.symbol = s.symbol
          WHERE mt.date <= ? AND mt.date >= ? AND mt.short_sell IS NOT NULL
        ),
        today AS (
          SELECT symbol, name, market, short_sell
          FROM recent WHERE rn = 1 AND short_sell >= ${ChipAnomalyParams.shortSurgeMinTodayLots}
        ),
        avg5d AS (
          SELECT symbol, AVG(short_sell) AS avg_short
          FROM recent WHERE rn BETWEEN 2 AND 6
          GROUP BY symbol
          HAVING AVG(short_sell) >= ${ChipAnomalyParams.shortSurgeHighVolMinAvgLots}
        )
        SELECT t.symbol, t.name, t.market, t.short_sell, a.avg_short,
               (t.short_sell / a.avg_short) AS ratio
        FROM today t
        INNER JOIN avg5d a ON t.symbol = a.symbol
        WHERE t.short_sell > a.avg_short * ${ChipAnomalyParams.shortSurgeMultiplier}
          AND (
            a.avg_short >= ${ChipAnomalyParams.shortSurgeMinAvgLots}
            OR t.short_sell >= ${ChipAnomalyParams.shortSurgeHighVolTodayLots}
          )
          AND t.symbol NOT IN (
            SELECT symbol FROM trading_warning
            WHERE warning_type = 'DISPOSAL' AND date >= ?
          )
        ORDER BY ratio DESC
        LIMIT ${ChipAnomalyParams.maxResultsPerType}
      ''';

      final rows = await _db
          .customSelect(
            query,
            variables: [
              Variable.withDateTime(date),
              Variable.withDateTime(dateLowerBound),
              Variable.withDateTime(disposalLookback),
            ],
          )
          .get();

      return rows.map((row) {
        final ratio = row.read<double>('ratio');
        return ChipAnomaly(
          type: ChipAnomalyType.shortSurge,
          severity: ChipSeverity.medium,
          symbol: row.read<String>('symbol'),
          stockName: row.read<String>('name'),
          market: row.read<String>('market'),
          keyValue: '${ratio.toStringAsFixed(1)}倍',
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(_tag, '偵測融券暴增失敗', e);
      return [];
    }
  }

  /// 法人集中大買/賣：單日絕對淨額 > 均值 × [ChipAnomalyParams.institutionalSurgeMultiplier]
  ///
  /// 使用倍率門檻替代 Z-score，避免 SQLite 中計算標準差的複雜度。
  Future<List<ChipAnomaly>> _detectInstitutionalSurge(DateTime date) async {
    try {
      final dateLowerBound = date.subtract(
        const Duration(days: ChipAnomalyParams.institutionalSurgeLookbackDays),
      );
      final disposalLookback = date.subtract(
        const Duration(days: ChipAnomalyParams.disposalExclusionLookbackDays),
      );

      const query =
          '''
        WITH recent AS (
          SELECT di.symbol, di.date,
                 COALESCE(di.foreign_net, 0) + COALESCE(di.investment_trust_net, 0) + COALESCE(di.dealer_net, 0) AS total_net,
                 s.name, s.market,
                 ROW_NUMBER() OVER (PARTITION BY di.symbol ORDER BY di.date DESC) AS rn
          FROM daily_institutional di
          INNER JOIN stock_master s ON di.symbol = s.symbol
          WHERE di.date <= ? AND di.date >= ?
        ),
        today AS (
          SELECT symbol, name, market, total_net
          FROM recent WHERE rn = 1 AND ABS(total_net) > 0
        ),
        avg30d AS (
          SELECT symbol, AVG(ABS(total_net)) AS avg_abs_net
          FROM recent WHERE rn BETWEEN 2 AND 31
          GROUP BY symbol
          HAVING COUNT(*) >= 10 AND AVG(ABS(total_net)) > 0
        )
        SELECT t.symbol, t.name, t.market, t.total_net,
               a.avg_abs_net,
               (ABS(t.total_net) / a.avg_abs_net) AS surge_ratio
        FROM today t
        INNER JOIN avg30d a ON t.symbol = a.symbol
        WHERE ABS(t.total_net) > a.avg_abs_net * ${ChipAnomalyParams.institutionalSurgeMultiplier}
          AND t.symbol NOT IN (
            SELECT symbol FROM trading_warning
            WHERE warning_type = 'DISPOSAL' AND date >= ?
          )
        ORDER BY surge_ratio DESC
        LIMIT ${ChipAnomalyParams.maxResultsPerType}
      ''';

      final rows = await _db
          .customSelect(
            query,
            variables: [
              Variable.withDateTime(date),
              Variable.withDateTime(dateLowerBound),
              Variable.withDateTime(disposalLookback),
            ],
          )
          .get();

      return rows.map((row) {
        final totalNet = row.read<double>('total_net');
        final isBuy = totalNet > 0;
        // DB 以「股」為單位，除以 1000 轉換為「張」後格式化
        final formatted = _formatSheets(totalNet.abs() / 1000);
        return ChipAnomaly(
          type: ChipAnomalyType.institutionalSurge,
          severity: ChipSeverity.high,
          symbol: row.read<String>('symbol'),
          stockName: row.read<String>('name'),
          market: row.read<String>('market'),
          keyValue: '${isBuy ? '+' : '-'}$formatted',
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(_tag, '偵測法人集中買賣失敗', e);
      return [];
    }
  }
}

/// 格式化張數（top-level，與 widget 層 _formatAmount 風格一致）
String _formatSheets(double value) {
  final absVal = value.abs();
  if (absVal >= 10000) {
    return '${(absVal / 10000).toStringAsFixed(1)}萬張';
  }
  return '${absVal.toStringAsFixed(0)}張';
}

/// 格式化內部人轉讓股數（股 → 張）
///
/// - shares == 0：申報尚未確定股數，使用 [kZeroInsiderTransfer] 哨兵值
/// - shares 1–999：不足一張，顯示 `<1張`（避免四捨五入誤判為零）
/// - shares ≥ 1000：正常換算為張數
String _formatInsiderShares(int shares) {
  if (shares == 0) return kZeroInsiderTransfer;
  if (shares < 1000) return '<1張';
  final lots = shares ~/ 1000;
  return '$lots張';
}

/// 內部人轉讓「股數為零」的哨兵值
///
/// 由 service 產生、widget 消費，集中定義避免跨層硬編碼字串比對。
const kZeroInsiderTransfer = '0張';
