import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// 推薦原因標籤的尺寸變體
enum ReasonTagSize {
  /// 精簡尺寸，適用於卡片視圖（較小的間距與文字）
  compact,

  /// 標準尺寸，適用於詳情視圖
  normal,
}

/// 可重用的推薦原因標籤 Widget，具有一致的樣式
class ReasonTags extends StatelessWidget {
  const ReasonTags({
    super.key,
    required this.reasons,
    this.size = ReasonTagSize.normal,
    this.maxTags,
    this.translateCodes = false,
  });

  /// 要顯示的原因標籤或代碼列表
  final List<String> reasons;

  /// 標籤的尺寸變體
  final ReasonTagSize size;

  /// 最多顯示的標籤數量（null = 顯示全部）
  final int? maxTags;

  /// 是否翻譯原因代碼（用於原始資料庫代碼）
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

  /// 將資料庫原因代碼轉換為翻譯後的標籤
  static String translateReasonCode(String code) {
    final key = switch (code) {
      // 原始訊號
      'REVERSAL_W2S' => 'reasons.reversalW2S',
      'REVERSAL_S2W' => 'reasons.reversalS2W',
      'TECH_BREAKOUT' => 'reasons.breakout',
      'TECH_BREAKDOWN' => 'reasons.breakdown',
      'VOLUME_SPIKE' => 'reasons.volumeSpike',
      'PRICE_SPIKE' => 'reasons.priceSpike',
      'INSTITUTIONAL_SHIFT' => 'reasons.institutional',
      'NEWS_RELATED' => 'reasons.news',
      // 第二階段：技術指標
      'KD_GOLDEN_CROSS' => 'reasons.kdGoldenCross',
      'KD_DEATH_CROSS' => 'reasons.kdDeathCross',
      'INSTITUTIONAL_BUY_STREAK' => 'reasons.institutionalBuyStreak',
      'INSTITUTIONAL_SELL_STREAK' => 'reasons.institutionalSellStreak',
      // 第二階段：K 線型態
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
      // 第三階段：52 週高低點與均線排列
      'WEEK_52_HIGH' => 'reasons.week52High',
      'WEEK_52_LOW' => 'reasons.week52Low',
      'MA_ALIGNMENT_BULLISH' => 'reasons.maAlignmentBullish',
      'MA_ALIGNMENT_BEARISH' => 'reasons.maAlignmentBearish',
      'RSI_EXTREME_OVERBOUGHT' => 'reasons.rsiExtremeOverbought',
      'RSI_EXTREME_OVERSOLD' => 'reasons.rsiExtremeOversold',
      // 第四階段：擴展市場資料
      'INSTITUTIONAL_BUY' => 'reasons.institutionalBuy',
      'INSTITUTIONAL_SELL' => 'reasons.institutionalSell',
      'FOREIGN_SHAREHOLDING_INCREASING' =>
        'reasons.foreignShareholdingIncreasing',
      'FOREIGN_SHAREHOLDING_DECREASING' =>
        'reasons.foreignShareholdingDecreasing',
      'DAY_TRADING_HIGH' => 'reasons.dayTradingHigh',
      'DAY_TRADING_EXTREME' => 'reasons.dayTradingExtreme',
      'CONCENTRATION_HIGH' => 'reasons.concentrationHigh',
      // 第五階段：量價背離
      'PRICE_VOLUME_BULLISH_DIVERGENCE' =>
        'reasons.priceVolumeBullishDivergence',
      'PRICE_VOLUME_BEARISH_DIVERGENCE' =>
        'reasons.priceVolumeBearishDivergence',
      'HIGH_VOLUME_BREAKOUT' => 'reasons.highVolumeBreakout',
      'LOW_VOLUME_ACCUMULATION' => 'reasons.lowVolumeAccumulation',
      // 第六階段：基本面訊號
      'REVENUE_YOY_SURGE' => 'reasons.revenueYoySurge',
      'REVENUE_YOY_DECLINE' => 'reasons.revenueYoyDecline',
      'REVENUE_MOM_GROWTH' => 'reasons.revenueMomGrowth',
      'HIGH_DIVIDEND_YIELD' => 'reasons.highDividendYield',
      'PE_UNDERVALUED' => 'reasons.peUndervalued',
      'PE_OVERVALUED' => 'reasons.peOvervalued',
      'PBR_UNDERVALUED' => 'reasons.pbrUndervalued',
      // 第七階段：EPS 分析
      'EPS_YOY_SURGE' => 'reasons.epsYoYSurge',
      'EPS_CONSECUTIVE_GROWTH' => 'reasons.epsConsecutiveGrowth',
      'EPS_TURNAROUND' => 'reasons.epsTurnaround',
      'EPS_DECLINE_WARNING' => 'reasons.epsDeclineWarning',
      // ROE 分析
      'ROE_EXCELLENT' => 'reasons.roeExcellent',
      'ROE_IMPROVING' => 'reasons.roeImproving',
      'ROE_DECLINING' => 'reasons.roeDeclining',
      _ => code, // 未知代碼則回傳原始代碼
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
