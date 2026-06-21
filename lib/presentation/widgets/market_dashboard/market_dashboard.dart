import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:afterclose/core/constants/animations.dart';
import 'package:afterclose/core/constants/market_codes.dart';
import 'package:afterclose/core/constants/app_routes.dart';
import 'package:afterclose/core/theme/breakpoints.dart';
import 'package:afterclose/presentation/providers/market_overview_provider.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/advance_decline_gauge.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/hero_index_section.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/industry_performance_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/institutional_flow_chart.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/margin_compact_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/chip_anomaly_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/trading_turnover_row.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/sentiment_gauge_section.dart';
import 'package:afterclose/presentation/widgets/market_dashboard/warnings_summary_row.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/date_context.dart';
import 'package:afterclose/core/utils/taiwan_calendar.dart';
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

/// 並排雙欄 view 的寬度門檻
///
/// `Breakpoints.mobile`（600px）作為「mobile 單欄+Tab」與其他的 binary
/// 切換太低 — 601-1023px 區間（iPad portrait、split-screen macOS、小 dev
/// window）會被切到 parallel 雙欄，每欄僅 ~300px 比 phone 還窄但用 desktop
/// 排版。改在 1024px（與 [Breakpoints.tablet] 對齊）才進入並排，medium
/// 寬度維持 tabbed 單欄，閱讀體驗一致。
const double _kParallelViewMinWidth = Breakpoints.tablet;

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
        padding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing16,
          vertical: DesignTokens.spacing8,
        ),
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

    // 有舊資料但最近一次 refresh 失敗時，在 dashboard 頂部顯示提示
    final refreshError = widget.state.error;
    final screenWidth = MediaQuery.of(context).size.width;
    // `isMobile` 涵蓋 phone + medium 螢幕（< 1024px）— 兩者都用 Tab 切換上市/
    // 上櫃單欄，避免 medium 螢幕被 600px 舊門檻塞進並排雙欄而各欄只有 ~300px。
    final isMobile = screenWidth < _kParallelViewMinWidth;

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
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // refresh 失敗提示（有舊資料仍顯示，但警告使用者資料可能過時）
              if (refreshError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.spacing8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: DesignTokens.spacing4),
                      Expanded(
                        child: Text(
                          refreshError,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // 標題列（包含市場選擇器）
              _buildHeader(theme, isMobile),

              const SizedBox(height: DesignTokens.spacing16),

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
        const SizedBox(width: DesignTokens.spacing8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'marketOverview.title'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            // 顯示近似資料日期：dashboard 各區塊可能來自不同日期
            // （by-market 回退、融資融券各市場最新值等），以 ≈ 標示
            if (dataDate != null)
              Text(
                '≈ ${DateFormat('MM/dd').format(dataDate)}${isLatest ? '' : ' ${'marketOverview.notToday'.tr()}'}',
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
          const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing12,
            vertical: DesignTokens.spacing6,
          ),
        ),
      ),
    );
  }

  /// 取得指定市場 Hero 指數的漲跌幅（%）
  ///
  /// 供量價 / 籌碼槓桿判讀使用（TWSE→加權指數、TPEx→櫃買指數）。
  /// 找不到對應指數時回傳 null，判讀行不顯示。
  double? _indexChangePercent(String marketKey) {
    final heroName = marketKey == MarketCode.twse
        ? MarketIndexNames.taiex
        : MarketIndexNames.tpexIndex;
    for (final idx in widget.state.indices) {
      if (idx.name == heroName) return idx.changePercent;
    }
    return null;
  }

  /// 計算指定市場的市場情緒分數
  MarketSentiment? _computeSentiment(String marketKey) {
    final ad = widget.state.advanceDeclineByMarket[marketKey];
    final trends = widget.state.historyTrends;
    final instHist = trends.institutionalTotalNet[marketKey];
    final turnHist = trends.turnover[marketKey];
    final marginHist = trends.marginBalance[marketKey];
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
            stageHistory:
                widget.state.indexStageHistory[taiex.first.name] ?? [],
            totalReturnHistory:
                widget.state.indexHistory[MarketIndexNames.totalReturnIndex] ??
                [],
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
            stageHistory:
                widget.state.indexStageHistory[MarketIndexNames.tpexIndex] ??
                [],
          ),
        );
      } else {
        sections.add(
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacing16),
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
          indexChangePercent: _indexChangePercent(marketKey),
        ),
      );
    }

    if (instData != null &&
        (instData.totalNet != 0 ||
            instData.foreignNet != 0 ||
            instData.trustNet != 0 ||
            instData.dealerNet != 0)) {
      sections.add(
        _wrapWithDateIndicator(
          sectionKey: MarketOverviewState.kSectionInstitutional,
          child: InstitutionalFlowChart(
            data: instData,
            streak: instStreak,
            totalNetHistory: instNetHist,
          ),
        ),
      );
    }

    if (marginData != null &&
        (marginData.marginChange != 0 || marginData.shortChange != 0)) {
      sections.add(
        _wrapWithDateIndicator(
          sectionKey: MarketOverviewState.kSectionMargin,
          child: MarginCompactRow(
            data: marginData,
            marginBalanceHistory: marginHist,
            shortBalanceHistory: shortHist,
            indexChangePercent: _indexChangePercent(marketKey),
          ),
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

    // 組合所有 sections
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i < 2)
            // Hero + 子指數之間用較小間距，不加分隔線
            const SizedBox(height: DesignTokens.spacing10)
          else ...[
            const SizedBox(height: DesignTokens.spacing14),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: DesignTokens.spacing14),
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
    final sentiment = _computeSentiment(MarketCode.twse);

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
      final twse = builder(MarketCode.twse);
      final tpex = builder(MarketCode.tpex);
      if (twse == null && tpex == null) continue;
      pairedRows.add(_buildPairedRow(theme, twse, tpex));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 共用：市場情緒儀表板（僅 TWSE，TPEx 資料量不足以穩定計算）
        if (sentiment != null) ...[
          Row(
            children: [
              Text(
                'marketOverview.twse'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: DesignTokens.spacing4),
              Text(
                'marketOverview.sentimentLabel'.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing6),
          SentimentGaugeSection(
            sentiment: sentiment,
            sentimentHistory: _computeSentimentHistory(MarketCode.twse),
            showInternalTitle: false, // 外層 Row 已渲染「上市 市場情緒」，避免重複
          ),
          const SizedBox(height: DesignTokens.spacing14),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: DesignTokens.spacing14),
        ],

        // 標題 + Hero 指數配對
        _buildPairedRow(
          theme,
          _buildMarketHeader(theme, MarketCode.twse),
          _buildMarketHeader(theme, MarketCode.tpex),
        ),

        // 資料 section 配對（每對等高對齊）
        for (final row in pairedRows) ...[
          const SizedBox(height: DesignTokens.spacing12),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          row,
        ],
      ],
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
    final heroName = market == MarketCode.twse
        ? MarketIndexNames.taiex
        : MarketIndexNames.tpexIndex;
    final heroIdx = widget.state.indices
        .where((idx) => idx.name == heroName)
        .toList();

    // TPEx 側保留與 TWSE badge 等高的空間
    final shouldReserveBadge =
        market == MarketCode.tpex &&
        (widget.state.indexHistory[MarketIndexNames.taiex]?.length ?? 0) >= 2 &&
        (widget.state.indexHistory[MarketIndexNames.totalReturnIndex]?.length ??
                0) >=
            2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          market == MarketCode.twse
              ? 'marketOverview.twse'.tr()
              : 'marketOverview.tpex'.tr(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DesignTokens.spacing12),
        if (heroIdx.isNotEmpty)
          HeroIndexSection(
            index: heroIdx.first,
            historyData: widget.state.indexHistory[heroName] ?? [],
            stageHistory: widget.state.indexStageHistory[heroName] ?? [],
            totalReturnHistory: market == MarketCode.twse
                ? widget.state.indexHistory[MarketIndexNames
                          .totalReturnIndex] ??
                      []
                : [],
            reserveBadgeSpace: shouldReserveBadge,
          )
        else
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacing16),
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

  // ==================================================
  // Section date indicator
  // ==================================================

  /// 若該區塊的實際資料日期比主日期舊，在右上角顯示小日期標籤
  Widget _wrapWithDateIndicator({
    required String sectionKey,
    required Widget child,
  }) {
    final sectionDate = widget.state.sectionDates[sectionKey];
    final mainDate = widget.state.dataDate;
    if (sectionDate == null || mainDate == null) return child;

    // 只在 section 日期比主日期舊時才顯示
    final sectionDay = DateTime(
      sectionDate.year,
      sectionDate.month,
      sectionDate.day,
    );
    final mainDay = DateTime(mainDate.year, mainDate.month, mainDate.day);
    if (!sectionDay.isBefore(mainDay)) return child;

    final theme = Theme.of(context);
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          child: Text(
            '${sectionDate.month}/${sectionDate.day}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
            ),
          ),
        ),
      ],
    );
  }

  // ==================================================
  // Section builders
  // ==================================================

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
      indexChangePercent: _indexChangePercent(market),
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
    return _wrapWithDateIndicator(
      sectionKey: MarketOverviewState.kSectionInstitutional,
      child: InstitutionalFlowChart(
        data: instData,
        streak: widget.state.institutionalStreakByMarket[market],
        totalNetHistory:
            widget.state.historyTrends.institutionalTotalNet[market],
      ),
    );
  }

  Widget? _buildMarginSection(String market) {
    final marginData = widget.state.marginByMarket[market];
    if (marginData == null ||
        (marginData.marginChange == 0 && marginData.shortChange == 0)) {
      return null;
    }
    return _wrapWithDateIndicator(
      sectionKey: MarketOverviewState.kSectionMargin,
      child: MarginCompactRow(
        data: marginData,
        marginBalanceHistory: widget.state.historyTrends.marginBalance[market],
        shortBalanceHistory: widget.state.historyTrends.shortBalance[market],
        indexChangePercent: _indexChangePercent(market),
      ),
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
