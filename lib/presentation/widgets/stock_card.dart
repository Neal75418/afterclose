import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/utils/price_limit.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';
import 'package:afterclose/presentation/widgets/score_ring.dart';
import 'package:afterclose/presentation/widgets/warning_badge.dart';

/// 現代化股票資訊卡片 Widget
///
/// 特色：
/// - 採用微妙漸層的現代視覺設計
/// - 依照台灣慣例的價格顏色（紅色 = 上漲，綠色 = 下跌）
/// - 帶有顏色編碼的評分標章
/// - 趨勢指示器與圖示
/// - 微互動：輕微的按壓縮放動畫
/// - 可選的迷你走勢圖
class StockCard extends StatefulWidget {
  const StockCard({
    super.key,
    required this.symbol,
    this.stockName,
    this.market,
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
    this.warningType,
    this.showLimitMarkers = true,
  });

  final String symbol;
  final String? stockName;

  /// 市場：'TWSE'（上市）或 'TPEx'（上櫃）
  final String? market;
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

  /// 警示類型（注意股票、處置股票、高質押）
  final WarningBadgeType? warningType;

  /// 是否顯示漲跌停標記
  final bool showLimitMarkers;

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  bool _isPressed = false;

  /// 建立無障礙語意標籤
  String _buildSemanticLabel() {
    final parts = <String>[];
    parts.add(S.accessibilityStock(widget.symbol));
    if (widget.stockName != null) parts.add(widget.stockName!);
    if (widget.latestClose != null) {
      parts.add(S.accessibilityPrice(widget.latestClose!));
    }
    if (widget.priceChange != null) {
      parts.add(S.accessibilityPriceChange(widget.priceChange!));
      if (widget.showLimitMarkers) {
        if (PriceLimit.isLimitUp(widget.priceChange)) {
          parts.add('漲停');
        } else if (PriceLimit.isLimitDown(widget.priceChange)) {
          parts.add('跌停');
        }
      }
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.stockCardMarginH,
                  vertical: DesignTokens.stockCardMarginV,
                ),
                decoration: AppTheme.cardDecoration(
                  context,
                  isPremium: (widget.score ?? 0) >= 80,
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
                      padding: const EdgeInsets.all(
                        DesignTokens.stockCardPadding,
                      ),
                      child: Row(
                        children: [
                          // 趨勢指示器（現代設計）
                          _buildTrendIndicator(theme, isDark),
                          const SizedBox(width: 12),

                          // 股票資訊區塊
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(theme),
                                if (widget.stockName != null) ...[
                                  const SizedBox(height: 2),
                                  _buildStockName(theme),
                                ],
                                if (widget.reasons.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _buildReasonTags(theme, isDark),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // 迷你走勢圖（需至少 7 天資料）
                          if (widget.recentPrices != null &&
                              widget.recentPrices!.length >= 7) ...[
                            _buildSparkline(priceColor),
                            const SizedBox(width: 8),
                          ],

                          // 價格區塊（帶顏色編碼）
                          _buildPriceSection(theme, priceColor),

                          // 自選按鈕
                          if (widget.onWatchlistTap != null)
                            _buildWatchlistButton(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 警示標記覆蓋層
              if (widget.warningType != null)
                Positioned(
                  top: 0,
                  right: 12,
                  child: WarningBadge(
                    type: widget.warningType!,
                    compact: true,
                    showIcon: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(ThemeData theme, bool isDark) {
    final trendColor = widget.trendState.trendColor;
    final icon = widget.trendState.trendIconData;

    // Simplified design: Icon only, no background container to reduce color noise
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(child: Icon(icon, color: trendColor, size: 24)),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Flexible(
          child: Text(
            widget.symbol,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
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
    final marketLabel = widget.market == 'TPEx' ? '櫃' : null;
    final isLimitUp =
        widget.showLimitMarkers && PriceLimit.isLimitUp(widget.priceChange);
    final isLimitDown =
        widget.showLimitMarkers && PriceLimit.isLimitDown(widget.priceChange);

    return Row(
      children: [
        Flexible(
          child: Text(
            widget.stockName!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (marketLabel != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              marketLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        // 漲停/跌停醒目標籤
        if (isLimitUp || isLimitDown) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.getPriceColor(widget.priceChange),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isLimitUp ? '漲停' : '跌停',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReasonTags(ThemeData theme, bool isDark) {
    // 使用 ConstrainedBox 限制高度為單行，防止標籤換行導致溢出
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 28),
      child: ClipRect(
        child: ReasonTags(
          reasons: widget.reasons,
          size: ReasonTagSize.compact,
          maxTags: 2,
          translateCodes: true,
        ),
      ),
    );
  }

  /// 建立迷你走勢圖
  ///
  /// 新增防禦性 null 檢查，避免條件判斷與方法呼叫之間的競態條件
  Widget _buildSparkline(Color priceColor) {
    final prices = widget.recentPrices;
    if (prices == null || prices.length < 7) {
      return const SizedBox.shrink();
    }
    return _MiniSparkline(prices: prices, color: priceColor);
  }

  Widget _buildPriceSection(ThemeData theme, Color priceColor) {
    final isPositive = (widget.priceChange ?? 0) >= 0;
    final isNeutral = widget.priceChange == null || widget.priceChange == 0;
    final isLimitUp =
        widget.showLimitMarkers && PriceLimit.isLimitUp(widget.priceChange);
    final isLimitDown =
        widget.showLimitMarkers && PriceLimit.isLimitDown(widget.priceChange);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.latestClose != null)
          Text(
            widget.latestClose!.toStringAsFixed(2),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: DesignTokens.fontSizeXl,
              letterSpacing: 0.5,
              fontFamily: 'RobotoMono',
            ),
          ),
        if (widget.priceChange != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: priceColor.withValues(alpha: isNeutral ? 0.1 : 0.15),
              borderRadius: BorderRadius.circular(6),
              border: (isLimitUp || isLimitDown)
                  ? Border.all(color: priceColor, width: 1.5)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 漲跌停標記
                if (isLimitUp || isLimitDown)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      isLimitUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: priceColor,
                      size: 14,
                    ),
                  )
                // 裝飾圖示 - 文字已包含正負號
                else if (!isNeutral)
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
}

/// 優化的迷你走勢圖 Widget
///
/// 效能優化：
/// 1. RepaintBoundary 將重繪與父元件隔離
/// 2. 資料正規化僅在建置時執行一次
/// 3. 最小化 LineChartData 設定
class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.prices, required this.color});

  final List<double> prices;
  final Color color;

  /// 顯示的最大資料點數（為清晰呈現）
  static const int _maxDataPoints = 20;

  /// 有意義圖表所需的最小資料點數
  static const int _minDataPoints = 5;

  /// 垂直間距百分比（上下各 10%）
  static const double _verticalPadding = 0.1;

  /// 間距後可用的內容範圍（1.0 - 2 * padding）
  static const double _contentRange = 0.8;

  /// 顯示圖表的最小價格變化百分比（0.3%）
  static const double _minVariationPercent = 0.003;

  /// 建立無障礙語意標籤
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
    // 需至少 5 個資料點才能呈現有意義的視覺化
    if (prices.length < _minDataPoints) {
      return const SizedBox.shrink();
    }

    // 取樣最近 N 個交易日以獲得更清晰的呈現
    final sampledPrices = _samplePrices(prices);

    // 檢查是否有足夠的價格變化
    final result = _normalizeToSpots(sampledPrices);
    if (result == null) {
      // 變化不足以顯示有意義的圖表
      return const SizedBox.shrink();
    }

    // 使用 RepaintBoundary 隔離圖表重繪
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
            duration: Duration.zero, // 停用動畫以提升效能
          ),
        ),
      ),
    );
  }

  /// 取樣價格至最近 N 個資料點以獲得更清晰的呈現
  List<double> _samplePrices(List<double> prices) {
    if (prices.length <= _maxDataPoints) return prices;
    // 取最近 N 個價格（最近的交易日）
    return prices.sublist(prices.length - _maxDataPoints);
  }

  /// 將價格正規化至 0-1 範圍以獲得一致的圖表高度
  /// 若變化不足以顯示有意義的圖表則回傳 null
  List<FlSpot>? _normalizeToSpots(List<double> prices) {
    if (prices.isEmpty) return null;
    if (prices.length == 1) return null;

    // 找出最小值和最大值
    var min = prices[0];
    var max = prices[0];
    for (final price in prices) {
      if (price < min) min = price;
      if (price > max) max = price;
    }

    // 檢查是否有足夠的變化（至少 0.3%）
    final range = max - min;
    final avgPrice = (max + min) / 2;
    final variationPercent = avgPrice > 0 ? range / avgPrice : 0;

    if (variationPercent < _minVariationPercent) {
      // 變化不足，不顯示圖表
      return null;
    }

    // 正規化至 0-1 範圍，並加上垂直間距
    return List.generate(
      prices.length,
      (i) => FlSpot(
        i.toDouble(),
        ((prices[i] - min) / range) * _contentRange + _verticalPadding,
      ),
    );
  }
}
