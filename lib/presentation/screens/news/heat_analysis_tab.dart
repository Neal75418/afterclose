import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/constants/scoring_mode.dart';
import 'package:afterclose/domain/services/news/heat_calculator.dart';
import 'package:afterclose/presentation/providers/news_heat_provider.dart';

/// 新聞頁「熱度分析」分頁：主流族群 + 焦點股（三模式交叉）
class HeatAnalysisTab extends ConsumerStatefulWidget {
  const HeatAnalysisTab({super.key});

  @override
  ConsumerState<HeatAnalysisTab> createState() => _HeatAnalysisTabState();
}

class _HeatAnalysisTabState extends ConsumerState<HeatAnalysisTab> {
  bool _pullbackOnly = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(newsHeatProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (data) {
        if (data.themes.isEmpty && data.stocks.isEmpty) {
          return Center(child: Text('news.heatEmpty'.tr()));
        }
        final stocks = _pullbackOnly
            ? data.stocks
                  .where(
                    (s) =>
                        data.modeBySymbol[s.symbol] ==
                        ScoringMode.weaknessObserve,
                  )
                  .toList()
            : data.stocks;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(newsHeatProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'news.hotThemes'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final t in data.themes)
                _ThemeCard(theme: t, stockNames: data.stockNames),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'news.focusStocks'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  FilterChip(
                    label: Text('news.pullbackOnly'.tr()),
                    selected: _pullbackOnly,
                    onSelected: (v) => setState(() => _pullbackOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final s in stocks)
                _FocusStockTile(
                  heat: s,
                  name: data.stockNames[s.symbol],
                  mode: data.modeBySymbol[s.symbol],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme, required this.stockNames});

  final ThemeHeat theme;
  final Map<String, String> stockNames;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  theme.theme,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                if (theme.isSurging) const _SurgeBadge(),
                const Spacer(),
                Text('news.articlesCount'.tr(args: ['${theme.articles7d}'])),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'news.prevWeekCount'.tr(args: ['${theme.articlesPrev21d}']),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final sym in theme.topStocks)
                  ActionChip(
                    label: Text(stockNames[sym] ?? sym),
                    onPressed: () => _openStockDetail(context, sym),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusStockTile extends StatelessWidget {
  const _FocusStockTile({required this.heat, this.name, this.mode});

  final StockHeat heat;
  final String? name;
  final ScoringMode? mode;

  @override
  Widget build(BuildContext context) {
    final isPullback = mode == ScoringMode.weaknessObserve;
    return Card(
      color: isPullback
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .3)
          : null,
      child: ListTile(
        title: Row(
          children: [
            Text(name ?? heat.symbol),
            const SizedBox(width: 6),
            Text(heat.symbol, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            if (heat.isSurging) const _SurgeBadge(),
            if (mode != null) ...[
              const SizedBox(width: 6),
              _ModeBadge(mode: mode!),
            ],
          ],
        ),
        subtitle: Text(
          '${'news.articlesCount'.tr(args: ['${heat.mentions7d}'])} · '
          '${'news.prevWeekCount'.tr(args: ['${heat.mentionsPrev21d}'])}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openStockDetail(context, heat.symbol),
      ),
    );
  }
}

class _SurgeBadge extends StatelessWidget {
  const _SurgeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'news.surgeBadge'.tr(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final ScoringMode mode;

  @override
  Widget build(BuildContext context) {
    // ScoringMode.displayKey 是既有 i18n key（scoringMode.*，Today screen 同源），
    // 照用避免另立一套字串（見 lib/core/constants/scoring_mode.dart）。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        mode.displayKey.tr(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

void _openStockDetail(BuildContext context, String symbol) {
  // 照 news_screen.dart 既有慣例（AppRoutes.stockDetail + context.push）。
  context.push(AppRoutes.stockDetail(symbol));
}
