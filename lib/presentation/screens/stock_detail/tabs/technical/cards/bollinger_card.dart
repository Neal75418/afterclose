import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/indicator_card_container.dart';

class BollingerCard extends StatelessWidget {
  const BollingerCard({
    super.key,
    required this.prices,
    required this.indicatorService,
  });

  final List<double> prices;
  final TechnicalIndicatorService indicatorService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boll = indicatorService.calculateBollingerBands(prices);
    final latestUpper = boll.upper.lastWhere(
      (v) => v != null,
      orElse: () => null,
    );
    final latestMiddle = boll.middle.lastWhere(
      (v) => v != null,
      orElse: () => null,
    );
    final latestLower = boll.lower.lastWhere(
      (v) => v != null,
      orElse: () => null,
    );
    final currentPrice = prices.isNotEmpty ? prices.last : null;

    String bollSignal = 'stockDetail.bollNeutral'.tr();
    Color bollColor = theme.colorScheme.onSurface;
    if (currentPrice != null && latestUpper != null && latestLower != null) {
      if (currentPrice >= latestUpper) {
        bollSignal = 'stockDetail.bollOverbought'.tr();
        bollColor = AppTheme.downColor;
      } else if (currentPrice <= latestLower) {
        bollSignal = 'stockDetail.bollOversold'.tr();
        bollColor = AppTheme.upColor;
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
                      'BOLL(20,2)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bollSignal,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: bollColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              LabeledValue(
                label: 'stockDetail.bollUpper'.tr(),
                value: latestUpper,
                color: AppTheme.downColor,
              ),
              LabeledValue(
                label: 'stockDetail.bollMiddle'.tr(),
                value: latestMiddle,
                color: theme.colorScheme.onSurface,
              ),
              LabeledValue(
                label: 'stockDetail.bollLower'.tr(),
                value: latestLower,
                color: AppTheme.upColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
