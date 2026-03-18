import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/domain/services/chip_anomaly_service.dart';

/// 籌碼異動摘要列
///
/// 依類型分群顯示異動數量，點展開可看個股明細。
class ChipAnomalyRow extends StatelessWidget {
  const ChipAnomalyRow({super.key, required this.anomalies});

  final List<ChipAnomaly> anomalies;

  @override
  Widget build(BuildContext context) {
    if (anomalies.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // 依類型分群
    final grouped = <ChipAnomalyType, List<ChipAnomaly>>{};
    for (final a in anomalies) {
      grouped.putIfAbsent(a.type, () => []).add(a);
    }

    // 依嚴重度排序：high 先於 medium
    final sortedTypes = grouped.keys.toList()
      ..sort((a, b) {
        final sa = grouped[a]!.first.severity;
        final sb = grouped[b]!.first.severity;
        if (sa == sb) return a.index.compareTo(b.index);
        return sa == ChipSeverity.high ? -1 : 1;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketOverview.chipAnomaly.title'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...() {
          // 自動展開第一個 high severity card
          bool hasExpandedFirst = false;
          return sortedTypes.map((type) {
            final items = grouped[type]!;
            final isHigh = items.any((a) => a.severity == ChipSeverity.high);
            final shouldExpand = isHigh && !hasExpandedFirst;
            if (shouldExpand) hasExpandedFirst = true;

            return Padding(
              padding: EdgeInsets.only(
                bottom: type != sortedTypes.last ? 6 : 0,
              ),
              child: _AnomalyTypeCard(
                type: type,
                items: items,
                initiallyExpanded: shouldExpand,
              ),
            );
          });
        }(),
      ],
    );
  }
}

class _AnomalyTypeCard extends StatefulWidget {
  const _AnomalyTypeCard({
    required this.type,
    required this.items,
    this.initiallyExpanded = false,
  });

  final ChipAnomalyType type;
  final List<ChipAnomaly> items;
  final bool initiallyExpanded;

  @override
  State<_AnomalyTypeCard> createState() => _AnomalyTypeCardState();
}

class _AnomalyTypeCardState extends State<_AnomalyTypeCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _typeMeta(widget.type);
    final isHigh = widget.items.any((a) => a.severity == ChipSeverity.high);
    final accentColor = isHigh ? AppTheme.downColor : Colors.orange;

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 標題列（可點擊展開）
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusSm,
                      ),
                    ),
                    child: Icon(meta.icon, size: 13, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meta.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusSm,
                      ),
                      color: accentColor.withValues(alpha: 0.1),
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: DesignTokens.fontSizeXs,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // 展開明細
          if (_expanded) ...[
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: widget.items
                    .map((a) => _AnomalyItem(anomaly: a))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnomalyItem extends StatelessWidget {
  const _AnomalyItem({required this.anomaly});

  final ChipAnomaly anomaly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              anomaly.symbol,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              anomaly.stockName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (anomaly.keyValue != null)
            Text(
              anomaly.keyValue!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: anomaly.severity == ChipSeverity.high
                    ? AppTheme.downColor
                    : Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: DesignTokens.fontSizeXs,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

/// 每種異動類型的顯示資訊
class _TypeMeta {
  const _TypeMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

_TypeMeta _typeMeta(ChipAnomalyType type) {
  switch (type) {
    case ChipAnomalyType.highPledge:
      return _TypeMeta(
        icon: Icons.lock_outline_rounded,
        label: 'marketOverview.chipAnomaly.highPledge'.tr(),
      );
    case ChipAnomalyType.insiderTransfer:
      return _TypeMeta(
        icon: Icons.swap_horiz_rounded,
        label: 'marketOverview.chipAnomaly.insiderTransfer'.tr(),
      );
    case ChipAnomalyType.foreignNearLimit:
      return _TypeMeta(
        icon: Icons.flag_rounded,
        label: 'marketOverview.chipAnomaly.foreignNearLimit'.tr(),
      );
    case ChipAnomalyType.shortSurge:
      return _TypeMeta(
        icon: Icons.trending_down_rounded,
        label: 'marketOverview.chipAnomaly.shortSurge'.tr(),
      );
    case ChipAnomalyType.institutionalSurge:
      return _TypeMeta(
        icon: Icons.flash_on_rounded,
        label: 'marketOverview.chipAnomaly.institutionalSurge'.tr(),
      );
  }
}
