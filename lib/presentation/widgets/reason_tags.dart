import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// Size variants for reason tags
enum ReasonTagSize {
  /// Compact size for card views (smaller padding, smaller text)
  compact,

  /// Normal size for detail views
  normal,
}

/// Reusable widget for displaying reason tags with consistent styling
class ReasonTags extends StatelessWidget {
  const ReasonTags({
    super.key,
    required this.reasons,
    this.size = ReasonTagSize.normal,
    this.maxTags,
    this.translateCodes = false,
  });

  /// List of reason labels or codes to display
  final List<String> reasons;

  /// Size variant for the tags
  final ReasonTagSize size;

  /// Maximum number of tags to display (null = show all)
  final int? maxTags;

  /// Whether to translate reason codes (for raw database codes)
  final bool translateCodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayReasons = maxTags != null ? reasons.take(maxTags!) : reasons;

    final isCompact = size == ReasonTagSize.compact;

    return Wrap(
      spacing: isCompact ? 6 : 8,
      runSpacing: isCompact ? 4 : 8,
      children: displayReasons.map((reason) {
        final label = translateCodes ? translateReasonCode(reason) : reason;
        return _ReasonTag(
          label: label,
          isCompact: isCompact,
          isDark: isDark,
          theme: theme,
        );
      }).toList(),
    );
  }

  /// Convert database reason code to translated label
  static String translateReasonCode(String code) {
    final key = switch (code) {
      // Original signals
      'REVERSAL_W2S' => 'reasons.reversalW2S',
      'REVERSAL_S2W' => 'reasons.reversalS2W',
      'TECH_BREAKOUT' => 'reasons.breakout',
      'TECH_BREAKDOWN' => 'reasons.breakdown',
      'VOLUME_SPIKE' => 'reasons.volumeSpike',
      'PRICE_SPIKE' => 'reasons.priceSpike',
      'INSTITUTIONAL_SHIFT' => 'reasons.institutional',
      'NEWS_RELATED' => 'reasons.news',
      // Phase 2: Technical indicators
      'KD_GOLDEN_CROSS' => 'reasons.kdGoldenCross',
      'KD_DEATH_CROSS' => 'reasons.kdDeathCross',
      'INSTITUTIONAL_BUY_STREAK' => 'reasons.institutionalBuyStreak',
      'INSTITUTIONAL_SELL_STREAK' => 'reasons.institutionalSellStreak',
      // Phase 2: Candlestick patterns
      'PATTERN_DOJI' => 'reasons.patternDoji',
      'PATTERN_BULLISH_ENGULFING' => 'reasons.patternBullishEngulfing',
      'PATTERN_BEARISH_ENGULFING' => 'reasons.patternBearishEngulfing',
      'PATTERN_HAMMER' => 'reasons.patternHammer',
      'PATTERN_HANGING_MAN' => 'reasons.patternHangingMan',
      'PATTERN_MORNING_STAR' => 'reasons.patternMorningStar',
      'PATTERN_EVENING_STAR' => 'reasons.patternEveningStar',
      'PATTERN_THREE_WHITE_SOLDIERS' => 'reasons.patternThreeWhiteSoldiers',
      'PATTERN_THREE_BLACK_CROWS' => 'reasons.patternThreeBlackCrows',
      'PATTERN_GAP_UP' => 'reasons.patternGapUp',
      'PATTERN_GAP_DOWN' => 'reasons.patternGapDown',
      // Phase 3: 52-week and MA alignment
      'WEEK_52_HIGH' => 'reasons.week52High',
      'WEEK_52_LOW' => 'reasons.week52Low',
      'MA_ALIGNMENT_BULLISH' => 'reasons.maAlignmentBullish',
      'MA_ALIGNMENT_BEARISH' => 'reasons.maAlignmentBearish',
      'RSI_EXTREME_OVERBOUGHT' => 'reasons.rsiExtremeOverbought',
      'RSI_EXTREME_OVERSOLD' => 'reasons.rsiExtremeOversold',
      // Phase 4: Extended market data
      'FOREIGN_SHAREHOLDING_INCREASING' =>
        'reasons.foreignShareholdingIncreasing',
      'FOREIGN_SHAREHOLDING_DECREASING' =>
        'reasons.foreignShareholdingDecreasing',
      'DAY_TRADING_HIGH' => 'reasons.dayTradingHigh',
      'DAY_TRADING_EXTREME' => 'reasons.dayTradingExtreme',
      'CONCENTRATION_HIGH' => 'reasons.concentrationHigh',
      // Phase 5: Price-volume divergence
      'PRICE_VOLUME_BULLISH_DIVERGENCE' =>
        'reasons.priceVolumeBullishDivergence',
      'PRICE_VOLUME_BEARISH_DIVERGENCE' =>
        'reasons.priceVolumeBearishDivergence',
      'HIGH_VOLUME_BREAKOUT' => 'reasons.highVolumeBreakout',
      'LOW_VOLUME_ACCUMULATION' => 'reasons.lowVolumeAccumulation',
      // Phase 6: Fundamental signals
      'REVENUE_YOY_SURGE' => 'reasons.revenueYoySurge',
      'REVENUE_YOY_DECLINE' => 'reasons.revenueYoyDecline',
      'REVENUE_MOM_GROWTH' => 'reasons.revenueMomGrowth',
      'HIGH_DIVIDEND_YIELD' => 'reasons.highDividendYield',
      'PE_UNDERVALUED' => 'reasons.peUndervalued',
      'PE_OVERVALUED' => 'reasons.peOvervalued',
      'PBR_UNDERVALUED' => 'reasons.pbrUndervalued',
      _ => code, // fallback to original code if unknown
    };
    return key.tr();
  }
}

class _ReasonTag extends StatelessWidget {
  const _ReasonTag({
    required this.label,
    required this.isCompact,
    required this.isDark,
    required this.theme,
  });

  final String label;
  final bool isCompact;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.secondaryColor.withValues(
                alpha: 0.25,
              ) // Increased from 0.15 for better visibility
            : AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
        border: isDark
            ? Border.all(
                color: AppTheme.secondaryColor.withValues(alpha: 0.4),
                width: 1,
              )
            : null,
      ),
      child: Text(
        label,
        style:
            (isCompact
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium)
                ?.copyWith(
                  color: isDark
                      ? AppTheme.secondaryColor
                      : AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
      ),
    );
  }
}
