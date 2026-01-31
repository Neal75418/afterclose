import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/comparison_header.dart';

/// Radar chart comparing stocks across 6 dimensions.
///
/// Axes: Score, Price Perf, Valuation, Revenue, Institutional, AI Sentiment.
/// Each axis is normalized to 0-100.
class RadarComparisonChart extends StatelessWidget {
  const RadarComparisonChart({super.key, required this.state});

  final ComparisonState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.symbols.length < 2) return const SizedBox.shrink();

    final datasets = _buildDatasets();
    if (datasets.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'comparison.radarTitle'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: RadarChart(
                RadarChartData(
                  dataSets: datasets,
                  radarBackgroundColor: Colors.transparent,
                  borderData: FlBorderData(show: false),
                  radarBorderData: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  tickBorderData: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  gridBorderData: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  tickCount: 4,
                  ticksTextStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                    fontSize: 8,
                  ),
                  titlePositionPercentageOffset: 0.2,
                  titleTextStyle: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  getTitle: (index, angle) {
                    const labels = [
                      'comparison.metricScore',
                      'comparison.sectionPrice',
                      'comparison.sectionValuation',
                      'comparison.sectionRevenue',
                      'comparison.sectionInstitutional',
                      'comparison.sectionAI',
                    ];
                    if (index < labels.length) {
                      return RadarChartTitle(text: labels[index].tr());
                    }
                    return const RadarChartTitle(text: '');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RadarDataSet> _buildDatasets() {
    final datasets = <RadarDataSet>[];

    for (var i = 0; i < state.symbols.length; i++) {
      final symbol = state.symbols[i];
      final color = comparisonColors[i % comparisonColors.length];

      final values = _computeRadarValues(symbol);

      datasets.add(
        RadarDataSet(
          dataEntries: values.map((v) => RadarEntry(value: v)).toList(),
          fillColor: color.withValues(alpha: 0.1),
          borderColor: color,
          borderWidth: 2,
          entryRadius: 3,
        ),
      );
    }

    return datasets;
  }

  /// Compute 6 normalized values (0-100) for a stock.
  List<double> _computeRadarValues(String symbol) {
    return [
      _scoreValue(symbol),
      _pricePerformanceValue(symbol),
      _valuationValue(symbol),
      _revenueValue(symbol),
      _institutionalValue(symbol),
      _sentimentValue(symbol),
    ];
  }

  /// Score: direct 0-100.
  double _scoreValue(String symbol) {
    return (state.analysesMap[symbol]?.score ?? 0).clamp(0, 100);
  }

  /// Price performance: 1M return mapped to 0-100 (clamped linear).
  /// -30% or worse = 0, +30% or better = 100, 0% = 50.
  double _pricePerformanceValue(String symbol) {
    final history = state.priceHistoriesMap[symbol];
    if (history == null || history.length < 2) return 50;

    final sorted = List<DailyPriceEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Get ~20 trading days ago (approx 1 month)
    final startIndex = max(0, sorted.length - 20);
    final startPrice = sorted[startIndex].close ?? 0.0;
    final endPrice = sorted.last.close ?? 0.0;

    if (startPrice == 0) return 50;

    final returnPct = ((endPrice / startPrice) - 1) * 100;
    // Map [-30, +30] to [0, 100]
    return ((returnPct + 30) / 60 * 100).clamp(0, 100);
  }

  /// Valuation: composite of P/E (lower = better), dividend yield (higher = better).
  /// P/E < 10 = 100, P/E > 40 = 0; Yield > 6% = 100, Yield 0% = 0.
  double _valuationValue(String symbol) {
    final valuation = state.valuationsMap[symbol];
    if (valuation == null) return 50;

    double score = 0;
    int count = 0;

    final pe = valuation.per;
    if (pe != null && pe > 0) {
      // Lower P/E = better: PE 10 → 100, PE 40 → 0
      score += ((40 - pe) / 30 * 100).clamp(0, 100);
      count++;
    }

    final yield_ = valuation.dividendYield;
    if (yield_ != null) {
      // Higher yield = better: 0% → 0, 6% → 100
      score += (yield_ / 6 * 100).clamp(0, 100);
      count++;
    }

    return count > 0 ? score / count : 50;
  }

  /// Revenue: YoY growth mapped to 0-100.
  /// -50% = 0, +50% = 100, 0% = 50.
  double _revenueValue(String symbol) {
    final revenueList = state.revenueMap[symbol];
    if (revenueList == null || revenueList.isEmpty) return 50;

    final yoy = revenueList.first.yoyGrowth;
    if (yoy == null) return 50;

    return ((yoy + 50) / 100 * 100).clamp(0, 100);
  }

  /// Institutional: 5-day net buy amount mapped.
  /// Positive = bullish, negative = bearish.
  double _institutionalValue(String symbol) {
    final instList = state.institutionalMap[symbol];
    if (instList == null || instList.isEmpty) return 50;

    // Sum 5-day foreign net
    final recent = instList.take(5);
    double totalNet = 0;
    for (final entry in recent) {
      totalNet += entry.foreignNet ?? 0;
    }

    // Normalize: ±50M as full range
    final normalized = (totalNet / 50000000) * 50 + 50;
    return normalized.clamp(0, 100);
  }

  /// Sentiment: bullish=85, neutral=50, bearish=15.
  double _sentimentValue(String symbol) {
    final summary = state.summariesMap[symbol];
    if (summary == null) return 50;

    return switch (summary.sentiment) {
      SummarySentiment.bullish => 85,
      SummarySentiment.neutral => 50,
      SummarySentiment.bearish => 15,
    };
  }
}
