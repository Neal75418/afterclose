import 'package:csv/csv.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:afterclose/presentation/providers/portfolio_provider.dart';
import 'package:afterclose/presentation/providers/stock_detail_provider.dart';
import 'package:afterclose/presentation/providers/comparison_provider.dart';
import 'package:afterclose/presentation/providers/watchlist_provider.dart';

/// 純 Dart 匯出服務 — 將各種資料格式化為 CSV 字串
class ExportService {
  const ExportService();

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// 自選股清單 → CSV
  String watchlistToCsv(List<WatchlistItemData> items) {
    final headers = [
      'export.csvSymbol'.tr(),
      'export.csvName'.tr(),
      'export.csvMarket'.tr(),
      'export.csvClose'.tr(),
      'export.csvChange'.tr(),
      'export.csvTrend'.tr(),
      'export.csvScore'.tr(),
    ];

    final rows = items.map((item) {
      return [
        item.symbol,
        item.stockName ?? '',
        item.market ?? '',
        item.latestClose?.toStringAsFixed(2) ?? '',
        item.priceChange != null
            ? '${item.priceChange! >= 0 ? "+" : ""}${item.priceChange!.toStringAsFixed(2)}%'
            : '',
        item.trendState ?? '',
        item.score?.toStringAsFixed(0) ?? '',
      ];
    }).toList();

    return const ListToCsvConverter().convert([headers, ...rows]);
  }

  /// 投資組合 → CSV
  String portfolioToCsv(List<PortfolioPositionData> positions) {
    final headers = [
      'export.csvSymbol'.tr(),
      'export.csvName'.tr(),
      'export.csvQuantity'.tr(),
      'export.csvAvgCost'.tr(),
      'export.csvCurrentPrice'.tr(),
      'export.csvMarketValue'.tr(),
      'export.csvUnrealizedPnl'.tr(),
      'export.csvRealizedPnl'.tr(),
      'export.csvDividend'.tr(),
    ];

    final rows = positions.map((pos) {
      return [
        pos.symbol,
        pos.stockName ?? '',
        pos.quantity.toStringAsFixed(0),
        pos.avgCost.toStringAsFixed(2),
        pos.currentPrice?.toStringAsFixed(2) ?? '',
        pos.marketValue.toStringAsFixed(0),
        pos.unrealizedPnl.toStringAsFixed(0),
        pos.realizedPnl.toStringAsFixed(0),
        pos.totalDividendReceived.toStringAsFixed(0),
      ];
    }).toList();

    return const ListToCsvConverter().convert([headers, ...rows]);
  }

  /// 個股分析 → CSV
  String analysisDataToCsv(String symbol, StockDetailState state) {
    final rows = <List<String>>[];

    // 基本資訊
    rows.add([
      'export.csvSection'.tr(),
      'export.csvItem'.tr(),
      'export.csvValue'.tr(),
    ]);

    final stock = state.stock;
    final price = state.latestPrice;
    final analysis = state.analysis;

    rows.add(['export.csvBasicInfo'.tr(), 'export.csvSymbol'.tr(), symbol]);
    if (stock != null) {
      rows.add(['', 'export.csvName'.tr(), stock.name]);
    }
    if (price != null) {
      rows.add([
        '',
        'export.csvClose'.tr(),
        price.close?.toStringAsFixed(2) ?? '',
      ]);
      rows.add(['', 'export.csvDate'.tr(), _dateFormat.format(price.date)]);
    }

    // 分析
    if (analysis != null) {
      rows.add([
        'export.csvAnalysis'.tr(),
        'export.csvTrend'.tr(),
        analysis.trendState,
      ]);
      if (analysis.reversalState != 'NONE') {
        rows.add(['', 'export.csvReversal'.tr(), analysis.reversalState]);
      }
      rows.add(['', 'export.csvScore'.tr(), analysis.score.toStringAsFixed(0)]);
    }

    // AI 摘要
    if (state.aiSummary != null) {
      final summary = state.aiSummary!;
      rows.add([
        'export.csvAiSummary'.tr(),
        'export.csvOverall'.tr(),
        summary.overallAssessment,
      ]);
      for (final signal in summary.keySignals) {
        rows.add(['', 'export.csvSignal'.tr(), signal]);
      }
      for (final risk in summary.riskFactors) {
        rows.add(['', 'export.csvRisk'.tr(), risk]);
      }
    }

    // 訊號
    for (final reason in state.reasons) {
      rows.add([
        'export.csvSignals'.tr(),
        reason.reasonType,
        reason.ruleScore.toStringAsFixed(0),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// 比較結果 → CSV
  String comparisonToCsv(ComparisonState state) {
    if (state.symbols.isEmpty) return '';

    // Header: 指標, symbol1, symbol2, ...
    final headers = ['export.csvItem'.tr()];
    for (final symbol in state.symbols) {
      final stock = state.stocksMap[symbol];
      headers.add('$symbol ${stock?.name ?? ""}');
    }

    final rows = <List<String>>[headers];

    // 收盤價
    _addComparisonRow(rows, 'export.csvClose'.tr(), state.symbols, (s) {
      return state.latestPricesMap[s]?.close?.toStringAsFixed(2) ?? '';
    });

    // 漲跌幅
    _addComparisonRow(rows, 'export.csvChange'.tr(), state.symbols, (s) {
      final price = state.latestPricesMap[s];
      if (price == null) return '';
      final close = price.close;
      final open = price.open;
      if (close == null || open == null || open == 0) return '';
      final change = (close - open) / open * 100;
      return '${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%';
    });

    // 趨勢
    _addComparisonRow(rows, 'export.csvTrend'.tr(), state.symbols, (s) {
      return state.analysesMap[s]?.trendState ?? '';
    });

    // 分數
    _addComparisonRow(rows, 'export.csvScore'.tr(), state.symbols, (s) {
      return state.analysesMap[s]?.score.toStringAsFixed(0) ?? '';
    });

    // 本益比
    _addComparisonRow(rows, 'comparison.metricPE'.tr(), state.symbols, (s) {
      return state.valuationsMap[s]?.per?.toStringAsFixed(2) ?? '';
    });

    // 殖利率
    _addComparisonRow(
      rows,
      'comparison.metricDividendYield'.tr(),
      state.symbols,
      (s) {
        return state.valuationsMap[s]?.dividendYield?.toStringAsFixed(2) ?? '';
      },
    );

    // AI 情緒
    _addComparisonRow(rows, 'comparison.metricSentiment'.tr(), state.symbols, (
      s,
    ) {
      final summary = state.summariesMap[s];
      if (summary == null) return '';
      return summary.sentiment.name;
    });

    return const ListToCsvConverter().convert(rows);
  }

  void _addComparisonRow(
    List<List<String>> rows,
    String label,
    List<String> symbols,
    String Function(String symbol) getValue,
  ) {
    final row = [label];
    for (final s in symbols) {
      row.add(getValue(s));
    }
    rows.add(row);
  }
}
