import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/pinned_thesis_provider.dart';

/// 釘選論點追蹤區（出場層 Phase 2，今日頁下方 / 警示頁共用卡片）
///
/// 空狀態渲染 nothing（零噪音）。[invalidatedOnly] = 警示頁模式：
/// 只列 INVALIDATED、動作為封存。
class PinnedThesisSection extends ConsumerWidget {
  const PinnedThesisSection({super.key, this.invalidatedOnly = false});

  final bool invalidatedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pinnedThesisProvider);
    final state = async.value;
    if (state == null) return const SizedBox.shrink();

    final theses = invalidatedOnly
        ? state.invalidated
        : [...state.active, ...state.invalidated];
    if (theses.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final title = invalidatedOnly
        ? 'thesis.alertSectionTitle'.tr()
        : 'thesis.sectionTitle'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing16,
            vertical: DesignTokens.spacing8,
          ),
          child: Text(
            '$title (${theses.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        for (final thesis in theses)
          _ThesisCard(
            thesis: thesis,
            currentClose: state.currentCloses[thesis.symbol],
            isDelisted: state.inactiveSymbols.contains(thesis.symbol),
          ),
      ],
    );
  }
}

class _ThesisCard extends ConsumerWidget {
  const _ThesisCard({
    required this.thesis,
    required this.currentClose,
    required this.isDelisted,
  });

  final PinnedThesisEntry thesis;
  final double? currentClose;
  final bool isDelisted;

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isActive = thesis.status == 'ACTIVE';
    final statusColor = isActive
        ? DesignTokens.successColor(theme)
        : theme.colorScheme.error;

    final diffPct = (currentClose != null && thesis.referencePrice > 0)
        ? (currentClose! / thesis.referencePrice - 1) * 100
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing16,
        vertical: DesignTokens.spacing4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  thesis.symbol,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: DesignTokens.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    isActive
                        ? 'thesis.statusActive'.tr()
                        : '${'thesis.statusInvalidated'.tr()}·${'thesis.reasonTimeStop'.tr()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (isActive)
                  IconButton(
                    tooltip: 'thesis.cancel'.tr(),
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(pinnedThesisProvider.notifier)
                        .cancel(thesis.id),
                  )
                else
                  IconButton(
                    tooltip: 'thesis.archive'.tr(),
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(pinnedThesisProvider.notifier)
                        .archive(thesis.id),
                  ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing4),
            Text(
              'thesis.refVsCurrent'.tr(
                namedArgs: {
                  'ref': thesis.referencePrice.toStringAsFixed(2),
                  'current':
                      currentClose?.toStringAsFixed(2) ?? 'thesis.noPrice'.tr(),
                  'diff': diffPct?.toStringAsFixed(1) ?? '—',
                },
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: DesignTokens.spacing4),
            Text(
              [
                'thesis.pinnedOn'.tr(
                  namedArgs: {'date': _fmtDate(thesis.pinnedDate)},
                ),
                if (thesis.lastCheckedDate != null)
                  'thesis.lastChecked'.tr(
                    namedArgs: {'date': _fmtDate(thesis.lastCheckedDate!)},
                  ),
              ].join('　'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (isDelisted) ...[
              const SizedBox(height: DesignTokens.spacing4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 14,
                    color: DesignTokens.warningColor(theme),
                  ),
                  const SizedBox(width: DesignTokens.spacing4),
                  Text(
                    'thesis.delisted'.tr(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: DesignTokens.warningColor(theme),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
