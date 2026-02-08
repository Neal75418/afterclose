import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/price_limit.dart';

/// 股票卡片的價格區塊 Widget
///
/// 顯示最新收盤價、絕對漲跌金額與漲跌幅百分比，包含漲跌停標記。
/// 格式符合台股慣例：▲2.50 (+1.67%)
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

  /// 從收盤價與漲跌幅百分比反算絕對漲跌金額
  double? get _absoluteChange {
    if (latestClose == null || priceChange == null || priceChange == 0) {
      return null;
    }
    // prevClose = latestClose / (1 + pct/100)
    // absoluteChange = latestClose - prevClose
    return latestClose! * priceChange! / (100 + priceChange!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = (priceChange ?? 0) >= 0;
    final isNeutral = priceChange == null || priceChange == 0;
    final isLimitUp = showLimitMarkers && PriceLimit.isLimitUp(priceChange);
    final isLimitDown = showLimitMarkers && PriceLimit.isLimitDown(priceChange);
    final absChange = _absoluteChange;

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
                  _formatChangeText(absChange, isPositive, isNeutral),
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

  /// 格式化漲跌文字：有絕對金額時顯示「2.50 (+1.67%)」，否則僅顯示百分比
  String _formatChangeText(double? absChange, bool isPositive, bool isNeutral) {
    final sign = isPositive && !isNeutral ? '+' : '';
    final pctText = '$sign${priceChange!.toStringAsFixed(2)}%';
    if (absChange != null) {
      final absText = '${isPositive ? '+' : ''}${absChange.toStringAsFixed(2)}';
      return '$absText ($pctText)';
    }
    return pctText;
  }
}
