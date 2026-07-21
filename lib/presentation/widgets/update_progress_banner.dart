import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';

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
    final isDark = context.isDark;

    // 漸層 icon 盒的前景依主題分流：淺色 primary 是深藍（#1D4ED8）白圖示
    // 6.70/3.68:1 合格；深色 primary 是淺藍（#60A5FA）白圖示僅 2.54:1，
    // 改用 onBrand 深字（6.97/4.82:1）——與「加入自選」等品牌填色按鈕的
    // M3 深字邏輯一致。
    final gradientColors = [
      theme.colorScheme.primary,
      AppTheme.brandDecorative,
    ];
    final iconOnGradient = context.isDark
        ? QualityColors.onBrand
        : Colors.white;

    final backgroundColor = isDark
        ? theme.colorScheme.surfaceContainerLow
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
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(
                  alpha: isDark
                      ? DesignTokens.opacity15
                      : DesignTokens.opacity10,
                ),
                blurRadius: DesignTokens.shadowBlurMd,
                offset: DesignTokens.shadowOffsetMd,
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
                      child: Icon(Icons.sync, color: iconOnGradient, size: 18),
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
                        // 雙層 tint（banner 底 + chip 漸層）合成後，primary
                        // 本色僅 3.2~3.9:1；改走深疊色專屬文字色
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark
                              ? QualityColors.brandOnDecorative
                              : QualityColors.brandOnDeepTintLight,
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
                  duration: AnimDurations.normal,
                  curve: AnimCurves.decelerate,
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
                                    blurRadius: DesignTokens.shadowBlurSm,
                                    offset: DesignTokens.shadowOffsetSm,
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
                  duration: AnimDurations.normal,
                  curve: AnimCurves.decelerate,
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
        .fadeIn(duration: AnimDurations.normal)
        .slideY(
          begin: -0.2,
          duration: AnimDurations.normal,
          curve: AnimCurves.enter,
        );
  }
}
