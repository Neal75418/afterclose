import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/indicator_card_container.dart';

class OBVCard extends StatelessWidget {
  const OBVCard({super.key, required this.obv});

  final List<double?> obv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nonNullObv = obv.whereType<double>().toList();
    if (nonNullObv.length < 5) {
      return const SizedBox.shrink();
    }

    final latestOBV = nonNullObv.last;
    final previousOBV = nonNullObv.length >= 5
        ? nonNullObv[nonNullObv.length - 5]
        : nonNullObv.first;
    final obvChange = latestOBV - previousOBV;
    final obvTrend = obvChange > 0
        ? 'stockDetail.obvRising'.tr()
        : obvChange < 0
        ? 'stockDetail.obvFalling'.tr()
        : 'stockDetail.obvNeutral'.tr();

    Color obvColor = theme.colorScheme.onSurface;
    if (obvChange > 0) {
      obvColor = AppTheme.upColor;
    } else if (obvChange < 0) {
      obvColor = AppTheme.downColor;
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
                      'OBV',
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
                        color: IndicatorColors.obvLabel.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusXs,
                        ),
                      ),
                      child: Text(
                        'stockDetail.obvLabel'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: IndicatorColors.obvLabel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacing4),
                Text(
                  obvTrend,
                  style: theme.textTheme.bodySmall?.copyWith(color: obvColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatOBV(latestOBV),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                  color: obvColor,
                ),
              ),
              Text(
                '${obvChange >= 0 ? "+" : ""}${_formatOBV(obvChange)} (5d)',
                style: theme.textTheme.labelSmall?.copyWith(color: obvColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatOBV(double value) {
    final absValue = value.abs();
    if (absValue >= 1e9) {
      return '${(value / 1e9).toStringAsFixed(1)}B';
    } else if (absValue >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(1)}M';
    } else if (absValue >= 1e3) {
      return '${(value / 1e3).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
