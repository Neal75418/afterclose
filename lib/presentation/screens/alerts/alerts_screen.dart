import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/widgets/empty_state.dart';
import 'package:afterclose/presentation/widgets/price_alert_dialog.dart';

/// Screen for managing price alerts
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(priceAlertProvider.notifier).loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceAlertProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('alert.title'.tr())),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.alerts.isEmpty
          ? _buildEmptyState()
          : _buildAlertsList(state.alerts, theme),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAlertDialog(context),
        tooltip: 'alert.create'.tr(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.notifications_off_outlined,
      title: 'alert.noAlerts'.tr(),
      subtitle: 'alert.noAlertsHint'.tr(),
    );
  }

  Widget _buildAlertsList(List<PriceAlertEntry> alerts, ThemeData theme) {
    // Group alerts by symbol
    final groupedAlerts = <String, List<PriceAlertEntry>>{};
    for (final alert in alerts) {
      groupedAlerts.putIfAbsent(alert.symbol, () => []).add(alert);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedAlerts.length,
      itemBuilder: (context, index) {
        final symbol = groupedAlerts.keys.elementAt(index);
        final symbolAlerts = groupedAlerts[symbol]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Symbol header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        symbol,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${symbolAlerts.length} ${'alert.title'.tr()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Alerts list
              ...symbolAlerts.asMap().entries.map((entry) {
                final alertIndex = entry.key;
                final alert = entry.value;
                return _buildAlertTile(alert, theme, alertIndex);
              }),
            ],
          ),
        ).animate().fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
        );
      },
    );
  }

  Widget _buildAlertTile(PriceAlertEntry alert, ThemeData theme, int index) {
    final alertType = AlertType.fromValue(alert.alertType);
    final isActive = alert.isActive;
    final wasTriggered = alert.triggeredAt != null;

    return Dismissible(
      key: Key('alert_${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await _confirmDelete(alert);
      },
      onDismissed: (_) {
        ref.read(priceAlertProvider.notifier).deleteAlert(alert.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('alert.deleted'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getAlertColor(alertType).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getAlertIcon(alertType),
            color: _getAlertColor(alertType),
            size: 20,
          ),
        ),
        title: Text(
          _getAlertDescription(alert, alertType),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            decoration: wasTriggered ? TextDecoration.lineThrough : null,
            color: wasTriggered ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.note != null && alert.note!.isNotEmpty)
              Text(
                alert.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    wasTriggered
                        ? 'alert.triggered'.tr()
                        : isActive
                        ? 'alert.active'.tr()
                        : 'alert.inactive'.tr(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: wasTriggered
                          ? Colors.orange
                          : isActive
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),
                if (wasTriggered && alert.triggeredAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatDateTime(alert.triggeredAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Switch(
          value: isActive,
          onChanged: wasTriggered
              ? null
              : (value) {
                  HapticFeedback.lightImpact();
                  ref
                      .read(priceAlertProvider.notifier)
                      .toggleAlert(alert.id, value);
                },
        ),
      ),
    );
  }

  IconData _getAlertIcon(AlertType type) {
    return switch (type) {
      AlertType.above => Icons.trending_up,
      AlertType.below => Icons.trending_down,
      AlertType.changePct => Icons.show_chart,
    };
  }

  Color _getAlertColor(AlertType type) {
    return switch (type) {
      AlertType.above => AppTheme.upColor,
      AlertType.below => AppTheme.downColor,
      AlertType.changePct => AppTheme.primaryColor,
    };
  }

  String _getAlertDescription(PriceAlertEntry alert, AlertType type) {
    return switch (type) {
      AlertType.above => 'alert.priceAbove'.tr(
        namedArgs: {'price': alert.targetValue.toStringAsFixed(2)},
      ),
      AlertType.below => 'alert.priceBelow'.tr(
        namedArgs: {'price': alert.targetValue.toStringAsFixed(2)},
      ),
      AlertType.changePct => 'alert.changeAbove'.tr(
        namedArgs: {'percent': alert.targetValue.toStringAsFixed(1)},
      ),
    };
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmDelete(PriceAlertEntry alert) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('common.delete'.tr()),
        content: Text('alert.deleteConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show dialog to add a new price alert
  Future<void> _showAddAlertDialog(BuildContext context) async {
    final db = ref.read(databaseProvider);

    final symbol = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _StockSymbolInputDialog(db: db),
    );

    if (symbol == null || !mounted) return;

    // Get stock info for the dialog
    final results = await Future.wait([
      db.getStock(symbol),
      db.getLatestPrice(symbol),
    ]);

    if (!context.mounted) return;

    final stock = results[0] as StockMasterEntry?;
    final latestPrice = results[1] as DailyPriceEntry?;

    final created = await showCreatePriceAlertDialog(
      context: context,
      symbol: symbol,
      stockName: stock?.name,
      currentPrice: latestPrice?.close,
    );

    if (created == true) {
      ref.read(priceAlertProvider.notifier).loadAlerts();
    }
  }
}

/// Separate StatefulWidget for stock symbol input dialog
/// This ensures TextEditingController is properly managed with State lifecycle
class _StockSymbolInputDialog extends StatefulWidget {
  const _StockSymbolInputDialog({required this.db});

  final AppDatabase db;

  @override
  State<_StockSymbolInputDialog> createState() => _StockSymbolInputDialogState();
}

class _StockSymbolInputDialogState extends State<_StockSymbolInputDialog> {
  final _controller = TextEditingController();
  bool _isSearching = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final input = _controller.text.trim().toUpperCase();
    if (input.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorText = null;
    });

    final stock = await widget.db.getStock(input);
    if (!mounted) return;

    if (stock != null) {
      Navigator.pop(context, input);
    } else {
      setState(() {
        _isSearching = false;
        _errorText = 'alert.stockNotFound'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('alert.selectStock'.tr()),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'alert.stockSymbol'.tr(),
          hintText: 'alert.stockSymbolHint'.tr(),
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
        enabled: !_isSearching,
        textCapitalization: TextCapitalization.characters,
        onSubmitted: (_) => _search(),
      ),
      actions: [
        TextButton(
          onPressed: _isSearching ? null : () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isSearching ? null : _search,
          child: _isSearching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.next'.tr()),
        ),
      ],
    );
  }
}
