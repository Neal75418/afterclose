import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';
import 'package:afterclose/presentation/widgets/score_ring.dart';

/// Modern card widget displaying stock information
///
/// Features:
/// - Modern visual design with subtle gradients
/// - Price color based on Taiwan convention (red = up, green = down)
/// - Score badge with color coding
/// - Trend indicator with icon
/// - Micro-interaction: subtle press-to-scale animation
/// - Optional sparkline chart
class StockCard extends StatefulWidget {
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
    this.onLongPress,
    this.onWatchlistTap,
    this.recentPrices,
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
  final VoidCallback? onLongPress;
  final VoidCallback? onWatchlistTap;
  final List<double>? recentPrices;

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  bool _isPressed = false;

  /// Build semantic label for accessibility
  String _buildSemanticLabel() {
    final parts = <String>[];
    parts.add(S.accessibilityStock(widget.symbol));
    if (widget.stockName != null) parts.add(widget.stockName!);
    if (widget.latestClose != null) {
      parts.add(S.accessibilityPrice(widget.latestClose!));
    }
    if (widget.priceChange != null) {
      parts.add(S.accessibilityPriceChange(widget.priceChange!));
    }
    if (widget.score != null && widget.score! > 0) {
      parts.add(S.accessibilityScore(widget.score!.toInt()));
    }
    if (widget.trendState != null) {
      parts.add(S.getTrendLabel(widget.trendState));
    }
    if (widget.reasons.isNotEmpty) {
      parts.add(S.accessibilitySignals(widget.reasons.take(2).join(', ')));
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priceColor = AppTheme.getPriceColor(widget.priceChange);

    return Semantics(
      label: _buildSemanticLabel(),
      button: true,
      enabled: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: AnimDurations.press,
          curve: AnimCurves.enter,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252536) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3A3A4A)
                    : const Color(0xFFE8E8F0),
                width: 1,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onTap?.call();
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  widget.onLongPress?.call();
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Trend indicator with modern design
                      _buildTrendIndicator(theme, isDark),
                      const SizedBox(width: 14),

                      // Stock info section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme),
                            if (widget.stockName != null) ...[
                              const SizedBox(height: 2),
                              _buildStockName(theme),
                            ],
                            if (widget.reasons.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildReasonTags(theme, isDark),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Mini sparkline chart (need at least 7 days of data)
                      if (widget.recentPrices != null &&
                          widget.recentPrices!.length >= 7) ...[
                        _buildSparkline(priceColor),
                        const SizedBox(width: 8),
                      ],

                      // Price section with color coding
                      _buildPriceSection(theme, priceColor),

                      // Watchlist button
                      if (widget.onWatchlistTap != null)
                        _buildWatchlistButton(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(ThemeData theme, bool isDark) {
    final trendColor = _getTrendColor(widget.trendState);
    final icon = _getTrendIconData(widget.trendState);
    final isNeutral = widget.trendState == null || widget.trendState == 'SIDEWAYS';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: isDark && isNeutral
            ? Border.all(
                color: trendColor.withValues(alpha: 0.4),
                width: 1,
              )
            : null,
      ),
      child: Center(child: Icon(icon, color: trendColor, size: 24)),
    );
  }

  IconData _getTrendIconData(String? trend) {
    return switch (trend) {
      'UP' => Icons.trending_up_rounded,
      'DOWN' => Icons.trending_down_rounded,
      _ => Icons.trending_flat_rounded,
    };
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Text(
          widget.symbol,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        if (widget.score != null && widget.score! > 0) ...[
          const SizedBox(width: 10),
          ScoreRing(score: widget.score!, size: ScoreRingSize.medium),
        ],
      ],
    );
  }

