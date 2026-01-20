import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';

/// Stock detail screen - shows comprehensive stock information
class StockDetailScreen extends ConsumerStatefulWidget {
  const StockDetailScreen({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(stockDetailProvider(widget.symbol).notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockDetailProvider(widget.symbol));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol),
        actions: [
          IconButton(
            icon: Icon(
              state.isInWatchlist ? Icons.star : Icons.star_border,
              color: state.isInWatchlist ? Colors.amber : null,
            ),
            onPressed: () {
              ref
                  .read(stockDetailProvider(widget.symbol).notifier)
                  .toggleWatchlist();
            },
            tooltip: state.isInWatchlist ? '從自選移除' : '加入自選',
          ),
        ],
      ),
      body: state.isLoading
          ? const StockDetailShimmer()
          : state.error != null
          ? EmptyStates.error(
              message: state.error!,
              onRetry: () {
                ref
                    .read(stockDetailProvider(widget.symbol).notifier)
                    .loadData();
              },
            )
          : _buildContent(state),
    );
  }

  Widget _buildContent(StockDetailState state) {
    final theme = Theme.of(context);
    final priceChange = state.priceChange;
    final isPositive = (priceChange ?? 0) >= 0;
    final priceColor = AppTheme.getPriceColor(priceChange);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stock header with Hero animations
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.stock?.name ?? widget.symbol,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.symbol,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    state.latestPrice?.close?.toStringAsFixed(2) ?? '-',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (priceChange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: priceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: priceColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Trend and reversal
          Row(
            children: [
              _buildInfoChip(
                label: '趨勢',
                value: state.trendLabel,
                icon: _getTrendIcon(state.analysis?.trendState),
              ),
              const SizedBox(width: 8),
              if (state.reversalLabel != null)
                _buildInfoChip(
                  label: '轉折',
                  value: state.reversalLabel!,
                  icon: '🔄',
                  color: Colors.orange,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Key levels
          if (state.analysis != null) ...[
            Text(
              '關鍵價位',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildLevelRow(
                      '壓力',
                      state.analysis!.resistanceLevel,
                      Colors.red,
                      state.latestPrice?.close,
                    ),
                    const Divider(),
                    _buildLevelRow(
                      '支撐',
                      state.analysis!.supportLevel,
                      Colors.green,
                      state.latestPrice?.close,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Reasons
          if (state.reasons.isNotEmpty) ...[
            Text(
              '觸發理由',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...state.reasons.map((reason) {
              final reasonType = ReasonType.values
                  .where((r) => r.code == reason.reasonType)
                  .firstOrNull;

              return Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _getReasonIcon(reason.reasonType),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  title: Text(
                    reasonType?.label ?? reason.reasonType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('+${reason.ruleScore} 分'),
                ),
              );
            }),
          ],

          const SizedBox(height: 16),

          // OHLCV info
          Text(
            '今日交易',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildDataRow('開盤', state.latestPrice?.open),
                  _buildDataRow('最高', state.latestPrice?.high),
                  _buildDataRow('最低', state.latestPrice?.low),
                  _buildDataRow('收盤', state.latestPrice?.close),
                  _buildDataRow(
                    '成交量',
                    state.latestPrice?.volume,
                    formatter: _formatVolume,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Institutional data
          if (state.institutionalHistory.isNotEmpty) ...[
            Text(
              '近期法人',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: state.institutionalHistory.reversed.take(5).map((
                    inst,
                  ) {
                    final netTotal =
                        (inst.foreignNet ?? 0) +
                        (inst.investmentTrustNet ?? 0) +
                        (inst.dealerNet ?? 0);
                    final isPositive = netTotal >= 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '${inst.date.month}/${inst.date.day}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Text(
                            '外資 ${_formatNet(inst.foreignNet)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '投信 ${_formatNet(inst.investmentTrustNet)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatNet(netTotal),
                              style: TextStyle(
                                color: isPositive
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required String icon,
    Color? color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow(
    String label,
    double? level,
    Color color,
    double? currentPrice,
  ) {
    final theme = Theme.of(context);

    String distance = '';
    if (level != null && currentPrice != null && currentPrice > 0) {
      final pct = ((level - currentPrice) / currentPrice) * 100;
      distance = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          level?.toStringAsFixed(2) ?? '-',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text(
          distance,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(
    String label,
    double? value, {
    String Function(double)? formatter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value != null
                ? (formatter?.call(value) ?? value.toStringAsFixed(2))
                : '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
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

  String _getReasonIcon(String reasonType) {
    return switch (reasonType) {
      'REVERSAL_W2S' => '🔄',
      'REVERSAL_S2W' => '🔄',
      'TECH_BREAKOUT' => '🚀',
      'TECH_BREAKDOWN' => '📉',
      'VOLUME_SPIKE' => '📊',
      'PRICE_SPIKE' => '💥',
      'INSTITUTIONAL_SHIFT' => '🏦',
      'NEWS_RELATED' => '📰',
      _ => '⚡',
    };
  }

  String _formatVolume(double volume) {
    if (volume >= 100000000) {
      return '${(volume / 100000000).toStringAsFixed(2)}億';
    } else if (volume >= 10000) {
      return '${(volume / 10000).toStringAsFixed(0)}萬';
    }
    return volume.toStringAsFixed(0);
  }

  String _formatNet(double? value) {
    if (value == null) return '-';
    if (value >= 1000 || value <= -1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
