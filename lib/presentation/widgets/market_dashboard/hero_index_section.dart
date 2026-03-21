import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/market_index_names.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Hero 指數區域
///
/// 顯示指數大數字 + 漲跌幅 + 30 日 Sparkline 走勢圖
/// 支援加權指數和櫃買指數，根據 index name 自動選擇標題
///
/// 當顯示加權指數且提供 [totalReturnHistory] 時，
/// 會在走勢圖下方顯示含息報酬指數的股息貢獻 badge。
class HeroIndexSection extends StatelessWidget {
  const HeroIndexSection({
    super.key,
    required this.index,
    this.historyData = const [],
    this.totalReturnHistory = const [],
    this.reserveBadgeSpace = false,
  });

  final TwseMarketIndex index;
  final List<double> historyData;

  /// 含息報酬指數歷史資料（供計算股息貢獻比較）
  final List<double> totalReturnHistory;

  /// 並排顯示時，為無 badge 的欄位保留相同高度
  final bool reserveBadgeSpace;

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

    final showBadge =
        index.name == MarketIndexNames.taiex &&
        totalReturnHistory.length >= 2 &&
        historyData.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero 卡片（上市/上櫃共用相同結構，確保高度一致）
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
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
                    index.name == MarketIndexNames.tpexIndex
                        ? 'marketOverview.tpexIndex'.tr()
                        : 'marketOverview.taiex'.tr(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // 漲跌幅 badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusSm,
                      ),
                    ),
                    child: Text(
                      '$sign${index.changePercent.toStringAsFixed(2)}%',
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
                    formatter.format(index.close),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$sign${formatter.format(index.change)}',
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
        ),

        // 含息報酬指數比較（卡片外部，僅加權指數顯示）
        // 放在 Container 外確保上市/上櫃卡片高度一致
        if (showBadge) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _TotalReturnBadge(
              taiexHistory: historyData,
              totalReturnHistory: totalReturnHistory,
            ),
          ),
        ] else if (reserveBadgeSpace) ...[
          // 並排模式：為 TPEx 側保留與 badge 等高的空間
          const SizedBox(height: 6),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// 含息報酬指數 vs 加權指數的股息貢獻 badge
///
/// 計算近 30 日期間內，含息報酬指數相對於加權指數的超額報酬，
/// 即「股息再投資」所貢獻的額外報酬百分比。
class _TotalReturnBadge extends StatelessWidget {
  const _TotalReturnBadge({
    required this.taiexHistory,
    required this.totalReturnHistory,
  });

  final List<double> taiexHistory;
  final List<double> totalReturnHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 避免除以零（資料異常時的防禦）
    if (taiexHistory.first == 0 || totalReturnHistory.first == 0) {
      return const SizedBox.shrink();
    }

    // 計算期間報酬率差異（股息貢獻）
    final taiexReturn =
        (taiexHistory.last - taiexHistory.first) / taiexHistory.first * 100;
    final triReturn =
        (totalReturnHistory.last - totalReturnHistory.first) /
        totalReturnHistory.first *
        100;
    final dividendContribution = triReturn - taiexReturn;

    // 貢獻太小時不顯示（避免噪音）
    if (dividendContribution.abs() < 0.01) return const SizedBox.shrink();

    final sign = dividendContribution > 0 ? '+' : '';

    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 12,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          'marketOverview.totalReturnIndex'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: DesignTokens.fontSizeXs,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          ),
          child: Text(
            'marketOverview.dividendContribution'.tr(
              namedArgs: {
                'pct': '$sign${dividendContribution.toStringAsFixed(2)}',
              },
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontSize: DesignTokens.fontSizeXs,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
