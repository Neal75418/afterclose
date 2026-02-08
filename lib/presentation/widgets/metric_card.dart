import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 共用指標卡片 Widget
///
/// 顯示帶有圖示、數值、標籤的指標卡片，用於基本面和內部人資料頁面。
/// 支援警示狀態（加粗邊框 + 紅色文字）。
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor = Colors.blue,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color accentColor;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(
          color: isWarning
              ? AppTheme.errorColor.withValues(alpha: 0.5)
              : accentColor.withValues(alpha: 0.3),
          width: isWarning ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isWarning ? AppTheme.errorColor : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
