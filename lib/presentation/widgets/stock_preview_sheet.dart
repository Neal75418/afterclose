import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/theme/app_theme.dart';

/// Data class for stock preview
class StockPreviewData {
  const StockPreviewData({
    required this.symbol,
    this.stockName,
    this.latestClose,
    this.priceChange,
    this.score,
    this.trendState,
    this.reasons = const [],
    this.isInWatchlist = false,
  });

  final String symbol;
  final String? stockName;
  final double? latestClose;
  final double? priceChange;
  final double? score;
  final String? trendState;
  final List<String> reasons;
  final bool isInWatchlist;
}

/// Shows a bottom sheet preview for a stock
Future<void> showStockPreviewSheet({
  required BuildContext context,
  required StockPreviewData data,
  VoidCallback? onViewDetails,
  VoidCallback? onToggleWatchlist,
}) {
  HapticFeedback.mediumImpact();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StockPreviewSheet(
      data: data,
      onViewDetails: onViewDetails,
      onToggleWatchlist: onToggleWatchlist,
    ),
  );
}

/// Bottom sheet widget for stock preview
class StockPreviewSheet extends StatelessWidget {
  const StockPreviewSheet({
    super.key,
    required this.data,
    this.onViewDetails,
    this.onToggleWatchlist,
  });

  final StockPreviewData data;
  final VoidCallback? onViewDetails;
  final VoidCallback? onToggleWatchlist;

  /// Build semantic label for the sheet
  String _buildSemanticLabel() {
    final parts = <String>['股票預覽', data.symbol];
    if (data.stockName != null) parts.add(data.stockName!);
    if (data.latestClose != null) parts.add('價格 ${data.latestClose!.toStringAsFixed(2)} 元');
    if (data.priceChange != null) {
      final direction = data.priceChange! >= 0 ? '上漲' : '下跌';
      parts.add('$direction ${data.priceChange!.abs().toStringAsFixed(2)} 百分比');
    }
    if (data.score != null && data.score! > 0) {
      parts.add('評分 ${data.score!.toInt()} 分');
      parts.add(_getScoreLevel(data.score!));
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priceColor = AppTheme.getPriceColor(data.priceChange);
    final isPositive = (data.priceChange ?? 0) >= 0;

    return Semantics(
      label: _buildSemanticLabel(),
      container: true,
      child: Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Trend indicator
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getTrendColor().withValues(alpha: 0.2),
                            _getTrendColor().withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getTrendColor().withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getTrendIcon(),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          duration: 300.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(width: 16),

                    // Symbol and name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.symbol,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (data.stockName != null)
                            Text(
                              data.stockName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Price section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (data.latestClose != null)
                          Text(
                            data.latestClose!.toStringAsFixed(2),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (data.priceChange != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priceColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.arrow_drop_up
                                      : Icons.arrow_drop_down,
                                  color: priceColor,
                                  size: 20,
                                ),
                                Text(
                                  '${isPositive ? '+' : ''}${data.priceChange!.toStringAsFixed(2)}%',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: priceColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Score section
                if (data.score != null && data.score! > 0) ...[
                  const SizedBox(height: 20),
                  _buildScoreSection(theme),
                ],

                // Reasons section
                if (data.reasons.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildReasonsSection(theme, isDark),
                ],

                // Action buttons
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          onToggleWatchlist?.call();
                        },
                        icon: Icon(
                          data.isInWatchlist
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: data.isInWatchlist ? Colors.amber : null,
                        ),
                        label: Text(data.isInWatchlist ? S.stockRemoveFromWatchlist : S.stockAddToWatchlist),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: data.isInWatchlist
                                ? Colors.amber
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          onViewDetails?.call();
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(S.stockViewDetails),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 300.ms)
                    .slideY(begin: 0.2, duration: 300.ms),

                // Bottom safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildScoreSection(ThemeData theme) {
    final scoreColor = AppTheme.getScoreColor(data.score!);
    final progress = (data.score! / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        // Score ring (larger version)
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 4,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  scoreColor.withValues(alpha: 0.2),
                ),
              ),
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                strokeCap: StrokeCap.round,
              ),
              Text(
                '${data.score!.toInt()}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.5, 0.5),
              delay: 100.ms,
              duration: 400.ms,
              curve: Curves.easeOutBack,
            ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.scoreLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _getScoreLevel(data.score!),
              style: theme.textTheme.titleSmall?.copyWith(
                color: scoreColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReasonsSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.reasonsLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.reasons.map((reason) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.secondaryColor.withValues(alpha: 0.15)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                reason,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 300.ms)
        .slideY(begin: 0.1, duration: 300.ms);
  }

  String _getTrendIcon() {
    return switch (data.trendState) {
      'UP' => '📈',
      'DOWN' => '📉',
      _ => '➡️',
    };
  }

  Color _getTrendColor() {
    return switch (data.trendState) {
      'UP' => AppTheme.upColor,
      'DOWN' => AppTheme.downColor,
      _ => AppTheme.neutralColor,
    };
  }

  String _getScoreLevel(double score) => S.getScoreLevel(score);
}
