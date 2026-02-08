import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/price_limit.dart';

/// 股票卡片的價格區塊 Widget
///
/// 顯示最新收盤價和漲跌幅百分比，包含漲跌停標記。
class StockCardPriceSection extends StatelessWidget {
  const StockCardPriceSection({
    super.key,
    this.latestClose,
    this.priceChange,
    this.showLimitMarkers = true,
    required this.priceColor,
  });

  final double? latestClose;
  final double? priceChange;
  final bool showLimitMarkers;
  final Color priceColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = (priceChange ?? 0) >= 0;
    final isNeutral = priceChange == null || priceChange == 0;
    final isLimitUp = showLimitMarkers && PriceLimit.isLimitUp(priceChange);
    final isLimitDown = showLimitMarkers && PriceLimit.isLimitDown(priceChange);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (latestClose != null)
          Text(
            latestClose!.toStringAsFixed(2),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: DesignTokens.fontSizeXl,
              letterSpacing: 0.5,
              fontFamily: 'RobotoMono',
            ),
          ),
        if (priceChange != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: priceColor.withValues(alpha: isNeutral ? 0.1 : 0.15),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
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
                  '${isPositive && !isNeutral ? '+' : ''}${priceChange!.toStringAsFixed(2)}%',
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
}
