import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/comparison_header.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/comparison_table.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/price_overlay_chart.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/radar_comparison_chart.dart';
import 'package:afterclose/presentation/screens/comparison/widgets/stock_picker_sheet.dart';
import 'package:afterclose/presentation/widgets/share_options_sheet.dart';
import 'package:afterclose/presentation/widgets/shareable/shareable_comparison_card.dart';
import 'package:afterclose/core/utils/widget_capture.dart';
import 'package:afterclose/core/services/share_service.dart';
import 'package:afterclose/domain/services/export_service.dart';

/// Main comparison screen that shows side-by-side stock analysis.
class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({super.key, this.initialSymbols = const []});

  final List<String> initialSymbols;

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(comparisonProvider.notifier).addStocks(widget.initialSymbols);
    });
  }

  Future<void> _showStockPicker() async {
    final state = ref.read(comparisonProvider);
    if (!state.canAddMore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('comparison.maxStocksReached'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final symbol = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StockPickerSheet(existingSymbols: state.symbols),
    );

    if (symbol != null && mounted) {
      ref.read(comparisonProvider.notifier).addStock(symbol);
    }
  }

  Future<void> _showShareOptions(ComparisonState state) async {
    final format = await ShareOptionsSheet.show(context);
    if (format == null || !mounted) return;

    const shareService = ShareService();
    const exportService = ExportService();

    try {
      if (format == ShareFormat.png) {
        final imageBytes = await _captureComparisonCard(state);
        if (imageBytes != null) {
          await shareService.shareImage(imageBytes, 'comparison.png');
        }
      } else {
        final csv = exportService.comparisonToCsv(state);
        await shareService.shareCsv(csv, 'comparison.csv');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'export.shareFailed'.tr(namedArgs: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  Future<Uint8List?> _captureComparisonCard(ComparisonState state) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -1000,
        top: -1000,
        child: RepaintBoundary(
          key: key,
          child: Material(child: ShareableComparisonCard(state: state)),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      return await const WidgetCapture().captureFromKey(key);
    } finally {
      entry.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(comparisonProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('comparison.title'.tr()),
        actions: [
          if (state.hasEnoughToCompare)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _showShareOptions(state),
              tooltip: 'export.title'.tr(),
            ),
          if (state.canAddMore)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showStockPicker,
              tooltip: 'comparison.addStock'.tr(),
            ),
        ],
      ),
      body: state.isLoading && state.symbols.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stock chips bar
                if (state.symbols.isNotEmpty)
                  ComparisonHeader(
                    symbols: state.symbols,
                    stocksMap: state.stocksMap,
                    canAddMore: state.canAddMore,
                    onRemove: (s) =>
                        ref.read(comparisonProvider.notifier).removeStock(s),
                    onAdd: _showStockPicker,
                  ),

                const SizedBox(height: 4),

                // Main content
                Expanded(
                  child: state.hasEnoughToCompare
                      ? _buildComparisonContent(state, theme)
                      : _buildEmptyState(state, theme),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ComparisonState state, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.compare_arrows,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'comparison.needMoreStocks'.tr(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'comparison.addStockHint'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showStockPicker,
            icon: const Icon(Icons.add),
            label: Text('comparison.addStock'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonContent(ComparisonState state, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loading overlay
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),

          // Price overlay chart
          PriceOverlayChart(
            symbols: state.symbols,
            priceHistoriesMap: state.priceHistoriesMap,
            stocksMap: state.stocksMap,
          ),

          const SizedBox(height: 16),

          // Radar chart
          RadarComparisonChart(state: state),

          const SizedBox(height: 16),

          // Comparison table
          ComparisonTable(state: state),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
