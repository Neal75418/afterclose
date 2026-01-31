import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/advance_decline_gauge.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/hero_index_section.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/institutional_flow_chart.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/margin_compact_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/sub_indices_row.dart';

/// 大盤總覽 Dashboard
///
/// 組合 5 個子 widget，取代舊的 MarketOverviewCard。
/// 顯示 Hero 指數、子指數、漲跌家數、法人動向、融資融券。
class MarketDashboard extends StatelessWidget {
  const MarketDashboard({super.key, required this.state});

  final MarketOverviewState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          child: SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    if (!state.hasData) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // 分離加權指數 vs 子指數
    final taiex = state.indices.where(
      (idx) => idx.name == MarketIndexNames.taiex,
    );
    // 依 dashboardIndices 定義順序排列子指數
    const subOrder = MarketIndexNames.dashboardIndices;
    final subIndices =
        state.indices
            .where((idx) => idx.name != MarketIndexNames.taiex)
            .toList()
          ..sort(
            (a, b) =>
                subOrder.indexOf(a.name).compareTo(subOrder.indexOf(b.name)),
          );

    // 收集各 section widget
    final sections = <Widget>[];

    // Section 1: Hero 加權指數
    if (taiex.isNotEmpty) {
      sections.add(
        HeroIndexSection(
          taiex: taiex.first,
          historyData: state.indexHistory[taiex.first.name] ?? [],
        ),
      );
    }

    // Section 2: 子指數列
    if (subIndices.isNotEmpty) {
      sections.add(
        SubIndicesRow(subIndices: subIndices, historyMap: state.indexHistory),
      );
    }

    // Section 3: 漲跌家數
    if (state.advanceDecline.total > 0) {
      sections.add(AdvanceDeclineGauge(data: state.advanceDecline));
    }

    // Section 4: 法人動向
    final inst = state.institutional;
    if (inst.totalNet != 0 ||
        inst.foreignNet != 0 ||
        inst.trustNet != 0 ||
        inst.dealerNet != 0) {
      sections.add(InstitutionalFlowChart(data: inst));
    }

    // Section 5: 融資融券
    if (state.margin.marginChange != 0 || state.margin.shortChange != 0) {
      sections.add(MarginCompactRow(data: state.margin));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題
              Row(
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'marketOverview.title'.tr(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // 各 section 之間用分隔線隔開
              for (int i = 0; i < sections.length; i++) ...[
                if (i < 2)
                  // Hero + 子指數之間用較小間距，不加分隔線
                  const SizedBox(height: 10)
                else ...[
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                sections[i],
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
