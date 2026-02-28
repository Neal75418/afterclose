import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/presentation/providers/notification_provider.dart';
import 'package:afterclose/presentation/providers/price_alert_provider.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

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
    // 若有當前價格則預填
    if (widget.currentPrice case final price?) {
      _valueController.text = price.toStringAsFixed(2);
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
            // 股票資訊
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
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

            // 警示類型選擇
            Text(
              'alert.type'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AlertType>(
              segments: AlertType.values
                  .where(
                    (type) => type.isImplemented,
                  ) // Only show implemented types
                  .map((type) {
                    return ButtonSegment<AlertType>(
                      value: type,
                      label: Text(
                        _getTypeLabel(type),
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  })
                  .toList(),
              selected: {_selectedType},
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedType = selected.first;
                });
              },
            ),

            const SizedBox(height: 16),

            // 目標值輸入
            TextField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: _getValueLabel(),
                hintText: _getValueHint(),
                suffixText: _selectedType == AlertType.changePct
                    ? '%'
                    : 'alert.currency'.tr(),
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),

            const SizedBox(height: 16),

            // 備註輸入（選填）
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'alert.note'.tr(),
                hintText: 'alert.noteHint'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            // 當前價格提示
            if (widget.currentPrice case final price?) ...[
              const SizedBox(height: 12),
              Text(
                'alert.currentPrice'.tr(args: [price.toStringAsFixed(2)]),
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
    return type.label;
  }

  String _getValueLabel() {
    if (!_selectedType.requiresTargetValue) {
      return ''; // No value needed
    }
    return switch (_selectedType) {
      AlertType.above || AlertType.below => 'alert.targetPrice'.tr(),
      AlertType.changePct => 'alert.targetPercent'.tr(),
      AlertType.breakResistance ||
      AlertType.breakSupport => 'alert.targetPrice'.tr(),
      AlertType.volumeAbove => 'alert.targetVolume'.tr(),
      AlertType.rsiOverbought ||
      AlertType.rsiOversold => 'alert.rsiThreshold'.tr(),
      AlertType.crossAboveMa || AlertType.crossBelowMa => 'alert.maDays'.tr(),
      _ => '',
    };
  }

  String _getValueHint() {
    if (!_selectedType.requiresTargetValue) {
      return ''; // No value needed
    }
    return switch (_selectedType) {
      AlertType.above || AlertType.below => 'alert.priceHint'.tr(),
      AlertType.changePct => 'alert.percentHint'.tr(),
      AlertType.breakResistance ||
      AlertType.breakSupport => 'alert.priceHint'.tr(),
      AlertType.volumeAbove => 'alert.volumeHint'.tr(),
      AlertType.rsiOverbought => 'alert.rsiOverboughtHint'.tr(),
      AlertType.rsiOversold => 'alert.rsiOversoldHint'.tr(),
      AlertType.crossAboveMa || AlertType.crossBelowMa => 'alert.maHint'.tr(),
      _ => '',
    };
  }

  Future<void> _createAlert() async {
    final valueText = _valueController.text.trim();
    if (_selectedType.requiresTargetValue && valueText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('alert.emptyValue'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final value = double.tryParse(valueText);
    if (_selectedType.requiresTargetValue && (value == null || value <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('alert.mustBePositive'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    // 建立提醒前確保已取得通知權限
    final hasPermission = await ref
        .read(notificationProvider.notifier)
        .ensurePermission();

    if (!hasPermission && mounted) {
      // 權限被拒絕，顯示提示但仍允許建立提醒（只是不會收到通知）
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('alert.permissionDenied'.tr()),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    final success = await ref
        .read(priceAlertProvider.notifier)
        .createAlert(
          symbol: widget.symbol,
          alertType: _selectedType,
          targetValue: value ?? 0,
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
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('alert.createFailed'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
