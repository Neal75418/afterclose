import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/utils/logger.dart';
import 'package:afterclose/presentation/providers/providers.dart';
import 'package:afterclose/presentation/providers/scan_provider.dart';

/// 產業概覽狀態
class _IndustryOverviewState {
  const _IndustryOverviewState({
    this.industries = const [],
    this.isLoading = true,
    this.error,
  });

  final List<_IndustryItem> industries;
  final bool isLoading;
  final String? error;
}

class _IndustryItem {
  const _IndustryItem({required this.name, required this.stockCount});

  final String name;
  final int stockCount;
}

/// 產業概覽頁 — 展示各產業分類與股票數量
class IndustryOverviewScreen extends ConsumerStatefulWidget {
  const IndustryOverviewScreen({super.key});

  @override
  ConsumerState<IndustryOverviewScreen> createState() =>
      _IndustryOverviewScreenState();
}

class _IndustryOverviewScreenState
    extends ConsumerState<IndustryOverviewScreen> {
  _IndustryOverviewState _state = const _IndustryOverviewState();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = ref.read(databaseProvider);
      final counts = await db.getIndustryStockCounts();

      final items =
          counts.entries
              .map((e) => _IndustryItem(name: e.key, stockCount: e.value))
              .toList()
            ..sort((a, b) => b.stockCount.compareTo(a.stockCount));

      if (mounted) {
        setState(() {
          _state = _IndustryOverviewState(industries: items, isLoading: false);
        });
      }
    } catch (e) {
      AppLogger.error('IndustryOverview', '載入產業資料失敗', e);
      if (mounted) {
        setState(() {
          _state = _IndustryOverviewState(
            isLoading: false,
            error: e.toString(),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('scan.selectIndustry'.tr())),
      body: _state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _state.error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _state.error!,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() {
                        _state = const _IndustryOverviewState();
                      });
                      _loadData();
                    },
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              itemCount: _state.industries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _state.industries[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.factory_outlined,
                      color: theme.colorScheme.onTertiaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(item.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'scan.industryStockCount'.tr(
                          namedArgs: {'count': item.stockCount.toString()},
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () {
                    ref
                        .read(scanProvider.notifier)
                        .setIndustryFilter(item.name);
                    context.pop();
                  },
                );
              },
            ),
    );
  }
}
