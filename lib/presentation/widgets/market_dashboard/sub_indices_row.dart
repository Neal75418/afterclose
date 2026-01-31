import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';

/// 子指數列表
///
/// 垂直排列未含金融、電子類、金融保險三個子指數，
/// 每行左側名稱+數字，右側走勢圖。
class SubIndicesRow extends StatelessWidget {
  const SubIndicesRow({
    super.key,
    required this.subIndices,
    this.historyMap = const {},
  });

  /// 子指數列表（排除加權指數）
  final List<TwseMarketIndex> subIndices;

  /// 指數名稱 → 歷史收盤值
  final Map<String, List<double>> historyMap;

  @override
  Widget build(BuildContext context) {
    if (subIndices.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        children: [
          for (int i = 0; i < subIndices.length; i++) ...[
            if (i > 0)
              Divider(
                height: 16,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
              ),
            _SubIndexRow(
              index: subIndices[i],
              historyData: historyMap[subIndices[i].name] ?? [],
            ),
          ],
        ],
      ),
    );
  }
}

class _SubIndexRow extends StatelessWidget {
  const _SubIndexRow({required this.index, required this.historyData});

  final TwseMarketIndex index;
  final List<double> historyData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = index.isUp
        ? AppTheme.upColor
        : index.change < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;
    final sign = index.change > 0 ? '+' : '';
    final formatter = NumberFormat('#,##0.00');

    return Row(
      children: [
        // 左側色點
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),

        // 中間：名稱 + 數字
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _shortenName(index.name),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatter.format(index.close),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$sign${index.changePercent.toStringAsFixed(2)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 右側走勢圖
        if (historyData.length >= 2)
          SizedBox(
            width: 80,
            height: 28,
            child: MiniTrendChart(
              dataPoints: historyData,
              height: 28,
              lineColor: color,
              fillColor: color.withValues(alpha: 0.08),
            ),
          ),
      ],
    );
  }

  String _shortenName(String name) {
    if (name.contains('未含金融')) return 'marketOverview.exFinance'.tr();
    if (name.contains('電子工業') || name.contains('電子類')) {
      return 'marketOverview.electronics'.tr();
    }
    if (name.contains('金融保險')) return 'marketOverview.finance'.tr();
    return name;
  }
}
