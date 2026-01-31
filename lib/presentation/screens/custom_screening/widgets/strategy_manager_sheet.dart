import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/domain/models/screening_condition.dart';
import 'package:afterclose/presentation/providers/custom_screening_provider.dart';

/// 策略儲存/載入 Bottom Sheet
class StrategyManagerSheet extends ConsumerStatefulWidget {
  const StrategyManagerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const StrategyManagerSheet(),
    );
  }

  @override
  ConsumerState<StrategyManagerSheet> createState() =>
      _StrategyManagerSheetState();
}

class _StrategyManagerSheetState extends ConsumerState<StrategyManagerSheet> {
  final _nameController = TextEditingController();
  bool _showSaveForm = false;

  @override
  void initState() {
    super.initState();
    // 載入已儲存策略
    Future.microtask(() {
      ref.read(customScreeningProvider.notifier).loadSavedStrategies();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(customScreeningProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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

              Text(
                'customScreening.savedStrategies'.tr(),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              // 已儲存策略列表
              if (state.isLoadingStrategies)
                const Center(child: CircularProgressIndicator())
              else if (state.savedStrategies.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'customScreening.noSavedStrategies'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                ...state.savedStrategies.map((strategy) {
                  return ListTile(
                    title: Text(strategy.name),
                    subtitle: Text(
                      'customScreening.conditions'.tr(
                        namedArgs: {
                          'count': strategy.conditions.length.toString(),
                        },
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(context, strategy),
                    ),
                    onTap: () {
                      ref
                          .read(customScreeningProvider.notifier)
                          .loadStrategy(strategy);
                      Navigator.of(context).pop();
                    },
                  );
                }),

              const Divider(),

              // 儲存目前條件
              if (state.conditions.isNotEmpty) ...[
                if (!_showSaveForm)
                  TextButton.icon(
                    onPressed: () => setState(() => _showSaveForm = true),
                    icon: const Icon(Icons.save),
                    label: Text('customScreening.saveCurrentStrategy'.tr()),
                  )
                else ...[
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'customScreening.strategyName'.tr(),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showSaveForm = false),
                        child: Text('customScreening.cancel'.tr()),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _nameController.text.trim().isEmpty
                            ? null
                            : _save,
                        child: Text('customScreening.save'.tr()),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final success = await ref
        .read(customScreeningProvider.notifier)
        .saveStrategy(name);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('customScreening.saveFailed'.tr())),
      );
    }
  }

  void _confirmDelete(BuildContext context, ScreeningStrategy strategy) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('customScreening.deleteStrategy'.tr()),
        content: Text(
          'customScreening.confirmDelete'.tr(
            namedArgs: {'name': strategy.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('customScreening.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              if (strategy.id != null) {
                final success = await ref
                    .read(customScreeningProvider.notifier)
                    .deleteStrategy(strategy.id!);
                if (mounted && !success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('customScreening.deleteFailed'.tr()),
                    ),
                  );
                }
              }
            },
            child: Text('customScreening.delete'.tr()),
          ),
        ],
      ),
    );
  }
}
