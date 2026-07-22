import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/number_formatter.dart';
import 'package:afterclose/domain/models/industry_ranking.dart';
import 'package:afterclose/presentation/providers/industry_ranking_provider.dart';
import 'package:afterclose/presentation/providers/stock_browsing_context_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/chip/chip_helpers.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// 今日頁族群排行 section（使用者選股法則 L1：族群決定 80%）
///
/// 橫向卡片列出動能前段產業：選定視窗（20日輪動／5日轉折）動能中位數、
/// 外資+投信近 3 日方向、成員數。點卡片開 bottom sheet 看領漲成員、
/// 可再點進個股詳情。
class IndustryRankingSection extends ConsumerStatefulWidget {
  const IndustryRankingSection({super.key});

  @override
  ConsumerState<IndustryRankingSection> createState() =>
      _IndustryRankingSectionState();
}

class _IndustryRankingSectionState
    extends ConsumerState<IndustryRankingSection> {
  RankingWindow _window = RankingWindow.d20;

  String _windowLabel(RankingWindow w) => switch (w) {
    RankingWindow.d20 => 'today.industryWindow20d'.tr(),
    RankingWindow.d5 => 'today.industryWindow5d'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final asyncRankings = ref.watch(industryRankingProvider(_window));
    return asyncRankings.when(
      // 輔助發現層：loading / error / 空資料（fresh DB、歷史回補中）都整段
      // 收起，不佔版面、不擋今日頁主線（推薦清單）。資料層錯誤已由上方
      // MarketDashboard / 更新錯誤橫幅承接，這裡不重複報錯。
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (rankings) {
        if (rankings.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'today.industryRanking'.tr(),
              icon: Icons.workspaces_outline,
              // 20日＝輪動主視角、5日＝轉折視角（20日弱但正在翻強的族群
              // 只有 5日排序才進得了前八——2026-07-22 實機回饋）
              trailing: SegmentedButton<RankingWindow>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                showSelectedIcon: false,
                segments: [
                  for (final w in RankingWindow.values)
                    ButtonSegment(value: w, label: Text(_windowLabel(w))),
                ],
                selected: {_window},
                onSelectionChanged: (set) {
                  HapticFeedback.selectionClick();
                  setState(() => _window = set.first);
                },
              ),
            ),
            SizedBox(
              height: 108,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing16,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: rankings.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: DesignTokens.spacing8),
                itemBuilder: (context, index) => _IndustryCard(
                  ranking: rankings[index],
                  rank: index + 1,
                  windowLabel: _windowLabel(_window),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spacing8),
          ],
        );
      },
    );
  }
}

class _IndustryCard extends ConsumerWidget {
  const _IndustryCard({
    required this.ranking,
    required this.rank,
    required this.windowLabel,
  });

  final IndustryRanking ranking;
  final int rank;
  final String windowLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final momentumColor = AppTheme.getPriceColor(
      ranking.momentumPct,
      theme.brightness,
    );
    final netColor = AppTheme.getPriceColor(
      ranking.institutionalNetShares,
      theme.brightness,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        onTap: () {
          HapticFeedback.selectionClick();
          _showMembersSheet(context, ref);
        },
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '$rank',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing4),
                  Text(
                    ranking.industry,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing4),
                  Text(
                    'today.industryMemberCount'.tr(
                      args: ['${ranking.memberCount}'],
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                AppNumberFormat.signedPercent(ranking.momentumPct, decimals: 1),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: momentumColor,
                ),
              ),
              Row(
                children: [
                  Text(
                    'today.industryInstitutional'.tr(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing4),
                  Text(
                    formatNet(ranking.institutionalNetShares),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: netColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMembersSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing16,
                ),
                child: Text(
                  'today.industryTopMembers'.tr(
                    args: [ranking.industry, windowLabel],
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              ...ranking.topMembers.map(
                (m) => ListTile(
                  dense: true,
                  title: Text(m.name.isEmpty ? m.symbol : m.name),
                  subtitle: Text(m.symbol),
                  trailing: Text(
                    AppNumberFormat.signedPercent(m.retPct, decimals: 1),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getPriceColor(m.retPct, theme.brightness),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ref.read(stockBrowsingContextProvider.notifier).set([
                      for (final t in ranking.topMembers) t.symbol,
                    ]);
                    context.push(AppRoutes.stockDetail(m.symbol));
                  },
                ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
            ],
          ),
        );
      },
    );
  }
}
