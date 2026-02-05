import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

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
          _RSICard(prices: prices, indicatorService: indicatorService),
        if (secondaryIndicators.contains(SecondaryState.KDJ))
          _KDCard(
            highs: highs,
            lows: lows,
            closes: prices,
            indicatorService: indicatorService,
          ),
        if (secondaryIndicators.contains(SecondaryState.MACD))
          _MACDCard(prices: prices, indicatorService: indicatorService),
        if (mainIndicators.contains(MainState.BOLL))
          _BollingerCard(prices: prices, indicatorService: indicatorService),

        // 進階指標：OBV 與 ATR（總是顯示）
        if (volumes.length >= 2)
          _OBVCard(
            closes: prices,
            volumes: volumes,
            indicatorService: indicatorService,
          ),
        if (highs.length >= 14 && lows.length >= 14 && prices.length >= 14)
          _ATRCard(
            highs: highs,
            lows: lows,
            closes: prices,
            indicatorService: indicatorService,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _RSICard extends StatelessWidget {
  const _RSICard({required this.prices, required this.indicatorService});

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

    return _IndicatorCardContainer(
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

class _KDCard extends StatelessWidget {
  const _KDCard({
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

    return _IndicatorCardContainer(
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
                  color: const Color(0xFF60A5FA),
                ),
              ),
              Text(
                'D: ${latestD?.toStringAsFixed(1) ?? '-'}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                  color: const Color(0xFFFACC15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MACDCard extends StatelessWidget {
  const _MACDCard({required this.prices, required this.indicatorService});

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

    return _IndicatorCardContainer(
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
              _LabeledValue(
                label: 'DIF',
                value: latestMACD,
                color: const Color(0xFF60A5FA),
              ),
              _LabeledValue(
                label: 'DEA',
                value: latestSignal,
                color: const Color(0xFFFACC15),
              ),
              _LabeledValue(
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

class _BollingerCard extends StatelessWidget {
  const _BollingerCard({required this.prices, required this.indicatorService});

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

    return _IndicatorCardContainer(
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
              _LabeledValue(
                label: 'stockDetail.bollUpper'.tr(),
                value: latestUpper,
                color: AppTheme.downColor,
              ),
              _LabeledValue(
                label: 'stockDetail.bollMiddle'.tr(),
                value: latestMiddle,
                color: theme.colorScheme.onSurface,
              ),
              _LabeledValue(
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

class _OBVCard extends StatelessWidget {
  const _OBVCard({
    required this.closes,
    required this.volumes,
    required this.indicatorService,
  });

  final List<double> closes;
  final List<double> volumes;
  final TechnicalIndicatorService indicatorService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obv = indicatorService.calculateOBV(closes, volumes);

    if (obv.length < 5) {
      return const SizedBox.shrink();
    }

    final latestOBV = obv.last;
    final previousOBV = obv.length >= 5 ? obv[obv.length - 5] : obv.first;
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

    // 格式化 OBV 值（可能很大）
    String formatOBV(double value) {
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

    return _IndicatorCardContainer(
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'stockDetail.obvLabel'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
                formatOBV(latestOBV),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                  color: obvColor,
                ),
              ),
              Text(
                '${obvChange >= 0 ? "+" : ""}${formatOBV(obvChange)} (5d)',
                style: theme.textTheme.labelSmall?.copyWith(color: obvColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ATRCard extends StatelessWidget {
  const _ATRCard({
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
    final atr = indicatorService.calculateATR(highs, lows, closes);
    final latestATR = atr.lastWhere((v) => v != null, orElse: () => null);
    final currentPrice = closes.isNotEmpty ? closes.last : null;

    if (latestATR == null || currentPrice == null || currentPrice == 0) {
      return const SizedBox.shrink();
    }

    // 計算 ATR 佔股價的百分比（波動性指標）
    final atrPercent = (latestATR / currentPrice) * 100;

    String volatilityLevel;
    Color volatilityColor;
    if (atrPercent < 2) {
      volatilityLevel = 'stockDetail.atrLow'.tr();
      volatilityColor = const Color(0xFF10B981); // Green
    } else if (atrPercent < 4) {
      volatilityLevel = 'stockDetail.atrMedium'.tr();
      volatilityColor = const Color(0xFFF59E0B); // Yellow
    } else {
      volatilityLevel = 'stockDetail.atrHigh'.tr();
      volatilityColor = const Color(0xFFEF4444); // Red
    }

    return _IndicatorCardContainer(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ATR(14)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'stockDetail.atrLabel'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'stockDetail.volatility'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: volatilityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        volatilityLevel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: volatilityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latestATR.toStringAsFixed(2),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                ),
              ),
              Text(
                '${atrPercent.toStringAsFixed(2)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: volatilityColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

/// Glassmorphism-style card container used by all indicator cards.
class _IndicatorCardContainer extends StatelessWidget {
  const _IndicatorCardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A label + value column used in MACD and Bollinger cards.
class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
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
}
