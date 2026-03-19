import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/breakpoints.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/advance_decline_gauge.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/hero_index_section.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/key_insights_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/industry_performance_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/institutional_flow_chart.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/margin_compact_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/chip_anomaly_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/recommendation_performance_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/sub_indices_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/trading_turnover_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/sentiment_gauge_section.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/warnings_summary_row.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
import 'package:afterclose/domain/services/market_insight_service.dart';
import 'package:afterclose/domain/services/market_sentiment_service.dart';

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
enum _MarketSegment {
  // ignore: constant_identifier_names
  TWSE,
  // ignore: constant_identifier_names
  TPEx;

  /// 對應 state map 的 key
  String get key => name;
}

class _MarketDashboardState extends State<MarketDashboard> {
  _MarketSegment _selectedMarket = _MarketSegment.TWSE;

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
    ).animate().fadeIn(duration: AnimDurations.standard);
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
    return SegmentedButton<_MarketSegment>(
      segments: [
        ButtonSegment(
          value: _MarketSegment.TWSE,
          label: Text(
            'marketOverview.twse'.tr(),
            style: const TextStyle(fontSize: DesignTokens.fontSizeSm),
          ),
        ),
        ButtonSegment(
          value: _MarketSegment.TPEx,
          label: Text(
            'marketOverview.tpex'.tr(),
            style: const TextStyle(fontSize: DesignTokens.fontSizeSm),
          ),
        ),
      ],
      selected: {_selectedMarket},
      onSelectionChanged: (Set<_MarketSegment> newSelection) {
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

  /// 計算指定市場的市場情緒分數
  MarketSentiment? _computeSentiment(String marketKey) {
    final ad = widget.state.advanceDeclineByMarket[marketKey];
    final trends = widget.state.historyTrends;
    final instHist = trends.institutionalTotalNet[marketKey];
    final turnHist = trends.turnover[marketKey];
    final marginHist = trends.marginBalance[marketKey];
    final limitUD = widget.state.limitUpDownByMarket[marketKey];
    final industries = widget.state.industrySummaryByMarket[marketKey];

    // 至少需要漲跌家數 + 一項歷史資料
    if (ad == null || ad.total == 0) return null;
    if ((instHist == null || instHist.length < 5) &&
        (turnHist == null || turnHist.length < 2)) {
      return null;
    }

    return MarketSentimentService.calculate(
      advanceDecline: ad,
      institutionalNetHistory: instHist ?? [],
      turnoverHistory: turnHist ?? [],
      marginBalanceHistory: marginHist ?? [],
      limitUpDown: limitUD,
      industries: industries ?? [],
    );
  }

  /// 計算歷史情緒分數序列（供趨勢 sparkline）
  List<double> _computeSentimentHistory(String marketKey) {
    final trends = widget.state.historyTrends;
    final advRatioHist = trends.advanceRatio[marketKey];
    final instHist = trends.institutionalTotalNet[marketKey];
    final turnHist = trends.turnover[marketKey];
    final marginHist = trends.marginBalance[marketKey];

    if (advRatioHist == null ||
        instHist == null ||
        turnHist == null ||
        marginHist == null) {
      return [];
    }

    return MarketSentimentService.calculateHistoricalScores(
      advanceRatioHistory: advRatioHist,
      institutionalNetHistory: instHist,
      turnoverHistory: turnHist,
      marginBalanceHistory: marginHist,
    );
  }

  /// 偵測智慧摘要洞察
  ///
  /// 接受已計算好的 [sentiment] 避免重複呼叫 [_computeSentiment]。
  List<MarketInsight> _computeInsights(
    String marketKey,
    MarketSentiment? sentiment,
  ) {
    return MarketInsightService.detect(
      sentiment: sentiment,
      streak: widget.state.institutionalStreakByMarket[marketKey],
      turnoverComparison: widget.state.turnoverComparisonByMarket[marketKey],
      chipAnomalies: widget.state.chipAnomaliesByMarket[marketKey] ?? [],
      limitUpDown: widget.state.limitUpDownByMarket[marketKey],
      margin: widget.state.marginByMarket[marketKey],
      industries: widget.state.industrySummaryByMarket[marketKey] ?? [],
    );
  }

  /// 建構手機單欄顯示
  Widget _buildMobileView(ThemeData theme) {
    final sections = <Widget>[];

    // Section 1: Hero 加權指數（僅 TWSE）
    if (_selectedMarket == _MarketSegment.TWSE) {
      final taiex = widget.state.indices
          .where((idx) => idx.name == MarketIndexNames.taiex)
          .toList();

      if (taiex.isNotEmpty) {
        sections.add(
          HeroIndexSection(
            index: taiex.first,
            historyData: widget.state.indexHistory[taiex.first.name] ?? [],
            totalReturnHistory:
                widget.state.indexHistory[MarketIndexNames.totalReturnIndex] ??
                [],
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
      // 上櫃：顯示櫃買指數 Hero
      final tpexIdx = widget.state.indices
          .where((idx) => idx.name == MarketIndexNames.tpexIndex)
          .toList();

      if (tpexIdx.isNotEmpty) {
        sections.add(
          HeroIndexSection(
            index: tpexIdx.first,
            historyData:
                widget.state.indexHistory[MarketIndexNames.tpexIndex] ?? [],
          ),
        );
      } else {
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
    }

    // Section: 市場情緒儀表板
    final marketKey = _selectedMarket.key;
    final sentiment = _computeSentiment(marketKey);
    if (sentiment != null) {
      sections.add(
        SentimentGaugeSection(
          sentiment: sentiment,
          sentimentHistory: _computeSentimentHistory(marketKey),
        ),
      );
    }

    // Section: 智慧摘要
    final insights = _computeInsights(marketKey, sentiment);
    if (insights.isNotEmpty) {
      sections.add(KeyInsightsRow(insights: insights));
    }

    // Section 3+: 統計數據（依選擇的市場顯示）
    final adData = widget.state.advanceDeclineByMarket[marketKey];
    final instData = widget.state.institutionalByMarket[marketKey];
    final marginData = widget.state.marginByMarket[marketKey];
    final turnoverData = widget.state.turnoverByMarket[marketKey];
    final limitUpDown = widget.state.limitUpDownByMarket[marketKey];
    final turnoverComparison =
        widget.state.turnoverComparisonByMarket[marketKey];
    final warningCounts = widget.state.warningCountsByMarket[marketKey];
    final instStreak = widget.state.institutionalStreakByMarket[marketKey];
    final industries = widget.state.industrySummaryByMarket[marketKey];

    // 30日歷史趨勢
    final trends = widget.state.historyTrends;
    final instNetHist = trends.institutionalTotalNet[marketKey];
    final turnoverHist = trends.turnover[marketKey];
    final marginHist = trends.marginBalance[marketKey];
    final shortHist = trends.shortBalance[marketKey];
    final advRatioHist = trends.advanceRatio[marketKey];

    if (adData != null && adData.total > 0) {
      sections.add(
        AdvanceDeclineGauge(
          data: adData,
          limitUpDown: limitUpDown,
          advanceRatioHistory: advRatioHist,
        ),
      );
    }

    // 成交量統計
    if (turnoverData != null && turnoverData.totalTurnover > 0) {
      sections.add(
        TradingTurnoverRow(
          data: turnoverData,
          turnoverComparison: turnoverComparison,
          turnoverHistory: turnoverHist,
        ),
      );
    }

    if (instData != null &&
        (instData.totalNet != 0 ||
            instData.foreignNet != 0 ||
            instData.trustNet != 0 ||
            instData.dealerNet != 0)) {
      sections.add(
        InstitutionalFlowChart(
          data: instData,
          streak: instStreak,
          totalNetHistory: instNetHist,
        ),
      );
    }

    if (marginData != null &&
        (marginData.marginChange != 0 || marginData.shortChange != 0)) {
      sections.add(
        MarginCompactRow(
          data: marginData,
          marginBalanceHistory: marginHist,
          shortBalanceHistory: shortHist,
        ),
      );
    }

    // 注意/處置股摘要
    if (warningCounts != null && warningCounts.total > 0) {
      sections.add(WarningsSummaryRow(data: warningCounts));
    }

    // 籌碼異動
    final chipAnomalies = widget.state.chipAnomaliesByMarket[marketKey];
    if (chipAnomalies != null && chipAnomalies.isNotEmpty) {
      sections.add(
        ChipAnomalyRow(
          anomalies: chipAnomalies,
          onStockTap: (symbol) => context.push(AppRoutes.stockDetail(symbol)),
        ),
      );
    }

    // 產業表現
    if (industries != null && industries.isNotEmpty) {
      sections.add(IndustryPerformanceRow(industries: industries));
    }

    // 推薦績效（全市場，非 per-market）
    final recPerf = widget.state.recommendationPerformance;
    if (recPerf != null) {
      sections.add(RecommendationPerformanceRow(data: recPerf));
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
  ///
  /// 使用跨欄配對方式，每個 section 型別左右配成一組 [IntrinsicHeight] + [Row]，
  /// 確保對應 section 水平對齊，避免左右高度差異導致後續 section 錯位。
  Widget _buildParallelView(ThemeData theme) {
    final subIndicesWidget = _buildSharedSubIndices();
    final sentiment = _computeSentiment('TWSE');

    // 每個 section builder 返回 Widget?，null 表示該市場無此資料
    final sectionBuilders = <Widget? Function(String)>[
      _buildAdvanceDeclineSection,
      _buildTurnoverSection,
      _buildInstitutionalSection,
      _buildMarginSection,
      _buildWarningsSection,
      _buildChipAnomalySection,
      _buildIndustrySection,
    ];

    // 產生配對的 section rows（跳過兩側皆無資料的 section）
    final pairedRows = <Widget>[];
    for (final builder in sectionBuilders) {
      final twse = builder('TWSE');
      final tpex = builder('TPEx');
      if (twse == null && tpex == null) continue;
      pairedRows.add(_buildPairedRow(theme, twse, tpex));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 共用：子指數列
        if (subIndicesWidget != null) ...[
          subIndicesWidget,
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 14),
        ],

        // 共用：市場情緒儀表板
        if (sentiment != null) ...[
          SentimentGaugeSection(
            sentiment: sentiment,
            sentimentHistory: _computeSentimentHistory('TWSE'),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 14),
        ],

        // 共用：智慧摘要
        ...() {
          final insights = _computeInsights('TWSE', sentiment);
          if (insights.isEmpty) return <Widget>[];
          return <Widget>[
            KeyInsightsRow(insights: insights),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 14),
          ];
        }(),

        // 標題 + Hero 指數配對
        _buildPairedRow(
          theme,
          _buildMarketHeader(theme, 'TWSE'),
          _buildMarketHeader(theme, 'TPEx'),
        ),

        // 資料 section 配對（每對等高對齊）
        for (final row in pairedRows) ...[
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          row,
        ],

        // 共用：推薦績效看板
        if (widget.state.recommendationPerformance != null) ...[
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 14),
          RecommendationPerformanceRow(
            data: widget.state.recommendationPerformance!,
          ),
        ],
      ],
    );
  }

  /// 建構共用子指數列（TWSE 產業指數，放在雙欄上方）
  Widget? _buildSharedSubIndices() {
    const subOrder = MarketIndexNames.dashboardIndices;
    final subIndices =
        widget.state.indices
            .where(
              (idx) =>
                  idx.name != MarketIndexNames.taiex &&
                  idx.name != MarketIndexNames.tpexIndex,
            )
            .toList()
          ..sort(
            (a, b) =>
                subOrder.indexOf(a.name).compareTo(subOrder.indexOf(b.name)),
          );

    if (subIndices.isEmpty) return null;

    return SubIndicesRow(
      subIndices: subIndices,
      historyMap: widget.state.indexHistory,
    );
  }

  /// 建構配對的跨欄 Row（左右等高）
  Widget _buildPairedRow(ThemeData theme, Widget? left, Widget? right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left ?? const SizedBox.shrink()),
          VerticalDivider(
            width: 32,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          Expanded(child: right ?? const SizedBox.shrink()),
        ],
      ),
    );
  }

  /// 建構市場標題 + Hero 指數
  Widget _buildMarketHeader(ThemeData theme, String market) {
    final heroName = market == 'TWSE'
        ? MarketIndexNames.taiex
        : MarketIndexNames.tpexIndex;
    final heroIdx = widget.state.indices
        .where((idx) => idx.name == heroName)
        .toList();

    // TPEx 側保留與 TWSE badge 等高的空間
    final shouldReserveBadge =
        market == 'TPEx' &&
        (widget.state.indexHistory[MarketIndexNames.taiex]?.length ?? 0) >= 2 &&
        (widget.state.indexHistory[MarketIndexNames.totalReturnIndex]?.length ??
                0) >=
            2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (heroIdx.isNotEmpty)
          HeroIndexSection(
            index: heroIdx.first,
            historyData: widget.state.indexHistory[heroName] ?? [],
            totalReturnHistory: market == 'TWSE'
                ? widget.state.indexHistory[MarketIndexNames
                          .totalReturnIndex] ??
                      []
                : [],
            reserveBadgeSpace: shouldReserveBadge,
          )
        else
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
      ],
    );
  }

  // ── Section builders ──────────────────────────────────────────────────

  Widget? _buildAdvanceDeclineSection(String market) {
    final adData = widget.state.advanceDeclineByMarket[market];
    if (adData == null || adData.total <= 0) return null;
    return AdvanceDeclineGauge(
      data: adData,
      limitUpDown: widget.state.limitUpDownByMarket[market],
      advanceRatioHistory: widget.state.historyTrends.advanceRatio[market],
    );
  }

  Widget? _buildTurnoverSection(String market) {
    final turnoverData = widget.state.turnoverByMarket[market];
    if (turnoverData == null || turnoverData.totalTurnover <= 0) return null;
    return TradingTurnoverRow(
      data: turnoverData,
      turnoverComparison: widget.state.turnoverComparisonByMarket[market],
      turnoverHistory: widget.state.historyTrends.turnover[market],
    );
  }

  Widget? _buildInstitutionalSection(String market) {
    final instData = widget.state.institutionalByMarket[market];
    if (instData == null ||
        (instData.totalNet == 0 &&
            instData.foreignNet == 0 &&
            instData.trustNet == 0 &&
            instData.dealerNet == 0)) {
      return null;
    }
    return InstitutionalFlowChart(
      data: instData,
      streak: widget.state.institutionalStreakByMarket[market],
      totalNetHistory: widget.state.historyTrends.institutionalTotalNet[market],
    );
  }

  Widget? _buildMarginSection(String market) {
    final marginData = widget.state.marginByMarket[market];
    if (marginData == null ||
        (marginData.marginChange == 0 && marginData.shortChange == 0)) {
      return null;
    }
    return MarginCompactRow(
      data: marginData,
      marginBalanceHistory: widget.state.historyTrends.marginBalance[market],
      shortBalanceHistory: widget.state.historyTrends.shortBalance[market],
    );
  }

  Widget? _buildWarningsSection(String market) {
    final warningCounts = widget.state.warningCountsByMarket[market];
    if (warningCounts == null || warningCounts.total <= 0) return null;
    return WarningsSummaryRow(data: warningCounts);
  }

  Widget? _buildChipAnomalySection(String market) {
    final chipAnomalies = widget.state.chipAnomaliesByMarket[market];
    if (chipAnomalies == null || chipAnomalies.isEmpty) return null;
    return ChipAnomalyRow(
      anomalies: chipAnomalies,
      onStockTap: (symbol) => context.push(AppRoutes.stockDetail(symbol)),
    );
  }

  Widget? _buildIndustrySection(String market) {
    final industries = widget.state.industrySummaryByMarket[market];
    if (industries == null || industries.isEmpty) return null;
    return IndustryPerformanceRow(industries: industries);
  }
}
