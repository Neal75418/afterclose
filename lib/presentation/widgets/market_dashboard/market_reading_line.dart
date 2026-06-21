import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
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
  const MarketReadingLine({super.key, required this.reading});

  /// 判讀結果；為 null 時不渲染任何內容（資料缺失時優雅留白）。
  final MarketReading? reading;

  @override
  Widget build(BuildContext context) {
    final reading = this.reading;
    if (reading == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.7,
    );

    // tone → 色彩：warning=amber、negative=下跌色，其餘 muted
    final color = switch (reading.tone) {
      InterpretationTone.warning => AppTheme.cautionColor,
      InterpretationTone.negative => AppTheme.downColor,
      InterpretationTone.positive => mutedColor,
      InterpretationTone.neutral => mutedColor,
    };

    final text = reading.args == null
        ? reading.messageKey.tr()
        : reading.messageKey.tr(namedArgs: reading.args!);

    final children = <Widget>[
      if (reading.tone == InterpretationTone.warning) ...[
        Text(
          '⚠',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: DesignTokens.fontSizeXs,
          ),
        ),
        const SizedBox(width: DesignTokens.spacing4),
      ],
      Flexible(
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: DesignTokens.fontSizeXs,
          ),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.spacing6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
