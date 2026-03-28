import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/indicator_card_container.dart';

class ATRCard extends StatelessWidget {
  const ATRCard({super.key, required this.atr, required this.currentPrice});

  final List<double?> atr;
  final double? currentPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestATR = atr.lastWhere((v) => v != null, orElse: () => null);
    final price = currentPrice;

    if (latestATR == null || price == null || price == 0) {
      return const SizedBox.shrink();
    }

    final atrPercent = (latestATR / price) * 100;

    String volatilityLevel;
    Color volatilityColor;
    if (atrPercent < 2) {
      volatilityLevel = 'stockDetail.atrLow'.tr();
      volatilityColor = IndicatorColors.volatilityLow;
    } else if (atrPercent < 4) {
      volatilityLevel = 'stockDetail.atrMedium'.tr();
      volatilityColor = IndicatorColors.volatilityMedium;
    } else {
      volatilityLevel = 'stockDetail.atrHigh'.tr();
      volatilityColor = IndicatorColors.volatilityHigh;
    }

    return IndicatorCardContainer(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ATR(14)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: IndicatorColors.atrLabel.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusXs,
                        ),
                      ),
                      child: Text(
                        'stockDetail.atrLabel'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: IndicatorColors.atrLabel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacing4),
                Row(
                  children: [
                    Text(
                      'stockDetail.volatility'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: volatilityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusXs,
                        ),
                      ),
                      child: Text(
                        volatilityLevel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: volatilityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latestATR.toStringAsFixed(2),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                ),
              ),
              Text(
                '${atrPercent.toStringAsFixed(2)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: volatilityColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
