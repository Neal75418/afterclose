import 'package:candlesticks/candlesticks.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/core/theme/design_tokens.dart';
import 'package:afterclose/core/utils/responsive_helper.dart';

/// K-line chart widget using candlesticks package
/// Note: This package doesn't support technical indicator overlays.
/// For indicators, use KLineChartWidget with k_chart_plus instead.
class CandlestickChartWidget extends StatefulWidget {
  const CandlestickChartWidget({super.key, required this.priceHistory});

  final List<DailyPriceEntry> priceHistory;

  @override
  State<CandlestickChartWidget> createState() => _CandlestickChartWidgetState();
}

class _CandlestickChartWidgetState extends State<CandlestickChartWidget> {
  List<Candle> _candles = [];

  @override
  void initState() {
    super.initState();
    _buildCandleData();
  }

  @override
  void didUpdateWidget(CandlestickChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.priceHistory != widget.priceHistory) {
      _buildCandleData();
    }
  }

  void _buildCandleData() {
    if (widget.priceHistory.isEmpty) {
      setState(() {
        _candles = [];
      });
      return;
    }

    // 將 DailyPriceEntry 轉換為 Candle（依日期降冪排序供套件使用）
    final sortedHistory = List<DailyPriceEntry>.from(widget.priceHistory)
      ..sort((a, b) => b.date.compareTo(a.date));

    final candles = <Candle>[];
    for (final entry in sortedHistory) {
      if (entry.open != null &&
          entry.high != null &&
          entry.low != null &&
          entry.close != null) {
        candles.add(
          Candle(
            date: entry.date,
            open: entry.open!,
            high: entry.high!,
            low: entry.low!,
            close: entry.close!,
            volume: entry.volume ?? 0,
          ),
        );
      }
    }

    setState(() {
      _candles = candles;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartHeight = context.responsive(
      mobile: 280.0,
      tablet: 360.0,
      desktop: 420.0,
    );

    if (_candles.isEmpty) {
      return Container(
        height: chartHeight,
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

    return Container(
      height: chartHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Candlesticks(
        candles: _candles,
        onLoadMoreCandles: () async {
          // 如需要可在此實作分頁
        },
        actions: const [
          // 可在此新增週期選擇功能
        ],
      ),
    );
  }
}

/// Volume chart widget using custom painter
class VolumeChartWidget extends StatelessWidget {
  const VolumeChartWidget({
    super.key,
    required this.priceHistory,
    this.height = 100,
  });

  final List<DailyPriceEntry> priceHistory;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (priceHistory.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        child: Center(
          child: Text(
            'stockDetail.noVolumeData'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    // Take last 60 data points for display
    final displayData = priceHistory.length > 60
        ? priceHistory.sublist(priceHistory.length - 60)
        : priceHistory;

    final maxVolume = displayData
        .map((e) => e.volume ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(8),
      child: CustomPaint(
        size: Size.infinite,
        painter: _VolumePainter(
          data: displayData,
          maxVolume: maxVolume,
          upColor: AppTheme.upColor,
          downColor: AppTheme.downColor,
        ),
      ),
    );
  }
}

class _VolumePainter extends CustomPainter {
  _VolumePainter({
    required this.data,
    required this.maxVolume,
    required this.upColor,
    required this.downColor,
  });

  final List<DailyPriceEntry> data;
  final double maxVolume;
  final Color upColor;
  final Color downColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxVolume == 0) return;

    final barWidth = size.width / data.length - 1;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final entry = data[i];
      final volume = entry.volume ?? 0;
      final close = entry.close ?? 0;
      final open = entry.open ?? 0;

      // 依漲跌決定顏色
      final isUp = close >= open;
      paint.color = (isUp ? upColor : downColor).withValues(alpha: 0.7);

      final barHeight = (volume / maxVolume) * size.height;
      final x = i * (barWidth + 1);
      final y = size.height - barHeight;

      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VolumePainter oldDelegate) {
    // 先比較參照（最快速檢查）
    if (identical(data, oldDelegate.data) &&
        maxVolume == oldDelegate.maxVolume) {
      return false;
    }
    // 再比較長度作為次要檢查
    if (data.length != oldDelegate.data.length) {
      return true;
    }
    // 比較最大成交量
    return maxVolume != oldDelegate.maxVolume;
  }
}
