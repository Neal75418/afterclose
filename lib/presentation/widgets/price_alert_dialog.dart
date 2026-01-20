import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';

/// Shows a dialog to create a new price alert
Future<bool?> showCreatePriceAlertDialog({
  required BuildContext context,
  required String symbol,
  String? stockName,
  double? currentPrice,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => CreatePriceAlertDialog(
      symbol: symbol,
      stockName: stockName,
      currentPrice: currentPrice,
    ),
  );
}

/// Dialog for creating a price alert
class CreatePriceAlertDialog extends ConsumerStatefulWidget {
  const CreatePriceAlertDialog({
    super.key,
    required this.symbol,
    this.stockName,
    this.currentPrice,
  });

  final String symbol;
  final String? stockName;
  final double? currentPrice;

  @override
  ConsumerState<CreatePriceAlertDialog> createState() =>
      _CreatePriceAlertDialogState();
}

class _CreatePriceAlertDialogState
    extends ConsumerState<CreatePriceAlertDialog> {
  AlertType _selectedType = AlertType.above;
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current price if available
    if (widget.currentPrice != null) {
      _valueController.text = widget.currentPrice!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('alert.create'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stock info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    widget.symbol,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.stockName != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.stockName!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Alert type selector
            Text(
              'alert.type'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AlertType>(
              segments: AlertType.values.map((type) {
                return ButtonSegment<AlertType>(
                  value: type,
                  label: Text(
                    _getTypeLabel(type),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              selected: {_selectedType},
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedType = selected.first;
                });
              },
            ),

            const SizedBox(height: 16),

            // Target value input
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: _getValueLabel(),
                hintText: _getValueHint(),
                suffixText: _selectedType == AlertType.changePct ? '%' : 'alert.currency'.tr(),
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
            ),

            const SizedBox(height: 16),

            // Note input (optional)
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'alert.note'.tr(),
                hintText: 'alert.noteHint'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            // Current price hint
            if (widget.currentPrice != null) ...[
              const SizedBox(height: 12),
              Text(
                'alert.currentPrice'.tr(args: [widget.currentPrice!.toStringAsFixed(2)]),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createAlert,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('alert.create'.tr()),
        ),
      ],
    );
  }

  String _getTypeLabel(AlertType type) {
    return switch (type) {
      AlertType.above => 'alert.typeAbove'.tr(),
      AlertType.below => 'alert.typeBelow'.tr(),
      AlertType.changePct => 'alert.typeChange'.tr(),
    };
  }

  String _getValueLabel() {
    return switch (_selectedType) {
      AlertType.above => 'alert.targetPrice'.tr(),
      AlertType.below => 'alert.targetPrice'.tr(),
      AlertType.changePct => 'alert.targetPercent'.tr(),
    };
  }

  String _getValueHint() {
    return switch (_selectedType) {
      AlertType.above => 'alert.priceHint'.tr(),
      AlertType.below => 'alert.priceHint'.tr(),
      AlertType.changePct => 'alert.percentHint'.tr(),
    };
  }

  Future<void> _createAlert() async {
    final value = double.tryParse(_valueController.text);
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

    final success = await ref.read(priceAlertProvider.notifier).createAlert(
          symbol: widget.symbol,
          alertType: _selectedType,
          targetValue: value,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );

    if (mounted) {
      setState(() => _isCreating = false);

      if (success) {
        HapticFeedback.lightImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('alert.created'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.upColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('alert.createFailed'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
