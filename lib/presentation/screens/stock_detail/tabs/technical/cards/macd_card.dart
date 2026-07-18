import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/core/utils/number_formatter.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/indicator_card_container.dart';

class MACDCard extends StatelessWidget {
  const MACDCard({super.key, required this.macd});

  final ({List<double?> macd, List<double?> signal, List<double?> histogram})
  macd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    // 與顯示文字同精度捨入後判方向：零軸穿越（histogram≈0）著中性色而非漲色
    final histColor = latestHist == null
        ? AppTheme.getFlatColor(theme.brightness)
        : AppTheme.getPriceColor(
            AppNumberFormat.roundForDisplay(latestHist, 2),
            theme.brightness,
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
                    const SizedBox(height: DesignTokens.spacing4),
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
                    ? AppNumberFormat.signedFixed(latestHist, decimals: 2)
                    : '-',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                  color: histColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing8),
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
              LabeledValue(label: 'HIST', value: latestHist, color: histColor),
            ],
          ),
        ],
      ),
    );
  }
}
