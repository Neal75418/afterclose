import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/pinned_thesis_provider.dart';

/// 釘選論點追蹤區（出場層 Phase 2，今日頁頂部 / 警示頁共用）
///
/// 空狀態渲染 nothing（零噪音）。[invalidatedOnly] = 警示頁模式：
/// 只列 INVALIDATED、動作為封存、恆展開。
///
/// 今日頁模式 = **一行摘要 strip + 可收合卡片**：失效是稀有事件
/// （gate 實測 60 日觸發率 8-15%），按變化頻率分層——平日收合一行
/// 不佔推薦版面；**有失效時 strip 轉紅並自動展開**（事件驅動顯眼度）。
class PinnedThesisSection extends ConsumerStatefulWidget {
  const PinnedThesisSection({super.key, this.invalidatedOnly = false});

  final bool invalidatedOnly;

  @override
  ConsumerState<PinnedThesisSection> createState() =>
      _PinnedThesisSectionState();
}

class _PinnedThesisSectionState extends ConsumerState<PinnedThesisSection> {
  /// 使用者手動展開/收合的覆寫；null = 跟隨預設（有失效 → 展開）
  bool? _expandedOverride;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pinnedThesisProvider);
    final state = async.value;
    if (state == null) return const SizedBox.shrink();

    final theses = widget.invalidatedOnly
        ? state.invalidated
        : [...state.active, ...state.invalidated];
    if (theses.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasInvalidated = state.invalidated.isNotEmpty;
    // 警示頁恆展開；今日頁預設「有失效才展開」、可手動覆寫
    final expanded =
        widget.invalidatedOnly || (_expandedOverride ?? hasInvalidated);
    final stripColor = hasInvalidated && !widget.invalidatedOnly
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    final summaryParts = [
      if (!widget.invalidatedOnly && state.active.isNotEmpty)
        'thesis.summaryActive'.tr(
          namedArgs: {'n': state.active.length.toString()},
        ),
      if (hasInvalidated)
        'thesis.summaryInvalidated'.tr(
          namedArgs: {'n': state.invalidated.length.toString()},
        ),
    ];
    final title = widget.invalidatedOnly
        ? '${'thesis.alertSectionTitle'.tr()} (${theses.length})'
        : '📌 ${summaryParts.join(' · ')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: widget.invalidatedOnly
              ? null
              : () => setState(() => _expandedOverride = !expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing16,
              vertical: DesignTokens.spacing8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: stripColor,
                    ),
                  ),
                ),
                if (!widget.invalidatedOnly)
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: stripColor,
                  ),
              ],
            ),
          ),
        ),
        if (expanded)
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
