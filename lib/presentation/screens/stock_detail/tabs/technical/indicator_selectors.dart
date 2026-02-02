import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/core/constants/animations.dart';

/// Selector for main chart indicators (MA, BOLL, SAR).
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'stockDetail.mainChart'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _IndicatorChip(
                  label: 'MA',
                  color: const Color(0xFF3498DB),
                  isSelected: selectedIndicators.contains(MainState.MA),
                  onTap: () => onToggle(MainState.MA),
                ),
                _IndicatorChip(
                  label: 'BOLL',
                  color: const Color(0xFF9B59B6),
                  isSelected: selectedIndicators.contains(MainState.BOLL),
                  onTap: () => onToggle(MainState.BOLL),
                ),
                _IndicatorChip(
                  label: 'SAR',
                  color: const Color(0xFFE67E22),
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

/// Selector for secondary chart indicators (MACD, KDJ, RSI, WR, CCI).
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            'stockDetail.subChart'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _IndicatorChip(
                  label: 'MACD',
                  color: const Color(0xFF3498DB),
                  isSelected: selectedIndicators.contains(SecondaryState.MACD),
                  onTap: () => onToggle(SecondaryState.MACD),
                ),
                _IndicatorChip(
                  label: 'KDJ',
                  color: const Color(0xFFE67E22),
                  isSelected: selectedIndicators.contains(SecondaryState.KDJ),
                  onTap: () => onToggle(SecondaryState.KDJ),
                ),
                _IndicatorChip(
                  label: 'RSI',
                  color: const Color(0xFF9B59B6),
                  isSelected: selectedIndicators.contains(SecondaryState.RSI),
                  onTap: () => onToggle(SecondaryState.RSI),
                ),
                _IndicatorChip(
                  label: 'WR',
                  color: const Color(0xFF1ABC9C),
                  isSelected: selectedIndicators.contains(SecondaryState.WR),
                  onTap: () => onToggle(SecondaryState.WR),
                ),
                _IndicatorChip(
                  label: 'CCI',
                  color: const Color(0xFFE74C3C),
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

/// A single toggle chip for an indicator.
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
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
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
