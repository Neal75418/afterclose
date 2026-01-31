import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/screening_condition.dart';

/// 單一篩選條件卡片
class ConditionCard extends StatelessWidget {
  const ConditionCard({
    super.key,
    required this.condition,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final ScreeningCondition condition;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('condition_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Icon(
            _categoryIcon(condition.field.category),
            color: theme.colorScheme.primary,
          ),
          title: Text(
            _buildConditionText(condition),
            style: theme.textTheme.bodyMedium,
          ),
          subtitle: Text(
            'customScreening.category.${condition.field.category.name}'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDelete,
          ),
          onTap: onEdit,
        ),
      ),
    );
  }

  String _buildConditionText(ScreeningCondition c) {
    final fieldName = 'customScreening.field.${c.field.name}'.tr();
    final opName = _operatorSymbol(c.operator);

    switch (c.operator) {
      case ScreeningOperator.between:
        return '$fieldName $opName ${_formatNum(c.value)} ~ ${_formatNum(c.valueTo)}';
      case ScreeningOperator.isTrue:
        return fieldName;
      case ScreeningOperator.isFalse:
        return '${'customScreening.operator.isFalse'.tr()} $fieldName';
      case ScreeningOperator.equals:
        if (c.field == ScreeningField.hasSignal && c.stringValue != null) {
          final label = ReasonType.values
              .where((r) => r.code == c.stringValue)
              .firstOrNull
              ?.label;
          return '$fieldName = ${label ?? c.stringValue}';
        }
        return '$fieldName = ${_formatNum(c.value)}';
      default:
        return '$fieldName $opName ${_formatNum(c.value)}';
    }
  }

  String _operatorSymbol(ScreeningOperator op) => switch (op) {
    ScreeningOperator.greaterThan => '>',
    ScreeningOperator.greaterOrEqual => '>=',
    ScreeningOperator.lessThan => '<',
    ScreeningOperator.lessOrEqual => '<=',
    ScreeningOperator.between => 'customScreening.operator.between'.tr(),
    ScreeningOperator.equals => '=',
    ScreeningOperator.isTrue => '',
    ScreeningOperator.isFalse => '',
  };

  String _formatNum(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }

  IconData _categoryIcon(ScreeningCategory category) => switch (category) {
    ScreeningCategory.price => Icons.trending_up,
    ScreeningCategory.volume => Icons.bar_chart,
    ScreeningCategory.technical => Icons.show_chart,
    ScreeningCategory.fundamental => Icons.account_balance,
    ScreeningCategory.signal => Icons.notifications_active,
  };
}
