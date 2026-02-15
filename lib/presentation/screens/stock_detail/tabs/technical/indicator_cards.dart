import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/rsi_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/kd_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/macd_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/bollinger_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/obv_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/atr_card.dart';

/// Displays detailed indicator value cards (RSI, KDJ, MACD, Bollinger)
/// based on the selected secondary and main indicators.
class IndicatorCardsSection extends StatelessWidget {
  const IndicatorCardsSection({
    super.key,
    required this.priceHistory,
    required this.secondaryIndicators,
    required this.mainIndicators,
    required this.indicatorService,
  });

  final List<DailyPriceEntry> priceHistory;
  final Set<SecondaryState> secondaryIndicators;
  final Set<MainState> mainIndicators;
  final TechnicalIndicatorService indicatorService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prices = priceHistory
        .where((p) => p.close != null)
        .map((p) => p.close!)
        .toList();

    if (prices.length < 14) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'stockDetail.insufficientData'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final highs = priceHistory
        .where((p) => p.high != null)
        .map((p) => p.high!)
        .toList();
    final lows = priceHistory
        .where((p) => p.low != null)
        .map((p) => p.low!)
        .toList();

    final volumes = priceHistory
        .where((p) => p.volume != null)
        .map((p) => p.volume!)
        .toList();

    return Column(
      children: [
        if (secondaryIndicators.contains(SecondaryState.RSI))
          RSICard(prices: prices, indicatorService: indicatorService),
        if (secondaryIndicators.contains(SecondaryState.KDJ))
          KDCard(
            highs: highs,
            lows: lows,
            closes: prices,
            indicatorService: indicatorService,
          ),
        if (secondaryIndicators.contains(SecondaryState.MACD))
          MACDCard(prices: prices, indicatorService: indicatorService),
        if (mainIndicators.contains(MainState.BOLL))
          BollingerCard(prices: prices, indicatorService: indicatorService),

        // 進階指標：OBV 與 ATR（總是顯示）
        if (volumes.length >= 2)
          OBVCard(
            closes: prices,
            volumes: volumes,
            indicatorService: indicatorService,
          ),
        if (highs.length >= 14 && lows.length >= 14 && prices.length >= 14)
          ATRCard(
            highs: highs,
            lows: lows,
            closes: prices,
            indicatorService: indicatorService,
          ),
      ],
    );
  }
}
