import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

// k_chart_plus 也匯出名為 `S` 的類別，需前綴避免衝突
import 'package:afterclose/core/l10n/app_strings.dart' as l10n;
import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/core/theme/indicator_colors.dart';
import 'package:afterclose/core/theme/semantic_colors.dart';
import 'package:afterclose/core/utils/number_formatter.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/chart_indicators.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/k_chart_detail_popup.dart';

/// 使用 k_chart_plus 套件的 K 線圖 Widget，
/// 支援 MA、BOLL、SAR、RSI、KDJ、MACD、WR、CCI 指標。
///
/// 2026-08-03 升級至 k_chart_plus 1.0.4，修掉 1.0.3 的兩個缺陷：
/// 1. `MainRenderer.drawMaLine` 寫死 `if (i == 3) break;`——**第四條均線
///    (MA60) 的線從來沒有被畫到 canvas**，只有圖例文字被畫出來
/// 2. `ChartColors.getMAColor` 用 `index % 3` 循環三色——MA60 的圖例
///    撞回 MA5 的藍色
///
/// 代價（已知、可接受）：1.0.4 的 [KChartStyle] 樣式欄位改為 final 硬編碼，
/// 原本的 `topPadding=30` / `candleLineWidth=1.5` 等微調回到套件預設值。
class KLineChartWidget extends StatefulWidget {
  const KLineChartWidget({
    super.key,
    required this.priceHistory,
    this.mainIndicators = const {ChartMainIndicator.ma},
    this.secondaryIndicators = const {},
    this.maDayList = kTechnicalMaDayList,
    this.height = 400,
    this.visibleCount,
  });

  /// 價格歷史（完整，未依顯示區間截斷）
  final List<DailyPriceEntry> priceHistory;
  final Set<ChartMainIndicator> mainIndicators;
  final Set<ChartSecondaryIndicator> secondaryIndicators;
  final List<int> maDayList;
  final double height;

  /// 只顯示最後 N 根 K 棒（null＝全部）。
  ///
  /// **指標在完整歷史上計算，之後才截尾顯示** —— 呼叫端若自行把
  /// `priceHistory` 先截短再傳進來，MA60 在 3M 視圖只會剩幾個有效點、
  /// 1M 視圖完全算不出來（60 日均線需要 60 根 bar）。
  final int? visibleCount;

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
        oldWidget.visibleCount != widget.visibleCount ||
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

    // 將 DailyPriceEntry 轉換為 KLineEntity
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

    // 指標在**完整歷史**上計算（MA 值算完後存進每個 entity），
    // 再截尾取顯示區間 —— 這樣 1M/3M 視圖裡的每根 K 棒都帶著用完整
    // 歷史算出的正確 MA60，而不是只有右緣幾個點有值。
    if (kLineData.isNotEmpty) {
      DataUtil.calculateAll(
        kLineData,
        _mainIndicatorsForCalc(),
        _secondaries(),
      );
    }

    final visible = widget.visibleCount;
    final shown = (visible != null && visible < kLineData.length)
        ? kLineData.sublist(kLineData.length - visible)
        : kLineData;

    setState(() {
      _kLineData = shown;
    });
  }

  /// 計算用的主圖指標（樣式不影響計算值，故用預設樣式即可）
  List<MainIndicator> _mainIndicatorsForCalc() => [
    if (widget.mainIndicators.contains(ChartMainIndicator.ma))
      MAIndicator(calcParams: widget.maDayList),
    if (widget.mainIndicators.contains(ChartMainIndicator.boll))
      BOLLIndicator(),
    if (widget.mainIndicators.contains(ChartMainIndicator.sar)) SARIndicator(),
  ];

  List<SecondaryIndicator> _secondaries() => [
    if (widget.secondaryIndicators.contains(ChartSecondaryIndicator.macd))
      MACDIndicator(),
    if (widget.secondaryIndicators.contains(ChartSecondaryIndicator.kdj))
      KDJIndicator(),
    if (widget.secondaryIndicators.contains(ChartSecondaryIndicator.rsi))
      RSIIndicator(),
    if (widget.secondaryIndicators.contains(ChartSecondaryIndicator.wr))
      WRIndicator(),
    if (widget.secondaryIndicators.contains(ChartSecondaryIndicator.cci))
      CCIIndicator(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.isDark;
    final chartBg = isDark
        ? IndicatorColors.chartDarkBackground
        : SemanticColors.lightBackground;

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

    // 依主題設定圖表顏色（1.0.4 的 KChartColors 只保留背景/K 棒/格線等
    // 共用色；各指標的線色移到自己的 IndicatorStyle）
    final chartColors = KChartColors(
      bgColor: chartBg,
      kLineColor: theme.colorScheme.primary,
      gridColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
      upColor: AppTheme.upColor, // 台股慣例：紅漲
      dnColor: AppTheme.downColor, // 綠跌
      volColor: theme.colorScheme.primary.withValues(alpha: 0.5),
      volUpColor: AppTheme.upColor,
      volDnColor: AppTheme.downColor,
      defaultTextColor: theme.colorScheme.onSurfaceVariant,
      nowPriceUpColor: AppTheme.upColor,
      nowPriceDnColor: AppTheme.downColor,
      selectBorderColor: theme.colorScheme.outlineVariant,
      selectFillColor: theme.colorScheme.surfaceContainerHighest,
      crossColor: theme.colorScheme.onSurfaceVariant,
      crossTextColor: theme.colorScheme.onSurface,
      maxColor: AppTheme.upColor,
      minColor: AppTheme.downColor,
    );

    // 繪製用的指標實例：同一組 calcParams、換上主題色
    final maColors = IndicatorColors.maColorsFor(theme.brightness);
    final mainForRender = <MainIndicator>[
      if (widget.mainIndicators.contains(ChartMainIndicator.ma))
        MAIndicator(
          calcParams: widget.maDayList,
          indicatorStyle: MAStyle(maColors: maColors),
        ),
      if (widget.mainIndicators.contains(ChartMainIndicator.boll))
        BOLLIndicator(),
      if (widget.mainIndicators.contains(ChartMainIndicator.sar))
        SARIndicator(),
    ];

    // 計算圖表摘要資訊供無障礙使用
    final summary = _buildChartSummary();

    return Semantics(
      label: summary,
      hint: 'stockDetail.chartHint'.tr(),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: chartBg,
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          // 以細框線定義圖表區域
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: KChartWidget(
          _kLineData,
          const KChartStyle(),
          chartColors,
          isTrendLine: false,
          mainIndicators: mainForRender,
          secondaryIndicators: _secondaries(),
          volHidden: false,
          isLine: false,
          isTapShowInfoDialog: true,
          hideGrid: false,
          showNowPrice: true,
          showInfoDialog: true,
          materialInfoDialog: true,
          timeFormat: TimeFormat.YEAR_MONTH_DAY,
          mBaseHeight: widget.height - 50,
          fixedLength: 2,
          detailBuilder: (entity) => KChartDetailPopup(entity: entity),
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
    // 以「實際播報出來的數字」（2 位）判方向，走三分法：平盤與捨入歸零
    // 都播報「持平」，避免出現「上漲 0.00%」這種自相矛盾的播報。
    final trend = l10n.S.priceChangeLabel(
      AppNumberFormat.roundForDisplay(changePercent, 2),
    );

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
