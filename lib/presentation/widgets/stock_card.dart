import 'package:flutter/material.dart';

/// Card widget displaying stock information
class StockCard extends StatelessWidget {
  const StockCard({
    super.key,
    required this.symbol,
    this.stockName,
    this.latestClose,
    this.priceChange,
    this.score,
    this.reasons = const [],
    this.trendState,
    this.isInWatchlist = false,
    this.onTap,
    this.onWatchlistTap,
  });

  final String symbol;
  final String? stockName;
  final double? latestClose;
  final double? priceChange;
  final double? score;
  final List<String> reasons;
  final String? trendState;
  final bool isInWatchlist;
  final VoidCallback? onTap;
  final VoidCallback? onWatchlistTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = (priceChange ?? 0) >= 0;
    final priceColor = isPositive ? Colors.red.shade700 : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Trend icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getTrendColor(trendState).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _getTrendIcon(trendState),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Stock info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          symbol,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (score != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getScoreColor(score!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${score!.toInt()}分',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (stockName != null)
                      Text(
                        stockName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (reasons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: reasons
                              .take(2)
                              .map(
                                (r) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    r,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),

              // Price info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (latestClose != null)
                    Text(
                      latestClose!.toStringAsFixed(2),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (priceChange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}${priceChange!.toStringAsFixed(2)}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: priceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              // Watchlist button
              if (onWatchlistTap != null)
                IconButton(
                  icon: Icon(
                    isInWatchlist ? Icons.star : Icons.star_border,
                    color: isInWatchlist ? Colors.amber : null,
                  ),
                  onPressed: onWatchlistTap,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTrendIcon(String? trend) {
    return switch (trend) {
      'UP' => '📈',
      'DOWN' => '📉',
      _ => '➡️',
    };
  }

  Color _getTrendColor(String? trend) {
    return switch (trend) {
      'UP' => Colors.red,
      'DOWN' => Colors.green,
      _ => Colors.grey,
    };
  }

  Color _getScoreColor(double score) {
    if (score >= 50) return Colors.red.shade700;
    if (score >= 35) return Colors.orange.shade700;
    if (score >= 20) return Colors.amber.shade700;
    return Colors.grey.shade600;
  }
}
