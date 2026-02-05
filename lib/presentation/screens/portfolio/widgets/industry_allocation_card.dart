import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/domain/services/portfolio_analytics_service.dart';

/// 產業配置卡片
///
/// 以長條圖顯示投資組合的產業配置比例
class IndustryAllocationCard extends StatelessWidget {
  const IndustryAllocationCard({super.key, required this.allocation});

  final Map<String, IndustryAllocation> allocation;

  // 產業顏色映射
  static const _industryColors = <String, Color>{
    '半導體業': Color(0xFF6366F1),
    '電腦及週邊設備業': Color(0xFF8B5CF6),
    '電子零組件業': Color(0xFFA855F7),
    '通信網路業': Color(0xFFD946EF),
    '光電業': Color(0xFFEC4899),
    '其他電子業': Color(0xFFF43F5E),
    '電子通路業': Color(0xFFF97316),
    '資訊服務業': Color(0xFFEAB308),
    '金融保險業': Color(0xFF22C55E),
    '航運業': Color(0xFF14B8A6),
    '鋼鐵業': Color(0xFF06B6D4),
    '塑膠工業': Color(0xFF3B82F6),
    '食品工業': Color(0xFF84CC16),
    '紡織纖維': Color(0xFFCA8A04),
    '生技醫療業': Color(0xFFDB2777),
    '其他': Color(0xFF94A3B8),
  };

  // 備用顏色（當產業不在映射中時使用）
  static const _fallbackColors = <Color>[
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFA855F7),
    Color(0xFFF97316),
    Color(0xFF22C55E),
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];

  Color _getColor(String industry, int index) {
    if (_industryColors.containsKey(industry)) {
      return _industryColors[industry]!;
    }
    return _fallbackColors[index % _fallbackColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (allocation.isEmpty) {
      return const SizedBox.shrink();
    }

    // 依比例排序
    final sorted = allocation.entries.toList()
      ..sort((a, b) => b.value.percentage.compareTo(a.value.percentage));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'portfolio.industryAllocation'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 長條圖
          for (var i = 0; i < sorted.length; i++) ...[
            _IndustryBar(
              industry: sorted[i].value.industry,
              percentage: sorted[i].value.percentage,
              symbols: sorted[i].value.symbols,
              color: _getColor(sorted[i].value.industry, i),
              theme: theme,
            ),
            if (i < sorted.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _IndustryBar extends StatelessWidget {
  const _IndustryBar({
    required this.industry,
    required this.percentage,
    required this.symbols,
    required this.color,
    required this.theme,
  });

  final String industry;
  final double percentage;
  final List<String> symbols;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                industry,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          symbols.join(', '),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
