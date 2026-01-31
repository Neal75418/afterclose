import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 分享選項 BottomSheet
///
/// 顯示可用的匯出格式（PNG / CSV），回傳使用者選擇的格式。
enum ShareFormat { png, csv }

class ShareOptionsSheet extends StatelessWidget {
  const ShareOptionsSheet({
    super.key,
    this.showPng = true,
    this.showCsv = true,
  });

  final bool showPng;
  final bool showCsv;

  static Future<ShareFormat?> show(
    BuildContext context, {
    bool showPng = true,
    bool showCsv = true,
  }) {
    return showModalBottomSheet<ShareFormat>(
      context: context,
      builder: (context) =>
          ShareOptionsSheet(showPng: showPng, showCsv: showCsv),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'export.title'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (showPng)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text('export.formatPng'.tr()),
                subtitle: Text('export.shareAnalysis'.tr()),
                onTap: () => Navigator.of(context).pop(ShareFormat.png),
              ),
            if (showCsv)
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: Text('export.formatCsv'.tr()),
                subtitle: Text('export.exportCsv'.tr()),
                onTap: () => Navigator.of(context).pop(ShareFormat.csv),
              ),
          ],
        ),
      ),
    );
  }
}
