import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:k_chart_plus/chart_translations.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/core/theme/design_tokens.dart';

/// Professional K-line chart widget using k_chart_plus package
/// Supports MA, BOLL, RSI, KDJ, MACD, WR, CCI indicators
class KLineChartWidget extends StatefulWidget {
  const KLineChartWidget({
    super.key,
    required this.priceHistory,
    this.mainIndicators = const {MainState.MA},
    this.secondaryIndicators = const {},
    this.maDayList = const [5, 10, 20],
    this.height = 400,
  });

  final List<DailyPriceEntry> priceHistory;
  final Set<MainState> mainIndicators;
  final Set<SecondaryState> secondaryIndicators;
  final List<int> maDayList;
  final double height;

  @override
  State<KLineChartWidget> createState() => _KLineChartWidgetState();
}

class _KLineChartWidgetState extends State<KLineChartWidget> {
  List<KLineEntity> _kLineData = [];

  @override
  void initState() {
    super.initState();
    _buildKLineData();
  }

  @override
  void didUpdateWidget(KLineChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.priceHistory != widget.priceHistory ||
        oldWidget.mainIndicators != widget.mainIndicators ||
        oldWidget.secondaryIndicators != widget.secondaryIndicators ||
        oldWidget.maDayList != widget.maDayList) {
      _buildKLineData();
    }
  }

  void _buildKLineData() {
    if (widget.priceHistory.isEmpty) {
      setState(() {
        _kLineData = [];
      });
      return;
    }

    // Convert DailyPriceEntry to KLineEntity
    // k_chart_plus requires data sorted from oldest to newest
    final sortedHistory = List<DailyPriceEntry>.from(widget.priceHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    final kLineData = <KLineEntity>[];
    for (final entry in sortedHistory) {
      if (entry.open != null &&
          entry.high != null &&
          entry.low != null &&
          entry.close != null) {
        kLineData.add(
          KLineEntity.fromCustom(
            time: entry.date.millisecondsSinceEpoch,
            open: entry.open!,
            high: entry.high!,
            low: entry.low!,
            close: entry.close!,
            vol: entry.volume ?? 0,
          ),
        );
      }
    }

    // Calculate all technical indicators
    if (kLineData.isNotEmpty) {
      DataUtil.calculate(kLineData, widget.maDayList);
    }

    setState(() {
      _kLineData = kLineData;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_kLineData.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        child: Center(
          child: Text(
            'stockDetail.noKlineData'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    // Configure chart colors based on theme
    // Configure chart colors based on theme
    final chartColors = ChartColors(
      bgColor: isDark
          ? IndicatorColors.chartDarkBackground
          : Colors.white, // Match AppTheme.scaffoldBackgroundColor
      kLineColor: theme.colorScheme.primary,
      gridColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
      ma5Color: IndicatorColors.chartPrimary,
      ma10Color: IndicatorColors.chartSecondary,
      ma30Color: IndicatorColors.chartTertiary,
      upColor: AppTheme.upColor, // Red
      dnColor: AppTheme.downColor, // Green
      volColor: theme.colorScheme.primary.withValues(alpha: 0.5),
      macdColor: IndicatorColors.chartPrimary,
      difColor: IndicatorColors.chartPrimary,
      deaColor: IndicatorColors.chartSecondary,
      kColor: IndicatorColors.chartPrimary,
      dColor: IndicatorColors.chartSecondary,
      jColor: IndicatorColors.chartTertiary,
      rsiColor: IndicatorColors.chartSecondary,
      defaultTextColor: theme.colorScheme.onSurfaceVariant,
      nowPriceUpColor: AppTheme.upColor,
      nowPriceDnColor: AppTheme.downColor,
      nowPriceTextColor: Colors.white,
      maxColor: AppTheme.upColor,
      minColor: AppTheme.downColor,
    );

    // Configure chart style (uses mutable properties)
    final chartStyle = ChartStyle()
      ..topPadding = 30
      ..bottomPadding = 20
      ..childPadding = 12
      ..pointWidth = 11
      ..candleWidth = 8.5
      ..candleLineWidth = 1.5
      ..volWidth = 8.5
      ..macdWidth = 3
      ..vCrossWidth = 8.5
      ..hCrossWidth = 0.5
      ..nowPriceLineLength = 1
      ..nowPriceLineSpan = 1
      ..nowPriceLineWidth = 1
      ..gridRows = 4
      ..gridColumns = 4;

    // 計算圖表摘要資訊供無障礙使用
    final summary = _buildChartSummary();

    return Semantics(
      label: summary,
      hint: 'stockDetail.chartHint'.tr(),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark ? IndicatorColors.chartDarkBackground : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          // Subtle border to define the chart area
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: KChartWidget(
          _kLineData,
          chartStyle,
          chartColors,
          isTrendLine: false,
          mainStateLi: widget.mainIndicators,
          secondaryStateLi: widget.secondaryIndicators,
          volHidden: false,
          isLine: false,
          isTapShowInfoDialog: true,
          hideGrid: false,
          showNowPrice: true,
          showInfoDialog: true,
          materialInfoDialog: true,
          maDayList: widget.maDayList,
          timeFormat: TimeFormat.YEAR_MONTH_DAY,
          mBaseHeight: widget.height - 50,
          fixedLength: 2,
          chartTranslations: ChartTranslations(
            date: 'stockDetail.date'.tr(),
            open: 'stockDetail.open'.tr(),
            high: 'stockDetail.high'.tr(),
            low: 'stockDetail.low'.tr(),
            close: 'stockDetail.close'.tr(),
            changeAmount: 'stockDetail.change'.tr(),
            change: 'stockDetail.changePercent'.tr(),
            vol: 'stockDetail.volume'.tr(),
          ),
        ),
      ),
    );
  }

  /// 建立圖表摘要供無障礙使用
  String _buildChartSummary() {
    if (_kLineData.isEmpty) {
      return 'stockDetail.noKlineData'.tr();
    }

    final first = _kLineData.first;
    final last = _kLineData.last;

    // 計算期間內的最高和最低價
    double high = last.high;
    double low = last.low;
    for (final entity in _kLineData) {
      if (entity.high > high) high = entity.high;
      if (entity.low < low) low = entity.low;
    }

    // 計算漲跌幅
    final change = last.close - first.close;
    final changePercent = first.close > 0 ? (change / first.close * 100) : 0.0;
    final trend = change >= 0 ? 'stockDetail.up'.tr() : 'stockDetail.down'.tr();

    return 'stockDetail.chartSummary'.tr(
      namedArgs: {
        'days': _kLineData.length.toString(),
        'high': high.toStringAsFixed(2),
        'low': low.toStringAsFixed(2),
        'close': last.close.toStringAsFixed(2),
        'trend': trend,
        'change': changePercent.abs().toStringAsFixed(2),
      },
    );
  }
}
