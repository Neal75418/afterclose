import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';

/// 注意/處置股摘要列
///
/// 顯示目前生效的注意股與處置股家數
class WarningsSummaryRow extends StatelessWidget {
  const WarningsSummaryRow({super.key, required this.data});

  final WarningCounts data;

  @override
  Widget build(BuildContext context) {
    if (data.total == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'marketOverview.warnings'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (data.attention > 0) ...[
            _WarningBadge(
              label: 'marketOverview.attentionCount'.tr(
                namedArgs: {'count': '${data.attention}'},
              ),
              color: Colors.orange,
            ),
          ],
          if (data.attention > 0 && data.disposal > 0) const SizedBox(width: 8),
          if (data.disposal > 0) ...[
            _WarningBadge(
              label: 'marketOverview.disposalCount'.tr(
                namedArgs: {'count': '${data.disposal}'},
              ),
              color: Colors.red,
            ),
          ],
        ],
      ),
    );
  }
}

class _WarningBadge extends StatelessWidget {
  const _WarningBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        color: color.withValues(alpha: 0.1),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: DesignTokens.fontSizeXs,
        ),
      ),
    );
  }
}
