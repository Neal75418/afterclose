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
/// 顯示 Hero 指數、子指數、漲跌家數 Donut、法人動向 Bar、融資融券。
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
      (idx) => idx.name.contains(MarketIndexNames.taiexKeyword),
    );
    final subIndices = state.indices
        .where((idx) => !idx.name.contains(MarketIndexNames.taiexKeyword))
        .toList();

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

              // Hero 加權指數
              if (taiex.isNotEmpty) ...[
                const SizedBox(height: 12),
                HeroIndexSection(
                  taiex: taiex.first,
                  historyData: state.indexHistory[taiex.first.name] ?? [],
                ),
              ],

              // 子指數列
              if (subIndices.isNotEmpty) ...[
                const SizedBox(height: 10),
                SubIndicesRow(
                  subIndices: subIndices,
                  historyMap: state.indexHistory,
                ),
              ],

              // 漲跌家數 Donut
              if (state.advanceDecline.total > 0) ...[
                const SizedBox(height: 16),
                AdvanceDeclineGauge(data: state.advanceDecline),
              ],

              // 法人動向
              if (state.institutional.totalNet != 0) ...[
                const SizedBox(height: 16),
                InstitutionalFlowChart(data: state.institutional),
              ],

              // 融資融券
              if (state.margin.marginChange != 0 ||
                  state.margin.shortChange != 0) ...[
                const SizedBox(height: 16),
                MarginCompactRow(data: state.margin),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
