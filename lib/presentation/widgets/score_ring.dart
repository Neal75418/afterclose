import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// ScoreRing 的預設尺寸變體
enum ScoreRingSize {
  /// 小型：28x28，線寬 2.5，字型大小 9
  small(28.0, 2.5, 9.0),

  /// 中型：32x32，線寬 3，字型大小 10
  medium(32.0, 3.0, 10.0),

  /// 大型：40x40，線寬 3.5，字型大小 12
  large(40.0, 3.5, 12.0),

  /// 特大型：48x48，線寬 4，字型大小 14（用於預覽面板）
  extraLarge(48.0, 4.0, 14.0);

  const ScoreRingSize(this.dimension, this.strokeWidth, this.fontSize);

  final double dimension;
  final double strokeWidth;
  final double fontSize;
}

/// 顯示分數值的圓形進度環
///
/// 特色：
/// - 依據分數顯示不同顏色的進度環
/// - 中央顯示分數文字
/// - 可設定的尺寸變體
/// - 無障礙語意標籤
@immutable
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.size = ScoreRingSize.medium,
    this.maxScore = 100.0,
  });

  /// 要顯示的分數（0-maxScore）
  final double score;

  /// 圓環的尺寸變體
  final ScoreRingSize size;

  /// 最大可能分數（預設：100）
  final double maxScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = AppTheme.getScoreColor(score);
    final progress = (score / maxScore).clamp(0.0, 1.0);
    final displayScore = score.toInt();

    return Semantics(
      label: '評分 $displayScore 分',
      child: SizedBox(
        width: size.dimension,
        height: size.dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背景圓環
            CircularProgressIndicator(
              value: 1.0,
              strokeWidth: size.strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                scoreColor.withValues(alpha: 0.2),
              ),
            ),
            // 進度圓環
            CircularProgressIndicator(
              value: progress,
              strokeWidth: size.strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              strokeCap: StrokeCap.round,
            ),
            // 中央的分數文字
            Text(
              '$displayScore',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scoreColor,
                fontWeight: FontWeight.bold,
                fontSize: size.fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
