import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/indicator_card_container.dart';

class MACDCard extends StatelessWidget {
  const MACDCard({
    super.key,
    required this.prices,
    required this.indicatorService,
  });

  final List<double> prices;
  final TechnicalIndicatorService indicatorService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macd = indicatorService.calculateMACD(prices);
    final latestMACD = macd.macd.lastWhere(
      (v) => v != null,
      orElse: () => null,
    );
    final latestSignal = macd.signal.lastWhere(
      (v) => v != null,
      orElse: () => null,
    );
    final latestHist = macd.histogram.lastWhere(
      (v) => v != null,
      orElse: () => null,
    );

    String macdSignal = 'stockDetail.macdNeutral'.tr();
    Color macdColor = theme.colorScheme.onSurface;
    if (latestMACD != null && latestSignal != null) {
      if (latestMACD > latestSignal) {
        macdSignal = 'stockDetail.macdBullish'.tr();
        macdColor = AppTheme.upColor;
      } else {
        macdSignal = 'stockDetail.macdBearish'.tr();
        macdColor = AppTheme.downColor;
      }
    }

    return IndicatorCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MACD(12,26,9)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      macdSignal,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: macdColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                latestHist != null
                    ? (latestHist >= 0 ? '+' : '') +
                          latestHist.toStringAsFixed(2)
                    : '-',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                  color: (latestHist ?? 0) >= 0
                      ? AppTheme.upColor
                      : AppTheme.downColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              LabeledValue(
                label: 'DIF',
                value: latestMACD,
                color: IndicatorColors.chartPrimary,
              ),
              LabeledValue(
                label: 'DEA',
                value: latestSignal,
                color: IndicatorColors.chartSecondary,
              ),
              LabeledValue(
                label: 'HIST',
                value: latestHist,
                color: (latestHist ?? 0) >= 0
                    ? AppTheme.upColor
                    : AppTheme.downColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
