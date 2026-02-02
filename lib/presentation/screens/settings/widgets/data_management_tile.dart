import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/today_provider.dart';

/// Data management tile for force sync and historical data progress
class DataManagementTile extends ConsumerStatefulWidget {
  const DataManagementTile({super.key});

  @override
  ConsumerState<DataManagementTile> createState() => _DataManagementTileState();
}

class _DataManagementTileState extends ConsumerState<DataManagementTile> {
  bool _isSyncing = false;
  String? _syncResult;
  bool? _syncSuccess;
  ({int completed, int total})? _historyProgress;

  @override
  void initState() {
    super.initState();
    _loadHistoryProgress();
  }

  Future<void> _loadHistoryProgress() async {
    final db = ref.read(databaseProvider);
    final progress = await db.getHistoricalDataProgress();
    if (mounted) {
      setState(() => _historyProgress = progress);
    }
  }

  Future<void> _forceSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.forceSyncTitle'.tr()),
        content: Text('settings.forceSyncConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('settings.forceSync'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSyncing = true;
      _syncResult = null;
      _syncSuccess = null;
    });

    try {
      final result = await ref
          .read(todayProvider.notifier)
          .runUpdate(forceFetch: true);

      if (mounted) {
        final hasRateLimitError = result.errors.any(
          (e) =>
              e.contains('流量') ||
              e.contains('limit') ||
              e.contains('quota') ||
              e.contains('429'),
        );

        if (hasRateLimitError) {
          _showRateLimitDialog();
        }

        setState(() {
          _isSyncing = false;
          _syncSuccess = result.success;
          _syncResult = result.success
              ? 'settings.forceSyncSuccess'.tr(
                  namedArgs: {
                    'prices': result.pricesUpdated.toString(),
                    'analyzed': result.stocksAnalyzed.toString(),
                  },
                )
              : 'settings.forceSyncFailed'.tr(
                  namedArgs: {
                    'error': result.errors.isNotEmpty
                        ? result.errors.first
                        : 'Unknown error',
                  },
                );
        });
        _loadHistoryProgress();
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        final isRateLimit =
            errorStr.contains('流量') ||
            errorStr.contains('limit') ||
            errorStr.contains('quota') ||
            errorStr.contains('429');

        if (isRateLimit) {
          _showRateLimitDialog();
        }

        setState(() {
          _isSyncing = false;
          _syncSuccess = false;
          _syncResult = 'settings.forceSyncFailed'.tr(
            namedArgs: {'error': errorStr},
          );
        });
      }
    }
  }

  void _showRateLimitDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: Text('settings.rateLimitTitle'.tr()),
        content: Text('settings.rateLimitMessage'.tr()),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.rateLimitOk'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.sync_rounded, color: theme.colorScheme.primary),
          title: Text('settings.forceSync'.tr()),
          subtitle: Text('settings.forceSyncDescription'.tr()),
          trailing: _isSyncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isSyncing ? null : _forceSync,
        ),
        if (_syncResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _syncSuccess == true ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: _syncSuccess == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _syncResult!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _syncSuccess == true ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_historyProgress != null) _buildHistoryProgress(theme),
      ],
    );
  }

  Widget _buildHistoryProgress(ThemeData theme) {
    final progress = _historyProgress!;
    final percent = progress.total > 0
        ? (progress.completed / progress.total * 100).round()
        : 0;
    final isComplete = percent >= 100;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.history,
                size: 16,
                color: isComplete
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'settings.historyProgress'.tr(
                    namedArgs: {
                      'completed': progress.completed.toString(),
                      'total': progress.total.toString(),
                      'percent': percent.toString(),
                    },
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.total > 0
                  ? progress.completed / progress.total
                  : 0,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? Colors.green : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
