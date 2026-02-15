import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/indicator_card_container.dart';

class RSICard extends StatelessWidget {
  const RSICard({
    super.key,
    required this.prices,
    required this.indicatorService,
  });

  final List<double> prices;
  final TechnicalIndicatorService indicatorService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rsi = indicatorService.calculateRSI(prices);
    final latestRSI = rsi.lastWhere((v) => v != null, orElse: () => null);

    Color rsiColor = theme.colorScheme.onSurface;
    String rsiSignal = 'stockDetail.rsiNeutral'.tr();
    if (latestRSI != null) {
      if (latestRSI >= 70) {
        rsiColor = AppTheme.downColor;
        rsiSignal = 'stockDetail.rsiOverbought'.tr();
      } else if (latestRSI <= 30) {
        rsiColor = AppTheme.upColor;
        rsiSignal = 'stockDetail.rsiOversold'.tr();
      }
    }

    return IndicatorCardContainer(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RSI(14)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rsiSignal,
                  style: theme.textTheme.bodySmall?.copyWith(color: rsiColor),
                ),
              ],
            ),
          ),
          Text(
            latestRSI?.toStringAsFixed(1) ?? '-',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'RobotoMono',
              color: rsiColor,
            ),
          ),
        ],
      ),
    );
  }
}
