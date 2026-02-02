import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/indicator_cards.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/indicator_selectors.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/ohlcv_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/k_line_chart_widget.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// Technical analysis tab - K-line chart + indicators + volume
class TechnicalTab extends ConsumerStatefulWidget {
  const TechnicalTab({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<TechnicalTab> createState() => _TechnicalTabState();
}

class _TechnicalTabState extends ConsumerState<TechnicalTab> {
  // Main indicators (overlaid on K-line chart): MA, BOLL
  final Set<MainState> _mainIndicators = {MainState.MA};
  // Secondary indicators (sub-charts): MACD, KDJ, RSI, WR, CCI
  final Set<SecondaryState> _secondaryIndicators = {};

  final TechnicalIndicatorService _indicatorService =
      TechnicalIndicatorService();

  void _toggleMainIndicator(MainState indicator) {
    setState(() {
      if (_mainIndicators.contains(indicator)) {
        _mainIndicators.remove(indicator);
      } else {
        _mainIndicators.add(indicator);
      }
    });
  }

  void _toggleSecondaryIndicator(SecondaryState indicator) {
    setState(() {
      if (_secondaryIndicators.contains(indicator)) {
        _secondaryIndicators.remove(indicator);
      } else {
        _secondaryIndicators.add(indicator);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockDetailProvider(widget.symbol));
    final theme = Theme.of(context);

    if (state.priceHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.candlestick_chart_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'stockDetail.noTechnicalData'.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate chart height based on selected secondary indicators
    const baseHeight = 350.0;
    final secondaryHeight = _secondaryIndicators.isEmpty
        ? 0.0
        : 120.0 * _secondaryIndicators.length;
    final totalChartHeight = baseHeight + secondaryHeight;

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // K-line chart section
          SectionHeader(
            title: 'stockDetail.klineChart'.tr(),
            icon: Icons.candlestick_chart,
          ),
          const SizedBox(height: 12),

          // Main indicator selector (MA, BOLL)
          MainIndicatorSelector(
            selectedIndicators: _mainIndicators,
            onToggle: _toggleMainIndicator,
          ),
          const SizedBox(height: 8),

          // K-line chart with indicators
          KLineChartWidget(
            priceHistory: state.priceHistory,
            mainIndicators: _mainIndicators,
            secondaryIndicators: _secondaryIndicators,
            height: totalChartHeight,
            maDayList: const [5, 10, 20, 60],
          ),
          const SizedBox(height: 16),

          // Secondary indicator selector (RSI, KD, MACD)
          SectionHeader(
            title: 'stockDetail.secondaryIndicators'.tr(),
            icon: Icons.show_chart,
          ),
          const SizedBox(height: 8),
          SecondaryIndicatorSelector(
            selectedIndicators: _secondaryIndicators,
            onToggle: _toggleSecondaryIndicator,
          ),
          const SizedBox(height: 16),

          // OHLCV data card
          OhlcvCard(
            latestPrice: state.latestPrice,
            priceChange: state.priceChange,
          ),

          // Detailed indicator values
          if (_secondaryIndicators.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(
              title: 'stockDetail.indicatorValues'.tr(),
              icon: Icons.analytics,
            ),
            const SizedBox(height: 12),
            IndicatorCardsSection(
              priceHistory: state.priceHistory,
              secondaryIndicators: _secondaryIndicators,
              mainIndicators: _mainIndicators,
              indicatorService: _indicatorService,
            ),
          ],
        ],
      ),
    );
  }
}
