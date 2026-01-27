import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
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
          _buildMainIndicatorSelector(context),
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
          _buildSecondaryIndicatorSelector(context),
          const SizedBox(height: 16),

          // OHLCV data card
          _buildOHLCVCard(context, state),

          // Detailed indicator values
          if (_secondaryIndicators.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(
              title: 'stockDetail.indicatorValues'.tr(),
              icon: Icons.analytics,
            ),
            const SizedBox(height: 12),
            _buildIndicatorCards(context, state),
          ],
        ],
      ),
    );
  }

  Widget _buildMainIndicatorSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'stockDetail.mainChart'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMainIndicatorChip(
                  MainState.MA,
                  'MA',
                  const Color(0xFF3498DB),
                ),
                _buildMainIndicatorChip(
                  MainState.BOLL,
                  'BOLL',
                  const Color(0xFF9B59B6),
                ),
                _buildMainIndicatorChip(
                  MainState.SAR,
                  'SAR',
                  const Color(0xFFE67E22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainIndicatorChip(
    MainState indicator,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isSelected = _mainIndicators.contains(indicator);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _mainIndicators.remove(indicator);
          } else {
            _mainIndicators.add(indicator);
          }
        });
      },
      child: AnimatedContainer(
        duration: AnimDurations.standard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? color : theme.colorScheme.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryIndicatorSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            'stockDetail.subChart'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSecondaryIndicatorChip(
                  SecondaryState.MACD,
                  'MACD',
                  const Color(0xFF3498DB),
                ),
                _buildSecondaryIndicatorChip(
                  SecondaryState.KDJ,
                  'KDJ',
                  const Color(0xFFE67E22),
                ),
                _buildSecondaryIndicatorChip(
                  SecondaryState.RSI,
                  'RSI',
                  const Color(0xFF9B59B6),
                ),
                _buildSecondaryIndicatorChip(
                  SecondaryState.WR,
                  'WR',
                  const Color(0xFF1ABC9C),
                ),
                _buildSecondaryIndicatorChip(
                  SecondaryState.CCI,
                  'CCI',
                  const Color(0xFFE74C3C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryIndicatorChip(
    SecondaryState indicator,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isSelected = _secondaryIndicators.contains(indicator);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _secondaryIndicators.remove(indicator);
          } else {
            _secondaryIndicators.add(indicator);
          }
        });
      },
      child: AnimatedContainer(
        duration: AnimDurations.standard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? color : theme.colorScheme.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorCards(BuildContext context, StockDetailState state) {
    final theme = Theme.of(context);
    final prices = state.priceHistory
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

    final highs = state.priceHistory
        .where((p) => p.high != null)
        .map((p) => p.high!)
        .toList();
    final lows = state.priceHistory
        .where((p) => p.low != null)
        .map((p) => p.low!)
        .toList();

    return Column(
      children: [
        // RSI Card
        if (_secondaryIndicators.contains(SecondaryState.RSI))
          _buildRSICard(context, prices),
        // KDJ Card
        if (_secondaryIndicators.contains(SecondaryState.KDJ))
          _buildKDCard(context, highs, lows, prices),
        // MACD Card
        if (_secondaryIndicators.contains(SecondaryState.MACD))
          _buildMACDCard(context, prices),
        // Bollinger Bands Card (if BOLL is in main indicators)
        if (_mainIndicators.contains(MainState.BOLL))
          _buildBollingerCard(context, prices),
      ],
    );
  }

  Widget _buildRSICard(BuildContext context, List<double> prices) {
    final theme = Theme.of(context);
    final rsi = _indicatorService.calculateRSI(prices);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: rsiColor,
                        ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildKDCard(
    BuildContext context,
    List<double> highs,
    List<double> lows,
    List<double> closes,
  ) {
    final theme = Theme.of(context);
    final kd = _indicatorService.calculateKD(highs, lows, closes);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kdColor,
                        ),
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
                        color: const Color(0xFF60A5FA), // Match chart color
                      ),
                    ),
                    Text(
                      'D: ${latestD?.toStringAsFixed(1) ?? '-'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'RobotoMono',
                        color: const Color(0xFFFACC15), // Match chart color
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMACDCard(BuildContext context, List<double> prices) {
    final theme = Theme.of(context);
    final macd = _indicatorService.calculateMACD(prices);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
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
                    _buildMACDValue(
                      context,
                      'DIF',
                      latestMACD,
                      const Color(0xFF60A5FA), // Blue 400
                    ),
                    _buildMACDValue(
                      context,
                      'DEA',
                      latestSignal,
                      const Color(0xFFFACC15), // Yellow 400
                    ),
                    _buildMACDValue(
                      context,
                      'HIST',
                      latestHist,
                      (latestHist ?? 0) >= 0
                          ? AppTheme.upColor
                          : AppTheme.downColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMACDValue(
    BuildContext context,
    String label,
    double? value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            // Use onSurfaceVariant for better visibility in dark mode
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value?.toStringAsFixed(2) ?? '-',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBollingerCard(BuildContext context, List<double> prices) {
    final theme = Theme.of(context);
    final boll = _indicatorService.calculateBollingerBands(prices);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
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
                    _buildBollValue(
                      context,
                      'stockDetail.bollUpper'.tr(),
                      latestUpper,
                      AppTheme.downColor,
                    ),
                    _buildBollValue(
                      context,
                      'stockDetail.bollMiddle'.tr(),
                      latestMiddle,
                      theme.colorScheme.onSurface,
                    ),
                    _buildBollValue(
                      context,
                      'stockDetail.bollLower'.tr(),
                      latestLower,
                      AppTheme.upColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBollValue(
    BuildContext context,
    String label,
    double? value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            // Use onSurfaceVariant for better visibility in dark mode
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value?.toStringAsFixed(2) ?? '-',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildOHLCVCard(BuildContext context, StockDetailState state) {
    final theme = Theme.of(context);
    final latestPrice = state.latestPrice;
    final priceChange = state.priceChange;
    final isUp = (priceChange ?? 0) >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.candlestick_chart,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'stockDetail.todayTrading'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (priceChange != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isUp ? AppTheme.upColor : AppTheme.downColor)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUp ? Icons.trending_up : Icons.trending_down,
                          size: 14,
                          color: isUp ? AppTheme.upColor : AppTheme.downColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isUp ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isUp ? AppTheme.upColor : AppTheme.downColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Price grid
            Row(
              children: [
                Expanded(
                  child: _buildPriceCell(
                    context,
                    'stockDetail.open'.tr(),
                    latestPrice?.open,
                    theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _buildPriceCell(
                    context,
                    'stockDetail.high'.tr(),
                    latestPrice?.high,
                    AppTheme.upColor,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: theme.colorScheme.outlineVariant),
            Row(
              children: [
                Expanded(
                  child: _buildPriceCell(
                    context,
                    'stockDetail.low'.tr(),
                    latestPrice?.low,
                    AppTheme.downColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _buildPriceCell(
                    context,
                    'stockDetail.close'.tr(),
                    latestPrice?.close,
                    isUp ? AppTheme.upColor : AppTheme.downColor,
                    isBold: true,
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: theme.colorScheme.outlineVariant),
            // Volume
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'stockDetail.volume'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatVolumeOrDash(latestPrice?.volume),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCell(
    BuildContext context,
    String label,
    double? value,
    Color valueColor, {
    bool isBold = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            // Use onSurfaceVariant for better visibility in dark mode
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value?.toStringAsFixed(2) ?? '-',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  /// 格式化成交量（股 → 張）
  /// 格式化成交量（處理 null）
  String _formatVolumeOrDash(double? volume) {
    if (volume == null) return '-';
    return _formatVolume(volume);
  }

  /// 格式化成交量為台灣習慣的「張」單位
  ///
  /// API 回傳單位為「股」，台灣股市習慣用「張」（1張 = 1000股）
  String _formatVolume(double volume) {
    // 先轉為張
    final lots = volume / 1000;

    if (lots >= 10000) {
      // 萬張
      return '${(lots / 10000).toStringAsFixed(1)}${'stockDetail.unitTenThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    } else if (lots >= 1000) {
      // 千張
      return '${(lots / 1000).toStringAsFixed(1)}${'stockDetail.unitThousand'.tr()}${'stockDetail.unitShares'.tr()}';
    } else if (lots >= 1) {
      // 張
      return '${lots.toStringAsFixed(0)}${'stockDetail.unitShares'.tr()}';
    }
    // 不足 1 張，顯示股數
    return volume.toStringAsFixed(0);
  }
}
