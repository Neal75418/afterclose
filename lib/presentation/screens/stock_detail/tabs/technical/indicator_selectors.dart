import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// 主圖指標選擇器（MA、BOLL、SAR）
class MainIndicatorSelector extends StatelessWidget {
  const MainIndicatorSelector({
    super.key,
    required this.selectedIndicators,
    required this.onToggle,
  });

  final Set<MainState> selectedIndicators;
  final ValueChanged<MainState> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing12,
        vertical: DesignTokens.spacing8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: DesignTokens.spacing8),
          Text(
            'stockDetail.mainChart'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: DesignTokens.spacing12),
          Expanded(
            child: Wrap(
              spacing: DesignTokens.spacing8,
              runSpacing: DesignTokens.spacing8,
              children: [
                _IndicatorChip(
                  label: 'MA',
                  color: IndicatorColors.selectorBlue,
                  isSelected: selectedIndicators.contains(MainState.MA),
                  onTap: () => onToggle(MainState.MA),
                ),
                _IndicatorChip(
                  label: 'BOLL',
                  color: IndicatorColors.selectorPurple,
                  isSelected: selectedIndicators.contains(MainState.BOLL),
                  onTap: () => onToggle(MainState.BOLL),
                ),
                _IndicatorChip(
                  label: 'SAR',
                  color: IndicatorColors.selectorOrange,
                  isSelected: selectedIndicators.contains(MainState.SAR),
                  onTap: () => onToggle(MainState.SAR),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 副圖指標選擇器（MACD、KDJ、RSI、WR、CCI）
class SecondaryIndicatorSelector extends StatelessWidget {
  const SecondaryIndicatorSelector({
    super.key,
    required this.selectedIndicators,
    required this.onToggle,
  });

  final Set<SecondaryState> selectedIndicators;
  final ValueChanged<SecondaryState> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing12,
        vertical: DesignTokens.spacing8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: DesignTokens.spacing8),
          Text(
            'stockDetail.subChart'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: DesignTokens.spacing12),
          Expanded(
            child: Wrap(
              spacing: DesignTokens.spacing8,
              runSpacing: DesignTokens.spacing8,
              children: [
                _IndicatorChip(
                  label: 'MACD',
                  color: IndicatorColors.selectorBlue,
                  isSelected: selectedIndicators.contains(SecondaryState.MACD),
                  onTap: () => onToggle(SecondaryState.MACD),
                ),
                _IndicatorChip(
                  label: 'KDJ',
                  color: IndicatorColors.selectorOrange,
                  isSelected: selectedIndicators.contains(SecondaryState.KDJ),
                  onTap: () => onToggle(SecondaryState.KDJ),
                ),
                _IndicatorChip(
                  label: 'RSI',
                  color: IndicatorColors.selectorPurple,
                  isSelected: selectedIndicators.contains(SecondaryState.RSI),
                  onTap: () => onToggle(SecondaryState.RSI),
                ),
                _IndicatorChip(
                  label: 'WR',
                  color: IndicatorColors.selectorTeal,
                  isSelected: selectedIndicators.contains(SecondaryState.WR),
                  onTap: () => onToggle(SecondaryState.WR),
                ),
                _IndicatorChip(
                  label: 'CCI',
                  color: IndicatorColors.selectorRed,
                  isSelected: selectedIndicators.contains(SecondaryState.CCI),
                  onTap: () => onToggle(SecondaryState.CCI),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 單一指標切換 Chip
class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AnimDurations.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing12,
          vertical: DesignTokens.spacing6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          border: Border.all(
            color: isSelected
                ? color
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? color : theme.colorScheme.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DesignTokens.spacing6),
            Text(
              label,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                // 選中態底是 color@0.15 tint，本色文字合成後 2.0~4.2:1，
                // 改走各 selector 的疊色專屬文字色
                color: isSelected
                    ? IndicatorColors.selectorOnTint(color, theme.brightness)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
