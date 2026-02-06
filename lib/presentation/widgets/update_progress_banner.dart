import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 增強版更新進度橫幅，具備：
/// - 步驟指示器（例如「3/10」）
/// - 圓角漸層進度條
/// - 流暢的動畫過渡效果
/// - 作用中狀態的脈動動畫
class UpdateProgressBanner extends StatelessWidget {
  const UpdateProgressBanner({super.key, required this.progress});

  final UpdateProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 依據主題的漸層顏色
    final gradientColors = isDark
        ? [AppTheme.primaryColor, AppTheme.secondaryColor]
        : [const Color(0xFF2196F3), const Color(0xFF00BCD4)];

    final backgroundColor = isDark
        ? const Color(0xFF1A2A3A)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.3);

    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(
                  alpha: isDark ? 0.15 : 0.1,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 標題列：圖示 + 訊息 + 步驟指示器
                Row(
                  children: [
                    // 同步圖示（靜態，避免與更新按鈕的旋轉動畫重複）
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusMd,
                        ),
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 訊息
                    Expanded(
                      child: Text(
                        progress.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 步驟指示器標籤
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            gradientColors[0].withValues(alpha: 0.2),
                            gradientColors[1].withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusLg,
                        ),
                        border: Border.all(
                          color: gradientColors[0].withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${progress.currentStep}/${progress.totalSteps}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: gradientColors[0],
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 動畫漸層進度條
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.progress),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusSm,
                      ),
                      child: Stack(
                        children: [
                          // 軌道
                          Container(
                            height: 8,
                            width: double.infinity,
                            color: trackColor,
                          ),
                          // 帶漸層的進度填充
                          FractionallySizedBox(
                            widthFactor: value.clamp(0.0, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                ),
                                borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusSm,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradientColors[0].withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 進行中狀態的微光覆蓋層
                          if (value > 0 && value < 1)
                            FractionallySizedBox(
                              widthFactor: value.clamp(0.0, 1.0),
                              child:
                                  Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      )
                                      .animate(onPlay: (c) => c.repeat())
                                      .shimmer(
                                        duration: 1200.ms,
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // 百分比文字
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.progress * 100),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      '${value.toInt()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.2, duration: 300.ms, curve: Curves.easeOut);
  }
}

/// 精簡版本，適用於 AppBar 或較小空間
class UpdateProgressCompact extends StatelessWidget {
  const UpdateProgressCompact({super.key, required this.progress});

  final UpdateProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: progress.progress,
            strokeWidth: 2.5,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${progress.currentStep}/${progress.totalSteps}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
