import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import 'package:afterclose/data/database/app_database.dart';
import 'package:afterclose/domain/services/ohlcv_data.dart';
import 'package:afterclose/domain/services/technical_indicator_service.dart';

import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/rsi_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/kd_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/macd_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/bollinger_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/obv_card.dart';
import 'package:afterclose/presentation/screens/stock_detail/tabs/technical/cards/atr_card.dart';

/// 從 priceHistory 提取的 OHLCV 快取，避免每次 build 重複 filter/map
///
/// 改用 [PriceEntryOhlcv.extractOhlcv]（單一 filter 條件）取代過去四個各自
/// 獨立的 `.where()`：舊實作對 prices/highs/lows 用「該欄位非 null」過濾，
/// 但 volumes 用「volume 非 null」過濾——停牌列 volume=0.0（非 null）會被
/// volumes 保留、卻被 prices/highs/lows 排除，兩者長度不一致，導致
/// calculateOBV 的長度守衛回傳 []、OBV 卡片永久空白。統一單一 filter 條件
/// 從源頭讓四個陣列必然等長。
class _ExtractedPrices {
  _ExtractedPrices(List<DailyPriceEntry> history)
    : _ohlcv = history.extractOhlcv();

  final OhlcvData _ohlcv;

  List<double> get prices => _ohlcv.closes;
  List<double> get highs => _ohlcv.highs;
  List<double> get lows => _ohlcv.lows;
  List<double> get volumes => _ohlcv.volumes;
  List<bool> get gapBefore => _ohlcv.gapBefore;
}

/// 根據選擇的副指標與主指標，顯示詳細的技術指標卡片
/// （選擇型：RSI/KDJ/MACD/Bollinger；恆顯型：OBV/ATR）。
class IndicatorCardsSection extends StatefulWidget {
  const IndicatorCardsSection({
    super.key,
    required this.priceHistory,
    required this.secondaryIndicators,
    required this.mainIndicators,
    required this.indicatorService,
  });

  final List<DailyPriceEntry> priceHistory;
  final Set<SecondaryState> secondaryIndicators;
  final Set<MainState> mainIndicators;
  final TechnicalIndicatorService indicatorService;

  @override
  State<IndicatorCardsSection> createState() => _IndicatorCardsSectionState();
}

class _IndicatorCardsSectionState extends State<IndicatorCardsSection> {
  _ExtractedPrices? _cached;
  List<DailyPriceEntry>? _lastHistory;

  // 快取指標計算結果，避免每次 build 重新計算 O(n) 序列
  List<double?>? _rsi;
  ({List<double?> k, List<double?> d})? _kd;
  ({List<double?> macd, List<double?> signal, List<double?> histogram})? _macd;
  ({List<double?> upper, List<double?> middle, List<double?> lower})? _boll;
  List<double>? _obv;
  List<double?>? _atr;

  _ExtractedPrices _getExtracted() {
    if (!identical(_lastHistory, widget.priceHistory)) {
      _lastHistory = widget.priceHistory;
      _cached = _ExtractedPrices(widget.priceHistory);
      // 價格變動時清除指標快取
      _rsi = null;
      _kd = null;
      _macd = null;
      _boll = null;
      _obv = null;
      _atr = null;
    }
    return _cached!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extracted = _getExtracted();
    final prices = extracted.prices;

    if (prices.length < 14) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'stockDetail.insufficientData'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final highs = extracted.highs;
    final lows = extracted.lows;
    final volumes = extracted.volumes;
    final svc = widget.indicatorService;

    // 按需計算並快取指標（只在 priceHistory 變動時重新計算）
    // gapBefore：停牌缺口不當成單一交易日變動採計，避免 RSI 曲線出現
    // 虛假極端值（root cause 修復，見 ohlcv_data.dart / calculateRSI）
    final rsi = _rsi ??= svc.calculateRSI(
      prices,
      gapBefore: extracted.gapBefore,
    );
    final kd = _kd ??= svc.calculateKD(highs, lows, prices);
    final macd = _macd ??= svc.calculateMACD(prices);
    final boll = _boll ??= svc.calculateBollingerBands(prices);
    final obv = _obv ??= svc.calculateOBV(prices, volumes);
    final atr = _atr ??= svc.calculateATR(highs, lows, prices);

    return Column(
      children: [
        if (widget.secondaryIndicators.contains(SecondaryState.RSI))
          RSICard(rsi: rsi, prices: prices),
        if (widget.secondaryIndicators.contains(SecondaryState.KDJ))
          KDCard(kd: kd),
        if (widget.secondaryIndicators.contains(SecondaryState.MACD))
          MACDCard(macd: macd),
        if (widget.mainIndicators.contains(MainState.BOLL))
          BollingerCard(boll: boll, prices: prices),
        if (volumes.length >= 2) OBVCard(obv: obv),
        if (highs.length >= 14 && lows.length >= 14 && prices.length >= 14)
          ATRCard(atr: atr, currentPrice: prices.last),
      ],
    );
  }
}
