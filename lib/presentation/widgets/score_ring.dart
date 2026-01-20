import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';

/// Predefined size variants for ScoreRing
enum ScoreRingSize {
  /// Small: 28x28, strokeWidth 2.5, fontSize 9
  small(28.0, 2.5, 9.0),

  /// Medium: 32x32, strokeWidth 3, fontSize 10
  medium(32.0, 3.0, 10.0),

  /// Large: 40x40, strokeWidth 3.5, fontSize 12
  large(40.0, 3.5, 12.0);

  const ScoreRingSize(this.dimension, this.strokeWidth, this.fontSize);

  final double dimension;
  final double strokeWidth;
  final double fontSize;
}

/// A circular progress ring showing a score value
///
/// Features:
/// - Progress ring with color based on score
/// - Score text displayed in center
/// - Configurable size variants
/// - Semantic label for accessibility
@immutable
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.size = ScoreRingSize.medium,
    this.maxScore = 100.0,
  });

  /// The score to display (0-maxScore)
  final double score;

  /// Size variant for the ring
  final ScoreRingSize size;

  /// Maximum possible score (default: 100)
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
            // Background ring
            CircularProgressIndicator(
              value: 1.0,
              strokeWidth: size.strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                scoreColor.withValues(alpha: 0.2),
              ),
            ),
            // Progress ring
            CircularProgressIndicator(
              value: progress,
              strokeWidth: size.strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              strokeCap: StrokeCap.round,
            ),
            // Score text in center
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
