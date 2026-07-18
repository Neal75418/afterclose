import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/chip_scoring_params.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart'
    show buildEmptyState;
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 當沖區塊 - 比率卡片 + 趨勢圖
class DayTradingSection extends StatelessWidget {
  const DayTradingSection({super.key, required this.history});

  final List<DayTradingEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'chip.sectionDayTrading'.tr(),
            icon: Icons.flash_on,
          ),
          const SizedBox(height: DesignTokens.spacing12),
          buildEmptyState(context, 'chip.noData'.tr()),
        ],
      );
    }

    final sorted = List<DayTradingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final latest = sorted.last;
    final latestRatio = latest.dayTradingRatio ?? 0;

    // 5-day average
    final recentCount = sorted.length >= 5 ? 5 : sorted.length;
    final recent = sorted.sublist(sorted.length - recentCount);
    double avg5 = 0;
    for (final e in recent) {
      avg5 += (e.dayTradingRatio ?? 0);
    }
    avg5 = avg5 / recentCount;

    // 與籌碼評分共用門檻，避免「UI 標紅」與「實際扣分」兩套數字漂移。
    // 2026-07-18 隨 [ChipScoringParams.dayTradingHighThresholdPct] 由 35 → 60
    // （35% 是流動股池的中位數，標紅一半的股票等於沒標；60% 為 p98.4、
    // 觸發率 1.64%，同 TWSE 注意股當沖標準）。
    final isHigh = latestRatio >= ChipScoringParams.dayTradingHighThresholdPct;

    final chartData = sorted
        .map((e) => (e.dayTradingRatio ?? 0).toDouble())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionDayTrading'.tr(),
          icon: Icons.flash_on,
        ),
        const SizedBox(height: DesignTokens.spacing12),

        // 摘要卡片
        Container(
          padding: const EdgeInsets.all(DesignTokens.spacing12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            border: isHigh
                ? Border.all(color: AppTheme.downColor.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chip.dayTradingRatio'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing4),
                    Text(
                      '${latestRatio.toStringAsFixed(1)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isHigh ? AppTheme.downColor : null,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chip.dayTradingAvg5'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing4),
                    Text(
                      '${avg5.toStringAsFixed(1)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.spacing8),

        // 趨勢圖
        MiniTrendChart(
          dataPoints: chartData,
          lineColor: isHigh ? AppTheme.downColor : const Color(0xFFFF9800),
          minY: 0,
        ),
      ],
    );
  }
}