  Widget _buildStockName(ThemeData theme) {
    return Text(
      widget.stockName!,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildReasonTags(ThemeData theme, bool isDark) {
    return ReasonTags(
      reasons: widget.reasons,
      size: ReasonTagSize.compact,
      maxTags: 2,
      translateCodes: true,
    );
  }

  Widget _buildSparkline(Color priceColor) {
    return _MiniSparkline(prices: widget.recentPrices!, color: priceColor);
  }

  Widget _buildPriceSection(ThemeData theme, Color priceColor) {
    final isPositive = (widget.priceChange ?? 0) >= 0;
    final isNeutral = widget.priceChange == null || widget.priceChange == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.latestClose != null)
          Text(
            widget.latestClose!.toStringAsFixed(2),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        if (widget.priceChange != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: priceColor.withValues(alpha: isNeutral ? 0.1 : 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decorative icon - text already contains +/- sign
                if (!isNeutral)
                  ExcludeSemantics(
                    child: Icon(
                      isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: priceColor,
                      size: 18,
                    ),
                  ),
                Text(
                  '${isPositive && !isNeutral ? '+' : ''}${widget.priceChange!.toStringAsFixed(2)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: priceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWatchlistButton(ThemeData theme) {
    final tooltipText = widget.isInWatchlist ? '從自選移除' : '加入自選';
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        label: tooltipText,
        button: true,
        child: IconButton(
          icon: Icon(
            widget.isInWatchlist
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: widget.isInWatchlist
                ? Colors.amber
                : theme.colorScheme.onSurfaceVariant,
            size: 26,
          ),
          tooltip: tooltipText,
          onPressed: () {
            HapticFeedback.mediumImpact();
            widget.onWatchlistTap?.call();
          },
          splashRadius: 20,
        ),
      ),
    );
  }

  Color _getTrendColor(String? trend) {
    return switch (trend) {
      'UP' => AppTheme.upColor,
      'DOWN' => AppTheme.downColor,
      _ => AppTheme.neutralColor,
    };
  }
}

/// Optimized mini sparkline chart widget
///
/// Performance optimizations:
/// 1. RepaintBoundary isolates repaints from parent
/// 2. Data normalization done once in build
/// 3. Minimal LineChartData configuration
class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.prices, required this.color});

  final List<double> prices;
  final Color color;

  /// Maximum data points to display (for clear visualization)
  static const int _maxDataPoints = 20;

  /// Minimum data points required for meaningful chart
  static const int _minDataPoints = 5;

  /// Vertical padding percentage (10% top and bottom)
  static const double _verticalPadding = 0.1;

  /// Usable content range after padding (1.0 - 2 * padding)
  static const double _contentRange = 0.8;

  /// Minimum price variation percentage to show chart (0.3%)
  static const double _minVariationPercent = 0.003;

  /// Build semantic label for accessibility
  String _buildSemanticLabel(List<double> sampledPrices) {
    if (sampledPrices.length < 2) return S.sparklineDefault;

    final first = sampledPrices.first;
    final last = sampledPrices.last;
    final change = first > 0 ? ((last - first) / first * 100) : 0.0;
    final days = sampledPrices.length;

    if (change.abs() < 0.1) {
      return S.sparklineFlat(days);
    }
    return S.sparklineTrend(days, change);
  }

  @override
  Widget build(BuildContext context) {
    // Need at least 5 data points for meaningful visualization
    if (prices.length < _minDataPoints) {
      return const SizedBox.shrink();
    }

    // Sample to last N trading days for clearer visualization
    final sampledPrices = _samplePrices(prices);

    // Check if there's meaningful price variation
    final result = _normalizeToSpots(sampledPrices);
    if (result == null) {
      // Not enough variation to show meaningful chart
      return const SizedBox.shrink();
    }

    // Use RepaintBoundary to isolate chart repaints
    return Semantics(
      label: _buildSemanticLabel(sampledPrices),
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
          width: 70,
          height: 32,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 1,
              lineBarsData: [
                LineChartBarData(
                  spots: result,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: color,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0.25),
                        color.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ],
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
            ),
            duration: Duration.zero, // Disable animations for performance
          ),
        ),
      ),
    );
  }

  /// Sample prices to last N data points for clearer visualization
  List<double> _samplePrices(List<double> prices) {
    if (prices.length <= _maxDataPoints) return prices;
    // Take the last N prices (most recent trading days)
    return prices.sublist(prices.length - _maxDataPoints);
  }

  /// Normalize prices to 0-1 range for consistent chart height
  /// Returns null if there's not enough variation to show meaningful chart
  List<FlSpot>? _normalizeToSpots(List<double> prices) {
    if (prices.isEmpty) return null;
    if (prices.length == 1) return null;

    // Find min and max
    var min = prices[0];
    var max = prices[0];
    for (final price in prices) {
      if (price < min) min = price;
      if (price > max) max = price;
    }

    // Check if there's meaningful variation (at least 0.3%)
    final range = max - min;
    final avgPrice = (max + min) / 2;
    final variationPercent = avgPrice > 0 ? range / avgPrice : 0;

    if (variationPercent < _minVariationPercent) {
      // Not enough variation, don't show chart
      return null;
    }

    // Normalize to 0-1 range with vertical padding
    return List.generate(
      prices.length,
      (i) => FlSpot(
        i.toDouble(),
        ((prices[i] - min) / range) * _contentRange + _verticalPadding,
      ),
    );
  }
}
