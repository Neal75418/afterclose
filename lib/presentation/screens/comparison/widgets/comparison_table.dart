import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 比較表格：6 個區塊、勝出高亮、綜合判定 banner
class ComparisonTable extends StatelessWidget {
  const ComparisonTable({super.key, required this.state});

  final ComparisonState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!state.hasEnoughToCompare) return const SizedBox.shrink();

    final sections = _buildSections();

    // 計算各股票勝出區塊數（用於綜合判定）
    final winCounts = <String, int>{};
    for (final symbol in state.symbols) {
      winCounts[symbol] = 0;
    }
    for (final section in sections) {
      final sectionWinner = _sectionWinner(section);
      if (sectionWinner != null) {
        winCounts[sectionWinner] = (winCounts[sectionWinner] ?? 0) + 1;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table sections
        for (final section in sections) ...[
          _buildSectionHeader(theme, section),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final row in section.rows) _buildMetricRow(theme, row),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Verdict banner
        _buildVerdict(theme, winCounts),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, _ComparisonSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(section.icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            section.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(ThemeData theme, _MetricRow row) {
    // Find winner index
    int? winnerIndex;
    if (row.higherIsBetter != null) {
      double? bestVal;
      for (var i = 0; i < row.values.length; i++) {
        final v = row.numericValues[i];
        if (v == null) continue;
        if (bestVal == null ||
            (row.higherIsBetter! ? v > bestVal : v < bestVal)) {
          bestVal = v;
          winnerIndex = i;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Metric label
          SizedBox(
            width: 80,
            child: Text(
              row.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Values
          for (var i = 0; i < row.values.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  color: i == winnerIndex
                      ? DesignTokens
                            .chartPalette[i % DesignTokens.chartPalette.length]
                            .withValues(alpha: 0.1)
                      : null,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Text(
                  row.values[i],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: i == winnerIndex
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: row.valueColors?[i],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerdict(ThemeData theme, Map<String, int> winCounts) {
    // Find overall winner
    String? winner;
    int maxWins = 0;
    bool isTie = false;

    for (final entry in winCounts.entries) {
      if (entry.value > maxWins) {
        maxWins = entry.value;
        winner = entry.key;
        isTie = false;
      } else if (entry.value == maxWins && maxWins > 0) {
        isTie = true;
      }
    }

    final verdictText = isTie || maxWins == 0
        ? 'comparison.verdictTie'.tr()
        : 'comparison.verdictWinner'.tr(
            namedArgs: {'symbol': winner ?? '', 'count': maxWins.toString()},
          );

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.emoji_events,
              size: 24,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                verdictText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Section builders
  // ──────────────────────────────────────────

  List<_ComparisonSection> _buildSections() {
    return [
      _buildScoreTrendSection(),
      _buildPriceSection(),
      _buildValuationSection(),
      _buildRevenueSection(),
      _buildInstitutionalSection(),
      _buildAISection(),
    ];
  }

  _ComparisonSection _buildScoreTrendSection() {
    return _ComparisonSection(
      title: 'comparison.sectionScoreTrend'.tr(),
      icon: Icons.trending_up,
      rows: [
        _MetricRow(
          label: 'comparison.metricScore'.tr(),
          values: state.symbols.map((s) {
            final score = state.analysesMap[s]?.score;
            return score != null ? score.toInt().toString() : '-';
          }).toList(),
          numericValues: state.symbols
              .map((s) => state.analysesMap[s]?.score)
              .toList(),
          higherIsBetter: true,
        ),
        _MetricRow(
          label: 'comparison.metricTrend'.tr(),
          values: state.symbols.map((s) {
            return state.analysesMap[s]?.trendState ?? '-';
          }).toList(),
        ),
        _MetricRow(
          label: 'comparison.metricReversal'.tr(),
          values: state.symbols.map((s) {
            return state.analysesMap[s]?.reversalState ?? '-';
          }).toList(),
        ),
      ],
    );
  }

  _ComparisonSection _buildPriceSection() {
    return _ComparisonSection(
      title: 'comparison.sectionPrice'.tr(),
      icon: Icons.candlestick_chart,
      rows: [
        _MetricRow(
          label: 'comparison.metricClose'.tr(),
          values: state.symbols.map((s) {
            final close = state.latestPricesMap[s]?.close;
            return close != null ? close.toStringAsFixed(1) : '-';
          }).toList(),
        ),
        _MetricRow(
          label: 'comparison.metricPriceChange'.tr(),
          values: state.symbols.map((s) {
            final latest = state.latestPricesMap[s]?.close;
            final history = state.priceHistoriesMap[s];
            if (latest == null || history == null || history.length < 2) {
              return '-';
            }
            final sorted = List<DailyPriceEntry>.from(history)
              ..sort((a, b) => a.date.compareTo(b.date));
            final prev = sorted[sorted.length - 2].close;
            if (prev == null || prev == 0) return '-';
            final pct = ((latest / prev) - 1) * 100;
            return '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%';
          }).toList(),
          numericValues: state.symbols.map((s) {
            final latest = state.latestPricesMap[s]?.close;
            final history = state.priceHistoriesMap[s];
            if (latest == null || history == null || history.length < 2) {
              return null;
            }
            final sorted = List<DailyPriceEntry>.from(history)
              ..sort((a, b) => a.date.compareTo(b.date));
            final prev = sorted[sorted.length - 2].close;
            if (prev == null || prev == 0) return null;
            return ((latest / prev) - 1) * 100;
          }).toList(),
          higherIsBetter: true,
          valueColors: state.symbols.map((s) {
            final latest = state.latestPricesMap[s]?.close;
            final history = state.priceHistoriesMap[s];
            if (latest == null || history == null || history.length < 2) {
              return null;
            }
            final sorted = List<DailyPriceEntry>.from(history)
              ..sort((a, b) => a.date.compareTo(b.date));
            final prev = sorted[sorted.length - 2].close;
            if (prev == null || prev == 0) return null;
            final pct = ((latest / prev) - 1) * 100;
            return pct > 0
                ? AppTheme.upColor
                : pct < 0
                ? AppTheme.downColor
                : null;
          }).toList(),
        ),
        _buildReturnRow('comparison.metricReturn1M'.tr(), 20),
        _buildReturnRow('comparison.metricReturn3M'.tr(), 60),
      ],
    );
  }

  _MetricRow _buildReturnRow(String label, int tradingDays) {
    return _MetricRow(
      label: label,
      values: state.symbols.map((s) {
        final history = state.priceHistoriesMap[s];
        if (history == null || history.isEmpty) return '-';
        final sorted = List<DailyPriceEntry>.from(history)
          ..sort((a, b) => a.date.compareTo(b.date));
        final startIdx = max(0, sorted.length - tradingDays);
        final startPrice = sorted[startIdx].close;
        final endPrice = sorted.last.close;
        if (startPrice == null || startPrice == 0 || endPrice == null) {
          return '-';
        }
        final pct = ((endPrice / startPrice) - 1) * 100;
        return '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%';
      }).toList(),
      numericValues: state.symbols.map<double?>((s) {
        final history = state.priceHistoriesMap[s];
        if (history == null || history.isEmpty) return null;
        final sorted = List<DailyPriceEntry>.from(history)
          ..sort((a, b) => a.date.compareTo(b.date));
        final startIdx = max(0, sorted.length - tradingDays);
        final startPrice = sorted[startIdx].close;
        final endPrice = sorted.last.close;
        if (startPrice == null || startPrice == 0 || endPrice == null) {
          return null;
        }
        return ((endPrice / startPrice) - 1) * 100;
      }).toList(),
      higherIsBetter: true,
      valueColors: state.symbols.map((s) {
        final history = state.priceHistoriesMap[s];
        if (history == null || history.isEmpty) return null;
        final sorted = List<DailyPriceEntry>.from(history)
          ..sort((a, b) => a.date.compareTo(b.date));
        final startIdx = max(0, sorted.length - tradingDays);
        final startPrice = sorted[startIdx].close;
        final endPrice = sorted.last.close;
        if (startPrice == null || startPrice == 0 || endPrice == null) {
          return null;
        }
        final pct = ((endPrice / startPrice) - 1) * 100;
        return pct > 0
            ? AppTheme.upColor
            : pct < 0
            ? AppTheme.downColor
            : null;
      }).toList(),
    );
  }

  _ComparisonSection _buildValuationSection() {
    return _ComparisonSection(
      title: 'comparison.sectionValuation'.tr(),
      icon: Icons.account_balance,
      rows: [
        _MetricRow(
          label: 'comparison.metricPE'.tr(),
          values: state.symbols.map((s) {
            final pe = state.valuationsMap[s]?.per;
            return pe != null ? pe.toStringAsFixed(1) : '-';
          }).toList(),
          numericValues: state.symbols
              .map((s) => state.valuationsMap[s]?.per)
              .toList(),
          higherIsBetter: false, // Lower P/E = better
        ),
        _MetricRow(
          label: 'comparison.metricPB'.tr(),
          values: state.symbols.map((s) {
            final pb = state.valuationsMap[s]?.pbr;
            return pb != null ? pb.toStringAsFixed(2) : '-';
          }).toList(),
          numericValues: state.symbols
              .map((s) => state.valuationsMap[s]?.pbr)
              .toList(),
          higherIsBetter: false, // Lower P/B = better
        ),
        _MetricRow(
          label: 'comparison.metricDividendYield'.tr(),
          values: state.symbols.map((s) {
            final y = state.valuationsMap[s]?.dividendYield;
            return y != null ? '${y.toStringAsFixed(1)}%' : '-';
          }).toList(),
          numericValues: state.symbols
              .map((s) => state.valuationsMap[s]?.dividendYield)
              .toList(),
          higherIsBetter: true, // Higher yield = better
        ),
      ],
    );
  }

  _ComparisonSection _buildRevenueSection() {
    return _ComparisonSection(
      title: 'comparison.sectionRevenue'.tr(),
      icon: Icons.bar_chart,
      rows: [
        _MetricRow(
          label: 'comparison.metricRevenueMoM'.tr(),
          values: state.symbols.map((s) {
            final rev = state.revenueMap[s];
            if (rev == null || rev.isEmpty) return '-';
            final mom = rev.first.momGrowth;
            return mom != null ? '${mom.toStringAsFixed(1)}%' : '-';
          }).toList(),
          numericValues: state.symbols.map((s) {
            return state.revenueMap[s]?.firstOrNull?.momGrowth;
          }).toList(),
          higherIsBetter: true,
        ),
        _MetricRow(
          label: 'comparison.metricRevenueYoY'.tr(),
          values: state.symbols.map((s) {
            final rev = state.revenueMap[s];
            if (rev == null || rev.isEmpty) return '-';
            final yoy = rev.first.yoyGrowth;
            return yoy != null ? '${yoy.toStringAsFixed(1)}%' : '-';
          }).toList(),
          numericValues: state.symbols.map((s) {
            return state.revenueMap[s]?.firstOrNull?.yoyGrowth;
          }).toList(),
          higherIsBetter: true,
        ),
        _MetricRow(
          label: 'comparison.metricLatestEPS'.tr(),
          values: state.symbols.map((s) {
            final epsList = state.epsMap[s];
            if (epsList == null || epsList.isEmpty) return '-';
            final v = epsList.first.value;
            return v != null ? v.toStringAsFixed(2) : '-';
          }).toList(),
          numericValues: state.symbols.map((s) {
            return state.epsMap[s]?.firstOrNull?.value;
          }).toList(),
          higherIsBetter: true,
        ),
      ],
    );
  }

  _ComparisonSection _buildInstitutionalSection() {
    return _ComparisonSection(
      title: 'comparison.sectionInstitutional'.tr(),
      icon: Icons.groups,
      rows: [
        _buildInstitutionalRow(
          'comparison.metricForeign5D'.tr(),
          (entry) => entry.foreignNet ?? 0,
        ),
        _buildInstitutionalRow(
          'comparison.metricTrust5D'.tr(),
          (entry) => entry.investmentTrustNet ?? 0,
        ),
        _buildInstitutionalRow(
          'comparison.metricDealer5D'.tr(),
          (entry) => entry.dealerNet ?? 0,
        ),
      ],
    );
  }

  _MetricRow _buildInstitutionalRow(
    String label,
    double Function(DailyInstitutionalEntry entry) getNet,
  ) {
    return _MetricRow(
      label: label,
      values: state.symbols.map((s) {
        final instList = state.institutionalMap[s];
        if (instList == null || instList.isEmpty) return '-';
        double total = 0;
        for (final entry in instList.take(5)) {
          total += getNet(entry);
        }
        final lots = (total / 1000).round();
        return '${lots >= 0 ? "+" : ""}$lots';
      }).toList(),
      numericValues: state.symbols.map((s) {
        final instList = state.institutionalMap[s];
        if (instList == null || instList.isEmpty) return null;
        double total = 0;
        for (final entry in instList.take(5)) {
          total += getNet(entry);
        }
        return total;
      }).toList(),
      higherIsBetter: true,
      valueColors: state.symbols.map((s) {
        final instList = state.institutionalMap[s];
        if (instList == null || instList.isEmpty) return null;
        double total = 0;
        for (final entry in instList.take(5)) {
          total += getNet(entry);
        }
        return total > 0
            ? AppTheme.upColor
            : total < 0
            ? AppTheme.downColor
            : null;
      }).toList(),
    );
  }

  _ComparisonSection _buildAISection() {
    return _ComparisonSection(
      title: 'comparison.sectionAI'.tr(),
      icon: Icons.auto_awesome,
      rows: [
        _MetricRow(
          label: 'comparison.metricSentiment'.tr(),
          values: state.symbols.map((s) {
            final summary = state.summariesMap[s];
            if (summary == null) return '-';
            return switch (summary.sentiment) {
              SummarySentiment.bullish => 'comparison.sentimentBullish'.tr(),
              SummarySentiment.neutral => 'comparison.sentimentNeutral'.tr(),
              SummarySentiment.bearish => 'comparison.sentimentBearish'.tr(),
            };
          }).toList(),
          numericValues: state.symbols.map((s) {
            final summary = state.summariesMap[s];
            if (summary == null) return null;
            return switch (summary.sentiment) {
              SummarySentiment.bullish => 3.0,
              SummarySentiment.neutral => 2.0,
              SummarySentiment.bearish => 1.0,
            };
          }).toList(),
          higherIsBetter: true,
          valueColors: state.symbols.map((s) {
            final summary = state.summariesMap[s];
            if (summary == null) return null;
            return switch (summary.sentiment) {
              SummarySentiment.bullish => AppTheme.upColor,
              SummarySentiment.neutral => AppTheme.neutralColor,
              SummarySentiment.bearish => AppTheme.downColor,
            };
          }).toList(),
        ),
      ],
    );
  }

  /// Determine the winner of a section by counting which stock wins the most rows.
  String? _sectionWinner(_ComparisonSection section) {
    final wins = <String, int>{};
    for (final symbol in state.symbols) {
      wins[symbol] = 0;
    }

    for (final row in section.rows) {
      if (row.higherIsBetter == null) continue;

      int? bestIdx;
      double? bestVal;
      for (var i = 0; i < row.numericValues.length; i++) {
        final v = row.numericValues[i];
        if (v == null) continue;
        if (bestVal == null ||
            (row.higherIsBetter! ? v > bestVal : v < bestVal)) {
          bestVal = v;
          bestIdx = i;
        }
      }

      if (bestIdx != null && bestIdx < state.symbols.length) {
        wins[state.symbols[bestIdx]] = (wins[state.symbols[bestIdx]] ?? 0) + 1;
      }
    }

    String? winner;
    int maxWins = 0;
    bool tie = false;
    for (final entry in wins.entries) {
      if (entry.value > maxWins) {
        maxWins = entry.value;
        winner = entry.key;
        tie = false;
      } else if (entry.value == maxWins && maxWins > 0) {
        tie = true;
      }
    }

    return tie ? null : winner;
  }
}

// ──────────────────────────────────────────
// Data models
// ──────────────────────────────────────────

class _ComparisonSection {
  const _ComparisonSection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_MetricRow> rows;
}

class _MetricRow {
  const _MetricRow({
    required this.label,
    required this.values,
    this.numericValues = const [],
    this.higherIsBetter,
    this.valueColors,
  });

  final String label;
  final List<String> values;
  final List<double?> numericValues;
  final bool? higherIsBetter;
  final List<Color?>? valueColors;
}
