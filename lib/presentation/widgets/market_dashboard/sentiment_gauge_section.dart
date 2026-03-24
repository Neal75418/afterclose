import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/domain/services/market_sentiment_service.dart';
import 'package:afterclose/presentation/widgets/stock_card_sparkline.dart';

/// 市場情緒儀表板
///
/// 顯示市場情緒分數 (0-100)、等級、漸層 bar 指標位置、6 項子指標。
class SentimentGaugeSection extends StatelessWidget {
  const SentimentGaugeSection({
    super.key,
    required this.sentiment,
    this.sentimentHistory = const [],
  });

  final MarketSentiment sentiment;

  /// 歷史情緒分數（oldest→newest），用於趨勢 sparkline
  final List<double> sentimentHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _levelColor(sentiment.level);
    final levelText = _levelText(sentiment.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題行
        Text(
          'marketOverview.sentiment.title'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DesignTokens.spacing10),

        Container(
          padding: const EdgeInsets.all(DesignTokens.spacing14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            color: theme.colorScheme.surfaceContainerLowest,
          ),
          child: Column(
            children: [
              // 大數字 + 等級標籤
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    sentiment.score.toStringAsFixed(0),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusSm,
                      ),
                    ),
                    child: Text(
                      levelText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing12),

              // 漸層 bar + 三角形指標
              _GradientBar(score: sentiment.score),
              const SizedBox(height: DesignTokens.spacing14),

              // 子指標 grid (2×3)
              if (sentiment.subScores.isNotEmpty)
                _SubScoresGrid(subScores: sentiment.subScores),

              // 趨勢 sparkline
              if (sentimentHistory.length >= 5) ...[
                const SizedBox(height: DesignTokens.spacing10),
                Row(
                  children: [
                    Text(
                      'marketOverview.sentiment.trend'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: DesignTokens.fontSizeXs,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: MiniSparkline(
                          prices: sentimentHistory,
                          color: color,
                          width: double.infinity,
                          height: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static Color _levelColor(SentimentLevel level) {
    return switch (level) {
      SentimentLevel.extremeFear => const Color(0xFF1B5E20),
      SentimentLevel.fear => AppTheme.downColor,
      SentimentLevel.neutral => AppTheme.neutralColor,
      SentimentLevel.greed => AppTheme.upColor,
      SentimentLevel.extremeGreed => const Color(0xFFB71C1C),
    };
  }

  static String _levelText(SentimentLevel level) {
    final key = switch (level) {
      SentimentLevel.extremeFear => 'marketOverview.sentiment.extremeFear',
      SentimentLevel.fear => 'marketOverview.sentiment.fear',
      SentimentLevel.neutral => 'marketOverview.sentiment.neutral',
      SentimentLevel.greed => 'marketOverview.sentiment.greed',
      SentimentLevel.extremeGreed => 'marketOverview.sentiment.extremeGreed',
    };
    return key.tr();
  }
}

/// 漸層 bar (綠→灰→紅) + 三角形指標
class _GradientBar extends StatelessWidget {
  const _GradientBar({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // 指標三角形
        LayoutBuilder(
          builder: (context, constraints) {
            final position = constraints.maxWidth * (score / 100);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(height: 8, width: constraints.maxWidth),
                Positioned(
                  left: position - 5,
                  bottom: 0,
                  child: CustomPaint(
                    size: const Size(10, 6),
                    painter: _TrianglePainter(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // 漸層條
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
          child: Container(
            height: 8,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1B5E20), // 極度恐懼
                  Color(0xFF4CAF50), // 恐懼
                  Color(0xFF9E9E9E), // 中性
                  Color(0xFFEF5350), // 貪婪
                  Color(0xFFB71C1C), // 極度貪婪
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spacing4),
        // 標籤行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'marketOverview.sentiment.fearLabel'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                fontSize: DesignTokens.fontSizeXs,
              ),
            ),
            Text(
              'marketOverview.sentiment.greedLabel'.tr(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                fontSize: DesignTokens.fontSizeXs,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      color != oldDelegate.color;
}

/// 子指標 grid (2×3 排列)
class _SubScoresGrid extends StatelessWidget {
  const _SubScoresGrid({required this.subScores});

  final Map<String, double> subScores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 定義顯示順序與名稱
    const indicators = [
      ('advanceRatio', 'marketOverview.sentiment.advanceRatio'),
      ('institutional', 'marketOverview.sentiment.institutional'),
      ('volumeMomentum', 'marketOverview.sentiment.volumeMomentum'),
      ('marginChange', 'marketOverview.sentiment.marginChange'),
      ('limitRatio', 'marketOverview.sentiment.limitRatio'),
      ('industryBreadth', 'marketOverview.sentiment.industryBreadth'),
    ];

    final items = indicators
        .where((ind) => subScores.containsKey(ind.$1))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 每列 3 個 item，扣除 2 個 spacing
        const columns = 3;
        const spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: DesignTokens.spacing6,
          children: items.map((ind) {
            final score = subScores[ind.$1]!;
            final color = _scoreColor(score);
            return SizedBox(
              width: itemWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing4),
                  Flexible(
                    child: Text(
                      ind.$2.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: DesignTokens.fontSizeXs,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing4),
                  Text(
                    score.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: DesignTokens.fontSizeXs,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static Color _scoreColor(double score) {
    if (score < 30) return AppTheme.downColor;
    if (score > 70) return AppTheme.upColor;
    return AppTheme.neutralColor;
  }
}
