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

/// 從 priceHistory 提取的 OHLCV 快取，避免每次 build 重複 filter/map
class _ExtractedPrices {
  _ExtractedPrices(List<DailyPriceEntry> history)
    : prices = history
          .where((p) => p.close != null)
          .map((p) => p.close!)
          .toList(),
      highs = history.where((p) => p.high != null).map((p) => p.high!).toList(),
      lows = history.where((p) => p.low != null).map((p) => p.low!).toList(),
      volumes = history
          .where((p) => p.volume != null)
          .map((p) => p.volume!.toDouble())
          .toList();

  final List<double> prices;
  final List<double> highs;
  final List<double> lows;
  final List<double> volumes;
}

/// 根據選擇的副指標與主指標，顯示詳細的技術指標卡片
/// （RSI、KDJ、MACD、Bollinger）。
class IndicatorCardsSection extends StatefulWidget {
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
  State<IndicatorCardsSection> createState() => _IndicatorCardsSectionState();
}

class _IndicatorCardsSectionState extends State<IndicatorCardsSection> {
  _ExtractedPrices? _cached;
  List<DailyPriceEntry>? _lastHistory;

  _ExtractedPrices _getExtracted() {
    if (!identical(_lastHistory, widget.priceHistory)) {
      _lastHistory = widget.priceHistory;
      _cached = _ExtractedPrices(widget.priceHistory);
    }
    return _cached!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extracted = _getExtracted();
    final prices = extracted.prices;

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

    final highs = extracted.highs;
    final lows = extracted.lows;

    final volumes = extracted.volumes;

    return Column(
      children: [
        if (widget.secondaryIndicators.contains(SecondaryState.RSI))
          RSICard(prices: prices, indicatorService: widget.indicatorService),
        if (widget.secondaryIndicators.contains(SecondaryState.KDJ))
          KDCard(
            highs: highs,
            lows: lows,
            closes: prices,
            indicatorService: widget.indicatorService,
          ),
        if (widget.secondaryIndicators.contains(SecondaryState.MACD))
          MACDCard(prices: prices, indicatorService: widget.indicatorService),
        if (widget.mainIndicators.contains(MainState.BOLL))
          BollingerCard(
            prices: prices,
            indicatorService: widget.indicatorService,
          ),

        // 進階指標：OBV 與 ATR（總是顯示）
        if (volumes.length >= 2)
          OBVCard(
            closes: prices,
            volumes: volumes,
            indicatorService: widget.indicatorService,
          ),
        if (highs.length >= 14 && lows.length >= 14 && prices.length >= 14)
          ATRCard(
            highs: highs,
            lows: lows,
            closes: prices,
            indicatorService: widget.indicatorService,
          ),
      ],
    );
  }
}
