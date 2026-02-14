import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/domain/services/technical_indicator_service.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/indicator_cards.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/indicator_selectors.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/ohlcv_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/widgets/k_line_chart_widget.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/core/utils/responsive_helper.dart';
import 'package:afterclose/presentation/widgets/section_header.dart';

/// 圖表時間範圍選項
enum ChartTimeRange {
  oneMonth(30, '1M'),
  threeMonths(90, '3M'),
  sixMonths(180, '6M'),
  oneYear(365, '1Y'),
  all(0, 'ALL'); // 0 表示全部資料

  const ChartTimeRange(this.days, this.label);
  final int days;
  final String label;
}

/// Technical analysis tab - K-line chart + indicators + volume
class TechnicalTab extends ConsumerStatefulWidget {
  const TechnicalTab({super.key, required this.symbol});

  final String symbol;

  @override
  ConsumerState<TechnicalTab> createState() => _TechnicalTabState();
}

class _TechnicalTabState extends ConsumerState<TechnicalTab> {
  // 主圖指標（疊加於 K 線圖）：MA、BOLL
  final Set<MainState> _mainIndicators = {MainState.MA};
  // 副圖指標（子圖表）：MACD、KDJ、RSI、WR、CCI
  final Set<SecondaryState> _secondaryIndicators = {};
  // 時間範圍（預設 3 個月）
  ChartTimeRange _timeRange = ChartTimeRange.threeMonths;

  final TechnicalIndicatorService _indicatorService =
      TechnicalIndicatorService();

  void _toggleMainIndicator(MainState indicator) {
    setState(() {
      if (_mainIndicators.contains(indicator)) {
        _mainIndicators.remove(indicator);
      } else {
        _mainIndicators.add(indicator);
      }
    });
  }

  void _toggleSecondaryIndicator(SecondaryState indicator) {
    setState(() {
      if (_secondaryIndicators.contains(indicator)) {
        _secondaryIndicators.remove(indicator);
      } else {
        _secondaryIndicators.add(indicator);
      }
    });
  }

  void _setTimeRange(ChartTimeRange range) {
    setState(() {
      _timeRange = range;
    });
  }

  /// 根據選擇的時間範圍過濾價格歷史資料
  List<DailyPriceEntry> _filterPriceHistory(List<DailyPriceEntry> history) {
    if (_timeRange == ChartTimeRange.all || history.isEmpty) {
      return history;
    }

    final cutoffDate = DateTime.now().subtract(Duration(days: _timeRange.days));
    return history.where((entry) => entry.date.isAfter(cutoffDate)).toList();
  }

  /// 建立時間範圍選擇器
  Widget _buildTimeRangeSelector(ThemeData theme) {
    return SegmentedButton<ChartTimeRange>(
      segments: ChartTimeRange.values
          .map(
            (range) => ButtonSegment<ChartTimeRange>(
              value: range,
              label: Text(range.label),
            ),
          )
          .toList(),
      selected: {_timeRange},
      onSelectionChanged: (Set<ChartTimeRange> selection) {
        _setTimeRange(selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockDetailProvider(widget.symbol));
    final theme = Theme.of(context);

    if (state.price.priceHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.candlestick_chart_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'stockDetail.noTechnicalData'.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 依選取的副圖指標計算圖表高度
    final baseHeight = context.responsive(
      mobile: 320.0,
      tablet: 400.0,
      desktop: 450.0,
    );
    final secondaryHeight = _secondaryIndicators.isEmpty
        ? 0.0
        : 120.0 * _secondaryIndicators.length;
    final totalChartHeight = baseHeight + secondaryHeight;

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // K 線圖區段
          SectionHeader(
            title: 'stockDetail.klineChart'.tr(),
            icon: Icons.candlestick_chart,
          ),
          const SizedBox(height: 12),

          // 主圖指標選擇（MA、BOLL）
          MainIndicatorSelector(
            selectedIndicators: _mainIndicators,
            onToggle: _toggleMainIndicator,
          ),
          const SizedBox(height: 8),

          // 時間區間選擇
          _buildTimeRangeSelector(theme),
          const SizedBox(height: 12),

          // 含指標的 K 線圖
          KLineChartWidget(
            priceHistory: _filterPriceHistory(state.price.priceHistory),
            mainIndicators: _mainIndicators,
            secondaryIndicators: _secondaryIndicators,
            height: totalChartHeight,
            maDayList: const [5, 10, 20, 60],
          ),
          const SizedBox(height: 16),

          // 副圖指標選擇（RSI、KD、MACD）
          SectionHeader(
            title: 'stockDetail.secondaryIndicators'.tr(),
            icon: Icons.show_chart,
          ),
          const SizedBox(height: 8),
          SecondaryIndicatorSelector(
            selectedIndicators: _secondaryIndicators,
            onToggle: _toggleSecondaryIndicator,
          ),
          const SizedBox(height: 16),

          // OHLCV 資料卡片
          OhlcvCard(
            latestPrice: state.price.latestPrice,
            priceChange: state.priceChange,
          ),

          // 詳細指標數值
          if (_secondaryIndicators.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionHeader(
              title: 'stockDetail.indicatorValues'.tr(),
              icon: Icons.analytics,
            ),
            const SizedBox(height: 12),
            IndicatorCardsSection(
              priceHistory: state.price.priceHistory,
              secondaryIndicators: _secondaryIndicators,
              mainIndicators: _mainIndicators,
              indicatorService: _indicatorService,
            ),
          ],
        ],
      ),
    );
  }
}
