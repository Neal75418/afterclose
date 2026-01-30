import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/remote/twse_client.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 大盤總覽卡片
///
/// 顯示市場指數、漲跌家數、法人動向、融資融券概況
class MarketOverviewCard extends StatelessWidget {
  const MarketOverviewCard({super.key, required this.state});

  final MarketOverviewState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          child: SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    if (!state.hasData) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題
              Row(
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'marketOverview.title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // 指數區
              if (state.indices.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildIndices(context, state.indices),
              ],

              // 漲跌家數
              if (state.advanceDecline.total > 0) ...[
                const SizedBox(height: 12),
                _buildAdvanceDecline(context, state.advanceDecline),
              ],

              // 法人動向
              if (state.institutional.totalNet != 0) ...[
                const SizedBox(height: 12),
                _buildInstitutional(context, state.institutional),
              ],

              // 融資融券
              if (state.margin.marginChange != 0 ||
                  state.margin.shortChange != 0) ...[
                const SizedBox(height: 12),
                _buildMargin(context, state.margin),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 指數區域
  Widget _buildIndices(BuildContext context, List<TwseMarketIndex> indices) {
    final theme = Theme.of(context);

    return Column(
      children: indices.map((idx) {
        final color = idx.isUp
            ? AppTheme.upColor
            : idx.isDown
            ? AppTheme.downColor
            : AppTheme.neutralColor;

        final sign = idx.change > 0 ? '+' : '';
        final formatter = NumberFormat('#,##0.00');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  _shortenIndexName(idx.name),
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  formatter.format(idx.close),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(
                  '$sign${formatter.format(idx.change)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '($sign${idx.changePercent.toStringAsFixed(2)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 漲跌家數
  Widget _buildAdvanceDecline(BuildContext context, AdvanceDecline ad) {
    final theme = Theme.of(context);
    final total = ad.total;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.advanceDecline'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        // 進度條
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: ad.advance,
                  child: Container(color: AppTheme.upColor),
                ),
                Expanded(
                  flex: ad.unchanged,
                  child: Container(color: AppTheme.neutralColor),
                ),
                Expanded(
                  flex: ad.decline,
                  child: Container(color: AppTheme.downColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 數字
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _labelValue(
              context,
              'marketOverview.advance'.tr(),
              '${ad.advance}',
              AppTheme.upColor,
            ),
            _labelValue(
              context,
              'marketOverview.unchanged'.tr(),
              '${ad.unchanged}',
              AppTheme.neutralColor,
            ),
            _labelValue(
              context,
              'marketOverview.decline'.tr(),
              '${ad.decline}',
              AppTheme.downColor,
            ),
          ],
        ),
      ],
    );
  }

  /// 法人動向
  Widget _buildInstitutional(BuildContext context, InstitutionalTotals inst) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.institutional'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _institutionalItem(
                context,
                'marketOverview.foreign'.tr(),
                inst.foreignNet,
                AppTheme.foreignColor,
              ),
            ),
            Expanded(
              child: _institutionalItem(
                context,
                'marketOverview.trust'.tr(),
                inst.trustNet,
                AppTheme.investmentTrustColor,
              ),
            ),
            Expanded(
              child: _institutionalItem(
                context,
                'marketOverview.dealer'.tr(),
                inst.dealerNet,
                AppTheme.dealerColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _institutionalItem(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    final theme = Theme.of(context);
    final valueColor = value > 0
        ? AppTheme.upColor
        : value < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;

    return Column(
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(
          _formatAmount(value),
          style: theme.textTheme.bodySmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 融資融券
  Widget _buildMargin(BuildContext context, MarginTradingTotals margin) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.margin'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _marginItem(
                context,
                'marketOverview.marginBalance'.tr(),
                margin.marginChange,
              ),
            ),
            Expanded(
              child: _marginItem(
                context,
                'marketOverview.shortBalance'.tr(),
                margin.shortChange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _marginItem(BuildContext context, String label, double change) {
    final theme = Theme.of(context);
    final color = change > 0
        ? AppTheme.upColor
        : change < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;
    final sign = change > 0 ? '+' : '';
    final formatter = NumberFormat('#,##0');

    return Column(
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          '$sign${formatter.format(change)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Helper Methods
  // ==========================================

  Widget _labelValue(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 縮短指數名稱
  String _shortenIndexName(String name) {
    if (name.contains('發行量加權')) return '加權指數';
    if (name.contains('未含金融')) return '未含金融';
    if (name.contains('電子類')) return '電子類';
    if (name.contains('金融保險')) return '金融保險';
    return name;
  }

  /// 格式化金額（億元）
  String _formatAmount(double value) {
    final absVal = value.abs();
    final sign = value > 0
        ? '+'
        : value < 0
        ? '-'
        : '';

    if (absVal >= 1e8) {
      // 億元
      return '$sign${(absVal / 1e8).toStringAsFixed(1)}億';
    } else if (absVal >= 1e4) {
      // 萬元
      return '$sign${(absVal / 1e4).toStringAsFixed(0)}萬';
    }
    return '$sign${absVal.toStringAsFixed(0)}';
  }
}
