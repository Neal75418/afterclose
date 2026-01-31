import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';

/// AI 智慧分析摘要卡片
///
/// 顯示在個股詳情頁 header 與 tab bar 之間，可收合。
class AiSummaryCard extends ConsumerStatefulWidget {
  const AiSummaryCard({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends ConsumerState<AiSummaryCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockDetailProvider(widget.symbol));
    final summary = state.aiSummary;
    final theme = Theme.of(context);

    if (summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題列
            _buildHeader(summary, theme),

            // 內容（可收合）
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? _buildContent(summary, theme)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StockSummary summary, ThemeData theme) {
    final sentimentColor = switch (summary.sentiment) {
      SummarySentiment.bullish => AppTheme.upColor,
      SummarySentiment.bearish => AppTheme.downColor,
      SummarySentiment.neutral => AppTheme.neutralColor,
    };
    final sentimentLabel = switch (summary.sentiment) {
      SummarySentiment.bullish => 'summary.sentimentBullish'.tr(),
      SummarySentiment.bearish => 'summary.sentimentBearish'.tr(),
      SummarySentiment.neutral => 'summary.sentimentNeutral'.tr(),
    };

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'summary.title'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: sentimentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sentimentLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: sentimentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StockSummary summary, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 總體評估
          Text(
            summary.overallAssessment,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),

          // 關鍵訊號
          if (summary.hasSignals) ...[
            const SizedBox(height: 12),
            _buildSectionTitle(
              theme,
              Icons.trending_up,
              'summary.keySignals'.tr(),
              AppTheme.upColor,
            ),
            const SizedBox(height: 4),
            ...summary.keySignals.map(
              (s) => _buildBulletItem(theme, s, AppTheme.upColor),
            ),
          ],

          // 風險提示
          if (summary.hasRisks) ...[
            const SizedBox(height: 12),
            _buildSectionTitle(
              theme,
              Icons.warning_amber_rounded,
              'summary.riskFactors'.tr(),
              Colors.orange,
            ),
            const SizedBox(height: 4),
            ...summary.riskFactors.map(
              (s) => _buildBulletItem(theme, s, Colors.orange),
            ),
          ],

          // 輔助數據
          if (summary.hasSupportingData) ...[
            const SizedBox(height: 12),
            _buildSectionTitle(
              theme,
              Icons.bar_chart,
              'summary.supportingDataTitle'.tr(),
              theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            ...summary.supportingData.map(
              (s) => _buildBulletItem(
                theme,
                s,
                theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          // 免責聲明
          const SizedBox(height: 12),
          Text(
            'summary.disclaimer'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    IconData icon,
    String title,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(ThemeData theme, String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
