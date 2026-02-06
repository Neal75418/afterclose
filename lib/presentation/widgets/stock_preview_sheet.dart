import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:afterclose/core/extensions/trend_state_extension.dart';
import 'package:afterclose/core/l10n/app_strings.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/widgets/common/drag_handle.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';
import 'package:afterclose/presentation/widgets/score_ring.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 股票預覽資料
class StockPreviewData {
  const StockPreviewData({
    required this.symbol,
    this.stockName,
    this.latestClose,
    this.priceChange,
    this.score,
    this.trendState,
    this.reasons = const [],
    this.isInWatchlist = false,
  });

  final String symbol;
  final String? stockName;
  final double? latestClose;
  final double? priceChange;
  final double? score;
  final String? trendState;
  final List<String> reasons;
  final bool isInWatchlist;
}

/// 顯示股票預覽 bottom sheet
Future<void> showStockPreviewSheet({
  required BuildContext context,
  required StockPreviewData data,
  VoidCallback? onViewDetails,
  VoidCallback? onToggleWatchlist,
}) {
  HapticFeedback.mediumImpact();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StockPreviewSheet(
      data: data,
      onViewDetails: onViewDetails,
      onToggleWatchlist: onToggleWatchlist,
    ),
  );
}

/// 股票預覽 bottom sheet 元件
class StockPreviewSheet extends StatelessWidget {
  const StockPreviewSheet({
    super.key,
    required this.data,
    this.onViewDetails,
    this.onToggleWatchlist,
  });

  final StockPreviewData data;
  final VoidCallback? onViewDetails;
  final VoidCallback? onToggleWatchlist;

  /// 建構無障礙語義標籤
  String _buildSemanticLabel() {
    final parts = <String>['股票預覽', data.symbol];
    if (data.stockName != null) parts.add(data.stockName!);
    if (data.latestClose != null) {
      parts.add('價格 ${data.latestClose!.toStringAsFixed(2)} 元');
    }
    if (data.priceChange != null) {
      final direction = data.priceChange! >= 0 ? '上漲' : '下跌';
      parts.add('$direction ${data.priceChange!.abs().toStringAsFixed(2)} 百分比');
    }
    if (data.score != null && data.score! > 0) {
      parts.add('評分 ${data.score!.toInt()} 分');
      parts.add(_getScoreLevel(data.score!));
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priceColor = AppTheme.getPriceColor(data.priceChange);
    final isPositive = (data.priceChange ?? 0) >= 0;

    return Semantics(
      label: _buildSemanticLabel(),
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖曳把手
            const DragHandle(),

            // 內容區
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題列
                  Row(
                    children: [
                      // 趨勢指示器
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              data.trendState.trendColor.withValues(alpha: 0.2),
                              data.trendState.trendColor.withValues(
                                alpha: 0.05,
                              ),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusXl,
                          ),
                          border: Border.all(
                            color: data.trendState.trendColor.withValues(
                              alpha: 0.3,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            data.trendState.trendEmoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ).animate().scale(
                        begin: const Offset(0.8, 0.8),
                        duration: 300.ms,
                        curve: Curves.easeOutBack,
                      ),
                      const SizedBox(width: 16),

                      // 代號與名稱
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.symbol,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (data.stockName != null)
                              Text(
                                data.stockName!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 價格區
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (data.latestClose != null)
                            Text(
                              data.latestClose!.toStringAsFixed(2),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (data.priceChange != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: priceColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusMd,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 裝飾圖示 — 文字已包含正負號
                                  ExcludeSemantics(
                                    child: Icon(
                                      isPositive
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                      color: priceColor,
                                      size: 20,
                                    ),
                                  ),
                                  Text(
                                    '${isPositive ? '+' : ''}${data.priceChange!.toStringAsFixed(2)}%',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: priceColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // 評分區
                  if (data.score != null && data.score! > 0) ...[
                    const SizedBox(height: 20),
                    _buildScoreSection(theme),
                  ],

                  // 訊號理由區
                  if (data.reasons.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildReasonsSection(theme, isDark),
                  ],

                  // 操作按鈕
                  const SizedBox(height: 24),
                  Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                onToggleWatchlist?.call();
                              },
                              icon: Icon(
                                data.isInWatchlist
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: data.isInWatchlist ? Colors.amber : null,
                              ),
                              label: Text(
                                data.isInWatchlist
                                    ? S.stockRemoveFromWatchlist
                                    : S.stockAddToWatchlist,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: data.isInWatchlist
                                      ? Colors.amber
                                      : theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                onViewDetails?.call();
                              },
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text(S.stockViewDetails),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 300.ms)
                      .slideY(begin: 0.2, duration: 300.ms),

                  // 底部安全區域
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSection(ThemeData theme) {
    final scoreColor = AppTheme.getScoreColor(data.score!);

    return Row(
      children: [
        // 使用共用 ScoreRing 元件（extraLarge 尺寸）
        ScoreRing(
          score: data.score!,
          size: ScoreRingSize.extraLarge,
        ).animate().scale(
          begin: const Offset(0.5, 0.5),
          delay: 100.ms,
          duration: 400.ms,
          curve: Curves.easeOutBack,
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.scoreLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _getScoreLevel(data.score!),
              style: theme.textTheme.titleSmall?.copyWith(
                color: scoreColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReasonsSection(ThemeData theme, bool isDark) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.reasonsLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ReasonTags(reasons: data.reasons, translateCodes: true),
          ],
        )
        .animate()
        .fadeIn(delay: 100.ms, duration: 300.ms)
        .slideY(begin: 0.1, duration: 300.ms);
  }

  String _getScoreLevel(double score) => S.getScoreLevel(score);
}
