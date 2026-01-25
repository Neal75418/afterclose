import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// Alerts tab - Price alerts for this stock
class AlertsTab extends ConsumerStatefulWidget {
  const AlertsTab({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends ConsumerState<AlertsTab> {
  @override
  void initState() {
    super.initState();
    // Load alerts when tab is initialized
    Future.microtask(() {
      ref.read(priceAlertProvider.notifier).loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockDetailProvider(widget.symbol));
    final alertState = ref.watch(priceAlertProvider);

    // Filter alerts for this stock
    final stockAlerts = alertState.alerts
        .where((alert) => alert.symbol == widget.symbol)
        .toList();

    final currentPrice = stockState.latestPrice?.close;

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current price display
          if (currentPrice != null) ...[
            _buildCurrentPriceCard(context, currentPrice),
            const SizedBox(height: 24),
          ],

          // Alerts list
          SectionHeader(
            title: 'alert.title'.tr(),
            icon: Icons.notifications_active,
          ),
          const SizedBox(height: 12),

          if (alertState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (stockAlerts.isEmpty)
            _buildEmptyState(context)
          else
            ...stockAlerts.map((alert) => _buildAlertCard(context, ref, alert)),

          const SizedBox(height: 16),

          // Add alert button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showAddAlertDialog(context, ref, currentPrice),
              icon: const Icon(Icons.add),
              label: Text('alert.create'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPriceCard(BuildContext context, double price) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.monetization_on,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'stockDetail.currentPrice'.tr(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  Text(
                    'NT\$${price.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'alert.noAlerts'.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'alert.noAlertsHint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    WidgetRef ref,
    PriceAlertEntry alert,
  ) {
    final theme = Theme.of(context);
    final alertType =
        AlertType.tryFromValue(alert.alertType) ?? AlertType.above;

    final description = _getAlertDescription(alert, alertType);

    return Dismissible(
      key: Key('alert_${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('common.delete'.tr()),
            content: Text('alert.deleteConfirm'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: Text('common.delete'.tr()),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref.read(priceAlertProvider.notifier).deleteAlert(alert.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('alert.deleted'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: alert.isActive
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getAlertIcon(alertType),
              color: alert.isActive
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.outline,
            ),
          ),
          title: Text(
            description,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: alert.isActive ? null : theme.colorScheme.outline,
            ),
          ),
          subtitle: alert.note?.isNotEmpty == true
              ? Text(alert.note!, style: theme.textTheme.bodySmall)
              : null,
          trailing: Switch(
            value: alert.isActive,
            onChanged: (value) {
              ref
                  .read(priceAlertProvider.notifier)
                  .toggleAlert(alert.id, value);
            },
          ),
        ),
      ),
    );
  }

  IconData _getAlertIcon(AlertType type) {
    return switch (type) {
      AlertType.above => Icons.trending_up,
      AlertType.below => Icons.trending_down,
      AlertType.changePct => Icons.percent,
      AlertType.volumeSpike || AlertType.volumeAbove => Icons.bar_chart,
      AlertType.rsiOverbought => Icons.arrow_upward,
      AlertType.rsiOversold => Icons.arrow_downward,
      AlertType.kdGoldenCross => Icons.add_circle_outline,
      AlertType.kdDeathCross => Icons.remove_circle_outline,
      AlertType.breakResistance => Icons.north_east,
      AlertType.breakSupport => Icons.south_east,
      AlertType.week52High => Icons.emoji_events,
      AlertType.week52Low => Icons.trending_down,
      AlertType.crossAboveMa || AlertType.crossBelowMa => Icons.timeline,
      AlertType.revenueYoySurge ||
      AlertType.highDividendYield ||
      AlertType.peUndervalued => Icons.analytics,
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
      AlertType.volumeSpike =>
        '成交量爆量（≥${alert.targetValue.toStringAsFixed(0)}倍均量）',
      AlertType.volumeAbove =>
        '成交量高於 ${alert.targetValue.toStringAsFixed(0)} 張',
      AlertType.rsiOverbought =>
        'RSI 超買（≥${alert.targetValue.toStringAsFixed(0)}）',
      AlertType.rsiOversold =>
        'RSI 超賣（≤${alert.targetValue.toStringAsFixed(0)}）',
      AlertType.kdGoldenCross => 'KD 黃金交叉',
      AlertType.kdDeathCross => 'KD 死亡交叉',
      AlertType.breakResistance =>
        '突破壓力 ${alert.targetValue.toStringAsFixed(2)} 元',
      AlertType.breakSupport =>
        '跌破支撐 ${alert.targetValue.toStringAsFixed(2)} 元',
      AlertType.week52High => '創 52 週新高',
      AlertType.week52Low => '創 52 週新低',
      AlertType.crossAboveMa => '站上 ${alert.targetValue.toInt()} 日均線',
      AlertType.crossBelowMa => '跌破 ${alert.targetValue.toInt()} 日均線',
      AlertType.revenueYoySurge =>
        '營收年增 ≥${alert.targetValue.toStringAsFixed(1)}%',
      AlertType.highDividendYield =>
        '殖利率 ≥${alert.targetValue.toStringAsFixed(1)}%',
      AlertType.peUndervalued => 'PE ≤${alert.targetValue.toStringAsFixed(1)}倍',
    };
  }

  void _showAddAlertDialog(
    BuildContext context,
    WidgetRef ref,
    double? currentPrice,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddAlertSheet(
        symbol: widget.symbol,
        currentPrice: currentPrice,
        onCreated: () {
          ref.read(priceAlertProvider.notifier).loadAlerts();
        },
      ),
    );
  }
}

/// Add alert bottom sheet
class _AddAlertSheet extends ConsumerStatefulWidget {
  const _AddAlertSheet({
    required this.symbol,
    required this.currentPrice,
    required this.onCreated,
  });

  final String symbol;
  final double? currentPrice;
  final VoidCallback onCreated;

  @override
  ConsumerState<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends ConsumerState<_AddAlertSheet> {
  AlertType _selectedType = AlertType.above;
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            children: [
              Text(
                'alert.create'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Current price info
          if (widget.currentPrice case final currentPrice?)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'stockDetail.currentPrice'.tr(),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    'NT\$${currentPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Alert type selector
          Text('alert.type'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<AlertType>(
            segments: [
              ButtonSegment(
                value: AlertType.above,
                label: Text('alert.typeAbove'.tr()),
                icon: const Icon(Icons.trending_up, size: 18),
              ),
              ButtonSegment(
                value: AlertType.below,
                label: Text('alert.typeBelow'.tr()),
                icon: const Icon(Icons.trending_down, size: 18),
              ),
              ButtonSegment(
                value: AlertType.changePct,
                label: Text('alert.typeChange'.tr()),
                icon: const Icon(Icons.percent, size: 18),
              ),
            ],
            selected: {_selectedType},
            onSelectionChanged: (selected) {
              setState(() {
                _selectedType = selected.first;
              });
            },
          ),
          const SizedBox(height: 16),

          // Target value input
          Text(
            _selectedType == AlertType.changePct
                ? 'alert.targetPercent'.tr()
                : 'alert.targetPrice'.tr(),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              hintText: _selectedType == AlertType.changePct
                  ? 'alert.percentHint'.tr()
                  : 'alert.priceHint'.tr(),
              suffixText: _selectedType == AlertType.changePct
                  ? '%'
                  : 'alert.currency'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Note input
          Text('alert.note'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'alert.noteHint'.tr(),
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Create button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isCreating ? null : _createAlert,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('alert.create'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createAlert() async {
    final valueText = _valueController.text.trim();
    if (valueText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('alert.invalidValue'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final value = double.tryParse(valueText);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('alert.invalidValue'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final success = await ref
        .read(priceAlertProvider.notifier)
        .createAlert(
          symbol: widget.symbol,
          alertType: _selectedType,
          targetValue: value,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    setState(() => _isCreating = false);

    if (success && mounted) {
      widget.onCreated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('alert.created'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('alert.createFailed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
