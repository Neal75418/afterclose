import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 格式化金額（元 → 億/千萬/百萬）
String _formatAmount(double value) {
  final absVal = value.abs();
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  final inBillion = absVal / 100000000;
  if (inBillion >= 100) {
    return '$sign${inBillion.toStringAsFixed(0)} ${'unit.billion'.tr()}';
  } else if (inBillion >= 10) {
    return '$sign${inBillion.toStringAsFixed(1)} ${'unit.billion'.tr()}';
  } else if (inBillion >= 1) {
    return '$sign${inBillion.toStringAsFixed(2)} ${'unit.billion'.tr()}';
  }
  final inTenMillion = absVal / 10000000;
  if (inTenMillion >= 1) {
    return '$sign${inTenMillion.toStringAsFixed(1)} ${'unit.tenMillion'.tr()}';
  }
  final inMillion = absVal / 1000000;
  return '$sign${inMillion.toStringAsFixed(0)} ${'unit.million'.tr()}';
}

/// 法人動向卡片
///
/// 以三張小卡呈現外資/投信/自營淨買賣，帶彩色左邊框 + 合計行
class InstitutionalFlowChart extends StatelessWidget {
  const InstitutionalFlowChart({super.key, required this.data});

  final InstitutionalTotals data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.totalNet == 0 &&
        data.foreignNet == 0 &&
        data.trustNet == 0 &&
        data.dealerNet == 0) {
      return const SizedBox.shrink();
    }

    final items = [
      _FlowItem(
        'marketOverview.foreign'.tr(),
        data.foreignNet,
        AppTheme.foreignColor,
      ),
      _FlowItem(
        'marketOverview.trust'.tr(),
        data.trustNet,
        AppTheme.investmentTrustColor,
      ),
      _FlowItem(
        'marketOverview.dealer'.tr(),
        data.dealerNet,
        AppTheme.dealerColor,
      ),
    ];

    // 找出最大絕對值，用於計算比例條寬度
    final maxAbs = items
        .map((e) => e.value.abs())
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.institutional'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),

        // 三張法人卡片
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: item != items.last ? 6 : 0),
            child: _FlowCard(item: item, maxAbs: maxAbs),
          ),
        ),

        // 合計
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            color: theme.colorScheme.surfaceContainerLowest,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'marketOverview.totalNet'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatAmount(data.totalNet),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: data.totalNet > 0
                      ? AppTheme.upColor
                      : data.totalNet < 0
                      ? AppTheme.downColor
                      : AppTheme.neutralColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlowItem {
  const _FlowItem(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.item, required this.maxAbs});

  final _FlowItem item;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = item.value >= 0;
    final valueColor = item.value > 0
        ? AppTheme.upColor
        : item.value < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;

    // 比例條寬度（0.0 ~ 1.0）
    final ratio = maxAbs > 0 ? item.value.abs() / maxAbs : 0.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 左邊框色條
            Container(width: 3, color: item.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名稱 + 金額
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: item.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatAmount(item.value),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: valueColor,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 比例條
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 4,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final barWidth = constraints.maxWidth * ratio;
                            return Stack(
                              children: [
                                Container(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.15),
                                ),
                                if (barWidth > 0)
                                  Positioned(
                                    left: isPositive ? 0 : null,
                                    right: isPositive ? null : 0,
                                    child: Container(
                                      width: barWidth,
                                      height: 4,
                                      color: isPositive
                                          ? item.color
                                          : item.color.withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
