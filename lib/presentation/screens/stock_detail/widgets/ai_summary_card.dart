import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/domain/models/stock_summary.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/shimmer_loading.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

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

    if (summary == null) return _buildLoadingSkeleton(theme);

    return Semantics(
      label: _buildSemanticLabel(summary),
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
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
      ),
    );
  }

  String _buildSemanticLabel(StockSummary summary) {
    final parts = <String>['summary.title'.tr()];

    final sentimentLabel = switch (summary.sentiment) {
      SummarySentiment.bullish => 'summary.sentimentBullish'.tr(),
      SummarySentiment.bearish => 'summary.sentimentBearish'.tr(),
      SummarySentiment.neutral => 'summary.sentimentNeutral'.tr(),
    };
    parts.add(sentimentLabel);

    parts.add(summary.overallAssessment);

    if (summary.hasSignals) {
      parts.add('${summary.keySignals.length} ${'summary.keySignals'.tr()}');
    }
    if (summary.hasRisks) {
      parts.add('${summary.riskFactors.length} ${'summary.riskFactors'.tr()}');
    }

    return parts.join(', ');
  }

  Widget _buildLoadingSkeleton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ShimmerContainer(
                    width: 18,
                    height: 18,
                    borderRadius: 4,
                  ),
                  const SizedBox(width: 8),
                  const ShimmerContainer(
                    width: 80,
                    height: 16,
                    borderRadius: 4,
                  ),
                  const SizedBox(width: 8),
                  ShimmerContainer(
                    width: 40,
                    height: 20,
                    borderRadius: 4,
                    semanticLabel: 'summary.title'.tr(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const ShimmerContainer(
                width: double.infinity,
                height: 14,
                borderRadius: 4,
              ),
              const SizedBox(height: 6),
              const ShimmerContainer(width: 240, height: 14, borderRadius: 4),
              const SizedBox(height: 12),
              const ShimmerContainer(width: 200, height: 12, borderRadius: 4),
              const SizedBox(height: 4),
              const ShimmerContainer(width: 180, height: 12, borderRadius: 4),
            ],
          ),
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
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                _Badge(label: sentimentLabel, color: sentimentColor),
                const SizedBox(width: 6),
                _Badge(
                  label: _confidenceLabel(summary.confidence),
                  color: _confidenceColor(summary.confidence, theme),
                ),
                const Spacer(),
                ExcludeSemantics(
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // 訊號強度條
            const SizedBox(height: 8),
            _SignalStrengthBar(summary: summary),
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
              AppTheme.warningColor,
            ),
            const SizedBox(height: 4),
            ...summary.riskFactors.map(
              (s) => _buildBulletItem(theme, s, AppTheme.warningColor),
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

          // 規則準確度（Sprint 10）
          _RuleAccuracySection(symbol: widget.symbol),

          // 快捷操作按鈕
          const SizedBox(height: 12),
          _buildActionButtons(theme),

          // 免責聲明
          const SizedBox(height: 8),
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

  Widget _buildActionButtons(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChip(
          icon: Icons.notifications_outlined,
          label: 'summary.actionSetAlert'.tr(),
          onTap: () => context.push(AppRoutes.alerts),
        ),
        _ActionChip(
          icon: Icons.compare_arrows,
          label: 'summary.actionCompare'.tr(),
          onTap: () => context.push(AppRoutes.compare, extra: [widget.symbol]),
        ),
      ],
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
          ExcludeSemantics(
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
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

  String _confidenceLabel(AnalysisConfidence confidence) {
    return switch (confidence) {
      AnalysisConfidence.high => 'summary.confidenceHigh'.tr(),
      AnalysisConfidence.medium => 'summary.confidenceMedium'.tr(),
      AnalysisConfidence.low => 'summary.confidenceLow'.tr(),
    };
  }

  Color _confidenceColor(AnalysisConfidence confidence, ThemeData theme) {
    return switch (confidence) {
      AnalysisConfidence.high => AppTheme.successColor,
      AnalysisConfidence.medium => AppTheme.warningColor,
      AnalysisConfidence.low => theme.colorScheme.onSurfaceVariant,
    };
  }
}

/// 統一的 badge 樣式（填滿背景）
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: theme.textTheme.labelSmall),
      onPressed: onTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 訊號強度條
///
/// 根據 confluence count、confidence、有無衝突計算整體訊號強度
class _SignalStrengthBar extends StatelessWidget {
  const _SignalStrengthBar({required this.summary});

  final StockSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 計算訊號強度（0.0 ~ 1.0）
    final strength = _calculateStrength();
    final strengthColor = _getStrengthColor(strength);

    return Row(
      children: [
        Icon(
          Icons.signal_cellular_alt,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Text(
          'summary.signalStrength'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: strength,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(strength * 100).toInt()}%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: strengthColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 計算訊號強度
  ///
  /// 基於以下因素：
  /// - 信心度（high=40%, medium=25%, low=10%）
  /// - 匯流數量（每個 +10%，最多 30%）
  /// - 衝突（-20%）
  /// - 有訊號（+10%）
  double _calculateStrength() {
    var strength = 0.0;

    // 信心度基礎分
    strength += switch (summary.confidence) {
      AnalysisConfidence.high => 0.40,
      AnalysisConfidence.medium => 0.25,
      AnalysisConfidence.low => 0.10,
    };

    // 匯流加成（每個 10%，最多 30%）
    strength += (summary.confluenceCount * 0.10).clamp(0.0, 0.30);

    // 有訊號加成
    if (summary.hasSignals || summary.hasRisks) {
      strength += 0.10;
    }

    // 衝突扣減
    if (summary.hasConflict) {
      strength -= 0.20;
    }

    // 有輔助數據加成
    if (summary.hasSupportingData) {
      strength += 0.10;
    }

    return strength.clamp(0.0, 1.0);
  }

  Color _getStrengthColor(double strength) {
    if (strength >= 0.7) return AppTheme.upColor;
    if (strength >= 0.4) return AppTheme.warningColor;
    return AppTheme.neutralColor;
  }
}

/// 規則準確度區塊（Sprint 10）
///
/// 顯示主要觸發規則的歷史命中率和平均報酬率。
class _RuleAccuracySection extends ConsumerWidget {
  const _RuleAccuracySection({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accuracyAsync = ref.watch(primaryRuleAccuracySummaryProvider(symbol));
    final theme = Theme.of(context);

    return accuracyAsync.when(
      data: (summaryText) {
        if (summaryText == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'summary.ruleAccuracy'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summaryText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
