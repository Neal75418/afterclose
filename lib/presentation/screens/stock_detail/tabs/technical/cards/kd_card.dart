import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/indicator_card_container.dart';

class KDCard extends StatelessWidget {
  const KDCard({
    super.key,
    required this.highs,
    required this.lows,
    required this.closes,
    required this.indicatorService,
  });

  final List<double> highs;
  final List<double> lows;
  final List<double> closes;
  final TechnicalIndicatorService indicatorService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kd = indicatorService.calculateKD(highs, lows, closes);
    final latestK = kd.k.lastWhere((v) => v != null, orElse: () => null);
    final latestD = kd.d.lastWhere((v) => v != null, orElse: () => null);

    String kdSignal = 'stockDetail.kdNeutral'.tr();
    Color kdColor = theme.colorScheme.onSurface;
    if (latestK != null && latestD != null) {
      if (latestK > latestD && latestK < 80) {
        kdSignal = 'stockDetail.kdGoldenCross'.tr();
        kdColor = AppTheme.upColor;
      } else if (latestK < latestD && latestK > 20) {
        kdSignal = 'stockDetail.kdDeathCross'.tr();
        kdColor = AppTheme.downColor;
      } else if (latestK >= 80) {
        kdSignal = 'stockDetail.kdOverbought'.tr();
        kdColor = AppTheme.downColor;
      } else if (latestK <= 20) {
        kdSignal = 'stockDetail.kdOversold'.tr();
        kdColor = AppTheme.upColor;
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
                  'KDJ(9,3,3)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kdSignal,
                  style: theme.textTheme.bodySmall?.copyWith(color: kdColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'K: ${latestK?.toStringAsFixed(1) ?? '-'}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                  color: IndicatorColors.chartPrimary,
                ),
              ),
              Text(
                'D: ${latestD?.toStringAsFixed(1) ?? '-'}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                  color: IndicatorColors.chartSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
