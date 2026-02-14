import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:afterclose/core/theme/breakpoints.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/advance_decline_gauge.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/hero_index_section.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/institutional_flow_chart.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/margin_compact_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/sub_indices_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/trading_turnover_row.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';

/// 大盤總覽 Dashboard
///
/// 組合 5 個子 widget，取代舊的 MarketOverviewCard。
/// 顯示 Hero 指數、子指數、漲跌家數、法人動向、融資融券。
/// 支援上市/上櫃市場切換，手機使用 Tab，平板/桌面並排顯示。
class MarketDashboard extends StatefulWidget {
  const MarketDashboard({super.key, required this.state});

  final MarketOverviewState state;

  @override
  State<MarketDashboard> createState() => _MarketDashboardState();
}

/// 市場區段（避免使用 magic string）
enum MarketSegment {
  // ignore: constant_identifier_names
  TWSE,
  // ignore: constant_identifier_names
  TPEx;

  /// 對應 state map 的 key
  String get key => name;
}

class _MarketDashboardState extends State<MarketDashboard> {
  MarketSegment _selectedMarket = MarketSegment.TWSE;

  @override
  Widget build(BuildContext context) {
    if (widget.state.isLoading) {
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

    if (!widget.state.hasData) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < Breakpoints.mobile;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題列（包含市場選擇器）
              _buildHeader(theme, isMobile),

              const SizedBox(height: 16),

              // 主內容區域
              if (isMobile)
                _buildMobileView(theme)
              else
                _buildParallelView(theme),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  /// 建構標題列
  Widget _buildHeader(ThemeData theme, bool isMobile) {
    final dataDate = widget.state.dataDate;
    final now = DateTime.now();
    final latestTradingDay = TaiwanCalendar.isTradingDay(now)
        ? DateContext.normalize(now)
        : TaiwanCalendar.getPreviousTradingDay(now);
    final isLatest =
        dataDate != null &&
        dataDate.year == latestTradingDay.year &&
        dataDate.month == latestTradingDay.month &&
        dataDate.day == latestTradingDay.day;

    return Row(
      children: [
        Icon(Icons.show_chart, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'marketOverview.title'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            // 顯示資料日期，非今日時以警示色標示
            if (dataDate != null)
              Text(
                DateFormat('MM/dd').format(dataDate) +
                    (isLatest ? '' : ' ${'marketOverview.notToday'.tr()}'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isLatest
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurfaceVariant.withAlpha(178),
                ),
              ),
          ],
        ),
        const Spacer(),
        // 市場選擇器（手機顯示）
        if (isMobile) _buildMarketSelector(theme),
      ],
    );
  }

  /// 建構市場選擇器（SegmentedButton）
  Widget _buildMarketSelector(ThemeData theme) {
    return SegmentedButton<MarketSegment>(
      segments: [
        ButtonSegment(
          value: MarketSegment.TWSE,
          label: Text(
            'marketOverview.twse'.tr(),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        ButtonSegment(
          value: MarketSegment.TPEx,
          label: Text(
            'marketOverview.tpex'.tr(),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
      selected: {_selectedMarket},
      onSelectionChanged: (Set<MarketSegment> newSelection) {
        setState(() {
          _selectedMarket = newSelection.first;
        });
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    );
  }

  /// 建構手機單欄顯示
  Widget _buildMobileView(ThemeData theme) {
    final sections = <Widget>[];

    // Section 1: Hero 加權指數（僅 TWSE）
    if (_selectedMarket == MarketSegment.TWSE) {
      final taiex = widget.state.indices
          .where((idx) => idx.name == MarketIndexNames.taiex)
          .toList();

      if (taiex.isNotEmpty) {
        sections.add(
          HeroIndexSection(
            taiex: taiex.first,
            historyData: widget.state.indexHistory[taiex.first.name] ?? [],
          ),
        );
      }

      // Section 2: 子指數列
      const subOrder = MarketIndexNames.dashboardIndices;
      final subIndices =
          widget.state.indices
              .where((idx) => idx.name != MarketIndexNames.taiex)
              .toList()
            ..sort(
              (a, b) =>
                  subOrder.indexOf(a.name).compareTo(subOrder.indexOf(b.name)),
            );

      if (subIndices.isNotEmpty) {
        sections.add(
          SubIndicesRow(
            subIndices: subIndices,
            historyMap: widget.state.indexHistory,
          ),
        );
      }
    } else {
      // 上櫃無指數，顯示佔位符
      sections.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'marketOverview.tpexNoIndex'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Section 3-6: 統計數據（依選擇的市場顯示）
    final marketKey = _selectedMarket.key;
    final adData = widget.state.advanceDeclineByMarket[marketKey];
    final instData = widget.state.institutionalByMarket[marketKey];
    final marginData = widget.state.marginByMarket[marketKey];
    final turnoverData = widget.state.turnoverByMarket[marketKey];

    if (adData != null && adData.total > 0) {
      sections.add(AdvanceDeclineGauge(data: adData));
    }

    // 成交量統計
    if (turnoverData != null && turnoverData.totalTurnover > 0) {
      sections.add(TradingTurnoverRow(data: turnoverData));
    }

    if (instData != null &&
        (instData.totalNet != 0 ||
            instData.foreignNet != 0 ||
            instData.trustNet != 0 ||
            instData.dealerNet != 0)) {
      sections.add(InstitutionalFlowChart(data: instData));
    }

    if (marginData != null &&
        (marginData.marginChange != 0 || marginData.shortChange != 0)) {
      sections.add(MarginCompactRow(data: marginData));
    }

    // 組合所有 sections
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i < 2)
            // Hero + 子指數之間用較小間距，不加分隔線
            const SizedBox(height: 10)
          else ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 14),
          ],
          sections[i],
        ],
      ],
    );
  }

  /// 建構平板/桌面並排顯示
  Widget _buildParallelView(ThemeData theme) {
    // 先顯示 Hero 指數（僅 TWSE）
    final sections = <Widget>[];

    final taiex = widget.state.indices
        .where((idx) => idx.name == MarketIndexNames.taiex)
        .toList();

    if (taiex.isNotEmpty) {
      sections.add(
        HeroIndexSection(
          taiex: taiex.first,
          historyData: widget.state.indexHistory[taiex.first.name] ?? [],
        ),
      );
    }

    // Section 2: 子指數列
    const subOrder = MarketIndexNames.dashboardIndices;
    final subIndices =
        widget.state.indices
            .where((idx) => idx.name != MarketIndexNames.taiex)
            .toList()
          ..sort(
            (a, b) =>
                subOrder.indexOf(a.name).compareTo(subOrder.indexOf(b.name)),
          );

    if (subIndices.isNotEmpty) {
      sections.add(
        SubIndicesRow(
          subIndices: subIndices,
          historyMap: widget.state.indexHistory,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero + 子指數
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          sections[i],
        ],

        const SizedBox(height: 14),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 14),

        // 並排顯示上市/上櫃統計數據
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildMarketColumn(theme, 'TWSE')),
              VerticalDivider(
                width: 32,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              Expanded(child: _buildMarketColumn(theme, 'TPEx')),
            ],
          ),
        ),
      ],
    );
  }

  /// 建構單一市場欄位（用於平板/桌面並排）
  Widget _buildMarketColumn(ThemeData theme, String market) {
    final adData = widget.state.advanceDeclineByMarket[market];
    final instData = widget.state.institutionalByMarket[market];
    final marginData = widget.state.marginByMarket[market];
    final turnoverData = widget.state.turnoverByMarket[market];

    final children = <Widget>[
      // 標題
      Text(
        market == 'TWSE'
            ? 'marketOverview.twse'.tr()
            : 'marketOverview.tpex'.tr(),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
    ];

    // 統計數據
    if (adData == null || adData.total == 0) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'marketOverview.noData'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      // 漲跌家數
      if (adData.total > 0) {
        children.add(AdvanceDeclineGauge(data: adData));
        children.add(const SizedBox(height: 12));
        children.add(
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        );
        children.add(const SizedBox(height: 12));
      }

      // 成交量統計
      if (turnoverData != null && turnoverData.totalTurnover > 0) {
        children.add(TradingTurnoverRow(data: turnoverData));
        children.add(const SizedBox(height: 12));
        children.add(
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        );
        children.add(const SizedBox(height: 12));
      }

      // 法人動向
      if (instData != null &&
          (instData.totalNet != 0 ||
              instData.foreignNet != 0 ||
              instData.trustNet != 0 ||
              instData.dealerNet != 0)) {
        children.add(InstitutionalFlowChart(data: instData));
        children.add(const SizedBox(height: 12));
        children.add(
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        );
        children.add(const SizedBox(height: 12));
      }

      // 融資融券
      if (marginData != null &&
          (marginData.marginChange != 0 || marginData.shortChange != 0)) {
        children.add(MarginCompactRow(data: marginData));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
