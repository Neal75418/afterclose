import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通用單選 dialog，取代重複的 radio button 選擇模式
class RadioSelectionDialog<T> extends StatelessWidget {
  const RadioSelectionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.currentValue,
    required this.onSelected,
    this.labelBuilder,
    this.trailingBuilder,
  });

  final String title;
  final List<T> options;
  final T currentValue;
  final ValueChanged<T> onSelected;
  final String Function(T)? labelBuilder;
  final Widget Function(T)? trailingBuilder;

  /// 顯示 RadioSelectionDialog 的便利方法
  static void show<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required T currentValue,
    required ValueChanged<T> onSelected,
    String Function(T)? labelBuilder,
    Widget Function(T)? trailingBuilder,
  }) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (_) => RadioSelectionDialog<T>(
        title: title,
        options: options,
        currentValue: currentValue,
        onSelected: onSelected,
        labelBuilder: labelBuilder,
        trailingBuilder: trailingBuilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = option == currentValue;
          return ListTile(
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
            title: Text(labelBuilder?.call(option) ?? option.toString()),
            trailing: trailingBuilder?.call(option),
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(option);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
