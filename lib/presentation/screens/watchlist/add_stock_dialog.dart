import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/presentation/providers/watchlist_provider.dart';

/// 顯示新增自選股對話框
///
/// 接受股票代號輸入，驗證後加入自選清單，並顯示結果 SnackBar。
void showAddStockDialog({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final controller = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);
  final parentContext = context;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      var isLoading = false;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('watchlist.addDialog'.tr()),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'watchlist.symbolLabel'.tr(),
                hintText: 'watchlist.symbolHint'.tr(),
              ),
              autofocus: true,
              enabled: !isLoading,
              textCapitalization: TextCapitalization.characters,
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final symbol = controller.text.trim().toUpperCase();
                        if (symbol.isEmpty) return;

                        setDialogState(() => isLoading = true);

                        final notifier = ref.read(watchlistProvider.notifier);
                        final success = await notifier.addStock(symbol);

                        // Check if dialog is still mounted
                        if (!dialogContext.mounted) return;

                        Navigator.pop(dialogContext);

                        if (parentContext.mounted) {
                          // 清除現有的 SnackBar，避免堆積
                          messenger.clearSnackBars();
                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'watchlist.added'.tr(
                                    namedArgs: {'symbol': symbol},
                                  ),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'watchlist.notFound'.tr(
                                    namedArgs: {'symbol': symbol},
                                  ),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Theme.of(
                                  parentContext,
                                ).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('common.add'.tr()),
              ),
            ],
          );
        },
      );
    },
  ).then((_) => controller.dispose());
}
