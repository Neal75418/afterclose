import 'dart:math';

import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';

/// Pure calculation utilities for the comparison table.
///
/// All methods are static and have no [BuildContext] dependency.
/// [Color] values are treated as plain data (sourced from [AppTheme]).
abstract final class ComparisonCalculator {
  // ──────────────────────────────────────────
  // 1) Winner detection
  // ──────────────────────────────────────────

  /// Given a list of nullable values, return the index of the "best" value.
  ///
  /// When [higherIsBetter] is `true`, the highest non-null value wins;
  /// otherwise the lowest wins. Returns `null` when every value is `null`.
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

  // ──────────────────────────────────────────
  // 2) Price return calculation
  // ──────────────────────────────────────────

  /// Calculate the percentage return over a given number of [tradingDays]
  /// from a price [history].
  ///
  /// Returns a record with:
  /// - `display`: formatted string like `"+12.3%"` or `"-5.1%"`, or `"-"` when
  ///   data is insufficient.
  /// - `numeric`: the raw percentage value (for comparison), or `null`.
  /// - `color`: up/down/null colour based on the sign.
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

  // ──────────────────────────────────────────
  // 3) Institutional net aggregation
  // ──────────────────────────────────────────

  /// Aggregate the net buy/sell across the first 5 entries using [getNet] as
  /// the accessor, then return formatted display (in lots, i.e. /1000), the
  /// raw total, and the corresponding colour.
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

  // ──────────────────────────────────────────
  // 4) Sentiment conversion
  // ──────────────────────────────────────────

  /// Map a [SummarySentiment] to a numeric score (0.0 -- 4.0) for comparison.
  ///
  /// Returns `null` when the input is `null`.
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

  /// Map a [SummarySentiment] to its corresponding [Color].
  ///
  /// Returns `null` when the input is `null`.
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
