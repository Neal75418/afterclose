import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/domain/services/market_reading_service.dart';

/// 判讀層（P2）共用顯示元件
///
/// 在大盤總覽各區塊下方附上一行分析師口吻的判讀文字。預設 muted；
/// [InterpretationTone.warning] 加 amber 提示色 + ⚠、
/// [InterpretationTone.negative] 沿用台股下跌色；positive / neutral 維持
/// muted（不與紅綠數字搶色）。
///
/// 將 tone → 樣式 的對應集中於此，四個區塊共用，確保視覺一致。
class MarketReadingLine extends StatelessWidget {
  const MarketReadingLine({
    super.key,
    required this.reading,
    this.prominent = false,
  });

  /// 判讀結果；為 null 時不渲染任何內容（資料缺失時優雅留白）。
  final MarketReading? reading;

  /// 是否以「醒目 strip」樣式呈現（帶淡背景色 + 較粗字重的一條）。
  ///
  /// 綜合判讀（top-level，見 [MarketReadingService.interpretCompositeSynthesis]）
  /// 用 `true` 升層為市場欄位頂部的視覺焦點；其餘三處 per-section 判讀
  /// （廣度／廣度趨勢／位階乖離）維持預設 `false`，樣式不變 — 四處共用同一
  /// 元件，僅 top-level 那一處選擇醒目樣式，避免全部連帶被拉高視覺權重、
  /// 蓋過各區塊自己的數字。
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final reading = this.reading;
    if (reading == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.7,
    );

    // tone → 文字色：warning 走疊色專屬文字色（caution 黃對白底／自身 tint
    // 合成底僅 1.3～1.4:1，只能當 tint 不能當文字）、negative=下跌色，
    // 其餘 muted。prominent 時 positive/neutral 改用全對比 onSurface，
    // 避免醒目 strip 裡的文字仍是灰階、達不到「readable weight」。
    final color = switch (reading.tone) {
      InterpretationTone.warning => WarningColors.onTintFor(theme.brightness),
      InterpretationTone.negative => AppTheme.downColor,
      InterpretationTone.positive =>
        prominent ? theme.colorScheme.onSurface : mutedColor,
      InterpretationTone.neutral =>
        prominent ? theme.colorScheme.onSurface : mutedColor,
    };

    // 醒目 strip 的淡背景維持 tone 識別色（warning 仍是琥珀 tint），
    // 不跟著文字色走——文字可讀性與底色識別是兩個獨立需求。
    final tintColor = switch (reading.tone) {
      InterpretationTone.warning => AppTheme.cautionColor,
      InterpretationTone.negative => AppTheme.downColor,
      InterpretationTone.positive => theme.colorScheme.onSurface,
      InterpretationTone.neutral => theme.colorScheme.onSurface,
    };

    final text = reading.args == null
        ? reading.messageKey.tr()
        : reading.messageKey.tr(namedArgs: reading.args!);

    final fontSize = prominent
        ? DesignTokens.fontSizeSm
        : DesignTokens.fontSizeXs;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reading.tone == InterpretationTone.warning) ...[
          Text(
            '⚠',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: fontSize,
            ),
          ),
          const SizedBox(width: DesignTokens.spacing4),
        ],
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: fontSize,
              fontWeight: prominent ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );

    if (!prominent) {
      return Padding(
        padding: const EdgeInsets.only(top: DesignTokens.spacing6),
        child: content,
      );
    }

    // 醒目 strip：淡背景（tone 色 10% 透明度）+ 圓角，貼齊各市場欄位頂部。
    return Container(
      margin: const EdgeInsets.only(top: DesignTokens.spacing8),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing10,
        vertical: DesignTokens.spacing6,
      ),
      decoration: BoxDecoration(
        color: tintColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: content,
    );
  }
}
