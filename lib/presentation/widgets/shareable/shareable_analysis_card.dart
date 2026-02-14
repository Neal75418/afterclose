import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 分析分享卡片（用於 PNG 匯出）
///
/// 固定尺寸 400×600 dp，pixelRatio 3.0 → 1200×1800 px 輸出。
class ShareableAnalysisCard extends StatelessWidget {
  const ShareableAnalysisCard({super.key, required this.state});

  final StockDetailState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stock = state.price.stock;
    final price = state.price.latestPrice;
    final analysis = state.price.analysis;
    final summary = state.aiSummary;

    final priceChange = state.priceChange;
    final changeColor = priceChange != null && priceChange > 0
        ? AppTheme.upColor
        : priceChange != null && priceChange < 0
        ? AppTheme.downColor
        : AppTheme.neutralColor;

    return SizedBox(
      width: 400,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題: AfterClose 品牌
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AfterClose',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (price != null)
                    Text(
                      DateFormat('yyyy-MM-dd').format(price.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),

              // 股票名稱與價格
              Text(
                '${stock?.symbol ?? ""} ${stock?.name ?? ""}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (price != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price.close?.toStringAsFixed(2) ?? '',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (priceChange != null)
                      Text(
                        '${priceChange >= 0 ? "+" : ""}${priceChange.toStringAsFixed(2)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: changeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),

              // 評分與趨勢
              if (analysis != null)
                Row(
                  children: [
                    _ScoreBadge(score: analysis.score),
                    const SizedBox(width: 12),
                    _TrendChip(trend: analysis.trendState),
                    if (analysis.reversalState != 'NONE') ...[
                      const SizedBox(width: 8),
                      _ReversalChip(reversal: analysis.reversalState),
                    ],
                  ],
                ),
              const SizedBox(height: 16),

              // AI 摘要
              if (summary != null) ...[
                Text(
                  summary.overallAssessment,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // 關鍵訊號
                if (summary.keySignals.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.trending_up,
                    label: 'summary.keySignals'.tr(),
                    color: AppTheme.upColor,
                  ),
                  const SizedBox(height: 4),
                  ...summary.keySignals
                      .take(3)
                      .map(
                        (s) => _BulletItem(text: s, color: AppTheme.upColor),
                      ),
                  const SizedBox(height: 8),
                ],

                // 風險提示
                if (summary.riskFactors.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.warning_amber,
                    label: 'summary.riskFactors'.tr(),
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 4),
                  ...summary.riskFactors
                      .take(2)
                      .map((s) => _BulletItem(text: s, color: Colors.orange)),
                  const SizedBox(height: 8),
                ],
              ],

              // 如果沒有 AI 摘要，顯示主要訊號
              if (summary == null && state.reasons.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.trending_up,
                  label: 'summary.keySignals'.tr(),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 4),
                ...state.reasons
                    .take(5)
                    .map(
                      (r) => _BulletItem(
                        text: ReasonTags.translateReasonCode(r.reasonType),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                const SizedBox(height: 8),
              ],

              const Divider(height: 24),

              // 免責聲明
              Text(
                'export.disclaimer'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getScoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Text(
        '${score.toStringAsFixed(0)} 分',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend});
  final String trend;

  @override
  Widget build(BuildContext context) {
    final isUp = trend == 'UP';
    final color = isUp ? AppTheme.upColor : AppTheme.downColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Text(
        trend,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ReversalChip extends StatelessWidget {
  const _ReversalChip({required this.reversal});
  final String reversal;

  @override
  Widget build(BuildContext context) {
    final isW2S = reversal == 'W2S';
    final color = isW2S ? AppTheme.upColor : AppTheme.downColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        reversal,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
