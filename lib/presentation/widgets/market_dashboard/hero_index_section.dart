import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/market_index_names.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/domain/services/market_reading_service.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/market_reading_line.dart';
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
    this.stageHistory = const [],
    this.totalReturnHistory = const [],
    this.reserveBadgeSpace = false,
  });

  final TwseMarketIndex index;
  final List<double> historyData;

  /// 較長窗口的收盤歷史（供大盤位階 MA60 計算，升序 oldest→newest）
  ///
  /// 與 [historyData]（30 點走勢圖）分離，需 ≥60 個交易日才能算出 MA60。
  final List<double> stageHistory;

  /// 含息報酬指數歷史資料（供計算股息貢獻比較）
  final List<double> totalReturnHistory;

  /// 並排顯示時，為無 badge 的欄位保留相同高度
  final bool reserveBadgeSpace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // index.isUp 是資料層旗標，與 change 的符號一致；統一走 getPriceColor
    // 解析，淺色主題才拿得到較深的下跌綠／平盤灰。
    final color = AppTheme.getPriceColor(index.change, theme.brightness);
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
          padding: const EdgeInsets.all(DesignTokens.spacing16),
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
                      horizontal: DesignTokens.spacing8,
                      vertical: DesignTokens.spacing2,
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
                        color: PriceColors.onTintOf(
                          color,
                          Theme.of(context).brightness,
                        ),
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing8),

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
                  const SizedBox(width: DesignTokens.spacing12),
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

              // 大盤位階（均線乖離）— 緊湊單行，位於大數字與走勢圖之間
              ..._buildStageRow(context, theme),

              // Sparkline 走勢圖
              //
              // 色彩語意：red/green 僅供價格方向（漲跌 badge、乖離 chip 等）
              // 使用。這條線畫的是 30 日「數列」本身，不是方向判斷，故不沿用
              // up/down 色，改中性 blue-grey（AppTheme.neutralSlateColor，
              // 既有 token：「用於非漲跌的平穩狀態」）。
              if (historyData.length >= 2) ...[
                const SizedBox(height: DesignTokens.spacing12),
                MiniTrendChart(
                  dataPoints: historyData,
                  height: 60,
                  lineColor: AppTheme.neutralSlateColor,
                ),
              ],
            ],
          ),
        ),

        // 含息報酬指數比較（卡片外部，僅加權指數顯示）
        // 放在 Container 外確保上市/上櫃卡片高度一致
        if (showBadge) ...[
          const SizedBox(height: DesignTokens.spacing6),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing4,
            ),
            child: _TotalReturnBadge(
              taiexHistory: historyData,
              totalReturnHistory: totalReturnHistory,
            ),
          ),
        ] else if (reserveBadgeSpace) ...[
          // 並排模式：為 TPEx 側保留與 badge 等高的空間
          const SizedBox(height: DesignTokens.spacing6),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// 建構大盤位階單行（位階 chip + 距 20MA / 距 60MA 乖離率）
  ///
  /// 資料不足時顯示「位階資料不足」muted 提示；完全沒有歷史資料時回傳空。
  List<Widget> _buildStageRow(BuildContext context, ThemeData theme) {
    if (stageHistory.length < 2) return const [];

    final result = TechnicalIndicatorService().calculateMarketStage(
      stageHistory,
    );

    final mutedColor = theme.colorScheme.onSurfaceVariant;

    // 資料不足：顯示 muted 提示（一行）
    if (result.stage == MarketStage.insufficient) {
      return [
        const SizedBox(height: DesignTokens.spacing8),
        Text(
          'marketOverview.stage.insufficient'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: mutedColor,
            fontSize: DesignTokens.fontSizeXs,
          ),
        ),
      ];
    }

    // 台股慣例：多頭 / 正乖離 = 紅、空頭 / 負乖離 = 綠、糾結 = 灰
    final (stageColor, stageKey) = switch (result.stage) {
      MarketStage.bullish => (AppTheme.upColor, 'bullish'),
      MarketStage.bearish => (PriceColors.downFor(theme.brightness), 'bearish'),
      MarketStage.neutral => (PriceColors.flatFor(theme.brightness), 'neutral'),
      MarketStage.insufficient => (
        PriceColors.flatFor(theme.brightness),
        'insufficient',
      ),
    };

    // 位階乖離判讀（僅在極端乖離時補充一行，其餘為 null 不顯示）
    final reading = result.biasMa60 == null
        ? null
        : MarketReadingService.interpretStageBias(
            stage: result.stage,
            biasMa60: result.biasMa60!,
          );

    return [
      const SizedBox(height: DesignTokens.spacing8),
      Row(
        children: [
          // 位階 chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing8,
              vertical: DesignTokens.spacing2,
            ),
            decoration: BoxDecoration(
              color: stageColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
            ),
            child: Text(
              'marketOverview.stage.$stageKey'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: PriceColors.onTintOf(
                  stageColor,
                  Theme.of(context).brightness,
                ),
                fontWeight: FontWeight.w700,
                fontSize: DesignTokens.fontSizeXs,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spacing8),
          // 距 20MA / 距 60MA 乖離率
          Flexible(
            child: Text(
              '${'marketOverview.biasMa20'.tr(namedArgs: {'value': _formatBias(result.biasMa20)})}'
              '  '
              '${'marketOverview.biasMa60'.tr(namedArgs: {'value': _formatBias(result.biasMa60)})}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: mutedColor,
                fontSize: DesignTokens.fontSizeXs,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
      // 判讀層（位階乖離）— 僅在 reading 非 null 時渲染
      if (reading != null) MarketReadingLine(reading: reading),
    ];
  }

  /// 格式化乖離率（帶正負號，一位小數）
  static String _formatBias(double? bias) {
    if (bias == null) return '--';
    final sign = bias > 0 ? '+' : '';
    return '$sign${bias.toStringAsFixed(1)}';
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
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: DesignTokens.spacing4),
        Text(
          'marketOverview.totalReturnIndex'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: DesignTokens.fontSizeXs,
          ),
        ),
        const SizedBox(width: DesignTokens.spacing6),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing6,
            vertical: 1,
          ),
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
