import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';

/// 子指數小卡列
///
/// 顯示未含金融、電子類、金融保險三個子指數，各帶迷你走勢圖
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

    return Row(
      children: subIndices.map((idx) {
        final history = historyMap[idx.name] ?? [];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: idx != subIndices.last ? 8 : 0),
            child: _SubIndexCard(index: idx, historyData: history),
          ),
        );
      }).toList(),
    );
  }
}

class _SubIndexCard extends StatelessWidget {
  const _SubIndexCard({required this.index, required this.historyData});

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

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _shortenName(index.name),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            formatter.format(index.close),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$sign${index.changePercent.toStringAsFixed(2)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (historyData.length >= 2) ...[
            const SizedBox(height: 6),
            MiniTrendChart(
              dataPoints: historyData,
              height: 30,
              lineColor: color,
              fillColor: color.withValues(alpha: 0.06),
            ),
          ],
        ],
      ),
    );
  }

  String _shortenName(String name) {
    if (name.contains('未含金融')) return 'marketOverview.exFinance'.tr();
    if (name.contains('電子類')) return 'marketOverview.electronics'.tr();
    if (name.contains('金融保險')) return 'marketOverview.finance'.tr();
    return name;
  }
}
