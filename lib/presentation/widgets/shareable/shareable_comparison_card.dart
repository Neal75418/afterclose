import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 比較結果分享卡片（用於 PNG 匯出）
class ShareableComparisonCard extends StatelessWidget {
  const ShareableComparisonCard({super.key, required this.state});

  final ComparisonState state;

  static const _stockColors = [
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF4CAF50),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 420,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.compare_arrows,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AfterClose',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              Text(
                'comparison.title'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 股票列表
              ...state.symbols.asMap().entries.map((entry) {
                final idx = entry.key;
                final symbol = entry.value;
                final stock = state.stocksMap[symbol];
                final price = state.latestPricesMap[symbol];
                final analysis = state.analysesMap[symbol];
                final valuation = state.valuationsMap[symbol];
                final color = _stockColors[idx % _stockColors.length];

                return _StockRow(
                  color: color,
                  symbol: symbol,
                  name: stock?.name ?? '',
                  close: price?.close,
                  score: analysis?.score,
                  trend: analysis?.trendState,
                  pe: valuation?.per,
                  dividendYield: valuation?.dividendYield,
                  sentiment: state.summariesMap[symbol]?.sentiment,
                );
              }),

              const Divider(height: 24),

              // 免責聲明
              Text(
                'export.disclaimer'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.color,
    required this.symbol,
    required this.name,
    this.close,
    this.score,
    this.trend,
    this.pe,
    this.dividendYield,
    this.sentiment,
  });

  final Color color;
  final String symbol;
  final String name;
  final double? close;
  final double? score;
  final String? trend;
  final double? pe;
  final double? dividendYield;
  final SummarySentiment? sentiment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$symbol $name',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (close != null)
                Text(
                  close!.toStringAsFixed(2),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (score != null) _Tag('${score!.toStringAsFixed(0)}分', color),
              if (trend != null) _Tag(trend!, _trendColor(trend!)),
              if (pe != null) _Tag('PE ${pe!.toStringAsFixed(1)}', Colors.grey),
              if (dividendYield != null)
                _Tag('殖 ${dividendYield!.toStringAsFixed(1)}%', Colors.teal),
              if (sentiment != null) _SentimentTag(sentiment: sentiment!),
            ],
          ),
        ],
      ),
    );
  }

  Color _trendColor(String trend) {
    if (trend == 'UP') return AppTheme.upColor;
    if (trend == 'DOWN') return AppTheme.downColor;
    return AppTheme.neutralColor;
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SentimentTag extends StatelessWidget {
  const _SentimentTag({required this.sentiment});
  final SummarySentiment sentiment;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (sentiment) {
      SummarySentiment.bullish => (
        'summary.sentimentBullish'.tr(),
        AppTheme.upColor,
      ),
      SummarySentiment.neutral => (
        'summary.sentimentNeutral'.tr(),
        AppTheme.neutralColor,
      ),
      SummarySentiment.bearish => (
        'summary.sentimentBearish'.tr(),
        AppTheme.downColor,
      ),
    };

    return _Tag(label, color);
  }
}
