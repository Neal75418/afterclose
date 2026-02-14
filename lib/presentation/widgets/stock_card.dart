import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/constants/ui_constants.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/utils/price_limit.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';
import 'package:afterclose/presentation/widgets/score_ring.dart';
import 'package:afterclose/presentation/widgets/stock_card_price.dart';
import 'package:afterclose/presentation/widgets/stock_card_sparkline.dart';
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
          parts.add(S.priceLimitUp);
        } else if (PriceLimit.isLimitDown(widget.priceChange)) {
          parts.add(S.priceLimitDown);
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
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        DesignTokens.stockCardPadding,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 緊湊模式：縮小字體/圖示/間距
                          final isCompactLayout =
                              constraints.maxWidth <
                              UiConstants.compactCardBreakpoint;
                          // Grid 固定高度時用 Flexible 防止垂直溢出
                          final isHeightConstrained =
                              constraints.maxHeight <
                              DesignTokens.stockCardHeight;
                          // 價格區塊是 Row 中佔最多寬度的元素，
                          // 需要比其他元素更早 compact 以釋放空間給訊號
                          final isCompactPrice =
                              constraints.maxWidth <
                              UiConstants.sparklineMinWidth;
                          // 走勢圖佔 78px，需要比 compact 更寬的門檻
                          final showSparkline =
                              !isCompactPrice &&
                              widget.recentPrices != null &&
                              widget.recentPrices!.length >= 7;

                          return Row(
                            children: [
                              // 趨勢指示器（響應式）
                              _buildTrendIndicator(compact: isCompactLayout),
                              SizedBox(
                                width: isCompactLayout
                                    ? DesignTokens.spacing8
                                    : DesignTokens.spacing12,
                              ),

                              // 股票資訊區塊
                              Expanded(
                                child: Column(
                                  // Grid 固定高度時用 max 才能讓
                                  // Flexible 正確分配剩餘空間
                                  mainAxisSize: isHeightConstrained
                                      ? MainAxisSize.max
                                      : MainAxisSize.min,
                                  // Grid 並排時垂直置中，對齊 Row 中其他
                                  // crossAxisAlignment.center 的元素
                                  mainAxisAlignment: isHeightConstrained
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeader(theme),
                                    if (widget.stockName != null) ...[
                                      const SizedBox(
                                        height: DesignTokens.spacing2,
                                      ),
                                      _buildStockName(theme),
                                    ],
                                    if (widget.reasons.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      if (isHeightConstrained)
                                        Flexible(
                                          child: ClipRect(
                                            child: ReasonTags(
                                              reasons: widget.reasons,
                                              maxTags: isCompactLayout ? 1 : 2,
                                              translateCodes: true,
                                              size: ReasonTagSize.compact,
                                            ),
                                          ),
                                        )
                                      else
                                        ReasonTags(
                                          reasons: widget.reasons,
                                          maxTags: isCompactLayout ? 1 : 2,
                                          translateCodes: true,
                                          size: ReasonTagSize.compact,
                                        ),
                                    ],
                                  ],
                                ),
                              ),

                              SizedBox(
                                width: isCompactLayout
                                    ? DesignTokens.spacing6
                                    : DesignTokens.spacing12,
                              ),

                              // 迷你走勢圖（窄卡片時自動隱藏）
                              if (showSparkline) ...[
                                _buildSparkline(priceColor),
                                const SizedBox(width: 8),
                              ],

                              // 價格區塊（兩級響應式：400px 以下即 compact）
                              StockCardPriceSection(
                                latestClose: widget.latestClose,
                                priceChange: widget.priceChange,
                                showLimitMarkers: widget.showLimitMarkers,
                                priceColor: priceColor,
                                compact: isCompactPrice,
                              ),

                              // 自選按鈕（響應式）
                              if (widget.onWatchlistTap != null)
                                _buildWatchlistButton(
                                  theme,
                                  compact: isCompactLayout,
                                ),
                            ],
                          );
                        },
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

  Widget _buildTrendIndicator({bool compact = false}) {
    final trendColor = widget.trendState.trendColor;
    final icon = widget.trendState.trendIconData;
    final iconSize = compact ? 18.0 : 24.0;

    // 簡化設計：僅圖示，不加背景容器以減少色彩干擾
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Center(
        child: Icon(icon, color: trendColor, size: iconSize),
      ),
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
          const SizedBox(width: 6),
          ScoreRing(score: widget.score!, size: ScoreRingSize.small),
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
              borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
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
              borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
            ),
            child: Text(
              isLimitUp ? S.priceLimitUp : S.priceLimitDown,
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

  /// 建立迷你走勢圖
  ///
  /// 新增防禦性 null 檢查，避免條件判斷與方法呼叫之間的競態條件
  Widget _buildSparkline(Color priceColor) {
    final prices = widget.recentPrices;
    if (prices == null || prices.length < 7) {
      return const SizedBox.shrink();
    }
    return MiniSparkline(prices: prices, color: priceColor);
  }

  Widget _buildWatchlistButton(ThemeData theme, {bool compact = false}) {
    final tooltipText = widget.isInWatchlist
        ? S.watchlistRemoveTooltip
        : S.watchlistAddTooltip;
    final iconSize = compact ? 20.0 : 26.0;
    return Padding(
      padding: EdgeInsets.only(left: compact ? 2 : 4),
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
            size: iconSize,
          ),
          tooltip: tooltipText,
          onPressed: () {
            HapticFeedback.mediumImpact();
            widget.onWatchlistTap?.call();
          },
          constraints: compact
              ? const BoxConstraints(minWidth: 32, minHeight: 32)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          splashRadius: compact ? 16 : 20,
        ),
      ),
    );
  }
}
