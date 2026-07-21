import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/fundamentals/fundamentals_helpers.dart'
    show buildEmptyState;
import 'package:afterclose/presentation/screens/stock_detail/widgets/mini_trend_chart.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// 外資持股區塊 - 比率卡片 + 趨勢圖
class ShareholdingSection extends StatelessWidget {
  const ShareholdingSection({super.key, required this.history});

  final List<ShareholdingEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'chip.sectionShareholding'.tr(),
            icon: Icons.language,
          ),
          const SizedBox(height: DesignTokens.spacing12),
          buildEmptyState(context, 'chip.noData'.tr()),
        ],
      );
    }

    final sorted = List<ShareholdingEntry>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final latest = sorted.last;
    final ratio = latest.foreignSharesRatio ?? 0;

    // 判斷趨勢
    String trendKey = 'chip.trendStable';
    if (sorted.length >= 5) {
      final fiveDaysAgo = sorted[sorted.length - 5].foreignSharesRatio ?? 0;
      final diff = ratio - fiveDaysAgo;
      if (diff >= 0.1) trendKey = 'chip.trendIncreasing';
      if (diff <= -0.1) trendKey = 'chip.trendDecreasing';
    }

    final chartData = sorted
        .map((e) => (e.foreignSharesRatio ?? 0).toDouble())
        .toList();

    final trendColor = _trendColor(trendKey, theme.brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'chip.sectionShareholding'.tr(),
          icon: Icons.language,
        ),
        const SizedBox(height: DesignTokens.spacing12),

        // Summary card
        Container(
          padding: const EdgeInsets.all(DesignTokens.spacing12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chip.shareholdingRatio'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing4),
                    Text(
                      '${ratio.toStringAsFixed(2)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing8,
                  vertical: DesignTokens.spacing4,
                ),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Text(
                  trendKey.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: PriceColors.onTintOf(
                      trendColor,
                      Theme.of(context).brightness,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.spacing8),

        // Trend chart
        //
        // 這裡不在 Card 內、直接坐落在 ChipTab 的 surface 底色上（非白色）
        // ——不得沿用 CategoryColors.neutral（對 surface 底僅 2.43:1，圖形
        // 物件 3.0:1 門檻不過）。改走主題 onSurfaceVariant，理由同
        // insider_section.dart／institutional_section.dart。
        MiniTrendChart(
          dataPoints: chartData,
          lineColor: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  /// 外資持股趨勢色。
  ///
  /// 外資持股增加＝籌碼偏多、減少＝偏空，與漲跌屬同一多空語意軸，
  /// 故套台股慣例：增加＝紅、減少＝綠、持平＝灰。
  ///
  /// 此處原本寫死 `#4CAF50`（增加→綠）與 `#F44336`（減少→紅），方向與
  /// 台股慣例完全相反，也與 insider_tab.dart 的內部人增持→紅互相矛盾
  /// ——使用者在同一支股票切換分頁就會看到同一語意兩種顏色。
  /// 與籌碼評等（`PriceColors.chipRating`）是同一個 bug class。
  static Color _trendColor(String key, Brightness brightness) {
    return switch (key) {
      'chip.trendIncreasing' => PriceColors.up,
      'chip.trendDecreasing' => PriceColors.downFor(brightness),
      _ => PriceColors.flatFor(brightness),
    };
  }
}
