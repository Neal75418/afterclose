import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/update_history_provider.dart';

/// Today screen 上 tap 「最後更新時間」會彈出此 sheet
///
/// 顯示最近 30 筆 `update_run` 紀錄：時間 / 耗時 / 狀態 / 訊息。Failed /
/// partial 的 row 可以展開看完整 message（含 stack trace 摘要）。
class UpdateHistorySheet extends ConsumerWidget {
  const UpdateHistorySheet({super.key});

  /// Helper：從任意 context 開啟此 sheet
  ///
  /// `isScrollControlled: true` 讓 sheet 高度可以隨內容（list 滾動），
  /// `useRootNavigator: true` 避免被 bottom nav 蓋到。
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => const UpdateHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(updateHistoryProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Title bar 不放手動 refresh 按鈕 — provider 已透過
            // dataUpdateEpochProvider 在任何 update 完成時自動 reload，
            // 而且打開 sheet 時就會 fetch 最新。手動按按鈕 99% 時間沒事做
            // （DB 沒變化），看起來像壞掉，整層移除。
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.spacing16,
                DesignTokens.spacing8,
                DesignTokens.spacing16,
                DesignTokens.spacing12,
              ),
              child: Text(
                'updateHistory.title'.tr(),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: historyAsync.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        'updateHistory.empty'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: DesignTokens.spacing8,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _UpdateRunTile(rows[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spacing16),
                    child: Text(
                      'updateHistory.error'.tr(args: ['$e']),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UpdateRunTile extends StatelessWidget {
  const _UpdateRunTile(this.row);

  final UpdateRunEntry row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _UpdateRunStatus.fromString(row.status);
    final duration = row.finishedAt?.difference(row.startedAt);

    final dateStr = DateFormat('MM-dd HH:mm').format(row.startedAt.toLocal());
    final durationStr = duration == null
        ? 'updateHistory.running'.tr()
        : '${duration.inSeconds}s';

    final hasMessage = row.message != null && row.message!.isNotEmpty;
    // 只在 message 真的「展開有意義」時才用 ExpansionTile：
    //   - 含換行（stack trace / multi-line error）
    //   - 或單行但超長（> 80 字，subtitle ellipsis 後看不到全貌）
    // 大部分 message 是「更新完成」短句，直接平鋪 ListTile 就好，
    // 展開後跟收起完全一樣的 bug。
    final needsExpand =
        hasMessage && (row.message!.contains('\n') || row.message!.length > 80);

    if (needsExpand) {
      return ExpansionTile(
        leading: _StatusIcon(status: status),
        title: _TitleRow(
          dateStr: dateStr,
          durationStr: durationStr,
          status: status,
        ),
        subtitle: Text(
          row.message!.split('\n').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          56,
          0,
          DesignTokens.spacing16,
          DesignTokens.spacing12,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              row.message!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return ListTile(
      leading: _StatusIcon(status: status),
      title: _TitleRow(
        dateStr: dateStr,
        durationStr: durationStr,
        status: status,
      ),
      subtitle: hasMessage
          ? Text(
              row.message!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.dateStr,
    required this.durationStr,
    required this.status,
  });

  final String dateStr;
  final String durationStr;
  final _UpdateRunStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(dateStr, style: theme.textTheme.bodyMedium),
        const SizedBox(width: DesignTokens.spacing8),
        Text(
          durationStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          status.labelKey.tr(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: status.color(theme),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final _UpdateRunStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Icon(status.icon, color: status.color(theme), size: 20);
  }
}

enum _UpdateRunStatus {
  success,
  partial,
  failed,
  running,
  unknown;

  static _UpdateRunStatus fromString(String s) => switch (s.toUpperCase()) {
    'SUCCESS' => _UpdateRunStatus.success,
    'PARTIAL' => _UpdateRunStatus.partial,
    'FAILED' => _UpdateRunStatus.failed,
    'RUNNING' => _UpdateRunStatus.running,
    _ => _UpdateRunStatus.unknown,
  };

  IconData get icon => switch (this) {
    _UpdateRunStatus.success => Icons.check_circle,
    _UpdateRunStatus.partial => Icons.error_outline,
    _UpdateRunStatus.failed => Icons.cancel,
    _UpdateRunStatus.running => Icons.sync,
    _UpdateRunStatus.unknown => Icons.help_outline,
  };

  Color color(ThemeData theme) => switch (this) {
    _UpdateRunStatus.success => Colors.green.shade600,
    _UpdateRunStatus.partial => Colors.orange.shade700,
    _UpdateRunStatus.failed => theme.colorScheme.error,
    _UpdateRunStatus.running => theme.colorScheme.primary,
    _UpdateRunStatus.unknown => theme.colorScheme.onSurfaceVariant,
  };

  String get labelKey => switch (this) {
    _UpdateRunStatus.success => 'updateHistory.statusSuccess',
    _UpdateRunStatus.partial => 'updateHistory.statusPartial',
    _UpdateRunStatus.failed => 'updateHistory.statusFailed',
    _UpdateRunStatus.running => 'updateHistory.statusRunning',
    _UpdateRunStatus.unknown => 'updateHistory.statusUnknown',
  };
}
