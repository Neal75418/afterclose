import 'package:drift/drift.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/data/database/app_database.dart';

/// 籌碼異動類型
enum ChipAnomalyType {
  /// 質押率飆升（> 50%）
  highPledge,

  /// 內部人轉讓申報
  insiderTransfer,

  /// 外資逼近持股上限（> 上限 × 90%）
  foreignNearLimit,

  /// 融券暴增（當日融券賣出 > 5日均量 × 3）
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
  static const String _logTag = 'ChipAnomaly';

  /// 偵測當日籌碼異動，依市場分組回傳
  ///
  /// 每種異動最多回傳 5 筆（避免大量結果淹沒 dashboard）。
  Future<Map<String, List<ChipAnomaly>>> detectAnomaliesByMarket(
    DateTime date,
  ) async {
    final result = <String, List<ChipAnomaly>>{'TWSE': [], 'TPEx': []};

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
      AppLogger.warning(_logTag, '偵測籌碼異動失敗: $e');
    }

    return result;
  }

  /// 質押率飆升：最新質押率 > 50%
  Future<List<ChipAnomaly>> _detectHighPledge() async {
    try {
      const query = '''
        SELECT ih.symbol, ih.pledge_ratio, s.name, s.market
        FROM insider_holding ih
        INNER JOIN (
          SELECT symbol, MAX(date) as max_date
          FROM insider_holding
          GROUP BY symbol
        ) latest ON ih.symbol = latest.symbol AND ih.date = latest.max_date
        INNER JOIN stock_master s ON ih.symbol = s.symbol
        WHERE ih.pledge_ratio >= 50
        ORDER BY ih.pledge_ratio DESC
        LIMIT 5
      ''';

      final rows = await _db.customSelect(query).get();

      return rows.map((row) {
        final ratio = row.read<double>('pledge_ratio');
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
      AppLogger.warning(_logTag, '偵測高質押失敗: $e');
      return [];
    }
  }

  /// 內部人轉讓：近 30 天內有申報轉讓記錄
  Future<List<ChipAnomaly>> _detectInsiderTransfers(DateTime date) async {
    try {
      final since = date.subtract(const Duration(days: 30));

      const query = '''
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
        LIMIT 5
      ''';

      final rows = await _db
          .customSelect(query, variables: [Variable.withDateTime(since)])
          .get();

      return rows.map((row) {
        final shares = row.read<int>('transfer_shares');
        final sharesK = (shares / 1000).toStringAsFixed(0);
        return ChipAnomaly(
          type: ChipAnomalyType.insiderTransfer,
          severity: ChipSeverity.medium,
          symbol: row.read<String>('symbol'),
          stockName: row.read<String>('name'),
          market: row.read<String>('market'),
          keyValue: '$sharesK張',
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(_logTag, '偵測內部人轉讓失敗: $e');
      return [];
    }
  }

  /// 外資逼近持股上限：持股比 > 上限 × 90%
  Future<List<ChipAnomaly>> _detectForeignNearLimit() async {
    try {
      const query = '''
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
        LIMIT 5
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
      AppLogger.warning(_logTag, '偵測外資逼近上限失敗: $e');
      return [];
    }
  }

  /// 融券暴增：當日融券賣出 > 近 5 日均融券賣出 × 3
  Future<List<ChipAnomaly>> _detectShortSurge(DateTime date) async {
    try {
      final dateLowerBound = date.subtract(const Duration(days: 15));

      const query = '''
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
          FROM recent WHERE rn = 1 AND short_sell > 0
        ),
        avg5d AS (
          SELECT symbol, AVG(short_sell) AS avg_short
          FROM recent WHERE rn BETWEEN 2 AND 6
          GROUP BY symbol
          HAVING AVG(short_sell) > 0
        )
        SELECT t.symbol, t.name, t.market, t.short_sell, a.avg_short,
               (t.short_sell / a.avg_short) AS ratio
        FROM today t
        INNER JOIN avg5d a ON t.symbol = a.symbol
        WHERE t.short_sell > a.avg_short * 3
        ORDER BY ratio DESC
        LIMIT 5
      ''';

      final rows = await _db
          .customSelect(
            query,
            variables: [
              Variable.withDateTime(date),
              Variable.withDateTime(dateLowerBound),
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
          keyValue: '${ratio.toStringAsFixed(1)}x',
        );
      }).toList();
    } catch (e) {
      AppLogger.warning(_logTag, '偵測融券暴增失敗: $e');
      return [];
    }
  }

  /// 法人集中大買/賣：單日絕對淨額 > 30日平均絕對淨額 × 5
  ///
  /// 使用倍率門檻替代 Z-score，避免 SQLite 中計算標準差的複雜度。
  Future<List<ChipAnomaly>> _detectInstitutionalSurge(DateTime date) async {
    try {
      final dateLowerBound = date.subtract(const Duration(days: 60));

      const query = '''
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
        WHERE ABS(t.total_net) > a.avg_abs_net * 5
        ORDER BY surge_ratio DESC
        LIMIT 5
      ''';

      final rows = await _db
          .customSelect(
            query,
            variables: [
              Variable.withDateTime(date),
              Variable.withDateTime(dateLowerBound),
            ],
          )
          .get();

      return rows.map((row) {
        final totalNet = row.read<double>('total_net');
        final isBuy = totalNet > 0;
        final formatted = _formatSheets(totalNet.abs());
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
      AppLogger.warning(_logTag, '偵測法人集中買賣失敗: $e');
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
