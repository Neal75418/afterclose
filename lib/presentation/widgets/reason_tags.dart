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
        final tooltip = translateCodes ? tooltipForReasonCode(reason) : null;
        return _ReasonTag(
          label: label,
          tooltip: tooltip,
          isCompact: isCompact,
          isDark: isDark,
          theme: theme,
        );
      }).toList(),
    );
  }

  /// 將資料庫原因代碼轉換為翻譯後的標籤
  ///
  /// 支援 SNAKE_CASE（DB 原始碼）與 camelCase（JSON 格式）兩種格式。
  static String translateReasonCode(String code) {
    final key = switch (code) {
      // 原始訊號
      'REVERSAL_W2S' || 'reversalW2S' => 'reasons.reversalW2S',
      'REVERSAL_S2W' || 'reversalS2W' => 'reasons.reversalS2W',
      'TECH_BREAKOUT' || 'techBreakout' => 'reasons.breakout',
      'TECH_BREAKDOWN' || 'techBreakdown' => 'reasons.breakdown',
      'VOLUME_SPIKE' || 'volumeSpike' => 'reasons.volumeSpike',
      'PRICE_SPIKE' || 'priceSpike' => 'reasons.priceSpike',
      'INSTITUTIONAL_SHIFT' || 'institutionalShift' => 'reasons.institutional',
      'NEWS_RELATED' || 'newsRelated' => 'reasons.news',
      // 技術指標
      'KD_GOLDEN_CROSS' || 'kdGoldenCross' => 'reasons.kdGoldenCross',
      'KD_DEATH_CROSS' || 'kdDeathCross' => 'reasons.kdDeathCross',
      'INSTITUTIONAL_BUY_STREAK' ||
      'institutionalBuyStreak' => 'reasons.institutionalBuyStreak',
      'INSTITUTIONAL_SELL_STREAK' ||
      'institutionalSellStreak' => 'reasons.institutionalSellStreak',
      // K 線型態
      'PATTERN_DOJI' || 'patternDoji' => 'reasons.patternDoji',
      'PATTERN_BULLISH_ENGULFING' ||
      'patternBullishEngulfing' => 'reasons.patternBullishEngulfing',
      'PATTERN_BEARISH_ENGULFING' ||
      'patternBearishEngulfing' => 'reasons.patternBearishEngulfing',
      'PATTERN_HAMMER' || 'patternHammer' => 'reasons.patternHammer',
      'PATTERN_HANGING_MAN' ||
      'patternHangingMan' => 'reasons.patternHangingMan',
      'PATTERN_MORNING_STAR' ||
      'patternMorningStar' => 'reasons.patternMorningStar',
      'PATTERN_EVENING_STAR' ||
      'patternEveningStar' => 'reasons.patternEveningStar',
      'PATTERN_THREE_WHITE_SOLDIERS' ||
      'patternThreeWhiteSoldiers' => 'reasons.patternThreeWhiteSoldiers',
      'PATTERN_THREE_BLACK_CROWS' ||
      'patternThreeBlackCrows' => 'reasons.patternThreeBlackCrows',
      'PATTERN_GAP_UP' || 'patternGapUp' => 'reasons.patternGapUp',
      'PATTERN_GAP_DOWN' || 'patternGapDown' => 'reasons.patternGapDown',
      // 52 週高低點與均線排列
      'WEEK_52_HIGH' || 'week52High' => 'reasons.week52High',
      'WEEK_52_LOW' || 'week52Low' => 'reasons.week52Low',
      'MA_ALIGNMENT_BULLISH' ||
      'maAlignmentBullish' => 'reasons.maAlignmentBullish',
      'MA_ALIGNMENT_BEARISH' ||
      'maAlignmentBearish' => 'reasons.maAlignmentBearish',
      'RSI_EXTREME_OVERBOUGHT' ||
      'rsiExtremeOverbought' => 'reasons.rsiExtremeOverbought',
      'RSI_EXTREME_OVERSOLD' ||
      'rsiExtremeOversold' => 'reasons.rsiExtremeOversold',
      // 擴展市場資料
      'INSTITUTIONAL_BUY' || 'institutionalBuy' => 'reasons.institutionalBuy',
      'INSTITUTIONAL_SELL' ||
      'institutionalSell' => 'reasons.institutionalSell',
      'FOREIGN_SHAREHOLDING_INCREASING' || 'foreignShareholdingIncreasing' =>
        'reasons.foreignShareholdingIncreasing',
      'FOREIGN_SHAREHOLDING_DECREASING' || 'foreignShareholdingDecreasing' =>
        'reasons.foreignShareholdingDecreasing',
      'DAY_TRADING_HIGH' || 'dayTradingHigh' => 'reasons.dayTradingHigh',
      'DAY_TRADING_EXTREME' ||
      'dayTradingExtreme' => 'reasons.dayTradingExtreme',
      'CONCENTRATION_HIGH' ||
      'concentrationHigh' => 'reasons.concentrationHigh',
      // 量價背離
      'PRICE_VOLUME_BULLISH_DIVERGENCE' ||
      'priceVolumeBullishDivergence' => 'reasons.priceVolumeBullishDivergence',
      'PRICE_VOLUME_BEARISH_DIVERGENCE' ||
      'priceVolumeBearishDivergence' => 'reasons.priceVolumeBearishDivergence',
      'HIGH_VOLUME_BREAKOUT' ||
      'highVolumeBreakout' => 'reasons.highVolumeBreakout',
      'LOW_VOLUME_ACCUMULATION' ||
      'lowVolumeAccumulation' => 'reasons.lowVolumeAccumulation',
      // 基本面訊號
      'REVENUE_YOY_SURGE' || 'revenueYoySurge' => 'reasons.revenueYoySurge',
      'REVENUE_YOY_DECLINE' ||
      'revenueYoyDecline' => 'reasons.revenueYoyDecline',
      'REVENUE_MOM_GROWTH' || 'revenueMomGrowth' => 'reasons.revenueMomGrowth',
      'HIGH_DIVIDEND_YIELD' ||
      'highDividendYield' => 'reasons.highDividendYield',
      'PE_UNDERVALUED' || 'peUndervalued' => 'reasons.peUndervalued',
      'PE_OVERVALUED' || 'peOvervalued' => 'reasons.peOvervalued',
      'PBR_UNDERVALUED' || 'pbrUndervalued' => 'reasons.pbrUndervalued',
      // EPS 分析
      'EPS_YOY_SURGE' || 'epsYoYSurge' => 'reasons.epsYoYSurge',
      'EPS_CONSECUTIVE_GROWTH' ||
      'epsConsecutiveGrowth' => 'reasons.epsConsecutiveGrowth',
      'EPS_TURNAROUND' || 'epsTurnaround' => 'reasons.epsTurnaround',
      'EPS_DECLINE_WARNING' ||
      'epsDeclineWarning' => 'reasons.epsDeclineWarning',
      // ROE 分析
      'ROE_EXCELLENT' || 'roeExcellent' => 'reasons.roeExcellent',
      'ROE_IMPROVING' || 'roeImproving' => 'reasons.roeImproving',
      'ROE_DECLINING' || 'roeDeclining' => 'reasons.roeDeclining',
      // 警示與內部人訊號
      'TRADING_WARNING_ATTENTION' ||
      'tradingWarningAttention' => 'reasons.tradingWarningAttention',
      'TRADING_WARNING_DISPOSAL' ||
      'tradingWarningDisposal' => 'reasons.tradingWarningDisposal',
      'INSIDER_SELLING_STREAK' ||
      'insiderSellingStreak' => 'reasons.insiderSellingStreak',
      'INSIDER_SIGNIFICANT_BUYING' ||
      'insiderSignificantBuying' => 'reasons.insiderSignificantBuying',
      'HIGH_PLEDGE_RATIO' || 'highPledgeRatio' => 'reasons.highPledgeRatio',
      'FOREIGN_CONCENTRATION_WARNING' ||
      'foreignConcentrationWarning' => 'reasons.foreignConcentrationWarning',
      'FOREIGN_EXODUS' || 'foreignExodus' => 'reasons.foreignExodus',
      _ => code, // 未知代碼則回傳原始代碼
    };
    return key.tr();
  }

  /// 取得原因代碼的說明文字（用於 tooltip）
  ///
  /// 對應 summary.* 的 i18n 鍵中的描述性句子。
  static String? tooltipForReasonCode(String code) {
    final key = switch (code) {
      'REVERSAL_W2S' || 'reversalW2S' => 'summary.reversalW2S',
      'REVERSAL_S2W' || 'reversalS2W' => 'summary.reversalS2W',
      'TECH_BREAKOUT' || 'techBreakout' => 'summary.breakout',
      'TECH_BREAKDOWN' || 'techBreakdown' => 'summary.breakdown',
      'VOLUME_SPIKE' || 'volumeSpike' => 'reasonTip.volumeSpike',
      'PRICE_SPIKE' || 'priceSpike' => 'reasonTip.priceSpike',
      'INSTITUTIONAL_SHIFT' ||
      'institutionalShift' => 'reasonTip.institutional',
      'NEWS_RELATED' || 'newsRelated' => 'reasonTip.news',
      'KD_GOLDEN_CROSS' || 'kdGoldenCross' => 'summary.kdGoldenCross',
      'KD_DEATH_CROSS' || 'kdDeathCross' => 'summary.kdDeathCross',
      'INSTITUTIONAL_BUY_STREAK' ||
      'institutionalBuyStreak' => 'summary.institutionalBuyStreak',
      'INSTITUTIONAL_SELL_STREAK' ||
      'institutionalSellStreak' => 'summary.institutionalSellStreak',
      'PATTERN_DOJI' || 'patternDoji' => 'summary.patternDoji',
      'PATTERN_BULLISH_ENGULFING' ||
      'patternBullishEngulfing' => 'summary.patternBullishEngulfing',
      'PATTERN_BEARISH_ENGULFING' ||
      'patternBearishEngulfing' => 'summary.patternBearishEngulfing',
      'PATTERN_HAMMER' || 'patternHammer' => 'summary.patternHammer',
      'PATTERN_HANGING_MAN' ||
      'patternHangingMan' => 'summary.patternHangingMan',
      'PATTERN_MORNING_STAR' ||
      'patternMorningStar' => 'summary.patternMorningStar',
      'PATTERN_EVENING_STAR' ||
      'patternEveningStar' => 'summary.patternEveningStar',
      'PATTERN_THREE_WHITE_SOLDIERS' ||
      'patternThreeWhiteSoldiers' => 'summary.patternThreeWhiteSoldiers',
      'PATTERN_THREE_BLACK_CROWS' ||
      'patternThreeBlackCrows' => 'summary.patternThreeBlackCrows',
      'PATTERN_GAP_UP' || 'patternGapUp' => 'summary.patternGapUp',
      'PATTERN_GAP_DOWN' || 'patternGapDown' => 'summary.patternGapDown',
      'WEEK_52_HIGH' || 'week52High' => 'summary.week52High',
      'WEEK_52_LOW' || 'week52Low' => 'summary.week52Low',
      'MA_ALIGNMENT_BULLISH' ||
      'maAlignmentBullish' => 'summary.maAlignmentBullish',
      'MA_ALIGNMENT_BEARISH' ||
      'maAlignmentBearish' => 'summary.maAlignmentBearish',
      'RSI_EXTREME_OVERBOUGHT' ||
      'rsiExtremeOverbought' => 'reasonTip.rsiOverbought',
      'RSI_EXTREME_OVERSOLD' || 'rsiExtremeOversold' => 'reasonTip.rsiOversold',
      'REVENUE_YOY_SURGE' || 'revenueYoySurge' => 'reasonTip.revenueYoySurge',
      'REVENUE_YOY_DECLINE' ||
      'revenueYoyDecline' => 'reasonTip.revenueYoyDecline',
      'REVENUE_MOM_GROWTH' ||
      'revenueMomGrowth' => 'reasonTip.revenueMomGrowth',
      'HIGH_DIVIDEND_YIELD' ||
      'highDividendYield' => 'reasonTip.highDividendYield',
      'PE_UNDERVALUED' || 'peUndervalued' => 'reasonTip.peUndervalued',
      'PE_OVERVALUED' || 'peOvervalued' => 'reasonTip.peOvervalued',
      'EPS_YOY_SURGE' || 'epsYoYSurge' => 'reasonTip.epsYoYSurge',
      'EPS_CONSECUTIVE_GROWTH' ||
      'epsConsecutiveGrowth' => 'reasonTip.epsConsecutiveGrowth',
      'EPS_TURNAROUND' || 'epsTurnaround' => 'reasonTip.epsTurnaround',
      'EPS_DECLINE_WARNING' || 'epsDeclineWarning' => 'reasonTip.epsDecline',
      'ROE_EXCELLENT' || 'roeExcellent' => 'reasonTip.roeExcellent',
      'ROE_IMPROVING' || 'roeImproving' => 'reasonTip.roeImproving',
      'ROE_DECLINING' || 'roeDeclining' => 'reasonTip.roeDeclining',
      'TRADING_WARNING_ATTENTION' ||
      'tradingWarningAttention' => 'summary.warningAttention',
      'TRADING_WARNING_DISPOSAL' ||
      'tradingWarningDisposal' => 'summary.warningDisposal',
      'INSIDER_SELLING_STREAK' ||
      'insiderSellingStreak' => 'reasonTip.insiderSelling',
      'INSIDER_SIGNIFICANT_BUYING' ||
      'insiderSignificantBuying' => 'summary.insiderBuying',
      'HIGH_PLEDGE_RATIO' || 'highPledgeRatio' => 'summary.highPledge',
      'INSTITUTIONAL_BUY' || 'institutionalBuy' => 'reasonTip.institutional',
      'INSTITUTIONAL_SELL' || 'institutionalSell' => 'reasonTip.institutional',
      'FOREIGN_SHAREHOLDING_INCREASING' ||
      'foreignShareholdingIncreasing' => 'reasonTip.foreignIncreasing',
      'FOREIGN_SHAREHOLDING_DECREASING' ||
      'foreignShareholdingDecreasing' => 'reasonTip.foreignDecreasing',
      'DAY_TRADING_HIGH' || 'dayTradingHigh' => 'reasonTip.dayTradingHigh',
      'DAY_TRADING_EXTREME' ||
      'dayTradingExtreme' => 'reasonTip.dayTradingHigh',
      'CONCENTRATION_HIGH' ||
      'concentrationHigh' => 'reasonTip.concentrationHigh',
      'PRICE_VOLUME_BULLISH_DIVERGENCE' ||
      'priceVolumeBullishDivergence' => 'reasonTip.bullishDivergence',
      'PRICE_VOLUME_BEARISH_DIVERGENCE' ||
      'priceVolumeBearishDivergence' => 'reasonTip.bearishDivergence',
      'HIGH_VOLUME_BREAKOUT' ||
      'highVolumeBreakout' => 'reasonTip.highVolumeBreakout',
      'LOW_VOLUME_ACCUMULATION' ||
      'lowVolumeAccumulation' => 'reasonTip.lowVolumeAccumulation',
      'PBR_UNDERVALUED' || 'pbrUndervalued' => 'reasonTip.pbrUndervalued',
      'FOREIGN_CONCENTRATION_WARNING' ||
      'foreignConcentrationWarning' => 'reasonTip.foreignConcentration',
      'FOREIGN_EXODUS' || 'foreignExodus' => 'reasonTip.foreignExodus',
      _ => null,
    };
    if (key == null) return null;
    final translated = key.tr();
    // If translation returned the key itself, it's missing
    return translated == key ? null : translated;
  }
}

class _ReasonTag extends StatelessWidget {
  const _ReasonTag({
    required this.label,
    this.tooltip,
    required this.isCompact,
    required this.isDark,
    required this.theme,
  });

  final String label;
  final String? tooltip;
  final bool isCompact;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final tag = Container(
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

    if (tooltip == null) return tag;

    return Tooltip(
      message: tooltip!,
      preferBelow: true,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: tag,
    );
  }
}
