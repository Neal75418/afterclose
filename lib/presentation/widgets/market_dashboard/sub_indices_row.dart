import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 子指數列表（水平滾動）
///
/// 顯示產業指數的水平卡片列表，支援滾動查看更多指數
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'marketOverview.industryIndices'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // 桌面版：使用 Wrap 排列；手機版：水平滾動
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subIndices.map((idx) {
                final history = historyMap[idx.name] ?? [];
                return SizedBox(
                  width: 140,
                  child: _SubIndexCard(index: idx, history: history),
                );
              }).toList(),
            ),
          )
        else
          SizedBox(
            height: 96, // 固定高度
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: subIndices.length,
              itemBuilder: (context, index) {
                final idx = subIndices[index];
                final history = historyMap[idx.name] ?? [];

                return Container(
                  width: 140, // 固定寬度
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SubIndexCard(index: idx, history: history),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SubIndexCard extends StatelessWidget {
  const _SubIndexCard({required this.index, required this.history});

  final TwseMarketIndex index;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = index.change >= 0;
    final color = index.isUp
        ? AppTheme.upColor
        : index.change < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 指數名稱（簡化顯示）
            Text(
              _simplifyIndexName(index.name),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // 指數值
            Text(
              index.close.toStringAsFixed(2),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),

            // 漲跌幅
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 2),
                Text(
                  '${isPositive ? '+' : ''}${index.changePercent.toStringAsFixed(2)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 簡化指數名稱顯示
  String _simplifyIndexName(String fullName) {
    // 優先使用翻譯鍵
    if (fullName.contains('未含金融')) return 'marketOverview.exFinance'.tr();
    if (fullName.contains('電子工業') || fullName.contains('電子類')) {
      return 'marketOverview.electronics'.tr();
    }
    if (fullName.contains('金融保險')) return 'marketOverview.finance'.tr();
    if (fullName.contains('半導體')) return 'marketOverview.semiconductor'.tr();
    if (fullName.contains('航運')) return 'marketOverview.shipping'.tr();
    if (fullName.contains('生技')) return 'marketOverview.biotech'.tr();
    if (fullName.contains('鋼鐵')) return 'marketOverview.steel'.tr();
    if (fullName.contains('綠能') || fullName.contains('環保')) {
      return 'marketOverview.greenEnergy'.tr();
    }
    if (fullName.contains('高股息')) return 'marketOverview.highDividend'.tr();

    // 如果沒有匹配到翻譯，嘗試簡化原名稱
    return fullName
        .replaceAll('類指數', '')
        .replaceAll('工業', '')
        .replaceAll('保險', '');
  }
}
