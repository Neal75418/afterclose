import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/quarterly_filing_calendar.dart';
import 'package:afterclose/core/utils/taiwan_time.dart';
import 'package:afterclose/presentation/providers/quarterly_report_overview_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

/// 今日頁的「季報公布中」入口(僅申報窗口內顯示,窗口見
/// [QuarterlyFilingCalendar])。
///
/// 結構完全鏡射 [RevenueFilingEntrySection]:只是入口不是內容——
/// 進度+自選交卷數一行帶過,點擊進 [AppRoutes.quarterlyOverview] 的
/// 完整清單頁。跨日補載用同一套 day-idempotent 機制(TodayScreen 被
/// indexedStack 保活,State 永不重建,initState 一次性載入會讓入口
/// 跨月/跨窗口隱形——2026-08-05 營收入口複審 Medium #5 的同一課)。
class QuarterlyFilingEntrySection extends ConsumerStatefulWidget {
  const QuarterlyFilingEntrySection({super.key});

  @override
  ConsumerState<QuarterlyFilingEntrySection> createState() =>
      _QuarterlyFilingEntrySectionState();
}

class _QuarterlyFilingEntrySectionState
    extends ConsumerState<QuarterlyFilingEntrySection> {
  String? _loadedDayKey;

  void _ensureLoadedToday() {
    final now = TaiwanTime.now();
    final key = '${now.year}-${now.month}-${now.day}';
    if (_loadedDayKey == key) return;
    _loadedDayKey = key;
    Future.microtask(() {
      if (mounted) {
        ref.read(quarterlyReportOverviewProvider.notifier).loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final expected = QuarterlyFilingCalendar.expectedFilingQuarter(
      TaiwanTime.now(),
    );
    if (expected == null) return const SizedBox.shrink();
    _ensureLoadedToday();

    final overview = ref.watch(
      quarterlyReportOverviewProvider.select((s) => s.overview),
    );
    if (overview == null) return const SizedBox.shrink();

    // 季 gate:窗口內但 DB 最新季還是上一季(窗口首日同步前的常態)時,
    // 不顯示「Q2 公布中」這種矛盾入口——等第一批新季資料落庫再現身。
    if (overview.year != expected.year ||
        overview.quarter != expected.quarter) {
      return const SizedBox.shrink();
    }

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
          onTap: () => context.push(AppRoutes.quarterlyOverview),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing12,
              vertical: DesignTokens.spacing8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.request_quote_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: DesignTokens.spacing8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'quarterlyOverview.entryTitle'.tr(
                          namedArgs: {'quarter': '${overview.quarter}'},
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'quarterlyOverview.entrySubtitle'.tr(
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
