import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';

/// Hero 加權指數區域
///
/// 顯示加權指數大數字 + 漲跌幅 + 30 日 Sparkline 走勢圖
class HeroIndexSection extends StatelessWidget {
  const HeroIndexSection({
    super.key,
    required this.taiex,
    this.historyData = const [],
  });

  final TwseMarketIndex taiex;
  final List<double> historyData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = taiex.isUp
        ? AppTheme.upColor
        : taiex.change < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;
    final sign = taiex.change > 0 ? '+' : '';
    final formatter = NumberFormat('#,##0.00');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'marketOverview.taiex'.tr(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // 漲跌幅 badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$sign${taiex.changePercent.toStringAsFixed(2)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 大數字 + 漲跌
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatter.format(taiex.close),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$sign${formatter.format(taiex.change)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          // Sparkline 走勢圖
          if (historyData.length >= 2) ...[
            const SizedBox(height: 12),
            MiniTrendChart(
              dataPoints: historyData,
              height: 60,
              lineColor: color,
              fillColor: color.withValues(alpha: 0.08),
            ),
          ],
        ],
      ),
    );
  }
}
