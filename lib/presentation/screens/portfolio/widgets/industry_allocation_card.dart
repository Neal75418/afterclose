import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/domain/services/portfolio_analytics_service.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';

/// 產業配置卡片
///
/// 以長條圖顯示投資組合的產業配置比例
class IndustryAllocationCard extends StatelessWidget {
  const IndustryAllocationCard({super.key, required this.allocation});

  final Map<String, IndustryAllocation> allocation;

  // 產業顏色映射
  //
  // 其他電子業／金融保險業／航運業／食品工業原色值落在股價語意色相區
  // （紅 >=345°或<=15°、綠 88-175°），與 chartPalette 同一問題，已改為
  // 安全色相。金融保險業原規劃沿用 chartPalette[0]（#3B82F6），但該值
  // 與塑膠工業重複（塑膠工業已使用 #3B82F6），會導致兩個產業在圖上同色
  // 無法區分，故改用同樣安全、未被佔用的 Sky 500。
  static const _industryColors = <String, Color>{
    '半導體業': Color(0xFF6366F1),
    '電腦及週邊設備業': Color(0xFF8B5CF6),
    '電子零組件業': Color(0xFFA855F7),
    '通信網路業': Color(0xFFD946EF),
    '光電業': Color(0xFFEC4899),
    '其他電子業': Color(0xFFC4B5FD), // 原 #F43F5E（紅 350°），改紫 300（252°）
    '電子通路業': Color(0xFFF97316),
    '資訊服務業': Color(0xFFEAB308),
    '金融保險業': Color(0xFF0EA5E9), // 原 #22C55E（綠 142°），改 Sky 500（199°）
    '航運業': Color(0xFF93C5FD), // 原 #14B8A6（青綠 173°），改藍 300（212°）
    '鋼鐵業': Color(0xFF06B6D4),
    '塑膠工業': Color(0xFF3B82F6),
    '食品工業': Color(0xFFFDBA74), // 原 #84CC16（黃綠 84°，逼近禁區），改橘 300（31°）
    '紡織纖維': Color(0xFFCA8A04),
    '生技醫療業': Color(0xFFDB2777),
    '其他': Color(0xFF94A3B8),
  };

  // 備用顏色（當產業不在映射中時使用）—— 委派至通用圖表色盤，
  // 避免另立一份色相準則不同的清單。
  static const _fallbackColors = CategoryColors.chartPalette;

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
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
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
                borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
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
