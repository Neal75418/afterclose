import 'package:candlesticks/candlesticks.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:afterclose/core/theme/app_theme.dart';
import 'package:afterclose/data/database/app_database.dart';

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

    // Convert DailyPriceEntry to Candle (sorted by date descending for candlesticks package)
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

    if (_candles.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
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
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Candlesticks(
        candles: _candles,
        onLoadMoreCandles: () async {
          // Could implement pagination here if needed
        },
        actions: const [
          // Period selector actions could be added here
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
          borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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

      // Determine color based on price movement
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
    // Compare by reference first (fastest check)
    if (identical(data, oldDelegate.data) &&
        maxVolume == oldDelegate.maxVolume) {
      return false;
    }
    // Compare lengths as secondary check
    if (data.length != oldDelegate.data.length) {
      return true;
    }
    // Compare maxVolume
    return maxVolume != oldDelegate.maxVolume;
  }
}
