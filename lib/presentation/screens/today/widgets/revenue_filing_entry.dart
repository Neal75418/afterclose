import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/api_config.dart';
import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/taiwan_time.dart';
import 'package:afterclose/presentation/providers/revenue_overview_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

/// 今日頁的「月營收公布中」入口(僅每月 1~[ApiConfig.mopsRevenueWindowLastDay]
/// 日顯示)。
///
/// 只是入口不是內容:進度+自選交卷數一行帶過,點擊進
/// [AppRoutes.revenueOverview] 的完整清單頁——清單的完整性在那裡,
/// 這裡刻意不做任何排行/策展(2026-08-05 設計討論:輪動榜會漏股)。
class RevenueFilingEntrySection extends ConsumerStatefulWidget {
  const RevenueFilingEntrySection({super.key});

  @override
  ConsumerState<RevenueFilingEntrySection> createState() =>
      _RevenueFilingEntrySectionState();
}

class _RevenueFilingEntrySectionState
    extends ConsumerState<RevenueFilingEntrySection> {
  @override
  void initState() {
    super.initState();
    if (_inWindow) {
      Future.microtask(() {
        if (mounted) {
          ref.read(revenueOverviewProvider.notifier).loadData();
        }
      });
    }
  }

  bool get _inWindow =>
      TaiwanTime.now().day <= ApiConfig.mopsRevenueWindowLastDay;

  @override
  Widget build(BuildContext context) {
    if (!_inWindow) return const SizedBox.shrink();

    final overview = ref.watch(
      revenueOverviewProvider.select((s) => s.overview),
    );
    if (overview == null) return const SizedBox.shrink();

    final watchlistSymbols = ref.watch(
      watchlistProvider.select((s) => s.items.map((i) => i.symbol).toSet()),
    );
    final theme = Theme.of(context);

    final filed = overview.rows.length;
    final filedSymbols = overview.rows.map((r) => r.symbol).toSet();
    final watchFiled = watchlistSymbols.intersection(filedSymbols).length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing16,
        vertical: DesignTokens.spacing4,
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        child: InkWell(
          onTap: () => context.push(AppRoutes.revenueOverview),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing12,
              vertical: DesignTokens.spacing8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: DesignTokens.spacing8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'revenueOverview.entryTitle'.tr(
                          namedArgs: {'month': '${overview.month}'},
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'revenueOverview.entrySubtitle'.tr(
                          namedArgs: {
                            'filed': '$filed',
                            'watchFiled': '$watchFiled',
                            'watchTotal': '${watchlistSymbols.length}',
                          },
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
