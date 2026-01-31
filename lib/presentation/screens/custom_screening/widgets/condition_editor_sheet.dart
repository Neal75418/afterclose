import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/constants/rule_params.dart';
import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/widgets/reason_tags.dart';

/// 新增/編輯篩選條件的 Bottom Sheet
///
/// 三步驟流程：選分類 → 選欄位 → 設定運算子與數值
class ConditionEditorSheet extends StatefulWidget {
  const ConditionEditorSheet({super.key, this.initial});

  /// 編輯模式時傳入現有條件
  final ScreeningCondition? initial;

  /// 顯示底部表單，回傳建立/修改的條件
  static Future<ScreeningCondition?> show(
    BuildContext context, {
    ScreeningCondition? initial,
  }) {
    return showModalBottomSheet<ScreeningCondition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ConditionEditorSheet(initial: initial),
    );
  }

  @override
  State<ConditionEditorSheet> createState() => _ConditionEditorSheetState();
}

class _ConditionEditorSheetState extends State<ConditionEditorSheet> {
  ScreeningCategory? _selectedCategory;
  ScreeningField? _selectedField;
  ScreeningOperator? _selectedOperator;
  final _valueController = TextEditingController();
  final _valueToController = TextEditingController();
  String? _selectedSignalCode;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final c = widget.initial!;
      _selectedCategory = c.field.category;
      _selectedField = c.field;
      _selectedOperator = c.operator;
      if (c.value != null) {
        _valueController.text = _formatNum(c.value!);
      }
      if (c.valueTo != null) {
        _valueToController.text = _formatNum(c.valueTo!);
      }
      _selectedSignalCode = c.stringValue;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _valueToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖動指示條
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 標題
              Text(
                widget.initial != null
                    ? 'customScreening.editCondition'.tr()
                    : 'customScreening.addCondition'.tr(),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Step 1: 選擇分類
              Text(
                'customScreening.stepCategory'.tr(),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ScreeningCategory.values.map((cat) {
                  final selected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text('customScreening.category.${cat.name}'.tr()),
                    selected: selected,
                    onSelected: (_) => _selectCategory(cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Step 2: 選擇欄位
              if (_selectedCategory != null) ...[
                Text(
                  'customScreening.stepField'.tr(),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _fieldsForCategory(_selectedCategory!).map((field) {
                    final selected = _selectedField == field;
                    return ChoiceChip(
                      label: Text('customScreening.field.${field.name}'.tr()),
                      selected: selected,
                      onSelected: (_) => _selectField(field),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Step 3: 設定運算子與數值
              if (_selectedField != null) ...[
                Text(
                  'customScreening.stepValue'.tr(),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                _buildValueEditor(theme),
                const SizedBox(height: 24),

                // 確認按鈕
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canConfirm() ? _confirm : null,
                    child: Text(
                      widget.initial != null
                          ? 'customScreening.updateCondition'.tr()
                          : 'customScreening.addCondition'.tr(),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueEditor(ThemeData theme) {
    final fieldType = _selectedField!.fieldType;

    // Boolean 型：只需選 isTrue/isFalse
    if (fieldType == ScreeningFieldType.boolean) {
      return Row(
        children: [
          ChoiceChip(
            label: Text('customScreening.operator.isTrue'.tr()),
            selected: _selectedOperator == ScreeningOperator.isTrue,
            onSelected: (_) {
              setState(() => _selectedOperator = ScreeningOperator.isTrue);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('customScreening.operator.isFalse'.tr()),
            selected: _selectedOperator == ScreeningOperator.isFalse,
            onSelected: (_) {
              setState(() => _selectedOperator = ScreeningOperator.isFalse);
            },
          ),
        ],
      );
    }

    // Signal 型：選擇訊號代碼
    // _selectedOperator 已在 _selectField() 中設為 equals
    if (fieldType == ScreeningFieldType.signal) {
      return _buildSignalSelector(theme);
    }

    // Numeric 型：選運算子 + 填值
    final availableOps = ScreeningOperator.availableFor(fieldType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 運算子選擇
        Wrap(
          spacing: 8,
          children: availableOps.map((op) {
            return ChoiceChip(
              label: Text('customScreening.operator.${op.name}'.tr()),
              selected: _selectedOperator == op,
              onSelected: (_) {
                setState(() => _selectedOperator = op);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // 數值輸入
        if (_selectedOperator != null)
          _selectedOperator == ScreeningOperator.between
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _valueController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'customScreening.minValue'.tr(),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~', style: theme.textTheme.titleMedium),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _valueToController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'customScreening.maxValue'.tr(),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                )
              : TextField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'customScreening.value'.tr(),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
      ],
    );
  }

  Widget _buildSignalSelector(ThemeData theme) {
    // 只顯示主要訊號類型
    final signalCodes = ReasonType.values
        .where((r) => r.code != 'UNKNOWN')
        .toList();

    return SizedBox(
      height: 200,
      child: ListView.builder(
        itemCount: signalCodes.length,
        itemBuilder: (context, index) {
          final reason = signalCodes[index];
          final selected = _selectedSignalCode == reason.code;
          return ListTile(
            dense: true,
            title: Text(ReasonTags.translateReasonCode(reason.code)),
            trailing: selected
                ? Icon(Icons.check, color: theme.colorScheme.primary)
                : null,
            selected: selected,
            onTap: () {
              setState(() => _selectedSignalCode = reason.code);
            },
          );
        },
      ),
    );
  }

  List<ScreeningField> _fieldsForCategory(ScreeningCategory category) {
    return ScreeningField.values.where((f) => f.category == category).toList();
  }

  void _selectCategory(ScreeningCategory category) {
    setState(() {
      _selectedCategory = category;
      _selectedField = null;
      _selectedOperator = null;
      _valueController.clear();
      _valueToController.clear();
      _selectedSignalCode = null;
    });
  }

  void _selectField(ScreeningField field) {
    setState(() {
      _selectedField = field;
      _selectedOperator = ScreeningOperator.defaultFor(field.fieldType);
      _valueController.clear();
      _valueToController.clear();
      _selectedSignalCode = null;
    });
  }

  bool _canConfirm() {
    if (_selectedField == null || _selectedOperator == null) return false;

    final fieldType = _selectedField!.fieldType;

    if (fieldType == ScreeningFieldType.boolean) return true;
    if (fieldType == ScreeningFieldType.signal) {
      return _selectedSignalCode != null;
    }

    // numeric
    if (_selectedOperator == ScreeningOperator.between) {
      return _valueController.text.isNotEmpty &&
          _valueToController.text.isNotEmpty;
    }
    return _valueController.text.isNotEmpty;
  }

  void _confirm() {
    final condition = ScreeningCondition(
      field: _selectedField!,
      operator: _selectedOperator!,
      value: double.tryParse(_valueController.text),
      valueTo: double.tryParse(_valueToController.text),
      stringValue: _selectedSignalCode,
    );
    Navigator.of(context).pop(condition);
  }

  String _formatNum(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }
}
