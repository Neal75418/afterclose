import 'dart:math';

import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';

/// 比較表的純計算工具。
///
/// 所有方法皆為 static，不依賴 [BuildContext]。
/// [Color] 視為純資料（來自 [AppTheme]）。
abstract final class ComparisonCalculator {
  // ==================================================
  // 1) Winner detection
  // ==================================================

  /// 從一組可為 null 的數值中，回傳「最佳」值的索引。
  ///
  /// 當 [higherIsBetter] 為 `true` 時，最大的非 null 值勝出；
  /// 反之最小值勝出。當所有值皆為 `null` 時回傳 `null`。
  static int? findWinnerIndex(
    List<double?> values, {
    required bool higherIsBetter,
  }) {
    int? bestIdx;
    double? bestVal;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      if (bestVal == null || (higherIsBetter ? v > bestVal : v < bestVal)) {
        bestVal = v;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  // ==================================================
  // 2) Price return calculation
  // ==================================================

  /// 根據價格 [history]，計算指定 [tradingDays] 交易日的報酬率百分比。
  ///
  /// 回傳 record 包含：
  /// - `display`：格式化字串如 `"+12.3%"` 或 `"-5.1%"`，資料不足時為 `"-"`。
  /// - `numeric`：原始百分比值（供比較用），或 `null`。
  /// - `color`：根據正負號對應的漲跌顏色。
  static ({String display, double? numeric, Color? color}) calculatePriceReturn(
    List<DailyPriceEntry>? history,
    int tradingDays,
  ) {
    if (history == null || history.isEmpty) {
      return (display: '-', numeric: null, color: null);
    }

    final sorted = List<DailyPriceEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final startIdx = max(0, sorted.length - tradingDays);
    final startPrice = sorted[startIdx].close;
    final endPrice = sorted.last.close;

    if (startPrice == null || startPrice == 0 || endPrice == null) {
      return (display: '-', numeric: null, color: null);
    }

    final pct = ((endPrice / startPrice) - 1) * 100;
    final display = '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%';
    final color = pct > 0
        ? AppTheme.upColor
        : pct < 0
        ? AppTheme.downColor
        : null;

    return (display: display, numeric: pct, color: color);
  }

  // ==================================================
  // 3) Institutional net aggregation
  // ==================================================

  /// 使用 [getNet] 存取器，彙總前 5 筆的法人買賣超，
  /// 回傳格式化顯示值（以張為單位，即 /1000）、原始合計值及對應顏色。
  static ({String display, double? numeric, Color? color})
  aggregateInstitutionalNet(
    List<DailyInstitutionalEntry>? entries,
    double Function(DailyInstitutionalEntry) getNet,
  ) {
    if (entries == null || entries.isEmpty) {
      return (display: '-', numeric: null, color: null);
    }

    double total = 0;
    for (final entry in entries.take(5)) {
      total += getNet(entry);
    }

    final lots = (total / 1000).round();
    final display = '${lots >= 0 ? "+" : ""}$lots';
    final color = total > 0
        ? AppTheme.upColor
        : total < 0
        ? AppTheme.downColor
        : null;

    return (display: display, numeric: total, color: color);
  }

  // ==================================================
  // 4) Sentiment conversion
  // ==================================================

  /// 將 [SummarySentiment] 對應為數值分數（0.0 -- 4.0）以供比較。
  ///
  /// 輸入為 `null` 時回傳 `null`。
  static double? sentimentToNumeric(SummarySentiment? sentiment) {
    if (sentiment == null) return null;
    return switch (sentiment) {
      SummarySentiment.strongBullish => 4.0,
      SummarySentiment.bullish => 3.0,
      SummarySentiment.neutral => 2.0,
      SummarySentiment.bearish => 1.0,
      SummarySentiment.strongBearish => 0.0,
    };
  }

  /// 將 [SummarySentiment] 對應為其對應的 [Color]。
  ///
  /// 輸入為 `null` 時回傳 `null`。
  static Color? sentimentToColor(SummarySentiment? sentiment) {
    if (sentiment == null) return null;
    return switch (sentiment) {
      SummarySentiment.strongBullish => AppTheme.upColor,
      SummarySentiment.bullish => AppTheme.upColor,
      SummarySentiment.neutral => AppTheme.neutralColor,
      SummarySentiment.bearish => AppTheme.downColor,
      SummarySentiment.strongBearish => AppTheme.downColor,
    };
  }
}
